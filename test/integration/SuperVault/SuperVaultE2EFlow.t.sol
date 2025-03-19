// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// superform
import { ISuperVault } from "../../../src/periphery/interfaces/ISuperVault.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";


contract SuperVaultE2EFlow is BaseSuperVaultTest {
    ERC7540YieldSourceOracle public oracle;
    ISuperLedger public superLedgerETH;

    uint256 amount;

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

        uint256 expectedLedgerFee =
            superLedgerETH.previewFees(accountEth,
            // TODO: Remove
//                address(vault),
                claimableAssets, userShares, 100);

        // Step 6: Claim Withdraw
        _claimWithdraw(claimableAssets);

        uint256 totalFee = superformFee + recipientFee + expectedLedgerFee;

        // Final balance assertions
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");

        // Verify fee was taken
        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));

    }
}
