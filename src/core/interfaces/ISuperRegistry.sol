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
    /// @dev This function configures the essential components of the SuperUSD system
    ///      Key components registered include:
    ///      - K coefficient calculators that determine stablecoin weightings
    ///      - Oracle providers for price and allocation data
    ///      - Circuit breaker controllers for depeg protection
    ///      - Yield source adapters for different stablecoins
    ///      
    ///      Access is strictly controlled to prevent unauthorized modifications
    ///      that could compromise the potential energy model
    /// @param id_ The bytes32 identifier for the component
    /// @param address_ The address to associate with the identifier
    function setAddress(bytes32 id_, address address_) external;

    /// @notice Registers an executor in the system
    /// @dev Executors are critical components that can initiate and execute rebalancing operations
    ///      In the potential energy model, executors are responsible for:
    ///      1. Identifying favorable energy gradients between stablecoins
    ///      2. Executing transitions between allocation targets
    ///      3. Triggering circuit breakers during depeg events
    ///      4. Managing cross-chain position transfers
    ///      
    ///      This function is highly access-controlled as executors can modify
    ///      positions and trigger rebalancing events across the system
    /// @param id_ The bytes32 identifier for the executor
    /// @param address_ The address of the executor contract
    function setExecutor(bytes32 id_, address address_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieves the address associated with an identifier
    /// @dev Used throughout the system to locate component addresses dynamically
    ///      Critical for finding the correct:
    ///      - K coefficient calculators for specific stablecoin types
    ///      - Oracle providers for price and allocation targets
    ///      - Circuit breaker controllers for different depeg scenarios
    ///      - Yield sources supported by the system
    ///      
    ///      Components must verify addresses are not zero before interaction
    /// @param id_ The bytes32 identifier to look up
    /// @return The address associated with the identifier, or address(0) if not found
    function getAddress(bytes32 id_) external view returns (address);

    /// @notice Verifies if an address is a registered executor with permission to call protected functions
    /// @dev Core security function that protects the potential energy model from manipulation
    ///      Used by components to verify that only authorized executors can:
    ///      1. Initiate rebalancing between different stablecoins
    ///      2. Modify K coefficients for stablecoin weightings
    ///      3. Trigger circuit breakers during market stress
    ///      4. Update target allocations based on yield opportunities
    ///      
    ///      This check is critical for maintaining system security at billion-dollar scale
    /// @param executor The address to check for executor permissions
    /// @return True if the address is a registered executor, false otherwise
    function isExecutorAllowed(address executor) external view returns (bool);
}
