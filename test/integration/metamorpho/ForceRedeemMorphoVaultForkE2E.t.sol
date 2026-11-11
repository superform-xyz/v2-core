// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ForceRedeemMorphoVaultHook } from
    "../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import { ForceDeallocateMorphoVaultHook } from
    "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoVaultHook.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../src/vendor/morpho/IMorphoMarketV1Adapter.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../src/vendor/morpho/IMorpho.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title ForceRedeemMorphoVaultForkE2E
/// @notice Mainnet-fork e2e for `ForceRedeemMorphoVaultHook` against a live Morpho Vault V2 that lists
///         more than one funded Morpho Blue market
/// @dev THE MARKET LIST IS READ, NEVER HARDCODED. Gauntlet WETH Prime listed one adapter and three markets
///      on 2026-11-10, two liquidity-bound and one position-bound, but a curator can add,
///      remove or re-weight markets under the timelock, and the three market ids are deliberately absent
///      from this file. Every expectation below is derived from the chain at `FORK_BLOCK`, so bumping the
///      block moves the numbers without invalidating the assertions.
/// @dev SHARES ARE MINTED BY DEPOSITING, not by pranking a whale. `forceDeallocate` burns penalty shares
///      from `onBehalf`, so the executing account must hold some; depositing is permissionless, keeps the
///      test independent of any particular holder's balance, and the deposit lands in idle where it is
///      measured before the pulls begin.
contract ForceRedeemMorphoVaultForkE2ETest is Test, Constants {
    /// @dev Pinned one block behind the tip at authoring time so the numbers below are reproducible.
    uint256 public constant FORK_BLOCK = 26_384_300;

    address public constant GAUNTLET_WETH_PRIME = 0x43fCd85E8D9D003D515f886891B7C742AC9f92da;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MORPHO_BLUE_ETHEREUM = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @dev Gauntlet's live rate was 1e13 WAD (0.1 bps) at the pinned block, far under this.
    uint256 public constant CAP = 0.0025e18;
    /// @dev Assets to shave off Morpho's documented full-exit size so the `+ penalisedCount` share slack
    ///      is covered. One pull => one share-wei of slack; at pps ~1.02 a few wei of assets more than cover it.
    uint256 public constant SLACK_ASSETS = 10;

    ForceRedeemMorphoVaultHook internal hook;
    address internal account;

    struct Capacity {
        bytes32 marketId;
        uint256 position;
        uint256 liquidity;
        uint256 pullable;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_ETHEREUM, CAP);
        account = makeAddr("forceDeallocateVaultAccount");

        // Mint a claim PROPORTIONATE TO WHAT THESE TESTS ASK FOR, not merely enough to pay a penalty.
        // `_requireSolvent` bounds the whole exit — `previewWithdraw(assets + penalty)` — because a leaf
        // pins only the vault and `assets` is resizable, so an account may not force out more than its own
        // claim. A 5 WETH fixture asking for thousands was exercising the weaker bound that review finding
        // F1 removed; sizing the deposit to the vault's reachable capacity is what makes these tests
        // represent a real exit rather than the hole.
        uint256 reachable = _totalPullable(_capacities());
        uint256 claim = reachable + reachable / 10;
        deal(WETH, account, claim);
        vm.startPrank(account);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool ok,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", claim, account));
        require(ok, "deposit failed");
        vm.stopPrank();
        require(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account) > 0, "deposit minted no shares");
    }

    /*//////////////////////////////////////////////////////////////
                           LIVE PRECONDITIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Everything downstream depends on this vault still being the multi-market shape the ticket
    ///      describes. If a curator reshapes it, this test is the one that explains why the others moved.
    function test_LiveShape_OneAdapterSeveralFundedMarkets() public view {
        IMorphoVaultV2 vault = IMorphoVaultV2(GAUNTLET_WETH_PRIME);
        assertEq(vault.asset(), WETH, "WETH vault");
        // `_capacities()` reads adapters(0) only, so a second adapter would make it under-report silently.
        assertEq(vault.adaptersLength(), 1, "fixture assumes a single adapter; _capacities() reads adapters(0)");

        Capacity[] memory caps = _capacities();
        assertGt(caps.length, 1, "more than one funded market, else this file proves nothing");

        uint256 funded;
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable != 0) ++funded;
        }
        assertGt(funded, 1, "at least two markets with capacity");
    }

    /// @dev Both bounds of `min(position, liquidity)` were live at the pinned block — two markets were
    ///      liquidity-bound and one position-bound — which is what makes this vault a good fixture.
    function test_LiveShape_BothCapacityBoundsAreExercised() public view {
        Capacity[] memory caps = _capacities();
        bool liquidityBound;
        bool positionBound;
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable == 0) continue;
            if (caps[i].liquidity < caps[i].position) liquidityBound = true;
            if (caps[i].position <= caps[i].liquidity) positionBound = true;
        }
        assertTrue(liquidityBound, "a market bounded by market liquidity");
        assertTrue(positionBound, "a market bounded by the adapter's position");
    }

    /*//////////////////////////////////////////////////////////////
                            THE CORE E2E
    //////////////////////////////////////////////////////////////*/

    /// @dev The ticket's headline acceptance: an amount ONE market cannot cover produces more than one
    ///      call, fewer calls than the vault lists markets, and raises the vault's underlying balance by
    ///      EXACTLY `assets` — not `assets * (1 - penalty)`. The penalty is a separate share burn.
    function test_SpansMarkets_PositionsFallByExactlyAssetsAndIdleIsRestored() public {
        Capacity[] memory caps = _capacities();
        uint256 largest = _largestPullable(caps);
        assertGt(largest, 0, "something must be pullable");

        // One quarter past what the single biggest market can pay, so at least two calls are required.
        uint256 assets = largest + largest / 4;
        assertLe(assets, _totalPullable(caps), "fixture must stay inside total capacity");

        uint256 positionsBefore = _positions();
        uint256 underlyingBefore = IERC20(WETH).balanceOf(account);
        uint256 idleBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);

        uint256 pulls = _runHook(assets);
        assertEq(IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME), idleBefore, "the vault's idle ends where it started");

        assertGt(pulls, 1, "more than one forceDeallocate");
        assertLt(pulls, caps.length, "strictly fewer calls than the vault lists markets");
        // NOT an idle-delta assertion. This hook withdraws in the same call, so the vault's idle ends
        // where it started; and because the fixture must deposit to obtain a claim, idle is large enough
        // to have served the withdraw on its own. The ADAPTER POSITIONS falling by exactly `assets` is the
        // assertion with teeth — it is what proves the deallocates did the work.
        assertEq(positionsBefore - _positions(), assets, "adapter positions fell by exactly the request");
        assertEq(
            IERC20(WETH).balanceOf(account) - underlyingBefore, assets, "the account received exactly the request"
        );
        assertLt(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account),
            sharesBefore,
            "the penalty was paid out of the account's shares"
        );
    }

    /// @dev A request one market covers alone must produce exactly one call, and must NOT drain it. The
    ///      penalty is charged on the amount pulled, so emptying a market to free a small exit overpays.
    function test_SingleMarketRequest_EmitsOneCallAndDoesNotDrainIt() public {
        uint256 largest = _largestPullable(_capacities());
        uint256 assets = largest / 2;

        uint256 positionsBefore = _positions();
        uint256 underlyingBefore = IERC20(WETH).balanceOf(account);
        uint256 pulls = _runHook(assets);

        assertEq(pulls, 1, "exactly one forceDeallocate");
        assertEq(positionsBefore - _positions(), assets, "exact amount pulled from the markets, no more");
        assertEq(IERC20(WETH).balanceOf(account) - underlyingBefore, assets, "and the account received it");
    }

    /// @dev F4, the one premise that cannot be settled from source: is pulling a market's FULL
    ///      `expectedSupplyAssets` safe? `morpho.withdraw` burns `toSharesUp(assets)` from the adapter's
    ///      position, so it only holds if `expectedSupplyAssets` is `toAssetsDown` of the adapter's shares,
    ///      giving `toSharesUp(toAssetsDown(s)) <= s`. If this ever fails, the fix is `position - 1` applied
    ///      to the POSITION bound only, never to liquidity.
    /// @dev IT MUST REQUEST THE WHOLE CAPACITY, NOT JUST THE POSITION-BOUND MARKET'S SHARE OF IT. An earlier
    ///      version asked for exactly that market's position and asserted a single pull — which passed
    ///      without ever touching it, because the fill sorts capacity-descending and covered the request
    ///      from the largest market instead. Asking for the total forces every candidate to be taken at
    ///      exactly its capacity, so the position-bound market IS pulled at exactly `expectedSupplyAssets`.
    function test_F4_PullingAFullPositionBoundMarketDoesNotRevert() public {
        Capacity[] memory caps = _capacities();

        uint256 positionBound;
        bytes32 positionBoundId;
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable != 0 && caps[i].position <= caps[i].liquidity) {
                positionBound = caps[i].position;
                positionBoundId = caps[i].marketId;
                break;
            }
        }
        assertGt(positionBound, 0, "no position-bound market at this block; F4 cannot be exercised");

        uint256 total = _totalPullable(caps);

        // Read the PLAN before executing it: the pulls drain the markets, so a `build` afterwards sees no
        // capacity at all. (That mistake showed up as SHORTFALL(0, total) rather than a wrong number.)
        assertEq(
            _pullAmountFor(positionBoundId, total),
            positionBound,
            "the position-bound market is planned at exactly its full position"
        );

        uint256 positionsBefore = _positions();
        uint256 underlyingBefore = IERC20(WETH).balanceOf(account);
        uint256 pulls = _runHook(total);
        assertEq(pulls, _fundedCount(caps), "every funded market was pulled at its full capacity");
        assertEq(positionsBefore - _positions(), total, "a full-position pull settled exactly");
        assertEq(IERC20(WETH).balanceOf(account) - underlyingBefore, total, "and reached the account");
    }

    /// @dev Asking for more than every eligible market can pay must revert before anything is built, and
    ///      must report the live availability rather than a stale constant.
    function test_AboveTotalCapacityRevertsShortfallWithTheLiveAvailability() public {
        uint256 total = _totalPullable(_capacities());
        uint256 assets = total + 1 ether;

        vm.prank(account);
        hook.setExecutionContext(account);
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, total, assets));
        vm.prank(account);
        hook.build(address(0), account, _hookData(assets));
    }

    /// @dev A cap below the live rate removes the only adapter, so the fill has nothing to draw on and the
    ///      failure is attributed to the cap rather than to liquidity.
    function test_CapBelowTheLiveRateBlamesTheCap() public {
        uint256 live = IMorphoVaultV2(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0)
        );
        assertGt(live, 1, "live rate must be above the tightest cap we can set");

        ForceRedeemMorphoVaultHook tight = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_ETHEREUM, live - 1);
        vm.prank(account);
        tight.setExecutionContext(account);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.PENALTY_ABOVE_CAP.selector, live, live - 1)
        );
        vm.prank(account);
        tight.build(address(0), account, _hookData(1 ether));
    }

    /// @dev THE OUTPUT FORWARDS, the reverse of the deallocate-only sibling. That hook publishes
    ///      `outAmount = 0` so a `usePrevHookAmount` successor fails closed, because the account receives
    ///      nothing there. This hook pays the account, so it publishes what the account actually received
    ///      — measured against the live vault, which is where a successor would read it.
    function test_PublishesTheUnderlyingItPaidOut() public {
        uint256 assets = _largestPullable(_capacities()) / 2;
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        _runHook(assets);

        assertEq(hook.getOutAmount(account), assets, "outAmount is the underlying the account received");
        assertEq(hook.getOutToken(account), WETH, "outToken is the vault underlying, not the vault");
        uint256 burned = sharesBefore - IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        assertEq(hook.usedShares(), burned, "usedShares spans the whole call, penalty burns included");
        assertGt(burned, 0, "and shares really were given up");
    }

    /// @dev `inspect` commits the vault and nothing else, which is what lets a curator list a new market
    ///      without re-signing the leaf. The bound on that authority is the immutable cap, not the leaf.
    function test_InspectCommitsOnlyTheVault() public view {
        assertEq(hook.inspect(_hookData(1 ether)), abi.encodePacked(GAUNTLET_WETH_PRIME));
    }

    /*//////////////////////////////////////////////////////////////
                  WHY THIS HOOK EXISTS, DEMONSTRATED
    //////////////////////////////////////////////////////////////*/

    /// @dev THE WHOLE JUSTIFICATION FOR THIS HOOK, AS AN EXECUTABLE PROOF RATHER THAN A COMMENT.
    ///      `forceDeallocate` moves underlying into the vault's OWN balance and nothing records it for the
    ///      caller, so between a deallocate transaction and a later redeem anyone holding shares can take
    ///      it — while the deallocating account has already burned its penalty. Here a bystander does
    ///      exactly that: after the deallocate-only sibling runs, the bystander withdraws the freed
    ///      liquidity and the paying account ends up with nothing but the penalty.
    function test_DeallocateOnly_LetsABystanderTakeTheFreedLiquidity() public {
        ForceDeallocateMorphoVaultHook deallocateOnly =
            new ForceDeallocateMorphoVaultHook(MORPHO_BLUE_ETHEREUM, CAP);

        // A bystander with a claim of its own, who performs no deallocation and pays no penalty.
        address bystander = makeAddr("bystander");
        deal(WETH, bystander, 3000 ether);
        vm.startPrank(bystander);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) =
            GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 3000 ether, bystander));
        require(okDep, "bystander deposit");
        vm.stopPrank();

        uint256 assets = 1000 ether;
        uint256 idleBeforeDeallocate = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 payerUnderlyingBefore = IERC20(WETH).balanceOf(account);
        uint256 payerSharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);

        // The paying account deallocates, and only deallocates.
        vm.startPrank(account);
        deallocateOnly.setExecutionContext(account);
        Execution[] memory all = deallocateOnly.build(address(0), account, _hookData(assets));
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "deallocate leg");
        }
        deallocateOnly.resetExecutionState(account);
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(account), payerUnderlyingBefore, "the payer received nothing yet");
        assertLt(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account),
            payerSharesBefore,
            "but has already burned the penalty"
        );

        // A separate transaction. The bystander takes the liquidity the payer freed.
        // The fixture's own deposits also sit in idle, so "a 1000 WETH withdraw succeeded" would prove
        // nothing on its own. The load-bearing check is that idle returns EXACTLY to its pre-deallocate
        // level: the bystander consumed precisely the amount the payer's pulls had added.
        uint256 idleAfterDeallocate = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        assertEq(idleAfterDeallocate - idleBeforeDeallocate, assets, "the pulls added exactly assets to idle");

        uint256 bystanderBefore = IERC20(WETH).balanceOf(bystander);
        vm.prank(bystander);
        (bool stolen,) = GAUNTLET_WETH_PRIME.call(abi.encodeCall(IERC4626.withdraw, (assets, bystander, bystander)));
        assertTrue(stolen, "a bystander can claim idle it did not free");
        assertEq(IERC20(WETH).balanceOf(bystander) - bystanderBefore, assets, "and takes exactly that amount");
        assertEq(
            IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME),
            idleBeforeDeallocate,
            "leaving idle exactly where it was before the payer did anything"
        );
    }

    /// @dev THE SAME SETUP, THROUGH THIS HOOK: there is no window at all. The account receives the
    ///      underlying inside the same call, and the vault's idle is already back to baseline by the time
    ///      any bystander could act.
    function test_ForceRedeem_LeavesNoWindowForABystander() public {
        address bystander = makeAddr("bystander2");
        deal(WETH, bystander, 3000 ether);
        vm.startPrank(bystander);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) =
            GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 3000 ether, bystander));
        require(okDep, "bystander deposit");
        vm.stopPrank();

        uint256 assets = 1000 ether;
        uint256 idleBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 payerBefore = IERC20(WETH).balanceOf(account);

        _runHook(assets);

        assertEq(IERC20(WETH).balanceOf(account) - payerBefore, assets, "the payer, not a bystander, got the assets");
        assertEq(IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME), idleBefore, "no freed idle is left lying around");
    }

    /*//////////////////////////////////////////////////////////////
                        FURTHER LIVE BEHAVIOUR
    //////////////////////////////////////////////////////////////*/

    /// @dev The penalty is paid ON TOP of the exit, out of shares, so the account gives up strictly more
    ///      share value than a plain withdraw of `assets` would have cost.
    function test_PenaltyIsPaidOnTopOfTheExit() public {
        uint256 assets = _largestPullable(_capacities()) / 2;
        uint256 plainCost = IMorphoVaultV2(GAUNTLET_WETH_PRIME).previewWithdraw(assets);

        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        _runHook(assets);
        uint256 burned = sharesBefore - IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);

        assertGt(burned, plainCost, "a forced exit costs more shares than an unforced one");
        assertEq(hook.usedShares(), burned, "and usedShares reports the whole cost");
    }

    /// @dev `usePrevHookAmount` end to end: a previous hop's output sizes both the pulls and the withdraw.
    function test_UsePrevHookAmountEndToEnd() public {
        uint256 assets = _largestPullable(_capacities()) / 4;

        ForceRedeemMorphoVaultHook source = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_ETHEREUM, CAP);
        vm.prank(account);
        source.setExecutionContext(account);

        // Drive the first hook so it publishes a real outAmount, then size the second from it.
        uint256 before = IERC20(WETH).balanceOf(account);
        vm.startPrank(account);
        Execution[] memory first = source.build(address(0), account, _hookData(assets));
        for (uint256 i; i < first.length; ++i) {
            (bool ok,) = first[i].target.call(first[i].callData);
            assertTrue(ok, "first exit");
        }
        vm.stopPrank();
        assertEq(source.getOutAmount(account), assets, "the first hook published what it paid out");

        bytes memory chained =
            abi.encodePacked(bytes32(uint256(0xFEED)), GAUNTLET_WETH_PRIME, uint256(1 wei), true);
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory second = hook.build(address(source), account, chained);
        for (uint256 i; i < second.length; ++i) {
            (bool ok,) = second[i].target.call(second[i].callData);
            assertTrue(ok, "chained exit");
        }
        hook.resetExecutionState(account);
        vm.stopPrank();

        assertEq(
            IERC20(WETH).balanceOf(account) - before, assets * 2, "both exits paid out, the second sized from the first"
        );
    }

    /// @dev A claim too small for the whole exit is refused before anything executes, so the account keeps
    ///      its shares rather than burning a penalty for an exit that cannot complete.
    function test_ClaimTooSmallIsRefusedBeforeAnyLegRuns() public {
        address poor = makeAddr("poor");
        deal(WETH, poor, 1 ether);
        vm.startPrank(poor);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 1 ether, poor));
        require(okDep, "poor deposit");
        vm.stopPrank();

        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(poor);
        uint256 positionsBefore = _positions();

        vm.prank(poor);
        hook.setExecutionContext(poor);
        vm.expectPartialRevert(ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector);
        vm.prank(poor);
        hook.build(address(0), poor, _hookData(500 ether));

        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(poor), sharesBefore, "no shares burned");
        assertEq(_positions(), positionsBefore, "and no market was touched");
    }

    /// @dev Two exits back to back against live state, so the second plans against what the first left.
    function test_SequentialExitsEachSettleExactly() public {
        uint256 assets = _largestPullable(_capacities()) / 4;
        uint256 before = IERC20(WETH).balanceOf(account);

        _runHook(assets);
        uint256 afterFirst = IERC20(WETH).balanceOf(account);
        assertEq(afterFirst - before, assets, "first exit");

        uint256 positionsMid = _positions();
        _runHook(assets);
        assertEq(IERC20(WETH).balanceOf(account) - afterFirst, assets, "second exit");
        assertEq(positionsMid - _positions(), assets, "and it came out of the markets again");
        // The account already held `assets` of WETH from the first exit, so an absolute-balance bug would
        // report 2x here. This is the live-chain twin of the pre-funded unit test.
        assertEq(hook.getOutAmount(account), assets, "outAmount is the delta of THIS exit, not the balance");
    }

    /// @dev `build` runs on chain inside the UserOp, so a real multi-pull exit's cost is a live constraint.
    ///      Recorded rather than asserted tightly, so a future regression is visible in the diff.
    function test_RealMultiPullExitGasIsRecorded() public {
        uint256 assets = _largestPullable(_capacities()) + 1 ether; // forces a second market

        vm.startPrank(account);
        hook.setExecutionContext(account);
        uint256 g = gasleft();
        Execution[] memory all = hook.build(address(0), account, _hookData(assets));
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
                      THE FULL EXIT, AND WHO BEARS THE PENALTY
    //////////////////////////////////////////////////////////////*/

    /// @dev THE SUP-21689 SHAPE: Morpho documents the full-exit size as `claim / (1 + penalty)`. Sized that
    ///      way, one call empties the account's position — the shares left are rounding dust.
    /// @dev FINDING FOR THE PLANNER: at EXACTLY that size the hook reverts `INSUFFICIENT_SHARES` by one
    ///      share-wei, because the `+ penalisedCount` slack is tight for worst-case rounding and the exact
    ///      full-exit figure sits right on it (measured: held 1468749516632606538274, required ...275).
    ///      SUP-21689 must therefore size a hair under Morpho's figure; `SLACK_ASSETS` is that hair here.
    function test_FullExitAtMorphosDocumentedSizeEmptiesThePosition() public {
        // A payer whose whole claim fits inside the vault's reachable capacity.
        address exiter = makeAddr("exiter");
        uint256 claimIn = 1500 ether;
        deal(WETH, exiter, claimIn);
        vm.startPrank(exiter);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", claimIn, exiter));
        require(okDep, "exiter deposit");
        vm.stopPrank();

        uint256 shares0 = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(exiter);
        uint256 claim = IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(shares0);
        uint256 penaltyWad = IMorphoVaultV2(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0)
        );
        uint256 assets = (claim * 1e18) / (1e18 + penaltyWad) - SLACK_ASSETS;

        uint256 under0 = IERC20(WETH).balanceOf(exiter);
        vm.startPrank(exiter);
        hook.setExecutionContext(exiter);
        Execution[] memory all = hook.build(address(0), exiter, _hookData(assets));
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("leg ", vm.toString(i)));
        }
        hook.resetExecutionState(exiter);
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(exiter) - under0, assets, "received the full-exit amount");
        uint256 dust = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(exiter);
        assertLt(dust, shares0 / 1e6, "what remains is rounding dust, not a position");
    }

    /// @dev WHO PAYS: the penalty leaves the exiter's shares and STAYS IN THE VAULT, so every other holder's
    ///      claim is worth at least what it was. The economic invariant behind "accrues to other holders".
    function test_OtherHoldersAreNotHarmedByAForcedExit() public {
        address other = makeAddr("otherHolder");
        deal(WETH, other, 2000 ether);
        vm.startPrank(other);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool okDep,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 2000 ether, other));
        require(okDep, "other deposit");
        vm.stopPrank();

        uint256 otherShares = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(other);
        uint256 otherClaim0 = IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(otherShares);

        _runHook(_largestPullable(_capacities()) / 2);

        uint256 otherClaim1 = IERC4626(GAUNTLET_WETH_PRIME).convertToAssets(otherShares);
        assertGe(otherClaim1, otherClaim0, "a bystander's claim did not fall");
        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(other), otherShares, "and its shares are untouched");
    }

    /// @dev HOW THE PENALTY MOVES, precisely. Vault V2 charges it with `withdraw(penaltyAssets, vault,
    ///      onBehalf)`: the exiter's shares burn AND `_totalAssets` is decremented like any withdraw, so
    ///      `totalAssets` falls by `assets + penalty`. But that withdraw's receiver is the vault itself — a
    ///      self-transfer — and this hook's own withdraw returns the pulled idle to the exiter, so the
    ///      vault's TOKEN balance is unchanged end to end. The penalty's underlying therefore stays behind
    ///      as surplus above `_totalAssets`, which the next `accrueInterest` recognises (rate-capped by
    ///      `maxRate`) for the remaining holders. "Accrues to other holders" is true, but delayed, not
    ///      instantaneous.
    function test_PenaltyLeavesTotalAssetsButNotTheVaultsBalance() public {
        uint256 assets = _largestPullable(_capacities()) / 2; // covered by one market: one pull, one penalty
        uint256 penaltyWad = IMorphoVaultV2(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0)
        );
        uint256 penalty = (assets * penaltyWad + 1e18 - 1) / 1e18;
        uint256 total0 = IERC4626(GAUNTLET_WETH_PRIME).totalAssets();
        uint256 bal0 = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 real0 = bal0 + _positions(); // what the vault actually controls: idle + market positions

        uint256 pulls = _runHook(assets);
        assertEq(pulls, 1, "fixture: a single penalised pull");

        uint256 total1 = IERC4626(GAUNTLET_WETH_PRIME).totalAssets();
        uint256 bal1 = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 real1 = bal1 + _positions();
        assertEq(total0 - total1, assets + penalty, "accounting: assets + penalty left totalAssets");
        assertEq(bal1, bal0, "tokens: idle was restored by the withdraw, net zero");
        assertEq(real0 - real1, assets, "real assets fell by only the exit");
        assertEq((real1 - total1) - (real0 - total0), penalty, "so the penalty sits above totalAssets as surplus");
    }

    /// @dev The cap comparison is `>`, so a hook deployed with its cap EQUAL to the live rate still works —
    ///      pinned on live state, not just the mock.
    function test_CapEqualToTheLiveRateIsStillEligible() public {
        uint256 live = IMorphoVaultV2(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0)
        );
        ForceRedeemMorphoVaultHook atCap = new ForceRedeemMorphoVaultHook(MORPHO_BLUE_ETHEREUM, live);
        uint256 assets = _largestPullable(_capacities()) / 4;

        uint256 under0 = IERC20(WETH).balanceOf(account);
        vm.startPrank(account);
        atCap.setExecutionContext(account);
        Execution[] memory all = atCap.build(address(0), account, _hookData(assets));
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "leg");
        }
        atCap.resetExecutionState(account);
        vm.stopPrank();
        assertEq(IERC20(WETH).balanceOf(account) - under0, assets, "an adapter exactly at the cap is used");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _hookData(uint256 assets) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(0xFEED)), GAUNTLET_WETH_PRIME, assets, false);
    }

    /// @dev Mirrors `SuperExecutorBase._processHook`: set the context, build, run every execution as the
    ///      account, then reset. `setExecutionContext` is what makes the account `lastCaller`, which
    ///      `resetExecutionState`'s `onlyLastCaller` requires, and the reset clears the one-shot pre/post
    ///      mutexes so a test can invoke the hook more than once.
    /// @return pulls The number of `forceDeallocate` calls, i.e. the executions between pre and post
    function _runHook(uint256 assets) internal returns (uint256 pulls) {
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory executions = hook.build(address(0), account, _hookData(assets));
        assertGe(executions.length, 4, "preExecute + at least one pull + the withdraw + postExecute");

        for (uint256 i; i < executions.length; ++i) {
            if (i != 0 && i != executions.length - 1) {
                assertEq(executions[i].target, GAUNTLET_WETH_PRIME, "pulls and the withdraw target the vault");
                assertEq(executions[i].value, 0, "no leg carries value");
            }
            (bool ok,) = executions[i].target.call(executions[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i), " failed"));
        }

        hook.resetExecutionState(account);
        vm.stopPrank();
        return executions.length - 3;
    }

    /// @dev Reproduces the hook's own discovery over the live vault, so expectations are derived from the
    ///      chain rather than restated from the ticket.
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

    /// @dev Rebuilds the plan and returns the amount it assigns to `marketId`, by matching the emitted
    ///      `MarketParams` back to its id. Matching on the PARAMS rather than on call order is what stops
    ///      this from passing against whichever market the sort happened to pick.
    function _pullAmountFor(bytes32 marketId, uint256 assets) internal view returns (uint256) {
        Execution[] memory all = hook.build(address(0), account, _hookData(assets));
        for (uint256 i = 1; i + 1 < all.length; ++i) {
            bytes memory raw = all[i].callData;
            bytes memory args = new bytes(raw.length - 4);
            for (uint256 b; b < args.length; ++b) {
                args[b] = raw[b + 4];
            }
            (, bytes memory inner, uint256 amount,) = abi.decode(args, (address, bytes, uint256, address));
            MarketParams memory p = abi.decode(inner, (MarketParams));
            if (keccak256(abi.encode(p)) == marketId) return amount;
        }
        return 0;
    }

    function _paramsOf(bytes32 marketId) internal view returns (MarketParams memory p) {
        (p.loanToken, p.collateralToken, p.oracle, p.irm, p.lltv) =
            IMorphoStaticTyping(MORPHO_BLUE_ETHEREUM).idToMarketParams(Id.wrap(marketId));
    }

    function _fundedCount(Capacity[] memory caps) internal pure returns (uint256 n) {
        for (uint256 i; i < caps.length; ++i) {
            if (caps[i].pullable != 0) ++n;
        }
    }

    /// @dev Total underlying the vault's markets hold, via the adapter's own accounting. The one measure
    ///      that cannot be satisfied by the fixture's own deposit sitting in idle.
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
