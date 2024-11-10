// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISentinel } from "../interfaces/sentinels/ISentinel.sol";
import { ISentinelDecoder } from "../interfaces/sentinels/ISentinelDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";

import "forge-std/console.sol";

contract RelayerSentinel is ISentinel, IRelayerSentinel {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public superRegistry;

    uint64 public CHAIN_ID;

    mapping(address => bool) public decoderWhitelist;
    mapping(address => bool) public moduleWhitelist;

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        if (block.chainid > type(uint64).max) {
            revert BLOCK_CHAIN_ID_OUT_OF_BOUNDS();
        }

        CHAIN_ID = uint64(block.chainid);

        superRegistry = ISuperRegistry(registry_);
    }

    modifier onlyRelayer() {
        if (msg.sender != superRegistry.getAddress(superRegistry.RELAYER_ID())) {
            revert NOT_RELAYER();
        }
        _;
    }

    modifier onlySentinelManager() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.RELAYER_SENTINEL_MANAGER())) revert NOT_RELAYER_MANAGER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        RELAYER MANAGER METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISentinel
    function addDecoderToWhitelist(address decoder_) external override onlySentinelManager {
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();
        decoderWhitelist[decoder_] = true;
        emit DecoderWhitelisted(decoder_);
    }

    /// @inheritdoc ISentinel
    function removeDecoderFromWhitelist(address decoder_) external override onlySentinelManager {
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();

        decoderWhitelist[decoder_] = false;
        emit DecoderRemovedFromWhitelist(decoder_);
    }

    /// @inheritdoc ISentinel
    function addModuleToWhitelist(address module_) external override onlySentinelManager {
        if (module_ == address(0)) revert ADDRESS_NOT_VALID();

        moduleWhitelist[module_] = true;
        emit ModuleWhitelisted(module_);
    }

    /// @inheritdoc ISentinel
    function removeModuleFromWhitelist(address module_) external override onlySentinelManager {
        if (module_ == address(0)) revert ADDRESS_NOT_VALID();

        moduleWhitelist[module_] = false;
        emit ModuleRemovedFromWhitelist(module_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISentinel
    function notify(address decoder_, bytes calldata data_, bool success_) external override {
        _notify(decoder_, data_, success_);
    }

    /// @inheritdoc IRelayerSentinel
    function receiveRelayerData(address target, bytes memory data) external override onlyRelayer {
        (bool success,) = target.call(data);
        if (!success) revert CALL_FAILED();
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // add chainId to the signature
    function _notify(address decoder_, bytes calldata data_, bool success_) private {
        if (!success_) revert CALL_FAILED();
        // don't allow forbidden or not configured intents to notify
        if (!moduleWhitelist[msg.sender]) revert NOT_WHITELISTED();
        // don't allow forbidden or not configured decoders to decode the action
        if (!decoderWhitelist[decoder_]) revert NOT_WHITELISTED();

        // @dev below is showing an example of transforming the data into the right format
        bytes memory relayerData = ISentinelDecoder(decoder_).extractSentinelData(data_);

        console.log("               RelayerSentinel: triggering relayer");

        ISuperRegistry registry = ISuperRegistry(superRegistry);

        emit Msg(CHAIN_ID, msg.sender, relayerData);

        console.log("               RelayerSentinel: triggered relayer");
    }
}
