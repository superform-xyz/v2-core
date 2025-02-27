// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { IPeripheryRegistry } from "../../../src/periphery/interfaces/IPeripheryRegistry.sol";

contract PeripheryRegistryTest is BaseTest {
    PeripheryRegistry peripheryRegistry;
    address testHook = address(0x2);

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        peripheryRegistry = new PeripheryRegistry(address(this), TREASURY);
        vm.label(address(peripheryRegistry), "PeripheryRegistry");
    }

    function testRegisterHook_Success() public {
        peripheryRegistry.registerHook(testHook);
        assertTrue(peripheryRegistry.isHookRegistered(testHook));
    }

    function testRegisterHook_Fail_NotAuthorized() public {
        vm.prank(address(0x1));
        vm.expectRevert();
        peripheryRegistry.registerHook(testHook);
    }

    function testUnregisterHook_Success() public {
        peripheryRegistry.registerHook(testHook);

        peripheryRegistry.unregisterHook(testHook);
        assertFalse(peripheryRegistry.isHookRegistered(testHook));
    }

    function testUnregisterHook_Fail_NotRegistered() public {
        vm.expectRevert(IPeripheryRegistry.HOOK_NOT_REGISTERED.selector);
        peripheryRegistry.unregisterHook(testHook);
    }

    function testGetRegisteredHooks() public {
        peripheryRegistry.registerHook(testHook);

        address[] memory hooks = peripheryRegistry.getRegisteredHooks();
        assertEq(hooks.length, 1);
        assertEq(hooks[0], testHook);
    }
}
