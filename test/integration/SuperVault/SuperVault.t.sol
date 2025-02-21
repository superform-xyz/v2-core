// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";

// superform
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";

contract SuperVaultTest is MerkleReader, BaseSuperVaultTest {
    function setUp() public override(BaseTest, BaseSuperVaultTest) {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _requestDeposit(depositAmount);

        // Verify state
        assertEq(strategy.pendingDepositRequest(accountEth), depositAmount, "Wrong pending deposit amount");
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");
    }

    function test_FulfillDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup deposit request first
        _requestDeposit(depositAmount);

        // Verify request state
        assertEq(strategy.pendingDepositRequest(accountEth), depositAmount, "Wrong pending deposit amount");
        console2.log("Pending deposit request:", strategy.pendingDepositRequest(accountEth));
        // Fulfill deposit
        _fulfillDeposit(depositAmount);

        // Verify state
        assertEq(strategy.pendingDepositRequest(accountEth), 0, "Pending request not cleared");
        assertGt(strategy.maxMint(accountEth), 0, "No shares available to mint");
    }

    function test_FulfillRedeem_FullAmount() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        uint256 vaultBalance = vault.balanceOf(accountEth);
        uint256 redeemShares = vaultBalance - (vaultBalance *2e4/1e5);
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.maxWithdraw(accountEth), 0, "No assets available to withdraw");
    }

    function test_FulfillRedeem_FullAmountV2() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        uint256 redeemShares = vault.balanceOf(accountEth);
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.maxWithdraw(accountEth), 0, "No assets available to withdraw");
    }



    function test_ClaimDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup and fulfill deposit
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);

        // Get claimable shares
        uint256 claimableShares = strategy.maxMint(accountEth);

        // Claim deposit
        _claimDeposit(depositAmount);

        // Verify state
        assertEq(vault.balanceOf(accountEth), claimableShares, "Wrong share balance");
        assertEq(strategy.maxMint(accountEth), 0, "Shares not claimed");
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestRedeem() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        // Now request redeem of half the shares
        uint256 redeemShares = vault.balanceOf(accountEth) / 2;
        _requestRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), redeemShares, "Wrong pending redeem amount");
        assertEq(vault.balanceOf(address(escrow)), redeemShares, "Wrong escrow balance");
    }

    function test_FulfillRedeem() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        // Now request redeem of half the shares
        uint256 redeemShares = vault.balanceOf(accountEth) / 2;
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.maxWithdraw(accountEth), 0, "No assets available to withdraw");
    }

    function test_ClaimRedeem() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _requestDeposit(depositAmount);
        _fulfillDeposit(depositAmount);
        _claimDeposit(depositAmount);

        // Get initial balances
        uint256 initialAssetBalance = asset.balanceOf(accountEth);
        uint256 initialShares = vault.balanceOf(accountEth);

        // Request redeem of half the shares
        uint256 redeemShares = initialShares / 2;
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares);

        // Get claimable assets
        uint256 claimableAssets = strategy.maxWithdraw(accountEth);

        // Claim redeem
        _claimWithdraw(claimableAssets);

        // Verify state
        assertEq(vault.balanceOf(accountEth), initialShares - redeemShares, "Wrong final share balance");
        assertApproxEqRel(
            asset.balanceOf(accountEth), initialAssetBalance + claimableAssets, 0.05e18, "Wrong final asset balance"
        );
        assertEq(strategy.maxWithdraw(accountEth), 0, "Assets not claimed");
    }

    // TODO: Add remaining tests following test-plan.md
}