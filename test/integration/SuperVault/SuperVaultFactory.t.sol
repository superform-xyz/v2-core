// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SuperVaultFactoryTest is BaseTest {
    SuperVaultFactory public factory;
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public FEE_RECIPIENT;

    IERC20Metadata public asset;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Deploy the factory
        address peripheryRegistry = _getContract(ETH, PERIPHERY_REGISTRY_KEY);
        factory = new SuperVaultFactory(peripheryRegistry);
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        FEE_RECIPIENT = _deployAccount(FEE_RECIPIENT_KEY, "FEE_RECIPIENT");
        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);
    }

    function test_DeployVault() public {
        // Create initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: 1_000_000e6, // USDC has 6 decimals
            superVaultCap: 5_000_000e6,
            maxAllocationRate: 10_000, // 100%
            vaultThreshold: 100_000e6
        });

        // Deploy a new vault
        (address vault, address strategy, address escrow) = factory.createVault(
            address(asset), "SuperVault", "SV", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );

        // Verify addresses are not zero
        assertTrue(vault != address(0), "Vault address should not be zero");
        assertTrue(strategy != address(0), "Strategy address should not be zero");
        assertTrue(escrow != address(0), "Escrow address should not be zero");

        // Verify initialization
        SuperVault vaultContract = SuperVault(vault);
        ISuperVaultStrategy strategyContract = ISuperVaultStrategy(strategy);
        SuperVaultEscrow escrowContract = SuperVaultEscrow(escrow);

        // Check vault state
        assertEq(vaultContract.name(), "SuperVault", "Wrong vault name");
        assertEq(vaultContract.symbol(), "SV", "Wrong vault symbol");
        assertEq(vaultContract.asset(), address(asset), "Wrong asset");
        assertEq(address(vaultContract.strategy()), strategy, "Wrong strategy");
        assertEq(vaultContract.decimals(), 6, "Wrong decimals");

        // Check strategy state
        (address _vault, address _asset, uint8 _decimals) = strategyContract.getVaultInfo();
        assertEq(strategyContract.isInitialized(), true, "Strategy not initialized");
        assertEq(_vault, vault, "Wrong vault in strategy");
        assertEq(_asset, address(asset), "Wrong asset in strategy");
        assertEq(_decimals, 6, "Wrong decimals in strategy");

        // Check escrow state
        assertTrue(escrowContract.initialized(), "Escrow not initialized");
        assertEq(escrowContract.vault(), vault, "Wrong vault in escrow");
        assertEq(escrowContract.strategy(), strategy, "Wrong strategy in escrow");
    }

    function test_DeployMultipleVaults() public {
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: 1_000_000e6,
            superVaultCap: 5_000_000e6,
            maxAllocationRate: 2000, // 20%
            vaultThreshold: 100_000e6
        });

        // Deploy multiple vaults with different names/symbols
        string[3] memory names = ["Super Test Vault 1", "Super Test Vault 2", "Super Test Vault 3"];
        string[3] memory symbols = ["sTV1", "sTV2", "sTV3"];

        for (uint256 i = 0; i < 3; i++) {
            (address vault, address strategy, address escrow) = factory.createVault(
                address(asset), names[i], symbols[i], SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
            );

            // Verify each vault is properly initialized
            SuperVault vaultContract = SuperVault(vault);
            assertEq(vaultContract.name(), names[i], "Wrong vault name");
            assertEq(vaultContract.symbol(), symbols[i], "Wrong vault symbol");
            assertEq(vaultContract.decimals(), 6, "Wrong decimals");

            assertEq(ISuperVaultStrategy(strategy).isInitialized(), true, "Strategy not initialized");

            assertTrue(SuperVaultEscrow(escrow).initialized(), "Escrow not initialized");
        }
    }

    function test_RevertOnZeroAddresses() public {
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: 1_000_000e6,
            superVaultCap: 5_000_000e6,
            maxAllocationRate: 2000,
            vaultThreshold: 100_000e6
        });

        // Test with zero asset address
        vm.expectRevert(SuperVaultFactory.ZERO_ADDRESS.selector);
        factory.createVault(
            address(0), "Test Vault", "TV", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );

        // Test with zero manager address
        vm.expectRevert(SuperVaultFactory.ZERO_ADDRESS.selector);
        factory.createVault(
            address(asset), "Test Vault", "TV", address(0), STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );

        // Test with zero strategist address
        vm.expectRevert(SuperVaultFactory.ZERO_ADDRESS.selector);
        factory.createVault(
            address(asset), "Test Vault", "TV", SV_MANAGER, address(0), EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );

        // Test with zero emergency admin address
        vm.expectRevert(SuperVaultFactory.ZERO_ADDRESS.selector);
        factory.createVault(
            address(asset), "Test Vault", "TV", SV_MANAGER, STRATEGIST, address(0), config, FEE_RECIPIENT
        );

        // Test with zero fee recipient address
        vm.expectRevert(SuperVaultFactory.ZERO_ADDRESS.selector);
        factory.createVault(
            address(asset), "Test Vault", "TV", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, address(0)
        );
    }
}
