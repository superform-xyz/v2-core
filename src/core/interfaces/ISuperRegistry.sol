// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperRegistry
/// @author Superform Labs
/// @notice Interface for the central registry that manages system component addresses
/// @dev The SuperRegistry serves as a centralized directory for all component addresses in the system
///      It uses bytes32 IDs to map to component addresses, allowing for upgradability and configuration
///      Components can be executors, validators, oracles, and other system contracts
interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when an address is associated with an ID in the registry
    /// @param id The bytes32 identifier for the component
    /// @param addr The address being registered for the identifier
    event AddressSet(bytes32 indexed id, address indexed addr);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a function restricted to executors is called by a non-executor address
    error NOT_EXECUTOR();
    
    /// @notice Thrown when an operation references an invalid or unauthorized account
    error INVALID_ACCOUNT();
    
    /// @notice Thrown when an invalid address (typically zero address) is provided
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Associates an address with an identifier in the registry
    /// @dev This function should be access-controlled to authorized addresses only
    ///      System components are identified using standardized bytes32 IDs
    ///      Cannot set the address to the zero address
    /// @param id_ The bytes32 identifier for the component
    /// @param address_ The address to associate with the identifier
    function setAddress(bytes32 id_, address address_) external;

    /// @notice Registers an executor in the system
    /// @dev Executors are special components with permission to interact with protected contracts
    ///      This function should be highly restricted as executors have elevated privileges
    ///      Typically used for cross-chain executors, bridges, and core smart accounts
    /// @param id_ The bytes32 identifier for the executor
    /// @param address_ The address of the executor contract
    function setExecutor(bytes32 id_, address address_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieves the address associated with an identifier
    /// @dev Returns the zero address if the ID has not been registered
    ///      Core system components should validate that returned addresses are not zero
    /// @param id_ The bytes32 identifier to look up
    /// @return The address associated with the identifier, or address(0) if not found
    function getAddress(bytes32 id_) external view returns (address);

    /// @notice Verifies if an address is a registered executor with permission to call protected functions
    /// @dev Used by protected contracts to enforce access control
    ///      Executors have elevated privileges to perform operations across the system
    ///      This is a key security check to prevent unauthorized access to critical functions
    /// @param executor The address to check for executor permissions
    /// @return True if the address is a registered executor, false otherwise
    function isExecutorAllowed(address executor) external view returns (bool);
}
