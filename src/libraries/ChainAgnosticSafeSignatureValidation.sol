// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { ISafeConfiguration } from "../vendor/gnosis/ISafeConfiguration.sol";
import { CheckSignatures } from "rhinestone/checknsignatures/src/CheckNSignatures.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

// Superform
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

library ChainAgnosticSafeSignatureValidation {
    using LibSort for address[];

    /// @notice Chain-agnostic domain separator type hash
    /// @dev Uses a fixed domain without chainId for cross-chain compatibility
    /// @notice verifyingContract is the safe smart account address
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    /// @notice Fixed chain ID for cross-chain signature 1271 compatibility
    uint256 private constant FIXED_CHAIN_ID = 1;
    /// @notice Domain name and version for cross-chain 1271 signatures
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";

    function validateChainAgnosticMultisig(
        address safe,
        ISuperValidator.SignatureData memory sigData,
        bytes32 rawHash
    )
        internal
        view
        returns (bool)
    {
        // Try to get Safe configuration - if it fails, this is not a Safe multisig
        address[] memory owners;
        uint256 threshold;

        try ISafeConfiguration(safe).getOwners() returns (address[] memory _owners) {
            owners = _owners;
        } catch {
            // Not a Safe multisig, return false to continue with fallback EIP-1271 validation
            return false;
        }

        try ISafeConfiguration(safe).getThreshold() returns (uint256 _threshold) {
            threshold = _threshold;
        } catch {
            // Not a Safe multisig, return false to continue with fallback EIP-1271 validation
            return false;
        }

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

        // Recover signers using CheckSignatures library (supports ECDSA, eth_sign, and contract signatures)
        (uint256 validSigCount, address[] memory recoveredSigners) =
            recoverNSignatures(chainAgnosticHash, sigData.signature, threshold);

        /// @dev this is the main check coming from above
        if (validSigCount < threshold) return false;

        // Sort recovered signers for efficient comparison
        recoveredSigners.insertionSort();

        // sorting owners here instead of requiring sorted list for improved UX
        owners.insertionSort();
        owners.uniquifySorted();

        // Count valid signatures from owners using searchSorted
        uint256 validOwnerSignatures = 0;
        uint256 ownersLength = owners.length;

        for (uint256 i; i < ownersLength; i++) {
            (bool found,) = recoveredSigners.searchSorted(owners[i]);
            if (found) {
                validOwnerSignatures++;
                if (validOwnerSignatures >= threshold) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Recover n signatures from a data hash
     *
     * Adapted from rhinestone/checknsignatures/src/CheckNSignatures.sol to return instead of reverting
     * @param dataHash The hash of the data
     * @param signatures The concatenated signatures
     * @param requiredSignatures The number of signatures required
     *
     * @return validSigCount The number of valid signatures
     * @return recoveredSigners The recovered signers
     */
    function recoverNSignatures(
        bytes32 dataHash,
        bytes memory signatures,
        uint256 requiredSignatures
    )
        internal
        view
        returns (uint256 validSigCount, address[] memory recoveredSigners)
    {
        uint256 signaturesLength = signatures.length;
        uint256 totalSignatures = signaturesLength / 65;
        recoveredSigners = new address[](totalSignatures);
        /// @dev adapted
        if (totalSignatures < requiredSignatures) return (0, recoveredSigners);
        for (uint256 i; i < totalSignatures; i++) {
            // split v,r,s from signatures
            address _signer;
            (uint8 v, bytes32 r, bytes32 s) = CheckSignatures.signatureSplit({ signatures: signatures, pos: i });

            if (v == 0) {
                // If v is 0 then it is a contract signature
                _signer = CheckSignatures.isValidContractSignature(dataHash, signatures, r, s, signaturesLength);
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the
                // Ethereum message prefix before applying ecrecover
                _signer = ECDSA.tryRecover({ hash: ECDSA.toEthSignedMessageHash(dataHash), v: v - 4, r: r, s: s });
            } else {
                _signer = ECDSA.tryRecover({ hash: dataHash, v: v, r: r, s: s });
            }
            if (_signer != address(0)) {
                validSigCount++;
            }
            recoveredSigners[i] = _signer;
        }
        /// @dev adapted (check removed)
    }
}
