// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { SuperVaultFulfillRedeemRequestsTest } from "./SuperVault.fulfillRedeemRequests.t.sol";

//external
import "forge-std/console.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";

contract SuperVaultMatchRequestsTest is SuperVaultFulfillRedeemRequestsTest {
    function test_MatchRequests_SinglePair(uint256 amount) public {
        amount = bound(amount, 100e6, 10000e6);

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
        amount = bound(amount, 10e3, 1000e3); 

        // Give initial shares to redeeming accounts through proper flow
        for (uint256 i = 40; i < 70; i++) {  // 30 redeem accounts
            _completeDepositFlow(amount, accInstances[i]);
            _claimDepositForAccount(accInstances[i], amount);
            
            // Verify shares were received
            uint256 shares = vault.balanceOf(accInstances[i].account);
            console.log("Account", i, "initial shares:", shares);
            require(shares > 0, "Initial deposit failed");
        }

        // Create 40 deposit requests
        for (uint256 i = 0; i < 40; i++) {
            _getTokens(address(asset), accInstances[i].account, amount);
            _requestDepositForAccount(accInstances[i], amount);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), amount, "Deposit request not created");
        }

        // Create 30 redeem requests
        for (uint256 i = 40; i < 70; i++) {
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            console.log("Account", i, "shares before redeem:", redeemShares);
            require(redeemShares > 0, "No shares available for redeem");
            
            _requestRedeemForAccount(accInstances[i], redeemShares);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemShares, "Redeem request not created");
        }

        // Match all requests at once
        address[] memory redeemUsers = new address[](30);
        address[] memory depositUsers = new address[](30);

        for (uint256 i = 0; i < 30; i++) {
            redeemUsers[i] = accInstances[i + 40].account;
            depositUsers[i] = accInstances[i].account;
        }

        // Match requests
        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        // Verify all matches
        for (uint256 i = 0; i < 30; i++) {
            assertEq(strategy.pendingDepositRequest(depositUsers[i]), 0, "Deposit request not cleared");
            assertGt(strategy.getSuperVaultState(depositUsers[i], 1), 0, "No shares to mint");
            
            uint256 assetsToWithdraw = strategy.getSuperVaultState(redeemUsers[i], 2);
            console.log("Assets to withdraw for user", i, ":", assetsToWithdraw);
            assertGt(assetsToWithdraw, 0, "No assets available to withdraw");
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

        // Deposit into underlying vaults to simulate yield
        asset.approve(address(fluidVault), yieldAmount / 2);
        asset.approve(address(aaveVault), yieldAmount / 2);
        fluidVault.deposit(yieldAmount / 2, address(strategy));
        aaveVault.deposit(yieldAmount / 2, address(strategy));

        // Simulate pps increase by warping
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

    function test_MatchRequests_DuplicateUsers() public {
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        // Create deposit request
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);

        // Create two redeem requests
        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares / 2);
        _requestRedeemForAccount(accInstances[1], redeemShares / 2); // Second request from same user

        address[] memory redeemUsers = new address[](2);
        address[] memory depositUsers = new address[](2);
        redeemUsers[0] = accInstances[1].account;
        redeemUsers[1] = accInstances[1].account; // Duplicate user
        depositUsers[0] = accInstances[0].account;
        depositUsers[1] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.REQUEST_NOT_FOUND.selector); // Second request should not exist
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

        // Setup requests
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        _requestRedeemForAccount(accInstances[1], vault.balanceOf(accInstances[1].account));

        // Trigger emergency withdrawal
        vm.startPrank(EMERGENCY_ADMIN);
        strategy.manageEmergencyWithdraw(1, address(0), 0); // Propose emergency withdrawal
        vm.warp(block.timestamp + 7 days);
        strategy.manageEmergencyWithdraw(2, address(0), 0); // Execute emergency withdrawal
        vm.stopPrank();

        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;

        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        // Verify matching still works in emergency state
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0, "Deposit not matched");
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0, "No shares to mint");
        assertGt(strategy.getSuperVaultState(accInstances[1].account, 2), 0, "No assets to withdraw");
    }

    function test_RevertWhen_MatchRequests_UnequalArrayLengths() public {
        // Setup initial state with valid requests
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        // Create two deposit requests
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        _getTokens(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        // Create one redeem request with matching total amount
        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

        // Create arrays with different lengths (but non-zero)
        address[] memory redeemUsers = new address[](1);
        address[] memory depositUsers = new address[](2);
        redeemUsers[0] = accInstances[1].account;
        depositUsers[0] = accInstances[0].account;
        depositUsers[1] = accInstances[2].account;

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.LENGTH_MISMATCH.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }

    function test_RevertWhen_MatchRequests_UnequalRequests(uint256 amount) public {
        amount = bound(amount, 100e6, 10_000e6);

        // Setup initial state
        _completeDepositFlow(amount);

        // Create 10 deposit requests
        for (uint256 i = 0; i < 10; i++) {
            _getTokens(address(asset), accInstances[i].account, amount);
            _requestDepositForAccount(accInstances[i], amount);
        }

        // Create 8 redeem requests
        for (uint256 i = 10; i < 18; i++) {
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
        }

        // Try to match 10 deposits with 8 redeems (should fail)
        address[] memory redeemUsers = new address[](8);
        address[] memory depositUsers = new address[](10);

        for (uint256 i = 0; i < 8; i++) {
            redeemUsers[i] = accInstances[i + 10].account;
        }
        for (uint256 i = 0; i < 10; i++) {
            depositUsers[i] = accInstances[i].account;
        }

        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.LENGTH_MISMATCH.selector);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();
    }
}
