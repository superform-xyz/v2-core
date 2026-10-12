// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ApproveAndSwapBinanceHook } from "../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockBinanceRouter } from "../mocks/MockBinanceRouter.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";

/// @title BinanceHookHandler
/// @notice Plays the smart account + executor: opens a fresh hook context, builds, runs the six executions
///         atomically (as the account's ERC-7579 batch would) and resets the context, with the router
///         scripted into a random adversarial mode and a random fill each call.
/// @dev The router's pull and send amounts are randomised INDEPENDENTLY of the header `inputAmount` and
///      `outputMin`, so partial fills leave residual allowance for the trailing approve(0) to clear and
///      the `ALLOWANCE_NOT_CLEARED` assert to police. `swapTwice` runs two batches in one call so the
///      per-transaction accumulator is actually exercised (each handler call is its own transaction).
contract BinanceHookHandler is Test, InternalHelpers {
    ApproveAndSwapBinanceHook public hook;
    MockBinanceRouter public router;
    MockERC20 public usdt;
    MockERC20 public aaplb;
    MockERC20 public other;

    uint256 public constant CAP = 100_000e18;
    uint256 public constant OTHER_BALANCE = 777e18;
    uint256 internal constant MODES = 11;

    // ghost state
    uint256 public ghostCalls;
    uint256 public ghostSuccesses;
    uint256 public ghostFailures;
    uint256 public ghostHeaderTotal; // sum of header inputAmount over SUCCESSFUL runs
    uint256 public ghostSpentTotal; // USDT actually leaving the account over SUCCESSFUL runs
    uint256 public ghostPartialFills; // successful runs where the router pulled strictly less than approved
    uint256 public ghostViolations; // per-run post-conditions that failed (must stay 0)
    uint256 public ghostTwiceSecondWrong; // swapTwice: second batch outcome disagreed with the cap arithmetic

    constructor() {
        usdt = new MockERC20("USDT", "USDT", 18);
        aaplb = new MockERC20("AAPLB", "AAPLB", 18);
        other = new MockERC20("Other", "OTH", 18);
        router = new MockBinanceRouter();
        hook = new ApproveAndSwapBinanceHook(address(router), CAP);
        router.setHook(address(hook));
        other.mint(address(this), OTHER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                                ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev One randomised batch.
    function swap(
        uint256 amountIn,
        uint256 pullSeed,
        uint256 amountOut,
        uint256 minOut,
        uint8 modeSeed,
        uint256 adversarySeed
    )
        external
    {
        _run(amountIn, pullSeed, amountOut, minOut, modeSeed, adversarySeed);
    }

    /// @dev Two batches in ONE call (= one transaction): exercises the per-tx accumulator. The second batch
    ///      must fail iff the running sum would exceed CAP (given the first succeeded and the second is
    ///      otherwise valid). Both batches are honest so the only variable is the cap.
    function swapTwice(uint256 amountA, uint256 amountB) external {
        amountA = bound(amountA, 1, CAP);
        amountB = bound(amountB, 1, CAP);
        uint256 before = hook.txSpent(address(this));

        bool okA = _honest(amountA);
        if (!okA) return; // cap already consumed earlier in this tx; nothing to learn

        bool okB = _honest(amountB);
        bool shouldFail = before + amountA + amountB > CAP;
        if (okB == shouldFail) ghostTwiceSecondWrong++;
        if (hook.txSpent(address(this)) > CAP) ghostViolations++;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _honest(uint256 amountIn) internal returns (bool ok) {
        router.setMode(MockBinanceRouter.Mode.HONEST);
        router.configure(address(usdt), amountIn, address(aaplb), 1e18);
        _fund(amountIn, 1e18);
        bytes memory data = _createBinanceSwapHookData(
            address(usdt), address(aaplb), amountIn, 0, 1, false, address(router), hex"ad43f73d00"
        );
        try this.runAtomic(data) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _run(
        uint256 amountIn,
        uint256 pullSeed,
        uint256 amountOut,
        uint256 minOut,
        uint8 modeSeed,
        uint256 adversarySeed
    )
        internal
    {
        ghostCalls++;
        amountIn = bound(amountIn, 0, CAP * 2);
        amountOut = bound(amountOut, 0, 1000e18);
        minOut = bound(minOut, 0, 1000e18);
        MockBinanceRouter.Mode mode = MockBinanceRouter.Mode(modeSeed % MODES);

        // Pull strictly less than approved in PARTIAL_FILL; otherwise a random fraction [0, amountIn].
        uint256 pull = bound(pullSeed, 0, amountIn);
        if (mode == MockBinanceRouter.Mode.PARTIAL_FILL && amountIn != 0) pull = bound(pullSeed, 0, amountIn - 1);

        router.setMode(mode);
        router.configure(address(usdt), pull, address(aaplb), amountOut);
        router.setPartialPull(pull);
        router.setThirdParty(address(0xBEEF));
        router.setOverPull(amountIn + 1 + (adversarySeed % 1e18));
        router.setSecondToken(address(other), 1 + (adversarySeed % OTHER_BALANCE));
        router.setBurnAmount(adversarySeed % 10e18);
        router.setBombSize(adversarySeed % 8192);

        _fund(amountIn, amountOut);

        bytes memory data = _createBinanceSwapHookData(
            address(usdt), address(aaplb), amountIn, 0, minOut, false, address(router), hex"ad43f73d00"
        );

        uint256 usdtBefore = usdt.balanceOf(address(this));
        uint256 aaplbBefore = aaplb.balanceOf(address(this));

        try this.runAtomic(data) {
            ghostSuccesses++;
            ghostHeaderTotal += amountIn;
            uint256 spent = usdtBefore - usdt.balanceOf(address(this));
            ghostSpentTotal += spent;
            uint256 received = aaplb.balanceOf(address(this)) - aaplbBefore;
            if (spent < amountIn) ghostPartialFills++;

            // Per-run post-conditions (hook out-state is transient per tx, so check here)
            if (spent > amountIn) ghostViolations++;
            if (received < minOut) ghostViolations++;
            if (minOut == 0) ghostViolations++; // build must have rejected it
            if (amountIn == 0 || amountIn > CAP) ghostViolations++; // build must have rejected it
            if (hook.getOutAmount(address(this)) != received) ghostViolations++;
            if (hook.getOutToken(address(this)) != address(aaplb)) ghostViolations++;
            if (usdt.allowance(address(this), address(router)) != 0) ghostViolations++;
            if (mode == MockBinanceRouter.Mode.REENTER_SET_CONTEXT) ghostViolations++; // must never succeed
            if (mode == MockBinanceRouter.Mode.REENTER_SET_OUT_AMOUNT) ghostViolations++; // must never succeed
        } catch {
            ghostFailures++;
        }
    }

    function _fund(uint256 amountIn, uint256 amountOut) internal {
        uint256 bal = usdt.balanceOf(address(this));
        if (bal < amountIn) usdt.mint(address(this), amountIn - bal);
        aaplb.mint(address(router), amountOut);
    }

    /// @dev Mirrors SuperExecutor around one hook entry: fresh context → build → six executions → reset.
    ///      Any failure reverts the whole thing (batch atomicity), including the context bookkeeping.
    function runAtomic(bytes calldata data) external {
        require(msg.sender == address(this), "handler only");
        hook.setExecutionContext(address(this));
        Execution[] memory executions = hook.build(address(0), address(this), data);
        require(executions.length == 6, "shape");
        for (uint256 i = 0; i < executions.length; i++) {
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        hook.resetExecutionState(address(this));
    }
}

/// @title BinanceHookInvariant
/// @notice Stateful fuzz over randomised router behaviour and fills. Properties that must hold after ANY
///         sequence: no residual allowance (even after partial fills), input spent never exceeds the header
///         amount, tokens the hook never touched are never moved, every successful run satisfied its own
///         post-conditions, re-entering facets never succeed, and the per-tx cap arithmetic is exact.
contract BinanceHookInvariant is Test {
    BinanceHookHandler public handler;

    function setUp() public {
        handler = new BinanceHookHandler();
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = BinanceHookHandler.swap.selector;
        selectors[1] = BinanceHookHandler.swapTwice.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /// @dev D10: the router never keeps an allowance, on any token, after any sequence — including partial
    ///      fills where the router pulled less than approved (that is what the trailing approve(0) clears).
    function invariant_NoResidualAllowance() public view {
        assertEq(handler.usdt().allowance(address(handler), address(handler.router())), 0);
        assertEq(handler.other().allowance(address(handler), address(handler.router())), 0);
        assertEq(handler.aaplb().allowance(address(handler), address(handler.router())), 0);
    }

    /// @dev The load-bearing property: total input spent <= sum of header inputAmounts of successful runs.
    function invariant_SpentNeverExceedsHeader() public view {
        assertLe(handler.ghostSpentTotal(), handler.ghostHeaderTotal());
    }

    /// @dev A token the hook never approved cannot be moved by the router, in any mode.
    function invariant_UnrelatedTokenUntouched() public view {
        assertEq(handler.other().balanceOf(address(handler)), handler.OTHER_BALANCE());
    }

    /// @dev Every successful run met its own outputMin, cap and allowance post-conditions; reentry never wins.
    function invariant_NoPostConditionViolations() public view {
        assertEq(handler.ghostViolations(), 0);
    }

    /// @dev Per-tx cap arithmetic: in every two-batch call the second batch failed iff the sum exceeded CAP.
    function invariant_TxCapArithmeticExact() public view {
        assertEq(handler.ghostTwiceSecondWrong(), 0);
    }

    /// @dev Not vacuous: the fuzzer reaches successes, failures AND partial fills.
    function invariant_OutcomesReachable() public view {
        uint256 calls = handler.ghostCalls();
        if (calls >= 200) {
            assertGe(handler.ghostSuccesses() * 100, calls * 3, "fewer than 3% successful runs");
            assertGt(handler.ghostFailures(), 0, "no failing runs");
            assertGt(handler.ghostPartialFills(), 0, "no partial fills reached");
        }
    }
}
