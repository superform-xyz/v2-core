// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultFulfillRedeemRequestsTest } from "./SuperVault.fulfillRedeemRequests.t.sol";

import "forge-std/console.sol";

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

    /**
    function test_MatchRequests_SinglePair_NoPreDeposits(uint256 amount) public {
        amount = bound(amount, 100e6, 10000e6);

        // Create redeem request from second user
        console.log("----A");
        _getTokens(address(asset), accInstances[1].account, amount);
        _requestDepositForAccount(accInstances[1], amount);
        console.log("----B");
        _fulfillDepositForAccount(accInstances[1], amount);
        console.log("----C");
        _claimDepositForAccount(accInstances[1], amount);
        console.log("----D");

        // Create deposit request from first user
        _getTokens(address(asset), accInstances[0].account, amount);
        _requestDepositForAccount(accInstances[0], amount);
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), amount, "Deposit request not created");



        uint256 redeemShares = vault.balanceOf(accInstances[1].account);
        console.log("------ amount", amount);
        console.log("------ redeemShares", redeemShares);
        revert("AAA");
        _requestRedeemForAccount(accInstances[1], redeemShares);
        assertEq(strategy.pendingRedeemRequest(accInstances[1].account), redeemShares, "Redeem request not created");

        // Match the requests
        address[] memory redeemUsers = new address[](1);
        redeemUsers[0] = accInstances[1].account;
        
        address[] memory depositUsers = new address[](1);
        depositUsers[0] = accInstances[0].account;

        uint256 pendingRedeemBefore = strategy.pendingRedeemRequest(accInstances[1].account);
        vm.startPrank(STRATEGIST);
        strategy.matchRequests(redeemUsers, depositUsers);
        vm.stopPrank();

        // Verify matching results
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0);
        assertGt(pendingRedeemBefore, strategy.pendingRedeemRequest(accInstances[1].account));
        assertGt(strategy.maxMint(accInstances[0].account), 0);
        assertGt(strategy.maxWithdraw(accInstances[1].account), 0);
    }
     */
}