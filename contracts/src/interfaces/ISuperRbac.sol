// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RoleAdded(address indexed account, bytes32 indexed role, bool allowed);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ACCOUNT();
    error INVALID_ROLE();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Check if an account has a role.
     * @param account The address of the account.
     * @param role The role to check.
     * @return Whether the account has the role.
     */
    function hasRole(address account, bytes32 role) external view returns (bool);
}
