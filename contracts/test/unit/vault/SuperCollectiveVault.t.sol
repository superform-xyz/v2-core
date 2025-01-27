// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import "forge-std/Test.sol";

import { ISuperCollectiveVault } from "../../../src/interfaces/vault/ISuperCollectiveVault.sol";
import { SuperCollectiveVault } from "../../../src/superPositions/SuperCollectiveVault.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import { BaseTest } from "../../BaseTest.t.sol";

contract SuperCollectiveVaultTest is BaseTest {
    SuperCollectiveVault public vault;
    MockERC20 public token;

    address executor = address(0x123);
    address manager = address(0x456);
    address user = address(0x789);

    function setUp() public override {
        super.setUp();
        
        vm.selectFork(FORKS[ETH]);

        // Deploy mock token and vault
        token = new MockERC20("Mock Token", "MKT", 18);
        vault = SuperCollectiveVault(_getContract(ETH, "SuperCollectiveVault"));
    }

    function testVault_LockTokens(uint256 amount) public {
        amount = bound(amount, SMALL, LARGE);
        _getTokens(address(token), address(user), amount);

        _resetCaller(user);
        token.approve(address(vault), amount);
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), amount);

        assertEq(vault.viewLockedAmount(user, address(token)), amount);

        vm.stopPrank();
    }

    function testVault_UnlockTokens(uint256 amount) public {
        amount = bound(amount, SMALL, LARGE);
        _getTokens(address(token), address(user), amount);

        _resetCaller(user);
        token.approve(address(vault), amount);
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), amount);
        assertEq(vault.viewLockedAmount(user, address(token)), amount);

        _resetCaller(address(this));
        vault.unlock(user, address(token), amount);

        assertEq(vault.viewLockedAmount(user, address(token)), 0);
    }

    function testVault_UpdateMerkleRoot() public {
        bytes32 newMerkleRoot = keccak256(abi.encodePacked("new_root"));

        assertEq(vault.isMerkleRootRegistered(newMerkleRoot), false);

        _resetCaller(address(user));
        vm.expectRevert(ISuperCollectiveVault.NOT_AUTHORIZED.selector);
        vault.updateMerkleRoot(newMerkleRoot, true);

        _resetCaller(address(this));
        vault.updateMerkleRoot(newMerkleRoot, true);

        assertEq(vault.isMerkleRootRegistered(newMerkleRoot), true);
    }

    function testCannotLockZeroAmount() public {
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vm.expectRevert(ISuperCollectiveVault.INVALID_AMOUNT.selector);
        vault.lock(user, address(token), 0);
    }

    function testCannotLockForZeroAddress() public {
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vm.expectRevert(ISuperCollectiveVault.INVALID_ACCOUNT.selector);
        vault.lock(address(0), address(token), 1e18);
    }

    function testLockWithoutApproval() public {
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vm.expectRevert();
        vault.lock(user, address(token), 1e18);
    }

    function testMultipleLocks() public {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e18;
        
        _getTokens(address(token), address(user), amount1 + amount2);
        
        _resetCaller(user);
        token.approve(address(vault), amount1 + amount2);
        
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), amount1);
        assertEq(vault.viewLockedAmount(user, address(token)), amount1);
        
        vault.lock(user, address(token), amount2);
        assertEq(vault.viewLockedAmount(user, address(token)), amount1 + amount2);
    }

    function testCannotUnlockZeroAmount() public {
        _resetCaller(address(this));
        vm.expectRevert(ISuperCollectiveVault.NO_LOCKED_ASSETS.selector);
        vault.unlock(user, address(token), 0);
    }

    function testCannotUnlockForZeroAddress() public {
        _resetCaller(address(this));
        vm.expectRevert(ISuperCollectiveVault.INVALID_ACCOUNT.selector);
        vault.unlock(address(0), address(token), 1e18);
    }

    function testCannotUnlockMoreThanLocked() public {
        uint256 lockAmount = 1e18;
        _getTokens(address(token), address(user), lockAmount);
        
        _resetCaller(user);
        token.approve(address(vault), lockAmount);
        
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), lockAmount);
        
        _resetCaller(address(this));
        vm.expectRevert(ISuperCollectiveVault.INVALID_AMOUNT.selector);
        vault.unlock(user, address(token), lockAmount + 1);
    }

    function testPartialUnlock() public {
        uint256 lockAmount = 2e18;
        uint256 unlockAmount = 1e18;
        
        _getTokens(address(token), address(user), lockAmount);
        
        _resetCaller(user);
        token.approve(address(vault), lockAmount);
        
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), lockAmount);
        
        _resetCaller(address(this));
        vault.unlock(user, address(token), unlockAmount);
        
        assertEq(vault.viewLockedAmount(user, address(token)), lockAmount - unlockAmount);
    }

    function testLockAndUnlockWithMultipleUsers() public {
        address user1 = address(0x123);
        address user2 = address(0x456);
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e18;
        
        // Setup initial tokens for users
        _getTokens(address(token), user1, amount1);
        _getTokens(address(token), user2, amount2);
        
        // User 1 approves and locks
        _resetCaller(user1);
        token.approve(address(vault), amount1);
        
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user1, address(token), amount1);
        
        // User 2 approves and locks
        _resetCaller(user2);
        token.approve(address(vault), amount2);
        
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user2, address(token), amount2);
        
        assertEq(vault.viewLockedAmount(user1, address(token)), amount1);
        assertEq(vault.viewLockedAmount(user2, address(token)), amount2);
        
        // Unlock for user1
        _resetCaller(address(this));
        vault.unlock(user1, address(token), amount1);
        
        assertEq(vault.viewLockedAmount(user1, address(token)), 0);
        assertEq(vault.viewLockedAmount(user2, address(token)), amount2);
        assertEq(token.balanceOf(user1), amount1);
    }
}