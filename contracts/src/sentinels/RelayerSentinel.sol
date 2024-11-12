// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ExcessivelySafeCall } from "excessivelySafeCall/ExcessivelySafeCall.sol";

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISentinel } from "../interfaces/sentinels/ISentinel.sol";
import { ISentinelDecoder } from "../interfaces/sentinels/ISentinelDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";

contract RelayerSentinel is ISentinel, IRelayerSentinel {
    using ExcessivelySafeCall for address;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISuperRegistry public superRegistry;
    mapping(address => bool) public decoderWhitelist;

    uint64 public constant SUPER_CHAIN_ID = 98;
    uint16 public constant MAX_COPY = 255;

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        superRegistry = ISuperRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyRelayer() {
        if (msg.sender != superRegistry.getAddress(superRegistry.RELAYER_ID())) {
            revert NOT_RELAYER();
        }
        _;
    }

    modifier onlySentinelManager() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.RELAYER_SENTINEL_CONFIGURATOR())) revert NOT_SENTINEL_CONFIGURATOR();
        _;
    }

    modifier onlyRelayerSentinelNotifier() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.RELAYER_SENTINEL_NOTIFIER())) revert NOT_RELAYER_SENTINEL_NOTIFIER();
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

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISentinel
    function notify(
        address decoder_,
        address target,
        bytes calldata data_,
        bool success_
    )
        external
        override
        onlyRelayerSentinelNotifier
    {
        _notify(decoder_, target, data_, success_);
    }

    /// @inheritdoc IRelayerSentinel
    function receiveRelayerData(address target, bytes memory data) external payable override onlyRelayer {
        (bool success,) = target.excessivelySafeCall(gasleft(), msg.value, MAX_COPY, data);
        if (!success) revert CALL_FAILED();
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // add chainId to the signature
    function _notify(address decoder_, address target, bytes calldata data_, bool success_) private {
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();
        if (!success_) revert CALL_FAILED();
        // don't allow forbidden or not configured decoders to decode the action
        if (!decoderWhitelist[decoder_]) revert NOT_WHITELISTED();

        // @dev below is showing an example of transforming the data into the right format
        bytes memory relayerData = ISentinelDecoder(decoder_).extractSentinelData(data_);

        emit Msg(SUPER_CHAIN_ID, target, relayerData);
    }
}
