// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// superform
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

import { console2 } from "forge-std/console2.sol";

import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract SuperVaultFulfillRedeemRequestsTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using Math for uint256;

    function test_RequestRedeem_MultipleUsers(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // request redeem for all users
        _requestRedeemForAllUsers(0);
    }

    function test_RequestRedeemMultipleUsers_With_CompleteFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        uint256 totalRedeemShares;
        for (uint256 i; i < ACCOUNT_COUNT;) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            totalRedeemShares += vaultBalance;
            unchecked {
                ++i;
            }
        }

        // request redeem for all users
        _requestRedeemForAllUsers(0);

        // create fullfillment data
        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;

            unchecked {
                ++i;
            }
        }

        // fulfill redeem
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // check that all pending requests are cleared
        for (uint256 i; i < ACCOUNT_COUNT;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 2), 0);
            unchecked {
                ++i;
            }
        }
    }

    function test_RequestRedeem_MultipleUsers_DifferentAmounts() public {
        uint256 depositAmount = 1000e6;

        // first deposit same amount for all users
        _completeDepositFlow(depositAmount);

        uint256[] memory redeemAmounts = new uint256[](ACCOUNT_COUNT);
        uint256 totalRedeemShares;

        // create redeem requests with randomized amounts based on vault balance
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            // random amount between 50% and 100% of maxRedeemable
            redeemAmounts[i] =
                bound(uint256(keccak256(abi.encodePacked(block.timestamp, i))), vaultBalance / 2, vaultBalance);
            redeemAmounts[i] =
                bound(uint256(keccak256(abi.encodePacked(block.timestamp, i))), vaultBalance / 2, vaultBalance);
            _requestRedeemForAccount(accInstances[i], redeemAmounts[i]);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            totalRedeemShares += redeemAmounts[i];
        }

        // fulfill all redeem requests
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // verify all redeems were fulfilled
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 2), 0);
        }
    }

    function test_RequestRedeemMultipleUsers_With_PartialUsersFullfilment(uint256 depositAmount) public {
        depositAmount = 100e6;

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // store redeem amounts for later verification
        uint256[] memory redeemAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT;) {
            redeemAmounts[i] = vault.balanceOf(accInstances[i].account);
            unchecked {
                ++i;
            }
        }

        // request redeem for all users
        _requestRedeemForAllUsers(0);

        // create fulfillment data for half the users
        uint256 partialUsersCount = ACCOUNT_COUNT / 2;
        uint256 totalRedeemShares;

        // calculate total redeem shares for partial users
        for (uint256 i; i < partialUsersCount;) {
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
            unchecked {
                ++i;
            }
        }

        address[] memory requestingUsers = new address[](partialUsersCount);
        for (uint256 i; i < partialUsersCount;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked {
                ++i;
            }
        }

        (uint256 allocationAmountVault1, uint256 allocationAmountVault2) = _calculateVaultShares(totalRedeemShares);

        // fulfill redeem for half the users
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // check that fulfilled requests are cleared
        for (uint256 i; i < partialUsersCount;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 2), 0);
            unchecked {
                ++i;
            }
        }

        // check that remaining users still have pending requests
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            assertEq(strategy.getSuperVaultState(accInstances[i].account, 2), 0);
            unchecked {
                ++i;
            }
        }

        // calculate total redeem shares for remaining users
        totalRedeemShares = 0;
        uint256 j;
        requestingUsers = new address[](ACCOUNT_COUNT - partialUsersCount);
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT;) {
            requestingUsers[j] = accInstances[i].account;
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
            unchecked {
                ++i;
                ++j;
            }
        }

        allocationAmountVault1 = totalRedeemShares / 2;
        allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        // fulfill remaining users
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
    }

    function test_RequestRedeem_RevertOnExceedingBalance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // first deposit for single user
        _completeDepositFlow(depositAmount);

        // try to redeem more than balance
        uint256 vaultBalance = vault.balanceOf(accInstances[0].account);
        uint256 excessAmount = vaultBalance * 100;

        // should revert when trying to redeem more than balance
        _requestRedeemForAccount_Revert(accInstances[0], excessAmount);
    }

    function test_ClaimRedeem_RevertBeforeFulfillment() public {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        _requestRedeemForAccount(accInstances[0], redeemAmount);

        assertEq(strategy.pendingRedeemRequest(accInstances[0].account), redeemAmount);
        assertEq(strategy.getSuperVaultState(accInstances[0].account, 2), 0);

        // try/catch pattern to verify the revert
        bool claimFailed = false;
        try this.externalClaimWithdraw(accInstances[0], redeemAmount) {
            claimFailed = false;
        } catch {
            claimFailed = true;
        }

        assertTrue(claimFailed, "Claim should have failed before fulfillment");

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        uint256 allocationAmountVault1 = redeemAmount / 2;
        uint256 allocationAmountVault2 = redeemAmount - allocationAmountVault1;

        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        assertEq(strategy.pendingRedeemRequest(accInstances[0].account), 0);
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 2), 0);

        _claimWithdrawForAccount(accInstances[0], vault.maxWithdraw(accInstances[0].account));

        assertEq(strategy.getSuperVaultState(accInstances[0].account, 2), 0);
    }

    function test_ClaimRedeem_AfterPriceIncrease() public {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        _requestRedeemForAccount(accInstances[0], redeemAmount);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        uint256 allocationAmountVault1 = redeemAmount / 2;
        uint256 allocationAmountVault2 = redeemAmount - allocationAmountVault1;
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
        console2.log("fulfilled redeem");
        uint256 initialAssetBalance = asset.balanceOf(accInstances[0].account);

        // increase price of assets
        uint256 yieldAmount = 100e6;
        deal(address(asset), address(this), yieldAmount * 2);
        asset.approve(address(fluidVault), yieldAmount);
        asset.approve(address(aaveVault), yieldAmount);
        fluidVault.deposit(yieldAmount, address(this));
        aaveVault.deposit(yieldAmount, address(this));

        uint256 strategyAssetBalanceBefore = asset.balanceOf(address(strategy));
        uint256 maxWithdraw = vault.maxWithdraw(accInstances[0].account);
        _claimWithdrawForAccount(accInstances[0], maxWithdraw);
        uint256 assetsReceived = asset.balanceOf(accInstances[0].account) - initialAssetBalance;
        assertApproxEqRel(
            assetsReceived,
            maxWithdraw,
            0.01e18,
            "Assets received should be greater than or equal to requested redeem amount"
        );

        uint256 strategyAssetBalanceAfter = asset.balanceOf(address(strategy));
        assertApproxEqRel(
            strategyAssetBalanceBefore - strategyAssetBalanceAfter,
            assetsReceived,
            0.01e18,
            "Strategy asset balance should decrease by the amount sent to user"
        );

        assertApproxEqRel(
            strategyAssetBalanceBefore - strategyAssetBalanceAfter,
            assetsReceived,
            0.01e18,
            "Strategy asset balance should decrease by the amount sent to user"
        );

        console2.log("Requested redeem amount:", redeemAmount);
        console2.log("Actual assets received:", assetsReceived);
        console2.log("Strategy asset withdrawn", strategyAssetBalanceBefore - strategyAssetBalanceAfter);

        // make sure redeem is cleared even if we have small rounding errors
        assertEq(strategy.getSuperVaultState(accInstances[0].account, 2), 0);
    }

    function test_Redeem_RoundingBehavior() public {
        uint256 depositAmount = 1000e6;

        // add some tokens initially to the strategy
        _getTokens(address(asset), address(strategy), 1000);

        _getTokens(address(asset), accInstances[0].account, depositAmount);
        _requestDepositForAccount(accInstances[0], depositAmount);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        _fulfillDepositForUsers(requestingUsers, depositAmount / 2, depositAmount / 2);
        _claimDepositForAccount(accInstances[0], depositAmount);

        uint256 initialShareBalance = vault.balanceOf(accInstances[0].account);
        uint256 initialAssetBalance = asset.balanceOf(accInstances[0].account);

        console2.log("Initial share balance:", initialShareBalance);
        console2.log("Initial asset balance:", initialAssetBalance);
        console2.log("Share value in assets:", vault.convertToAssets(initialShareBalance));
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        _requestRedeemForAccount(accInstances[0], redeemAmount);
        _fulfillRedeemForUsers(requestingUsers, redeemAmount / 2, redeemAmount / 2);
        uint256 maxWithdraw = vault.maxWithdraw(accInstances[0].account);
        _claimWithdrawForAccount(accInstances[0], maxWithdraw);

        uint256 finalShareBalance = vault.balanceOf(accInstances[0].account);
        uint256 finalAssetBalance = asset.balanceOf(accInstances[0].account);
        uint256 sharesBurned = initialShareBalance - finalShareBalance;
        uint256 assetsReceived = finalAssetBalance - initialAssetBalance;
        console2.log("Shares burned:", sharesBurned);
        console2.log("Assets received:", assetsReceived);
        console2.log(
            "Difference:", maxWithdraw > assetsReceived ? maxWithdraw - assetsReceived : assetsReceived - maxWithdraw
        );

        uint256 difference = maxWithdraw > assetsReceived ? maxWithdraw - assetsReceived : assetsReceived - maxWithdraw;
        assertEq(difference, 0);

        uint256 remainingShareValue = vault.convertToAssets(finalShareBalance);
        console2.log("Remaining share balance:", finalShareBalance);
        console2.log("Remaining share value:", remainingShareValue);
        console2.log("Expected remaining value:", depositAmount - maxWithdraw);

        assertApproxEqRel(remainingShareValue, depositAmount - maxWithdraw, 0.001e18); // 0.1% tolerance
    }

    function externalClaimWithdraw(AccountInstance memory accInst, uint256 assets) external {
        _claimWithdrawForAccount(accInst, assets);
    }

    function test_RequestRedeem_VerifyAmounts() public {
        RedeemVerificationVars memory vars;
        vars.depositAmount = 1000e6;

        _completeDepositFlow(vars.depositAmount);

        vars.userShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            vars.userShareBalances[i] = vault.balanceOf(accInstances[i].account);
        }
        console2.log("pps", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        console2.log("deposits done");
        /// redeem half of the shares
        vars.redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        console2.log("redeem amount:", vars.redeemAmount);

        _requestRedeemForAllUsers(vars.redeemAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialStrategyAssetBalance = asset.balanceOf(address(strategy));

        vars.totalDepositAmount = vars.depositAmount * ACCOUNT_COUNT;
        vars.totalRedeemAmount = vars.redeemAmount * ACCOUNT_COUNT;

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        vars.allocationAmountVault1 = vars.totalRedeemAmount / 2;
        vars.allocationAmountVault2 = vars.totalRedeemAmount - vars.allocationAmountVault1;

        _fulfillRedeemForUsers(requestingUsers, vars.allocationAmountVault1, vars.allocationAmountVault2);

        vars.fluidVaultSharesDecrease = vars.initialFluidVaultBalance - fluidVault.balanceOf(address(strategy));
        vars.aaveVaultSharesDecrease = vars.initialAaveVaultBalance - aaveVault.balanceOf(address(strategy));
        vars.strategyAssetBalanceIncrease = asset.balanceOf(address(strategy)) - vars.initialStrategyAssetBalance;

        vars.fluidVaultAssetsValue = fluidVault.convertToAssets(vars.fluidVaultSharesDecrease);
        vars.aaveVaultAssetsValue = aaveVault.convertToAssets(vars.aaveVaultSharesDecrease);

        vars.totalAssetsRedeemed = vars.fluidVaultAssetsValue + vars.aaveVaultAssetsValue;

        vars.totalRedeemedAssets = vault.convertToAssets(vars.totalRedeemAmount);
        assertApproxEqRel(vars.totalAssetsRedeemed, vars.totalRedeemedAssets, 0.01e18);

        assertApproxEqRel(vars.strategyAssetBalanceIncrease, vars.totalRedeemedAssets, 0.01e18);

        _verifyRedeemSharesAndAssets(vars);
    }

    function test_MultipleUsers_SameAllocation_EqualRedeemValue() public {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256[] memory initialShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
            console2.log("User", i, "initial share balance:", initialShareBalances[i]);
        }
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        // request redem
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            _requestRedeemForAccount(accInstances[i], redeemAmount);
        }

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalRedeemAmount = redeemAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalRedeemAmount / 2;
        uint256 allocationAmountVault2 = totalRedeemAmount - allocationAmountVault1;

        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        uint256[] memory initialAssetBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }

        // Arrays to store results
        uint256[] memory assetsReceived = new uint256[](ACCOUNT_COUNT);
        uint256[] memory sharesBurned = new uint256[](ACCOUNT_COUNT);
        uint256[] memory assetPerShare = new uint256[](ACCOUNT_COUNT);

        // Claim redemptions for all users
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            // Record share balance before claiming
            uint256 shareBalanceBeforeClaim = vault.balanceOf(accInstances[i].account);
            console2.log("User", i, "share balance before claim:", shareBalanceBeforeClaim);
            uint256 maxWithdraw = vault.maxWithdraw(accInstances[i].account);
            _claimWithdrawForAccount(accInstances[i], maxWithdraw);

            uint256 shareBalanceAfterClaim = vault.balanceOf(accInstances[i].account);
            uint256 assetBalanceAfterClaim = asset.balanceOf(accInstances[i].account);

            console2.log("User", i, "share balance after claim:", shareBalanceAfterClaim);

            sharesBurned[i] = initialShareBalances[i] - shareBalanceAfterClaim;
            assetsReceived[i] = assetBalanceAfterClaim - initialAssetBalances[i];

            console2.log("User", i, "shares burned:", sharesBurned[i]);
            console2.log("User", i, "assets received:", assetsReceived[i]);

            if (sharesBurned[i] > 0) {
                assetPerShare[i] = assetsReceived[i] * 1e18 / sharesBurned[i];
                console2.log("User", i, "asset per share:", assetPerShare[i]);
            } else {
                console2.log("User", i, "!!! No shares were burned!");
            }

            assertGt(sharesBurned[i], 0, "No shares were burned for user");
            assertGt(assetsReceived[i], 0, "No assets were received for user");
        }

        for (uint256 i = 1; i < ACCOUNT_COUNT; i++) {
            assertApproxEqRel(assetPerShare[i], assetPerShare[0], 0.001e18, "Asset per share ratio should be equal");
            assertApproxEqRel(assetsReceived[i], assetsReceived[0], 0.001e18, "Assets received should be equal");
            assertApproxEqRel(sharesBurned[i], sharesBurned[0], 0.001e18, "Shares burned should be equal");
        }
    }

    function test_MultipleUsers_ChangingAllocation_RedeemValue() public {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256[] memory initialShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
        }

        // update to 90/10% allo rate
        vm.startPrank(MANAGER);
        strategy.updateGlobalConfig(
            ISuperVaultStrategy.GlobalConfig({
                vaultCap: VAULT_CAP,
                superVaultCap: SUPER_VAULT_CAP,
                maxAllocationRate: 9000, // 90%
                vaultThreshold: VAULT_THRESHOLD
            })
        );
        vm.stopPrank();
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            _requestRedeemForAccount(accInstances[i], redeemAmount);
        }
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalRedeemAmount = redeemAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalRedeemAmount * 90 / 100;
        uint256 allocationAmountVault2 = totalRedeemAmount - allocationAmountVault1;
        console2.log("Redeem allocation vault1:", allocationAmountVault1 * 100 / totalRedeemAmount, "%");
        console2.log("Redeem allocation vault2:", allocationAmountVault2 * 100 / totalRedeemAmount, "%");

        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        uint256[] memory initialAssetBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }

        uint256[] memory assetsReceived = new uint256[](ACCOUNT_COUNT);
        uint256[] memory sharesBurned = new uint256[](ACCOUNT_COUNT);
        uint256[] memory assetPerShare = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 maxWithdraw = vault.maxWithdraw(accInstances[i].account);
            _claimWithdrawForAccount(accInstances[i], maxWithdraw);

            uint256 shareBalanceAfterClaim = vault.balanceOf(accInstances[i].account);
            uint256 assetBalanceAfterClaim = asset.balanceOf(accInstances[i].account);

            sharesBurned[i] = initialShareBalances[i] - shareBalanceAfterClaim;
            assetsReceived[i] = assetBalanceAfterClaim - initialAssetBalances[i];

            if (sharesBurned[i] > 0) {
                assetPerShare[i] = assetsReceived[i] * 1e18 / sharesBurned[i];
            }

            assertGt(sharesBurned[i], 0, "No shares were burned for user");
            assertGt(assetsReceived[i], 0, "No assets were received for user");

            console2.log("User", i, "shares burned:", sharesBurned[i]);
            console2.log("User", i, "assets received:", assetsReceived[i]);
            console2.log("User", i, "asset per share:", assetPerShare[i]);
        }

        for (uint256 i = 1; i < ACCOUNT_COUNT; i++) {
            assertApproxEqRel(assetPerShare[i], assetPerShare[0], 0.001e18, "Asset per share ratio should be equal");
            assertApproxEqRel(assetsReceived[i], assetsReceived[0], 0.001e18, "Assets received should be equal");
            assertApproxEqRel(sharesBurned[i], sharesBurned[0], 0.001e18, "Shares burned should be equal");
        }

        uint256 totalAssetsReceived = 0;
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            totalAssetsReceived += assetsReceived[i];
        }

        assertApproxEqRel(
            totalAssetsReceived, totalRedeemAmount, 0.01e18, "Total assets received should match total redeem amount"
        );
    }
}
