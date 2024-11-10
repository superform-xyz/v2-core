// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface IRelayerSentinel {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/
    enum ModuleNotificationType {
        Forbidden, // can be used as a blacklist/default
        Deposit4626
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ADDRESS_NOT_VALID();
    error NOT_RELAYER_MANAGER();
    error BLOCK_CHAIN_ID_OUT_OF_BOUNDS()M

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when the notification type for an module is set.
    /// @param module The address of the module.
    /// @param notificationType The notification type.
    event ModuleNotificationTypeSet(address indexed module, ModuleNotificationType notificationType);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the decoder address.
    /// @return The decoder address.
    function decoder() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the notification type for an module.
    /// @param module_ The address of the module.
    /// @param notificationType_ The notification type.
    function setModuleNotificationType(address module_, ModuleNotificationType notificationType_) external;
}
