// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ChainAgnosticSafeSignatureValidation } from "../../../src/libraries/ChainAgnosticSafeSignatureValidation.sol";
import { ISafeConfiguration } from "../../../src/vendor/gnosis/ISafeConfiguration.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title Mock Safe implementation for testing
contract MockSafeAccount is ISafeConfiguration {
    address[] public _owners;
    uint256 public _threshold;

    constructor(address[] memory owners_, uint256 threshold_) {
        _owners = owners_;
        _threshold = threshold_;
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function getThreshold() external view returns (uint256) {
        return _threshold;
    }
    
    function isOwner(address owner) external view returns (bool) {
        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == owner) {
                return true;
            }
        }
        return false;
    }
}

contract ChainAgnosticSafeSignatureValidationTest is Test {
    using ChainAgnosticSafeSignatureValidation for address;

    // Test accounts
    uint256 private constant privateKey1 = 1;
    uint256 private constant privateKey2 = 2;
    uint256 private constant privateKey3 = 3;
    address private owner1;
    address private owner2;
    address private owner3;

    // Mock Safe contract
    MockSafeAccount private mockSafe;

    // EIP-712 constants (must match the library values)
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH = 
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    uint256 private constant FIXED_CHAIN_ID = 1;
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";

    function setUp() public {
        // Setup owners using private keys
        owner1 = vm.addr(privateKey1);
        owner2 = vm.addr(privateKey2);
        owner3 = vm.addr(privateKey3);

        // Create ordered array of owners
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // Setup mock Safe with threshold of 2
        mockSafe = new MockSafeAccount(owners, 2);
    }

    function test_ValidateChainAgnosticMultisig_ValidSignatures() public view {
         // Create test message hash
        bytes32 rawHash = keccak256(abi.encode("SuperValidator", bytes32(uint256(123))));
        
        // Create chain-agnostic hash for signing
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                address(mockSafe)
            )
        );
        
        bytes32 chainAgnosticHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(rawHash))))
            )
        );

        // Sign with owner2 and owner1 keys
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, chainAgnosticHash);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, chainAgnosticHash);

        // Assemble signature data in wrong order (owner2 then owner1)
        bytes memory signature = abi.encodePacked(
            address(0), // validator address prefix (20 bytes)
            abi.encodePacked(r2, s2, v2), // signature from owner2
            abi.encodePacked(r1, s1, v1)  // signature from owner1 (should be in ascending order)
        );

        // Create SignatureData struct
        ISuperValidator.SignatureData memory sigData = ISuperValidator.SignatureData({
            signature: signature,
            merkleRoot: bytes32(uint256(123)),
            validUntil: uint48(block.timestamp + 1 days),
            validateDstProof: false,
            proofSrc: new bytes32[](0),
            proofDst: new ISuperValidator.DstProof[](0)
        });

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertTrue(isValid, "Validation should pass");
    }

    function test_ValidateChainAgnosticMultisig_InvalidSignatures() public view {
        // Create test message hash
        bytes32 rawHash = keccak256(abi.encode("SuperValidator", bytes32(uint256(123))));
        
        // Sign with wrong message hash using owner1 and owner2 keys
        bytes32 wrongHash = keccak256("wrong message hash");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, wrongHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, wrongHash);

        // Assemble signature data with invalid signatures
        bytes memory signature = abi.encodePacked(
            address(0), // validator address prefix (20 bytes)
            abi.encodePacked(r1, s1, v1), // signature from owner1 for wrong hash
            abi.encodePacked(r2, s2, v2)  // signature from owner2 for wrong hash
        );
        ISuperValidator.SignatureData memory sigData = ISuperValidator.SignatureData({
            signature: signature,
            merkleRoot: bytes32(uint256(123)),
            validUntil: uint48(block.timestamp + 1 days),
            validateDstProof: false,
            proofSrc: new bytes32[](0),
            proofDst: new ISuperValidator.DstProof[](0)
        });

        // Validate - should fail with invalid signatures
        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Invalid signatures should fail validation");
    }

    function test_ValidateChainAgnosticMultisig_ThresholdNotMet() public view {
        // Create test message hash
        bytes32 rawHash = keccak256(abi.encode("SuperValidator", bytes32(uint256(123))));
        
        // Create chain-agnostic hash for signing
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                address(mockSafe)
            )
        );
        
        bytes32 chainAgnosticHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(rawHash))))
            )
        );

        // Sign with only one owner
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, chainAgnosticHash);

        // Assemble signature data with only one signature (threshold is 2)
        bytes memory signature = abi.encodePacked(
            address(0), // validator address prefix (20 bytes)
            abi.encodePacked(r1, s1, v1) // signature from owner1 only
        );

        // Create SignatureData struct
        ISuperValidator.SignatureData memory sigData = ISuperValidator.SignatureData({
            signature: signature,
            merkleRoot: bytes32(uint256(123)),
            validUntil: uint48(block.timestamp + 1 days),
            validateDstProof: false,
            proofSrc: new bytes32[](0),
            proofDst: new ISuperValidator.DstProof[](0)
        });

        // Validate - should fail because threshold (2) is not met
        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Validation should fail when threshold is not met");
    }

    function test_ValidateChainAgnosticMultisig_EmptyOwnersArray() public {
        // Create Safe with empty owners array
        address[] memory emptyOwners = new address[](0);
        MockSafeAccount emptySafe = new MockSafeAccount(emptyOwners, 0);

        // Create test message hash and arbitrary signature
        bytes32 rawHash = keccak256(abi.encode("SuperValidator", bytes32(uint256(123))));
        bytes memory signature = abi.encodePacked(address(0), bytes32(0), bytes32(0), uint8(0));

        // Create SignatureData struct
        ISuperValidator.SignatureData memory sigData = ISuperValidator.SignatureData({
            signature: signature,
            merkleRoot: bytes32(uint256(123)),
            validUntil: uint48(block.timestamp + 1 days),
            validateDstProof: false,
            proofSrc: new bytes32[](0),
            proofDst: new ISuperValidator.DstProof[](0)
        });

        // Validate - should fail with empty owners array
        bool isValid = address(emptySafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Validation should fail with empty owners array");
    }
}
