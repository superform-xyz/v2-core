// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperRegistry
/// @author Superform Labs
/// @notice Interface for the central registry
/// @dev The SuperRegistry serves as a centralized directory for all component addresses in the system
///      It uses bytes32 IDs to map to component addresses, allowing for upgradability and configuration
///      Components can be executors, validators, oracles, and other system contracts
interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when an address is associated with an ID in the registry
    /// @dev Important for audit trails and tracking changes to the system's component addresses
    /// @param id The bytes32 identifier for the component
    /// @param addr The address being registered for the identifier
    event AddressSet(bytes32 indexed id, address indexed addr);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a function restricted to executors is called by a non-executor address
    /// @dev Used by protected contracts to enforce access control
    ///      Executors have elevated privileges to perform operations across the system
    error NOT_EXECUTOR();
    
    /// @notice Thrown when an operation references an invalid or unauthorized account
    /// @dev Ensures operations are performed only on valid accounts
    ///      Important for maintaining system integrity during rebalancing
    error INVALID_ACCOUNT();
    
    /// @notice Thrown when an invalid address (typically zero address) is provided
    /// @dev Prevents critical components from being set to unusable addresses
    ///      Particularly important for oracle and circuit breaker components
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Associates an address with an identifier in the registry
    /// @dev This function configures the essential components of the Superform system
    ///      Key components registered include:
    ///      - Protocol validators for cross-chain operations
    ///      - Executors for processing transactions
    ///      - Oracle providers for required data
    ///      - Bridge adapters for cross-chain communication
    ///      
    ///      Access is strictly controlled to prevent unauthorized modifications
    ///      that could compromise the system security
    /// @param id_ The bytes32 identifier for the component
    /// @param address_ The address to associate with the identifier
    function setAddress(bytes32 id_, address address_) external;

    /// @notice Registers an executor in the system
    /// @dev Executors are critical components that can initiate and execute operations
    ///      In the Superform system, executors are responsible for:
    ///      1. Processing user transactions
    ///      2. Executing cross-chain operations
    ///      3. Managing the execution flow through hooks
    ///      4. Ensuring proper transaction validation
    ///      
    ///      This function is highly access-controlled as executors can modify
    ///      system state and trigger critical events across chains
    /// @param id_ The bytes32 identifier for the executor
    /// @param address_ The address of the executor contract
    function setExecutor(bytes32 id_, address address_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieves the address associated with an identifier
    /// @dev Used throughout the system to locate component addresses dynamically
    ///      Critical for finding the correct:
    ///      - Validator modules for operation verification
    ///      - Executor contracts for transaction processing
    ///      - Bridge adapters for cross-chain communication
    ///      - Hook implementations for execution extensions
    ///      
    ///      Components must verify addresses are not zero before interaction
    /// @param id_ The bytes32 identifier to look up
    /// @return The address associated with the identifier, or address(0) if not found
    function getAddress(bytes32 id_) external view returns (address);

    /// @notice Verifies if an address is a registered executor with permission to call protected functions
    /// @dev Core security function that protects the Superform system from unauthorized access
    ///      Used by components to verify that only authorized executors can:
    ///      1. Process cross-chain operations
    ///      2. Execute user transactions
    ///      3. Interact with validator modules
    ///      4. Manage critical system parameters
    ///      
    ///      This check is critical for maintaining system security and preventing unauthorized operations
    /// @param executor The address to check for executor permissions
    /// @return True if the address is a registered executor, false otherwise
    function isExecutorAllowed(address executor) external view returns (bool);
}
