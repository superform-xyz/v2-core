// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { ISafeConfiguration } from "../vendor/gnosis/ISafeConfiguration.sol";

// Superform
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

library ChainAgnosticSafeSignatureValidation {
    /// @notice Chain-agnostic domain separator type hash
    /// @dev Uses a fixed domain without chainId for cross-chain compatibility
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f; 
    /// @notice Fixed chain ID for cross-chain signature 1271 compatibility
    uint256 private constant FIXED_CHAIN_ID = 1;
    /// @notice Domain name and version for cross-chain 1271 signatures
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";
    /// @notice Magic value for EIP-1271 validation
    bytes4 internal constant MAGIC_VALUE_EIP1271 = bytes4(0x1626ba7e);

    function validateChainAgnosticMultisig(address safe, ISuperValidator.SignatureData memory sigData, bytes32 rawHash) internal view returns (bool) {
        // Get the chain-agnostic message hash
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                safe
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

        // Get Safe configuration
        address[] memory owners = ISafeConfiguration(safe).getOwners();
        uint256 threshold = ISafeConfiguration(safe).getThreshold();

        // Validate signatures against the multisig configuration
        return _verifyMultisigSignatures(chainAgnosticHash, sigData.signature, owners, threshold);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Verifies multisig signatures against owners and threshold
    /// @dev Implements Safe-compatible signature verification with chain-agnostic hash
    /// @param messageHash The chain-agnostic message hash
    /// @param signatures The concatenated signature data
    /// @param owners Array of Safe owner addresses
    /// @param threshold Required number of signatures
    /// @return True if enough valid signatures are provided
    function _verifyMultisigSignatures(
        bytes32 messageHash,
        bytes memory signatures,
        address[] memory owners,
        uint256 threshold
    )
        private
        pure
        returns (bool)
    {
        // Check for valid threshold and owners
        if (threshold == 0 || owners.length == 0) {
            return false;
        }

        if (signatures.length < threshold * 65) {
            return false;
        }

        // Account for 20-byte validator address prefix in Safe signature format
        uint256 signatureOffset = 20;
        uint256 actualSignatureLength = signatures.length - signatureOffset;

        // Each ECDSA signature is 65 bytes: r (32) + s (32) + v (1)
        if (actualSignatureLength < threshold * 65) {
            return false;
        }

        address lastOwner = address(0);
        uint256 validSignatures = 0;

        for (uint256 i = 0; i < threshold; i++) {
            // Calculate signature position (skip the 20-byte validator prefix)
            uint256 pos = 20 + (i * 65);
            
            // Make sure we don't go out of bounds
            if (pos + 65 > signatures.length) {
                return false;
            }
            
            // Extract signature components
            bytes32 r;
            bytes32 s;
            uint8 v;
            
            // Extract r, s, v components with proper offset calculations
            assembly {
                // Calculate memory position for this signature
                // signatures pointer + 0x20 (to skip length) + pos
                let signaturePos := add(add(signatures, 0x20), pos)
                
                // Load r, s components
                r := mload(signaturePos)                      // First 32 bytes
                s := mload(add(signaturePos, 32))             // Next 32 bytes
                
                // Extract v from the 65th byte (first byte of the next word)
                v := byte(0, mload(add(signaturePos, 64)))   // 65th byte
            }
            
            // Skip empty signatures
            if (v == 0 && r == bytes32(0) && s == bytes32(0)) {
                continue;
            }

            // Adjust v for Ethereum signed messages (some clients use 0/1 instead of 27/28)
            if (v < 27) {
                v += 27;
            }
            
            // Recover signer address
            address currentOwner = ecrecover(messageHash, v, r, s);
            
            // Make sure we have a valid recovered address
            if (currentOwner == address(0)) {
                return false;
            }

            // Check if recovered address is a valid owner and maintains ascending order
            if (_isOwner(currentOwner, owners)) {
                // Check ordering - must be ascending to prevent signature reuse
                if (currentOwner <= lastOwner) {
                    return false; // Signatures not in ascending order
                }
                
                validSignatures++;
                lastOwner = currentOwner;
            }
        }

        // All signatures must be valid and from distinct owners
        return validSignatures == threshold;
    }

    /// @notice Checks if an address is in the owners array
    /// @dev Helper function for signature verification
    /// @param addr Address to check
    /// @param owners Array of owner addresses
    /// @return True if the address is an owner
    function _isOwner(address addr, address[] memory owners) private pure returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == addr) {
                return true;
            }
        }
        return false;
    }
}