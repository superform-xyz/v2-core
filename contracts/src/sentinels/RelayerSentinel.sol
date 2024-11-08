// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { IRelayer } from "../interfaces/relayer/IRelayer.sol";
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISentinel } from "../interfaces/sentinels/ISentinel.sol";
import { IRelayerDecoder } from "../interfaces/sentinels/IRelayerDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";

import "forge-std/console.sol";

contract RelayerSentinel is ISentinel, IRelayerSentinel {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public decoder;
    address public superRegistry;

    mapping(address => IntentNotificationType) public intentNotificationTypes;

    constructor(address registry_, address decoder_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();

        decoder = decoder_;
        superRegistry = registry_;
    }

    modifier onlyRelayerManager() {
        ISuperRegistry _registry = ISuperRegistry(superRegistry);
        ISuperRbac rbac = ISuperRbac(_registry.getAddress(_registry.ROLES_ID()));
        if (!rbac.hasRole(msg.sender, _registry.RELAYER_SENTINEL_MANAGER())) revert NOT_RELAYER_MANAGER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    function setIntentNotificationType(
        address intent_,
        IntentNotificationType notificationType_
    )
        external
        override
        onlyRelayerManager
    {
        intentNotificationTypes[intent_] = notificationType_;
        emit IntentNotificationTypeSet(intent_, notificationType_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel
    function notify(bytes calldata data_, bytes calldata output_, bool success_) external override {
        _notify(data_, output_, success_);
    }

    /// @inheritdoc ISentinel
    function batchNotify(
        bytes[] calldata data_,
        bytes[] calldata output_,
        bool[] calldata success_
    )
        external
        override
    {
        uint256 length = data_.length;
        for (uint256 i; i < length; i++) {
            _notify(data_[i], output_[i], success_[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // add chainId to the signature
    function _notify(bytes calldata data_, bytes calldata output_, bool success_) private {
        // don't allow forbidden or not configured intents to notify
        if (intentNotificationTypes[msg.sender] == IntentNotificationType.Forbidden) return;

        // @dev below is showing an example of transforming the data into the right format
        bytes memory relayerData =
            IRelayerDecoder(decoder).extractRelayerMessage(data_, output_, intentNotificationTypes[msg.sender]);

        console.log(
            "               RelayerSentinel: notification received for type {%s}",
            uint256(intentNotificationTypes[msg.sender])
        );
        console.log("               RelayerSentinel: triggering relayer");

        ISuperRegistry _registry = ISuperRegistry(superRegistry);
        IRelayer relayer = IRelayer(_registry.getAddress(_registry.RELAYER_ID()));

        relayer.send(block.chainid, msg.sender, relayerData);
        console.log("               RelayerSentinel: triggered relayer");
    }

    function _extractDeposit4626Data(
        bytes calldata data_,
        bytes calldata output_
    )
        private
        view
        returns (bytes memory)
    {
        (address account, uint256 amountIn) = abi.decode(data_, (address, uint256));
        uint256 amountOut = abi.decode(output_, (uint256));

        return abi.encode(account, intentNotificationTypes[msg.sender], amountIn, amountOut);
    }
}
