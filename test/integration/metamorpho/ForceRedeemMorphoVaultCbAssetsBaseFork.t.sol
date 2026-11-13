// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { ForceRedeemMorphoVaultHook } from "../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../src/vendor/morpho/IMorphoMarketV1Adapter.sol";
import { MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title ForceRedeemMorphoVaultCbAssetsBaseFork
/// @notice Base-fork e2e for `ForceRedeemMorphoVaultHook` against Clearstar's cbAssets Vault V2, the venue behind
///         SuperGOOGL and the case the review asked about: USDC (6 decimals) under 18-decimal shares, so
///         `virtualShares == 1e12`; a 30 bps adapter penalty (the rate that broke the old 25 bps cap); thirteen
///         listed markets; ZERO idle; and a `liquidityAdapter` set, which the WETH Prime suite cannot reach.
/// @dev Deposits are closed on this vault (`maxDeposit == 0`), so the fixture mints the account's shares with
///      `deal(..., adjust = true)`, which also raises `totalSupply`. The share price falls a hair once; both `build`
///      and execution see the same state, which is all the exact-settlement assertions need.
contract ForceRedeemMorphoVaultCbAssetsBaseForkTest is Test, Constants {
    /// @dev Pinned at authoring time (2026-11-13) so every number below is reproducible.
    uint256 public constant FORK_BLOCK = 57_006_077;

    address public constant CB_ASSETS = 0x91C056B6d4311a743614FBc03ac32d4E6A2d3a3c;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant MORPHO_BLUE_BASE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    uint256 public constant CB_ASSETS_PENALTY = 0.003e18; // 30 bps

    ForceRedeemMorphoVaultHook internal hook;
    address internal account;
    /// @dev 250k shares, roughly 258k USDC at the pinned block: well inside the reachable market liquidity.
    uint256 internal constant CLAIM = 250_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_BASE);
        account = makeAddr("cbAssetsExiter");
        deal(CB_ASSETS, account, CLAIM, true);
    }

    /*//////////////////////////////////////////////////////////////
                                FIXTURE
    //////////////////////////////////////////////////////////////*/

    /// @dev Pins the shape this suite exists for; if the vault changes, the test says so instead of passing vacuously.
    function test_Fixture_IsTheDecimalOffsetCase() public view {
        IMorphoVaultV2 vault = IMorphoVaultV2(CB_ASSETS);
        assertEq(IERC20Metadata(USDC).decimals(), 6, "USDC has 6 decimals");
        assertEq(IERC20Metadata(CB_ASSETS).decimals(), 18, "shares have 18 decimals");
        assertEq(vault.virtualShares(), 1e12, "virtualShares = 10 ** (18 - 6)");
        assertEq(IERC20(USDC).balanceOf(CB_ASSETS), 0, "no idle: every exit needs at least one pull");
        assertEq(vault.adaptersLength(), 1);
        address adapter = vault.adapters(0);
        assertEq(vault.forceDeallocatePenalty(adapter), CB_ASSETS_PENALTY, "30 bps, above the old 25 bps cap");
        assertEq(IMorphoMarketV1Adapter(adapter).marketIdsLength(), 13);
        assertTrue(_liquidityAdapter() != address(0), "a liquidity adapter is set on this vault");
        assertEq(vault.balanceOf(account), CLAIM);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXITS
    //////////////////////////////////////////////////////////////*/

    /// @dev The headline in 6-decimal units: a full exit ends at zero shares and pays exactly `previewAssetsOut`.
    function test_FullExit_LeavesZeroShares_PaysPreviewAssetsOut_InUsdc() public {
        uint256 quoted = hook.previewAssetsOut(CB_ASSETS, account, CLAIM);
        assertGt(quoted, 240_000e6, "about 1.03 USDC per share at the pinned block");
        assertLt(quoted, 270_000e6);

        uint256 pulls = _run(CLAIM);
        assertGt(pulls, 0, "a fully allocated vault needs at least one pull");

        assertEq(IMorphoVaultV2(CB_ASSETS).balanceOf(account), 0, "a full-balance input ends at zero shares");
        assertEq(IERC20(USDC).balanceOf(account), quoted, "USDC received equals previewAssetsOut to the wei");
        assertEq(hook.getOutAmount(account), quoted, "outAmount is the measured 6-decimal delta");
        assertEq(hook.getOutToken(account), USDC);
        assertEq(hook.usedShares(), CLAIM, "usedShares spans the whole call, penalty burns included");
    }

    /// @dev A partial exit burns exactly S and nothing else; the rest of the claim stays whole.
    function test_PartialExit_BurnsExactlyS_PaysPreview() public {
        uint256 shares = CLAIM / 3;
        uint256 quoted = hook.previewAssetsOut(CB_ASSETS, account, shares);
        _run(shares);
        assertEq(IMorphoVaultV2(CB_ASSETS).balanceOf(account), CLAIM - shares, "exactly S shares left");
        assertEq(IERC20(USDC).balanceOf(account), quoted);
    }

    /// @dev The per-pull burns match the stepper with N carrying the 1e12 virtual shares and D in USDC wei, and the
    ///      penalty is 30 bps of each pull rounded up: this is the arithmetic the review asked to see at 6 decimals.
    function test_PerPullBurns_MatchTheSteppedRate_AtSixDecimals() public {
        Execution[] memory all = hook.build(address(0), account, _hookData(CLAIM));
        assertGe(all.length, 5, "pre, accrue, >= 1 pull, redeem, post");
        assertEq(bytes4(all[1].callData), IMorphoVaultV2.accrueInterest.selector, "accrual is the first leg");

        IMorphoVaultV2 vault = IMorphoVaultV2(CB_ASSETS);
        (uint256 ta, uint256 pf, uint256 mf) = vault.accrueInterestView();
        uint256 n = vault.totalSupply() + pf + mf + vault.virtualShares();
        uint256 d = ta + 1;
        assertGt(n / d, 1e11, "N/D is ~1e12 x the share price: the decimal offset is live");
        uint256 predictedP;
        uint256 sourced;

        vm.startPrank(account);
        hook.setExecutionContext(account);
        for (uint256 i; i < all.length; ++i) {
            (bool ok, bytes memory ret) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("leg ", vm.toString(i)));
            if (i > 1 && i + 2 < all.length) {
                (,, uint256 x,) = _decodePull(all[i]);
                uint256 pa = _mulDivUp(x, CB_ASSETS_PENALTY, 1e18);
                uint256 ps = _mulDivUp(pa, n, d);
                n -= ps;
                d -= pa;
                predictedP += ps;
                sourced += x;
                assertEq(abi.decode(ret, (uint256)), ps, "forceDeallocate burned exactly the stepped shares");
            }
        }
        hook.resetExecutionState(account);
        vm.stopPrank();

        (uint256 redeemed,,) = _decodeRedeem(all[all.length - 2]);
        assertEq(redeemed, CLAIM - predictedP, "the redeem leg was S minus the stepped burns");
        assertEq(vault.balanceOf(account), 0);
        uint256 paid = IERC20(USDC).balanceOf(account);
        assertLe(paid, sourced, "paid out of what was deallocated (idle was zero)");
        assertEq(IERC20(USDC).balanceOf(CB_ASSETS), sourced - paid, "the residual is the vault's new idle");
        assertLt(sourced - paid, 10e6, "the smallest covering X leaves only rounding dust idle");
    }

    /// @dev The liquidity adapter is never the one paying: the redeem is covered from the deallocated amount, so
    ///      the vault's `exit` does not reach for `liquidityData`. Observable as the liquidity market's position
    ///      moving only by what the pulls took from it, never by an extra redeem-time withdrawal.
    function test_RedeemIsPaidFromThePulls_NotTheLiquidityAdapter() public {
        Execution[] memory all = hook.build(address(0), account, _hookData(CLAIM));
        IMorphoMarketV1Adapter adapter = IMorphoMarketV1Adapter(IMorphoVaultV2(CB_ASSETS).adapters(0));
        bytes32 liqId = _marketId(_liquidityParams());
        uint256 liqBefore = adapter.expectedSupplyAssets(liqId);

        uint256 pulledFromLiq;
        for (uint256 i = 2; i + 2 < all.length; ++i) {
            (, MarketParams memory p, uint256 x,) = _decodePull(all[i]);
            if (_marketId(p) == liqId) pulledFromLiq += x;
        }

        _run(CLAIM);
        uint256 liqAfter = adapter.expectedSupplyAssets(liqId);
        // Morpho's own withdraw rounding can move the reported position by a wei or two.
        assertApproxEqAbs(liqBefore - liqAfter, pulledFromLiq, 2, "the liquidity market lost only what the pulls took");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _hookData(uint256 shares) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(0xFEED)), CB_ASSETS, shares, false);
    }

    /// @dev Mirrors `SuperExecutorBase._processHook`; returns the number of `forceDeallocate` legs.
    function _run(uint256 shares) internal returns (uint256 pulls) {
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, _hookData(shares));
        for (uint256 i; i < all.length; ++i) {
            (bool ok, bytes memory ret) = all[i].target.call(all[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        return all.length - 4;
    }

    function _liquidityAdapter() internal view returns (address a) {
        (bool ok, bytes memory ret) = CB_ASSETS.staticcall(abi.encodeWithSignature("liquidityAdapter()"));
        require(ok && ret.length == 32, "liquidityAdapter()");
        a = abi.decode(ret, (address));
    }

    function _liquidityParams() internal view returns (MarketParams memory p) {
        (bool ok, bytes memory ret) = CB_ASSETS.staticcall(abi.encodeWithSignature("liquidityData()"));
        require(ok, "liquidityData()");
        bytes memory raw = abi.decode(ret, (bytes));
        p = abi.decode(raw, (MarketParams));
    }

    function _marketId(MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function _decodePull(Execution memory e)
        internal
        pure
        returns (address adapter_, MarketParams memory p, uint256 assets, address onBehalf)
    {
        bytes memory args = _args(e.callData);
        bytes memory inner;
        (adapter_, inner, assets, onBehalf) = abi.decode(args, (address, bytes, uint256, address));
        p = abi.decode(inner, (MarketParams));
    }

    function _decodeRedeem(Execution memory e) internal pure returns (uint256 shares, address receiver, address owner) {
        assertEq(bytes4(e.callData), IERC4626.redeem.selector, "last leg is redeem");
        (shares, receiver, owner) = abi.decode(_args(e.callData), (uint256, address, address));
    }

    function _args(bytes memory raw) internal pure returns (bytes memory args) {
        args = new bytes(raw.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = raw[i + 4];
        }
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return (x * y + (z - 1)) / z;
    }
}
