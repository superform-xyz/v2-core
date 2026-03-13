// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IScaleHelper
/// @notice Interface for KyberSwap's ScaleHelper contract that adjusts swap calldata to a new input amount
/// @dev Contract address: 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D (same on all chains)
///      The ScaleHelper decodes SwapExecutionParams, walks through targetData to identify each DEX-specific
///      sub-call, and proportionally adjusts intermediate amounts. Returns isSuccess=false when the route
///      contains non-scalable DEX sources or the deviation exceeds +/-5%.
interface IScaleHelper {
    /// @notice Scale swap calldata to a new input amount
    /// @param inputData Pre-encoded txData for MetaAggregationRouterV2 (with 4-byte selector)
    /// @param newAmount The new desired input amount
    /// @return isSuccess Whether the scaling was successful (false if route contains non-scalable sources)
    /// @return newScaledData The re-encoded txData with proportionally adjusted amounts (including targetData)
    function getScaledInputData(
        bytes calldata inputData,
        uint256 newAmount
    )
        external
        view
        returns (bool isSuccess, bytes memory newScaledData);
}
