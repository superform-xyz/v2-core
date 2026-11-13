// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import { ApproveAndSwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { IRedSnwapper } from "../../../src/vendor/sushiswap/IRedSnwapper.sol";
import { IRouteProcessor7 } from "../../../src/vendor/sushiswap/IRouteProcessor7.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { SushiKatanaFixtures } from "./SushiKatanaFixtures.sol";

/// @dev Reproduces the VERIFIED RedSnwapper semantics: snapshot the recipient's output, pull `amountIn` from
///      msg.sender to the executor, call the executor with value, enforce the floor. ONE test-only tightening: the real
///      contract never compares `msg.value` with `amountIn` (it just forwards the value); this mock requires equality
///      so a hook that forwarded the wrong value would fail loudly here.
contract MockRedSnwapper {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error MinimalOutputBalanceViolation(address tokenOut, uint256 amountOut);

    uint256 public lastAmountIn;
    uint256 public lastValue;
    address public lastExecutor;

    function snwap(
        address tokenIn,
        uint256 amountIn,
        address recipient,
        address tokenOut,
        uint256 amountOutMin,
        address executor,
        bytes calldata executorData
    )
        external
        payable
        returns (uint256 amountOut)
    {
        uint256 before = _bal(tokenOut, recipient);
        if (tokenIn != NATIVE) {
            require(msg.value == 0, "unexpected value");
            require(amountIn > 0, "balance mode unsupported in mock");
            IERC20(tokenIn).transferFrom(msg.sender, executor, amountIn);
        } else {
            require(msg.value == amountIn, "bad value");
        }
        lastAmountIn = amountIn;
        lastValue = msg.value;
        lastExecutor = executor;
        (bool ok, bytes memory ret) = executor.call{ value: msg.value }(executorData);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(ret, 32), mload(ret))
            }
        }
        amountOut = _bal(tokenOut, recipient) - before;
        if (amountOut < amountOutMin) revert MinimalOutputBalanceViolation(tokenOut, amountOut);
    }

    function _bal(address t, address who) private view returns (uint256) {
        return t == NATIVE ? who.balance : IERC20(t).balanceOf(who);
    }
}

/// @dev Reproduces the EMPIRICAL executor behaviour from the Katana probe: swaps its own pre-funded balance (route is
///      ignored), output = input * rate / 1e18 minted/paid to `to`; with `takeSurplus` the recipient receives at most
///      `amountOutMin` and the executor keeps the rest (the cap semantics). Without `takeSurplus`, `amountOutMin` is a
///      hard floor (RouteProcessor6 lineage).
contract MockRouteProcessor {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public rate = 1e18; // out per in, 1e18 = 1:1
    uint256 public lastInputUsed;
    uint256 public surplusKept;
    uint256 public lastValue;

    function setRate(uint256 r) external {
        rate = r;
    }

    function processRoute(
        address tokenIn,
        uint256,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory,
        bool takeSurplus,
        uint32
    )
        external
        payable
        returns (uint256 amountOut)
    {
        lastValue = msg.value;
        uint256 input = tokenIn == NATIVE ? address(this).balance : IERC20(tokenIn).balanceOf(address(this));
        lastInputUsed = input;
        uint256 produced = input * rate / 1e18;
        if (tokenIn != NATIVE) {
            // consume the input (burn by sending to a sink)
            IERC20(tokenIn).transfer(address(0xdead), input);
        }
        amountOut = produced;
        if (takeSurplus && produced > amountOutMin) {
            surplusKept += produced - amountOutMin;
            amountOut = amountOutMin;
        } else if (!takeSurplus) {
            require(produced >= amountOutMin, "RP: min");
        }
        if (tokenOut == NATIVE) {
            (bool s,) = to.call{ value: amountOut }("");
            require(s, "native out");
        } else {
            MockERC20(tokenOut).mint(to, amountOut);
        }
    }

    receive() external payable { }
}

