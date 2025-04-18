// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { BundlerRegistry } from "../../../src/periphery/BundlerRegistry.sol";
import { IBundlerRegistry } from "../../../src/periphery/interfaces/IBundlerRegistry.sol";

contract BundlerRegistryTest is BaseTest {
    BundlerRegistry public bundlerRegistry;
    address public BUNDLER;
    bytes public constant EXTRA_DATA = "test_data";
    address public constant NEW_BUNDLER_ADDRESS = address(0x456);
    bytes public constant NEW_EXTRA_DATA = "new_test_data";

    event BundlerRegistered(uint256 indexed id, address indexed bundlerAddress);
    event BundlerAddressUpdated(uint256 indexed id, address indexed oldAddress, address indexed newAddress);
    event BundlerExtraDataUpdated(uint256 indexed id, address indexed bundlerAddress, bytes extraData);
    event BundlerStatusChanged(uint256 indexed id, address indexed bundlerAddress, bool isActive);

    function setUp() public override {
        super.setUp();
        // Deploy BundlerRegistry with owner as this contract
        bundlerRegistry = new BundlerRegistry(address(this));
        BUNDLER = address(this);
    }

    function test_RegisterBundler() public {
        bundlerRegistry.registerBundler(EXTRA_DATA);
        
        // Get the bundler data
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundlerByAddress(BUNDLER);
        
        // Verify registration
        assertTrue(bundlerRegistry.isBundlerRegistered(BUNDLER), "Bundler should be registered");
        assertTrue(bundlerRegistry.isBundlerActive(BUNDLER), "Bundler should be active");
        assertEq(bundler.bundlerAddress, BUNDLER, "Bundler address mismatch");
        assertEq(bundler.extraData, EXTRA_DATA, "Extra data mismatch");
        assertTrue(bundler.isActive, "Bundler should be active");
        
        vm.stopPrank();
    }

    function test_UpdateBundlerAddress() public {
        // First register a bundler
        bundlerRegistry.registerBundler(EXTRA_DATA);
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundlerByAddress(BUNDLER);
        uint256 bundlerId = bundler.id;

        // Update bundler address
        vm.expectEmit(true, true, true, true);
        emit BundlerAddressUpdated(bundlerId, BUNDLER, NEW_BUNDLER_ADDRESS);
        
        bundlerRegistry.updateBundlerAddress(bundlerId, NEW_BUNDLER_ADDRESS);

        IBundlerRegistry.Bundler memory updatedBundler = bundlerRegistry.getBundler(bundlerId);
        assertEq(updatedBundler.bundlerAddress, NEW_BUNDLER_ADDRESS, "Bundler address not updated - getBundler");

        // Verify update using getBundlerByAddress instead of getBundler
        updatedBundler = bundlerRegistry.getBundlerByAddress(NEW_BUNDLER_ADDRESS);
        assertEq(updatedBundler.bundlerAddress, NEW_BUNDLER_ADDRESS, "Bundler address not updated");
        assertTrue(bundlerRegistry.isBundlerRegistered(NEW_BUNDLER_ADDRESS), "New address should be registered");
        assertFalse(bundlerRegistry.isBundlerRegistered(BUNDLER), "Old address should not be registered");
    }

    function test_UpdateBundlerExtraData() public {
        // First register a bundler
        bundlerRegistry.registerBundler(EXTRA_DATA);
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundlerByAddress(BUNDLER);
        uint256 bundlerId = bundler.id;

        // Update extra data
        vm.expectEmit(true, true, false, true);
        emit BundlerExtraDataUpdated(bundlerId, BUNDLER, NEW_EXTRA_DATA);
        
        bundlerRegistry.updateBundlerExtraData(bundlerId, NEW_EXTRA_DATA);

        // Verify update
        IBundlerRegistry.Bundler memory updatedBundler = bundlerRegistry.getBundler(bundlerId);
        assertEq(updatedBundler.extraData, NEW_EXTRA_DATA, "Extra data not updated");
    }

    function test_UpdateBundlerStatus() public {
        // First register a bundler
        bundlerRegistry.registerBundler(EXTRA_DATA);
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundlerByAddress(BUNDLER);
        uint256 bundlerId = bundler.id;

        // Update status to inactive
        vm.expectEmit(true, true, false, true);
        emit BundlerStatusChanged(bundlerId, BUNDLER, false);
        
        bundlerRegistry.updateBundlerStatus(bundlerId, false);

        // Verify update
        assertFalse(bundlerRegistry.isBundlerActive(BUNDLER), "Bundler should be inactive");
        IBundlerRegistry.Bundler memory updatedBundler = bundlerRegistry.getBundler(bundlerId);
        assertFalse(updatedBundler.isActive, "Bundler status not updated");
    }

    function test_RevertWhen_UnauthorizedRegister() public {
        // Try to register from non-owner address
        address nonOwner = address(0x789);
        vm.prank(nonOwner);
        vm.expectRevert();
        bundlerRegistry.registerBundler(EXTRA_DATA);
    }

    function test_RevertWhen_UnauthorizedUpdate() public {
        // First register a bundler
        bundlerRegistry.registerBundler(EXTRA_DATA);
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundlerByAddress(BUNDLER);
        uint256 bundlerId = bundler.id;

        // Try to update from non-owner address
        address nonOwner = address(0x789);
        vm.startPrank(nonOwner);

        vm.expectRevert();
        bundlerRegistry.updateBundlerAddress(bundlerId, NEW_BUNDLER_ADDRESS);

        vm.expectRevert();
        bundlerRegistry.updateBundlerExtraData(bundlerId, NEW_EXTRA_DATA);

        vm.expectRevert();
        bundlerRegistry.updateBundlerStatus(bundlerId, false);

        vm.stopPrank();
    }

    function test_GetNonExistentBundler() public view {
        // Try to get a non-existent bundler
        IBundlerRegistry.Bundler memory nonExistentBundler = bundlerRegistry.getBundlerByAddress(address(0x999));
        assertEq(nonExistentBundler.bundlerAddress, address(0), "Non-existent bundler should have zero address");
        assertFalse(nonExistentBundler.isActive, "Non-existent bundler should be inactive");
    }
}
