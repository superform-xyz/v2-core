// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// superform
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { RuggableVault } from "../../mocks/RuggableVault.sol";
import { RuggableConvertVault } from "../../mocks/RuggableConvertVault.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";

contract SuperVaultScenariosTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using Math for uint256;

    struct MultipleOperationsVars {
        uint256 seed;
        uint256[] depositAmounts;
        address[] redeemUsers;
        uint256[] redeemAmounts;
        bool[] selected;
        uint256 selectedCount;
        uint256 totalRedeemShares;
        uint256 redeemSharesVault1;
        uint256 redeemSharesVault2;
        uint256 initialTimestamp;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
    }

    struct FinalBalanceVerificationVars {
        // Global vault state
        uint256 finalTotalAssets;
        uint256 finalTotalSupply;
        uint256 finalPricePerShare;
        uint256 totalValueLocked;
        // Strategy state
        uint256 fluidBalance;
        uint256 aaveBalance;
        // Escrow state
        uint256 escrowBalance;
        // Yield tracking
        uint256 totalYieldAccrued;
        uint256 yieldPerShare;
        // User accounting
        uint256 totalUserShares;
        uint256 totalUserAssets;
        uint256 totalPendingDeposits;
        uint256 totalPendingRedeems;
        // Per-user state
        uint256 currentShares;
        uint256 currentAssets;
        uint256 expectedShares;
        uint256 expectedAssets;
        uint256 userYieldAccrued;
        bool isRedeemer;
        uint256 redeemedShares;
    }

    struct NewYieldSourceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialMockVaultBalance;
        uint256 initialPendleVaultBalance;
        uint256 amountToReallocateFluidVault;
        uint256 amountToReallocateAaveVault;
        uint256 assetAmountToReallocateFromFluidVault;
        uint256 assetAmountToReallocateFromAaveVault;
        uint256 assetAmountToReallocateToMockVault;
        uint256 assetAmountToReallocateToPendleVault;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalMockVaultBalance;
        uint256 finalPendleVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        Mock4626Vault newVault;
        address pendleVault;
        // Price per share tracking
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialPendleVaultPPS;
        uint256 initialMockVaultPPS;
    }

    struct VaultLifecycleVars {
        uint256 depositAmount;
        uint256 initialTimestamp;
        uint256[] userDepositAmounts;
        address[] users;
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialPendleVaultPPS;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        uint256[] userInitialShares;
        uint256[] userInitialAssets;
        uint256[] userFinalShares;
        uint256[] userFinalAssets;
        uint256[] userYields;
        address pendleVault;
    }

    struct RugTestVarsDeposit {
        uint256 depositAmount;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 rugPercentage;
        address[] depositUsers;
        uint256[] depositAmounts;
        uint256 initialTimestamp;
        RuggableVault ruggableVault;
    }

    struct RugTestVarsWithdraw {
        bool convertVault;
        uint256 depositAmount;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 rugPercentage;
        address[] depositUsers;
        uint256[] depositAmounts;
        address[] redeemUsers;
        uint256[] redeemAmounts;
        uint256 totalRedeemShares;
        uint256 redeemSharesVault1;
        uint256 redeemSharesVault2;
        uint256 initialTimestamp;
        address ruggableVault;
        uint256 initialRuggableVaultBalance;
        uint256 initialFluidVaultBalance;
        uint256 initialRuggableVaultAssets;
        uint256 initialFluidVaultAssets;
        uint256 amountToReallocate;
        uint256 assetAmountToReallocate;
        uint256 finalRuggableVaultBalance;
        uint256 finalFluidVaultBalance;
        uint256 finalRuggableVaultAssets;
        uint256 finalFluidVaultAssets;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        uint256 vaultTotalAssetsAfterAllocation;
        uint256 pricePerShareAfterAllocation;
        uint256 ppsBeforeWarp;
        uint256 ppsAfterWarp;
        uint256[] expectedAssetsOrSharesOut;
        uint256 assetsVault1;
        uint256 assetsVault2;
    }

    struct VaultCapTestVars {
        address withdrawHookAddress;
        address depositHookAddress;
        address[] hooksAddresses;
        bytes[] hooksData;
        // Initial setup
        uint256 depositAmount;
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialEulerVaultPPS;
        uint256 totalInitialBalance;
        uint256 initialFluidRatio;
        uint256 initialAaveRatio;
        uint256 initialEulerRatio;
        // Vault balances
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialEulerVaultBalance;
        int256 fluidDiff;
        int256 aaveDiff;
        int256 eulerDiff;
        address[] sources;
        uint256[] sourceAmounts;
        address[] destinations;
        uint256[] destinationAmounts;
        uint256 sourceCount;
        uint256 destCount;
        address source;
        address destination;
        uint256 amountToMove;
        // First reallocation (50/25/25)
        uint256 assetsToMove;
        uint256 sharesToRedeem;
        uint256 targetFluidAssets;
        uint256 targetAaveAssets;
        uint256 targetEulerAssets;
        uint256 currentFluidAssets;
        uint256 currentAaveAssets;
        uint256 currentEulerAssets;
        uint256 excessFluidAssets;
        uint256 fluidSharesToRedeem;
        uint256 assetsToMoveAave;
        uint256 assetsToMoveEuler;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalEulerVaultBalance;
        uint256 totalFinalBalance;
        uint256 finalFluidRatio;
        uint256 finalAaveRatio;
        uint256 finalEulerRatio;
        // Second reallocation (40/30/30)
        uint256 newVaultCap;
        uint256 assetsToMoveToAave;
        uint256 assetsToMoveToEuler;
        uint256 targetFluidAssets2;
        uint256 targetAaveAssets2;
        uint256 targetEulerAssets2;
        uint256 finalFluidVaultBalance2;
        uint256 finalAaveVaultBalance2;
        uint256 finalEulerVaultBalance2;
        uint256 totalFinalBalance2;
        uint256 finalFluidRatio2;
        uint256 finalAaveRatio2;
        uint256 finalEulerRatio2;
        uint256 finalTotalValue;
        // misc
        ISuperVaultStrategy.GlobalConfig newConfig;
    }

    function test_2_MultipleOperations_RandomAmounts(uint256 seed) public {
        MultipleOperationsVars memory vars;
        // Setup random seed and initial timestamp
        vars.initialTimestamp = block.timestamp;
        vars.seed = seed;
        // Generate random deposit amounts for all users (20 users)
        vars.depositAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            // Use the seed to generate random amounts
            // 50% chance for large amount (1M-2M), 50% chance for small amount (100-1000)
            uint256 rand = uint256(keccak256(abi.encodePacked(vars.seed, i)));
            if (rand % 2 == 0) {
                // Large amount: 1M-2M USDC
                vars.depositAmounts[i] = 1_000_000e6 + (rand % 1_000_000e6);
            } else {
                // Small amount: 100-1000 USDC
                vars.depositAmounts[i] = 100e6 + (rand % 900e6);
            }
        }

        _completeDepositFlowWithVaryingAmounts(vars.depositAmounts);

        // Store initial state for yield verification
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Verify initial balances and shares
        _verifyInitialBalances(vars.depositAmounts);

        // Simulate time passing (1 day) to accumulate some yield
        vm.warp(vars.initialTimestamp + 1 days);
        console2.log("\n=== After 1 day ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Setup redemption arrays
        vars.redeemUsers = new address[](15);
        vars.redeemAmounts = new uint256[](15);
        vars.selected = new bool[](ACCOUNT_COUNT);

        // Select random users for redemption
        vars = _selectRandomUsersForRedemption(vars);

        // Simulate some more time passing (12 hours) before redemption requests
        vm.warp(vars.initialTimestamp + 1 days + 12 hours);
        console2.log("\n=== After 1.5 days ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Request redemptions
        _processRedemptionRequests(vars);

        // Calculate total redemption amount for allocation
        vars.totalRedeemShares = 0;
        for (uint256 i; i < 15; i++) {
            vars.totalRedeemShares += vars.redeemAmounts[i];
        }

        // Simulate time passing (6 hours) before fulfilling redemptions
        vm.warp(vars.initialTimestamp + 1 days + 18 hours);
        console2.log("\n=== After 1.75 days ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Fulfill redemptions
        vars.redeemSharesVault1 = vars.totalRedeemShares / 2;
        vars.redeemSharesVault2 = vars.totalRedeemShares - vars.redeemSharesVault1;
        _fulfillRedeemForUsers(
            vars.redeemUsers, vars.redeemSharesVault1, vars.redeemSharesVault2, address(fluidVault), address(aaveVault)
        );

        // Process claims for redeemed users
        _claimRedeemForUsers(vars.redeemUsers);

        // Simulate final time passing (6 hours) before final verification
        vm.warp(vars.initialTimestamp + 2 days);
        console2.log("\n=== After 2 days ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Verify final balances and shares
        _verifyFinalBalances(vars);
    }

    function test_11_Allocate_NewYieldSource() public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);

        // add new vault as yield source
        vars.newVault = new Mock4626Vault(asset, "New Vault", "NV");

        //  -- add funds to the newVault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(address(vars.newVault), type(uint256).max);
        vars.newVault.deposit(2 * VAULT_THRESHOLD, address(this));

        vm.warp(block.timestamp + 20 days);

        // -- add it as a new yield source
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(address(vars.newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialPendleVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial PendleVault balance:", vars.initialPendleVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToPendleVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);

        vm.warp(block.timestamp + 20 days);

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
        // deposit to PendleVault
        hooksData[2] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.newVault),
            vars.assetAmountToReallocateToPendleVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalPendleVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final PendleVault balance:", vars.finalPendleVaultBalance);

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

        assertGt(vars.finalPendleVaultBalance, vars.initialPendleVaultBalance, "PendleVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.initialPendleVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.finalPendleVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        // Enhanced checks for price per share and yield
        console2.log("\n=== Enhanced Vault Metrics ===");

        // Price per share comparison
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(1e18);
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(1e18);
        uint256 pendleVaultFinalPPS = vars.newVault.convertToAssets(1e18);

        console2.log("\nPrice per Share Changes:");
        console2.log("Fluid Vault:");
        console2.log("  Initial PPS:", vars.initialFluidVaultPPS);
        console2.log("  Final PPS:", fluidVaultFinalPPS);
        console2.log(
            "  Change:",
            fluidVaultFinalPPS > vars.initialFluidVaultPPS ? "+" : "",
            fluidVaultFinalPPS - vars.initialFluidVaultPPS
        );
        console2.log(
            "  Change %:", ((fluidVaultFinalPPS - vars.initialFluidVaultPPS) * 10_000) / vars.initialFluidVaultPPS
        );

        console2.log("\nAave Vault:");
        console2.log("  Initial PPS:", vars.initialAaveVaultPPS);
        console2.log("  Final PPS:", aaveVaultFinalPPS);
        console2.log(
            "  Change:",
            aaveVaultFinalPPS > vars.initialAaveVaultPPS ? "+" : "",
            aaveVaultFinalPPS - vars.initialAaveVaultPPS
        );
        console2.log(
            "  Change %:", ((aaveVaultFinalPPS - vars.initialAaveVaultPPS) * 10_000) / vars.initialAaveVaultPPS
        );

        console2.log("\nYield Metrics:");
        uint256 totalYield =
            vars.finalTotalValue > vars.initialTotalValue ? vars.finalTotalValue - vars.initialTotalValue : 0;
        console2.log("Total Yield:", totalYield);
        console2.log("Yield %:", (totalYield * 10_000) / vars.initialTotalValue);

        assertGe(fluidVaultFinalPPS, vars.initialFluidVaultPPS, "Fluid Vault should not lose value");
        assertGe(aaveVaultFinalPPS, vars.initialAaveVaultPPS, "Aave Vault should not lose value");
        assertGe(pendleVaultFinalPPS, 1e18, "Pendle Vault should not lose value");

        uint256 totalFinalBalance =
            vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalPendleVaultBalance;

        uint256 fluidRatio = (vars.finalFluidVaultBalance * 100) / totalFinalBalance;
        uint256 aaveRatio = (vars.finalAaveVaultBalance * 100) / totalFinalBalance;
        uint256 pendleRatio = (vars.finalPendleVaultBalance * 100) / totalFinalBalance;

        console2.log("\nFinal Allocation Ratios:");
        console2.log("Fluid Vault:", fluidRatio, "%");
        console2.log("Aave Vault:", aaveRatio, "%");
        console2.log("Pendle Vault:", pendleRatio, "%");
    }

    function test_4_Allocate_Simple_Vault_Caps() public {
        VaultCapTestVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // Initial allocation - this will put the first two vaults at ~50/50
        _completeDepositFlow(vars.depositAmount);

        // Add Euler vault as a new yield source
        address eulerVaultAddr = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        vm.label(eulerVaultAddr, "EulerVault");
        IERC4626 eulerVault = IERC4626(eulerVaultAddr);

        // Add funds to the Euler vault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(eulerVaultAddr, type(uint256).max);
        eulerVault.deposit(2 * VAULT_THRESHOLD, address(this));

        vm.warp(block.timestamp + 20 days);

        // Add Euler vault as a new yield source
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(eulerVaultAddr, _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        // Get initial balances
        vars.initialFluidVaultBalance = fluidVault.convertToAssets(fluidVault.balanceOf(address(strategy)));
        vars.initialAaveVaultBalance = aaveVault.convertToAssets(aaveVault.balanceOf(address(strategy)));
        vars.initialEulerVaultBalance = eulerVault.convertToAssets(eulerVault.balanceOf(address(strategy)));

        console2.log("\n=== Initial Balances ===");
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial EulerVault balance:", vars.initialEulerVaultBalance);

        // Calculate initial allocation percentages
        vars.totalInitialBalance =
            vars.initialFluidVaultBalance + vars.initialAaveVaultBalance + vars.initialEulerVaultBalance;
        vars.initialFluidRatio = (vars.initialFluidVaultBalance * 10_000) / vars.totalInitialBalance;
        vars.initialAaveRatio = (vars.initialAaveVaultBalance * 10_000) / vars.totalInitialBalance;
        vars.initialEulerRatio = (vars.initialEulerVaultBalance * 10_000) / vars.totalInitialBalance;

        console2.log("\n=== Initial Allocation Ratios ===");
        console2.log("Fluid Vault:", vars.initialFluidRatio / 100, "%");
        console2.log("Aave Vault:", vars.initialAaveRatio / 100, "%");
        console2.log("Euler Vault:", vars.initialEulerRatio / 100, "%");

        // First reallocation: Change to 50/25/25 (fluid/aave/euler)
        console2.log("\n=== First Reallocation: Target 50/25/25 ===");

        // Calculate target balances for 50/25/25 allocation
        vars.targetFluidAssets = vars.totalInitialBalance * 5000 / 10_000;
        vars.targetAaveAssets = vars.totalInitialBalance * 2500 / 10_000;
        vars.targetEulerAssets = vars.totalInitialBalance * 2500 / 10_000;

        console2.log("Total initial balance:", vars.totalInitialBalance);
        console2.log("Target Fluid Assets:", vars.targetFluidAssets);
        console2.log("Target Aave Assets:", vars.targetAaveAssets);
        console2.log("Target Euler Assets:", vars.targetEulerAssets);

        // Set up hooks for reallocation
        vars.withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        vars.depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        // REFACTORED REALLOCATION ALGORITHM
        // Calculate the differences between current and target allocations
        vars.fluidDiff = int256(vars.targetFluidAssets) - int256(vars.initialFluidVaultBalance);
        vars.aaveDiff = int256(vars.targetAaveAssets) - int256(vars.initialAaveVaultBalance);
        vars.eulerDiff = int256(vars.targetEulerAssets) - int256(vars.initialEulerVaultBalance);

        console2.log("\n=== Allocation Differences ===");
        console2.log("Fluid Diff:", vars.fluidDiff);
        console2.log("Aave Diff:", vars.aaveDiff);
        console2.log("Euler Diff:", vars.eulerDiff);

        // Identify sources (vaults with excess assets) and destinations (vaults needing assets)
        vars.sources = new address[](3);
        vars.sourceAmounts = new uint256[](3);
        vars.destinations = new address[](3);
        vars.destinationAmounts = new uint256[](3);
        vars.sourceCount = 0;
        vars.destCount = 0;

        if (vars.fluidDiff < 0) {
            vars.sources[vars.sourceCount] = address(fluidVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.fluidDiff);
            vars.sourceCount++;
        } else if (vars.fluidDiff > 0) {
            vars.destinations[vars.destCount] = address(fluidVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.fluidDiff);
            vars.destCount++;
        }

        if (vars.aaveDiff < 0) {
            vars.sources[vars.sourceCount] = address(aaveVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.aaveDiff);
            vars.sourceCount++;
        } else if (vars.aaveDiff > 0) {
            vars.destinations[vars.destCount] = address(aaveVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.aaveDiff);
            vars.destCount++;
        }

        if (vars.eulerDiff < 0) {
            vars.sources[vars.sourceCount] = address(eulerVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.eulerDiff);
            vars.sourceCount++;
        } else if (vars.eulerDiff > 0) {
            vars.destinations[vars.destCount] = address(eulerVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.eulerDiff);
            vars.destCount++;
        }

        // Resize arrays to actual count
        vars.sources = _resizeAddressArray(vars.sources, vars.sourceCount);
        vars.sourceAmounts = _resizeUint256Array(vars.sourceAmounts, vars.sourceCount);
        vars.destinations = _resizeAddressArray(vars.destinations, vars.destCount);
        vars.destinationAmounts = _resizeUint256Array(vars.destinationAmounts, vars.destCount);

        console2.log("\n=== Sources and Destinations ===");
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            console2.log("Source:", vars.sources[i]);
            console2.log("Amount:", vars.sourceAmounts[i]);
        }
        for (uint256 i = 0; i < vars.destCount; i++) {
            console2.log("Destination:", vars.destinations[i]);
            console2.log("Amount:", vars.destinationAmounts[i]);
        }

        // Iteratively move assets from sources to destinations
        for (uint256 i = 0; i < vars.sourceCount && i < vars.destCount; i++) {
            vars.source = vars.sources[i];
            vars.destination = vars.destinations[i];
            vars.amountToMove =
                vars.sourceAmounts[i] < vars.destinationAmounts[i] ? vars.sourceAmounts[i] : vars.destinationAmounts[i];

            if (vars.amountToMove > 0) {
                console2.log("\nMoving", vars.amountToMove);

                console2.log("from", vars.source, "to", vars.destination);

                // Convert asset amount to shares for the source vault
                vars.sharesToRedeem;
                if (vars.source == address(fluidVault)) {
                    vars.sharesToRedeem = fluidVault.convertToShares(vars.amountToMove);
                } else if (vars.source == address(aaveVault)) {
                    vars.sharesToRedeem = aaveVault.convertToShares(vars.amountToMove);
                } else if (vars.source == address(eulerVault)) {
                    vars.sharesToRedeem = eulerVault.convertToShares(vars.amountToMove);
                }

                console2.log("Shares to redeem:", vars.sharesToRedeem);

                vars.hooksAddresses = new address[](2);
                vars.hooksAddresses[0] = vars.withdrawHookAddress;
                vars.hooksAddresses[1] = vars.depositHookAddress;

                vars.hooksData = new bytes[](2);
                vars.hooksData[0] = _createWithdraw4626HookData(
                    bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                    vars.source,
                    address(strategy),
                    vars.sharesToRedeem,
                    false,
                    false
                );
                vars.hooksData[1] = _createDeposit4626HookData(
                    bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vars.destination, vars.amountToMove, true, false
                );

                vm.startPrank(STRATEGIST);
                strategy.executeHooks(vars.hooksAddresses, vars.hooksData);
                vm.stopPrank();

                // Update remaining amounts
                vars.sourceAmounts[i] -= vars.amountToMove;
                console2.log("euler dst amounts", vars.destinationAmounts[i]);
                vars.destinationAmounts[i] -= vars.amountToMove;
                console2.log("euler dst amounts after", vars.destinationAmounts[i]);
            }
        }

        // Handle any remaining sources or destinations by pairing them
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            if (vars.sourceAmounts[i] > 0) {
                for (uint256 j = 0; j < vars.destCount; j++) {
                    if (vars.destinationAmounts[j] > 0) {
                        vars.amountToMove = vars.sourceAmounts[i] < vars.destinationAmounts[j]
                            ? vars.sourceAmounts[i]
                            : vars.destinationAmounts[j];

                        if (vars.amountToMove > 0) {
                            console2.log("\nMoving remaining", vars.amountToMove);
                            console2.log("from", vars.sources[i], "to", vars.destinations[j]);
                            // Convert asset amount to shares for the source vault
                            if (vars.sources[i] == address(fluidVault)) {
                                vars.sharesToRedeem = fluidVault.convertToShares(vars.amountToMove);
                            } else if (vars.sources[i] == address(aaveVault)) {
                                vars.sharesToRedeem = aaveVault.convertToShares(vars.amountToMove);
                            } else if (vars.sources[i] == address(eulerVault)) {
                                vars.sharesToRedeem = eulerVault.convertToShares(vars.amountToMove);
                            }

                            console2.log("Shares to redeem:", vars.sharesToRedeem);

                            vars.hooksAddresses = new address[](2);
                            vars.hooksAddresses[0] = vars.withdrawHookAddress;
                            vars.hooksAddresses[1] = vars.depositHookAddress;

                            vars.hooksData = new bytes[](2);
                            vars.hooksData[0] = _createWithdraw4626HookData(
                                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                                vars.sources[i],
                                address(strategy),
                                vars.sharesToRedeem,
                                false,
                                false
                            );
                            vars.hooksData[1] = _createDeposit4626HookData(
                                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                                vars.destinations[j],
                                vars.amountToMove,
                                true,
                                false
                            );

                            vm.startPrank(STRATEGIST);
                            strategy.executeHooks(vars.hooksAddresses, vars.hooksData);
                            vm.stopPrank();

                            // Update remaining amounts
                            vars.sourceAmounts[i] -= vars.amountToMove;
                            vars.destinationAmounts[j] -= vars.amountToMove;

                            if (vars.sourceAmounts[i] == 0) {
                                break; // This source is depleted, move to next source
                            }
                        }
                    }
                }
            }
        }

        // Check new balances after reallocation
        vars.finalFluidVaultBalance = fluidVault.convertToAssets(fluidVault.balanceOf(address(strategy)));
        vars.finalAaveVaultBalance = aaveVault.convertToAssets(aaveVault.balanceOf(address(strategy)));
        vars.finalEulerVaultBalance = eulerVault.convertToAssets(eulerVault.balanceOf(address(strategy)));

        console2.log("\n=== Final Balances After First Reallocation ===");
        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final EulerVault balance:", vars.finalEulerVaultBalance);

        // Calculate final allocation percentages
        vars.totalFinalBalance = vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalEulerVaultBalance;
        vars.finalFluidRatio = (vars.finalFluidVaultBalance * 10_000) / vars.totalFinalBalance;
        vars.finalAaveRatio = (vars.finalAaveVaultBalance * 10_000) / vars.totalFinalBalance;
        vars.finalEulerRatio = (vars.finalEulerVaultBalance * 10_000) / vars.totalFinalBalance;

        console2.log("\n=== Final Allocation Ratios ===");
        console2.log("Fluid Vault:", vars.finalFluidRatio / 100, "%");
        console2.log("Aave Vault:", vars.finalAaveRatio / 100, "%");
        console2.log("Euler Vault:", vars.finalEulerRatio / 100, "%");

        // Verify the allocation is close to 50/25/25
        assertApproxEqRel(vars.finalFluidRatio, 5000, 0.05e18, "Fluid allocation should be close to 50%");
        assertApproxEqRel(vars.finalAaveRatio, 2500, 0.05e18, "Aave allocation should be close to 25%");
        assertApproxEqRel(vars.finalEulerRatio, 2500, 0.05e18, "Euler allocation should be close to 25%");

        // Second reallocation: Change to 40/30/30 (fluid/aave/euler)
        console2.log("\n=== Second Reallocation: Target 40/30/30 ===");

        // Set the vault cap to be slightly higher than the current assets in the Aave vault
        // This will cause the next reallocation to fail when trying to increase Aave allocation
        vars.newVaultCap = vars.finalAaveVaultBalance + (vars.finalAaveVaultBalance * 500 / 10_000); // Current + 5%

        console2.log("Setting new vault cap to:", vars.newVaultCap);

        vm.startPrank(MANAGER);
        vars.newConfig = ISuperVaultStrategy.GlobalConfig({
            vaultCap: vars.newVaultCap,
            superVaultCap: SUPER_VAULT_CAP,
            vaultThreshold: VAULT_THRESHOLD
        });
        strategy.updateGlobalConfig(vars.newConfig);
        vm.stopPrank();

        // Calculate target balances for 40/30/30 allocation
        vars.targetFluidAssets2 = vars.totalFinalBalance * 4000 / 10_000;
        vars.targetAaveAssets2 = vars.totalFinalBalance * 3000 / 10_000;
        vars.targetEulerAssets2 = vars.totalFinalBalance * 3000 / 10_000;

        console2.log("Total Assets:", vars.totalFinalBalance);
        console2.log("Target Fluid Assets:", vars.targetFluidAssets2);
        console2.log("Target Aave Assets:", vars.targetAaveAssets2);
        console2.log("Target Euler Assets:", vars.targetEulerAssets2);

        // Check if the target Aave assets would exceed the vault cap
        if (vars.targetAaveAssets2 > vars.newVaultCap) {
            console2.log("Target Aave assets would exceed vault cap!");
            console2.log("Vault Cap:", vars.newVaultCap);
            console2.log("Target Aave Assets:", vars.targetAaveAssets2);

            // Try to move assets from Fluid to Aave, which should fail with LIMIT_EXCEEDED
            vars.assetsToMove = vars.targetAaveAssets2 - vars.finalAaveVaultBalance;

            vars.hooksAddresses = new address[](2);
            vars.hooksAddresses[0] = vars.withdrawHookAddress;
            vars.hooksAddresses[1] = vars.depositHookAddress;

            vars.hooksData = new bytes[](2);
            vars.hooksData[0] = _createWithdraw4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                address(fluidVault),
                address(strategy),
                fluidVault.convertToShares(vars.assetsToMove),
                false,
                false
            );
            vars.hooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), vars.assetsToMove, true, false
            );

            vm.startPrank(STRATEGIST);
            vm.expectRevert(ISuperVaultStrategy.LIMIT_EXCEEDED.selector);
            strategy.executeHooks(vars.hooksAddresses, vars.hooksData);
            vm.stopPrank();

            // Now increase the vault cap to allow the reallocation
            console2.log("\nIncreasing vault cap to allow reallocation");
            vars.newVaultCap = vars.targetAaveAssets2 * 2; // Set to double the target to ensure it works

            vm.startPrank(MANAGER);
            vars.newConfig = ISuperVaultStrategy.GlobalConfig({
                vaultCap: vars.newVaultCap,
                superVaultCap: SUPER_VAULT_CAP,
                vaultThreshold: VAULT_THRESHOLD
            });
            strategy.updateGlobalConfig(vars.newConfig);
            vm.stopPrank();

            console2.log("New vault cap:", vars.newVaultCap);
        }

        // REFACTORED SECOND REALLOCATION ALGORITHM
        // Calculate the differences between current and target allocations
        vars.fluidDiff = int256(vars.targetFluidAssets2) - int256(vars.finalFluidVaultBalance);
        vars.aaveDiff = int256(vars.targetAaveAssets2) - int256(vars.finalAaveVaultBalance);
        vars.eulerDiff = int256(vars.targetEulerAssets2) - int256(vars.finalEulerVaultBalance);

        console2.log("\n=== Second Allocation Differences ===");
        console2.log("Fluid Diff:", vars.fluidDiff);
        console2.log("Aave Diff:", vars.aaveDiff);
        console2.log("Euler Diff:", vars.eulerDiff);

        // Reset arrays
        vars.sources = new address[](3);
        vars.sourceAmounts = new uint256[](3);
        vars.destinations = new address[](3);
        vars.destinationAmounts = new uint256[](3);
        vars.sourceCount = 0;
        vars.destCount = 0;

        if (vars.fluidDiff < 0) {
            vars.sources[vars.sourceCount] = address(fluidVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.fluidDiff);
            vars.sourceCount++;
        } else if (vars.fluidDiff > 0) {
            vars.destinations[vars.destCount] = address(fluidVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.fluidDiff);
            vars.destCount++;
        }

        if (vars.aaveDiff < 0) {
            vars.sources[vars.sourceCount] = address(aaveVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.aaveDiff);
            vars.sourceCount++;
        } else if (vars.aaveDiff > 0) {
            vars.destinations[vars.destCount] = address(aaveVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.aaveDiff);
            vars.destCount++;
        }

        if (vars.eulerDiff < 0) {
            vars.sources[vars.sourceCount] = address(eulerVault);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.eulerDiff);
            vars.sourceCount++;
        } else if (vars.eulerDiff > 0) {
            vars.destinations[vars.destCount] = address(eulerVault);
            vars.destinationAmounts[vars.destCount] = uint256(vars.eulerDiff);
            vars.destCount++;
        }

        // Resize arrays to actual count
        vars.sources = _resizeAddressArray(vars.sources, vars.sourceCount);
        vars.sourceAmounts = _resizeUint256Array(vars.sourceAmounts, vars.sourceCount);
        vars.destinations = _resizeAddressArray(vars.destinations, vars.destCount);
        vars.destinationAmounts = _resizeUint256Array(vars.destinationAmounts, vars.destCount);

        console2.log("\n=== Second Reallocation Sources and Destinations ===");
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            console2.log("Source:", vars.sources[i]);
            console2.log("Amount:", vars.sourceAmounts[i]);
        }
        for (uint256 i = 0; i < vars.destCount; i++) {
            console2.log("Destination:", vars.destinations[i]);
            console2.log("Amount:", vars.destinationAmounts[i]);
        }

        // Iteratively move assets from sources to destinations
        for (uint256 i = 0; i < vars.sourceCount && i < vars.destCount; i++) {
            vars.source = vars.sources[i];
            vars.destination = vars.destinations[i];
            vars.amountToMove =
                vars.sourceAmounts[i] < vars.destinationAmounts[i] ? vars.sourceAmounts[i] : vars.destinationAmounts[i];

            if (vars.amountToMove > 0) {
                console2.log("\nMoving", vars.amountToMove);
                console2.log("from", vars.source, "to", vars.destination);

                // Convert asset amount to shares for the source vault
                if (vars.source == address(fluidVault)) {
                    vars.sharesToRedeem = fluidVault.convertToShares(vars.amountToMove);
                } else if (vars.source == address(aaveVault)) {
                    vars.sharesToRedeem = aaveVault.convertToShares(vars.amountToMove);
                } else if (vars.source == address(eulerVault)) {
                    vars.sharesToRedeem = eulerVault.convertToShares(vars.amountToMove);
                }

                console2.log("Shares to redeem:", vars.sharesToRedeem);

                vars.hooksAddresses = new address[](2);
                vars.hooksAddresses[0] = vars.withdrawHookAddress;
                vars.hooksAddresses[1] = vars.depositHookAddress;

                vars.hooksData = new bytes[](2);
                vars.hooksData[0] = _createWithdraw4626HookData(
                    bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                    vars.source,
                    address(strategy),
                    vars.sharesToRedeem,
                    false,
                    false
                );
                vars.hooksData[1] = _createDeposit4626HookData(
                    bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vars.destination, vars.amountToMove, true, false
                );

                vm.startPrank(STRATEGIST);
                strategy.executeHooks(vars.hooksAddresses, vars.hooksData);
                vm.stopPrank();

                // Update remaining amounts
                vars.sourceAmounts[i] -= vars.amountToMove;
                vars.destinationAmounts[i] -= vars.amountToMove;
            }
        }

        // Handle any remaining sources or destinations by pairing them
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            if (vars.sourceAmounts[i] > 0) {
                for (uint256 j = 0; j < vars.destCount; j++) {
                    if (vars.destinationAmounts[j] > 0) {
                        vars.amountToMove = vars.sourceAmounts[i] < vars.destinationAmounts[j]
                            ? vars.sourceAmounts[i]
                            : vars.destinationAmounts[j];

                        if (vars.amountToMove > 0) {
                            console2.log("\nMoving remaining", vars.amountToMove);
                            console2.log("from", vars.sources[i], "to", vars.destinations[j]);

                            // Convert asset amount to shares for the source vault
                            uint256 sharesToRedeem;
                            if (vars.sources[i] == address(fluidVault)) {
                                vars.sharesToRedeem = fluidVault.convertToShares(vars.amountToMove);
                            } else if (vars.sources[i] == address(aaveVault)) {
                                vars.sharesToRedeem = aaveVault.convertToShares(vars.amountToMove);
                            } else if (vars.sources[i] == address(eulerVault)) {
                                vars.sharesToRedeem = eulerVault.convertToShares(vars.amountToMove);
                            }

                            console2.log("Shares to redeem:", vars.sharesToRedeem);

                            vars.hooksAddresses = new address[](2);
                            vars.hooksAddresses[0] = vars.withdrawHookAddress;
                            vars.hooksAddresses[1] = vars.depositHookAddress;

                            vars.hooksData = new bytes[](2);
                            vars.hooksData[0] = _createWithdraw4626HookData(
                                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                                vars.sources[i],
                                address(strategy),
                                vars.sharesToRedeem,
                                false,
                                false
                            );
                            vars.hooksData[1] = _createDeposit4626HookData(
                                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                                vars.destinations[j],
                                vars.amountToMove,
                                true,
                                false
                            );

                            vm.startPrank(STRATEGIST);
                            strategy.executeHooks(vars.hooksAddresses, vars.hooksData);
                            vm.stopPrank();

                            // Update remaining amounts
                            vars.sourceAmounts[i] -= vars.amountToMove;
                            vars.destinationAmounts[j] -= vars.amountToMove;

                            if (vars.sourceAmounts[i] == 0) {
                                break; // This source is depleted, move to next source
                            }
                        }
                    }
                }
            }
        }

        // Check final balances after second reallocation
        vars.finalFluidVaultBalance2 = fluidVault.convertToAssets(fluidVault.balanceOf(address(strategy)));
        vars.finalAaveVaultBalance2 = aaveVault.convertToAssets(aaveVault.balanceOf(address(strategy)));
        vars.finalEulerVaultBalance2 = eulerVault.convertToAssets(eulerVault.balanceOf(address(strategy)));

        console2.log("\n=== Final Balances After Second Reallocation ===");
        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance2);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance2);
        console2.log("Final EulerVault balance:", vars.finalEulerVaultBalance2);

        // Calculate final allocation percentages
        vars.totalFinalBalance2 =
            vars.finalFluidVaultBalance2 + vars.finalAaveVaultBalance2 + vars.finalEulerVaultBalance2;
        vars.finalFluidRatio2 = (vars.finalFluidVaultBalance2 * 10_000) / vars.totalFinalBalance2;
        vars.finalAaveRatio2 = (vars.finalAaveVaultBalance2 * 10_000) / vars.totalFinalBalance2;
        vars.finalEulerRatio2 = (vars.finalEulerVaultBalance2 * 10_000) / vars.totalFinalBalance2;

        console2.log("\n=== Final Allocation Ratios ===");
        console2.log("Fluid Vault:", vars.finalFluidRatio2 / 100, "%");
        console2.log("Aave Vault:", vars.finalAaveRatio2 / 100, "%");
        console2.log("Euler Vault:", vars.finalEulerRatio2 / 100, "%");

        // Verify the allocation is close to 40/30/30
        assertApproxEqRel(vars.finalFluidRatio2, 4000, 0.05e18, "Fluid allocation should be close to 40%");
        assertApproxEqRel(vars.finalAaveRatio2, 3000, 0.05e18, "Aave allocation should be close to 30%");
        assertApproxEqRel(vars.finalEulerRatio2, 3000, 0.05e18, "Euler allocation should be close to 30%");

        // Verify total value is preserved
        vars.finalTotalValue = vars.finalFluidVaultBalance2 + vars.finalAaveVaultBalance2 + vars.finalEulerVaultBalance2;

        assertApproxEqRel(
            vars.finalTotalValue,
            vars.totalInitialBalance,
            0.01e18,
            "Total value should be preserved during reallocation"
        );
    }

    function test_10_RuggableVault_Deposit_No_ExpectedAssetsOrSharesOut() public {
        RugTestVarsDeposit memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 10; // 0.1% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs on deposit
        vars.ruggableVault = new RuggableVault(
            IERC20(address(asset)),
            "Ruggable Vault",
            "RUG",
            true, // rug on deposit
            false, // don't rug on withdraw
            vars.rugPercentage
        );

        // Add funds to the ruggable vault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(address(vars.ruggableVault), type(uint256).max);
        vars.ruggableVault.deposit(2 * VAULT_THRESHOLD, address(this));

        // Deploy a new SuperVault with the ruggable vault
        _deployNewSuperVaultWithRuggableVault(address(vars.ruggableVault));

        // Setup deposit users and amounts
        vars.depositUsers = new address[](5);
        vars.depositAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // Perform deposits
        for (uint256 i = 0; i < 5; i++) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.requestDeposit(vars.depositAmounts[i], vars.depositUsers[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Store initial state
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Log initial state
        console2.log("\n=== Initial State ===");
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", vars.ruggableVault.balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Simulate time passing
        vm.warp(vars.initialTimestamp + 1 days);

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = 0; //10% slippage
        expectedAssetsOrSharesOut[1] = 0; // this should make the call revert

        _fulfillDepositForUsers(
            vars.depositUsers,
            vars.depositAmount * 5 / 2,
            vars.depositAmount * 5 / 2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            bytes4(0)
        );
    }

    function test_10_RuggableVault_Deposit() public {
        RugTestVarsDeposit memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 10; // 0.1% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs on deposit
        vars.ruggableVault = new RuggableVault(
            IERC20(address(asset)),
            "Ruggable Vault",
            "RUG",
            true, // rug on deposit
            false, // don't rug on withdraw
            vars.rugPercentage
        );

        // Add funds to the ruggable vault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(address(vars.ruggableVault), type(uint256).max);
        vars.ruggableVault.deposit(2 * VAULT_THRESHOLD, address(this));

        // Deploy a new SuperVault with the ruggable vault
        _deployNewSuperVaultWithRuggableVault(address(vars.ruggableVault));

        // Setup deposit users and amounts
        vars.depositUsers = new address[](5);
        vars.depositAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // Perform deposits
        for (uint256 i = 0; i < 5; i++) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.requestDeposit(vars.depositAmounts[i], vars.depositUsers[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Store initial state
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Log initial state
        console2.log("\n=== Initial State ===");
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", vars.ruggableVault.balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Simulate time passing
        vm.warp(vars.initialTimestamp + 1 days);

        uint256 sharesVault1 = IERC4626(address(fluidVault)).convertToShares(vars.depositAmount * 5 / 2);
        uint256 sharesVault2 = IERC4626(address(vars.ruggableVault)).convertToShares(vars.depositAmount * 5 / 2);

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = sharesVault1 - sharesVault1 * 1e4 / 1e5; //10% slippage
        expectedAssetsOrSharesOut[1] = sharesVault2 * 2; // this should make the call revert

        // expect revert on this call and try again after
        _fulfillDepositForUsers(
            vars.depositUsers,
            vars.depositAmount * 5 / 2,
            vars.depositAmount * 5 / 2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            ISuperVaultStrategy.MINIMUM_OUTPUT_AMOUNT_NOT_MET.selector
        );

        expectedAssetsOrSharesOut[1] = sharesVault2 - sharesVault2 * 1e3 / 1e5; //1% slippage
        _fulfillDepositForUsers(
            vars.depositUsers,
            vars.depositAmount * 5 / 2,
            vars.depositAmount * 5 / 2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            bytes4(0)
        );
    }

    function test_10_RuggableVault_WithdrawX() public {
        RugTestVarsWithdraw memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 5000; // 50% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs on withdraw
        RuggableVault ruggableVault = new RuggableVault(
            IERC20(address(asset)),
            "Ruggable Vault",
            "RUG",
            false, // don't rug on deposit
            true, // rug on withdraw
            vars.rugPercentage
        );

        vars.ruggableVault = address(ruggableVault);
        vars.convertVault = false;
        // Log the rug configuration
        console2.log("\n=== RuggableVault Configuration ===");
        console2.log("Rug on deposit:", ruggableVault.rugOnDeposit());
        console2.log("Rug on withdraw:", ruggableVault.rugOnWithdraw());
        console2.log("Rug percentage:", ruggableVault.rugPercentage());

        // Calculate how much would be rugged for a sample amount
        uint256 sampleAmount = 1000e6;
        uint256 ruggedAmount = ruggableVault.calculateRuggedAmount(sampleAmount);
        console2.log("For a sample amount of", sampleAmount, "the rugged amount would be", ruggedAmount);

        // Verify the rug calculation is correct
        assertEq(
            ruggedAmount,
            sampleAmount * vars.rugPercentage / 10_000,
            "Rugged amount calculation should match expected value"
        );

        _testRuggableVaultWithdraw(vars);
    }

    function test_10_RuggableVault_Withdraw_ConvertDistortion() public {
        RugTestVarsWithdraw memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 5000; // 50% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs via convert functions
        RuggableConvertVault ruggableConvertVault = new RuggableConvertVault(
            IERC20(address(asset)),
            "Ruggable Convert Vault",
            "RUGC",
            vars.rugPercentage,
            true // rug enabled
        );

        vars.ruggableVault = address(ruggableConvertVault);
        vars.convertVault = true;
        _testRuggableVaultWithdraw(vars);

        // Verify that the SuperVault's totalAssets was affected by the inflated reporting
        uint256 vaultTotalAssets = ruggableConvertVault.totalAssets();
        console2.log("Ruggable vault total assets:", vaultTotalAssets);

        // Disable the rug to see the true value
        ruggableConvertVault.setRugEnabled(false);
        uint256 vaultTotalAssetsWithoutRug = ruggableConvertVault.totalAssets();
        console2.log("Ruggable total assets (rug disabled):", vaultTotalAssetsWithoutRug);
        console2.log("Difference:", vaultTotalAssets - vaultTotalAssetsWithoutRug);

        // The difference should be significant if there are still assets in the ruggable vault
        assertGt(
            vaultTotalAssets, vaultTotalAssetsWithoutRug, "SuperVault total assets should be higher with rug enabled"
        );
    }

    function test_9_VaultLifecycle_FullAlocateOverTime_() public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allocation
        _completeDepositFlow(vars.depositAmount);

        uint256[] memory initialUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory initialUserShares = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            initialUserShares[i] = vault.balanceOf(accInstances[i].account);
        }

        vm.warp(block.timestamp + 20 days);

        uint256[] memory midUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory midUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            midUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            midUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(midUserAssets[i], initialUserAssets[i], "User assets should increase after 20 days");
            assertEq(midUserShares[i], initialUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Yield after 20 days ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Current Assets:", midUserAssets[i]);
            console2.log("Yield:", midUserAssets[i] - initialUserAssets[i]);
            console2.log("Yield %:", ((midUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]);
        }

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        // 100% to aave allocation
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);

        vm.warp(block.timestamp + 20 days);

        uint256[] memory finalUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory finalUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }

        // allocation; fluid -> aave
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);
        // redeem from fluid entirely
        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false,
            false
        );
        // deposit to aave
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        assertEq(vars.finalFluidVaultBalance, 0, "FluidVault balance should be 0");
        assertGt(vars.finalAaveVaultBalance, vars.initialAaveVaultBalance, "AaveVault balance should increase");

        vm.warp(block.timestamp + 20 days);

        // 80% to aave allocation
        vars.amountToReallocateAaveVault = vars.finalAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        // re-allocate back to fluid; withdraw from aave (20%)
        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false,
            false
        );
        // deposit to f;io
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total final value should be preserved during allocation"
        );

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }
    }

    function test_9_VaultLifecycle_AddAndRemoveOverTime() public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allocation
        _completeDepositFlow(vars.depositAmount);

        uint256[] memory initialUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory initialUserShares = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            initialUserShares[i] = vault.balanceOf(accInstances[i].account);
        }

        vm.warp(block.timestamp + 20 days);

        uint256[] memory midUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory midUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            midUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            midUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(midUserAssets[i], initialUserAssets[i], "User assets should increase after 20 days");
            assertEq(midUserShares[i], initialUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Yield after 20 days ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Current Assets:", midUserAssets[i]);
            console2.log("Yield:", midUserAssets[i] - initialUserAssets[i]);
            console2.log("Yield %:", ((midUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]);
        }

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        // 100% to aave allocation
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);

        vm.warp(block.timestamp + 20 days);

        uint256[] memory finalUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory finalUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }

        // allocation; fluid -> aave
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);
        // redeem from fluid entirely
        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false,
            false
        );
        // deposit to aave
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        // disable fluid vault entirely
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 2, false);
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        assertEq(vars.finalFluidVaultBalance, 0, "FluidVault balance should be 0");
        assertGt(vars.finalAaveVaultBalance, vars.initialAaveVaultBalance, "AaveVault balance should increase");

        vm.warp(block.timestamp + 20 days);

        // 80% to aave allocation
        vars.amountToReallocateAaveVault = vars.finalAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        // re-allocate back to fluid; withdraw from aave (20%)
        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false,
            false
        );
        // deposit to f;io
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.YIELD_SOURCE_NOT_ACTIVE.selector);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        // re-enable fluid vault
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 2, true);
        vm.stopPrank();

        // try allocate again
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total final value should be preserved during allocation"
        );

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }
    }

    function test_1_DynamicAllocation(uint256 amount) public {
        NewYieldSourceVars memory vars;
        vars.depositAmount = bound(amount, 10e6, 1000e6);

        vars.newVault = new Mock4626Vault(asset, "New Vault", "NV");

        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(address(vars.newVault), type(uint256).max);
        vars.newVault.deposit(2 * VAULT_THRESHOLD, address(this));

        // warp before adding a new vault;
        vm.warp(block.timestamp + 20 days);

        // -- add it as a new yield source
        vm.startPrank(MANAGER);
        strategy.manageYieldSource(address(vars.newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // warp again
        vm.warp(block.timestamp + 20 days);

        // create deposit requests for all users
        _requestDepositForAllUsers(vars.depositAmount);

        // create fullfillment data
        uint256 totalAmount = vars.depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount * 40 / 100;
        uint256 allocationAmountVault2 = totalAmount * 30 / 100;
        uint256 allocationAmountVault3 = totalAmount * 30 / 100;

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked {
                ++i;
            }
        }

        // fulfill deposits
        _fulfillDepositForUsers(
            requestingUsers,
            address(fluidVault),
            address(aaveVault),
            address(vars.newVault),
            allocationAmountVault1,
            allocationAmountVault2,
            allocationAmountVault3
        );

        // claim deposits
        for (uint256 i; i < ACCOUNT_COUNT;) {
            _claimDepositForAccount(accInstances[i], vars.depositAmount);
            unchecked {
                ++i;
            }
        }

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialMockVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial MockVault balance:", vars.initialMockVaultBalance);

        _test_1_performReallocation(vars);

        console2.log("\n=== Enhanced Vault Metrics ===");
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(1e18);
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(1e18);
        uint256 mockVaultFinalPPS = vars.newVault.convertToAssets(1e18);

        console2.log("\nPrice per Share Changes:");
        console2.log("Fluid Vault:");
        console2.log("  Initial PPS:", vars.initialFluidVaultPPS);
        console2.log("  Final PPS:", fluidVaultFinalPPS);
        console2.log(
            "  Change:",
            fluidVaultFinalPPS > vars.initialFluidVaultPPS ? "+" : "",
            fluidVaultFinalPPS - vars.initialFluidVaultPPS
        );
        console2.log(
            "  Change %:", ((fluidVaultFinalPPS - vars.initialFluidVaultPPS) * 10_000) / vars.initialFluidVaultPPS
        );

        console2.log("\nAave Vault:");
        console2.log("  Initial PPS:", vars.initialAaveVaultPPS);
        console2.log("  Final PPS:", aaveVaultFinalPPS);
        console2.log(
            "  Change:",
            aaveVaultFinalPPS > vars.initialAaveVaultPPS ? "+" : "",
            aaveVaultFinalPPS - vars.initialAaveVaultPPS
        );
        console2.log(
            "  Change %:", ((aaveVaultFinalPPS - vars.initialAaveVaultPPS) * 10_000) / vars.initialAaveVaultPPS
        );

        console2.log("\nYield Metrics:");
        uint256 totalYield =
            vars.finalTotalValue > vars.initialTotalValue ? vars.finalTotalValue - vars.initialTotalValue : 0;
        console2.log("Total Yield:", totalYield);
        console2.log("Yield %:", (totalYield * 10_000) / vars.initialTotalValue);

        assertGe(fluidVaultFinalPPS, vars.initialFluidVaultPPS, "Fluid Vault should not lose value");
        assertGe(aaveVaultFinalPPS, vars.initialAaveVaultPPS, "Aave Vault should not lose value");
        assertGe(mockVaultFinalPPS, 1e18, "Mock Vault should not lose value");

        uint256 totalFinalBalance =
            vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalMockVaultBalance;
        uint256 fluidRatio = (vars.finalFluidVaultBalance * 100) / totalFinalBalance;
        uint256 aaveRatio = (vars.finalAaveVaultBalance * 100) / totalFinalBalance;
        uint256 mockRatio = (vars.finalMockVaultBalance * 100) / totalFinalBalance;

        console2.log("\nFinal Allocation Ratios:");
        console2.log("Fluid Vault:", fluidRatio, "%");
        console2.log("Aave Vault:", aaveRatio, "%");
        console2.log("Mock Vault:", mockRatio, "%");
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _test_1_performReallocation(NewYieldSourceVars memory vars) private {
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToMockVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);
        console2.log("Asset amount to reallocate from MocmVault:", vars.assetAmountToReallocateToMockVault);

        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        bytes[] memory hooksData = new bytes[](3);

        // Setup hooks
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false,
            false
        );

        hooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false,
            false
        );

        hooksData[2] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.newVault),
            vars.assetAmountToReallocateToMockVault,
            false,
            false
        );

        // Perform allocation
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        vm.warp(block.timestamp + 20 days);

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalMockVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("MockVault balance:", vars.finalMockVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.initialMockVaultBalance);
        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.finalMockVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved during allocation - after first reallocation"
        );

        // Verify balance changes
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

        vars.initialMockVaultBalance = vars.newVault.balanceOf(address(strategy));
        vars.assetAmountToReallocateToMockVault = vars.newVault.convertToAssets(vars.initialMockVaultBalance);
        vars.assetAmountToReallocateFromFluidVault = vars.assetAmountToReallocateToMockVault * 30 / 100;
        vars.assetAmountToReallocateFromAaveVault =
            vars.initialMockVaultBalance - vars.assetAmountToReallocateFromFluidVault; // the rest goes here

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);
        console2.log("Asset amount to reallocate from MocmVault:", vars.assetAmountToReallocateToMockVault);

        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;
        hooksAddresses[2] = depositHookAddress;

        hooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.newVault),
            address(strategy),
            vars.assetAmountToReallocateToMockVault,
            false,
            false
        );

        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            false
        );

        hooksData[2] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            false
        );

        // Perform allocation
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(hooksAddresses, hooksData);
        vm.stopPrank();

        vm.warp(block.timestamp + 20 days);

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalMockVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("MockVault balance:", vars.finalMockVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.finalMockVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved during allocation - after second reallocation"
        );
    }

    function _verifyInitialBalances(uint256[] memory depositAmounts) internal view {
        console2.log("\n=== Initial State ===");
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 pricePerShare = totalAssets.mulDiv(1e18, totalSupply, Math.Rounding.Floor);

        console2.log("Total Assets:", totalAssets);
        console2.log("Total Supply:", totalSupply);
        console2.log("Price per share:", pricePerShare);

        // Verify vault invariants
        assertGt(totalSupply, 0, "Total supply should be positive");
        assertGt(totalAssets, 0, "Total assets should be positive");
        assertGe(pricePerShare, 1e18, "Initial price per share should be >= 1");

        // Verify underlying balances
        uint256 totalUnderlyingInVaults =
            fluidVault.balanceOf(address(strategy)) + aaveVault.balanceOf(address(strategy));
        assertGt(totalUnderlyingInVaults, 0, "Should have balance in underlying vaults");

        // Verify total deposits match total assets (accounting for bootstrap amount)
        uint256 expectedTotalDeposits = BOOTSTRAP_AMOUNT;
        for (uint256 i; i < depositAmounts.length; i++) {
            expectedTotalDeposits += depositAmounts[i];
        }
        assertApproxEqRel(totalAssets, expectedTotalDeposits, 0.01e18, "Total assets should match deposits");

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 shares = vault.balanceOf(accInstances[i].account);
            uint256 assets = vault.convertToAssets(shares);
            assertApproxEqRel(assets, depositAmounts[i], 0.01e18);
            console2.log("\nUser", i);
            console2.log("deposited:", depositAmounts[i]);
            console2.log("got shares:", shares);
            console2.log("got assets:", assets);

            // Verify share-asset conversion consistency
            uint256 sharesFromAssets = vault.convertToShares(assets);
            assertApproxEqRel(sharesFromAssets, shares, 0.01e18, "Share-asset conversion should be consistent");
        }
    }

    function _selectRandomUsersForRedemption(MultipleOperationsVars memory vars)
        internal
        view
        returns (MultipleOperationsVars memory)
    {
        uint256 i;
        while (vars.selectedCount < 15) {
            uint256 randIndex = uint256(keccak256(abi.encodePacked(vars.seed, "redeem", i))) % ACCOUNT_COUNT;

            if (!vars.selected[randIndex]) {
                vars.redeemUsers[vars.selectedCount] = accInstances[randIndex].account;
                // Redeem 25-75% of their balance
                uint256 randPercent = 2500 + (uint256(keccak256(abi.encodePacked(vars.seed, "percent", i))) % 5100);
                uint256 shares = vault.balanceOf(accInstances[randIndex].account);

                vars.redeemAmounts[vars.selectedCount] = (shares * randPercent) / 10_000;
                vars.selected[randIndex] = true;
                vars.selectedCount++;
            }
            i++;
        }
        return vars;
    }

    function _processRedemptionRequests(MultipleOperationsVars memory vars) internal {
        for (uint256 i; i < vars.selectedCount; i++) {
            vm.startPrank(vars.redeemUsers[i]);
            vault.requestRedeem(vars.redeemAmounts[i], vars.redeemUsers[i], vars.redeemUsers[i]);
            vm.stopPrank();
        }
    }

    function _claimRedeemForUsers(address[] memory redeemUsers) internal {
        for (uint256 i; i < redeemUsers.length; i++) {
            address user = redeemUsers[i];
            uint256 maxWithdrawAmount = vault.maxWithdraw(user);
            if (maxWithdrawAmount > 0) {
                vm.startPrank(user);
                vault.withdraw(maxWithdrawAmount, user, user);
                vm.stopPrank();
            }
        }
    }

    function _verifyFinalBalances(MultipleOperationsVars memory vars) internal view {
        FinalBalanceVerificationVars memory v;

        // Calculate global vault state
        v.finalTotalAssets = vault.totalAssets();
        v.finalTotalSupply = vault.totalSupply();
        v.finalPricePerShare = v.finalTotalAssets.mulDiv(1e18, v.finalTotalSupply, Math.Rounding.Floor);
        v.totalValueLocked = v.finalTotalAssets;

        // Get escrow balance
        v.escrowBalance = vault.balanceOf(address(escrow));

        // Log final state
        console2.log("\n=== Final State ===");
        console2.log("Final Total Assets:", v.finalTotalAssets);
        console2.log("Final Total Supply:", v.finalTotalSupply);
        console2.log("Final Price per share:", v.finalPricePerShare);
        console2.log("Total Value Locked:", v.totalValueLocked);
        console2.log("Escrow Balance:", v.escrowBalance);

        // Verify escrow state
        assertEq(v.escrowBalance, 0, "Escrow should have no shares after all claims are processed");

        // Calculate yield metrics
        v.totalYieldAccrued =
            v.finalTotalAssets > vars.initialTotalAssets ? v.finalTotalAssets - vars.initialTotalAssets : 0;
        v.yieldPerShare = v.totalYieldAccrued.mulDiv(1e18, v.finalTotalSupply, Math.Rounding.Floor);

        console2.log("\n=== Yield Metrics ===");
        console2.log("Total Yield Accrued:", v.totalYieldAccrued);
        console2.log("Yield Per Share:", v.yieldPerShare);

        // Verify yield accrual
        assertGe(
            v.finalPricePerShare,
            vars.initialPricePerShare,
            "Price per share should not decrease over time due to yield"
        );
        assertGt(v.totalValueLocked, 0, "TVL should be positive");

        // Verify strategy state
        v.fluidBalance = fluidVault.balanceOf(address(strategy));
        v.aaveBalance = aaveVault.balanceOf(address(strategy));

        console2.log("\n=== Strategy State ===");
        console2.log("Fluid Vault Balance:", v.fluidBalance);
        console2.log("Aave Vault Balance:", v.aaveBalance);

        // Strategy invariant checks
        assertGt(v.fluidBalance, 0, "Should maintain minimum fluid vault allocation");
        assertGt(v.aaveBalance, 0, "Should maintain minimum aave vault allocation");

        // Verify user states and accumulate totals
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            v.currentShares = vault.balanceOf(accInstances[i].account);
            v.currentAssets = vault.convertToAssets(v.currentShares);
            v.totalUserShares += v.currentShares;
            v.totalUserAssets += v.currentAssets;

            // Check if user is a redeemer
            v.isRedeemer = false;
            v.redeemedShares = 0;
            for (uint256 j; j < 15; j++) {
                if (accInstances[i].account == vars.redeemUsers[j]) {
                    v.isRedeemer = true;
                    v.redeemedShares = vars.redeemAmounts[j];
                    break;
                }
            }

            // Calculate user's yield
            v.userYieldAccrued = v.currentAssets > vars.depositAmounts[i] ? v.currentAssets - vars.depositAmounts[i] : 0;

            console2.log(string.concat("\n=== User ", Strings.toString(i), " State ==="));
            console2.log("Current Shares:", v.currentShares);
            console2.log("Current Assets:", v.currentAssets);
            console2.log("Yield Accrued:", v.userYieldAccrued);

            if (v.isRedeemer) {
                v.expectedShares = vault.convertToShares(vars.depositAmounts[i]) - v.redeemedShares;
                assertApproxEqRel(v.currentShares, v.expectedShares, 0.01e18, "Redeemer shares mismatch");

                // Verify redeemer's remaining position if they still have shares
                if (v.currentShares > 0) {
                    assertGt(
                        v.currentAssets.mulDiv(v.finalTotalSupply, v.currentShares, Math.Rounding.Floor),
                        vars.depositAmounts[i],
                        "Redeemer's remaining position should be worth more due to yield"
                    );
                }
            } else {
                v.expectedAssets = vars.depositAmounts[i];
                assertApproxEqRel(v.currentAssets, v.expectedAssets, 0.01e18, "Non-redeemer assets mismatch");
                assertGt(v.currentAssets, vars.depositAmounts[i], "Non-redeemer should have more assets due to yield");
            }

            // Verify no pending operations
            v.totalPendingDeposits += strategy.pendingDepositRequest(accInstances[i].account);
            v.totalPendingRedeems += strategy.pendingRedeemRequest(accInstances[i].account);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0, "Should have no pending deposits");
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0, "Should have no pending redemptions");
        }

        // Final global state verification
        console2.log("\n=== Final Verification ===");
        console2.log("Total User Shares:", v.totalUserShares);
        console2.log("Total User Assets:", v.totalUserAssets);
        console2.log("Total Pending Deposits:", v.totalPendingDeposits);
        console2.log("Total Pending Redeems:", v.totalPendingRedeems);

        assertApproxEqRel(v.totalUserShares, v.finalTotalSupply, 0.01e18, "Total shares should match supply");
        assertApproxEqRel(v.totalUserAssets, v.finalTotalAssets, 0.01e18, "Total assets should match TVL");
        assertEq(v.totalPendingDeposits, 0, "Should have no pending deposits globally");
        assertEq(v.totalPendingRedeems, 0, "Should have no pending redeems globally");
    }

    function _testRuggableVaultWithdraw(RugTestVarsWithdraw memory vars) internal {
        // Add funds to the ruggable vault to respect VAULT_THRESHOLD
        _getTokens(address(asset), address(this), 2 * VAULT_THRESHOLD);
        asset.approve(vars.ruggableVault, type(uint256).max);
        IERC4626(vars.ruggableVault).deposit(2 * VAULT_THRESHOLD, address(this));

        // Deploy a new SuperVault with the ruggable vault
        _deployNewSuperVaultWithRuggableVault(vars.ruggableVault);

        // Setup deposit users and amounts
        vars.depositUsers = new address[](5);
        vars.depositAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // Perform deposits
        for (uint256 i = 0; i < 5; i++) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.requestDeposit(vars.depositAmounts[i], vars.depositUsers[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Fulfill deposit requests
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = IERC4626(address(fluidVault)).convertToShares(vars.depositAmount * 5 / 2);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vars.ruggableVault)).convertToShares(vars.depositAmount * 5 / 2);
        _fulfillDepositForUsers(
            vars.depositUsers,
            vars.depositAmount * 5 / 2,
            vars.depositAmount * 5 / 2,
            address(fluidVault),
            vars.ruggableVault
        );
        console2.log("\n=== TIME WARPING ===");

        vars.ppsBeforeWarp = vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor);
        console2.log("PPS BEFORE WARP", vars.ppsBeforeWarp);
        vm.warp(block.timestamp + 10 weeks);
        vars.ppsAfterWarp = vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor);
        console2.log("PPS AFTER WARP", vars.ppsAfterWarp);
        // Claim deposits
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(vars.depositUsers[i]);
            uint256 maxDeposit = vault.maxDeposit(vars.depositUsers[i]);
            vault.deposit(maxDeposit, vars.depositUsers[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Store initial state
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Log initial state
        console2.log("\n=== Initial State Before Redemption ===");
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", IERC4626(vars.ruggableVault).balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Verify the initial state
        assertGt(vars.initialTotalAssets, 0, "Initial total assets should be positive");
        assertGt(vars.initialTotalSupply, 0, "Initial total supply should be positive");

        // Setup redeem users and amounts
        vars.redeemUsers = new address[](3);
        vars.redeemAmounts = new uint256[](3);
        vars.totalRedeemShares = 0;

        for (uint256 i = 0; i < 3; i++) {
            vars.redeemUsers[i] = vars.depositUsers[i];
            uint256 userShares = vault.balanceOf(vars.redeemUsers[i]);
            vars.redeemAmounts[i] = userShares; // Redeem all of their shares
            vars.totalRedeemShares += vars.redeemAmounts[i];
        }

        // Request redemptions
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(vars.redeemUsers[i]);
            vault.requestRedeem(vars.redeemAmounts[i], vars.redeemUsers[i], vars.redeemUsers[i]);
            vm.stopPrank();
        }

        // Simulate time passing
        console2.log("\n=== TIME WARPING ===");

        vars.ppsBeforeWarp = vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor);
        console2.log("PPS BEFORE WARP", vars.ppsBeforeWarp);
        vm.warp(block.timestamp + 12 weeks);
        vars.ppsAfterWarp = vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor);
        console2.log("PPS AFTER WARP", vars.ppsAfterWarp);

        // Fulfill redemption requests
        vars.redeemSharesVault1 = vars.totalRedeemShares / 2;
        vars.redeemSharesVault2 = vars.totalRedeemShares - vars.redeemSharesVault1;

        vars.assetsVault1 = IERC4626(address(fluidVault)).convertToAssets(vars.redeemSharesVault1);
        vars.assetsVault2 = IERC4626(address(vars.ruggableVault)).convertToAssets(vars.redeemSharesVault2);

        vars.expectedAssetsOrSharesOut = new uint256[](2);
        vars.expectedAssetsOrSharesOut[0] = vars.assetsVault1 - vars.assetsVault1; //10% slippage
        vars.expectedAssetsOrSharesOut[1] = vars.assetsVault2 * 2; // this should make the call revert

        // this should revert
        _fulfillRedeemForUsers(
            vars.redeemUsers,
            vars.redeemSharesVault1,
            vars.redeemSharesVault2,
            address(fluidVault),
            vars.ruggableVault,
            vars.expectedAssetsOrSharesOut,
            ISuperVaultStrategy.MINIMUM_OUTPUT_AMOUNT_NOT_MET.selector
        );

        vars.expectedAssetsOrSharesOut[0] = vars.assetsVault1 / 2;
        vars.expectedAssetsOrSharesOut[1] = vars.assetsVault2 / 2;
        _fulfillRedeemForUsers(
            vars.redeemUsers,
            vars.redeemSharesVault1,
            vars.redeemSharesVault2,
            address(fluidVault),
            vars.ruggableVault,
            vars.expectedAssetsOrSharesOut,
            bytes4(0)
        );

        // Log post-fulfillment state
        console2.log("\n=== Post-Fulfillment State ===");
        uint256 totalAssetsPreClaimTaintedAssets = vault.totalAssets();
        uint256 totalSupplyPreClaimTaintedAssets = vault.totalSupply();
        console2.log("Total Assets:", totalAssetsPreClaimTaintedAssets);
        console2.log("Total Supply:", totalSupplyPreClaimTaintedAssets);
        uint256 pricePerSharePreClaimTaintedAssets =
            totalAssetsPreClaimTaintedAssets.mulDiv(1e18, totalSupplyPreClaimTaintedAssets, Math.Rounding.Floor);
        console2.log("Price per share:", pricePerSharePreClaimTaintedAssets);
        console2.log("Ruggable Vault Balance:", IERC4626(vars.ruggableVault).balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Process claims for redeemed users, this will burn all tainted shares
        _claimRedeemForUsers(vars.redeemUsers);

        // Verify global state
        uint256 finalTotalAssets = vault.totalAssets();
        uint256 finalTotalSupply = vault.totalSupply();
        uint256 finalPricePerShare = finalTotalAssets.mulDiv(1e18, finalTotalSupply, Math.Rounding.Floor);

        console2.log("\n=== Final State ===");
        console2.log("Final Total Assets:", finalTotalAssets);
        console2.log("Final Total Supply:", finalTotalSupply);
        console2.log("Final Price per share:", finalPricePerShare);

        // CONTINUATION: Allocate from rugged vault back to fluid vault
        console2.log("\n=== Allocating from Rugged Vault back to Fluid Vault ===");

        // Get initial balances
        vars.initialRuggableVaultBalance = IERC4626(vars.ruggableVault).balanceOf(address(strategy));
        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));

        console2.log("Initial Ruggable Vault balance:", vars.initialRuggableVaultBalance);
        console2.log("Initial Fluid Vault balance:", vars.initialFluidVaultBalance);

        // Calculate asset amounts
        vars.initialRuggableVaultAssets = IERC4626(vars.ruggableVault).convertToAssets(vars.initialRuggableVaultBalance);
        vars.initialFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);

        console2.log("Initial Ruggable Vault assets:", vars.initialRuggableVaultAssets);
        console2.log("Initial Fluid Vault assets:", vars.initialFluidVaultAssets);

        vars.amountToReallocate = vars.initialRuggableVaultBalance;
        vars.assetAmountToReallocate =
            IERC4626(vars.ruggableVault).convertToAssets(vars.amountToReallocate) * 5000 / 10_000;

        console2.log("Shares to reallocate from Ruggable Vault:", vars.amountToReallocate);
        console2.log("Asset amount to reallocate:", vars.assetAmountToReallocate);

        // Skip reallocation if there are no shares to reallocate
        if (vars.amountToReallocate > 0) {
            // Prepare allocation hooks
            address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
            address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

            address[] memory hooksAddresses = new address[](2);
            hooksAddresses[0] = withdrawHookAddress;
            hooksAddresses[1] = depositHookAddress;

            bytes[] memory hooksData = new bytes[](2);

            // Redeem from Ruggable Vault
            hooksData[0] = _createWithdraw4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                vars.ruggableVault,
                address(strategy),
                vars.amountToReallocate,
                false,
                false
            );

            // Deposit to Fluid Vault
            hooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                address(fluidVault),
                vars.assetAmountToReallocate,
                false,
                false
            );

            // Execute allocation
            vm.startPrank(STRATEGIST);
            strategy.executeHooks(hooksAddresses, hooksData);
            vm.stopPrank();

            // Check final balances
            vars.finalRuggableVaultBalance = IERC4626(vars.ruggableVault).balanceOf(address(strategy));
            vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));

            console2.log("Final Ruggable Vault balance:", vars.finalRuggableVaultBalance);
            console2.log("Final Fluid Vault balance:", vars.finalFluidVaultBalance);

            // Calculate asset amounts after reallocation
            vars.finalRuggableVaultAssets = IERC4626(vars.ruggableVault).convertToAssets(vars.finalRuggableVaultBalance);
            vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);

            console2.log("Final Ruggable Vault assets:", vars.finalRuggableVaultAssets);
            console2.log("Final Fluid Vault assets:", vars.finalFluidVaultAssets);

            // Verify reallocation
            assertApproxEqRel(
                vars.finalRuggableVaultBalance,
                vars.initialRuggableVaultBalance - vars.amountToReallocate,
                0.01e18,
                "Ruggable Vault balance should decrease by the reallocated amount"
            );

            assertGt(vars.finalFluidVaultBalance, vars.initialFluidVaultBalance, "Fluid Vault balance should increase");

            // Check total value preservation
            vars.initialTotalValue = vars.initialRuggableVaultAssets + vars.initialFluidVaultAssets;
            vars.finalTotalValue = vars.finalRuggableVaultAssets + vars.finalFluidVaultAssets;

            console2.log("Initial total value:", vars.initialTotalValue);
            console2.log("Final total value:", vars.finalTotalValue);

            // Check final vault state
            vars.vaultTotalAssetsAfterAllocation = vault.totalAssets();
            vars.pricePerShareAfterAllocation =
                vars.vaultTotalAssetsAfterAllocation.mulDiv(1e18, finalTotalSupply, Math.Rounding.Floor);

            console2.log("Vault total assets after allocation:", vars.vaultTotalAssetsAfterAllocation);
            console2.log("Price per share after allocation:", vars.pricePerShareAfterAllocation);
        } else {
            console2.log("Skipping reallocation as there are no shares to reallocate");
        }
    }

    function _deployNewSuperVaultWithRuggableVault(address ruggableVault) internal {
        // Deploy a new SuperVault with the ruggable vault
        address vaultAddr;
        address strategyAddr;
        address escrowAddr;
        (vaultAddr, strategyAddr, escrowAddr) = _deployVault("SV_USDC_RUG");

        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Replace aaveVault with ruggableVault in the strategy
        vm.startPrank(SV_MANAGER);
        strategy.manageYieldSource(ruggableVault, _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true); // Add
            // ruggableVault
        vm.stopPrank();
    }

    // Structure to hold test variables
    struct TestVars {
        uint256 initialTimestamp;
        uint256 totalDeposited;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 finalTotalAssets;
        uint256 finalTotalSupply;
        uint256 finalPricePerShare;
        uint256 fluidVaultBalance;
        uint256 aaveVaultBalance;
        uint256[] depositAmounts;
        address[] depositUsers;
    }

    function test_12_multiMillionDeposits() public {
        TestVars memory vars;
        vars.initialTimestamp = block.timestamp;

        // Set up deposit amounts for multiple rounds
        // We'll do 3 rounds of deposits to reach 10M+ USDC
        uint256 depositRounds = 3;
        uint256 targetTotalDeposits = 9_000_000e6; // 10M USDC
        uint256 depositPerRound = targetTotalDeposits / depositRounds;
        uint256 depositPerUser = depositPerRound / ACCOUNT_COUNT;

        console2.log("\n=== Starting multi-million deposit test ===");
        console2.log("Target total deposits:", targetTotalDeposits / 1e6, "M USDC");
        console2.log("Deposit rounds:", depositRounds);
        console2.log("Deposit per round:", depositPerRound / 1e6, "M USDC");
        console2.log("Deposit per user per round:", depositPerUser / 1e6, "M USDC");

        // Round 1: Initial deposits
        console2.log("\n=== Round 1 Deposits ===");
        vars.depositAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            vars.depositAmounts[i] = depositPerUser;
        }
        _completeDepositFlowWithVaryingAmounts(vars.depositAmounts);
        vars.totalDeposited += depositPerRound;
        console2.log("balance of vault", IERC20(address(asset)).balanceOf(address(strategy)));
        console2.log("total deposited", vars.totalDeposited);
        console2.log("Total Assets:", vault.totalAssets());

        // Wait 1 week
        vm.warp(vars.initialTimestamp + 1 weeks);
        console2.log("\n=== After 1 week ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Round 2: More deposits after 1 week
        console2.log("\n=== Round 2 Deposits ===");
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _getTokens(address(asset), accInstances[i].account, depositPerUser);
            _requestDepositForAccount(accInstances[i], depositPerUser);
        }

        // Prepare for fulfillment
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        // Fulfill deposits with 60/40 split between vaults
        console2.log("deposit per round", depositPerRound);

        uint256 allocationAmountVault1 = (depositPerRound * 6000) / 10_000; // 60% to fluid vault
        uint256 allocationAmountVault2 = depositPerRound - allocationAmountVault1; // 40% to aave vault
        console2.log("\n=== Round 2 Fulfill Requests ===");

        console2.log("allocation vault 1", allocationAmountVault1);
        console2.log("allocation vault 2", allocationAmountVault2);
        console2.log("balance of vault", IERC20(address(asset)).balanceOf(address(strategy)));
        // TVL fluid 1669215723572
        // tvl aave 1668059877911
        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // Claim deposits
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _claimDepositForAccount(accInstances[i], depositPerUser);
        }

        vars.totalDeposited += depositPerRound;

        // Wait 2 more weeks
        vm.warp(vars.initialTimestamp + 3 weeks);
        console2.log("\n=== After 3 weeks ===");
        console2.log("Total Assets:", vault.totalAssets() / 1e6, "M USDC");
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Round 3: Final deposits after 3 weeks
        console2.log("\n=== Round 3 Deposits ===");
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _getTokens(address(asset), accInstances[i].account, depositPerUser);
            _requestDepositForAccount(accInstances[i], depositPerUser);
        }

        // Wait 2 more weeks before fulfilling final deposits
        vm.warp(vars.initialTimestamp + 5 weeks);
        console2.log("\n=== After 5 weeks (before final fulfillment) ===");
        console2.log("Total Assets:", vault.totalAssets() / 1e6, "M USDC");
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Store state before final fulfillment
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Fulfill final deposits with 70/30 split
        allocationAmountVault1 = (depositPerRound * 70) / 100; // 70% to fluid vault
        allocationAmountVault2 = depositPerRound - allocationAmountVault1; // 30% to aave vault

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // Claim deposits
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _claimDepositForAccount(accInstances[i], depositPerUser);
        }

        vars.totalDeposited += depositPerRound;

        // Final verification after all deposits
        console2.log("\n=== Final state after all deposits ===");
        vars.finalTotalAssets = vault.totalAssets();
        vars.finalTotalSupply = vault.totalSupply();
        vars.finalPricePerShare = vars.finalTotalAssets.mulDiv(1e18, vars.finalTotalSupply, Math.Rounding.Floor);

        console2.log("Total deposited:", vars.totalDeposited / 1e6, "M USDC");
        console2.log("Final total assets:", vars.finalTotalAssets / 1e6, "M USDC");
        console2.log("Final price per share:", vars.finalPricePerShare);

        // Check underlying vault balances
        vars.fluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.aaveVaultBalance = aaveVault.balanceOf(address(strategy));

        uint256 fluidVaultAssets = fluidVault.convertToAssets(vars.fluidVaultBalance);
        uint256 aaveVaultAssets = aaveVault.convertToAssets(vars.aaveVaultBalance);

        console2.log("\n=== Underlying vault balances ===");
        console2.log("Fluid vault shares:", vars.fluidVaultBalance);
        console2.log("Fluid vault assets:", fluidVaultAssets / 1e6, "M USDC");
        console2.log("Aave vault shares:", vars.aaveVaultBalance);
        console2.log("Aave vault assets:", aaveVaultAssets / 1e6, "M USDC");
        console2.log("Total underlying assets:", (fluidVaultAssets + aaveVaultAssets) / 1e6, "M USDC");

        // Verify total assets matches the sum of underlying vault assets
        assertApproxEqRel(vars.finalTotalAssets, fluidVaultAssets + aaveVaultAssets, 0.01e18); // 1% tolerance

        // Verify price per share increased over time (yield accrual)
        assertGt(vars.finalPricePerShare, 1e18, "Price per share should be greater than 1e18 after yield accrual");

        // Verify total deposits reached target
        assertGe(
            vars.finalTotalAssets, targetTotalDeposits, "Total assets should be at least the target deposit amount"
        );
    }

    /**
     * @notice Resizes an array of addresses to the specified length
     * @param array The original array to resize
     * @param newLength The new length for the array
     * @return A new array with the specified length containing elements from the original array
     */
    function _resizeAddressArray(address[] memory array, uint256 newLength) internal pure returns (address[] memory) {
        address[] memory newArray = new address[](newLength);
        for (uint256 i = 0; i < newLength; i++) {
            newArray[i] = array[i];
        }
        return newArray;
    }

    /**
     * @notice Resizes an array of uint256 to the specified length
     * @param array The original array to resize
     * @param newLength The new length for the array
     * @return A new array with the specified length containing elements from the original array
     */
    function _resizeUint256Array(uint256[] memory array, uint256 newLength) internal pure returns (uint256[] memory) {
        uint256[] memory newArray = new uint256[](newLength);
        for (uint256 i = 0; i < newLength; i++) {
            newArray[i] = array[i];
        }
        return newArray;
    }
}
