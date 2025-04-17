// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @title ISuperDestinationExecutor Interface
/// @notice Defines the standard interface for receiving bridged executions.
interface ISuperDestinationExecutor {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account);
    event SuperDestinationExecutorReceivedButNoHooks(address indexed account);
    event SuperDestinationExecutorExecuted(address indexed account);
    event SuperDestinationExecutorFailed(address indexed account, string reason);
    event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData);
    event AccountCreated(address indexed account, bytes32 salt);

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the nonce for an account
    /// @param account The account to get the nonce for
    /// @return The nonce for the account
    function nonces(address account) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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