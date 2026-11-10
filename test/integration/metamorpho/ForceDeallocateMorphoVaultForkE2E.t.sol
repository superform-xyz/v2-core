// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ForceDeallocateMorphoVaultHook } from
    "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../src/vendor/morpho/IMorphoMarketV1Adapter.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../src/vendor/morpho/IMorpho.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title ForceDeallocateMorphoVaultForkE2E
/// @notice Mainnet-fork e2e for `ForceDeallocateMorphoVaultHook` against a live Morpho Vault V2 that lists
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
contract ForceDeallocateMorphoVaultForkE2ETest is Test, Constants {
    /// @dev Pinned one block behind the tip at authoring time so the numbers below are reproducible.
    uint256 public constant FORK_BLOCK = 26_384_300;

    address public constant GAUNTLET_WETH_PRIME = 0x43fCd85E8D9D003D515f886891B7C742AC9f92da;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MORPHO_BLUE_ETHEREUM = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @dev Gauntlet's live rate was 1e13 WAD (0.1 bps) at the pinned block, far under this.
    uint256 public constant CAP = 0.0025e18;

    ForceDeallocateMorphoVaultHook internal hook;
    address internal account;

    struct Capacity {
        bytes32 marketId;
        uint256 position;
        uint256 liquidity;
        uint256 pullable;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceDeallocateMorphoVaultHook(MORPHO_BLUE_ETHEREUM, CAP);
        account = makeAddr("forceDeallocateVaultAccount");

        // Mint shares so the penalty burn has something to consume, and leave the deposit in idle.
        deal(WETH, account, 10 ether);
        vm.startPrank(account);
        IERC20(WETH).approve(GAUNTLET_WETH_PRIME, type(uint256).max);
        (bool ok,) = GAUNTLET_WETH_PRIME.call(abi.encodeWithSignature("deposit(uint256,address)", 5 ether, account));
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
    function test_SpansMarkets_IdleRisesByExactlyAssets() public {
        Capacity[] memory caps = _capacities();
        uint256 largest = _largestPullable(caps);
        assertGt(largest, 0, "something must be pullable");

        // One quarter past what the single biggest market can pay, so at least two calls are required.
        uint256 assets = largest + largest / 4;
        assertLe(assets, _totalPullable(caps), "fixture must stay inside total capacity");

        uint256 idleBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);

        uint256 pulls = _runHook(assets);

        assertGt(pulls, 1, "more than one forceDeallocate");
        assertLt(pulls, caps.length, "strictly fewer calls than the vault lists markets");
        assertEq(
            IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME) - idleBefore,
            assets,
            "idle rose by exactly the requested amount"
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

        uint256 idleBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 pulls = _runHook(assets);

        assertEq(pulls, 1, "exactly one call");
        assertEq(IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME) - idleBefore, assets, "exact amount, no more");
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

        uint256 idleBefore = IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME);
        uint256 pulls = _runHook(total);
        assertEq(pulls, _fundedCount(caps), "every funded market was pulled at its full capacity");
        assertEq(
            IERC20(WETH).balanceOf(GAUNTLET_WETH_PRIME) - idleBefore, total, "a full-position pull settled exactly"
        );
    }

    /// @dev Asking for more than every eligible market can pay must revert before anything is built, and
    ///      must report the live availability rather than a stale constant.
    function test_AboveTotalCapacityRevertsShortfallWithTheLiveAvailability() public {
        uint256 total = _totalPullable(_capacities());
        uint256 assets = total + 1 ether;

        vm.prank(account);
        hook.setExecutionContext(account);
        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, total, assets));
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

        ForceDeallocateMorphoVaultHook tight = new ForceDeallocateMorphoVaultHook(MORPHO_BLUE_ETHEREUM, live - 1);
        vm.prank(account);
        tight.setExecutionContext(account);
        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.PENALTY_ABOVE_CAP.selector, live, live - 1)
        );
        vm.prank(account);
        tight.build(address(0), account, _hookData(1 ether));
    }

    /// @dev `outAmount` is zero and `outToken` is the underlying, so nothing downstream can chain off this
    ///      hop. Asserted against the live vault because that is where a successor would read it.
    function test_PublishesNoChainableOutput() public {
        uint256 assets = _largestPullable(_capacities()) / 2;
        _runHook(assets);

        assertEq(hook.getOutAmount(account), 0, "outAmount is zero so a successor fails closed");
        assertEq(hook.getOutToken(account), WETH, "outToken is the vault underlying, not the vault");
    }

    /// @dev `inspect` commits the vault and nothing else, which is what lets a curator list a new market
    ///      without re-signing the leaf. The bound on that authority is the immutable cap, not the leaf.
    function test_InspectCommitsOnlyTheVault() public view {
        assertEq(hook.inspect(_hookData(1 ether)), abi.encodePacked(GAUNTLET_WETH_PRIME));
    }

    /// @dev PINS WHAT `forceDeallocate` ACTUALLY RETURNS, because the vendored interface's return-value
    ///      NAME is documentation that no code checks. Morpho pays the penalty with
    ///      `withdraw(penaltyAssets, address(this), onBehalf)` and returns that call's result, and ERC-4626
    ///      `withdraw` returns SHARES — so the returned number is the shares burned, not the
    ///      asset-denominated penalty. This hook ignores the return value entirely, which is exactly why
    ///      only a test can keep the interface's name honest.
    /// @dev Driven through the hook rather than by a direct vault call: `forceDeallocate` on this vault
    ///      reverts when invoked outside the hook's planning (the penalty leg has its own preconditions),
    ///      and the point here is the return value, not a second way to call it.
    function test_ForceDeallocateReturnsSharesBurnedNotPenaltyAssets() public {
        uint256 assets = _largestPullable(_capacities()) / 2;

        uint256 penaltyWad = IMorphoVaultV2(GAUNTLET_WETH_PRIME).forceDeallocatePenalty(
            IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0)
        );
        uint256 penaltyAssets = (assets * penaltyWad + 1e18 - 1) / 1e18;
        assertGt(penaltyAssets, 0, "the fixture must charge a non-zero penalty");

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, _hookData(assets));
        assertEq(all.length, 3, "one pull, so one return value to inspect");

        (bool okPre,) = all[0].target.call(all[0].callData);
        assertTrue(okPre, "preExecute");

        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);
        (bool okPull, bytes memory ret) = all[1].target.call(all[1].callData);
        assertTrue(okPull, "the pull itself");
        uint256 sharesBurned = sharesBefore - IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(account);

        (bool okPost,) = all[2].target.call(all[2].callData);
        assertTrue(okPost, "postExecute");
        hook.resetExecutionState(account);
        vm.stopPrank();

        assertEq(ret.length, 32, "forceDeallocate returns one word");
        uint256 returned = abi.decode(ret, (uint256));

        emit log_named_uint("returned     ", returned);
        emit log_named_uint("sharesBurned ", sharesBurned);
        emit log_named_uint("penaltyAssets", penaltyAssets);

        assertGt(sharesBurned, 0, "the penalty really was burned from the account");
        assertEq(returned, sharesBurned, "the return value is the SHARES burned, not the penalty assets");
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
        assertGe(executions.length, 3, "preExecute + at least one pull + postExecute");

        for (uint256 i; i < executions.length; ++i) {
            if (i != 0 && i != executions.length - 1) {
                assertEq(executions[i].target, GAUNTLET_WETH_PRIME, "pulls target the vault");
                assertEq(executions[i].value, 0, "pulls carry no value");
            }
            (bool ok,) = executions[i].target.call(executions[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i), " failed"));
        }

        hook.resetExecutionState(account);
        vm.stopPrank();
        return executions.length - 2;
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
