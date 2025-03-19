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

import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperVaultFulfillDepositRequestsTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    function test_RequestDeposit_MultipleUsers(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);
    }

    function test_RequestDepositMultipleUsers_With_CompleteFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        // fulfill deposits
        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // check that all pending requests are cleared
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }
    }

    function test_RequestMultipleUsers_With_PartialUsersFullfilment(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 partialUsersCount = ACCOUNT_COUNT / 2;
        uint256 totalAmount = depositAmount * partialUsersCount;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](partialUsersCount);
        for (uint256 i; i < partialUsersCount; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        // fulfill deposits
        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // check that all pending requests are cleared
        for (uint256 i; i < partialUsersCount; ++i) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }

        // check that the remaining users have not been affected
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT; ++i) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
            assertEq(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }

        // try to fullfil the rest of the users in 1 vault
        uint256 j;
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT;) {
            requestingUsers[j] = accInstances[i].account;
            unchecked {
                ++i;
                ++j;
            }
        }

        // fullfill the rest of the users in 2 vaults
        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
    }

    function test_RequestDeposit_SingleUser_MultipleRequests(uint256 depositAmount) public {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // create multiple deposit requests for single user
        uint256 requestCount = 3;
        for (uint256 i; i < requestCount; i++) {
            _getTokens(address(asset), accInstances[0].account, depositAmount);
            _requestDepositForAccount(accInstances[0], depositAmount);
            assertEq(strategy.pendingDepositRequest(accInstances[0].account), depositAmount * (i + 1));
        }

        // fulfill deposits
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        uint256 totalAmount = depositAmount * requestCount;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        assertEq(strategy.pendingDepositRequest(accInstances[0].account), 0);
        assertGt(strategy.getSuperVaultState(accInstances[0].account, 1), 0);
    }

    function test_RequestDeposit_MultipleUsers_DifferentAmounts() public {
        uint256[] memory amounts = new uint256[](ACCOUNT_COUNT);
        uint256 totalAmount;

        // Create deposit requests with different amounts for each user
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            amounts[i] = (i + 1) * 100e6; // Increasing amounts
            _getTokens(address(asset), accInstances[i].account, amounts[i]);
            _requestDepositForAccount(accInstances[i], amounts[i]);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), amounts[i]);
            totalAmount += amounts[i];
        }

        // Create fulfillment data
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // Verify all deposits were fulfilled
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), 0);
            assertGt(strategy.getSuperVaultState(accInstances[i].account, 1), 0);
        }
    }

    function test_RequestDeposit_RevertOnInvalidAllocation() public {
        uint256 depositAmount = 1000e6;

        // Create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // Create fulfillment data with invalid allocation (total less than deposits)
        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 invalidAmount = totalAmount / 4; // Allocating less than total deposits

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        // Should revert when trying to fulfill with insufficient allocation
        _fulfillDepositForUsers(
            requestingUsers,
            invalidAmount,
            invalidAmount,
            address(fluidVault),
            address(aaveVault),
            ISuperVaultStrategy.INVALID_AMOUNT.selector
        );
    }

    function test_RequestDeposit_UnorderedFulfillment(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // Create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // Create unordered array of users for fulfillment
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            // Reverse order of users
            requestingUsers[i] = accInstances[ACCOUNT_COUNT - 1 - i].account;
        }

        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        // Fulfill deposits with unordered user array
        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // Verify all deposits were fulfilled correctly
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
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
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
        }

        // Fulfill all requests
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
    }

    function test_RequestDeposit_MultipleUsers_DifferentTimestamps() public {
        uint256 depositAmount = 1000e6;

        // Create deposit requests at different timestamps
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            vm.warp(block.timestamp + 1 hours);
            _getTokens(address(asset), accInstances[i].account, depositAmount);
            _requestDepositForAccount(accInstances[i], depositAmount);
        }

        // Fulfill all requests
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
    }

    function test_RequestDeposit_VerifyAmounts() public {
        DepositVerificationVars memory vars;
        vars.depositAmount = 1000e6;

        _requestDepositForAllUsers(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialStrategyAssetBalance = asset.balanceOf(address(strategy));

        vars.totalAmount = vars.depositAmount * ACCOUNT_COUNT;
        vars.allocationAmountVault1 = vars.totalAmount / 2;
        vars.allocationAmountVault2 = vars.totalAmount - vars.allocationAmountVault1;
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        _fulfillDepositForUsers(
            requestingUsers,
            vars.allocationAmountVault1,
            vars.allocationAmountVault2,
            address(fluidVault),
            address(aaveVault)
        );

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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });

        UserOpData memory claimUserOpData = _getExecOps(accInstances[0], superExecutorOnEth, abi.encode(claimEntry));
        accInstances[0].expect4337Revert();
        executeOp(claimUserOpData);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        _fulfillDepositForUsers(
            requestingUsers, depositAmount / 2, depositAmount / 2, address(fluidVault), address(aaveVault)
        );

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

        _fulfillDepositForUsers(
            requestingUsers, depositAmount / 2, depositAmount / 2, address(fluidVault), address(aaveVault)
        );

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
        console2.log("userShares                  ", userShares);
        console2.log("userShare in asset          ", userShareValue);
        console2.log("depositAmount               ", depositAmount);

        uint256 initialBootstrapperShares = vault.balanceOf(address(this));
        console2.log("boostrapper shares          ", initialBootstrapperShares);
        console2.log("bootstrapper shares in asset", initialBootstrapperShares);
        assertEq(userShareValue, expectedAssetValue, "share value should match expected");
        assertGt(userShareValue, depositAmount, "share value should be greater than deposit due to yield");
    }

    function test_MultipleUsers_SameAllocation_EqualSharePrice() public {
        uint256 depositAmount = 1000e6;

        _requestDepositForAllUsers(depositAmount);

        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        _fulfillDepositForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        uint256[] memory initialShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
        }

        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            _claimDepositForAccount(accInstances[i], depositAmount);
        }

        uint256 firstUserShares = vault.balanceOf(accInstances[0].account) - initialShareBalances[0];
        uint256 sharesPerAsset = firstUserShares * 1e18 / depositAmount;

        /// this test compares the shares of the first user
        for (uint256 i = 1; i < ACCOUNT_COUNT; ++i) {
            uint256 userShares = vault.balanceOf(accInstances[i].account) - initialShareBalances[i];
            uint256 userSharesPerAsset = userShares * 1e18 / depositAmount;
            assertEq(userSharesPerAsset, sharesPerAsset);
            assertEq(userShares, firstUserShares);
        }
    }

    function test_SingleUser_MultipleDeposits_SameAllocation() public {
        uint256 firstDepositAmount = 1000e6;
        uint256 secondDepositAmount = 1000e6;

        _getTokens(address(asset), accInstances[0].account, firstDepositAmount + secondDepositAmount);
        _requestDepositForAccount(accInstances[0], firstDepositAmount);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        _fulfillDepositForUsers(
            requestingUsers, firstDepositAmount / 2, firstDepositAmount / 2, address(fluidVault), address(aaveVault)
        );

        uint256 initialShareBalance = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], firstDepositAmount);
        uint256 firstDepositShares = vault.balanceOf(accInstances[0].account) - initialShareBalance;
        uint256 firstDepositSharePrice = firstDepositShares * 1e18 / firstDepositAmount;

        _requestDepositForAccount(accInstances[0], secondDepositAmount);
        _fulfillDepositForUsers(
            requestingUsers, secondDepositAmount / 2, secondDepositAmount / 2, address(fluidVault), address(aaveVault)
        );

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
        console2.log(
            "Difference percentage:",
            (firstDepositSharePrice > secondDepositSharePrice)
                ? ((firstDepositSharePrice - secondDepositSharePrice) * 100 / firstDepositSharePrice)
                : ((secondDepositSharePrice - firstDepositSharePrice) * 100 / firstDepositSharePrice)
        );
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
        _fulfillDepositForUsers(
            requestingUsers,
            vars.firstAllocationVault1,
            vars.firstAllocationVault2,
            address(fluidVault),
            address(aaveVault)
        );

        vars.initialShareBalance = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], vars.firstDepositAmount);
        vars.firstDepositShares = vault.balanceOf(accInstances[0].account) - vars.initialShareBalance;
        vars.firstDepositSharePrice = vars.firstDepositShares * 1e18 / vars.firstDepositAmount;

        _requestDepositForAccount(accInstances[0], vars.secondDepositAmount);

        vars.secondAllocationVault1 = vars.secondDepositAmount * 90 / 100;
        vars.secondAllocationVault2 = vars.secondDepositAmount - vars.secondAllocationVault1;
        _fulfillDepositForUsers(
            requestingUsers,
            vars.secondAllocationVault1,
            vars.secondAllocationVault2,
            address(fluidVault),
            address(aaveVault)
        );

        vars.shareBalanceAfterFirstDeposit = vault.balanceOf(accInstances[0].account);
        _claimDepositForAccount(accInstances[0], vars.secondDepositAmount);
        vars.secondDepositShares = vault.balanceOf(accInstances[0].account) - vars.shareBalanceAfterFirstDeposit;
        vars.secondDepositSharePrice = vars.secondDepositShares * 1e18 / vars.secondDepositAmount;

        _verifyAndLogChangingAllocation(vars);
    }
}
