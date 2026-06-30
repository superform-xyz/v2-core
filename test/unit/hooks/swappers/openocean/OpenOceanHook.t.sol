// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    ApproveAndSwapOpenOceanHook
} from "../../../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { SwapOpenOceanHook } from "../../../../../src/hooks/swappers/openocean/SwapOpenOceanHook.sol";
import { OpenOceanDynamicAmountUpdater } from "../../../../../src/libraries/OpenOceanDynamicAmountUpdater.sol";
import { IOpenOceanCaller } from "../../../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { ISuperHook, ISuperHookInflowOutflow } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";

contract OpenOceanDynamicAmountUpdaterHarness {
    function updateTxDataAmounts(
        bytes memory txData_,
        address expectedReferrer_,
        address expectedReceiver_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        external
        pure
        returns (bytes memory, address, address)
    {
        return OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            txData_, expectedReferrer_, expectedReceiver_, newAmount_, originalAmount_
        );
    }
}

contract MockOpenOceanRouter is IOpenOceanExchange {
    uint256 public lastAmount;
    uint256 public lastMinReturnAmount;
    uint256 public lastMsgValue;

    function swap(
        IOpenOceanCaller,
        SwapDescription calldata desc,
        IOpenOceanCaller.CallDescription[] calldata
    )
        external
        payable
        override
        returns (uint256)
    {
        lastAmount = desc.amount;
        lastMinReturnAmount = desc.minReturnAmount;
        lastMsgValue = msg.value;

        address receiver = desc.dstReceiver == address(0) ? msg.sender : desc.dstReceiver;
        if (address(desc.srcToken) == address(0)) {
            require(msg.value == desc.amount, "invalid msg.value");
        } else {
            IERC20(address(desc.srcToken)).transferFrom(msg.sender, address(this), desc.amount);
        }

        MockERC20(address(desc.dstToken)).mint(receiver, desc.amount);
        return desc.amount;
    }
}

