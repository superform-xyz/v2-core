// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// superform
import { ISuperVault } from "src/periphery/interfaces/ISuperVault.sol";

contract SuperVaultE2EFlow is BaseSuperVaultTest {
    uint256 amountPerVault = 1000e6; // 1000 USDC

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SuperVault_E2E_Flow() public {
        // Initial setup - get USDC for testing account
        vm.selectFork(FORKS[ETH]);
        deal(address(asset), accountEth, amountPerVault);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 initialVaultAssets = asset.balanceOf(address(vault));
        uint256 initialUserShares = IERC20(vault.share()).balanceOf(accountEth);

        // Step 1: Request Deposit
        _requestDeposit(amountPerVault);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth),
            initialUserAssets - amountPerVault,
            "User assets not reduced after deposit request"
        );
        assertEq(
            asset.balanceOf(address(strategy)),
            initialVaultAssets + amountPerVault,
            "Vault assets not increased after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit(amountPerVault);

        // Step 3: Claim Deposit
        _claimDeposit(amountPerVault);

        // Verify shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);
        assertGt(userShares, 0, "No shares minted to user");
        assertGt(userShares, initialUserShares, "User shares not increased after deposit");

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);
        uint256 preRedeemVaultAssets = asset.balanceOf(address(vault));
        uint256 preRedeemUserShares = IERC20(vault.share()).balanceOf(accountEth);

        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(preRedeemUserShares, 0, "Shares not transferred to escrow");

        // Step 5: Fulfill Redeem
        _fulfillRedeem(userShares);

        // Step 6: Claim Withdraw
        // Calculate expected assets based on shares
        uint256 expectedAssets = vault.convertToAssets(userShares);
        _claimWithdraw(expectedAssets);

        // Final balance assertions
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User should have no shares after redeem");
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");
        assertLt(asset.balanceOf(address(vault)), preRedeemVaultAssets, "Vault assets not decreased after redeem");
    }
}
