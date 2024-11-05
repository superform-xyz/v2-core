// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

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
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Check if the hook is allowed to trigger the sentinel.
    /// @param hook_ The address of the hook.
    /// @return Whether the hook is allowed.
    function allowed(address hook_) external view returns (bool);

    /// @dev Get the length of the hook entries.
    /// @param hook_ The address of the hook.
    /// @return The length of the hook entries.
    function entriesLength(address hook_) external view returns (uint256);

    /// @dev Get the nonce of the hook.
    /// @param hook_ The address of the hook.
    /// @param index_ The index of the entry.
    /// @return The entry of the hook.
    function entry(address hook_, uint256 index_) external view returns (Entry memory);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Notify the sentinel from an 7579 account.
    /// @param data_ Additional data to pass.
    function notifyFromAccount(bytes calldata data_) external;

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
