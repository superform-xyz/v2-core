// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";
import { IRelayerSentinel } from "src/interfaces/sentinels/IRelayerSentinel.sol";

abstract contract BaseModule is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISentinel public relayerSentinel;
    ISuperRegistry public superRegistry;

    error ADDRESS_NOT_VALID();
    error NOT_RELAYER_MANAGER();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        superRegistry = ISuperRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the relayer sentinel.
    /// @param sentinel_ The address of the sentinel.
    function setRelayerSentinel(address sentinel_) external {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SENTINELS_MANAGER())) revert NOT_RELAYER_MANAGER();
        _setRelayerSentinel(sentinel_);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _setRelayerSentinel(address sentinel_) internal {
        if (sentinel_ == address(0)) revert ADDRESS_NOT_VALID();

        relayerSentinel = ISentinel(sentinel_);
    }

    function _notifyRelayerSentinel(address decoder, bytes memory data, bool success) internal {
        if (address(relayerSentinel) == address(0)) revert ADDRESS_NOT_VALID();

        relayerSentinel.notify(decoder, data, success);
    }
}
