// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
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

    uint64 public CHAIN_ID;

    mapping(address => ModuleNotificationType) public moduleNotificationTypes;

    constructor(address registry_, address decoder_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();

        if (block.chainid > type(uint64).max) {
            revert BLOCK_CHAIN_ID_OUT_OF_BOUNDS();
        }

        CHAIN_ID = uint64(block.chainid);

        superRegistry = registry_;
        decoder = decoder_;
    }

    modifier onlyRelayerManager() {
        ISuperRegistry registry = ISuperRegistry(superRegistry);
        ISuperRbac rbac = ISuperRbac(registry.getAddress(registry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.RELAYER_SENTINEL_MANAGER())) revert NOT_RELAYER_MANAGER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    function setModuleNotificationType(
        address module_,
        ModuleNotificationType notificationType_
    )
        external
        override
        onlyRelayerManager
    {
        moduleNotificationTypes[module_] = notificationType_;
        emit ModuleNotificationTypeSet(module_, notificationType_);
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
        if (moduleNotificationTypes[msg.sender] == ModuleNotificationType.Forbidden) return;

        // @dev below is showing an example of transforming the data into the right format
        bytes memory relayerData =
            IRelayerDecoder(decoder).extractRelayerMessage(data_, output_, moduleNotificationTypes[msg.sender]);

        console.log(
            "RelayerSentinel: notification received for type {%s}", uint256(moduleNotificationTypes[msg.sender])
        );
        console.log("               RelayerSentinel: triggering relayer");

        ISuperRegistry registry = ISuperRegistry(superRegistry);

        emit Msg(CHAIN_ID, msg.sender, relayerData);

        console.log("               RelayerSentinel: triggered relayer");
    }
}
