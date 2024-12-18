// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperRbac {
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

    // roles
    /// @dev Get the ID of the admin role.
    function SUPER_ADMIN_ROLE() external view returns (bytes32);

    /// @dev Get the ID of the executor configurator role.
    function EXECUTOR_CONFIGURATOR() external view returns (bytes32);

    /// @dev Get the ID of the actions configurator role.
    function SUPER_ACTIONS_CONFIGURATOR() external view returns (bytes32);

    /// @dev Get the ID of the bridge gateway role.
    function BRIDGE_GATEWAY() external view returns (bytes32);

    /// @dev Get the ID of the sentinel configurator role.
    function SENTINEL_CONFIGURATOR() external view returns (bytes32);

    /// @dev Get the ID of the strategy oracle configurator role.
    function STRATEGY_ORACLE_CONFIGURATOR() external view returns (bytes32);

    /// @dev Get the ID of the executor role.
    function EXECUTOR() external view returns (bytes32);
}
