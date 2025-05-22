// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperExecutor
/// @author Superform Labs
/// @notice Interface for the executor component that processes hook execution sequences
/// @dev The executor is responsible for executing a sequence of hooks in order, processing
///      results between them, and managing the overall transaction flow
///      It acts as a middleware between user accounts and the hooks they want to execute
interface ISuperExecutor {
    /// @notice Input data structure for hook execution
    /// @dev Contains parallel arrays of hook addresses and their corresponding input data
    ///      Both arrays must have the same length, with each index corresponding to the same hook
    struct ExecutorEntry {
        /// @notice Ordered array of hook contract addresses to execute in sequence
        /// @dev Hooks are executed in the exact order provided, with state passed between them
        ///      Zero address entries are not allowed
        address[] hooksAddresses;
        /// @notice Corresponding hook-specific input data for each hook
        /// @dev Each bytes array contains ABI-encoded parameters for the corresponding hook
        ///      The encoding format is specific to each hook implementation
        bytes[] hooksData;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when trying to execute with an empty hooks array
    /// @dev A valid execution requires at least one hook to process
    error NO_HOOKS();

    /// @notice Thrown when a fee calculation results in an invalid amount
    /// @dev Typically occurs when a fee exceeds the available amount or is negative
    ///      Important for maintaining economic integrity in the system
    error INVALID_FEE();

    /// @notice Thrown when an unauthorized address attempts a restricted operation
    /// @dev Security measure to ensure only approved addresses can perform certain actions
    ///      Critical for maintaining system security and integrity
    error NOT_AUTHORIZED();

    /// @notice Thrown when the hooks addresses and data arrays have different lengths
    /// @dev Each hook address must have a corresponding data element
    ///      This ensures data integrity during execution sequences
    error LENGTH_MISMATCH();

    /// @notice Thrown when trying to use an executor that hasn't been initialized for an account
    /// @dev Executors must be properly initialized before use to ensure correct state
    error NOT_INITIALIZED();

    /// @notice Thrown when a manager address is required but not set
    /// @dev The manager is needed for certain privileged operations
    ///      Particularly important for rebalancing governance
    error MANAGER_NOT_SET();

    /// @notice Thrown when an operation references an invalid chain ID
    /// @dev Cross-chain operations must use valid destination chain identifiers
    ///      Essential for multi-chain SuperUSD deployments
    error INVALID_CHAIN_ID();

    /// @notice Thrown when an invalid address (typically zero address) is provided
    /// @dev Prevents operations with problematic address values
    ///      Zero addresses are generally not allowed as hooks or recipients
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when trying to initialize an executor that's already initialized
    /// @dev Prevents duplicate initialization which could reset important state
    error ALREADY_INITIALIZED();

    /// @notice Thrown when a fee transfer fails to complete correctly
    /// @dev Used to detect potential issues with the fee transfer mechanism
    error FEE_NOT_TRANSFERRED();

    /// @notice Thrown when an account has insufficient balance to pay required fees
    /// @dev Ensures operations only proceed when proper compensation can be provided
    error INSUFFICIENT_BALANCE_FOR_FEE();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a cross-chain SuperPosition mint is requested
    /// @dev This event signals that a position should be minted on another chain
    /// @param account The account that will receive the minted SuperPosition
    /// @param spToken The SuperPosition token address to be minted
    /// @param amount The amount of tokens to mint, in the token's native units
    /// @param dstChainId The destination chain ID where the mint will occur
    event SuperPositionMintRequested(
        address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId
    );

    /*//////////////////////////////////////////////////////////////
                                  VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if an account has initialized this executor
    /// @dev Used to verify if an account has permission to use this executor
    /// @param account The address to check initialization status for
    /// @return True if the account is initialized, false otherwise
    function isInitialized(address account) external view returns (bool);

    /// @notice Returns the name of the executor implementation
    /// @dev Must be implemented by each executor to identify its type
    /// @return The name string of the specific executor implementation
    function name() external view returns (string memory);

    /// @notice Returns the version of the executor implementation
    /// @dev Used for tracking implementation version for upgrades and compatibility
    /// @return The version string of the specific executor implementation
    function version() external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                                  EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handles module installation for an account
    /// @dev Called by the ERC-7579 account during module installation
    ///      Sets up the initialization status for the calling account
    /// @param data Installation data (may be used by specific implementations)
    function onInstall(bytes calldata data) external;

    /// @notice Handles module uninstallation for an account
    /// @dev Called by the ERC-7579 account during module removal
    ///      Clears the initialization status for the calling account
    /// @param data Uninstallation data (may be used by specific implementations)
    function onUninstall(bytes calldata data) external;

    /// @notice Executes a sequence of hooks with their respective parameters
    /// @dev The main entry point for executing hook sequences
    ///      The input data should be encoded ExecutorEntry struct
    ///      Hooks are executed in sequence, with results from each hook potentially
    ///      influencing the execution of subsequent hooks
    ///      Each hook's execution involves calling preExecute, build, and postExecute
    /// @param data ABI-encoded ExecutorEntry containing hooks and their parameters
    function execute(bytes calldata data) external;
}
