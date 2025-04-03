// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// superform
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

contract SuperVaultE2EFlow is BaseSuperVaultTest {
    ERC7540YieldSourceOracle public oracle;
    ISuperLedger public superLedgerETH;

    uint256 amount;

    struct MultipleDepositsPartialRedemptionsVars {
        // Balances
        uint256 initialUserAssets;
        uint256 feeBalanceBefore;
        // Deposit amounts
        uint256 deposit1Amount;
        uint256 deposit2Amount;
        uint256 deposit3Amount;
        // Shares
        uint256 shares1;
        uint256 shares2;
        uint256 shares3;
        uint256 totalShares;
        // Redemption 1
        uint256 redeemAmount1;
        uint256 superformFee1;
        uint256 recipientFee1;
        uint256 totalFee1;
        uint256 userBalanceBeforeRedeem1;
        uint256 treasuryBalanceAfterRedeem1;
        uint256 claimableAssets1;
        uint256 userAssetsAfterRedeem1;
        // Redemption 2
        uint256 remainingShares;
        uint256 redeemAmount2;
        uint256 superformFee2;
        uint256 recipientFee2;
        uint256 totalFee2;
        uint256 userBalanceBeforeRedeem2;
        uint256 treasuryBalanceAfterRedeem2;
        uint256 claimableAssets2;
        uint256 userAssetsAfterRedeem2;
        // Redemption 3
        uint256 finalShares;
        uint256 superformFee3;
        uint256 recipientFee3;
        uint256 totalFee3;
        uint256 userBalanceBeforeRedeem3;
        uint256 treasuryBalanceAfterRedeem3;
        uint256 claimableAssets3;
        uint256 userAssetsAfterRedeem3;
        // Totals
        uint256 totalDeposits;
        uint256 totalFees;
        uint256 totalAssetsReceived;
    }

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));

        oracle = ERC7540YieldSourceOracle(_getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY));

        _setUpSuperLedgerForVault();

        amount = 1000e6; // 1000 USDC
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SuperVault_E2E_Flow() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        _requestDeposit(amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit(amount, accountEth, address(fluidVault), address(aaveVault));

        // Step 3: Claim Deposit
        _claimDeposit(amount);

        // Get shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);

        console2.log("----deposit done ---");
        uint256 totalRedeemShares = vault.balanceOf(accountEth);

        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(IERC20(vault.share()).balanceOf(address(escrow)), userShares, "Shares not transferred to escrow");

        (uint256 superformFee, uint256 recipientFee) = _deriveSuperVaultFees(userShares, _getSuperVaultPricePerShare());

        uint256 totalFee = superformFee + recipientFee;

        _fulfillRedeem(totalRedeemShares, address(fluidVault), address(aaveVault));

        // Calculate expected assets based on shares
        uint256 claimableAssets = vault.maxWithdraw(accountEth);

        // Step 6: Claim Withdraw
        _claimWithdraw(claimableAssets);

        // Final balance assertions
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");

        // Verify fee was taken
        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));
    }

    function test_SuperVault_E2E_Flow_With_Ledger_Fees() public {
        vm.selectFork(FORKS[ETH]);

        _setUpSuperLedgerForVault_With_Ledger_Fees();

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 initialVaultAssets = asset.balanceOf(address(vault));

        // Step 1: Request Deposit
        _requestDeposit(amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );
        assertEq(
            asset.balanceOf(address(strategy)),
            initialVaultAssets + amount,
            "Vault assets not increased after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit(amount, accountEth, address(fluidVault), address(aaveVault));

        // Step 3: Claim Deposit
        _claimDeposit(amount);

        // Verify shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);

        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(IERC20(vault.share()).balanceOf(address(escrow)), userShares, "Shares not transferred to escrow");

        (uint256 superformFee, uint256 recipientFee) = _deriveSuperVaultFees(userShares, _getSuperVaultPricePerShare());

        // Step 5: Fulfill Redeem
        _fulfillRedeem(userShares, address(fluidVault), address(aaveVault));

        // Calculate expected assets based on shares
        uint256 claimableAssets = vault.maxWithdraw(accountEth);

        uint256 expectedLedgerFee = superLedgerETH.previewFees(accountEth, address(vault), claimableAssets, userShares, 100);

        // Step 6: Claim Withdraw
        _claimWithdraw(claimableAssets);

        uint256 totalFee = superformFee + recipientFee + expectedLedgerFee;

        // Final balance assertions
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");

        // Verify fee was taken
        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));
    }

    function test_SuperVault_MultipleDeposits_PartialRedemptions() public {
        vm.selectFork(FORKS[ETH]);

        MultipleDepositsPartialRedemptionsVars memory vars;

        // Record initial balances
        vars.initialUserAssets = asset.balanceOf(accountEth);
        vars.feeBalanceBefore = asset.balanceOf(TREASURY);

        // ========== DEPOSIT 1 ==========
        console2.log("===== DEPOSIT 1 =====");
        vars.deposit1Amount = 1000e6; // 1000 USDC

        // Step 1: Request first Deposit
        _requestDeposit(vars.deposit1Amount);

        // Step 2: Fulfill first Deposit
        _fulfillDeposit(vars.deposit1Amount, accountEth, address(fluidVault), address(aaveVault));

        // Step 3: Claim first Deposit
        _claimDeposit(vars.deposit1Amount);

        // Get shares minted to user for first deposit
        vars.shares1 = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Shares after deposit 1:", vars.shares1);

        // Simulate some yield accrual between deposits
        vm.warp(block.timestamp + 4 weeks);

        // ========== DEPOSIT 2 ==========
        console2.log("===== DEPOSIT 2 =====");
        vars.deposit2Amount = 2000e6; // 2000 USDC

        // Deal more tokens to user
        deal(address(asset), accountEth, vars.deposit2Amount);

        // Step 1: Request second Deposit
        _requestDeposit(vars.deposit2Amount);

        // Step 2: Fulfill second Deposit
        _fulfillDeposit(vars.deposit2Amount, accountEth, address(fluidVault), address(aaveVault));

        // Step 3: Claim second Deposit
        _claimDeposit(vars.deposit2Amount);

        // Get additional shares minted to user
        vars.shares2 = IERC20(vault.share()).balanceOf(accountEth) - vars.shares1;
        console2.log("Shares after deposit 2:", vars.shares2);

        // Simulate more yield accrual between deposits
        vm.warp(block.timestamp + 4 weeks);

        // ========== DEPOSIT 3 ==========
        console2.log("===== DEPOSIT 3 =====");
        vars.deposit3Amount = 3000e6; // 3000 USDC

        // Deal more tokens to user
        deal(address(asset), accountEth, vars.deposit3Amount);

        // Step 1: Request third Deposit
        _requestDeposit(vars.deposit3Amount);

        // Step 2: Fulfill third Deposit
        _fulfillDeposit(vars.deposit3Amount, accountEth, address(fluidVault), address(aaveVault));

        // Step 3: Claim third Deposit
        _claimDeposit(vars.deposit3Amount);

        // Get additional shares minted to user
        vars.shares3 = IERC20(vault.share()).balanceOf(accountEth) - vars.shares1 - vars.shares2;
        console2.log("Shares after deposit 3:", vars.shares3);

        // Get total shares for user
        vars.totalShares = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Total shares:", vars.totalShares);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 42 weeks); // significant time for yield accrual
        console2.log("PPS after 50 weeks:", _getSuperVaultPricePerShare());

        // ========== REDEMPTION 1 (25% of shares) ==========
        console2.log("===== REDEMPTION 1 (25%) =====");
        vars.redeemAmount1 = vars.totalShares / 4; // 25% of shares
        console2.log("Redeeming shares (25%):", vars.redeemAmount1);

        // Calculate expected fee for first redemption
        (vars.superformFee1, vars.recipientFee1) =
            _deriveSuperVaultFees(vars.redeemAmount1, _getSuperVaultPricePerShare());
        vars.totalFee1 = vars.superformFee1 + vars.recipientFee1;
        console2.log("Expected fee for redemption 1:", vars.totalFee1);

        vars.treasuryBalanceAfterRedeem1 = vars.feeBalanceBefore;

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem1 = asset.balanceOf(accountEth);

        // Step 1: Request first Redeem
        _requestRedeem(vars.redeemAmount1);

        // Step 2: Fulfill first Redeem
        _fulfillRedeem(vars.redeemAmount1, address(fluidVault), address(aaveVault));

        // Step 3: Claim first Withdraw
        vars.claimableAssets1 = vault.maxWithdraw(accountEth);
        _claimWithdraw(vars.claimableAssets1);

        vars.treasuryBalanceAfterRedeem1 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem1 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem1;
        console2.log("User received assets after redemption 1:", vars.userAssetsAfterRedeem1);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee1, vars.feeBalanceBefore, vars.treasuryBalanceAfterRedeem1);
        console2.log("Treasury balance after redemption 1:", vars.treasuryBalanceAfterRedeem1);

        // ========== REDEMPTION 2 (33% of remaining shares) ==========
        console2.log("===== REDEMPTION 2 (33% of remaining) =====");
        vars.remainingShares = IERC20(vault.share()).balanceOf(accountEth);
        vars.redeemAmount2 = vars.remainingShares / 3; // 33% of remaining shares
        console2.log("Redeeming shares (33% of remaining):", vars.redeemAmount2);

        // Calculate expected fee for second redemption
        (vars.superformFee2, vars.recipientFee2) =
            _deriveSuperVaultFees(vars.redeemAmount2, _getSuperVaultPricePerShare());
        vars.totalFee2 = vars.superformFee2 + vars.recipientFee2;
        console2.log("Expected fee for redemption 2:", vars.totalFee2);

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem2 = asset.balanceOf(accountEth);

        // Step 1: Request second Redeem
        _requestRedeem(vars.redeemAmount2);

        // Step 2: Fulfill second Redeem
        _fulfillRedeem(vars.redeemAmount2, address(fluidVault), address(aaveVault));

        // Step 3: Claim second Withdraw
        vars.claimableAssets2 = vault.maxWithdraw(accountEth);
        _claimWithdraw(vars.claimableAssets2);

        vars.treasuryBalanceAfterRedeem2 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem2 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem2;
        console2.log("User received assets after redemption 2:", vars.userAssetsAfterRedeem2);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee2, vars.treasuryBalanceAfterRedeem1, vars.treasuryBalanceAfterRedeem2);
        console2.log("Treasury balance after redemption 2:", vars.treasuryBalanceAfterRedeem2);

        // ========== REDEMPTION 3 (all remaining shares) ==========
        console2.log("===== REDEMPTION 3 (all remaining) =====");
        vars.finalShares = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Redeeming final shares:", vars.finalShares);

        // Calculate expected fee for third redemption
        (vars.superformFee3, vars.recipientFee3) =
            _deriveSuperVaultFees(vars.finalShares, _getSuperVaultPricePerShare());
        vars.totalFee3 = vars.superformFee3 + vars.recipientFee3;
        console2.log("Expected fee for redemption 3:", vars.totalFee3);

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem3 = asset.balanceOf(accountEth);

        // Step 1: Request third Redeem
        _requestRedeem(vars.finalShares);

        // Step 2: Fulfill third Redeem
        _fulfillRedeem(vars.finalShares, address(fluidVault), address(aaveVault));

        // Step 3: Claim third Withdraw
        vars.claimableAssets3 = vault.maxWithdraw(accountEth);
        _claimWithdraw(vars.claimableAssets3);

        vars.treasuryBalanceAfterRedeem3 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem3 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem3;
        console2.log("User received assets after redemption 3:", vars.userAssetsAfterRedeem3);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee3, vars.treasuryBalanceAfterRedeem2, vars.treasuryBalanceAfterRedeem3);

        // Verify total fee collection
        vars.totalFees = vars.totalFee1 + vars.totalFee2 + vars.totalFee3;
        console2.log("Total fees collected:", vars.totalFees);
        console2.log("Initial treasury balance:", vars.feeBalanceBefore);
        console2.log("Final treasury balance:", vars.treasuryBalanceAfterRedeem3);
        assertEq(
            vars.treasuryBalanceAfterRedeem3, vars.feeBalanceBefore + vars.totalFees, "Total fee collection mismatch"
        );

        // Verify user has received all assets minus fees
        vars.totalDeposits = vars.deposit1Amount + vars.deposit2Amount + vars.deposit3Amount;
        vars.totalAssetsReceived =
            vars.userAssetsAfterRedeem1 + vars.userAssetsAfterRedeem2 + vars.userAssetsAfterRedeem3;
        console2.log("Total deposits:", vars.totalDeposits);
        console2.log("Total assets received:", vars.totalAssetsReceived);
        assertGt(vars.totalAssetsReceived, vars.totalDeposits, "User should receive more than deposited due to yield");

        // Verify all shares are redeemed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User should have no shares left");
    }
}
