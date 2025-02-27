// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { SuperVaultFulfillRedeemRequestsTest } from "./SuperVault.fulfillRedeemRequests.t.sol";

//external
import "forge-std/console2.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        amount = bound(amount, 100e6, 500e6);

        console2.log("\n=== Setting up redeemers ===");
        for (uint256 i = 40; i < 70; i++) {
            console2.log("\nProcessing redeemer", i);

            uint256 pricePerShareBefore = vault.convertToAssets(1e18);
            console2.log("Price per share before deposit:", pricePerShareBefore);

            _getTokens(address(asset), accInstances[i].account, amount);

            uint256 sharesBefore = vault.balanceOf(accInstances[i].account);
            console2.log("Account", i, "shares before deposit:", sharesBefore);

            // Request deposit
            _requestDepositForAccount(accInstances[i], amount);
            uint256 pendingRequest = strategy.pendingDepositRequest(accInstances[i].account);
            console2.log("Deposit requested");
            console2.log("Pending request amount:", pendingRequest);

            // Wait for deposit to be claimable
            vm.warp(block.timestamp + 1 days);

            // Fulfill deposit request
            __fulfillDepositRequest(accInstances[i], amount);
            console2.log("Deposit fulfilled");

            // Wait for claim delay and check state
            vm.warp(block.timestamp + 1 hours);
            uint256 claimableShares = strategy.getSuperVaultState(accInstances[i].account, 1);
            require(claimableShares > 0, "No shares to claim");

            // Claim deposit
            _claimDepositForAccount(accInstances[i], amount);
            console2.log("Deposit claimed");

            uint256 sharesAfter = vault.balanceOf(accInstances[i].account);
            console2.log("Account", i, "shares after deposit:", sharesAfter);

            uint256 pricePerShareAfter = vault.convertToAssets(1e18);
            console2.log("Price per share after deposit:", pricePerShareAfter);
            
            // Only calculate difference if after > before to avoid underflow
            if (pricePerShareAfter >= pricePerShareBefore) {
                console2.log("Price per share increase:", pricePerShareAfter - pricePerShareBefore);
            } else {
                console2.log("Price per share decrease:", pricePerShareBefore - pricePerShareAfter);
            }

            // Request redeem
            _requestRedeemForAccount(accInstances[i], sharesAfter);
        }

        console2.log("\n=== Creating deposit requests ===");
        // Create 40 deposit requests
        for (uint256 i = 0; i < 40; i++) {
            console2.log("\nProcessing depositor", i);
            _getTokens(address(asset), accInstances[i].account, amount);

            uint256 balanceBefore = IERC20(address(asset)).balanceOf(accInstances[i].account);
            console2.log("Account", i, "balance before request:", balanceBefore);
            require(balanceBefore >= amount, "Insufficient balance for deposit request");

            _requestDepositForAccount(accInstances[i], amount);
            uint256 pendingRequest = strategy.pendingDepositRequest(accInstances[i].account);
            console2.log("Account", i, "pending deposit request:", pendingRequest);
            assertEq(pendingRequest, amount, "Deposit request not created");
        }

        console2.log("\n=== Creating redeem requests ===");
        // Create redeem requests
        for (uint256 i = 40; i < 70; i++) {
            console2.log("\nProcessing redeemer", i);
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            console2.log("Account", i, "shares available:", redeemShares);

            // Add balance check for strategy
            uint256 strategyBalance = IERC20(address(asset)).balanceOf(address(strategy));
            console2.log("Strategy balance before redeem request:", strategyBalance);

            // Add total supply check
            uint256 totalSupply = vault.totalSupply();
            console2.log("Vault total supply:", totalSupply);

            // Add price per share check
            uint256 pricePerShare = vault.convertToAssets(1e18);
            console2.log("Current price per share:", pricePerShare);

            require(redeemShares > 0, "No shares available for redeem");

            _requestRedeemForAccount(accInstances[i], redeemShares);
            uint256 pendingRedeem = strategy.pendingRedeemRequest(accInstances[i].account);
            console2.log("Account", i, "pending redeem request:", pendingRedeem);
            console2.log("Redeem shares requested vs pending:", redeemShares, "vs", pendingRedeem);
            assertEq(pendingRedeem, redeemShares, "Redeem request not created");
        }

        console2.log("\n=== Setting up match arrays ===");
        // Set up arrays for matching
        address[] memory redeemUsers = new address[](30);
        address[] memory depositUsers = new address[](30);

        for (uint256 i = 0; i < 30; i++) {
            redeemUsers[i] = accInstances[i + 40].account;
            depositUsers[i] = accInstances[i].account;
            console2.log("Pair", i);
            console2.log("- Depositor:", depositUsers[i]);
            console2.log("- Redeemer:", redeemUsers[i]);
        }

        console2.log("\n=== Executing match ===");
        // Add pre-match state checks
        uint256 totalStrategyBalance = IERC20(address(asset)).balanceOf(address(strategy));
        uint256 fluidVaultShares = fluidVault.balanceOf(address(strategy));
        uint256 aaveVaultShares = aaveVault.balanceOf(address(strategy));

        console2.log("Strategy:", totalStrategyBalance);
        console2.log("FluidShares:", fluidVaultShares);
        console2.log("AaveShares:", aaveVaultShares);

        // Convert shares to assets
        uint256 fluidAssets = fluidVault.convertToAssets(fluidVaultShares);
        uint256 aaveAssets = aaveVault.convertToAssets(aaveVaultShares);
        console2.log("FluidAssets:", fluidAssets, "AaveAssets:", aaveAssets);

        // First pair details
        address firstDepositor = depositUsers[0];
        address firstRedeemer = redeemUsers[0];
        console2.log("First pair - Deposit:", strategy.pendingDepositRequest(firstDepositor));
        console2.log("First pair - Redeem:", strategy.pendingRedeemRequest(firstRedeemer));

        try strategy.matchRequests(redeemUsers, depositUsers) {
            console2.log("Match succeeded");
        } catch Error(string memory reason) {
            console2.log("Match failed:", reason);
        } catch (bytes memory) {
            console2.log("Match failed with no reason");
        }

        for (uint256 i = 0; i < 30; i++) {
            assertEq(strategy.pendingDepositRequest(depositUsers[i]), 0, "Deposit request not cleared");
            assertGt(strategy.getSuperVaultState(depositUsers[i], 1), 0, "No shares to mint");

            assertGt(strategy.getSuperVaultState(redeemUsers[i], 2), 0, "No assets to withdraw");
        }

        for (uint256 i = 30; i < 40; i++) {
            assertEq(
                strategy.pendingDepositRequest(accInstances[i].account),
                amount,
                "Unmatched deposit request should remain pending"
            );
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
        _requestRedeemForAccount(accInstances[1], redeemShares / 2);
        _requestRedeemForAccount(accInstances[1], redeemShares / 2);

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

    function test_RevertWhen_MatchRequests_UnequalArrayLengths() public {
        uint256 amount = 1000e6;
        _completeDepositFlow(amount);

        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        _getTokens(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        _requestRedeemForAccount(accInstances[1], redeemShares);

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

        _completeDepositFlow(amount);

        for (uint256 i = 0; i < 10; i++) {
            _getTokens(address(asset), accInstances[i].account, amount);
            _requestDepositForAccount(accInstances[i], amount);
        }

        for (uint256 i = 10; i < 18; i++) {
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
        }

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

    function _completeDepositFlow(uint256 amount, AccountInstance memory acc) internal override {
        _getTokens(address(asset), acc.account, amount);

        uint256 balanceBefore = IERC20(address(asset)).balanceOf(acc.account);
        uint256 sharesBefore = vault.balanceOf(acc.account);
        console2.log("Starting complete deposit flow for amount:", amount);
        console2.log("Using account:", acc.account);
        console2.log("Balance before:", balanceBefore, "after:", IERC20(address(asset)).balanceOf(acc.account));

        _requestDepositForAccount(acc, amount);
        uint256 pendingRequest = strategy.pendingDepositRequest(acc.account);
        console2.log("Deposit requested");
        console2.log("Pending request amount:", pendingRequest);

        // Wait for deposit to be claimable
        vm.warp(block.timestamp + 1 days);

        // Fulfill deposit request
        __fulfillDepositRequest(acc, amount);
        console2.log("Deposit fulfilled");

        // Wait for claim delay and check state
        vm.warp(block.timestamp + 1 hours);
        uint256 claimableShares = strategy.getSuperVaultState(acc.account, 1);
        require(claimableShares > 0, "No shares to claim");

        // Claim deposit
        _claimDepositForAccount(acc, amount);
        console2.log("Deposit claimed");

        uint256 sharesAfter = vault.balanceOf(acc.account);
        console2.log("Shares minted:", sharesAfter - sharesBefore);
    }
}
