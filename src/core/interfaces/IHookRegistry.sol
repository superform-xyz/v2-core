// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IHookRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error HOOK_NOT_REGISTERED();
    error HOOK_ALREADY_REGISTERED();
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event HookRegistered(address indexed hook);
    event HookUnregistered(address indexed hook);

    /// @notice Register a hook
    /// @param hook_ The hook to register
    function registerHook(address hook_) external;

    /// @notice Unregister a hook
    /// @param hook_ The hook to unregister
    function unregisterHook(address hook_) external;

    /// @notice Get all registered hooks
    function getRegisteredHooks() external view returns (address[] memory);
}


