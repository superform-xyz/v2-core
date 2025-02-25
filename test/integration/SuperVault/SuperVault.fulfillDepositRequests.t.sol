// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
// external

// superform
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

import { AccountInstance } from "modulekit/ModuleKit.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

contract SuperVaultFulfillDepositRequestsTest is BaseSuperVaultTest {

    AccountInstance[] accInstances;
    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, RANDOM_ACCOUNT_COUNT);
    }

    function test_RequestDeposit_MultipleUsers(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);
    }

    function test_RequestDepositMultipleUsers_With_CompleteFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
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

        // check that all pending requests are cleared
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
            unchecked { ++i; }
        }
    }

    function test_RequestMultipleUsers_With_PartialUsersFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
      
        // create deposit requests for all users
       _requestDepositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 partialUsersCount = RANDOM_ACCOUNT_COUNT / 2;
        uint256 totalAmount = depositAmount * partialUsersCount;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](partialUsersCount);
        for (uint256 i; i < partialUsersCount;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }

        // fulfill deposits
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // check that all pending requests are cleared
        for (uint256 i; i < partialUsersCount;) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
            unchecked { ++i; }
        }
        
        // check that the remaining users have not been affected
        for (uint256 i = partialUsersCount; i < RANDOM_ACCOUNT_COUNT;) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
            assertEq(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
            unchecked { ++i; }
        }

        // try to fullfil the rest of the users in 1 vault
        uint256 j;
        for (uint256 i = partialUsersCount; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[j] = accInstances[i].account;
            unchecked { ++i; ++j; }
        }
        vm.expectRevert(ISuperVaultStrategy.LIMIT_EXCEEDED.selector);
        _fulfillDepositForUsers(requestingUsers, totalAmount, 0);

        // fullfill the rest of the users in 2 vaults
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
    }

    function test_RequestDeposit_SingleUser_MultipleRequests(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10000e6);
        
        // create multiple deposit requests for single user
        uint256 requestCount = 3;
        for (uint256 i; i < requestCount; i++) {
            _getTokens(address(asset), accInstances[0].account, depositAmount);
            _requestDepositForAccount(accInstances[0], depositAmount);
            assertEq(
                strategy.pendingDepositRequest(accInstances[0].account), 
                depositAmount * (i + 1)
            );
        }

        // fulfill deposits
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        uint256 totalAmount = depositAmount * requestCount;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
        
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0);
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0);
    }

    function test_RequestDeposit_MultipleUsers_DifferentAmounts() public {
        uint256[] memory amounts = new uint256[](RANDOM_ACCOUNT_COUNT);
        uint256 totalAmount;
        
        // Create deposit requests with different amounts for each user
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            amounts[i] = (i + 1) * 100e6; // Increasing amounts
            _getTokens(address(asset), accInstances[i].account, amounts[i]);
            _requestDepositForAccount(accInstances[i], amounts[i]);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), amounts[i]);
            totalAmount += amounts[i];
        }

        // Create fulfillment data
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // Verify all deposits were fulfilled
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }
    }

    function test_RequestDeposit_RevertOnInvalidAllocation() public {
        uint256 depositAmount = 1000e6;
        
        // Create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // Create fulfillment data with invalid allocation (total less than deposits)
        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 invalidAmount = totalAmount / 4; // Allocating less than total deposits
        
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        // Should revert when trying to fulfill with insufficient allocation
        vm.expectRevert(); 
        _fulfillDepositForUsers(requestingUsers, invalidAmount, invalidAmount);
    }

    function test_RequestDeposit_UnorderedFulfillment(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 100e6, 10000e6);
        
        // Create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // Create unordered array of users for fulfillment
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            // Reverse order of users
            requestingUsers[i] = accInstances[RANDOM_ACCOUNT_COUNT - 1 - i].account;
        }

        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        // Fulfill deposits with unordered user array
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // Verify all deposits were fulfilled correctly
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }
    }


    function test_RequestDeposit_MultipleUsers_SameTimestamp() public {
        uint256 depositAmount = 1000e6;
        
        // Create deposit requests for all users at the same timestamp
        uint256 timestamp = block.timestamp + 1 days;
        vm.warp(timestamp);
        
        _requestDepositForAllUsers(depositAmount);
        
        // Verify all requests were created with same timestamp
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
        }

        // Fulfill all requests
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
    }

    function test_RequestDeposit_MultipleUsers_DifferentTimestamps() public {
        uint256 depositAmount = 1000e6;
        
        // Create deposit requests at different timestamps
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            vm.warp(block.timestamp + 1 hours);
            _getTokens(address(asset), accInstances[i].account, depositAmount);
            _requestDepositForAccount(accInstances[i], depositAmount);
        }

        // Fulfill all requests
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
    }

    function test_RequestDeposit_FullAllocationInOneVault() public {
        uint256 depositAmount = 1000e6;
        
        // Create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // Try to fulfill all requests using only one vault
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        
        // Should revert when trying to allocate everything to one vault
        vm.expectRevert(ISuperVaultStrategy.LIMIT_EXCEEDED.selector);
        _fulfillDepositForUsers(requestingUsers, totalAmount, 0);
    }


    function _requestDepositForAllUsers(uint256 depositAmount) internal {
         for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            _getTokens(address(asset), accInstances[i].account, depositAmount);
            _requestDepositForAccount(accInstances[i], depositAmount);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
            unchecked { ++i; }
        }
    }

    function _fulfillDepositForUsers(address[] memory requestingUsers, uint256 allocationAmountVault1, uint256 allocationAmountVault2) internal {
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), allocationAmountVault1, false, false
        );
        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), allocationAmountVault2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();
    }
}