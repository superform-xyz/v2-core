// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { SuperVaultFulfillRedeemRequestsTest } from "./SuperVault.fulfillRedeemRequests.t.sol";

import "forge-std/console.sol";

contract SuperVaultMatchRequestsTest is SuperVaultFulfillRedeemRequestsTest {
    function test_MatchRequests_SinglePair(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), amount, "Deposit request not created");

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);
        assertEq(strategy.pendingRedeemRequest(accInstances[1].account), redeemShares, "Redeem request not created");

        address[] memory redeemUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;

        address[] memory depositUsers = new address[](1);
        depositUsers[0] = accInstances[0].account;

        uint256 pendingRedeembefore = strategy.pendingRedeemRequest(accInstances[1].account);
        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0);
        assertGt(pendingRedeembefore, strategy.pendingRedeemRequest(accInstances[1].account));
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0);
        assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0);
    }

    function test_MatchRequests_MultiplePairs(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        // Setup multiple deposits and redeems
        _completeDepositFlow(amount);

        // Create 3 deposit requests
        for (uint256 i = 0; i < 3; i++) {
            _getTokens(address(asset), accInstances[i].account, amount);
            _requestDepositForAccount(accInstances[i], amount);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), amount, "Deposit request not created");
        }

        // Create 3 redeem requests
        for (uint256 i = 3; i < 6; i++) {
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemShares, "Redeem request not created");
        }

        // Setup arrays for matching
        address[] memory redeemUsers = new address[](3);
        address[] memory depositUsers = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            redeemUsers[i] = accInstances[i + 3].account;
            depositUsers[i] = accInstances[i].account;
        }

        // Match requests
        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        // Verify all deposits were matched
        for (uint256 i = 0; i < 3; i++) {
            assertEq(strategy.pendingDepositRequest(depositUsers[i]), 0, "Deposit request not cleared");
            assertGt(strategy.getSuperVaultState(depositUsers[i], 1), 0, "No shares available to mint");
        }

        // Verify all redeems were matched
        for (uint256 i = 0; i < 3; i++) {
            assertGt(strategy.getSuperVaultState(redeemUsers[i], 2), 0, "No assets available to withdraw");
        }
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

        // Setup initial state
        _completeDepositFlow(amount);

        // Create deposit request with larger amount
        _getTokens(address(asset), accInstances[0].account, amount * 2);
        _requestDepositForAccount(accInstances[0], amount * 2);

        // Create redeem request with smaller amount
        uint256 redeemShares = vault.balanceOf(accInstances[1].account) / 2;
        _requestRedeemForAccount(accInstances[1], redeemShares);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        // Should revert because deposit cannot be fully matched
        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.INCOMPLETE_DEPOSIT_MATCH.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_MatchRequests_WithPriceChange(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        // Setup initial state
        _completeDepositFlow(amount);

        // Create deposit and redeem requests
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

        // Get initial price
        uint256 pricePerShareBefore = vault.convertToAssets(1e18);
        console.log("Price per share before:", pricePerShareBefore);

        // Simulate yield by depositing and withdrawing from underlying vaults
        uint256 yieldAmount = amount / 2;
        _getTokens(address(asset), address(this), yieldAmount);

        // Simulate yield increase by warping
        vm.warp(block.timestamp + 1 weeks);

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        uint256 pricePerShareAfter = vault.convertToAssets(1e18);
        console.log("Price per share after:", pricePerShareAfter);

        assertGt(pricePerShareAfter, pricePerShareBefore, "Price should have increased");

        // Verify matching still worked
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
        assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
    }

    function test_MatchRequests_MultipleRounds(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        // First round
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

        // Claim first round results
        uint256 claimableAssets = strategy.getSuperVaultState(accInstances[1].account, 2);
        vm.startPrank(accInstances[1].account);
        vault.withdraw(claimableAssets, accInstances[1].account, accInstances[1].account);
        vm.stopPrank();

        // Second round with same users
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        // Check remaining shares and request a valid amount
        uint256 remainingShares = vault.balanceOf(accInstances[1].account);
        console.log("Remaining shares for second redeem:", remainingShares);

        if (remainingShares > 0) {
            _requestRedeemForAccount(accInstances[1], remainingShares);

            vm.startPrank(STRATEGIST);
            strategy.matchRequests(redeemUsers, depositUsers);
            vm.stopPrank();

            // Verify second round worked
            assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
            assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
            assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
        }
    }
}
