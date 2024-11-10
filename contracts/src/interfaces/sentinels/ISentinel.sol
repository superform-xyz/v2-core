// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperRegistrySet(address superRegistry);
    event WhitelistedHook(address hook, bool allowed);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Entry struct.
    struct Entry {
        bytes input;
        bytes output;
        bool success;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_HOOK();
    error NOTIFIER_NOT_ALLOWED();
    error INVALID_SUPER_REGISTRY();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Notify the sentinel. `msg.sender` is the hook.
    /// @param input_ Additional data to pass to the hook.
    /// @param output_ The return data from the hook.
    /// @param success_ Whether the hook was successful.
    function notify(bytes calldata input_, bytes calldata output_, bool success_) external;

    /// @dev Batch notify the sentinel. `msg.sender` is the hook.
    /// @param input_ Additional data to pass to the hooks.
    /// @param output_ The return data from the hooks.
    /// @param success_ Whether the hooks were successful.
    function batchNotify(bytes[] calldata input_, bytes[] calldata output_, bool[] calldata success_) external;
}
