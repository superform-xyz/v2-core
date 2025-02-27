// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IAccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

interface ISuperRegistry is IAccessControlEnumerable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AddressSet(bytes32 indexed id, address indexed addr);
    event RoleUpdated(address indexed account, bytes32 indexed role, bool allowed);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ROLE();
    error INVALID_ACCOUNT();
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Add a role to an account.
    /// @param account_ The address of the account.
    /// @param role_ The role to add.
    /// @param allowed_ Whether the role is allowed.
    function setRole(address account_, bytes32 role_, bool allowed_) external;

    /// @dev Set the address of an ID.
    /// @param id_ The ID.
    /// @param address_ The address.
    function setAddress(bytes32 id_, address address_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);
}
