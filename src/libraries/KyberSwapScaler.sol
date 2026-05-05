// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../vendor/BytesLib.sol";
import { IMetaAggregationRouterV2 } from "../vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IScaleHelper } from "../vendor/kyberswap/IScaleHelper.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { HookDataUpdater } from "./HookDataUpdater.sol";

/// @title KyberSwapScaler
/// @author Superform Labs
/// @notice Shared scaling logic for KyberSwap hooks when usePrevHookAmount is true.
///         Primary: uses KyberSwap ScaleHelper to properly scale targetData internals.
///         Fallback: proportional scaling of desc fields (amount, minReturnAmount, srcAmounts, feeAmounts).
library KyberSwapScaler {
    error ZERO_AMOUNT();

    /// @dev Updates txData amounts when usePrevHookAmount is true.
    ///      Only runs in view _buildHookExecutions (off-chain simulation).
    /// @param scaleHelper_ The KyberSwap ScaleHelper contract (address(0) to skip)
    /// @param txData_ The encoded swap calldata
    /// @param newAmount The new input amount (from previous hook)
    /// @param originalAmount The original input amount (from hookData)
    function updateTxDataAmounts(
        IScaleHelper scaleHelper_,
        bytes memory txData_,
        uint256 newAmount,
        uint256 originalAmount
    )
        internal
        view
        returns (bytes memory)
    {
        if (newAmount == 0) revert ZERO_AMOUNT();

        // Try ScaleHelper first — it properly scales targetData internals for multihop routes
        if (address(scaleHelper_) != address(0)) {
            try scaleHelper_.getScaledInputData(txData_, newAmount) returns (bool isSuccess, bytes memory scaledData) {
                if (isSuccess) {
                    return scaledData;
                }
            } catch { }
        }

        // Fallback: proportional scaling of desc-level fields only
        return _proportionalScale(txData_, newAmount, originalAmount);
    }

    /// @dev Proportional scaling fallback — updates desc.amount, desc.minReturnAmount,
    ///      desc.srcAmounts, and desc.feeAmounts. Does NOT update targetData internals.
    function _proportionalScale(
        bytes memory txData_,
        uint256 newAmount,
        uint256 originalAmount
    )
        private
        pure
        returns (bytes memory)
    {
        if (originalAmount == 0) revert ZERO_AMOUNT();

        IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4), (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        params.desc.minReturnAmount =
            HookDataUpdater.getUpdatedOutputAmount(newAmount, originalAmount, params.desc.minReturnAmount);
        params.desc.amount = newAmount;

        for (uint256 i = 0; i < params.desc.srcAmounts.length; i++) {
            params.desc.srcAmounts[i] = Math.mulDiv(params.desc.srcAmounts[i], newAmount, originalAmount);
        }

        for (uint256 i = 0; i < params.desc.feeAmounts.length; i++) {
            params.desc.feeAmounts[i] = Math.mulDiv(params.desc.feeAmounts[i], newAmount, originalAmount);
        }

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }
}
