// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RolesSet(address indexed roles);
    event AddressSet(bytes32 indexed id, address indexed addr);
    event SuperRbacSet(address indexed superRbac);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);

    // ids
    /// @dev Get the ID of the hook type.
    /// @return The ID.
    function HOOK_TYPE_ID() external view returns (bytes32);

    /// @dev Get the ID of the hook manager.
    /// @return The ID.
    function HOOK_MANAGER_ID() external view returns (bytes32);

    /// @dev Get the ID of the SuperRbac.
    /// @return The ID.
    function ROLES_ID() external view returns (bytes32);

    // roles
    /// @dev Get the ID of the admin role.
    function ADMIN_ROLE() external view returns (bytes32);

    /// @dev Get the ID of the hook registration role.
    function HOOK_REGISTRATION_ROLE() external view returns (bytes32);

    /// @dev Get the ID of the hook executor role.
    function HOOK_EXECUTOR_ROLE() external view returns (bytes32);
}
