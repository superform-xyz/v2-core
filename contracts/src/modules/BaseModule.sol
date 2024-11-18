// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";

abstract contract BaseModule is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISentinel public relayerSentinel;
    ISuperRegistry public superRegistry;

    error ADDRESS_NOT_VALID();
    error NOT_SENTINEL_CONFIGURATOR();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        superRegistry = ISuperRegistry(registry_);
    }

    modifier onlySentinelConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SENTINELS_CONFIGURATOR())) revert NOT_SENTINEL_CONFIGURATOR();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the relayer sentinel.
    /// @param sentinel_ The address of the sentinel.
    function setRelayerSentinel(address sentinel_) external onlySentinelConfigurator {
        _validateAddress(sentinel_);
        relayerSentinel = ISentinel(sentinel_);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Notify the relayer sentinel
    /// @param decoder The `ISentinelDecoder` address
    /// @param target The target address
    /// @param data The data sent to the Relayer
    /// @param success The success state
    function _notifyRelayerSentinel(address decoder, address target, bytes memory data, bool success) internal {
        // checks
        _validateAddress(address(relayerSentinel));

        // interactions
        relayerSentinel.notify(decoder, target, data, success);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _validateAddress(address addr_) private pure {
        if (addr_ == address(0)) revert ADDRESS_NOT_VALID();
    }
}
