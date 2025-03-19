// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

//external
import "forge-std/console2.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

contract SuperVaultMatchRequestsTest is BaseSuperVaultTest {
    function test_MatchRequests_SinglePair(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        // Initial deposit to setup vault
        _completeDepositFlow(amount);

        // Setup depositor
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), amount, "Deposit request not created");

        // Setup redeemer - note that redeemer already has shares from initial deposit
        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);
        assertEq(strategy.pendingRedeemRequest(accInstances[1].account), redeemShares, "Redeem request not created");

        // Match requests
        address[] memory redeemUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        address[] memory depositUsers = new address[](1);
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function _sendFundsToStrategy(uint256 amount) internal {
        _getTokens(address(asset), address(this), amount);
        IERC20(address(asset)).transfer(address(strategy), amount);
    }

    function _sendFundsToSuperVault(uint256 amount) internal {
        _getTokens(address(asset), address(this), amount);
        IERC20(address(asset)).transfer(address(vault), amount);
    }

    function test_MatchRequests_MultiplePairs(uint256 amount) public {
        amount = bound(amount, 100e6, 200e6);
        uint256 nDepositors = 10;

        /// @dev 1 more redeemer than depositors to test partial matching and guarantee matching
        uint256 nRedeemers = 11;
        // Initial setup with much larger funds to handle all redemptions
        console2.log("\n=== Initializing with funds ===");
        _sendFundsToStrategy(amount * 100);
        _sendFundsToSuperVault(amount * 100);

        console2.log("Initial price per share:", _getSuperVaultPricePerShare());

        // Setup depositors with deposit requests
        console2.log("\n=== Setting up depositors ===");
        address[] memory redeemUsers = new address[](nRedeemers);
        address[] memory depositUsers = new address[](nDepositors);
        uint256 pendingDeposit;

        // First set up all depositor requests
        for (uint256 i = 0; i < nDepositors; i++) {
            console2.log("\n--- Setting up depositor", i, "---");
            _getTokens(address(asset), accInstances[i].account, amount);
            _requestDepositForAccount(accInstances[i], amount);
            depositUsers[i] = accInstances[i].account;

            pendingDeposit = strategy.pendingDepositRequest(accInstances[i].account);
            console2.log("Pending deposit amount:", pendingDeposit);
            assertEq(pendingDeposit, amount, "Deposit request not created");
        }

        // Process all redeemers first, then do all redemption requests together
        console2.log("\n=== Setting up and processing redeemers ===");
        for (uint256 i = 0; i < nRedeemers; i++) {
            uint256 redeemIndex = i + nDepositors;
            console2.log("\n--- Processing redeemer's deposit", redeemIndex, "---");

            // Complete deposit flow for each redeemer
            _getTokens(address(asset), accInstances[redeemIndex].account, amount);
            _requestDepositForAccount(accInstances[redeemIndex], amount);

            _fulfillDeposit(amount, accInstances[redeemIndex].account, address(fluidVault), address(aaveVault));

            _claimDepositForAccount(accInstances[redeemIndex], amount);
            redeemUsers[i] = accInstances[redeemIndex].account;
        }

        // Now do all redemption requests with same price
        for (uint256 i = 0; i < nRedeemers; i++) {
            console2.log("\n--- Processing redeemer's redeem", i, "---");

            _requestRedeemForAccount(
                accInstances[i + nDepositors], vault.balanceOf(accInstances[i + nDepositors].account)
            );
        }

        // Match the requests
        console2.log("\n=== Strategy State Before Matching ===");
        console2.log("Strategy USDC balance:", IERC20(address(asset)).balanceOf(address(strategy)));

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        // Verify all matches
        for (uint256 i = 0; i < nDepositors; i++) {
            console2.log("\n--- Verifying pair", i, "---");

            // Verify depositor state
            uint256 depositState = strategy.getSuperVaultState(depositUsers[i], 1);
            console2.log("Depositor shares to mint:", depositState);
            assertEq(strategy.pendingDepositRequest(depositUsers[i]), 0, "Deposit request not matched");
            assertGt(depositState, 0, "No shares to mint for depositor");

            // Verify redeemer state
            uint256 redeemState = strategy.getSuperVaultState(redeemUsers[i], 2);
            console2.log("Redeemer assets to withdraw:", redeemState);
            assertGt(redeemState, 0, "No assets to withdraw for redeemer");

            // Add additional verification
            uint256 pendingRedeem = strategy.pendingRedeemRequest(redeemUsers[i]);
            assertEq(pendingRedeem, 0, "Redeem request not matched");
        }
        assertGt(strategy.pendingRedeemRequest(redeemUsers[nRedeemers - 1]), 0, "Last redeemer has pending redeem");
    }

    function test_RevertWhen_MatchRequests_EmptyArrays() public {
        address[] memory emptyArray = new address[](0);

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.ZERO_LENGTH.selector);
        strategy.matchRequests(emptyArray, emptyArray);
        vm.stopPrank();
    }

    function test_RevertWhen_MatchRequests_NoValidRequests(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[0].account;
        depositUsers[0] = accInstances[1].account;

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.REQUEST_NOT_FOUND.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_RevertWhen_MatchRequests_NotStrategist(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);

        vm.startPrank(accInstances[0].account);
        vm.expectRevert(ISuperVaultStrategy.ACCESS_DENIED.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_MatchRequests_PartialMatch(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount * 2);
        _requestDepositForAccount(accInstances[0], amount * 2);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account) / 2;
        _requestRedeemForAccount(accInstances[1], redeemShares);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.INCOMPLETE_DEPOSIT_MATCH.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_MatchRequests_WithPriceChange(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

        uint256 pricePerShareBefore = vault.convertToAssets(1e18);
        console2.log("Price per share before:", pricePerShareBefore);

        uint256 yieldAmount = amount / 2;
        _getTokens(address(asset), address(this), yieldAmount);

        asset.approve(address(fluidVault), yieldAmount / 2);
        asset.approve(address(aaveVault), yieldAmount / 2);
        fluidVault.deposit(yieldAmount / 2, address(strategy));
        aaveVault.deposit(yieldAmount / 2, address(strategy));

        vm.warp(block.timestamp + 1 weeks);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        uint256 pricePerShareAfter = vault.convertToAssets(1e18);
        console2.log("Price per share after:", pricePerShareAfter);

        assertGt(pricePerShareAfter, pricePerShareBefore, "Price should have increased");

        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
        assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
    }

    function test_MatchRequests_MultipleRounds(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        uint256 claimableAssets = strategy.getSuperVaultState(accInstances[1].account, 2);
        vm.startPrank(accInstances[1].account);
        vault.withdraw(claimableAssets, accInstances[1].account, accInstances[1].account);
        vm.stopPrank();

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        uint256 remainingShares = vault.balanceOf(accInstances[1].account);
        console2.log("Remaining shares for second redeem:", remainingShares);

        if (remainingShares > 0) {
            _requestRedeemForAccount(accInstances[1], remainingShares);

            vm.startPrank(STRATEGIST);
            strategy.matchRequests(redeemUsers, depositUsers);
            vm.stopPrank();

            assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
            assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
            assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
        }
    }

    function test_MatchRequests_DuplicateUsers() public {
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

        address[] memory redeemUsers = new address[](2);
        address[] memory depositUsers = new address[](2);
        redeemUsers[0] = accInstances[1].account;
        redeemUsers[1] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;
        depositUsers[1] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.REQUEST_NOT_FOUND.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_MatchRequests_ZeroAddresses() public {
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = address(0);
        depositUsers[0] = address(0);

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.REQUEST_NOT_FOUND.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_MatchRequests_AfterEmergencyWithdraw() public {
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        _requestRedeemForAccount(accInstances[1], vault.balanceOf(accInstances[1].account));

        vm.startPrank(EMERGENCY_ADMIN);
        strategy.manageEmergencyWithdraw(1, address(0), 0);
        vm.warp(block.timestamp + 7 days);
        strategy.manageEmergencyWithdraw(2, address(0), 0);
        vm.stopPrank();

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
        assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
    }

    function _completeDepositFlow(uint256 amount, AccountInstance memory acc) internal {
        _getTokens(address(asset), acc.account, amount);

        uint256 balanceBefore = IERC20(address(asset)).balanceOf(acc.account);
        uint256 sharesBefore = vault.balanceOf(acc.account);
        console2.log("\n=== Starting complete deposit flow ===");
        console2.log("Amount:", amount);
        console2.log("Account:", acc.account);
        console2.log("Balance before:", balanceBefore);
        console2.log("Shares before:", sharesBefore);
        console2.log("Current price per share:", vault.convertToAssets(1e18));

        console2.log("\n--- Requesting deposit ---");
        _requestDepositForAccount(acc, amount);
        uint256 pendingDeposit = strategy.pendingDepositRequest(acc.account);
        console2.log("Pending deposit after request:", pendingDeposit);

        console2.log("\n--- Fulfilling deposit ---");
        vm.warp(block.timestamp + 1 days);
        uint256 strategyBalanceBefore = IERC20(address(asset)).balanceOf(address(strategy));
        console2.log("Strategy balance before fulfill:", strategyBalanceBefore);

        _fulfillDeposit(amount, acc.account, address(fluidVault), address(aaveVault));

        uint256 strategyBalanceAfter = IERC20(address(asset)).balanceOf(address(strategy));
        console2.log("Strategy balance after fulfill:", strategyBalanceAfter);
        uint256 balanceChange = strategyBalanceBefore > strategyBalanceAfter
            ? strategyBalanceBefore - strategyBalanceAfter
            : strategyBalanceAfter - strategyBalanceBefore;
        console2.log("Strategy balance change:", balanceChange);

        console2.log("\n--- Claiming deposit ---");
        vm.warp(block.timestamp + 1 days);

        uint256 sharesToMint = strategy.getSuperVaultState(acc.account, 1);
        console2.log("Shares to mint before claim:", sharesToMint);
        uint256 depositState = strategy.getSuperVaultState(acc.account, 3);
        console2.log("Deposit state before claim:", depositState);

        _claimDepositForAccount(acc, amount);

        uint256 sharesAfter = vault.balanceOf(acc.account);
        console2.log("\n=== Deposit flow complete ===");
        console2.log("Final shares:", sharesAfter);
        console2.log("Shares minted:", sharesAfter - sharesBefore);
    }
}
