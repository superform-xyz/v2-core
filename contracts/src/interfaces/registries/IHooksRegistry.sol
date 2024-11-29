// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IHooksRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Vote for an item
    /// @param item_ The address of the item to vote for
    function vote(address item_) external;

    /// @notice Register an item
    /// @param item_ The address of the item to register
    function registerHook(address item_) external;

    /// @notice Delist an item
    /// @param item_ The address of the item to delist
    function delistHook(address item_) external;

    /// @notice Accept a pending item registration
    /// @param item_ The address of the item to accept the registration for
    function acceptHookRegistration(address item_) external;
}
