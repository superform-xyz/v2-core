// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract HooksRegistry is SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public isHookRegistered;
    address[] public registeredHooks;

    constructor(address registry_) SuperRegistryImplementer(registry_) {}

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error HOOK_NOT_REGISTERED();
    error HOOK_ALREADY_REGISTERED();
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event HookRegistered(address indexed hook);
    event HookUnregistered(address indexed hook);

    modifier onlyHooksManager() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(keccak256("SUPER_RBAC_ID")));
        if (!rbac.hasRole(keccak256("HOOKS_MANAGER_ROLE"), msg.sender)) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    function registerHook(address hook_) external onlyHooksManager {
        if (isHookRegistered[hook_]) revert HOOK_ALREADY_REGISTERED();
        isHookRegistered[hook_] = true;
        registeredHooks.push(hook_);
        emit HookRegistered(hook_);
    }

    function unregisterHook(address hook_) external onlyHooksManager {
        if (!isHookRegistered[hook_]) revert HOOK_NOT_REGISTERED();
        isHookRegistered[hook_] = false;
        emit HookUnregistered(hook_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function getRegisteredHooks() external view returns (address[] memory) {
        return registeredHooks;
    }
}

