// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperDestinationExecutor Interface
/// @author Superform Labs
/// @notice Interface for processing cross-chain execution requests on destination chains
/// @dev This interface defines the contract responsible for executing operations that originate
///      from another blockchain. It handles the receipt of bridged messages, account creation if needed,
///      and execution of the intended operation on the destination chain.
interface ISuperDestinationExecutor {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a bridged execution is received but the account has insufficient balance
    /// @param account The target account that lacks sufficient balance for execution
    /// @param token The token that is required but not available
    /// @param intentAmount The amount of tokens required for execution
    /// @param available The amount of tokens currently available
    event SuperDestinationExecutorReceivedButNotEnoughBalance(
        address indexed account, address indexed token, uint256 intentAmount, uint256 available
    );

    /// @notice Emitted when a bridged execution is received but the account has no hooks
    /// @param account The target account that lacks hooks for execution
    event SuperDestinationExecutorReceivedButNoHooks(address indexed account);

    /// @notice Emitted when a bridged execution is received but the root has already been used
    /// @param account The target account that has already used the root
    /// @param root The merkle root that has already been used
    event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root);

    /// @notice Emitted when a bridged execution completes successfully
    /// @param account The account on which the execution was performed
    event SuperDestinationExecutorExecuted(address indexed account);

    /// @notice Emitted when a new account is created during bridged execution
    /// @param account The address of the newly created account
    /// @param salt The deterministic salt used to create the account
    event AccountCreated(address indexed account, bytes32 salt);

    /// @notice Emitted when a bridged execution fails with an invalid intent amount
    /// @param account The account on which the execution failed
    /// @param token The token that was required but not available
    /// @param intentAmount The amount of tokens required for execution
    event SuperDestinationExecutorInvalidIntentAmount(
        address indexed account, address indexed token, uint256 intentAmount
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when the account is not a valid account
    error INVALID_ACCOUNT();

    /// @notice Emitted when the signature is invalid
    error INVALID_SIGNATURE();

    /// @notice Emitted when the address is not an account
    error ADDRESS_NOT_ACCOUNT();

    /// @notice Emitted when the account is not created
    error ACCOUNT_NOT_CREATED();

    /// @notice Emitted when the array length mismatch
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Emitted when the merkle root is already used
    error MERKLE_ROOT_ALREADY_USED();

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if a merkle root has already been used by an account
    /// @dev Used to prevent replay attacks in cross-chain message verification
    ///      Each valid merkle root should only be usable once per user account
    /// @param user The user account to check for merkle root usage
    /// @param merkleRoot The merkle root hash to verify usage status
    /// @return True if the merkle root has already been used by this account, false otherwise
    function isMerkleRootUsed(address user, bytes32 merkleRoot) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a cross-chain execution request that was bridged from another blockchain
    /// @dev This is the main entry point for cross-chain operations on the destination chain
    ///      The function handles several key tasks:
    ///      1. Verifies the bridged message using signature or merkle proof
    ///      2. Creates the target account if it doesn't exist yet
    ///      3. Ensures the account has sufficient balance for the operation
    ///      4. Executes the requested operation on the target account
    ///
    ///      Typically called by a bridge adapter contract after receiving a cross-chain message
    /// @param tokenSent The token address that was bridged to be used in the execution
    /// @param targetAccount The destination smart contract account to execute the operation on
    /// @param dstTokens The tokens required in the target account to proceed with the execution.
    /// @param intentAmounts The amounts required in the target account to proceed with the execution.
    /// @param initData Optional initialization data for creating a new account if needed
    /// @param executorCalldata The encoded execution data (typically a SuperExecutor entry)
    /// @param userSignatureData Verification data (signature or merkle proof) to validate the request
    function processBridgedExecution(
        address tokenSent,
        address targetAccount,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external;
}
