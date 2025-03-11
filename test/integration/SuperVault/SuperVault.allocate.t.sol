// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// superform
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { AccountInstance } from "modulekit/ModuleKit.sol";
import { SuperVaultFulfillRedeemRequestsTest } from "./SuperVault.fulfillRedeemRequests.t.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperVaultAllocateTest is SuperVaultFulfillRedeemRequestsTest {
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

        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

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
        bytes32[][] memory proofs = new bytes32[][](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = _getMerkleProof(depositHookAddress);

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
        strategy.updateGlobalConfig(
            ISuperVaultStrategy.GlobalConfig({
                vaultCap: 500_000_000e6,
                superVaultCap: 1_000_000_000e6,
                vaultThreshold: VAULT_THRESHOLD
            })
        );
        vm.stopPrank();

        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        address[] memory hooksAddresses = new address[](2);
        bytes32[][] memory proofs = new bytes32[][](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = _getMerkleProof(depositHookAddress);

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
        uint256 initialMockVaultBalance;
        uint256 amountToReallocateFluidVault;
        uint256 amountToReallocateAaveVault;
        uint256 assetAmountToReallocateFromFluidVault;
        uint256 assetAmountToReallocateFromAaveVault;
        uint256 assetAmountToReallocateToMockVault;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalMockVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        Mock4626Vault newVault;
    }

    function test_Allocate_NewYieldSource() public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);

        // add new vault as yield source
        vars.newVault = new Mock4626Vault(asset, "New Vault", "NV");

        //  -- add funds to the newVault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(address(vars.newVault), type(uint256).max);
        vars.newVault.deposit(2 * VAULT_THRESHOLD, address(this));

        // -- add it as a new yield source
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(address(vars.newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialMockVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial MockVault balance:", vars.initialMockVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToMockVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);

        // allocation
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](3);
        // redeem from FluidVault
        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false,
            false
        );
        // redeem from AaveVault
        hooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false,
            false
        );
        // deposit to MockVault
        hooksData[2] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.newVault),
            vars.assetAmountToReallocateToMockVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalMockVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final MockVault balance:", vars.finalMockVaultBalance);

        assertApproxEqRel(
            vars.finalFluidVaultBalance,
            vars.initialFluidVaultBalance - vars.amountToReallocateFluidVault,
            0.01e18,
            "FluidVault balance should decrease by the reallocated amount"
        );

        assertApproxEqRel(
            vars.finalAaveVaultBalance,
            vars.initialAaveVaultBalance - vars.amountToReallocateAaveVault,
            0.01e18,
            "AaveVault balance should decrease by the reallocated amount"
        );

        assertGt(vars.finalMockVaultBalance, vars.initialMockVaultBalance, "MockVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.initialMockVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.finalMockVaultBalance);
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
