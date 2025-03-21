// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { BaseTest } from "../../BaseTest.t.sol";

import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { ISuperRegistry } from "../../../src/core/interfaces/ISuperRegistry.sol";

contract SuperRegistryTest is BaseTest {
    SuperRegistry public superRegistry;
    bytes32 public constant TEST_ID = keccak256("TEST_ID");
    bytes32 public constant EMPTY_ID = keccak256("EMPTY_ID");
    address public constant TEST_ADDRESS = address(0x123);

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        superRegistry = SuperRegistry(_getContract(ETH, SUPER_REGISTRY_KEY));
    }

    function test_Constructor() public {
        address owner = address(0xdead);
        SuperRegistry newRegistry = new SuperRegistry(owner);
        assertEq(newRegistry.owner(), owner);
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new SuperRegistry(address(0));
    }

    function test_SetAddress() public {
        vm.startPrank(superRegistry.owner());
        superRegistry.setAddress(TEST_ID, TEST_ADDRESS);
        vm.stopPrank();
        
        assertEq(superRegistry.addresses(TEST_ID), TEST_ADDRESS);
    }

    function test_SetAddress_RevertIf_NotOwner() public {
        address nonOwner = address(0xbad);
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        superRegistry.setAddress(TEST_ID, TEST_ADDRESS);
        vm.stopPrank();
    }

    function test_SetAddress_RevertIf_ZeroAddress() public {
        vm.startPrank(superRegistry.owner());
        vm.expectRevert(ISuperRegistry.INVALID_ADDRESS.selector);
        superRegistry.setAddress(TEST_ID, address(0));
        vm.stopPrank();
    }

    function test_GetAddress() public {
        vm.startPrank(superRegistry.owner());
        superRegistry.setAddress(TEST_ID, TEST_ADDRESS);
        vm.stopPrank();
        
        address retrievedAddress = superRegistry.getAddress(TEST_ID);
        assertEq(retrievedAddress, TEST_ADDRESS);
    }

    function test_GetAddress_RevertIf_AddressNotSet() public {
        vm.expectRevert(ISuperRegistry.INVALID_ADDRESS.selector);
        superRegistry.getAddress(EMPTY_ID);
    }

    function test_TransferOwnership() public {
        address newOwner = address(0xbeef);
        
        vm.startPrank(superRegistry.owner());
        superRegistry.transferOwnership(newOwner);
        vm.stopPrank();
        
        assertEq(superRegistry.pendingOwner(), newOwner);
    }

    function test_TransferOwnership_RevertIf_NotOwner() public {
        address nonOwner = address(0xbad);
        address newOwner = address(0xbeef);
        
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        superRegistry.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_To_ZeroAddress() public {
        vm.startPrank(superRegistry.owner());
        superRegistry.transferOwnership(address(0));
        vm.stopPrank();
    }

    function test_AcceptOwnership() public {
        address newOwner = address(0xbeef);
        
        vm.startPrank(superRegistry.owner());
        superRegistry.transferOwnership(newOwner);
        vm.stopPrank();
        
        vm.startPrank(newOwner);
        superRegistry.acceptOwnership();
        vm.stopPrank();
        
        assertEq(superRegistry.owner(), newOwner);
    }

    function test_AcceptOwnership_RevertIf_NotPendingOwner() public {
        address newOwner = address(0xbeef);
        address notPendingOwner = address(0xbad);
        
        vm.startPrank(superRegistry.owner());
        superRegistry.transferOwnership(newOwner);
        vm.stopPrank();
        
        vm.startPrank(notPendingOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notPendingOwner));
        superRegistry.acceptOwnership();
        vm.stopPrank();
    }

    function test_RenounceOwnership() public {
        vm.startPrank(superRegistry.owner());
        superRegistry.renounceOwnership();
        vm.stopPrank();
        
        assertEq(superRegistry.owner(), address(0));
    }

    function test_RenounceOwnership_RevertIf_NotOwner() public {
        address nonOwner = address(0xbad);
        
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        superRegistry.renounceOwnership();
        vm.stopPrank();
    }

    function test_SetAddress_UpdateExistingAddress() public {
        address firstAddress = address(0x123);
        address secondAddress = address(0x456);
        
        vm.startPrank(superRegistry.owner());
        
        // Set initial address
        superRegistry.setAddress(TEST_ID, firstAddress);
        assertEq(superRegistry.addresses(TEST_ID), firstAddress);
        
        // Update to new address
        superRegistry.setAddress(TEST_ID, secondAddress);
        assertEq(superRegistry.addresses(TEST_ID), secondAddress);
        
        vm.stopPrank();
    }

    function test_EmitEvents() public {
        vm.startPrank(superRegistry.owner());
        
        vm.expectEmit(true, true, false, true);
        emit ISuperRegistry.AddressSet(TEST_ID, TEST_ADDRESS);
        superRegistry.setAddress(TEST_ID, TEST_ADDRESS);
        
        vm.stopPrank();
    }

    function test_TransferOwnership_ToSelf() public {
        address owner = superRegistry.owner();
        
        vm.startPrank(owner);
        superRegistry.transferOwnership(owner);
        vm.stopPrank();
        
        assertEq(superRegistry.pendingOwner(), owner);
    }

    function test_TransferOwnership_MultipleTimes() public {
        address owner = superRegistry.owner();
        address newOwner1 = address(0xbeef);
        address newOwner2 = address(0xcafe);
        
        vm.startPrank(owner);
        
        // First transfer
        superRegistry.transferOwnership(newOwner1);
        assertEq(superRegistry.pendingOwner(), newOwner1);
        
        // Change to different pending owner
        superRegistry.transferOwnership(newOwner2);
        assertEq(superRegistry.pendingOwner(), newOwner2);
        
        vm.stopPrank();
    }

    function test_AcceptOwnership_AfterOwnershipTransferred() public {
        address originalOwner = superRegistry.owner();
        address newOwner = address(0xbeef);
        address finalOwner = address(0xcafe);
        
        // First transfer
        vm.prank(originalOwner);
        superRegistry.transferOwnership(newOwner);
        
        // Accept ownership
        vm.prank(newOwner);
        superRegistry.acceptOwnership();
        
        // Verify new owner
        assertEq(superRegistry.owner(), newOwner);
        
        // Transfer again
        vm.prank(newOwner);
        superRegistry.transferOwnership(finalOwner);
        
        // Accept again
        vm.prank(finalOwner);
        superRegistry.acceptOwnership();
        
        // Verify final owner
        assertEq(superRegistry.owner(), finalOwner);
    }
}
