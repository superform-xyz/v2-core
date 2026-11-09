// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { ForceDeallocateMorphoHook } from "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol";
import { Constants } from "../../utils/Constants.sol";

interface IMorphoVaultV2Read {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function adapters(uint256 index) external view returns (address);
    function adaptersLength() external view returns (uint256);
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
}

interface IAdapterRead {
    function realAssets() external view returns (uint256);
    function parentVault() external view returns (address);
}

interface ISuperVaultRead {
    function name() external view returns (string memory);
    function asset() external view returns (address);
}

/// @title ForceDeallocateMorphoSuperWETHFork
/// @author Superform Labs
/// @notice E2E for `ForceDeallocateMorphoHook` against the LIVE condition it exists to resolve: the
///         Flagship WETH SuperVault's position in Gauntlet WETH Prime is fully allocated into a Morpho
///         Blue adapter, so `maxWithdraw` for the strategy is ZERO and no redeem can draw on it.
/// @dev WHY A SEPARATE FILE. `ForceDeallocateMorphoHookE2E` pins `FORK_BLOCK = 25_140_000`, which
///      predates this position. This file pins a recent block instead, and the two cannot share a fork.
/// @dev WHY A PINNED BLOCK AND NOT `latest`. The assertions below describe a live, resolvable condition:
///      the moment anyone force-deallocates this adapter, or the curator raises the vault's idle balance,
///      a `latest` fork stops reproducing it and the test starts failing for a reason that is not a
///      regression. Pinning preserves the demonstration permanently. If you want to re-check the
///      condition against today's chain, bump FORK_BLOCK and expect the numbers to move.
/// @dev MEASURED AT THE PINNED BLOCK (values asserted relatively, not hard-coded, except where noted):
///        Gauntlet WETH Prime totalAssets   10,003.623358 WETH
///        held in adapter 0xc2B92c...7a35   10,003.623358 WETH
///        the vault's own WETH balance           0.0000016 WETH   <- all a withdraw can draw on
///        strategy's position                  649.703639 WETH
///        forceDeallocatePenalty(adapter)   1e13 WAD = 0.001% (0.1 bps)
/// @dev DO NOT ASSERT ON `maxWithdraw` HERE, AND THIS IS NOT AN OVERSIGHT. On this vault it returns 0
///      both before AND after a successful force-deallocate — measured — while `withdraw` itself goes
///      from reverting to succeeding. Asserting the view would have produced a test that passes for the
///      wrong reason before the fix and fails for the wrong reason after it. These tests assert the
///      vault's real WETH balance and whether `withdraw` actually executes.
contract ForceDeallocateMorphoSuperWETHFork is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Flagship WETH SuperVault ("superWETH") and its strategy, from SuperVaultAggregator
    ///      0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698 (`getAllSuperVaults`/`getAllSuperVaultStrategies`
    ///      index 1). The STRATEGY is the account that holds the Morpho position and executes hooks.
    address public constant SUPER_WETH_VAULT = 0xa036823b9A24F63c32553367bf181Ee04229c3AC;
    address public constant SUPER_WETH_STRATEGY = 0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2;

    /// @dev The one yield source of the 19 registered on this strategy that actually holds a position.
    address public constant GAUNTLET_WETH_PRIME = 0x43fCd85E8D9D003D515f886891B7C742AC9f92da;
    address public constant GAUNTLET_ADAPTER = 0xc2B92c498b235516380c04879259Eb2CB1A87a35;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @dev The adapter is a Morpho Blue market adapter (`morpho()` returns MORPHO_BLUE), so its
    ///      `adapterData` is an ABI-encoded `MarketParams` naming WHICH market to pull from. This is the
    ///      WETH/wstETH market at 96.5% LLTV, one of two the adapter supplies into. An EMPTY tail reverts
    ///      on this adapter — see `test_EmptyAdapterData_RevertsOnARealMarketAdapter`.
    address public constant MARKET_ORACLE = 0xbD60A6770b27E084E8617335ddE769241B0e71D8;
    address public constant MARKET_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 public constant MARKET_LLTV = 965_000_000_000_000_000;

    uint256 public constant FORK_BLOCK = 26_376_760;

    /// @dev Deliberately small relative to the ~2,661 WETH of free liquidity in the Morpho market at the
    ///      pinned block, so the test exercises the hook rather than the market's capacity.
    uint256 public constant DEALLOCATE_AMOUNT = 10 ether;

    ForceDeallocateMorphoHook public hook;

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceDeallocateMorphoHook();
    }

    /*//////////////////////////////////////////////////////////////
                        THE LIVE CONDITION
    //////////////////////////////////////////////////////////////*/

    /// @notice Documents the problem: a 649 WETH position the strategy cannot draw 1 WETH from.
    /// @dev The assertion that matters is the last one: `withdraw` REVERTS. Everything above it explains
    ///      why. If this test ever fails because the withdraw succeeds, the condition was resolved
    ///      on-chain and the fork block needs revisiting — it is not a hook regression.
    function test_SuperWETH_PositionIsStuck_WithdrawReverts() public {
        assertEq(ISuperVaultRead(SUPER_WETH_VAULT).asset(), WETH, "superWETH is a WETH vault");
        assertEq(IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).asset(), WETH, "so is the Morpho vault");
        assertEq(IAdapterRead(GAUNTLET_ADAPTER).parentVault(), GAUNTLET_WETH_PRIME, "adapter belongs to it");

        uint256 position = _position();
        assertGt(position, 100 ether, "the strategy holds a materially large position");

        // Essentially everything the vault reports is in the adapter, so there is nothing to pay out.
        uint256 liquid = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        assertLt(liquid, 0.01 ether, "the vault holds dust");
        assertLt(liquid * 1000, position, "dust is orders of magnitude below the position");

        assertFalse(_tryWithdraw(1 ether), "withdrawing even 1 WETH must REVERT - this is the issue");
    }

    /// @notice The hook resolves it: after force-deallocating, the same withdraw succeeds.
    function test_SuperWETH_ForceDeallocate_UnblocksTheWithdraw() public {
        assertFalse(_tryWithdraw(1 ether), "blocked before");

        uint256 liquidBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        _runHook(DEALLOCATE_AMOUNT);
        uint256 liquidAfter = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);

        // The amount that lands is `assets` MINUS the penalty, not `assets` — one more reason the hook
        // must not publish `assets` as an output. Penalty is 0.1 bps here, so allow for it.
        assertGt(liquidAfter, liquidBefore, "underlying moved into the vault");
        uint256 landed = liquidAfter - liquidBefore;
        assertLe(landed, DEALLOCATE_AMOUNT, "never more than requested");
        assertGe(landed, DEALLOCATE_AMOUNT - (DEALLOCATE_AMOUNT / 100), "within 1% of requested");

        assertTrue(_tryWithdraw(1 ether), "the withdraw that reverted before now succeeds");
    }

    /// @notice The strategy actually receives the WETH, which is the operational point.
    function test_SuperWETH_ForceDeallocate_ThenStrategyReceivesWETH() public {
        _runHook(DEALLOCATE_AMOUNT);

        uint256 before = IERC20(WETH).balanceOf(SUPER_WETH_STRATEGY);
        vm.prank(SUPER_WETH_STRATEGY);
        (bool ok,) = GAUNTLET_WETH_PRIME.call(
            abi.encodeWithSignature("withdraw(uint256,address,address)", 5 ether, SUPER_WETH_STRATEGY, SUPER_WETH_STRATEGY)
        );
        assertTrue(ok, "withdraw succeeds once the vault has underlying");
        assertEq(IERC20(WETH).balanceOf(SUPER_WETH_STRATEGY) - before, 5 ether, "strategy received 5 WETH");
    }

    /// @notice The penalty is a REAL cost in shares, and the account receives NO underlying from the hop.
    /// @dev Precisely why `outAmount` must be zero: across this operation the account's share balance
    ///      strictly DECREASES and its WETH balance does not move at all.
    function test_SuperWETH_ForceDeallocate_BurnsPenaltySharesAndPaysNothing() public {
        uint256 sharesBefore = IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).balanceOf(SUPER_WETH_STRATEGY);
        uint256 wethBefore = IERC20(WETH).balanceOf(SUPER_WETH_STRATEGY);

        _runHook(DEALLOCATE_AMOUNT);

        assertLt(
            IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).balanceOf(SUPER_WETH_STRATEGY),
            sharesBefore,
            "penalty shares burned from the executing account"
        );
        assertEq(
            IERC20(WETH).balanceOf(SUPER_WETH_STRATEGY), wethBefore, "the account received NO underlying"
        );

        uint256 penaltyWad = IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(GAUNTLET_ADAPTER);
        assertGt(penaltyWad, 0, "this adapter charges a penalty");
        assertLe(penaltyWad, 0.02e18, "Morpho caps it at 2%");
    }

    /*//////////////////////////////////////////////////////////////
                SUP-21780 SEMANTICS, ON A REAL POSITION
    //////////////////////////////////////////////////////////////*/

    /// @notice `outAmount` is ZERO and `outToken` is the underlying - verified against a live position.
    function test_SuperWETH_ForceDeallocate_PublishesZeroOutAmount() public {
        _runHook(DEALLOCATE_AMOUNT);

        assertEq(
            ISuperHookResult(address(hook)).getOutAmount(SUPER_WETH_STRATEGY),
            0,
            "outAmount must be 0: nothing was paid to the account, so nothing may chain off it"
        );
        assertEq(
            ISuperHookResult(address(hook)).getOutToken(SUPER_WETH_STRATEGY),
            WETH,
            "outToken is the underlying that moved, for off-chain classification"
        );
    }

    /// @notice The raw `adapterData` tail is load-bearing on a real Morpho Blue market adapter.
    /// @dev Every pre-existing E2E case passes an EMPTY tail, because those adapters accept one. This one
    ///      does not: it needs an ABI-encoded `MarketParams`. So this is the case that actually proves
    ///      SUP-21780's tail survives end to end - an off-by-one at offset 105 would hand Morpho a
    ///      corrupted payload rather than fail.
    function test_EmptyAdapterData_RevertsOnARealMarketAdapter() public {
        assertFalse(_tryHook(DEALLOCATE_AMOUNT, ""), "an empty tail cannot name a Morpho Blue market");
    }

    /// @notice A WRONG market in the tail is rejected, proving the bytes are forwarded not reconstructed.
    function test_WrongMarketInAdapterData_IsRejected() public {
        MarketParams memory bad = _market();
        bad.lltv = 1; // not a market this adapter supplies into
        assertFalse(_tryHook(DEALLOCATE_AMOUNT, abi.encode(bad)), "a bogus market must be rejected");
    }

    /// @notice And the correct tail works, so the two tests above are not passing for a trivial reason.
    function test_CorrectAdapterData_Succeeds() public {
        assertTrue(_tryHook(DEALLOCATE_AMOUNT, abi.encode(_market())), "the real market params work");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _position() internal view returns (uint256) {
        return IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).convertToAssets(
            IMorphoVaultV2Read(GAUNTLET_WETH_PRIME).balanceOf(SUPER_WETH_STRATEGY)
        );
    }

    /// @dev Attempts a withdraw as the strategy and reports success, reverting nothing itself.
    function _tryWithdraw(uint256 assets) internal returns (bool ok) {
        uint256 snap = vm.snapshotState();
        vm.prank(SUPER_WETH_STRATEGY);
        (ok,) = GAUNTLET_WETH_PRIME.call(
            abi.encodeWithSignature("withdraw(uint256,address,address)", assets, SUPER_WETH_STRATEGY, SUPER_WETH_STRATEGY)
        );
        vm.revertToState(snap);
    }

    /// @dev Builds and runs the hook, reporting whether the VAULT CALL succeeded. preExecute is asserted
    ///      separately because it is layout-only and must not depend on the adapter payload.
    function _tryHook(uint256 assets, bytes memory adapterData) internal returns (bool okCall) {
        Execution[] memory executions = hook.build(address(0), SUPER_WETH_STRATEGY, _hookData(assets, adapterData));
        vm.startPrank(SUPER_WETH_STRATEGY);
        (bool okPre,) = executions[0].target.call(executions[0].callData);
        assertTrue(okPre, "preExecute must not depend on adapterData");
        (okCall,) = executions[1].target.call(executions[1].callData);
        vm.stopPrank();
    }

    function _market() internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: WETH,
            collateralToken: WSTETH,
            oracle: MARKET_ORACLE,
            irm: MARKET_IRM,
            lltv: MARKET_LLTV
        });
    }

    /// @dev The SUP-21780 layout: oracle id at 0, yieldSource at 32, adapter at 52, assets at 72,
    ///      the flag at 104 and the raw adapterData tail at 105.
    function _hookData(uint256 assets, bytes memory adapterData) internal pure returns (bytes memory) {
        return bytes.concat(
            abi.encodePacked(bytes32(uint256(0xFEED))),
            abi.encodePacked(GAUNTLET_WETH_PRIME),
            abi.encodePacked(GAUNTLET_ADAPTER),
            abi.encode(assets),
            abi.encodePacked(uint8(0)),
            adapterData
        );
    }

    function _runHook(uint256 assets) internal {
        bytes memory data = _hookData(assets, abi.encode(_market()));
        Execution[] memory executions = hook.build(address(0), SUPER_WETH_STRATEGY, data);
        assertEq(executions.length, 3, "preExecute + vault call + postExecute");
        assertEq(executions[1].target, GAUNTLET_WETH_PRIME, "the vault is the call target");

        vm.startPrank(SUPER_WETH_STRATEGY);
        for (uint256 i; i < executions.length; ++i) {
            (bool ok,) = executions[i].target.call(executions[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }
}
