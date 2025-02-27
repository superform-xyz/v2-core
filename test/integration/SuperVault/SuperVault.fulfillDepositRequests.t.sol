// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// superform
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { AccountInstance } from "modulekit/ModuleKit.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperVaultFulfillDepositRequestsTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

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
        vm.expectRevert(ISuperVaultStrategy.MAX_ALLOCATION_RATE_EXCEEDED.selector);
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
        vm.expectRevert(ISuperVaultStrategy.MAX_ALLOCATION_RATE_EXCEEDED.selector);
        _fulfillDepositForUsers(requestingUsers, totalAmount, 0);
    }

    // Define a struct to hold test variables to avoid stack too deep errors
    struct DepositVerificationVars {
        uint256 depositAmount;
        uint256 totalAmount;
        uint256 allocationAmountVault1;
        uint256 allocationAmountVault2;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialStrategyAssetBalance;
        uint256 fluidVaultSharesIncrease;
        uint256 aaveVaultSharesIncrease;
        uint256 strategyAssetBalanceDecrease;
        uint256 fluidVaultAssetsValue;
        uint256 aaveVaultAssetsValue;
        uint256 totalAssetsAllocated;
        uint256 totalSharesMinted;
        uint256 totalAssetsFromShares;
    }
    function test_RequestDeposit_VerifyAmounts() public {
        DepositVerificationVars memory vars;
        vars.depositAmount = 1000e6;
        
        _requestDepositForAllUsers(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialStrategyAssetBalance = asset.balanceOf(address(strategy));
        
        vars.totalAmount = vars.depositAmount * RANDOM_ACCOUNT_COUNT;
        vars.allocationAmountVault1 = vars.totalAmount / 2;
        vars.allocationAmountVault2 = vars.totalAmount - vars.allocationAmountVault1;
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }

        _fulfillDepositForUsers(requestingUsers, vars.allocationAmountVault1, vars.allocationAmountVault2);

        vars.fluidVaultSharesIncrease = fluidVault.balanceOf(address(strategy)) - vars.initialFluidVaultBalance;
        vars.aaveVaultSharesIncrease = aaveVault.balanceOf(address(strategy)) - vars.initialAaveVaultBalance;
        vars.strategyAssetBalanceDecrease = vars.initialStrategyAssetBalance - asset.balanceOf(address(strategy));
        
        vars.fluidVaultAssetsValue = fluidVault.convertToAssets(vars.fluidVaultSharesIncrease);
        vars.aaveVaultAssetsValue = aaveVault.convertToAssets(vars.aaveVaultSharesIncrease);
        
        vars.totalAssetsAllocated = vars.fluidVaultAssetsValue + vars.aaveVaultAssetsValue;
        // rounding errors accounted for
        assertApproxEqRel(vars.totalAssetsAllocated, vars.totalAmount, 0.01e18); 
        assertApproxEqRel(vars.strategyAssetBalanceDecrease, vars.totalAmount, 0.01e18); 
        
        _verifySharesAndAssets(vars);
    }

    function test_ClaimDeposit_RevertBeforeFulfillment() public {
        uint256 depositAmount = 1000e6;
        
        _getTokens(address(asset), accInstances[0].account, depositAmount);
        _requestDepositForAccount(accInstances[0], depositAmount);
        
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), depositAmount);
        
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), 
            address(vault), 
            accInstances[0].account, 
            depositAmount, 
            false, 
            false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: claimHooksAddresses,
            hooksData: claimHooksData
        });

        UserOpData memory claimUserOpData = _getExecOps(accInstances[0], superExecutorOnEth, abi.encode(claimEntry));
        accInstances[0].expect4337Revert();
        executeOp(claimUserOpData);
        
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        _fulfillDepositForUsers(requestingUsers, depositAmount / 2, depositAmount / 2);
        
        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0);
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0);
        
        _claimDepositForAccount(accInstances[0], depositAmount);
        
        assertGt(vault.balanceOf(accInstances[0].account), 0);
    }

    function test_ClaimDeposit_AfterPriceIncrease() public {
        uint256 depositAmount = 1000e6;
        
        _getTokens(address(asset), accInstances[0].account, depositAmount);
        _requestDepositForAccount(accInstances[0], depositAmount);
        
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        _fulfillDepositForUsers(requestingUsers, depositAmount / 2, depositAmount / 2);
        
        uint256 initialSharePrice = vault.convertToAssets(1e18);
        
        // increase price of assets
        uint256 yieldAmount = 100e6;
        deal(address(asset), address(this), yieldAmount * 2);
        asset.approve(address(fluidVault), yieldAmount);
        asset.approve(address(aaveVault), yieldAmount);
        fluidVault.deposit(yieldAmount, address(this));
        aaveVault.deposit(yieldAmount, address(this));
        
        vm.warp(block.timestamp + 1 days);
        
        uint256 newSharePrice = vault.convertToAssets(1e18);
        assertGt(newSharePrice, initialSharePrice, "share price should increase after yield accrual");
        
        uint256 expectedShares = strategy.getSuperVaultState(accInstances[0].account, 1);
        uint256 expectedAssetValue = vault.convertToAssets(expectedShares);
        
        _claimDepositForAccount(accInstances[0], depositAmount);
        
        uint256 userShares = vault.balanceOf(accInstances[0].account);
        assertEq(userShares, expectedShares, "user should receive expected shares");
        
        uint256 userShareValue = vault.convertToAssets(userShares);
        assertEq(userShareValue, expectedAssetValue, "share value should match expected");
        assertGt(userShareValue, depositAmount, "share value should be greater than deposit due to yield");
    }

    function test_MultipleUsers_SameAllocation_EqualSharePrice() public {
        uint256 depositAmount = 1000e6;
        
        _requestDepositForAllUsers(depositAmount);
        
        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked { ++i; }
        }
        
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);
        
        uint256[] memory initialShareBalances = new uint256[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
            unchecked { ++i; }
        }
        
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            _claimDepositForAccount(accInstances[i], depositAmount);
            unchecked { ++i; }
        }
        
        uint256 firstUserShares = vault.balanceOf(accInstances[0].account) - initialShareBalances[0];
        uint256 sharesPerAsset = firstUserShares * 1e18 / depositAmount;
        
        for (uint256 i = 1; i < RANDOM_ACCOUNT_COUNT;) {
            uint256 userShares = vault.balanceOf(accInstances[i].account) - initialShareBalances[i];
            uint256 userSharesPerAsset = userShares * 1e18 / depositAmount;
            
            assertEq(userSharesPerAsset, sharesPerAsset);
            assertEq(userShares, firstUserShares);
            
            unchecked { ++i; }
        }
    }

    function test_SingleUser_MultipleDeposits_SameAllocation() public {
        uint256 firstDepositAmount = 1000e6;
        uint256 secondDepositAmount = 1000e6;
        
        _getTokens(address(asset), accInstances[0].account, firstDepositAmount + secondDepositAmount);
        _requestDepositForAccount(accInstances[0], firstDepositAmount);
        
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        _fulfillDepositForUsers(requestingUsers, firstDepositAmount / 2, firstDepositAmount / 2);
        
        uint256 initialShareBalance = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], firstDepositAmount);
        uint256 firstDepositShares = vault.balanceOf(accInstances[0].account) - initialShareBalance;
        uint256 firstDepositSharePrice = firstDepositShares * 1e18 / firstDepositAmount;
        
        _requestDepositForAccount(accInstances[0], secondDepositAmount);
        _fulfillDepositForUsers(requestingUsers, secondDepositAmount / 2, secondDepositAmount / 2);
        
        uint256 shareBalanceAfterFirstDeposit = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], secondDepositAmount);
        uint256 secondDepositShares = vault.balanceOf(accInstances[0].account) - shareBalanceAfterFirstDeposit;
        uint256 secondDepositSharePrice = secondDepositShares * 1e18 / secondDepositAmount;
        
        uint256 totalShares = vault.balanceOf(accInstances[0].account) - initialShareBalance;
        assertEq(totalShares, firstDepositShares + secondDepositShares);
        
        uint256 totalShareValue = vault.convertToAssets(totalShares);
        assertApproxEqRel(totalShareValue, firstDepositAmount + secondDepositAmount, 0.01e18); // 1% tolerance
        
        console2.log("First deposit share price:", firstDepositSharePrice);
        console2.log("Second deposit share price:", secondDepositSharePrice);
        console2.log("Difference percentage:", (firstDepositSharePrice > secondDepositSharePrice) 
            ? ((firstDepositSharePrice - secondDepositSharePrice) * 100 / firstDepositSharePrice)
            : ((secondDepositSharePrice - firstDepositSharePrice) * 100 / firstDepositSharePrice));
    }

    struct ChangingAllocationVars {
        uint256 firstDepositAmount;
        uint256 secondDepositAmount;
        uint256 firstAllocationVault1;
        uint256 firstAllocationVault2;
        uint256 secondAllocationVault1;
        uint256 secondAllocationVault2;
        uint256 initialShareBalance;
        uint256 firstDepositShares;
        uint256 firstDepositSharePrice;
        uint256 shareBalanceAfterFirstDeposit;
        uint256 secondDepositShares;
        uint256 secondDepositSharePrice;
        uint256 totalShares;
        uint256 totalShareValue;
    }
    function test_SingleUser_ChangingAllocation() public {
        ChangingAllocationVars memory vars;
        vars.firstDepositAmount = 1000e6;
        vars.secondDepositAmount = 1000e6;
        
        _getTokens(address(asset), accInstances[0].account, vars.firstDepositAmount + vars.secondDepositAmount);
        _requestDepositForAccount(accInstances[0], vars.firstDepositAmount);
        
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        vars.firstAllocationVault1 = vars.firstDepositAmount / 2;
        vars.firstAllocationVault2 = vars.firstDepositAmount - vars.firstAllocationVault1;
        _fulfillDepositForUsers(requestingUsers, vars.firstAllocationVault1, vars.firstAllocationVault2);
        
        vars.initialShareBalance = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], vars.firstDepositAmount);
        vars.firstDepositShares = vault.balanceOf(accInstances[0].account) - vars.initialShareBalance;
        vars.firstDepositSharePrice = vars.firstDepositShares * 1e18 / vars.firstDepositAmount;
        
        vm.startPrank(MANAGER);
        strategy.updateGlobalConfig(
            ISuperVaultStrategy.GlobalConfig({
                  vaultCap: VAULT_CAP,
                superVaultCap: SUPER_VAULT_CAP,
                maxAllocationRate: 9000,
                vaultThreshold: VAULT_THRESHOLD
            })
        );
        vm.stopPrank();
        
        _requestDepositForAccount(accInstances[0], vars.secondDepositAmount);
        
        vars.secondAllocationVault1 = vars.secondDepositAmount * 90 / 100;
        vars.secondAllocationVault2 = vars.secondDepositAmount - vars.secondAllocationVault1;
        _fulfillDepositForUsers(requestingUsers, vars.secondAllocationVault1, vars.secondAllocationVault2);
        
        vars.shareBalanceAfterFirstDeposit = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], vars.secondDepositAmount);
        vars.secondDepositShares = vault.balanceOf(accInstances[0].account) - vars.shareBalanceAfterFirstDeposit;
        vars.secondDepositSharePrice = vars.secondDepositShares * 1e18 / vars.secondDepositAmount;
        
        _verifyAndLogChangingAllocation(vars);
    }
 
    function test_SingleUser_HighAllocation_RevertWithoutConfigUpdate() public {
        uint256 depositAmount = 1000e6;
        
        _getTokens(address(asset), accInstances[0].account, depositAmount);
        _requestDepositForAccount(accInstances[0], depositAmount);
        
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        
        uint256 highAllocationAmount = depositAmount * 90 / 100;
        uint256 lowAllocationAmount = depositAmount - highAllocationAmount;
        
        vm.expectRevert(ISuperVaultStrategy.MAX_ALLOCATION_RATE_EXCEEDED.selector);
        _fulfillDepositForUsers(requestingUsers, highAllocationAmount, lowAllocationAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _verifyAndLogChangingAllocation(ChangingAllocationVars memory vars) internal view {
        vars.totalShares = vault.balanceOf(accInstances[0].account) - vars.initialShareBalance;
        assertEq(vars.totalShares, vars.firstDepositShares + vars.secondDepositShares);
        
        vars.totalShareValue = vault.convertToAssets(vars.totalShares);
        assertApproxEqRel(vars.totalShareValue, vars.firstDepositAmount + vars.secondDepositAmount, 0.01e18); // 1% tolerance
        
        console2.log("first deposit - vault1 allocation:", vars.firstAllocationVault1 * 100 / vars.firstDepositAmount, "%");
        console2.log("first deposit - vault2 allocation:", vars.firstAllocationVault2 * 100 / vars.firstDepositAmount, "%");
        console2.log("first deposit share price:", vars.firstDepositSharePrice);
        
        console2.log("second deposit - vault1 allocation:", vars.secondAllocationVault1 * 100 / vars.secondDepositAmount, "%");
        console2.log("second deposit - vault2 allocation:", vars.secondAllocationVault2 * 100 / vars.secondDepositAmount, "%");
        console2.log("second deposit share price:", vars.secondDepositSharePrice);
        
        console2.log("share price difference percentage:", (vars.firstDepositSharePrice > vars.secondDepositSharePrice) 
            ? ((vars.firstDepositSharePrice - vars.secondDepositSharePrice) * 100 / vars.firstDepositSharePrice)
            : ((vars.secondDepositSharePrice - vars.firstDepositSharePrice) * 100 / vars.firstDepositSharePrice));
    }

     function _verifySharesAndAssets(DepositVerificationVars memory vars) internal {
        uint256[] memory initialUserShareBalances = new uint256[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            initialUserShareBalances[i] = vault.balanceOf(accInstances[i].account);
            _claimDepositForAccount(accInstances[i], vars.depositAmount);
            unchecked { ++i; }
        }
        
        vars.totalSharesMinted = 0;
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            uint256 userSharesReceived = vault.balanceOf(accInstances[i].account) - initialUserShareBalances[i];
            vars.totalSharesMinted += userSharesReceived;
            
            // Verify user can convert shares back to approximately the original deposit amount
            uint256 assetsFromShares = vault.convertToAssets(userSharesReceived);
            assertApproxEqRel(assetsFromShares, vars.depositAmount, 0.01e18); // Allow 1% deviation
            
            unchecked { ++i; }
        }
        
        vars.totalAssetsFromShares = vault.convertToAssets(vars.totalSharesMinted);
        assertApproxEqRel(vars.totalAssetsFromShares, vars.totalAmount, 0.01e18); // Allow 1% deviation
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