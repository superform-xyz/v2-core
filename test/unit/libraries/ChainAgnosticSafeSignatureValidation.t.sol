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
    bool public _isValid;

    constructor(address[] memory owners_, uint256 threshold_) {
        _owners = owners_;
        _threshold = threshold_;
        _isValid = true;
    }

    function getOwners() external view returns (address[] memory) {
        require(_isValid, "Mock: getOwners failed");
        return _owners;
    }

    function getThreshold() external view returns (uint256) {
        require(_isValid, "Mock: getThreshold failed");
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

    function setInvalid() external {
        _isValid = false;
    }
}

/// @title Mock non-Safe contract for testing fallback behavior
contract MockNonSafe {
    // This contract doesn't implement ISafeConfiguration
    function someOtherFunction() external pure returns (bool) {
        return true;
    }
}

contract ChainAgnosticSafeSignatureValidationTest is Test {
    using ChainAgnosticSafeSignatureValidation for address;

    // Test accounts
    uint256 private constant PRIVATE_KEY_1 = 1;
    uint256 private constant PRIVATE_KEY_2 = 2;
    uint256 private constant PRIVATE_KEY_3 = 3;
    uint256 private constant PRIVATE_KEY_4 = 4;

    address private owner1;
    address private owner2;
    address private owner3;
    address private owner4;

    // Mock contracts
    MockSafeAccount private mockSafe;
    MockNonSafe private mockNonSafe;

    // EIP-712 constants (must match the library values)
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    uint256 private constant FIXED_CHAIN_ID = 1;
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";

    function setUp() public {
        // Setup owners using private keys
        owner1 = vm.addr(PRIVATE_KEY_1);
        owner2 = vm.addr(PRIVATE_KEY_2);
        owner3 = vm.addr(PRIVATE_KEY_3);
        owner4 = vm.addr(PRIVATE_KEY_4);

        // Create owners array (will be sorted by the library)
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // Setup mock Safe with threshold of 2
        mockSafe = new MockSafeAccount(owners, 2);
        mockNonSafe = new MockNonSafe();
    }

    /// @dev Helper function to create chain-agnostic hash
    function _createChainAgnosticHash(address safe, bytes32 rawHash) private pure returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                safe
            )
        );

        return keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(rawHash))))
            )
        );
    }

    /// @dev Helper function to create signatures in CheckNSignatures format (no validator prefix)
    function _createSignatures(uint256[] memory privateKeys, bytes32 hash) private pure returns (bytes memory) {
        bytes memory signatures = "";

        for (uint256 i = 0; i < privateKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], hash);
            signatures = abi.encodePacked(signatures, r, s, v);
        }

        return signatures;
    }

    /// @dev Helper function to create SignatureData struct
    function _createSignatureData(bytes memory signature) private view returns (ISuperValidator.SignatureData memory) {
        return ISuperValidator.SignatureData({
            signature: signature,
            merkleRoot: bytes32(uint256(123)),
            validUntil: uint48(block.timestamp + 1 days),
            chainsWithDestinationExecution: new uint64[](0),
            proofSrc: new bytes32[](0),
            proofDst: new ISuperValidator.DstProof[](0)
        });
    }

    function test_ValidateChainAgnosticMultisig_ValidSignatures_ExactThreshold() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Create signatures from owner1 and owner2 (meets threshold of 2)
        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;

        bytes memory signatures = _createSignatures(signingKeys, chainAgnosticHash);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertTrue(isValid, "Should validate with exact threshold");
    }

    function test_ValidateChainAgnosticMultisig_ValidSignatures_AboveThreshold() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Create signatures from all three owners (above threshold of 2)
        uint256[] memory signingKeys = new uint256[](3);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;
        signingKeys[2] = PRIVATE_KEY_3;

        bytes memory signatures = _createSignatures(signingKeys, chainAgnosticHash);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertTrue(isValid, "Should validate with signatures above threshold");
    }

    function test_ValidateChainAgnosticMultisig_InvalidSignatures_WrongHash() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 wrongHash = keccak256(abi.encode("wrong message", block.timestamp));

        // Sign with wrong hash
        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;

        bytes memory signatures = _createSignatures(signingKeys, wrongHash);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with signatures for wrong hash");
    }

    function test_ValidateChainAgnosticMultisig_ThresholdNotMet() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Only one signature (threshold is 2)
        uint256[] memory signingKeys = new uint256[](1);
        signingKeys[0] = PRIVATE_KEY_1;

        bytes memory signatures = _createSignatures(signingKeys, chainAgnosticHash);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail when threshold not met");
    }

    function test_ValidateChainAgnosticMultisig_InvalidOwner() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Sign with owner1 and owner4 (owner4 is not in the Safe)
        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1; // valid owner
        signingKeys[1] = PRIVATE_KEY_4; // invalid owner (not in Safe)

        bytes memory signatures = _createSignatures(signingKeys, chainAgnosticHash);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with signature from non-owner");
    }

    function test_ValidateChainAgnosticMultisig_EmptySignatures() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        bytes memory emptySignatures = "";
        ISuperValidator.SignatureData memory sigData = _createSignatureData(emptySignatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with empty signatures");
    }

    function test_ValidateChainAgnosticMultisig_ZeroThreshold() public {
        // Create Safe with zero threshold
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        MockSafeAccount zeroThresholdSafe = new MockSafeAccount(owners, 0);

        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes memory signatures = "";
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(zeroThresholdSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with zero threshold");
    }

    function test_ValidateChainAgnosticMultisig_EmptyOwnersArray() public {
        // Create Safe with empty owners array
        address[] memory emptyOwners = new address[](0);
        MockSafeAccount emptySafe = new MockSafeAccount(emptyOwners, 1);

        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        uint256[] memory signingKeys = new uint256[](1);
        signingKeys[0] = PRIVATE_KEY_1;
        bytes memory signatures = _createSignatures(signingKeys, keccak256("anything"));
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(emptySafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with empty owners array");
    }

    function test_ValidateChainAgnosticMultisig_NonSafeContract() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;
        bytes memory signatures = _createSignatures(signingKeys, keccak256("anything"));
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        // Test with non-Safe contract
        bool isValid = address(mockNonSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail for non-Safe contract");
    }

    function test_ValidateChainAgnosticMultisig_SafeConfigurationFails() public {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        // Make the mock Safe fail getOwners/getThreshold calls
        mockSafe.setInvalid();

        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;
        bytes memory signatures = _createSignatures(signingKeys, keccak256("anything"));
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail when Safe configuration calls fail");
    }

    function test_ValidateChainAgnosticMultisig_MalformedSignatures() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        // Create malformed signatures (not multiple of 65 bytes)
        bytes memory malformedSignatures = abi.encodePacked(bytes32(0), bytes16(0)); // 48 bytes
        ISuperValidator.SignatureData memory sigData = _createSignatureData(malformedSignatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with malformed signatures");
    }

    function test_ValidateChainAgnosticMultisig_DuplicateSignatures() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Create duplicate signatures from the same owner
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY_1, chainAgnosticHash);
        bytes memory signatures = abi.encodePacked(
            r,
            s,
            v, // First signature from owner1
            r,
            s,
            v // Duplicate signature from owner1
        );

        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertFalse(isValid, "Should fail with duplicate signatures");
    }

    function test_ValidateChainAgnosticMultisig_SignatureOrdering() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));
        bytes32 chainAgnosticHash = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Test that signature ordering doesn't matter due to sorting in library
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(PRIVATE_KEY_1, chainAgnosticHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(PRIVATE_KEY_2, chainAgnosticHash);

        // Test different orderings
        bytes memory signaturesOrder1 = abi.encodePacked(r1, s1, v1, r2, s2, v2);
        bytes memory signaturesOrder2 = abi.encodePacked(r2, s2, v2, r1, s1, v1);

        ISuperValidator.SignatureData memory sigData1 = _createSignatureData(signaturesOrder1);
        ISuperValidator.SignatureData memory sigData2 = _createSignatureData(signaturesOrder2);

        bool isValid1 = address(mockSafe).validateChainAgnosticMultisig(sigData1, rawHash);
        bool isValid2 = address(mockSafe).validateChainAgnosticMultisig(sigData2, rawHash);

        assertTrue(isValid1, "Should validate regardless of signature order (1)");
        assertTrue(isValid2, "Should validate regardless of signature order (2)");
    }

    function test_ValidateChainAgnosticMultisig_ChainAgnosticProperty() public view {
        bytes32 rawHash = keccak256(abi.encode("test message", block.timestamp));

        // Hash should always use FIXED_CHAIN_ID (1), not block.chainid
        bytes32 chainAgnosticHash1 = _createChainAgnosticHash(address(mockSafe), rawHash);

        // Hash should always use FIXED_CHAIN_ID (1), not block.chainid
        assertTrue(chainAgnosticHash1 != bytes32(0), "Chain agnostic hash should be generated");

        // Create valid signatures
        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = PRIVATE_KEY_1;
        signingKeys[1] = PRIVATE_KEY_2;

        bytes memory signatures = _createSignatures(signingKeys, chainAgnosticHash1);
        ISuperValidator.SignatureData memory sigData = _createSignatureData(signatures);

        bool isValid = address(mockSafe).validateChainAgnosticMultisig(sigData, rawHash);
        assertTrue(isValid, "Chain agnostic validation should work");
    }
}
