// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperRegistrySet(address superRegistry);
    event WhitelistedHook(address hook, bool allowed);
    /// @notice Emitted when a decoder is whitelisted.
    /// @param decoder The address of the decoder.
    event DecoderWhitelisted(address indexed decoder);

    /// @notice Emitted when a decoder is removed from the whitelist.
    /// @param decoder The address of the decoder.
    event DecoderRemovedFromWhitelist(address indexed decoder);

    /// @notice Emitted when a module is whitelisted.
    /// @param module The address of the module.
    event ModuleWhitelisted(address indexed module);

    /// @notice Emitted when a module is removed from the whitelist.
    /// @param module The address of the module.
    event ModuleRemovedFromWhitelist(address indexed module);
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

    /// @dev Add a decoder to the whitelist
    /// @param decoder_ The address of the decoder to whitelist
    function addDecoderToWhitelist(address decoder_) external;

    /// @dev Remove a decoder from the whitelist
    /// @param decoder_ The address of the decoder to remove from whitelist
    function removeDecoderFromWhitelist(address decoder_) external;

    /// @dev Notify the sentinel. `msg.sender` is the module.
    /// @param decoder_ The address of the decoder.
    /// @param target The target address.
    /// @param data_ The return data from the module.
    /// @param success_ Whether the module was successful.
    function notify(address decoder_, address target, bytes calldata data_, bool success_) external;
}
