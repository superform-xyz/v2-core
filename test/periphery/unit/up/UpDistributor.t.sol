// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../../src/periphery/UP/Up.sol";
import "../../../../src/periphery/UP/UpDistributor.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MerkleReader } from "./merkle/helper/MerkleReader.sol";

contract UpDistributorTest is Test, MerkleReader {
    Up public UpToken;
    UpDistributor public distributor;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;
    bytes32 public merkleRoot;
    uint256 public constant CLAIM_AMOUNT = 100 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Deploy contracts
        UpToken = new Up(owner);
        distributor = new UpDistributor(address(UpToken), owner);

        // Create Merkle tree data
        (merkleRoot, merkleProof1) = _generateMerkleTree(MerkleReader.MerkleArgs(user1));
        (, merkleProof2) = _generateMerkleTree(MerkleReader.MerkleArgs(user2));

        // Set merkle root
        distributor.setMerkleRoot(merkleRoot);

        // Transfer tokens to distributor
        UpToken.transfer(address(distributor), CLAIM_AMOUNT * 3);

        // Label addresses for better trace output
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(address(UpToken), "UpToken");
        vm.label(address(distributor), "Distributor");
    }

    /**
     *
     * Constructor Tests
     *
     */
    function test_Constructor() public view {
        assertEq(address(distributor.token()), address(UpToken));
        assertEq(distributor.owner(), owner);
        assertEq(distributor.merkleRoot(), merkleRoot);
    }

    /**
     *
     * Merkle Root Tests
     *
     */
    function test_SetMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        distributor.setMerkleRoot(newRoot);
        assertEq(distributor.merkleRoot(), newRoot);
    }

    function test_RevertWhen_SettingMerkleRootByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        distributor.setMerkleRoot(bytes32(0));
    }

    /**
     *
     * Claim Tests
     *
     */
    function test_Claim() public {
        uint256 initialBalance = UpToken.balanceOf(user1);

        vm.prank(user1);
        distributor.claim(CLAIM_AMOUNT, merkleProof1);

        assertEq(UpToken.balanceOf(user1), initialBalance + CLAIM_AMOUNT);
        assertTrue(distributor.hasClaimed(user1));
    }

    function test_RevertWhen_ClaimingWithInvalidProof() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidMerkleProof()"));
        distributor.claim(CLAIM_AMOUNT, merkleProof2);
    }

    function test_RevertWhen_ClaimingWithInvalidAmount() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidMerkleProof()"));
        distributor.claim(CLAIM_AMOUNT + 1, merkleProof1);
    }

    function test_RevertWhen_ClaimingAlreadyClaimed() public {
        vm.startPrank(user1);
        distributor.claim(CLAIM_AMOUNT, merkleProof1);
        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        distributor.claim(CLAIM_AMOUNT, merkleProof1);
        vm.stopPrank();
    }

    /**
     *
     * Token Reclamation Tests
     *
     */
    function test_ReclaimTokens() public {
        uint256 initialBalance = UpToken.balanceOf(owner);
        uint256 distributorBalance = UpToken.balanceOf(address(distributor));

        distributor.reclaimTokens(distributorBalance);

        assertEq(UpToken.balanceOf(owner), initialBalance + distributorBalance);
        assertEq(UpToken.balanceOf(address(distributor)), 0);
    }

    function test_RevertWhen_ReclaimingTokensByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        distributor.reclaimTokens(1);
    }

    function test_RevertWhen_ReclaimingInsufficientBalance() public {
        uint256 balance = UpToken.balanceOf(address(distributor));
        vm.expectRevert(abi.encodeWithSignature("NoTokensToReclaim()"));
        distributor.reclaimTokens(balance + 1);
    }

    /**
     *
     * Integration Tests
     *
     */
    function test_CompleteDistributionCycle() public {
        // Initial state checks
        uint256 initialDistributorBalance = UpToken.balanceOf(address(distributor));

        // Users claim their tokens
        vm.prank(user1);
        distributor.claim(CLAIM_AMOUNT, merkleProof1);

        vm.prank(user2);
        distributor.claim(CLAIM_AMOUNT, merkleProof2);

        // Verify claims
        assertTrue(distributor.hasClaimed(user1));
        assertTrue(distributor.hasClaimed(user2));
        assertEq(UpToken.balanceOf(user1), CLAIM_AMOUNT);
        assertEq(UpToken.balanceOf(user2), CLAIM_AMOUNT);

        // Owner reclaims remaining tokens
        uint256 remainingBalance = UpToken.balanceOf(address(distributor));
        distributor.reclaimTokens(remainingBalance);

        // Final state checks
        assertEq(UpToken.balanceOf(address(distributor)), 0);
        assertEq(remainingBalance, initialDistributorBalance - (CLAIM_AMOUNT * 2));
    }

    function test_NewDistributionCycle() public {
        // Complete first distribution
        vm.prank(user1);
        distributor.claim(CLAIM_AMOUNT, merkleProof1);

        // Start new distribution
        bytes32 newRoot = keccak256("new root");
        distributor.setMerkleRoot(newRoot);

        // Previous claims should still be recorded
        assertTrue(distributor.hasClaimed(user1));

        // Transfer more tokens for new distribution
        UpToken.transfer(address(distributor), CLAIM_AMOUNT * 2);

        // Reclaim remaining tokens from previous distribution
        uint256 remainingBalance = UpToken.balanceOf(address(distributor));
        distributor.reclaimTokens(remainingBalance);

        assertEq(UpToken.balanceOf(address(distributor)), 0);
    }
}
