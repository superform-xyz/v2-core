// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { SuperMerkleValidator } from "../../../src/core/validators/SuperMerkleValidator.sol";
import { MerkleProofVerifier } from "../../../src/core/verifiers/MerkleProofVerifier.sol";
import { ECDSASignatureVerifier } from "../../../src/core/verifiers/ECDSASignatureVerifier.sol";
import { ISuperProofVerifier } from "../../../src/core/interfaces/ISuperProofVerifier.sol";
import { ISuperSignatureVerifier } from "../../../src/core/interfaces/ISuperSignatureVerifier.sol";

import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseTest } from "../../BaseTest.t.sol";

/// @title ProofBasedValidationTest
/// @dev Tests for proof-based validation functionality
contract ProofBasedValidationTest is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    // Core contracts
    SuperMerkleValidator public validator;
    MerkleProofVerifier public proofVerifier;
    ECDSASignatureVerifier public signatureVerifier;
    
    // Test addresses
    address public constant ADMIN = address(0x1);
    address public constant USER = address(0x2);
    
    // User's private key for testing
    uint256 private userPrivateKey;
    
    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        
        // Generate a deterministic user key pair for signing
        userPrivateKey = 0x12345678;
        address derivedUser = vm.addr(userPrivateKey);
        
        // Deploy verifiers
        proofVerifier = new MerkleProofVerifier();
        signatureVerifier = new ECDSASignatureVerifier();
        
        // Deploy validator with verifiers
        validator = new SuperMerkleValidator(
            address(proofVerifier),
            address(signatureVerifier)
        );
        
        // Install validator on test account
        accountInstances[ETH].installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
    }
    
    function test_ValidatorUsesProofVerifier() public {
        // Create a simple execution
        bytes32 executionHash = keccak256(abi.encode("test execution"));
        
        // Generate Merkle tree components for validation
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = executionHash;
        
        // For simplicity, we're using a one-node Merkle tree
        bytes32 root = leaves[0];
        bytes32[] memory proof = new bytes32[](0);
        
        // Encode proof for validator
        bytes memory encodedProof = abi.encode(proof);
        
        // Sign the root with user's private key
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                root
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Setup user account ownership
        address account = accountInstances[ETH].account;
        
        // Initialize validator for account
        vm.prank(account);
        validator.onInstall("");
        
        // Set user as the owner
        vm.prank(account);
        validator.setAccountOwner(vm.addr(userPrivateKey));
        
        // Prepare and validate the execution
        bytes memory validatorPayload = abi.encode(
            uint48(block.timestamp + 1 hours), // validUntil
            root,                              // merkleRoot
            encodedProof,                      // proof
            signature                          // signature
        );
        
        // Verify the execution is validated properly
        bool isValid = validator.validateUserOp(
            account,
            executionHash,
            validatorPayload
        );
        
        // The validation should succeed
        assertTrue(isValid, "Proof-based validation failed");
    }
    
    function test_ValidatorRejectsInvalidProof() public {
        // Create a simple execution
        bytes32 executionHash = keccak256(abi.encode("test execution"));
        bytes32 differentExecutionHash = keccak256(abi.encode("different execution"));
        
        // Generate Merkle tree components for validation
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = executionHash; // The valid hash
        
        // For simplicity, we're using a one-node Merkle tree
        bytes32 root = leaves[0];
        bytes32[] memory proof = new bytes32[](0);
        
        // Encode proof for validator
        bytes memory encodedProof = abi.encode(proof);
        
        // Sign the root with user's private key
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                root
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Setup user account ownership
        address account = accountInstances[ETH].account;
        
        // Initialize validator for account
        vm.prank(account);
        validator.onInstall("");
        
        // Set user as the owner
        vm.prank(account);
        validator.setAccountOwner(vm.addr(userPrivateKey));
        
        // Prepare and validate the execution with different hash than what's in the Merkle tree
        bytes memory validatorPayload = abi.encode(
            uint48(block.timestamp + 1 hours), // validUntil
            root,                              // merkleRoot
            encodedProof,                      // proof
            signature                          // signature
        );
        
        // Try to validate with a different hash than what's in the Merkle tree
        bool isValid = validator.validateUserOp(
            account,
            differentExecutionHash, // Different hash than what was used in the Merkle tree
            validatorPayload
        );
        
        // The validation should fail
        assertFalse(isValid, "Proof verification should have failed with invalid hash");
    }
    
    function test_ValidatorRejectsInvalidSignature() public {
        // Create a simple execution
        bytes32 executionHash = keccak256(abi.encode("test execution"));
        
        // Generate Merkle tree components for validation
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = executionHash;
        
        // For simplicity, we're using a one-node Merkle tree
        bytes32 root = leaves[0];
        bytes32[] memory proof = new bytes32[](0);
        
        // Encode proof for validator
        bytes memory encodedProof = abi.encode(proof);
        
        // Sign with wrong private key
        uint256 wrongPrivateKey = 0x87654321;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                root
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, messageHash);
        bytes memory invalidSignature = abi.encodePacked(r, s, v);
        
        // Setup user account ownership
        address account = accountInstances[ETH].account;
        
        // Initialize validator for account
        vm.prank(account);
        validator.onInstall("");
        
        // Set user as the owner
        vm.prank(account);
        validator.setAccountOwner(vm.addr(userPrivateKey));
        
        // Prepare and validate the execution with invalid signature
        bytes memory validatorPayload = abi.encode(
            uint48(block.timestamp + 1 hours), // validUntil
            root,                              // merkleRoot
            encodedProof,                      // proof
            invalidSignature                   // invalid signature
        );
        
        // Verify the execution is rejected due to invalid signature
        bool isValid = validator.validateUserOp(
            account,
            executionHash,
            validatorPayload
        );
        
        // The validation should fail
        assertFalse(isValid, "Validation should fail with invalid signature");
    }
}
