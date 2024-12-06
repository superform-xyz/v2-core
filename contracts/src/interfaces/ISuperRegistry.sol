// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SharedStateNamespaceSet(string namespace_);
    event AddressSet(bytes32 indexed id, address indexed addr);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Set the address of an ID.
    /// @param id_ The ID.
    /// @param address_ The address.
    function setAddress(bytes32 id_, address address_) external;

    /// @dev Set the namespace of the shared state.
    /// @param namespace_ The namespace.
    function setSharedStateNamespace(string memory namespace_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);

    /// @dev Get the namespace of the shared state.
    /// @return The namespace.
    function sharedStateNamespace() external view returns (string memory);

    // ids
    /// @dev Get the ID of the SuperRbac.
    function SUPER_RBAC_ID() external view returns (bytes32);

    /// @dev Get the ID of the super positions.
    function SUPER_POSITIONS_ID() external view returns (bytes32);

    /// @dev Get the ID of the strategies registry.
    function STRATEGIES_REGISTRY_ID() external view returns (bytes32);

    /// @dev Get the ID of the Across bridge gateway.
    function ACROSS_GATEWAY_ID() external view returns (bytes32);

    /// @dev Get the ID of the super gateway executor.
    function SUPER_GATEWAY_EXECUTOR_ID() external view returns (bytes32);

    /// @dev Get the ID of the shared state.
    function SHARED_STATE_ID() external view returns (bytes32);
}
