// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IAccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol"; 
interface ISuperRbac is IAccessControlEnumerable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RoleUpdated(address indexed account, bytes32 indexed role, bool allowed);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ROLE();
    error NOT_AUTHORIZED();
    error INVALID_ACCOUNT();
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Add a role to an account.
    /// @param account_ The address of the account.
    /// @param role_ The role to add.
    /// @param allowed_ Whether the role is allowed.

    function setRole(address account_, bytes32 role_, bool allowed_) external;
}
