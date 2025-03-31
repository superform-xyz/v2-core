// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// superform
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";

import { console2 } from "forge-std/console2.sol";

import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

contract SuperVaultAllocateTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    struct RebalanceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 totalAssets;
        uint256 targetFluidVaultAssets;
        uint256 targetAaveVaultAssets;
        uint256 currentFluidVaultAssets;
        uint256 currentAaveVaultAssets;
        uint256 assetsToMove;
        uint256 sharesToRedeem;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalFluidVaultAssets;
        uint256 finalAaveVaultAssets;
        uint256 finalTotalAssets;
        uint256 fluidVaultPercentage;
        uint256 aaveVaultPercentage;
        uint256 initialTotalValue;
    }

    function test_Allocate_Rebalance() public {
        RebalanceVars memory vars;
        vars.depositAmount = 1000e6;

        //60/40 initial allo
        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        (vars.totalAssets,) = strategy.totalAssets();
        console2.log("vars.totalAssets", vars.totalAssets);
        vars.targetFluidVaultAssets = vars.totalAssets * 70 / 100;
        vars.targetAaveVaultAssets = vars.totalAssets * 30 / 100;
        console2.log("vars.targetFluidVaultAssets", vars.targetFluidVaultAssets);
        console2.log("vars.targetAaveVaultAssets", vars.targetAaveVaultAssets);

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        console2.log("vars.currentFluidVaultAssets", vars.currentFluidVaultAssets);
        console2.log("vars.currentAaveVaultAssets", vars.currentAaveVaultAssets);

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);

        // Determine which way to rebalance
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }

        // final balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = vars.finalFluidVaultAssets * 100 / vars.finalTotalAssets;
        vars.aaveVaultPercentage = vars.finalAaveVaultAssets * 100 / vars.finalTotalAssets;

        console2.log("Final FluidVault assets:", vars.finalFluidVaultAssets);
        console2.log("Final AaveVault assets:", vars.finalAaveVaultAssets);
        console2.log("Final FluidVault percentage:", vars.fluidVaultPercentage, "%");
        console2.log("Final AaveVault percentage:", vars.aaveVaultPercentage, "%");

        // checks
        assertApproxEqRel(vars.fluidVaultPercentage, 70, 0.02e18, "FluidVault should have ~70% allocation");
        assertApproxEqRel(vars.aaveVaultPercentage, 30, 0.02e18, "AaveVault should have ~30% allocation");

        // check total vcalue
        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets, vars.initialTotalValue, 0.01e18, "Total value should be preserved during rebalancing"
        );
    }

    function test_Allocate_SmallAmounts() public {
        RebalanceVars memory vars;
        vars.depositAmount = 5e5; //0.5 usd

        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.totalAssets = vars.currentFluidVaultAssets + vars.currentAaveVaultAssets;

        vars.targetFluidVaultAssets = (vars.totalAssets * 7000) / 10_000;
        vars.targetAaveVaultAssets = (vars.totalAssets * 3000) / 10_000;

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        vm.startPrank(STRATEGIST);
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }
        vm.stopPrank();

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = (vars.finalFluidVaultAssets * 10_000) / vars.finalTotalAssets;
        vars.aaveVaultPercentage = (vars.finalAaveVaultAssets * 10_000) / vars.finalTotalAssets;

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("FluidVault percentage:", vars.fluidVaultPercentage);
        console2.log("AaveVault percentage:", vars.aaveVaultPercentage);

        assertApproxEqRel(
            vars.fluidVaultPercentage, 7000, 0.05e18, "FluidVault allocation should be ~70% even for small amounts"
        );
        assertApproxEqRel(
            vars.aaveVaultPercentage, 3000, 0.05e18, "AaveVault allocation should be ~30% even for small amounts"
        );

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets,
            vars.initialTotalValue,
            0.02e18,
            "Total value should be preserved even with small amounts"
        );
    }

    function test_Allocate_LargeAmounts() public {
        RebalanceVars memory vars;
        vars.depositAmount = 10_000_000e6; // 10M USD * 30

        // update vault cap
        vm.startPrank(MANAGER);
        strategy.updateSuperVaultCap(1_000_000_000e6);
        vm.stopPrank();

        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.totalAssets = vars.currentFluidVaultAssets + vars.currentAaveVaultAssets;

        vars.targetFluidVaultAssets = (vars.totalAssets * 7000) / 10_000;
        vars.targetAaveVaultAssets = (vars.totalAssets * 3000) / 10_000;

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        vm.startPrank(STRATEGIST);
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }
        vm.stopPrank();

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = (vars.finalFluidVaultAssets * 10_000) / vars.finalTotalAssets;
        vars.aaveVaultPercentage = (vars.finalAaveVaultAssets * 10_000) / vars.finalTotalAssets;

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("FluidVault percentage:", vars.fluidVaultPercentage);
        console2.log("AaveVault percentage:", vars.aaveVaultPercentage);

        assertApproxEqRel(
            vars.fluidVaultPercentage, 7000, 0.01e18, "FluidVault allocation should be ~70% for large amounts"
        );
        assertApproxEqRel(
            vars.aaveVaultPercentage, 3000, 0.01e18, "AaveVault allocation should be ~30% for large amounts"
        );

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved even with large amounts"
        );
    }

    struct NewYieldSourceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialNewVaultBalance;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalNewVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
    }

    function test_Allocate_NewYieldSource() public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);

        // add new vault as yield source
        Mock4626Vault newVault = new Mock4626Vault(asset, "New Vault", "NV");

        //  -- add funds to the newVault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(newVault), type(uint256).max);
        newVault.deposit(2 * LARGE_DEPOSIT, address(this));

        // -- add it as a new yield source
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(
            address(newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true, false
        );
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial NewVault balance:", vars.initialNewVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        uint256 amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        uint256 amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        uint256 assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(amountToReallocateFluidVault);
        uint256 assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(amountToReallocateAaveVault);
        uint256 assetAmountToReallocateToNewVault =
            assetAmountToReallocateFromFluidVault + assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", assetAmountToReallocateFromAaveVault);

        // allocation
        address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](3);
        // redeem from FluidVault
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            amountToReallocateFluidVault,
            false,
            false
        );
        // redeem from AaveVault
        hooksData[1] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            amountToReallocateAaveVault,
            false,
            false
        );
        // deposit to NewVault
        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(newVault),
            address(asset),
            assetAmountToReallocateToNewVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.execute(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](0),
                isDeposit: false
            })
        );
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final NewVault balance:", vars.finalNewVaultBalance);

        assertApproxEqRel(
            vars.finalFluidVaultBalance,
            vars.initialFluidVaultBalance - amountToReallocateFluidVault,
            0.01e18,
            "FluidVault balance should decrease by the reallocated amount"
        );

        assertApproxEqRel(
            vars.finalAaveVaultBalance,
            vars.initialAaveVaultBalance - amountToReallocateAaveVault,
            0.01e18,
            "AaveVault balance should decrease by the reallocated amount"
        );

        assertGt(vars.finalNewVaultBalance, vars.initialNewVaultBalance, "NewVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + newVault.convertToAssets(vars.initialNewVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance) + newVault.convertToAssets(vars.finalNewVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _rebalanceFromAaveToFluid(
        RebalanceVars memory vars,
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        private
    {
        _rebalanceFromVaultToVault(
            hooksAddresses,
            hooksData,
            address(aaveVault),
            address(fluidVault),
            vars.targetFluidVaultAssets,
            vars.currentFluidVaultAssets
        );
    }

    function _rebalanceFromFluidToAave(
        RebalanceVars memory vars,
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        private
    {
        _rebalanceFromVaultToVault(
            hooksAddresses,
            hooksData,
            address(fluidVault),
            address(aaveVault),
            vars.targetAaveVaultAssets,
            vars.currentAaveVaultAssets
        );
    }
}
