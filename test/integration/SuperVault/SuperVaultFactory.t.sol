// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";

contract SuperVaultFactoryTest is BaseSuperVaultTest {
    function test_DeployVault() public {
        // Deploy a new vault
        (address vaultAddr, address strategyAddr, address escrowAddr) =
            _deployVault(address(asset), 1_000_000e6, 5_000_000e6, 100_000e6, 1e6, "SV");
        // Verify addresses are not zero
        assertTrue(vaultAddr != address(0), "Vault address should not be zero");
        assertTrue(strategyAddr != address(0), "Strategy address should not be zero");
        assertTrue(escrowAddr != address(0), "Escrow address should not be zero");

        // Verify initialization
        SuperVault vaultContract = SuperVault(vaultAddr);
        ISuperVaultStrategy strategyContract = ISuperVaultStrategy(strategyAddr);
        SuperVaultEscrow escrowContract = SuperVaultEscrow(escrowAddr);

        // Check vault state
        assertEq(vaultContract.name(), "SuperVault", "Wrong vault name");
        assertEq(vaultContract.symbol(), "SV", "Wrong vault symbol");
        assertEq(vaultContract.asset(), address(asset), "Wrong asset");
        assertEq(address(vaultContract.strategy()), strategyAddr, "Wrong strategy");
        assertEq(vaultContract.decimals(), 6, "Wrong decimals");

        // Check strategy state
        (address _vaultAddr, address _asset, uint8 _decimals) = strategyContract.getVaultInfo();
        assertEq(strategyContract.isInitialized(), true, "Strategy not initialized");
        assertEq(_vaultAddr, vaultAddr, "Wrong vault in strategy");
        assertEq(_asset, address(asset), "Wrong asset in strategy");
        assertEq(_decimals, 6, "Wrong decimals in strategy");

        // Check escrow state
        assertTrue(escrowContract.initialized(), "Escrow not initialized");
        assertEq(escrowContract.vault(), vaultAddr, "Wrong vault in escrow");
        assertEq(escrowContract.strategy(), strategyAddr, "Wrong strategy in escrow");
    }

    function test_DeployMultipleVaults() public {
        // Deploy multiple vaults with different names/symbols
        string[3] memory symbols = ["sTV1", "sTV2", "sTV3"];

        for (uint256 i = 0; i < 3; i++) {
            // Deploy a new vault with custom configuration
            (address vaultAddr, address strategyAddr, address escrowAddr) = _deployVault(
                address(asset),
                1_000_000e6, // vaultCap
                5_000_000e6, // superVaultCap
                100_000e6, // vaultThreshold
                1e6, // bootstrapAmount
                symbols[i] // symbol
            );

            // Verify each vault is properly initialized
            SuperVault vaultContract = SuperVault(vaultAddr);
            assertEq(vaultContract.symbol(), symbols[i], "Wrong vault symbol");
            assertEq(vaultContract.decimals(), 6, "Wrong decimals");

            assertEq(ISuperVaultStrategy(strategyAddr).isInitialized(), true, "Strategy not initialized");

            assertTrue(SuperVaultEscrow(escrowAddr).initialized(), "Escrow not initialized");
        }
    }

    function test_RevertOnZeroAddresses() public {
        address[] memory bootstrapHooks;
        bytes[] memory bootstrapHookCalldata;
        uint256[] memory expectedAssetsOrSharesOut;

        // Test with zero asset address
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(0),
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                vaultCap: 1_000_000e6,
                superVaultCap: 5_000_000e6,
                vaultThreshold: 100_000e6,
                bootstrapAmount: 1e6,
                symbol: "TV",
                initHooksRoot: bytes32(0),
                initYieldSource: address(0),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookCalldata: bootstrapHookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );

        // Test with zero manager address (by temporarily setting SV_MANAGER to address(0))
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(asset),
                manager: address(0),
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                vaultCap: 1_000_000e6,
                superVaultCap: 5_000_000e6,
                vaultThreshold: 100_000e6,
                bootstrapAmount: 1e6,
                symbol: "TV",
                initHooksRoot: bytes32(0),
                initYieldSource: address(0),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookCalldata: bootstrapHookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );

        // Test with zero strategist address (by temporarily setting STRATEGIST to address(0))
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(asset),
                manager: SV_MANAGER,
                strategist: address(0),
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                vaultCap: 1_000_000e6,
                superVaultCap: 5_000_000e6,
                vaultThreshold: 100_000e6,
                bootstrapAmount: 1e6,
                symbol: "TV",
                initHooksRoot: bytes32(0),
                initYieldSource: address(0),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookCalldata: bootstrapHookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );

        // Test with zero emergency admin address (by temporarily setting EMERGENCY_ADMIN to address(0))
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(asset),
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: address(0),
                feeRecipient: TREASURY,
                vaultCap: 1_000_000e6,
                superVaultCap: 5_000_000e6,
                vaultThreshold: 100_000e6,
                bootstrapAmount: 1e6,
                symbol: "TV",
                initHooksRoot: bytes32(0),
                initYieldSource: address(0),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookCalldata: bootstrapHookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    struct VaultCreationParams {
        address asset;
        address manager;
        address strategist;
        address emergencyAdmin;
        address feeRecipient;
        uint256 vaultCap;
        uint256 superVaultCap;
        uint256 vaultThreshold;
        uint256 bootstrapAmount;
        string symbol;
        bytes32 initHooksRoot;
        address initYieldSource;
        address[] bootstrappingHooks;
        bytes[] bootstrappingHookCalldata;
        uint256[] expectedAssetsOrSharesOut;
    }

    function _createVault(VaultCreationParams memory params)
        internal
        returns (address vaultAddr, address strategyAddr, address escrowAddr)
    {
        ISuperVaultStrategy.GlobalConfig memory globalConfig = ISuperVaultStrategy.GlobalConfig({
            vaultCap: params.vaultCap,
            superVaultCap: params.superVaultCap,
            vaultThreshold: params.vaultThreshold
        });
        (vaultAddr, strategyAddr, escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: params.asset,
                name: "SuperVault",
                symbol: params.symbol,
                manager: params.manager,
                strategist: params.strategist,
                emergencyAdmin: params.emergencyAdmin,
                feeRecipient: params.feeRecipient,
                config: globalConfig,
                bootstrapAmount: params.bootstrapAmount,
                initYieldSource: params.initYieldSource,
                initHooksRoot: params.initHooksRoot,
                initYieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: params.bootstrappingHooks,
                bootstrappingHookCalldata: params.bootstrappingHookCalldata,
                expectedAssetsOrSharesOut: params.expectedAssetsOrSharesOut
            })
        );
    }
}
