// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SwapKyberSwapHook } from "../../../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import {
    ApproveAndSwapKyberSwapHook
} from "../../../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { IMetaAggregationRouterV2 } from "../../../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IScaleHelper } from "../../../../../src/vendor/kyberswap/IScaleHelper.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { HookDataUpdater } from "../../../../../src/libraries/HookDataUpdater.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

/// @title KyberSwapUpdateTxDataTest
/// @notice Tests that _updateTxDataAmounts correctly decodes, updates, and re-encodes SwapExecutionParams
///         This validates the key improvement over 0x: updating both desc.amount AND desc.minReturnAmount
contract KyberSwapUpdateTxDataTest is Helpers {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address account;
    address kyberRouter;
    address callTarget;
    address approveTarget;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        callTarget = makeAddr("callTarget");
        approveTarget = makeAddr("approveTarget");

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        kyberRouter = address(new MockKyberRouterForUpdateTest());

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        swapHook = new SwapKyberSwapHook(kyberRouter, address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(kyberRouter, address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }

    /// @notice Tests that when usePrevHookAmount=true and prevAmount doubles,
    ///         the re-encoded txData has updated amount, proportionally scaled minReturnAmount, and scaled srcAmounts
    function test_SwapHook_UpdateTxData_DoublesAmount() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 2000; // doubled

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode the swap calldata from executions[1] (index 0=preExecute, 1=swap, 2=postExecute)
        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        // Amount should be updated to prevAmount
        assertEq(decoded.desc.amount, prevAmount, "amount should be updated to prevAmount");

        // minReturnAmount should be proportionally scaled: 900 * 2000 / 1000 = 1800
        assertEq(decoded.desc.minReturnAmount, 1800, "minReturnAmount should scale proportionally");

        // srcAmounts should be proportionally scaled: 1000 * 2000 / 1000 = 2000
        assertEq(decoded.desc.srcAmounts[0], prevAmount, "srcAmounts[0] should scale proportionally");
    }

    /// @notice Tests that when usePrevHookAmount=true and prevAmount halves,
    ///         minReturnAmount is proportionally reduced
    function test_SwapHook_UpdateTxData_HalvesAmount() public {
        uint256 originalAmount = 2000;
        uint256 originalMinReturn = 1800;
        uint256 prevAmount = 1000; // halved

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should be updated to prevAmount");
        // minReturnAmount: 1800 * 1000 / 2000 = 900
        assertEq(decoded.desc.minReturnAmount, 900, "minReturnAmount should scale proportionally");
        // srcAmounts: 2000 * 1000 / 2000 = 1000
        assertEq(decoded.desc.srcAmounts[0], prevAmount, "srcAmounts[0] should scale proportionally");
    }

    /// @notice Tests that when usePrevHookAmount=false, txData is forwarded as-is
    function test_SwapHook_NoUpdateWhenNotUsePrevHook() public view {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(0)), // usePrevHookAmount = false
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        // Should remain unchanged
        assertEq(decoded.desc.amount, originalAmount, "amount should remain unchanged");
        assertEq(decoded.desc.minReturnAmount, originalMinReturn, "minReturnAmount should remain unchanged");
    }

    /// @notice Tests the ApproveAndSwap variant also correctly updates txData
    function test_ApproveAndSwapHook_UpdateTxData() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 3000; // tripled

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // executions: [0]=preExecute, [1]=approve(0), [2]=approve(amount), [3]=swap, [4]=approve(0), [5]=postExecute
        bytes memory swapCalldata = executions[3].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should be updated to prevAmount");
        // minReturnAmount: 900 * 3000 / 1000 = 2700
        assertEq(decoded.desc.minReturnAmount, 2700, "minReturnAmount should scale proportionally");
    }

    /// @notice Tests that other SwapExecutionParams fields are preserved after update
    function test_SwapHook_UpdateTxData_PreservesOtherFields() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 2000;

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        // Verify other fields are preserved
        assertEq(decoded.callTarget, callTarget, "callTarget should be preserved");
        assertEq(decoded.approveTarget, approveTarget, "approveTarget should be preserved");
        assertEq(address(decoded.desc.srcToken), inputToken, "srcToken should be preserved");
        assertEq(address(decoded.desc.dstToken), outputToken, "dstToken should be preserved");
        assertEq(decoded.desc.dstReceiver, account, "dstReceiver should be preserved");
    }

    /// @notice Fuzz test for proportional scaling
    function test_SwapHook_UpdateTxData_Fuzz(uint256 originalAmount, uint256 prevAmount) public {
        // Bound to reasonable values to avoid overflow
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        uint256 originalMinReturn = originalAmount * 9 / 10; // 90% of input

        bytes memory txData_ = _buildKyberTxDataWithAmounts(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should equal prevAmount");

        // Use HookDataUpdater directly to compute expected value (it uses percentage-based scaling with PRECISION)
        uint256 expectedMinReturn =
            HookDataUpdater.getUpdatedOutputAmount(prevAmount, originalAmount, originalMinReturn);
        assertEq(decoded.desc.minReturnAmount, expectedMinReturn, "minReturnAmount should scale correctly");
    }

    /// @notice Tests that srcAmounts scale correctly with multiple receivers (split routes)
    function test_SwapHook_UpdateTxData_ScalesSrcAmountsMultiReceiver() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 3000; // tripled

        // Build txData with multiple srcReceivers (simulating a split route: 60/40 split)
        bytes memory txData_ = _buildKyberTxDataWithSplitRoute(originalAmount, originalMinReturn, 600, 400);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should be updated");
        // 600 * 3000 / 1000 = 1800
        assertEq(decoded.desc.srcAmounts[0], 1800, "srcAmounts[0] should scale (60% of 3000)");
        // 400 * 3000 / 1000 = 1200
        assertEq(decoded.desc.srcAmounts[1], 1200, "srcAmounts[1] should scale (40% of 3000)");
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildKyberTxDataWithAmounts(
        uint256 amount,
        uint256 minReturnAmount
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;

        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        address[] memory feeReceivers = new address[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(inputToken),
            dstToken: IERC20(outputToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturnAmount,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget,
            approveTarget: approveTarget,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    function _buildKyberTxDataWithSplitRoute(
        uint256 amount,
        uint256 minReturnAmount,
        uint256 splitAmount0,
        uint256 splitAmount1
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](2);
        srcReceivers[0] = callTarget;
        srcReceivers[1] = address(0xBEEF);

        uint256[] memory srcAmounts = new uint256[](2);
        srcAmounts[0] = splitAmount0;
        srcAmounts[1] = splitAmount1;

        address[] memory feeReceivers = new address[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(inputToken),
            dstToken: IERC20(outputToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturnAmount,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget,
            approveTarget: approveTarget,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    function _sliceAfterSelector(bytes memory data) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - 4);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[i + 4];
        }
        return result;
    }
}

contract MockKyberRouterForUpdateTest is IMetaAggregationRouterV2 {
    function swap(SwapExecutionParams calldata) external payable override returns (uint256, uint256) {
        return (0, 0);
    }
}

/// @dev Mock ScaleHelper that succeeds: re-encodes with newAmount in desc.amount and a marker in clientData
contract MockScaleHelperSuccess is IScaleHelper {
    function getScaledInputData(
        bytes calldata inputData,
        uint256 newAmount
    )
        external
        pure
        override
        returns (bool isSuccess, bytes memory newScaledData)
    {
        // Decode, update amount, add marker in clientData to prove ScaleHelper was used
        IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
            inputData[4:], (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        params.desc.amount = newAmount;
        params.desc.minReturnAmount = Math.mulDiv(params.desc.minReturnAmount, newAmount, params.desc.amount);
        params.clientData = "SCALED"; // marker to verify ScaleHelper was used

        // Scale srcAmounts too (simulating real ScaleHelper behavior)
        uint256 originalAmount = params.desc.amount;
        for (uint256 i = 0; i < params.desc.srcAmounts.length; i++) {
            params.desc.srcAmounts[i] = Math.mulDiv(params.desc.srcAmounts[i], newAmount, originalAmount);
        }

        newScaledData = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
        isSuccess = true;
    }
}

/// @dev Mock ScaleHelper that always fails (simulating non-scalable sources)
contract MockScaleHelperFail is IScaleHelper {
    function getScaledInputData(bytes calldata, uint256) external pure override returns (bool, bytes memory) {
        return (false, "");
    }
}

/// @dev Mock ScaleHelper that reverts (simulating unexpected errors)
contract MockScaleHelperRevert is IScaleHelper {
    function getScaledInputData(bytes calldata, uint256) external pure override returns (bool, bytes memory) {
        revert("ScaleHelper: unexpected error");
    }
}

/// @title KyberSwapScaleHelperTest
/// @notice Tests the ScaleHelper integration in _updateTxDataAmounts
contract KyberSwapScaleHelperTest is Helpers {
    SwapKyberSwapHook public swapHookWithScaleHelper;
    SwapKyberSwapHook public swapHookWithFailingScaleHelper;
    SwapKyberSwapHook public swapHookWithRevertingScaleHelper;
    ApproveAndSwapKyberSwapHook public approveHookWithScaleHelper;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address account;
    address kyberRouter;
    address callTarget;
    address approveTarget;

    function setUp() public {
        account = address(this);
        callTarget = makeAddr("callTarget");
        approveTarget = makeAddr("approveTarget");

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        kyberRouter = address(new MockKyberRouterForUpdateTest());

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        address scaleHelperSuccess = address(new MockScaleHelperSuccess());
        address scaleHelperFail = address(new MockScaleHelperFail());
        address scaleHelperRevert = address(new MockScaleHelperRevert());

        swapHookWithScaleHelper = new SwapKyberSwapHook(kyberRouter, scaleHelperSuccess, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        swapHookWithFailingScaleHelper = new SwapKyberSwapHook(kyberRouter, scaleHelperFail, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        swapHookWithRevertingScaleHelper = new SwapKyberSwapHook(kyberRouter, scaleHelperRevert, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        approveHookWithScaleHelper = new ApproveAndSwapKyberSwapHook(kyberRouter, scaleHelperSuccess, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }

    /// @notice When ScaleHelper succeeds, its output should be used (verified via clientData marker)
    function test_ScaleHelper_UsedWhenSuccessful() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 1050; // +5%, within ScaleHelper window

        bytes memory txData_ = _buildKyberTxData(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHookWithScaleHelper.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        // ScaleHelper should have updated the amount
        assertEq(decoded.desc.amount, prevAmount, "amount should be updated by ScaleHelper");

        // Verify ScaleHelper was used via the clientData marker
        assertEq(string(decoded.clientData), "SCALED", "clientData marker should prove ScaleHelper was used");
    }

    /// @notice When ScaleHelper fails (non-scalable sources), should fall back to proportional scaling
    function test_ScaleHelper_FallbackWhenFails() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 2000; // doubled

        bytes memory txData_ = _buildKyberTxData(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHookWithFailingScaleHelper.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        // Should use proportional fallback
        assertEq(decoded.desc.amount, prevAmount, "amount should be updated by fallback");
        assertEq(decoded.desc.minReturnAmount, 1800, "minReturnAmount should be proportionally scaled");
        assertEq(decoded.desc.srcAmounts[0], prevAmount, "srcAmounts should be proportionally scaled");

        // clientData should remain empty (ScaleHelper was not used)
        assertEq(decoded.clientData.length, 0, "clientData should be empty (fallback used)");
    }

    /// @notice When ScaleHelper reverts, should gracefully fall back to proportional scaling
    function test_ScaleHelper_FallbackWhenReverts() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 2000;

        bytes memory txData_ = _buildKyberTxData(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        // Should not revert — should gracefully fall back
        Execution[] memory executions = swapHookWithRevertingScaleHelper.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should be updated by fallback");
        assertEq(decoded.desc.minReturnAmount, 1800, "minReturnAmount should be proportionally scaled");
    }

    /// @notice ApproveAndSwap variant should also use ScaleHelper when available
    function test_ApproveAndSwap_ScaleHelper_Used() public {
        uint256 originalAmount = 1000;
        uint256 originalMinReturn = 900;
        uint256 prevAmount = 1050;

        bytes memory txData_ = _buildKyberTxData(originalAmount, originalMinReturn);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(originalAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(originalMinReturn),
            bytes1(uint8(1)),
            bytes32(abi.encode(txData_).length),
            abi.encode(txData_)
        );

        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = approveHookWithScaleHelper.build(address(prevHook), account, data);

        // executions: [0]=preExecute, [1]=approve(0), [2]=approve(amount), [3]=swap, [4]=approve(0), [5]=postExecute
        bytes memory swapCalldata = executions[3].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceAfterSelector(swapCalldata), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.desc.amount, prevAmount, "amount should be updated by ScaleHelper");
        assertEq(string(decoded.clientData), "SCALED", "ScaleHelper should have been used");
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildKyberTxData(uint256 amount, uint256 minReturnAmount) internal view returns (bytes memory) {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;

        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(inputToken),
            dstToken: IERC20(outputToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: new address[](0),
            feeAmounts: new uint256[](0),
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturnAmount,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget,
            approveTarget: approveTarget,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    function _sliceAfterSelector(bytes memory data) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - 4);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[i + 4];
        }
        return result;
    }
}
