// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/console2.sol";


// superform

import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";


import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";




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
        uint256 initialPendeVaultBalance;
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
        address pendleVault;
        // Price per share tracking
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialMockVaultPPS;
    }

    struct VaultLifecycleVars {
        uint256 depositAmount;
        uint256 initialTimestamp;
        uint256[] userDepositAmounts;
        address[] users;
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialMockVaultPPS;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        uint256[] userInitialShares;
        uint256[] userInitialAssets;
        uint256[] userFinalShares;
        uint256[] userFinalAssets;
        uint256[] userYields;
    }

    function test_MultipleOperations_RandomAmounts(uint256 seed) public {
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

        // Complete deposits with varying amounts
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
        _fulfillRedeemForUsers(vars.redeemUsers, vars.redeemSharesVault1, vars.redeemSharesVault2);

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

    function test_Allocate_NewYieldSource() public {
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

        vm.warp(block.timestamp + 20 days);

        // allocation
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](3);
        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = _getMerkleProof(withdrawHookAddress);
        proofs[2] = _getMerkleProof(depositHookAddress);

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

        // change allocation rates to allow 30/30/40 allo
        vm.startPrank(MANAGER);
        strategy.updateGlobalConfig(
            ISuperVaultStrategy.GlobalConfig({
                vaultCap: VAULT_CAP,
                superVaultCap: SUPER_VAULT_CAP,
                maxAllocationRate: 5000,
                vaultThreshold: VAULT_THRESHOLD
            })
        );
        vm.stopPrank();

        vm.startPrank(STRATEGIST);
        strategy.allocate(hooksAddresses, proofs, hooksData);
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

        // Enhanced checks for price per share and yield
        console2.log("\n=== Enhanced Vault Metrics ===");
        
        // Price per share comparison
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(1e18);
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(1e18);
        uint256 mockVaultFinalPPS = vars.newVault.convertToAssets(1e18);

        console2.log("\nPrice per Share Changes:");
        console2.log("Fluid Vault:");
        console2.log("  Initial PPS:", vars.initialFluidVaultPPS);
        console2.log("  Final PPS:", fluidVaultFinalPPS);
        console2.log("  Change:", fluidVaultFinalPPS > vars.initialFluidVaultPPS ? "+" : "", 
            fluidVaultFinalPPS - vars.initialFluidVaultPPS);
        console2.log("  Change %:", ((fluidVaultFinalPPS - vars.initialFluidVaultPPS) * 10000) / vars.initialFluidVaultPPS);

        console2.log("\nAave Vault:");
        console2.log("  Initial PPS:", vars.initialAaveVaultPPS);
        console2.log("  Final PPS:", aaveVaultFinalPPS);
        console2.log("  Change:", aaveVaultFinalPPS > vars.initialAaveVaultPPS ? "+" : "", 
            aaveVaultFinalPPS - vars.initialAaveVaultPPS);
        console2.log("  Change %:", ((aaveVaultFinalPPS - vars.initialAaveVaultPPS) * 10000) / vars.initialAaveVaultPPS);

        console2.log("\nYield Metrics:");
        uint256 totalYield = vars.finalTotalValue > vars.initialTotalValue ? 
            vars.finalTotalValue - vars.initialTotalValue : 0;
        console2.log("Total Yield:", totalYield);
        console2.log("Yield %:", (totalYield * 10000) / vars.initialTotalValue);

        assertGe(fluidVaultFinalPPS, vars.initialFluidVaultPPS, "Fluid Vault should not lose value");
        assertGe(aaveVaultFinalPPS, vars.initialAaveVaultPPS, "Aave Vault should not lose value");
        assertGe(mockVaultFinalPPS, 1e18, "Mock Vault should not lose value");

        uint256 totalFinalBalance = vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalMockVaultBalance;
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
        for (uint256 i; i < ACCOUNT_COUNT && vars.selectedCount < 15; i++) {
            uint256 randIndex = uint256(keccak256(abi.encodePacked(vars.seed, "redeem", i))) % ACCOUNT_COUNT;
            if (!vars.selected[randIndex]) {
                vars.selected[randIndex] = true;
                vars.redeemUsers[vars.selectedCount] = accInstances[randIndex].account;
                // Redeem 25-75% of their balance
                uint256 randPercent = 25 + (uint256(keccak256(abi.encodePacked(vars.seed, "percent", i))) % 51);
                uint256 shares = vault.balanceOf(accInstances[randIndex].account);
                vars.redeemAmounts[vars.selectedCount] = (shares * randPercent) / 100;
                vars.selectedCount++;
            }
        }
        return vars;
    }

    function _processRedemptionRequests(MultipleOperationsVars memory vars) internal {
        for (uint256 i; i < 15; i++) {
            vm.startPrank(vars.redeemUsers[i]);
            vault.requestRedeem(vars.redeemAmounts[i], vars.redeemUsers[i], vars.redeemUsers[i]);
            vm.stopPrank();
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
}
