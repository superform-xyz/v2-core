// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IMetaAggregationRouterV2 } from "../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IScaleHelper } from "../../../src/vendor/kyberswap/IScaleHelper.sol";
import { KyberSwapScaler } from "../../../src/libraries/KyberSwapScaler.sol";
import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";

/// @title KyberSwapScalerTest
/// @notice Direct unit tests for the KyberSwapScaler library via a wrapper contract
contract KyberSwapScalerTest is Test {
    KyberSwapScalerWrapper public wrapper;

    address inputToken;
    address outputToken;
    address account;
    address callTarget;
    address approveTarget;

    function setUp() public {
        wrapper = new KyberSwapScalerWrapper();
        account = address(this);
        inputToken = makeAddr("inputToken");
        outputToken = makeAddr("outputToken");
        callTarget = makeAddr("callTarget");
        approveTarget = makeAddr("approveTarget");
    }

    /*//////////////////////////////////////////////////////////////
                     ZERO AMOUNT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice updateTxDataAmounts reverts with ZERO_AMOUNT when newAmount=0
    function test_RevertIf_NewAmountZero() public {
        bytes memory txData_ = _buildTxData(1000, 900);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 0, 1000);
    }

    /// @notice proportionalScale reverts with ZERO_AMOUNT when originalAmount=0
    function test_RevertIf_OriginalAmountZero() public {
        bytes memory txData_ = _buildTxData(1000, 900);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 500, 0);
    }

    /// @notice Both newAmount=0 and originalAmount=0 — newAmount check triggers first
    function test_RevertIf_BothAmountsZero() public {
        bytes memory txData_ = _buildTxData(1000, 900);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                 PROPORTIONAL SCALING (NO SCALE HELPER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Basic proportional scaling doubles desc.amount
    function test_ProportionalScale_DoublesAmount() public view {
        bytes memory txData_ = _buildTxData(1000, 900);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 2000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 2000, "amount doubled");
        assertEq(decoded.desc.minReturnAmount, 1800, "minReturn doubled");
        assertEq(decoded.desc.srcAmounts[0], 2000, "srcAmounts[0] doubled");
    }

    /// @notice Proportional scaling halves all amounts
    function test_ProportionalScale_HalvesAmount() public view {
        bytes memory txData_ = _buildTxData(2000, 1800);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 1000, 2000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 1000, "amount halved");
        assertEq(decoded.desc.minReturnAmount, 900, "minReturn halved");
        assertEq(decoded.desc.srcAmounts[0], 1000, "srcAmounts[0] halved");
    }

    /// @notice Proportional scaling with split routes scales each srcAmount
    function test_ProportionalScale_SplitRoute() public view {
        bytes memory txData_ = _buildTxDataSplitRoute(1000, 900, 600, 400);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 3000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.srcAmounts[0], 1800, "srcAmounts[0]: 600 * 3000/1000");
        assertEq(decoded.desc.srcAmounts[1], 1200, "srcAmounts[1]: 400 * 3000/1000");
    }

    /// @notice Proportional scaling of feeAmounts in proportional fallback
    function test_ProportionalScale_FeeAmountsScaled() public view {
        bytes memory txData_ = _buildTxDataWithFees(1000, 900, 10, 5);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 2000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.feeAmounts[0], 20, "feeAmounts[0]: 10 * 2000/1000");
        assertEq(decoded.desc.feeAmounts[1], 10, "feeAmounts[1]: 5 * 2000/1000");
    }

    /// @notice Proportional scaling with single feeAmount
    function test_ProportionalScale_SingleFeeAmountScaled() public view {
        bytes memory txData_ = _buildTxDataWithSingleFee(1000, 900, 25);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 500, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.feeAmounts[0], 12, "feeAmounts[0]: 25 * 500/1000 = 12 (rounded down)");
    }

    /// @notice Proportional scaling preserves non-amount fields
    function test_ProportionalScale_PreservesOtherFields() public view {
        bytes memory txData_ = _buildTxData(1000, 900);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 2000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.callTarget, callTarget, "callTarget preserved");
        assertEq(decoded.approveTarget, approveTarget, "approveTarget preserved");
        assertEq(address(decoded.desc.srcToken), inputToken, "srcToken preserved");
        assertEq(address(decoded.desc.dstToken), outputToken, "dstToken preserved");
        assertEq(decoded.desc.dstReceiver, account, "dstReceiver preserved");
    }

    /// @notice Proportional scaling output has correct selector
    function test_ProportionalScale_CorrectSelector() public view {
        bytes memory txData_ = _buildTxData(1000, 900);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 2000, 1000);

        bytes4 selector;
        assembly ("memory-safe") {
            selector := mload(add(scaled, 32))
        }
        assertEq(selector, IMetaAggregationRouterV2.swap.selector, "selector preserved");
    }

    /// @notice Fuzz test for proportional scaling
    function test_ProportionalScale_Fuzz(uint256 originalAmount, uint256 newAmount) public view {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        newAmount = bound(newAmount, 1, type(uint128).max);

        uint256 originalMinReturn = originalAmount * 9 / 10;

        bytes memory txData_ = _buildTxData(originalAmount, originalMinReturn);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, newAmount, originalAmount);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, newAmount, "amount updated");

        uint256 expectedMinReturn =
            HookDataUpdater.getUpdatedOutputAmount(newAmount, originalAmount, originalMinReturn);
        assertEq(decoded.desc.minReturnAmount, expectedMinReturn, "minReturn uses HookDataUpdater");

        uint256 expectedSrcAmount = Math.mulDiv(originalAmount, newAmount, originalAmount);
        assertEq(decoded.desc.srcAmounts[0], expectedSrcAmount, "srcAmounts scaled");
    }

    /*//////////////////////////////////////////////////////////////
                     SCALE HELPER INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice ScaleHelper success → uses ScaleHelper output
    function test_ScaleHelper_UsedWhenSuccessful() public {
        bytes memory txData_ = _buildTxData(1000, 900);
        MockScaleHelperForLib scaleHelper = new MockScaleHelperForLib(true, false);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(scaleHelper)), txData_, 1050, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 1050, "ScaleHelper updated amount");
        assertEq(string(decoded.clientData), "SCALE_HELPER_USED", "ScaleHelper marker present");
    }

    /// @notice ScaleHelper returns isSuccess=false → falls back to proportional
    function test_ScaleHelper_FallbackWhenFails() public {
        bytes memory txData_ = _buildTxData(1000, 900);
        MockScaleHelperForLib scaleHelper = new MockScaleHelperForLib(false, false);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(scaleHelper)), txData_, 2000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 2000, "fallback updated amount");
        assertEq(decoded.clientData.length, 0, "no ScaleHelper marker (fallback used)");
    }

    /// @notice ScaleHelper reverts → falls back to proportional
    function test_ScaleHelper_FallbackWhenReverts() public {
        bytes memory txData_ = _buildTxData(1000, 900);
        MockScaleHelperForLib scaleHelper = new MockScaleHelperForLib(false, true);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(scaleHelper)), txData_, 2000, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 2000, "fallback updated amount after revert");
    }

    /// @notice ScaleHelper=address(0) → proportional scaling without try/catch
    function test_NoScaleHelper_ProportionalOnly() public view {
        bytes memory txData_ = _buildTxData(1000, 900);

        bytes memory scaled = wrapper.updateTxDataAmounts(IScaleHelper(address(0)), txData_, 1500, 1000);

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = _decodeTxData(scaled);
        assertEq(decoded.desc.amount, 1500, "proportional scaling used");
        assertEq(decoded.desc.srcAmounts[0], 1500, "srcAmounts scaled");
    }

    /// @notice ScaleHelper success but newAmount=0 → reverts BEFORE ScaleHelper call
    function test_ScaleHelper_RevertIf_NewAmountZero() public {
        bytes memory txData_ = _buildTxData(1000, 900);
        MockScaleHelperForLib scaleHelper = new MockScaleHelperForLib(true, false);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        wrapper.updateTxDataAmounts(IScaleHelper(address(scaleHelper)), txData_, 0, 1000);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildTxData(uint256 amount, uint256 minReturn) internal view returns (bytes memory) {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        return _encodeTxData(amount, minReturn, srcReceivers, srcAmounts, new address[](0), new uint256[](0));
    }

    function _buildTxDataSplitRoute(
        uint256 amount,
        uint256 minReturn,
        uint256 split0,
        uint256 split1
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](2);
        srcReceivers[0] = callTarget;
        srcReceivers[1] = address(0xBEEF);
        uint256[] memory srcAmounts = new uint256[](2);
        srcAmounts[0] = split0;
        srcAmounts[1] = split1;

        return _encodeTxData(amount, minReturn, srcReceivers, srcAmounts, new address[](0), new uint256[](0));
    }

    function _buildTxDataWithFees(
        uint256 amount,
        uint256 minReturn,
        uint256 fee0,
        uint256 fee1
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        address[] memory feeReceivers = new address[](2);
        feeReceivers[0] = address(0xFEE1);
        feeReceivers[1] = address(0xFEE2);
        uint256[] memory feeAmounts = new uint256[](2);
        feeAmounts[0] = fee0;
        feeAmounts[1] = fee1;

        return _encodeTxData(amount, minReturn, srcReceivers, srcAmounts, feeReceivers, feeAmounts);
    }

    function _buildTxDataWithSingleFee(
        uint256 amount,
        uint256 minReturn,
        uint256 fee
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = address(0xFEE1);
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = fee;

        return _encodeTxData(amount, minReturn, srcReceivers, srcAmounts, feeReceivers, feeAmounts);
    }

    function _encodeTxData(
        uint256 amount,
        uint256 minReturn,
        address[] memory srcReceivers,
        uint256[] memory srcAmounts,
        address[] memory feeReceivers,
        uint256[] memory feeAmounts
    )
        internal
        view
        returns (bytes memory)
    {
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(inputToken),
            dstToken: IERC20(outputToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturn,
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

    function _decodeTxData(bytes memory txData_)
        internal
        pure
        returns (IMetaAggregationRouterV2.SwapExecutionParams memory)
    {
        bytes memory paramBytes = new bytes(txData_.length - 4);
        for (uint256 i = 0; i < paramBytes.length; i++) {
            paramBytes[i] = txData_[i + 4];
        }
        return abi.decode(paramBytes, (IMetaAggregationRouterV2.SwapExecutionParams));
    }
}

/// @dev Wrapper to expose KyberSwapScaler library functions for direct testing
contract KyberSwapScalerWrapper {
    function updateTxDataAmounts(
        IScaleHelper scaleHelper_,
        bytes memory txData_,
        uint256 newAmount,
        uint256 originalAmount
    )
        external
        view
        returns (bytes memory)
    {
        return KyberSwapScaler.updateTxDataAmounts(scaleHelper_, txData_, newAmount, originalAmount);
    }
}

/// @dev Mock ScaleHelper for library-level testing
contract MockScaleHelperForLib is IScaleHelper {
    bool private _shouldSucceed;
    bool private _shouldRevert;

    constructor(bool shouldSucceed_, bool shouldRevert_) {
        _shouldSucceed = shouldSucceed_;
        _shouldRevert = shouldRevert_;
    }

    function getScaledInputData(
        bytes calldata inputData,
        uint256 newAmount
    )
        external
        view
        override
        returns (bool isSuccess, bytes memory newScaledData)
    {
        if (_shouldRevert) {
            revert("ScaleHelper: test revert");
        }

        if (!_shouldSucceed) {
            return (false, "");
        }

        // Decode, update amount, add marker
        IMetaAggregationRouterV2.SwapExecutionParams memory params =
            abi.decode(inputData[4:], (IMetaAggregationRouterV2.SwapExecutionParams));

        params.desc.amount = newAmount;
        params.clientData = "SCALE_HELPER_USED";

        return (true, abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params)));
    }
}
