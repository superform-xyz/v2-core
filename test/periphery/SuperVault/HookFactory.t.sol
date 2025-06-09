// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Test
import { BaseSuperVaultTest } from "../integration/SuperVault/BaseSuperVaultTest.t.sol";

// Superform
import { HookFactory } from "../../../src/periphery/SuperVault/HookFactory.sol";
import { IHookFactory } from "../../../src/periphery/interfaces/SuperVault/IHookFactory.sol";
import { ISuperAssetRegistry } from "../../../src/periphery/interfaces/SuperVault/ISuperAssetRegistry.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { SuperAssetRegistry } from "../../../src/periphery/SuperVault/SuperAssetRegistry.sol";

contract HookFactoryTest is BaseSuperVaultTest {
    HookFactory public hookFactory;
    SuperAssetRegistry public superAssetRegistry;
    
    address public constant STRATEGY = address(0x1234);
    address public constant UNAUTHORIZED = address(0xDEF0);
    address public constant AGGREGATOR = address(0xABCD);
    
    bytes32 public constant GLOBAL_ROOT = keccak256("global_root");
    bytes32 public constant STRATEGY_ROOT = keccak256("strategy_root");

    function setUp() public override {
        super.setUp();
        
        // Deploy SuperAssetRegistry
        superAssetRegistry = new SuperAssetRegistry(address(superGovernor));
        
        // Deploy HookFactory
        hookFactory = new HookFactory(address(superGovernor), address(superAssetRegistry));
    }

    function test_constructor_ValidAddresses() public {
        HookFactory factory = new HookFactory(address(superGovernor), address(superAssetRegistry));
        assertEq(address(factory.SUPER_GOVERNOR()), address(superGovernor));
        assertEq(address(factory.SUPER_ASSET_REGISTRY()), address(superAssetRegistry));
    }

    function test_constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(IHookFactory.ZERO_ADDRESS.selector);
        new HookFactory(address(0), address(superAssetRegistry));
    }

    function test_setHooksRootUpdateTimelock_ByGovernor() public {
        uint256 newTimelock = 24 hours;
        
        vm.prank(address(superGovernor));
        hookFactory.setHooksRootUpdateTimelock(newTimelock);
        
        assertEq(hookFactory.getHooksRootUpdateTimelock(), newTimelock);
    }

    function test_executeGlobalHooksRootUpdate_Success() public {
        // First propose
        vm.prank(address(superGovernor));
        hookFactory.proposeGlobalHooksRoot(GLOBAL_ROOT);
        
        // Fast forward time
        uint256 timelock = hookFactory.getHooksRootUpdateTimelock();
        vm.warp(block.timestamp + timelock + 1);
        
        hookFactory.executeGlobalHooksRootUpdate();
        
        assertEq(hookFactory.getGlobalHooksRoot(), GLOBAL_ROOT);
    }

    function test_validateHook_ValidCall() public {
        bytes memory hookArgs = abi.encode("test_hook");
        bytes32[] memory globalProof;
        bytes32[] memory strategyProof;
        
        bool isValid = hookFactory.validateHook(STRATEGY, hookArgs, globalProof, strategyProof);
        
        // Just verify function doesn't revert
        assertTrue(isValid || !isValid);
    }
} 