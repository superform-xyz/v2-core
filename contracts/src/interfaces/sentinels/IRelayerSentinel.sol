// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface IRelayerSentinel {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/
    enum IntentNotificationType {
        Forbidden, // can be used as a blacklist/default
        Deposit4626
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ADDRESS_NOT_VALID();
    error NOT_RELAYER_MANAGER();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when the notification type for an intent is set.
    /// @param intent The address of the intent.
    /// @param notificationType The notification type.
    event IntentNotificationTypeSet(address indexed intent, IntentNotificationType notificationType);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the decoder address.
    /// @return The decoder address.
    function decoder() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the notification type for an intent.
    /// @param intent_ The address of the intent.
    /// @param notificationType_ The notification type.
    function setIntentNotificationType(address intent_, IntentNotificationType notificationType_) external;
}
