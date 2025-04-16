// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @title ISuperDestinationExecutor Interface
/// @notice Defines the standard interface for receiving bridged executions.
interface ISuperDestinationExecutor {
    /// @notice Processes a bridged execution request, typically called by an adapter contract.
    /// @param tokenSent The token that was bridged and should be used for the execution.
    /// @param targetAccount The target smart contract account for the execution.
    /// @param intentAmount The amount required in the target account to proceed with the execution.
    /// @param initData Optional initialization data for creating the target account if it doesn't exist.
    /// @param executorCalldata The calldata for the execution logic to be run on the target account.
    /// @param userSignatureData The signature data provided by the user for validation.
    function processBridgedExecution(
        address tokenSent,
        address targetAccount,
        uint256 intentAmount,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external;
}
