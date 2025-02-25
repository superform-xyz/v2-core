// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IHookRegistry } from "../interfaces/IHookRegistry.sol";

contract HooksRegistry is SuperRegistryImplementer, IHookRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public isHookRegistered;
    address[] private registeredHooks;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    modifier onlyHooksManager() {
        if (!superRegistry.hasRole(keccak256("HOOKS_MANAGER_ROLE"), msg.sender)) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IHookRegistry
    function registerHook(address hook_) external onlyHooksManager {
        if (isHookRegistered[hook_]) revert HOOK_ALREADY_REGISTERED();
        isHookRegistered[hook_] = true;
        registeredHooks.push(hook_);
        emit HookRegistered(hook_);
    }

    /// @inheritdoc IHookRegistry
    function unregisterHook(address hook_) external onlyHooksManager {
        if (!isHookRegistered[hook_]) revert HOOK_NOT_REGISTERED();
        isHookRegistered[hook_] = false;
        emit HookUnregistered(hook_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IHookRegistry
    function getRegisteredHooks() external view returns (address[] memory) {
        return registeredHooks;
    }
}
