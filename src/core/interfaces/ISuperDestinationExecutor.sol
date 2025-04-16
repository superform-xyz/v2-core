// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @title ISuperDestinationExecutor Interface
/// @notice Defines the standard interface for receiving bridged executions.
interface ISuperDestinationExecutor {
    /// @notice Processes a bridged execution request, typically called by an adapter contract.
    /// @param tokenSent The token that was bridged and should be used for the execution.
    /// @param amountReceived The actual amount of `tokenSent` received by the adapter/caller.
    /// @param targetAccount The target smart contract account for the execution.
    /// @param intentAmount The amount required in the target account to proceed with the execution.
    /// @param initData Optional initialization data for creating the target account if it doesn't exist.
    /// @param executorCalldata The calldata for the execution logic to be run on the target account.
    /// @param userSignatureData The signature data provided by the user for validation.
    function processBridgedExecution(
        address tokenSent,
        uint256 amountReceived, // Note: This parameter might be redundant if balance check suffices
        address targetAccount,
        uint256 intentAmount,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external;

    // Add relevant events if adapters need to listen to them, or define them only in the implementation
    // Example events that might be useful (mirroring old ones):
    // event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account);
    // event SuperDestinationExecutorReceivedButNoHooks(address indexed account);
    // event SuperDestinationExecutorExecuted(address indexed account);
    // event SuperDestinationExecutorFailed(address indexed account, string reason);
    // event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData);
    // event AccountCreated(address indexed account, bytes32 salt);
}
