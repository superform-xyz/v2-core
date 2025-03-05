// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { IPeripheryRegistry } from "../../../src/periphery/interfaces/IPeripheryRegistry.sol";

contract PeripheryRegistryTest is BaseTest {
    PeripheryRegistry peripheryRegistry;
    address testHook = address(0x2);
    address testFulfillHook = address(0x3);

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        peripheryRegistry = new PeripheryRegistry(address(this), TREASURY);
        vm.label(address(peripheryRegistry), "PeripheryRegistry");
    }

    function testRegisterHook_RegularHook_Success() public {
        peripheryRegistry.registerHook(testHook, false);
        assertTrue(peripheryRegistry.isHookRegistered(testHook));
        assertFalse(peripheryRegistry.isFulfillRequestsHookRegistered(testHook));
    }

    function testRegisterHook_FulfillHook_Success() public {
        peripheryRegistry.registerHook(testFulfillHook, true);
        assertTrue(peripheryRegistry.isFulfillRequestsHookRegistered(testFulfillHook));
        assertFalse(peripheryRegistry.isHookRegistered(testFulfillHook));
    }

    function testRegisterHook_Fail_NotAuthorized() public {
        vm.prank(address(0x1));
        vm.expectRevert();
        peripheryRegistry.registerHook(testHook, false);
    }

    function testRegisterHook_Fail_ZeroAddress() public {
        vm.expectRevert(IPeripheryRegistry.INVALID_ADDRESS.selector);
        peripheryRegistry.registerHook(address(0), false);

        vm.expectRevert(IPeripheryRegistry.INVALID_ADDRESS.selector);
        peripheryRegistry.registerHook(address(0), true);
    }

    function testRegisterHook_Fail_AlreadyRegistered() public {
        // Test regular hook
        peripheryRegistry.registerHook(testHook, false);
        vm.expectRevert(IPeripheryRegistry.HOOK_ALREADY_REGISTERED.selector);
        peripheryRegistry.registerHook(testHook, false);

        // Test fulfill hook
        peripheryRegistry.registerHook(testFulfillHook, true);
        vm.expectRevert(IPeripheryRegistry.HOOK_ALREADY_REGISTERED.selector);
        peripheryRegistry.registerHook(testFulfillHook, true);
    }

    function testUnregisterHook_RegularHook_Success() public {
        peripheryRegistry.registerHook(testHook, false);
        assertTrue(peripheryRegistry.isHookRegistered(testHook));

        peripheryRegistry.unregisterHook(testHook, false);
        assertFalse(peripheryRegistry.isHookRegistered(testHook));
    }

    function testUnregisterHook_FulfillHook_Success() public {
        peripheryRegistry.registerHook(testFulfillHook, true);
        assertTrue(peripheryRegistry.isFulfillRequestsHookRegistered(testFulfillHook));

        peripheryRegistry.unregisterHook(testFulfillHook, true);
        assertFalse(peripheryRegistry.isFulfillRequestsHookRegistered(testFulfillHook));
    }

    function testUnregisterHook_Fail_NotRegistered() public {
        vm.expectRevert(IPeripheryRegistry.HOOK_NOT_REGISTERED.selector);
        peripheryRegistry.unregisterHook(testHook, false);

        vm.expectRevert(IPeripheryRegistry.HOOK_NOT_REGISTERED.selector);
        peripheryRegistry.unregisterHook(testFulfillHook, true);
    }

    function testUnregisterHook_Fail_ZeroAddress() public {
        vm.expectRevert(IPeripheryRegistry.INVALID_ADDRESS.selector);
        peripheryRegistry.unregisterHook(address(0), false);

        vm.expectRevert(IPeripheryRegistry.INVALID_ADDRESS.selector);
        peripheryRegistry.unregisterHook(address(0), true);
    }

    function testUnregisterHook_Fail_NotAuthorized() public {
        vm.prank(address(0x1));
        vm.expectRevert();
        peripheryRegistry.unregisterHook(testHook, false);
    }

    function testGetRegisteredHooks_RegularHooks() public {
        peripheryRegistry.registerHook(testHook, false);
        address[] memory hooks = peripheryRegistry.getRegisteredHooks();
        assertEq(hooks.length, 1);
        assertEq(hooks[0], testHook);
    }

    function testMultipleHooks_Registration() public {
        // Register multiple hooks of each type
        address[] memory regularHooks = new address[](3);
        address[] memory fulfillHooks = new address[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            regularHooks[i] = address(uint160(0x100 + i));
            fulfillHooks[i] = address(uint160(0x200 + i));
            
            peripheryRegistry.registerHook(regularHooks[i], false);
            peripheryRegistry.registerHook(fulfillHooks[i], true);
        }

        // Verify regular hooks
        address[] memory registeredHooks = peripheryRegistry.getRegisteredHooks();
        assertEq(registeredHooks.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(registeredHooks[i], regularHooks[i]);
            assertTrue(peripheryRegistry.isHookRegistered(regularHooks[i]));
        }

        // Verify fulfill hooks
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(peripheryRegistry.isFulfillRequestsHookRegistered(fulfillHooks[i]));
        }

        // Unregister middle hooks
        peripheryRegistry.unregisterHook(regularHooks[1], false);
        peripheryRegistry.unregisterHook(fulfillHooks[1], true);

        // Verify updated arrays and mappings
        registeredHooks = peripheryRegistry.getRegisteredHooks();
        assertEq(registeredHooks.length, 2);
        assertFalse(peripheryRegistry.isHookRegistered(regularHooks[1]));
        assertFalse(peripheryRegistry.isFulfillRequestsHookRegistered(fulfillHooks[1]));
    }
}
