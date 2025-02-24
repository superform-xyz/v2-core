// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultFulfillDepositRequestsTest } from "./SuperVault.fulfillDepositRequests.t.sol";

contract SuperVaultFulfillRedeemRequestsTest is SuperVaultFulfillDepositRequestsTest {

    function test_RequestRedeem_MultipleUsers(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // request redeem for all users
        _requestRedeemForAllUsers();
    }

    function test_RequestRedeemMultipleUsers_With_CompleteFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
        // perform deposit operations
        _completeDepositFlow(depositAmount);

        uint256 totalRedeemShares;
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            totalRedeemShares += vaultBalance;
            unchecked { ++i; }
        }

        // request redeem for all users
        _requestRedeemForAllUsers();

        // create fullfillment data
        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }

        // fulfill redeem
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // check that all pending requests are cleared
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.maxWithdraw(accInstances[i].account), 0);
            unchecked { ++i; }
        }
    }

    function test_RequestRedeem_MultipleUsers_DifferentAmounts() public {
        uint256 depositAmount = 1000e6;
        
        // first deposit same amount for all users
        _completeDepositFlow(depositAmount);

        uint256[] memory redeemAmounts = new uint256[](RANDOM_ACCOUNT_COUNT);
        uint256 totalRedeemShares;
        
        // create redeem requests with randomized amounts based on vault balance
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            // random amount between 50% and 100% of maxRedeemable
            redeemAmounts[i] = bound(
                uint256(keccak256(abi.encodePacked(block.timestamp, i))),
                vaultBalance / 2,
                vaultBalance
            );
            _requestRedeemForAccount(accInstances[i], redeemAmounts[i]);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            totalRedeemShares += redeemAmounts[i];
        }

        // fulfill all redeem requests
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // verify all redeems were fulfilled
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.maxWithdraw(accInstances[i].account), 0);
        }
    }

    function test_RequestRedeemMultipleUsers_With_PartialUsersFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // store redeem amounts for later verification
        uint256[] memory redeemAmounts = new uint256[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            redeemAmounts[i] = vault.balanceOf(accInstances[i].account);
            unchecked { ++i; }
        }

        // request redeem for all users
        _requestRedeemForAllUsers();

        // create fulfillment data for half the users
        uint256 partialUsersCount = RANDOM_ACCOUNT_COUNT / 2;
        uint256 totalRedeemShares;
        
        // calculate total redeem shares for partial users
        for (uint256 i; i < partialUsersCount;) {
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
            unchecked { ++i; }
        }

        address[] memory requestingUsers = new address[](partialUsersCount);
        for (uint256 i; i < partialUsersCount;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }

        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        // fulfill redeem for half the users
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // check that fulfilled requests are cleared
        for (uint256 i; i < partialUsersCount;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.maxWithdraw(accInstances[i].account), 0);
            unchecked { ++i; }
        }
        
        // check that remaining users still have pending requests
        for (uint256 i = partialUsersCount; i < RANDOM_ACCOUNT_COUNT;) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            assertEq(strategy.maxWithdraw(accInstances[i].account), 0);
            unchecked { ++i; }
        }

        // calculate total redeem shares for remaining users
        totalRedeemShares = 0;
        uint256 j;
        requestingUsers = new address[](RANDOM_ACCOUNT_COUNT - partialUsersCount);
        for (uint256 i = partialUsersCount; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[j] = accInstances[i].account;
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
            unchecked { ++i; ++j; }
        }

        allocationAmountVault1 = totalRedeemShares / 2;
        allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        // fulfill remaining users
        _fulfillRedeemForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
    }

    function test_RequestRedeem_RevertOnExceedingBalance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 100e6, 10000e6);
        
        // first deposit for single user
        _completeDepositFlow(depositAmount);

        // try to redeem more than balance
        uint256 vaultBalance = vault.balanceOf(accInstances[0].account);
        uint256 excessAmount = vaultBalance * 100;

        // should revert when trying to redeem more than balance
        _requestRedeemForAccount_Revert(accInstances[0], excessAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _fulfillRedeemForUsers(
        address[] memory requestingUsers, 
        uint256 redeemSharesVault1, 
        uint256 redeemSharesVault2
    ) internal {
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults
        fulfillHooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            redeemSharesVault1,
            false,
            false
        );
        fulfillHooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            redeemSharesVault2,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRedeemRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData);
        vm.stopPrank();
    }

    function _completeDepositFlow(uint256 depositAmount) internal {
        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }
        // fulfill deposits
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // claim deposits
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            _claimDepositForAccount(accInstances[i], depositAmount);
            unchecked { ++i; }
        }
    }

    function _requestRedeemForAllUsers() internal {
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            uint256 redeemShares = vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
            unchecked { ++i; }
        }
    }
}