// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

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
    error NOT_WHITELISTED();
    error BLOCK_CHAIN_ID_OUT_OF_BOUNDS();
    error CALL_FAILED();
    error INVALID_LENGTH();
    error NOT_RELAYER();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when the notification type for an module is set.
    /// @param module The address of the module.
    /// @param notificationType The notification type.
    event ModuleNotificationTypeSet(address indexed module, ModuleNotificationType notificationType);

    /// @notice Emitted when a message is sent.
    /// @param destinationChainId The originating chain ID.
    /// @param destinationContract The sender contract address.
    /// @param data The data.
    event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Receive relayer data.
    /// @param target The target address.
    /// @param data The data.
    function receiveRelayerData(address target, bytes memory data) external;
}