contract SushiSwapHookE2ETest is Test, SushiKatanaFixtures {
    MockRedSnwapper private rs;
    MockRouteProcessor private rp;
    SwapSushiSwapHook private swapHook;
    ApproveAndSwapSushiSwapHook private approveHook;
    MockHook private prevHook;

    address private account;
    MockERC20 private inToken;
    MockERC20 private outToken;

    uint256 private constant IN = 1000e18;
    uint256 private constant QUOTE = 1000e18; // 1:1 mock rate
    uint256 private constant OUTER_MIN = 990e18; // Sushi floor
    uint256 private constant HEADER_MIN = 995e18; // standardized floor (tighter than Sushi's)

    receive() external payable { }

    function setUp() public {
        account = address(this);
        rs = new MockRedSnwapper();
        rp = new MockRouteProcessor();
        vm.deal(address(rp), 10_000 ether); // native-out liquidity (quotes are 1000e18)
        inToken = new MockERC20("Input", "IN", 18);
        outToken = new MockERC20("Output", "OUT", 18);
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inToken));
        prevHook.setOutToken(address(inToken));

        swapHook = new SwapSushiSwapHook(address(rs), address(rp), NATIVE);
        approveHook = new ApproveAndSwapSushiSwapHook(address(rs), address(rp), NATIVE);
    }

    function _executeAll(Execution[] memory ex) internal {
        for (uint256 i = 0; i < ex.length; i++) {
            (bool ok, bytes memory ret) = ex[i].target.call{ value: ex[i].value }(ex[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
    }

    /// @dev External wrapper so vm.expectRevert binds to the whole batch.
    function executeAllExternal(Execution[] memory ex) external {
        _executeAll(ex);
    }

    /*//////////////////////////////////////////////////////////////
                               HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_E2E_ApproveAndSwap_ERC20_Fixed() public {
        inToken.mint(account, IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));

        _executeAll(approveHook.build(address(prevHook), account, data));

        assertEq(inToken.balanceOf(account), 0, "input spent exactly");
        assertEq(outToken.balanceOf(account), QUOTE, "output received");
        assertEq(inToken.allowance(account, address(rs)), 0, "allowance reset");
        assertEq(rs.lastAmountIn(), IN);
        assertEq(rp.lastInputUsed(), IN, "executor swapped exactly the pulled amount");
        assertEq(approveHook.getOutAmount(account), QUOTE);
        assertEq(approveHook.getOutToken(account), address(outToken));
        _assertNoDustOnHooks();
    }

    function test_E2E_PlainSwap_ERC20_ExternalApproval() public {
        inToken.mint(account, IN);
        inToken.approve(address(rs), IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));

        _executeAll(swapHook.build(address(prevHook), account, data));

        assertEq(inToken.balanceOf(account), 0);
        assertEq(outToken.balanceOf(account), QUOTE);
        assertEq(swapHook.getOutAmount(account), QUOTE);
        _assertNoDustOnHooks();
    }

    function test_E2E_NativeInput_BothVariants() public {
        vm.deal(account, 2 * IN);
        bytes memory tx_ = _tx(NATIVE, address(outToken), IN, OUTER_MIN, QUOTE, account);
        bytes memory data = _data(NATIVE, address(outToken), IN, HEADER_MIN, false, tx_);

        uint256 ethBefore = account.balance;
        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(ethBefore - account.balance, IN, "value forwarded == amount");
        assertEq(rs.lastValue(), IN);
        assertEq(rp.lastValue(), IN);
        assertEq(outToken.balanceOf(account), QUOTE);

        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(outToken.balanceOf(account), 2 * QUOTE);
        _assertNoDustOnHooks();
    }

    function test_E2E_NativeOutput_BothVariants() public {
        inToken.mint(account, 2 * IN);
        bytes memory tx_ = _tx(address(inToken), NATIVE, IN, OUTER_MIN, QUOTE, account);
        bytes memory data = _data(address(inToken), NATIVE, IN, HEADER_MIN, false, tx_);

        uint256 ethBefore = account.balance;
        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(account.balance - ethBefore, QUOTE, "native delivered");
        assertEq(approveHook.getOutAmount(account), QUOTE);
        assertEq(approveHook.getOutToken(account), NATIVE);

        inToken.approve(address(rs), IN);
        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(account.balance - ethBefore, 2 * QUOTE);
        _assertNoDustOnHooks();
    }

    function test_E2E_UsePrevHookAmount_Down95_BothVariants() public {
        uint256 actual = IN * 95 / 100;
        inToken.mint(account, 2 * actual);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, true, _txErc20(IN));
        prevHook.setOutAmount(actual, account);

        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(inToken.balanceOf(account), actual, "spent exactly the actual amount");
        assertEq(rp.lastInputUsed(), actual);
        assertEq(outToken.balanceOf(account), actual, "1:1 at the scaled size (cap == scaled quote)");
        assertEq(approveHook.getOutAmount(account), actual);

        inToken.approve(address(rs), actual);
        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(inToken.balanceOf(account), 0);
        assertEq(outToken.balanceOf(account), 2 * actual);
        _assertNoDustOnHooks();
    }

    function test_E2E_UsePrevHookAmount_Up105_BothVariants() public {
        uint256 actual = IN * 105 / 100;
        inToken.mint(account, 2 * actual);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, true, _txErc20(IN));
        prevHook.setOutAmount(actual, account);

        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(inToken.balanceOf(account), actual);
        assertEq(outToken.balanceOf(account), actual, "cap scaled up with the input");
        assertEq(inToken.allowance(account, address(rs)), 0);

        inToken.approve(address(rs), actual);
        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(outToken.balanceOf(account), 2 * actual);
        _assertNoDustOnHooks();
    }

    function test_E2E_UsePrevHookAmount_NativeInput_ValueScaled() public {
        uint256 actual = IN * 9 / 10;
        vm.deal(account, actual);
        prevHook.setOutAmount(actual, account);
        prevHook.setOutToken(NATIVE);
        bytes memory tx_ = _tx(NATIVE, address(outToken), IN, OUTER_MIN, QUOTE, account);
        bytes memory data = _data(NATIVE, address(outToken), IN, HEADER_MIN, true, tx_);

        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(account.balance, 0, "exactly the scaled value was forwarded");
        assertEq(rp.lastValue(), actual);
        assertEq(outToken.balanceOf(account), actual);
    }

    /*//////////////////////////////////////////////////////////////
                                SECURITY
    //////////////////////////////////////////////////////////////*/

    /// @notice The executor pays at most the nested cap. Because the hook raises the cap with the input, a 150%
    ///         upsize yields 150% of the quoted output. Had only the outer head been patched the cap would have
    ///         stayed at QUOTE and the executor would have kept the extra 50%.
    function test_E2E_Security_InnerCapScaled_AccountGetsProportionalOutput() public {
        uint256 actual = IN * 150 / 100;
        inToken.mint(account, actual);
        prevHook.setOutAmount(actual, account);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, true, _txErc20(IN));

        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(outToken.balanceOf(account), QUOTE * 150 / 100, "proportional output reached the account");
        assertEq(rp.surplusKept(), 0, "no surplus leaked to the executor");
    }

    /// @notice Characterisation of the cap: with a better rate the executor keeps everything above the (scaled) cap.
    function test_E2E_Security_CapSemantics_SurplusStaysWithExecutor() public {
        rp.setRate(1.2e18);
        inToken.mint(account, IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));
        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(outToken.balanceOf(account), QUOTE, "capped at the quote");
        assertEq(rp.surplusKept(), QUOTE * 20 / 100);
    }

    /// @notice Sushi's own floor passes (outer min 990) but the standardized header floor (995) does not: the
    ///         hook's independent check reverts the whole batch.
    function test_E2E_Security_HookFloor_RevertsBelowScaledHeaderMin() public {
        rp.setRate(0.992e18); // 992 out: above Sushi's 990 floor, below the header's 995
        inToken.mint(account, IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        vm.expectRevert(
            abi.encodeWithSelector(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 992e18, HEADER_MIN)
        );
        this.executeAllExternal(ex);
        assertEq(inToken.balanceOf(account), IN, "nothing moved (batch reverted atomically)");
    }

    function test_E2E_Security_HookFloor_ScaledOnChainedPath() public {
        // 50% downsize: required = ceil(995e18 * 0.5) = 497.5e18; rate 0.994 -> 497e18 received -> revert
        uint256 actual = IN / 2;
        rp.setRate(0.994e18);
        inToken.mint(account, actual);
        prevHook.setOutAmount(actual, account);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, true, _txErc20(IN));
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        vm.expectRevert(
            abi.encodeWithSelector(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 497e18, 497.5e18)
        );
        this.executeAllExternal(ex);
    }

    function test_E2E_Security_RedSnwapperFloor_Propagates() public {
        rp.setRate(0.5e18);
        inToken.mint(account, IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        vm.expectRevert(
            abi.encodeWithSelector(MockRedSnwapper.MinimalOutputBalanceViolation.selector, address(outToken), 500e18)
        );
        this.executeAllExternal(ex);
    }

    function test_E2E_Security_OutputAccountingIsDelta() public {
        outToken.mint(account, 777e18); // pre-existing output must not count
        inToken.mint(account, IN);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, _txErc20(IN));
        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(approveHook.getOutAmount(account), QUOTE);
    }

    function test_E2E_Security_InputSubstitution_Blocked() public {
        MockERC20 other = new MockERC20("Other", "OTH", 18);
        inToken.mint(account, IN);
        bytes memory tx_ = _tx(address(other), address(outToken), IN, OUTER_MIN, QUOTE, account);
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, tx_);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
        assertEq(inToken.balanceOf(account), IN);
    }

    function test_E2E_Security_ExecutorSubstitution_Blocked() public {
        MockRouteProcessor rogue = new MockRouteProcessor();
        bytes memory inner = _inner(address(inToken), address(outToken), IN, QUOTE, account);
        bytes memory tx_ = abi.encodeWithSelector(
            IRedSnwapper.snwap.selector,
            address(inToken),
            IN,
            account,
            address(outToken),
            OUTER_MIN,
            address(rogue),
            inner
        );
        bytes memory data = _data(address(inToken), address(outToken), IN, HEADER_MIN, false, tx_);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INVALID_EXECUTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assertNoDustOnHooks() private view {
        assertEq(inToken.balanceOf(address(swapHook)), 0);
        assertEq(outToken.balanceOf(address(swapHook)), 0);
        assertEq(address(swapHook).balance, 0);
        assertEq(inToken.balanceOf(address(approveHook)), 0);
        assertEq(outToken.balanceOf(address(approveHook)), 0);
        assertEq(address(approveHook).balance, 0);
        assertEq(inToken.balanceOf(address(rs)), 0, "RedSnwapper holds nothing");
    }

    function _inner(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 innerMin,
        address to
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IRouteProcessor7.processRoute.selector,
            tokenIn,
            amountIn,
            tokenOut,
            innerMin,
            to,
            hex"01aa",
            true,
            uint32(0)
        );
    }

    function _tx(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 outerMin,
        uint256 innerMin,
        address recipient
    )
        private
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IRedSnwapper.snwap.selector,
            tokenIn,
            amountIn,
            recipient,
            tokenOut,
            outerMin,
            address(rp),
            _inner(tokenIn, tokenOut, amountIn, innerMin, recipient)
        );
    }

    function _txErc20(uint256 amountIn) private view returns (bytes memory) {
        return _tx(address(inToken), address(outToken), amountIn, OUTER_MIN, QUOTE, account);
    }

    function _data(
        address in_,
        address out_,
        uint256 amount,
        uint256 outputMin,
        bool flag,
        bytes memory txData
    )
        private
        pure
        returns (bytes memory)
    {
        return _hookData(in_, out_, amount, QUOTE, outputMin, flag, txData);
    }
}
