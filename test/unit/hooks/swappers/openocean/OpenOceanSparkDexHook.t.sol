// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    ApproveAndSwapOpenOceanSparkDexHook
} from "../../../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol";
import { SwapOpenOceanSparkDexHook } from "../../../../../src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol";
import { OpenOceanSparkDexScaler } from "../../../../../src/libraries/OpenOceanSparkDexScaler.sol";
import { IOpenOceanCaller } from "../../../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";

contract OpenOceanSparkDexScalerHarness {
    function updateTxDataAmounts(
        bytes memory txData_,
        address expectedCaller_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        external
        pure
        returns (bytes memory)
    {
        return OpenOceanSparkDexScaler.updateTxDataAmounts(txData_, expectedCaller_, newAmount_, originalAmount_);
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

contract OpenOceanSparkDexHookTest is Test {
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

    OpenOceanSparkDexScalerHarness private harness;
    SwapOpenOceanSparkDexHook private swapHook;
    ApproveAndSwapOpenOceanSparkDexHook private approveAndSwapHook;
    MockOpenOceanRouter private mockRouter;
    MockHook private prevHook;

    address private router;
    address private caller;
    address private account;
    address private inputToken;
    address private outputToken;
    address private pool;

    function setUp() public {
        harness = new OpenOceanSparkDexScalerHarness();
        mockRouter = new MockOpenOceanRouter();
        router = address(mockRouter);
        caller = makeAddr("openOceanCaller");
        account = address(this);
        pool = makeAddr("sparkDexV4Pool");

        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);
        swapHook = new SwapOpenOceanSparkDexHook(router, caller, NATIVE);
        approveAndSwapHook = new ApproveAndSwapOpenOceanSparkDexHook(router, caller, NATIVE);
    }

    function test_Scaler_ScalesErc20RouteAndKeepsDistributionSentinels() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);

        bytes memory updated = harness.updateTxDataAmounts(txData, caller, 2000, 1000);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(updated);

        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
        assertEq(desc.guaranteedAmount, 1900);

        assertEq(_decodeUniswapAmount(calls[0].data), 2000);
        assertEq(_decodeUniswapAmount(_nestedDistributionData(calls[1].data)), 1);

        uint256 collectAmount = _decodeCollectSlippageAmount(calls[2].data);
        assertEq(collectAmount & ~uint256(type(uint240).max), COLLECT_SLIPPAGE_HIGH_BITS);
        assertEq(collectAmount & uint256(type(uint240).max), 2200);

        assertEq(_decodeSafeTransferAmount(_nestedDistributionData(calls[3].data)), 1);
    }

    function test_Scaler_ScalesNativeValuesAndDirectInputsWithSameRemainder() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);

        bytes memory updated = harness.updateTxDataAmounts(txData, caller, 2000, 1001);
        (, IOpenOceanExchange.SwapDescription memory desc, IOpenOceanCaller.CallDescription[] memory calls) =
            _decodeSwap(updated);

        assertEq(address(desc.srcToken), address(0));
        assertEq(desc.amount, 2000);
        assertEq(calls[0].value + calls[2].value, 2000);
        assertEq(calls[0].value, 399);
        assertEq(calls[2].value, 1601);
        assertEq(_decodeUniswapAmount(calls[1].data), 399);
        assertEq(_decodeUniswapAmount(calls[3].data), 1601);
    }

    function test_SwapHook_UsesPrevAmountAndScalesCallData() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _swapHookData(outputToken, 0, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[1].callData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, router);
        assertEq(executions[1].value, 0);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, 1800);
    }

    function test_SwapHook_UpdatesNativeExecutionValue() public {
        bytes memory txData = _buildNativeSplitTxData(1001, 900, 950);
        bytes memory data = _swapHookData(outputToken, 1001, 1001, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[1].callData);

        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
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

        vm.expectRevert(SwapOpenOceanSparkDexHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(0), account, data);
    }

    function test_ApproveAndSwapHook_UsesPrevAmountForApprovalAndSwap() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 2);
        bytes memory data = _approveAndSwapHookData(inputToken, outputToken, 1000, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        (, uint256 approvalAmount) = abi.decode(_sliceAfterSelector(executions[2].callData), (address, uint256));
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[3].callData);

        assertEq(executions.length, 6);
        assertEq(executions[1].target, inputToken);
        assertEq(executions[2].target, inputToken);
        assertEq(executions[3].target, router);
        assertEq(approvalAmount, 2000);
        assertEq(desc.amount, 2000);
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
        bytes memory data = _approveAndSwapHookData(address(0), outputToken, 1001, 900, true, txData);

        prevHook.setOutAmount(2000, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(executions[1].callData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, router);
        assertEq(executions[1].value, 2000);
        assertEq(desc.amount, 2000);
        assertEq(desc.minReturnAmount, uint256(900) * 2000 / 1001);
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

        vm.expectRevert(ApproveAndSwapOpenOceanSparkDexHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        approveAndSwapHook.build(address(0), account, data);
    }

    function test_RevertWhenCallerDoesNotMatch() public {
        bytes memory txData = _buildErc20RouteTxData(makeAddr("wrongCaller"), 1000, 900, 950, 0);

        vm.expectRevert(OpenOceanSparkDexScaler.INVALID_OPENOCEAN_CALLER.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

    function test_RevertWhenPartialFillFlagIsSet() public {
        bytes memory txData = _buildErc20RouteTxData(caller, 1000, 900, 950, 1);

        vm.expectRevert(OpenOceanSparkDexScaler.PARTIAL_FILL_NOT_ALLOWED.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

    function test_RevertWhenDistributionBiasIsWrong() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, _singleDistributionCall(inputToken, _uniswapCallData(inputToken, outputToken, 1), 0x40));

        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        vm.expectRevert(OpenOceanSparkDexScaler.INVALID_AMOUNT_BIAS.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

    function test_RevertWhenDirectSafeTransferAppears() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] =
            _call(0, 0, abi.encodePacked(SAFE_TRANSFER_SELECTOR, abi.encode(outputToken, account, uint256(1000))));
        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        vm.expectRevert(OpenOceanSparkDexScaler.DIRECT_SAFE_TRANSFER_NOT_SUPPORTED.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

    function test_RevertWhenUnknownSelectorAppears() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, hex"12345678");
        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        vm.expectRevert(OpenOceanSparkDexScaler.INVALID_SELECTOR.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

    function test_Scaler_AllowsMaxNestedMakeCallDepth() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, _nestedMakeCallData(_uniswapCallData(inputToken, outputToken, 1000), 10));
        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        bytes memory updated = harness.updateTxDataAmounts(txData, caller, 2000, 1000);
        (,, IOpenOceanCaller.CallDescription[] memory updatedCalls) = _decodeSwap(updated);

        assertEq(_decodeUniswapAmount(_unwrapMakeCallData(updatedCalls[0].data, 10)), 2000);
    }

    function test_RevertWhenNestedMakeCallDepthExceedsMax() public {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = _call(0, 0, _nestedMakeCallData(_uniswapCallData(inputToken, outputToken, 1000), 11));
        bytes memory txData = _buildTxData(caller, inputToken, outputToken, 1000, 900, 950, 0, calls);

        vm.expectRevert(OpenOceanSparkDexScaler.MAX_CALL_DEPTH_EXCEEDED.selector);
        harness.updateTxDataAmounts(txData, caller, 2000, 1000);
    }

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

        return
            _buildTxData(caller_, inputToken, outputToken, amount_, minReturnAmount_, guaranteedAmount_, flags_, calls);
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
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(srcToken_),
            dstToken: IERC20(dstToken_),
            srcReceiver: caller_,
            dstReceiver: account,
            amount: amount_,
            minReturnAmount: minReturnAmount_,
            guaranteedAmount: guaranteedAmount_,
            flags: flags_,
            referrer: address(0),
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
        IOpenOceanCaller.CallDescription memory nested = _call(0, 0, nestedData_);
        return abi.encodePacked(
            SINGLE_DISTRIBUTION_CALL_SELECTOR, abi.encode(token_, DISTRIBUTION_SENTINEL, nested, amountBias_)
        );
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
}