contract OpenOceanHookTest is Test {
    function _singleAmount(uint256 amt) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = amt;
    }


    uint256 private constant DISTRIBUTION_SENTINEL = (uint256(1) << 128) + 1;
    uint256 private constant COLLECT_SLIPPAGE_HIGH_BITS = uint256(0x32) << 240;

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes4 private constant UNISWAP_V3_SWAP_SELECTOR = 0xe5b07cdb;
    bytes4 private constant SINGLE_DISTRIBUTION_CALL_SELECTOR = 0x9f865422;
    bytes4 private constant COLLECT_SLIPPAGE_SELECTOR = 0x8a6a1e85;
    bytes4 private constant SAFE_TRANSFER_SELECTOR = 0xd1660f99;
    bytes4 private constant DEPOSIT_SELECTOR = 0xd0e30db0;
    bytes4 private constant WITHDRAW_SELECTOR = 0x2e1a7d4d;
    bytes4 private constant MAKE_CALL_SELECTOR = 0x0c7e1209;

    OpenOceanDynamicAmountUpdaterHarness private harness;
    SwapOpenOceanHook private swapHook;
    ApproveAndSwapOpenOceanHook private approveAndSwapHook;
    MockOpenOceanRouter private mockRouter;
    MockHook private prevHook;

    address private router;
    address private caller;
    address private referrer;
    address private account;
    address private inputToken;
    address private outputToken;
    address private pool;

    function setUp() public {
        harness = new OpenOceanDynamicAmountUpdaterHarness();
        mockRouter = new MockOpenOceanRouter();
        router = address(mockRouter);
        caller = makeAddr("openOceanCaller");
        referrer = makeAddr("openOceanReferrer");
        account = address(this);
        pool = makeAddr("sparkDexV4Pool");

        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);
        swapHook = new SwapOpenOceanHook(router, referrer, NATIVE);
        approveAndSwapHook = new ApproveAndSwapOpenOceanHook(router, referrer, NATIVE);
    }

    function test_SwapHook_InspectReturnsDstReceiverOnly() public {
        address dstReceiver = makeAddr("openOceanDstReceiver");
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData =
            _buildTxDataWithReceiver(caller, referrer, inputToken, outputToken, 1000, 900, 950, 0, calls, dstReceiver);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);

        bytes memory argsEncoded = swapHook.inspect(data);

        assertEq(argsEncoded, abi.encodePacked(dstReceiver));
        assertEq(argsEncoded.length, 20);
    }

    function test_ApproveAndSwapHook_InspectReturnsDstReceiverOnly() public {
        address dstReceiver = makeAddr("approveAndSwapOpenOceanDstReceiver");
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData =
            _buildTxDataWithReceiver(caller, referrer, inputToken, outputToken, 1000, 900, 950, 0, calls, dstReceiver);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);

        bytes memory argsEncoded = approveAndSwapHook.inspect(data);

        assertEq(argsEncoded, abi.encodePacked(dstReceiver));
        assertEq(argsEncoded.length, 20);
    }

    function test_Updater_ScalesDescFieldsAndLeavesErc20CallsUntouched() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);

        (bytes memory updated,,) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(updated);

        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);

        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_Updater_ScalesNativeValuesAndLeavesNativeCallDataUntouched() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);

        (bytes memory updated,,) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1001);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(updated);

        assertEq(address(desc.srcToken), address(0));
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, uint256(900) * 2000 / 1001);
        assertEq(desc.guaranteedAmount, uint256(950) * 2000 / 1001);
        assertEq(calls[0].value + calls[2].value, 2000);
        assertEq(calls[0].value, 399);
        assertEq(calls[2].value, 1601);

        _assertCallDataUnchanged(originalCalls, calls);
    }

    function test_Updater_LeavesZeroValueNativeCallsUntouched() public {
        bytes memory txData = _buildNativeZeroValueTxData(1000, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);

        (bytes memory updated,,) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(updated);

        assertEq(address(desc.srcToken), address(0));
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);
        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_SwapHook_UsesPrevAmountAndScalesCallData() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[1].callData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, router);
        assertEq(executions[1].value, 0);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);
        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_SwapHook_UpdatesNativeExecutionValue() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _swapHookData(outputToken, 1001, 1001, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, uint256(900) * 2000 / 1001);
        assertEq(desc.guaranteedAmount, uint256(950) * 2000 / 1001);
        assertEq(_sumCallValues(calls), 2000);
        assertEq(calls[0].value, 399);
        assertEq(calls[2].value, 1601);
        _assertCallDataUnchanged(originalCalls, calls);
    }

    function test_SwapHook_UsesPrevAmountWithZeroValueNativeCalls() public {
        bytes memory txData = _buildNativeZeroValueTxData(1000, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _swapHookData(outputToken, 1000, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);
        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_SwapHook_DerivesNativeValueFromInputAmount() public view {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        bytes memory data = _swapHookData(outputToken, 2000, 1001, 900, false, txData);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 1001);
        assertEq(desc.amount, 1001);
    }

    function test_SwapHook_DerivesZeroValueForErc20Input() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 1000, 1000, 900, false, txData);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 0);
        assertEq(desc.amount, 1000);
    }

    function test_SwapHook_UsesPrevAmountAndExecutesNativeSwap() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        bytes memory data = _swapHookData(outputToken, 1001, 1001, 900, true, txData);

        vm.deal(account, 2000);
        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        _execute(executions);

        assertEq(mockRouter.lastAmount(), 2000);
        assertEq(mockRouter.lastMinReturnAmount(), uint256(900) * 2000 / 1001);
        assertEq(mockRouter.lastMsgValue(), 2000);
        assertEq(IERC20(outputToken).balanceOf(account), 2000);
        assertEq(swapHook.getOutAmount(account), 2000);
    }

    function test_RevertWhenSwapHookInputTokenEqualsOutputToken() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _swapHookData(inputToken, 0, 1000, 900, false, txData);

        vm.expectRevert(SwapOpenOceanHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(0), account, data);
    }

    function test_ApproveAndSwapHook_UsesPrevAmountForApprovalAndSwap() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        (, uint256 approvalAmount) = abi.decode(_sliceAfterSelector(executions[2].callData), (address, uint256));
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[3].callData);

        assertEq(executions.length, 6);
        assertEq(executions[1].target, inputToken);
        assertEq(executions[2].target, inputToken);
        assertEq(executions[3].target, router);
        assertEq(approvalAmount, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);
        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_ApproveAndSwapHook_UsesPrevAmountAndExecutesSwap() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, true, txData);

        MockERC20(inputToken).mint(account, 2000);
        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        _execute(executions);

        assertEq(mockRouter.lastAmount(), 2000);
        assertEq(mockRouter.lastMinReturnAmount(), 1800);
        assertEq(IERC20(inputToken).balanceOf(account), 0);
        assertEq(IERC20(inputToken).allowance(account, router), 0);
        assertEq(IERC20(outputToken).balanceOf(account), 2000);
        assertEq(approveAndSwapHook.getOutAmount(account), 2000);
    }

    function test_ApproveAndSwapHook_UsesNativePathAndPrevAmount() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _approveAndSwapHookData(address(0), outputToken, 1001, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[1].callData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, router);
        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, uint256(900) * 2000 / 1001);
        assertEq(desc.guaranteedAmount, uint256(950) * 2000 / 1001);
        assertEq(_sumCallValues(calls), 2000);
        assertEq(calls[0].value, 399);
        assertEq(calls[2].value, 1601);
        _assertCallDataUnchanged(originalCalls, calls);
    }

    function test_ApproveAndSwapHook_UsesPrevAmountWithZeroValueNativeCalls() public {
        bytes memory txData = _buildNativeZeroValueTxData(1000, 900, 950);
        (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(txData);
        bytes memory data = _approveAndSwapHookData(address(0), outputToken, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);
        assertEq(_sumCallValues(calls), 0);
        _assertCallsUnchanged(originalCalls, calls);
    }

    function test_ApproveAndSwapHook_UsesPrevAmountAndExecutesNativeSwap() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        bytes memory data = _approveAndSwapHookData(address(0), outputToken, 1001, 900, true, txData);

        vm.deal(account, 2000);
        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        _execute(executions);

        assertEq(mockRouter.lastAmount(), 2000);
        assertEq(mockRouter.lastMinReturnAmount(), uint256(900) * 2000 / 1001);
        assertEq(mockRouter.lastMsgValue(), 2000);
        assertEq(IERC20(outputToken).balanceOf(account), 2000);
        assertEq(approveAndSwapHook.getOutAmount(account), 2000);
    }

    function test_RevertWhenApproveAndSwapHookInputTokenEqualsOutputToken() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _approveAndSwapHookData(inputToken, inputToken, 1000, 900, false, txData);

        vm.expectRevert(ApproveAndSwapOpenOceanHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        approveAndSwapHook.build(address(0), account, data);
    }

    function test_Updater_AllowsCallerDriftWhenReferrerMatches() public {
        bytes memory txData = _buildErc20RouteTxData(makeAddr("newOpenOceanCaller"), 1000, 900, 950, 0);

        (bytes memory updated,,) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
        (IOpenOceanCaller updatedCaller, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(updated);

        assertEq(address(updatedCaller), makeAddr("newOpenOceanCaller"));
        assertEq(desc.amount, 2000);
    }

    function test_RevertWhenReferrerDoesNotMatch() public {
        bytes memory txData = _buildErc20RouteTxDataWithReferrer(caller, makeAddr("wrongReferrer"), 1000, 900, 950, 0);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_OPENOCEAN_REFERRER.selector);
        harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
    }

    function test_RevertWhenPartialFillFlagIsSet() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 1);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.PARTIAL_FILL_NOT_ALLOWED.selector);
        harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
    }

    function test_RevertWhenNativeCallValueSumIsPartial() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](2);
        calls[0] = _call(uint256(uint160(inputToken)), 100, abi.encodePacked(DEPOSIT_SELECTOR));
        calls[1] = _call(0, 0, _uniswapCallData(inputToken, outputToken, 100));
        bytes memory txData = _buildTxData(caller, address(0), outputToken, 1000, 900, 950, 0, calls);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_CALL_VALUE.selector);
        harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
    }

    function test_Updater_AllowsUnknownErc20RouteSelectors() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        (bytes memory updated,,) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory updatedCalls) =
            _decodeSwap(updated);

        assertEq(desc.amount, 2000);
        assertEq(keccak256(updatedCalls[0].data), keccak256(hex"12345678"));
    }

    // ==================== Security Fix Tests ====================

    function test_Updater_ReturnsSrcAndDstTokens() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);

        (, address srcToken, address dstToken) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1000);

        assertEq(srcToken, inputToken);
        assertEq(dstToken, outputToken);
    }

    function test_Updater_ReturnsNativeSrcToken() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);

        (, address srcToken, address dstToken) = harness.updateTxDataAmounts(txData, referrer, account, 2000, 1001);

        assertEq(srcToken, address(0));
        assertEq(dstToken, outputToken);
    }

    function test_RevertWhenDstReceiverDoesNotMatch() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_DST_RECEIVER.selector);
        harness.updateTxDataAmounts(txData, referrer, makeAddr("attacker"), 2000, 1000);
    }

    function test_RevertWhenSwapHookDstTokenDoesNotMatchOutputToken() public {
        // Build txData with dstToken = inputToken (mismatch with hookData's outputToken)
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxData(caller, inputToken, inputToken, 1000, 900, 950, 0, calls);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);

        vm.expectRevert(SwapOpenOceanHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(0), account, data);
    }

    function test_RevertWhenApproveAndSwapHookDstTokenDoesNotMatchOutputToken() public {
        // Build txData with dstToken = inputToken (mismatch with hookData's outputToken)
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxData(caller, inputToken, inputToken, 1000, 900, 950, 0, calls);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);

        vm.expectRevert(ApproveAndSwapOpenOceanHook.OUTPUT_TOKEN_MISMATCH.selector);
        approveAndSwapHook.build(address(0), account, data);
    }

    function test_SwapOpenOcean_DecodeAmounts() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);
        assertEq(swapHook.decodeAmounts(data)[0], 1000);
    }

    function test_SwapOpenOcean_ReplaceCalldataAmounts() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapOpenOcean_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapOpenOcean_DecodeAmounts() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], 1000);
    }

    function test_ApproveAndSwapOpenOcean_ReplaceCalldataAmounts() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapOpenOcean_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapOpenOcean_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapOpenOcean_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapOpenOcean_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(999));
        // Verify bytes before AMOUNT_POSITION (40) are unchanged
        for (uint256 i = 0; i < 40; i++) {
            assertEq(replaced[i], data[i]);
        }
        // Verify bytes after AMOUNT_POSITION + 32 (72) are unchanged
        for (uint256 i = 72; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function test_RevertWhenSwapHookPrevHookReturnsZero() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, true, txData);

        prevHook.setOutAmount(0, account);

        vm.expectRevert(SwapOpenOceanHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_RevertWhenApproveAndSwapHookPrevHookReturnsZero() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, true, txData);

        prevHook.setOutAmount(0, account);

        vm.expectRevert(ApproveAndSwapOpenOceanHook.ZERO_EXECUTION_AMOUNT.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_RevertWhenApproveAndSwapHookInputTokenMismatch() public {
        // Build txData with srcToken = thirdToken (mismatch with hookData's inputToken)
        address thirdToken = address(new MockERC20("Third", "THD", 18));
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxData(caller, thirdToken, outputToken, 1000, 900, 950, 0, calls);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);

        vm.expectRevert(ApproveAndSwapOpenOceanHook.INPUT_TOKEN_MISMATCH.selector);
        approveAndSwapHook.build(address(0), account, data);
    }

    function test_SwapHook_RevertWhenTxDataDstReceiverIsAttacker() public {
        // Simulate attack: txData has dstReceiver pointing to attacker
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxDataWithReceiver(
            caller, referrer, inputToken, outputToken, 1000, 900, 950, 0, calls, makeAddr("attacker")
        );
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_DST_RECEIVER.selector);
        swapHook.build(address(0), account, data);
    }

    function test_ApproveAndSwapHook_RevertWhenTxDataDstReceiverIsAttacker() public {
        // Simulate attack: txData has dstReceiver pointing to attacker
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxDataWithReceiver(
            caller, referrer, inputToken, outputToken, 1000, 900, 950, 0, calls, makeAddr("attacker")
        );
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);

        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_DST_RECEIVER.selector);
        approveAndSwapHook.build(address(0), account, data);
    }

    // ==================== Inspect Tests ====================

    function test_SwapHook_InspectReturnsDstReceiver() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, false, txData);

        bytes memory inspected = swapHook.inspect(data);

        assertEq(inspected.length, 20);
        assertEq(address(bytes20(inspected)), account);
    }

    function test_ApproveAndSwapHook_InspectReturnsDstReceiver() public view {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 0);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, false, txData);

        bytes memory inspected = approveAndSwapHook.inspect(data);

        assertEq(inspected.length, 20);
        assertEq(address(bytes20(inspected)), account);
    }

    // ==================== Helpers ====================

    function _buildErc20RouteTxData(
        address caller_,
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_,
        uint256 flags_
    )
        private
        view
        returns (bytes memory)
    {
        return
            _buildErc20RouteTxDataWithReferrer(caller_, referrer, amount_, minReturnAmount_, guaranteedAmount_, flags_);
    }

    function _buildErc20RouteTxDataWithReferrer(
        address caller_,
        address referrer_,
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_,
        uint256 flags_
    )
        private
        view
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](4);
        calls[0] = _call(0, 0, _uniswapCallData(inputToken, outputToken, amount_));
        calls[1] = _call(0, 0, _singleDistributionCall(outputToken, _uniswapCallData(outputToken, inputToken, 1), 0x44));
        calls[2] = _call(
            0,
            0,
            abi.encodePacked(
                COLLECT_SLIPPAGE_SELECTOR, abi.encode(outputToken, address(0xBEEF), COLLECT_SLIPPAGE_HIGH_BITS | 1100)
            )
        );
        calls[3] = _call(
            0,
            0,
            _singleDistributionCall(
                outputToken,
                abi.encodePacked(SAFE_TRANSFER_SELECTOR, abi.encode(outputToken, account, uint256(1))),
                0x44
            )
        );

        return _buildTxDataWithReferrer(
            caller_, referrer_, inputToken, outputToken, amount_, minReturnAmount_, guaranteedAmount_, flags_, calls
        );
    }

    function _buildNativeSplitTxData(
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_
    )
        private
        view
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](6);
        calls[0] = _call(uint256(uint160(inputToken)), 200, abi.encodePacked(DEPOSIT_SELECTOR));
        calls[1] = _call(0, 0, _uniswapCallData(inputToken, outputToken, 200));
        calls[2] = _call(uint256(uint160(inputToken)), 801, abi.encodePacked(DEPOSIT_SELECTOR));
        calls[3] = _call(0, 0, _uniswapCallData(inputToken, outputToken, 801));
        calls[4] = _call(
            0,
            0,
            abi.encodePacked(
                COLLECT_SLIPPAGE_SELECTOR, abi.encode(outputToken, address(0xBEEF), COLLECT_SLIPPAGE_HIGH_BITS | 1100)
            )
        );
        calls[5] = _call(
            0,
            0,
            _singleDistributionCall(outputToken, abi.encodePacked(WITHDRAW_SELECTOR, abi.encode(uint256(1))), 0x04)
        );

        return _buildTxData(caller, address(0), outputToken, amount_, minReturnAmount_, guaranteedAmount_, 0, calls);
    }

    function _buildNativeZeroValueTxData(
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_
    )
        private
        view
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](4);
        calls[0] = _call(0, 0, _singleDistributionCall(inputToken, abi.encodePacked(DEPOSIT_SELECTOR), 0x44));
        calls[1] = _call(0, 0, _uniswapCallData(inputToken, outputToken, amount_));
        calls[2] = _call(
            0,
            0,
            abi.encodePacked(
                COLLECT_SLIPPAGE_SELECTOR, abi.encode(outputToken, address(0xBEEF), COLLECT_SLIPPAGE_HIGH_BITS | 1100)
            )
        );
        calls[3] = _call(
            0,
            0,
            _singleDistributionCall(
                outputToken,
                abi.encodePacked(SAFE_TRANSFER_SELECTOR, abi.encode(outputToken, account, uint256(1))),
                0x44
            )
        );

        return _buildTxData(caller, address(0), outputToken, amount_, minReturnAmount_, guaranteedAmount_, 0, calls);
    }

    function _buildFractionalDistributionTxData(uint256 distribution_) private view returns (bytes memory) {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(
            0, 0, _singleDistributionCall(inputToken, _uniswapCallData(inputToken, outputToken, 1), 0x44, distribution_)
        );

        return _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);
    }

    function _buildTxData(
        address caller_,
        address srcToken_,
        address dstToken_,
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_,
        uint256 flags_,
        IOpenOceanCaller.CallDescription[] memory calls_
    )
        private
        view
        returns (bytes memory)
    {
        return _buildTxDataWithReferrer(
            caller_, referrer, srcToken_, dstToken_, amount_, minReturnAmount_, guaranteedAmount_, flags_, calls_
        );
    }

    function _buildTxDataWithReferrer(
        address caller_,
        address referrer_,
        address srcToken_,
        address dstToken_,
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_,
        uint256 flags_,
        IOpenOceanCaller.CallDescription[] memory calls_
    )
        private
        view
        returns (bytes memory)
    {
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(srcToken_),
            dstToken: IERC20(dstToken_),
            srcReceiver: caller_,
            dstReceiver: account,
            amount: amount_,
            minReturnAmount: minReturnAmount_,
            guaranteedAmount: guaranteedAmount_,
            flags: flags_,
            referrer: referrer_,
            permit: ""
        });

        return abi.encodePacked(IOpenOceanExchange.swap.selector, abi.encode(IOpenOceanCaller(caller_), desc, calls_));
    }

    function _buildTxDataWithReceiver(
        address caller_,
        address referrer_,
        address srcToken_,
        address dstToken_,
        uint256 amount_,
        uint256 minReturnAmount_,
        uint256 guaranteedAmount_,
        uint256 flags_,
        IOpenOceanCaller.CallDescription[] memory calls_,
        address dstReceiver_
    )
        private
        pure
        returns (bytes memory)
    {
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(srcToken_),
            dstToken: IERC20(dstToken_),
            srcReceiver: caller_,
            dstReceiver: dstReceiver_,
            amount: amount_,
            minReturnAmount: minReturnAmount_,
            guaranteedAmount: guaranteedAmount_,
            flags: flags_,
            referrer: referrer_,
            permit: ""
        });

        return abi.encodePacked(IOpenOceanExchange.swap.selector, abi.encode(IOpenOceanCaller(caller_), desc, calls_));
    }

    function _uniswapCallData(
        address tokenIn_,
        address tokenOut_,
        uint256 amount_
    )
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            UNISWAP_V3_SWAP_SELECTOR,
            abi.encode(
                pool, tokenIn_ < tokenOut_, int256(amount_), caller, abi.encodePacked(tokenIn_, uint24(100), tokenOut_)
            )
        );
    }

    function _singleDistributionCall(
        address token_,
        bytes memory nestedData_,
        uint256 amountBias_
    )
        private
        pure
        returns (bytes memory)
    {
        return _singleDistributionCall(token_, nestedData_, amountBias_, DISTRIBUTION_SENTINEL);
    }

    function _singleDistributionCall(
        address token_,
        bytes memory nestedData_,
        uint256 amountBias_,
        uint256 distribution_
    )
        private
        pure
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription memory nested = _call(0, 0, nestedData_);
        return
            abi.encodePacked(SINGLE_DISTRIBUTION_CALL_SELECTOR, abi.encode(token_, distribution_, nested, amountBias_));
    }

    function _nestedMakeCallData(
        bytes memory data_,
        uint256 depth_
    )
        private
        pure
        returns (bytes memory nestedData)
    {
        nestedData = data_;
        for (uint256 i; i < depth_; ++i) {
            nestedData = abi.encodePacked(MAKE_CALL_SELECTOR, abi.encode(_call(0, 0, nestedData)));
        }
    }

    function _unwrapMakeCallData(
        bytes memory data_,
        uint256 depth_
    )
        private
        pure
        returns (bytes memory unwrappedData)
    {
        unwrappedData = data_;
        for (uint256 i; i < depth_; ++i) {
            IOpenOceanCaller.CallDescription memory nested =
                abi.decode(_sliceAfterSelector(unwrappedData), (IOpenOceanCaller.CallDescription));
            unwrappedData = nested.data;
        }
    }

    function _call(
        uint256 target_,
        uint256 value_,
        bytes memory data_
    )
        private
        pure
        returns (IOpenOceanCaller.CallDescription memory)
    {
        return IOpenOceanCaller.CallDescription({ target: target_, gasLimit: 0, value: value_, data: data_ });
    }

    function _swapHookData(
        address outputToken_,
        uint256 value_,
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory txData_
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(outputToken_),
            bytes32(value_),
            bytes32(inputAmount_),
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    function _approveAndSwapHookData(
        address inputToken_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory txData_
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(inputToken_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    function _decodeSwap(bytes memory txData_)
        private
        pure
        returns (
            IOpenOceanCaller caller_,
            IOpenOceanExchange.SwapDescription memory desc_,
            IOpenOceanCaller.CallDescription[] memory calls_
        )
    {
        return abi.decode(
            _sliceAfterSelector(txData_),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
    }

    function _nestedDistributionData(bytes memory data_) private pure returns (bytes memory nestedData) {
        (,, IOpenOceanCaller.CallDescription memory nested,) =
            abi.decode(_sliceAfterSelector(data_), (address, uint256, IOpenOceanCaller.CallDescription, uint256));
        nestedData = nested.data;
    }

    function _decodeDistribution(bytes memory data_) private pure returns (uint256 distribution) {
        (, distribution,,) =
            abi.decode(_sliceAfterSelector(data_), (address, uint256, IOpenOceanCaller.CallDescription, uint256));
    }

    function _distribution(uint256 numerator_, uint256 denominator_) private pure returns (uint256) {
        return (numerator_ << 128) | denominator_;
    }

    function _decodeUniswapAmount(bytes memory data_) private pure returns (uint256) {
        (,, int256 amount,,) = abi.decode(_sliceAfterSelector(data_), (address, bool, int256, address, bytes));
        return uint256(amount);
    }

    function _decodeCollectSlippageAmount(bytes memory data_) private pure returns (uint256 amount) {
        (,, amount) = abi.decode(_sliceAfterSelector(data_), (address, address, uint256));
    }

    function _decodeSafeTransferAmount(bytes memory data_) private pure returns (uint256 amount) {
        (,, amount) = abi.decode(_sliceAfterSelector(data_), (address, address, uint256));
    }

    function _sumCallValues(IOpenOceanCaller.CallDescription[] memory calls_) private pure returns (uint256 sum) {
        for (uint256 i; i < calls_.length; ++i) {
            sum += calls_[i].value;
        }
    }

    function _assertCallsUnchanged(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_
    )
        private
        pure
    {
        _assertCallDataUnchanged(originalCalls_, updatedCalls_);
        for (uint256 i; i < updatedCalls_.length; ++i) {
            assertEq(updatedCalls_[i].value, originalCalls_[i].value);
        }
    }

    function _assertCallDataUnchanged(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_
    )
        private
        pure
    {
        assertEq(updatedCalls_.length, originalCalls_.length);
        for (uint256 i; i < updatedCalls_.length; ++i) {
            assertEq(updatedCalls_[i].target, originalCalls_[i].target);
            assertEq(updatedCalls_[i].gasLimit, originalCalls_[i].gasLimit);
            assertEq(keccak256(updatedCalls_[i].data), keccak256(originalCalls_[i].data));
        }
    }

    function _execute(Execution[] memory executions_) private {
        for (uint256 i; i < executions_.length; ++i) {
            (bool success, bytes memory returnData) =
                executions_[i].target.call{ value: executions_[i].value }(executions_[i].callData);
            assertTrue(success, string(returnData));
        }
    }

    function _sliceAfterSelector(bytes memory data_) private pure returns (bytes memory result) {
        result = new bytes(data_.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data_[i + 4];
        }
    }

    /*//////////////////////////////////////////////////////////////
                         NAME / DESCRIPTION
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Name() public view {
        assertEq(swapHook.name(), "Swap OpenOcean");
    }

    function test_SwapHook_Description() public view {
        assertEq(swapHook.description(), "Swaps tokens via OpenOcean aggregator");
    }

    function test_ApproveAndSwapHook_Name() public view {
        assertEq(approveAndSwapHook.name(), "Approve and Swap OpenOcean");
    }

    function test_ApproveAndSwapHook_Description() public view {
        assertEq(approveAndSwapHook.description(), "Approves and swaps tokens via OpenOcean aggregator");
    }

    /*//////////////////////////////////////////////////////////////
                            AMOUNT ROLES
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = swapHook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_ApproveAndSwapHook_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = approveAndSwapHook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }
}
