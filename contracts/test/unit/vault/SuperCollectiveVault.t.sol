// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import "forge-std/Test.sol";

import { ISuperCollectiveVault } from "../../../src/interfaces/vault/ISuperCollectiveVault.sol";
import { SuperCollectiveVault } from "../../../src/vault/SuperCollectiveVault.sol";
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
        vm.expectRevert(ISuperCollectiveVault.INVALID_AMOUNT.selector);
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

    function testDistributeRewards() public {
        // Create reward token
        MockERC20 rewardToken = new MockERC20("Reward Token", "RWD", 18);
        uint256 rewardAmount = 100e18;
        
        // Create merkle tree data
        bytes32[] memory data = new bytes32[](1);
        data[0] = keccak256(abi.encodePacked(
            user,                   // recipient
            address(rewardToken),   // reward token
            rewardAmount           // amount
        ));
        
        // Create merkle root (in this simple case, it's just the single leaf)
        bytes32 merkleRoot = data[0];
        
        // Register merkle root
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        
        // Setup empty proof (since we're using a single-node tree)
        bytes32[] memory proof = new bytes32[](0);
        
        // Setup rewards
        _getTokens(address(rewardToken), address(vault), rewardAmount);
        
        // Distribute rewards
        vault.distributeRewards(
            merkleRoot,
            user,
            address(rewardToken),
            rewardAmount,
            proof
        );
        
        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(user), rewardAmount);
        assertEq(rewardToken.balanceOf(address(vault)), 0); // Rewards should go directly to user
    }

    function testDistributeRewardsWithMultipleRecipients() public {
        MockERC20 rewardToken = new MockERC20("Reward Token", "RWD", 18);
        
        address user1 = address(0xABC);
        address user2 = address(0xDEF);
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        
        // Create merkle tree with two leaves
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, address(rewardToken), amount1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, address(rewardToken), amount2));
        bytes32 merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));
        
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        
        // Create proofs
        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = leaf2;  // To prove leaf1, we need leaf2
        
        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = leaf1;  // To prove leaf2, we need leaf1
        
        // Setup rewards
        _getTokens(address(rewardToken), address(vault), amount1 + amount2);
        
        // Distribute rewards to both users
        vault.distributeRewards(
            merkleRoot,
            user1,
            address(rewardToken),
            amount1,
            proof1
        );
        
        vault.distributeRewards(
            merkleRoot,
            user2,
            address(rewardToken),
            amount2,
            proof2
        );
        
        // Verify rewards
        assertEq(rewardToken.balanceOf(user1), amount1);
        assertEq(rewardToken.balanceOf(user2), amount2);
    }

    function testCannotDistributeRewardsWithUnregisteredRoot() public {
        MockERC20 rewardToken = new MockERC20("Reward Token", "RWD", 18);
        bytes32 unregisteredRoot = keccak256(abi.encodePacked("unregistered"));
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("proof"));
        
        uint256 amount = 100e18;
        _getTokens(address(rewardToken), address(this), amount);
        rewardToken.approve(address(vault), amount);
        
        vm.expectRevert(ISuperCollectiveVault.INVALID_MERKLE_ROOT.selector);
        vault.distributeRewards(
            unregisteredRoot,
            user,  // recipient account
            address(rewardToken),
            amount,
            proof
        );
    }

    function testCannotDistributeZeroRewards() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("root"));
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("proof"));
        
        vm.expectRevert(ISuperCollectiveVault.INVALID_AMOUNT.selector);
        vault.distributeRewards(
            merkleRoot,
            user,  // recipient account
            address(token),
            0,
            proof
        );
    }

    function testCannotDistributeRewardsToZeroAddress() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("root"));
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("proof"));
        
        vm.expectRevert(ISuperCollectiveVault.INVALID_TOKEN.selector);
        vault.distributeRewards(
            merkleRoot,
            user,  // recipient account
            address(0),  // zero token address
            100e18,
            proof
        );
    }

    function testCannotDistributeToZeroAccount() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("root"));
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("proof"));
        
        vm.expectRevert(ISuperCollectiveVault.INVALID_ACCOUNT.selector);
        vault.distributeRewards(
            merkleRoot,
            address(0),  // zero account address
            address(token),
            100e18,
            proof
        );
    }

    function testUnregisterMerkleRoot() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("root"));
        
        _resetCaller(address(this));
        vault.updateMerkleRoot(merkleRoot, true);
        assertEq(vault.isMerkleRootRegistered(merkleRoot), true);
        
        vault.updateMerkleRoot(merkleRoot, false);
        assertEq(vault.isMerkleRootRegistered(merkleRoot), false);
        
        // Try to distribute rewards with unregistered root
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("proof"));
        
        vm.expectRevert(ISuperCollectiveVault.INVALID_MERKLE_ROOT.selector);
        vault.distributeRewards(
            merkleRoot,
            address(user),
            address(token),
            100e18,
            proof
        );
    }

    function testMultipleMerkleRoots() public {
        bytes32[] memory roots = new bytes32[](3);
        roots[0] = keccak256(abi.encodePacked("root1"));
        roots[1] = keccak256(abi.encodePacked("root2"));
        roots[2] = keccak256(abi.encodePacked("root3"));
        
        _resetCaller(address(this));
        
        // Register all roots
        for(uint i = 0; i < roots.length; i++) {
            vault.updateMerkleRoot(roots[i], true);
            assertEq(vault.isMerkleRootRegistered(roots[i]), true);
        }
        
        // Unregister middle root
        vault.updateMerkleRoot(roots[1], false);
        
        // Verify states
        assertEq(vault.isMerkleRootRegistered(roots[0]), true);
        assertEq(vault.isMerkleRootRegistered(roots[1]), false);
        assertEq(vault.isMerkleRootRegistered(roots[2]), true);
    }
}