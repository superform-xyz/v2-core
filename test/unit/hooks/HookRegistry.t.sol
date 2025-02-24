// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { HooksRegistry } from "../../../src/core/hooks/HooksRegistry.sol";
import { IHookRegistry } from "../../../src/core/interfaces/IHookRegistry.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";

contract HooksRegistryTest is BaseTest {
    HooksRegistry hooksRegistry;
    address testHook = address(0x2);

    SuperRegistry public superRegistry;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        superRegistry = SuperRegistry(_getContract(ETH, SUPER_REGISTRY_KEY));
        hooksRegistry = new HooksRegistry(address(superRegistry));
        vm.label(address(hooksRegistry), "HooksRegistry");

        superRegistry.grantRole(keccak256("HOOKS_MANAGER_ROLE"), address(this));
    }

    function testRegisterHook_Success() public {
        hooksRegistry.registerHook(testHook);
        assertTrue(hooksRegistry.isHookRegistered(testHook));
    }

    function testRegisterHook_Fail_NotAuthorized() public {
        vm.prank(address(0x1));
        vm.expectRevert(IHookRegistry.NOT_AUTHORIZED.selector);
        hooksRegistry.registerHook(testHook);
    }

    function testUnregisterHook_Success() public {
        hooksRegistry.registerHook(testHook);
        
        hooksRegistry.unregisterHook(testHook);
        assertFalse(hooksRegistry.isHookRegistered(testHook));
    }

    function testUnregisterHook_Fail_NotRegistered() public {
        vm.expectRevert(IHookRegistry.HOOK_NOT_REGISTERED.selector);
        hooksRegistry.unregisterHook(testHook);
    }

    function testGetRegisteredHooks() public {
        hooksRegistry.registerHook(testHook);
        
        address[] memory hooks = hooksRegistry.getRegisteredHooks();
        assertEq(hooks.length, 1);
        assertEq(hooks[0], testHook);
    }
}

