// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { BaseRegistry } from "src/utils/BaseRegistry.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { IHooksRegistry } from "src/interfaces/registries/IHooksRegistry.sol";

contract HooksRegistry is SuperRegistryImplementer, BaseRegistry, IHooksRegistry {
    constructor(address registry_) SuperRegistryImplementer(registry_) BaseRegistry("HooksRegistry") { }

    modifier onlyHookRegistryConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.HOOK_REGISTRY_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IHooksRegistry
    function delistHook(address hook_) external onlyHookRegistryConfigurator {
        _delistItem(hook_);
    }

    /// @inheritdoc IHooksRegistry
    function registerHook(address hook_) external {
        _registerItem(hook_);
    }

    /// @inheritdoc IHooksRegistry
    function acceptHookRegistration(address hook_) external onlyHookRegistryConfigurator {
        _acceptItemRegistration(hook_);
    }

    /// @inheritdoc IHooksRegistry
    function vote(address hook_) external {
        _vote(hook_);
    }
}
