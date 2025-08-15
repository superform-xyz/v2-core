// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SignatureTransientStorage } from "../../../src/libraries/SignatureTransientStorage.sol";

/**
 * @title SignatureTransientStorageTest
 * @notice Unit tests for the SignatureTransientStorage library
 */
contract SignatureTransientStorageTest is Test {
    using SignatureTransientStorage for uint256;

    // Event to verify error handling
    event ErrorCaptured(string message);
    
    /**
     * @notice Helper function to store signature data that handles memory to calldata conversion
     * @param identifier The unique identifier for the signature
     * @param data The signature data in memory
     */
    function storeSignatureHelper(uint256 identifier, bytes memory data) internal {
        // Call helper function that accepts bytes calldata
        this.storeSignatureCalldataHelper(identifier, data);
    }
    
    /**
     * @notice External helper function that takes bytes calldata and forwards to library
     * @dev This function must be external to convert memory to calldata
     * @param identifier The unique identifier for the signature
     * @param data The signature data as calldata
     */
    function storeSignatureCalldataHelper(uint256 identifier, bytes calldata data) external {
        identifier.storeSignature(data);
    }

    function test_StoreAndLoadSignature() public {
        // Create test data
        uint256 identifier = uint256(0x1234);
        bytes memory testSignature = abi.encodePacked(
            bytes32(uint256(0x123456)),
            bytes32(uint256(0x789abc)),
            bytes1(0xaa)
        );
        
        // Store the signature data using helper
        storeSignatureHelper(identifier, testSignature);
        
        // Load the signature data
        bytes memory retrieved = identifier.loadSignature();
        
        // Verify the retrieved data matches the original
        assertEq(retrieved.length, testSignature.length, "Retrieved signature length should match stored length");
        assertEq(keccak256(retrieved), keccak256(testSignature), "Retrieved signature should match stored signature");
    }
    
    function test_StoreSignatureWithLargeData() public {
        // Create a larger test signature (200 bytes)
        uint256 identifier = uint256(0x5678);
        bytes memory largeSignature = new bytes(200);
        
        // Fill with some pattern data
        for (uint256 i = 0; i < largeSignature.length; i++) {
            largeSignature[i] = bytes1(uint8(i % 256));
        }
        
        // Store using helper and retrieve
        storeSignatureHelper(identifier, largeSignature);
        bytes memory retrieved = identifier.loadSignature();
        
        // Verify
        assertEq(retrieved.length, largeSignature.length, "Retrieved large signature length should match stored length");
        assertEq(keccak256(retrieved), keccak256(largeSignature), "Retrieved large signature should match stored signature");
    }
    
    function test_StoreSignatureMultipleTimes() public {
        // Attempt to store two different signatures with the same identifier
        uint256 identifier = uint256(0x9abc);
        bytes memory sig1 = abi.encodePacked(bytes32(uint256(0x1111)));
        bytes memory sig2 = abi.encodePacked(bytes32(uint256(0x2222)));
        
        // Store the first signature
        storeSignatureHelper(identifier, sig1);
        
        // Attempt to store the second signature with the same identifier (should revert)
        vm.expectRevert(SignatureTransientStorage.INVALID_USER_OP.selector);
        storeSignatureHelper(identifier, sig2);
    }
    
    function test_DifferentIdentifiers() public {
        // Test that different identifiers don't overwrite each other
        uint256 identifier1 = uint256(0x1111);
        uint256 identifier2 = uint256(0x2222);
        
        bytes memory sig1 = abi.encodePacked(bytes32(uint256(0xaaaa)));
        bytes memory sig2 = abi.encodePacked(bytes32(uint256(0xbbbb)));
        
        // Store both signatures using helper
        storeSignatureHelper(identifier1, sig1);
        storeSignatureHelper(identifier2, sig2);
        
        // Retrieve and verify
        bytes memory retrieved1 = identifier1.loadSignature();
        bytes memory retrieved2 = identifier2.loadSignature();
        
        // Check that the signatures weren't mixed up
        assertEq(keccak256(retrieved1), keccak256(sig1), "First signature should be correctly retrieved");
        assertEq(keccak256(retrieved2), keccak256(sig2), "Second signature should be correctly retrieved");
    }
    
    function test_EmptySignature() public {
        // Test with an empty signature
        uint256 identifier = uint256(0xdeadbeef);
        bytes memory emptySignature = new bytes(0);
        
        // Store using helper and retrieve
        storeSignatureHelper(identifier, emptySignature);
        bytes memory retrieved = identifier.loadSignature();
        
        // Verify
        assertEq(retrieved.length, 0, "Retrieved empty signature should have zero length");
    }

    function test_StoreSignatureAcrossMultipleWords() public {
        // Create a test signature that spans multiple 32-byte words to test the assembly loop
        uint256 identifier = uint256(0xABCD);
        
        // Create signature with 96 bytes (3 words) to ensure multiple iterations in the assembly loop
        bytes memory multiWordSignature = new bytes(96);
        
        // Fill with recognizable patterns for each word to verify storage/retrieval
        for (uint i = 0; i < 32; i++) {
            multiWordSignature[i] = bytes1(uint8(0xAA)); // First word
        }
        for (uint i = 32; i < 64; i++) {
            multiWordSignature[i] = bytes1(uint8(0xBB)); // Second word
        }
        for (uint i = 64; i < 96; i++) {
            multiWordSignature[i] = bytes1(uint8(0xCC)); // Third word
        }
        
        // Store using helper
        storeSignatureHelper(identifier, multiWordSignature);
        
        // Load the signature
        bytes memory retrieved = identifier.loadSignature();
        
        // Verify signature length
        assertEq(retrieved.length, multiWordSignature.length, "Retrieved multi-word signature length mismatch");
        
        // Verify content of each word
        for (uint i = 0; i < 32; i++) {
            assertEq(uint8(retrieved[i]), 0xAA, "First word content mismatch");
        }
        for (uint i = 32; i < 64; i++) {
            assertEq(uint8(retrieved[i]), 0xBB, "Second word content mismatch");
        }
        for (uint i = 64; i < 96; i++) {
            assertEq(uint8(retrieved[i]), 0xCC, "Third word content mismatch");
        }
        
        // Also verify full signature matches
        assertEq(keccak256(retrieved), keccak256(multiWordSignature), "Full multi-word signature mismatch");
    }
}
