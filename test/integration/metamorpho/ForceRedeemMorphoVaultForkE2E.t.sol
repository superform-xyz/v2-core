// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { ForceRedeemMorphoVaultHook } from "../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import {
    ForceDeallocateMorphoVaultHook
} from "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../src/vendor/morpho/IMorphoMarketV1Adapter.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../src/vendor/morpho/IMorpho.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title ForceRedeemMorphoVaultForkE2E
/// @notice Mainnet-fork e2e for the SHARE-SIZED `ForceRedeemMorphoVaultHook` (SUP-21849) against Gauntlet WETH
///         Prime, a live Morpho Vault V2 listing several funded Morpho Blue markets.
/// @dev THE MARKET LIST IS READ, NEVER HARDCODED. Every expectation is derived from the chain at `FORK_BLOCK`.
/// @dev IDLE IS PUSHED OUT. The fixture obtains shares by depositing, and a deposit lands in idle, which the
///      new hook consumes FIRST: a depositor's exit would be a single penalty-free `redeem`. To exercise the
///      pulls the way a fully allocated vault would, `setUp` sets the vault's WETH balance down to a small
///      residual with `deal` after the deposit. The vault then books the difference as a loss on its next
///      accrual (share price falls once), which is a consistent state for both `build` and execution and is
///      exactly the shape this hook exists for.
contract ForceRedeemMorphoVaultForkE2ETest is Test, Constants {
    /// @dev Pinned one block behind the tip at authoring time so the numbers below are reproducible.
    uint256 public constant FORK_BLOCK = 26_384_300;

    address public constant GAUNTLET_WETH_PRIME = 0x43fCd85E8D9D003D515f886891B7C742AC9f92da;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MORPHO_BLUE_ETHEREUM = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @dev What `setUp` leaves in the vault's idle after the deposit.
    uint256 public constant RESIDUAL_IDLE = 1 ether;

    ForceRedeemMorphoVaultHook internal hook;
    address internal account;
    uint256 internal claimShares;

    struct Capacity {
        bytes32 marketId;
        uint256 position;
        uint256 liquidity;
        uint256 pullable;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_ETHEREUM);
        account = makeAddr("forceRedeemAccount");

        // A claim worth about half the reachable capacity, so a FULL exit is feasible from the markets.
        uint256 claim = _totalPullable(_capacities()) / 2;
        deal(WETH, account, claim);
        vm.startPrank(account);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool ok,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", claim, account));
        require(ok, "deposit failed");
        vm.stopPrank();
        claimShares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        require(claimShares > 0, "deposit minted no shares");

        // Push idle out: the deposit (and whatever idle the vault already held) would otherwise cover the
        // redeem without a single pull.
        deal(WETH, GAUNTLET_WETH_PRIME, RESIDUAL_IDLE);
    }

    /*//////////////////////////////////////////////////////////////
                           LIVE PRECONDITIONS
    //////////////////////////////////////////////////////////////*/

    function test_LiveShape_OneAdapterSeveralFundedMarkets_IdlePushedOut() public view {
        IMorphoVaultV2 vault = IMorphoVaultV2(GAUNTLET_WETH_PRIME);
        assertEq(vault.asset(), WETH, "WETH vault");
        assertEq(vault.adaptersLength(), 1, "fixture assumes a single adapter; _capacities() reads adapters(0)");
        assertGt(_fundedCount(_capacities()), 1, "at least two markets with capacity");
        assertEq(IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME), RESIDUAL_IDLE, "idle is the residual only");
        assertGt(vault.previewRedeem(claimShares), RESIDUAL_IDLE, "the claim cannot be paid from idle alone");
    }

    /*//////////////////////////////////////////////////////////////
                               THE CORE E2E
    //////////////////////////////////////////////////////////////*/

    /// @dev The ticket's headline: a FULL-BALANCE exit ends at zero shares and pays exactly `previewAssetsOut`.
    function test_FullBalanceExit_LeavesZeroShares_AndPaysPreviewAssetsOut() public {
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, account, claimShares);
        assertGt(quoted, 0);

        uint256 under0 = IERC20(WETH).balanceOf(account);
        uint256 pulls = _runHook(claimShares);
        assertGt(pulls, 0, "a fully allocated vault needs at least one pull");

        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account), 0, "a full-balance input ends at zero shares");
        assertEq(IERC20(WETH).balanceOf(account) - under0, quoted, "the underlying received equals previewAssetsOut");
        assertEq(hook.getOutAmount(account), quoted, "outAmount is the measured underlying delta");
        assertEq(hook.getOutToken(account), WETH);
        assertEq(hook.usedShares(), claimShares, "usedShares spans the whole call, penalty burns included");
    }

    /// @dev Idle after the pulls is exactly `residual + X - assetsOut`: the penalty transfer is to the vault
    ///      itself and the redeem is paid from the deallocated amount.
    function test_IdleAccounting_ResidualPlusSourcedMinusPaid() public {
        uint256 shares = claimShares / 3;
        Execution[] memory all = _build(shares);
        uint256 sourced;
        for (uint256 i = 1; i + 2 < all.length; ++i) {
            (,, uint256 x,) = _decodePull(all[i]);
            sourced += x;
        }
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, account, shares);
        assertLe(quoted, RESIDUAL_IDLE + sourced, "covered");
        _runHook(shares);
        assertEq(
            IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME),
            RESIDUAL_IDLE + sourced - quoted,
            "idle = residual + deallocated - paid"
        );
    }

    /// @dev Per-pull burns match the stepper: the returned `penaltyShares` of each `forceDeallocate` equal
    ///      `mulDivUp(mulDivUp(pull, rate, 1e18), N, D)` with N and D stepped from `accrueInterestView`.
    function test_PerPullBurns_MatchTheSteppedRate() public {
        uint256 shares = claimShares; // full exit
        Execution[] memory all = _build(shares);
        assertGe(all.length, 4, "at least one pull");

        IMorphoVaultV2 vault = IMorphoVaultV2(GAUNTLET_WETH_PRIME);
        (uint256 ta, uint256 pf, uint256 mf) = vault.accrueInterestView();
        uint256 n = vault.totalSupply() + pf + mf + vault.virtualShares();
        uint256 d = ta + 1;
        uint256 rate = vault.forceDeallocatePenalty(vault.adapters(0));
        uint256 predictedP;

        vm.startPrank(account);
        hook.setExecutionContext(account);
        for (uint256 i; i < all.length; ++i) {
            (bool ok, bytes memory ret) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("leg ", vm.toString(i)));
            if (i != 0 && i + 2 < all.length) {
                (,, uint256 x,) = _decodePull(all[i]);
                uint256 pa = _mulDivUp(x, rate, 1e18);
                uint256 ps = _mulDivUp(pa, n, d);
                n -= ps;
                d -= pa;
                predictedP += ps;
                assertEq(abi.decode(ret, (uint256)), ps, "forceDeallocate burned exactly the stepped shares");
            }
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        (uint256 redeemed,,) = _decodeRedeem(all[all.length - 2]);
        assertEq(redeemed, shares - predictedP, "the redeem leg was S minus the stepped burns");
        assertEq(vault.balanceOf(account), 0);
    }

    /// @dev An input that one market covers alone produces exactly one pull and does NOT drain it.
    function test_SmallInput_OnePull_NotDrained() public {
        Capacity[] memory caps = _capacities();
        uint256 largest = _largestPullable(caps);
        // shares whose redeem is well inside the largest market
        uint256 shares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).previewWithdraw(largest / 4);
        uint256 positions0 = _positions();
        uint256 pulls = _runHook(shares);
        assertEq(pulls, 1, "exactly one forceDeallocate");
        assertLt(positions0 - _positions(), largest, "the market was not drained");
        assertEq(IERC20(WETH).balanceOf(account), hook.getOutAmount(account));
    }

    /// @dev Idle that already covers the redeem: no pull, a single `redeem(S)`, received == previewRedeem(S).
    function test_IdleCovers_SingleRedeem_NoPenalty() public {
        uint256 shares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).previewWithdraw(RESIDUAL_IDLE / 2);
        Execution[] memory all = _build(shares);
        assertEq(all.length, 3, "pre, redeem, post");
        (uint256 s,,) = _decodeRedeem(all[1]);
        assertEq(s, shares);
        uint256 quoted = IMorphoVaultV2(GAUNTLET_WETH_PRIME).previewRedeem(shares);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        _runHook(shares);
        assertEq(hook.getOutAmount(account), quoted);
        assertEq(sharesBefore - IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account), shares, "no penalty burned");
    }

    /*//////////////////////////////////////////////////////////////
                         REFUSALS, LIVE NUMBERS
    //////////////////////////////////////////////////////////////*/

    /// @dev A claim larger than every eligible market plus idle can pay reverts SHORTFALL before anything runs.
    function test_Shortfall_WhenTheMarketsCannotFundTheRedeem() public {
        address whale = makeAddr("whale");
        uint256 big = _totalPullable(_capacities()) * 3;
        deal(WETH, whale, big);
        vm.startPrank(whale);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool ok,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", big, whale));
        require(ok, "whale deposit");
        vm.stopPrank();
        deal(WETH, GAUNTLET_WETH_PRIME, RESIDUAL_IDLE); // push the whale's idle out too
        uint256 whaleShares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(whale);

        vm.prank(whale);
        hook.setExecutionContext(whale);
        vm.expectPartialRevert(ForceRedeemMorphoVaultHook.SHORTFALL.selector);
        vm.prank(whale);
        hook.build(address(0), whale, _hookData(whaleShares));
        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(whale), whaleShares, "no shares burned");
    }

    /// @dev SUP-21849: `minAssetsOut` is the on-chain bound. One wei above the live quote is refused at build;
    ///      a floor equal to the quote builds, runs and is met exactly on the real vault.
    function test_MinAssetsOut_RefusedAboveTheQuote_MetAtTheQuote() public {
        uint256 shares = claimShares / 3;
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, account, shares);
        assertGt(quoted, 0);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quoted, quoted + 1)
        );
        hook.build(address(0), account, _hookDataWithMin(shares, quoted + 1));
        vm.stopPrank();

        uint256 before = IERC20(WETH).balanceOf(account);
        _runHookWithData(_hookDataWithMin(shares, quoted));
        assertEq(IERC20(WETH).balanceOf(account) - before, quoted, "the floor set at the quote is met exactly");
    }

    function test_UsePrevHookAmount_IsRefused() public {
        bytes memory flagged =
            abi.encodePacked(bytes32(uint256(0xFEED)), GAUNTLET_WETH_PRIME, uint256(1), true, uint256(0));
        vm.expectRevert(ForceRedeemMorphoVaultHook.USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED.selector);
        hook.build(address(0), account, flagged);
    }

    function test_InsufficientShares_IsRefusedBeforeAnyLegRuns() public {
        uint256 positions0 = _positions();
        vm.prank(account);
        hook.setExecutionContext(account);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, claimShares, claimShares + 1
            )
        );
        vm.prank(account);
        hook.build(address(0), account, _hookData(claimShares + 1));
        assertEq(_positions(), positions0, "no market was touched");
    }

    function test_InspectCommitsOnlyTheVault() public view {
        assertEq(hook.inspect(_hookData(1 ether)), abi.encodePacked(GAUNTLET_WETH_PRIME));
    }

    /*//////////////////////////////////////////////////////////////
                      WHY THIS HOOK EXISTS, DEMONSTRATED
    //////////////////////////////////////////////////////////////*/

    /// @dev The deallocate-only sibling leaves the freed idle for a bystander; this hook pays the account
    ///      inside the same call, so a bystander finds nothing beyond what was there before.
    function test_ForceRedeem_LeavesNoWindowForABystander() public {
        uint256 shares = claimShares / 2;
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, account, shares);
        uint256 payerBefore = IERC20(WETH).balanceOf(account);
        _runHook(shares);
        assertEq(IERC20(WETH).balanceOf(account) - payerBefore, quoted, "the payer, not a bystander, got the assets");
        assertLe(
            IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME),
            RESIDUAL_IDLE + 2,
            "no freed idle beyond the residual (and solver rounding) is left lying around"
        );
    }

    /// @dev The penalty is paid ON TOP: the account burns strictly more shares than `previewWithdraw` of what
    ///      it received would have cost, and every other holder's claim does not fall.
    function test_PenaltyIsPaidOnTop_OtherHoldersNotHarmed() public {
        address other = makeAddr("otherHolder");
        deal(WETH, other, 50 ether);
        vm.startPrank(other);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 50 ether, other));
        require(okDep, "other deposit");
        vm.stopPrank();
        deal(WETH, GAUNTLET_WETH_PRIME, RESIDUAL_IDLE);
        uint256 otherShares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(other);
        // accrue the pushed-out idle as a loss once, so the comparison below is apples to apples
        IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(1);
        uint256 otherClaim0 = IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(otherShares);

        uint256 shares = claimShares / 2;
        uint256 received = _runHookReturningDelta(shares);
        uint256 plainCost = IMorphoVaultV2(GAUNTLET_WETH_PRIME).previewWithdraw(received);
        assertGt(hook.usedShares(), plainCost, "a forced exit costs more shares than an unforced one");

        assertGe(
            IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(otherShares), otherClaim0, "a bystander's claim did not fall"
        );
    }

    /// @dev Two exits back to back: the second plans against what the first left, and `outAmount` is the
    ///      delta of THIS exit rather than the balance.
    function test_SequentialExitsEachSettleExactly() public {
        uint256 shares = claimShares / 4;
        uint256 r1 = _runHookReturningDelta(shares);
        uint256 quote2 = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, account, shares);
        uint256 r2 = _runHookReturningDelta(shares);
        assertEq(r2, quote2, "second exit == its own quote");
        assertEq(hook.getOutAmount(account), r2);
        assertGt(r1, 0);
        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account), claimShares - 2 * shares);
    }

    /// @dev `build` runs on chain inside the UserOp; a real multi-pull exit's cost is recorded.
    function test_RealMultiPullExitGasIsRecorded() public {
        vm.startPrank(account);
        hook.setExecutionContext(account);
        uint256 g = gasleft();
        Execution[] memory all = hook.build(address(0), account, _hookData(claimShares));
        uint256 buildGas = g - gasleft();
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "leg");
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        emit log_named_uint("pulls                  ", all.length - 3);
        emit log_named_uint("build gas (live state) ", buildGas);
        assertLt(buildGas, 2 ** 24, "build alone must fit under the per-transaction gas cap");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev No floor unless a test sets one.
    function _hookData(uint256 shares) internal pure returns (bytes memory) {
        return _hookDataWithMin(shares, 0);
    }

    function _hookDataWithMin(uint256 shares, uint256 minAssetsOut) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(0xFEED)), GAUNTLET_WETH_PRIME, shares, false, minAssetsOut);
    }

    function _build(uint256 shares) internal view returns (Execution[] memory) {
        return hook.build(address(0), account, _hookData(shares));
    }

    /// @dev Mirrors `SuperExecutorBase._processHook`: set the context, build, run every execution as the
    ///      account, then reset.
    /// @return pulls The number of `forceDeallocate` calls: the executions between pre and the redeem
    function _runHook(uint256 shares) internal returns (uint256 pulls) {
        return _runHookWithData(_hookData(shares));
    }

    function _runHookWithData(bytes memory data) internal returns (uint256 pulls) {
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory executions = hook.build(address(0), account, data);
        assertGe(executions.length, 3, "preExecute + the redeem + postExecute");
        for (uint256 i; i < executions.length; ++i) {
            if (i != 0 && i != executions.length - 1) {
                assertEq(executions[i].target, GAUNTLET_WETH_PRIME, "pulls and the redeem target the vault");
                assertEq(executions[i].value, 0, "no leg carries value");
            }
            (bool ok, bytes memory ret) = executions[i].target.call(executions[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        return executions.length - 3;
    }

    function _runHookReturningDelta(uint256 shares) internal returns (uint256 delta) {
        uint256 before = IERC20(WETH).balanceOf(account);
        _runHook(shares);
        delta = IERC20(WETH).balanceOf(account) - before;
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

    /// @dev Reproduces the hook's own discovery over the live vault.
    function _capacities() internal view returns (Capacity[] memory caps) {
        IMorphoVaultV2 vault = IMorphoVaultV2(GAUNTLET_WETH_PRIME);
        IMorphoMarketV1Adapter adapter = IMorphoMarketV1Adapter(vault.adapters(0));
        address morpho = adapter.morpho();
        uint256 n = adapter.marketIdsLength();
        caps = new Capacity[](n);
        for (uint256 i; i < n; ++i) {
            bytes32 id = adapter.marketIds(i);
            (uint128 supply,, uint128 borrow,,,) = IMorphoStaticTyping(morpho).market(Id.wrap(id));
            uint256 liquidity = supply > borrow ? uint256(supply - borrow) : 0;
            uint256 position = adapter.expectedSupplyAssets(id);
            caps[i] = Capacity(id, position, liquidity, position < liquidity ? position : liquidity);
        }
    }

    function _fundedCount(Capacity[] memory caps) internal pure returns (uint256 n) {
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable != 0) ++n;
        }
    }

    function _positions() internal view returns (uint256 total) {
        Capacity[] memory caps = _capacities();
        for (uint256 i; i < caps.length; ++i) {
            total += caps[i].position;
        }
    }

    function _largestPullable(Capacity[] memory caps) internal pure returns (uint256 largest) {
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable > largest) largest = caps[i].pullable;
        }
    }

    function _totalPullable(Capacity[] memory caps) internal pure returns (uint256 total) {
        for (uint256 i; i < caps.length; ++i) {
            total += caps[i].pullable;
        }
    }
}
