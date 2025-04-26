// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ISuperSignatureVerifier } from "../interfaces/ISuperSignatureVerifier.sol";

/// @title ECDSASignatureVerifier
/// @author Superform Labs
/// @notice Implementation of ECDSA signature verification
contract ECDSASignatureVerifier is ISuperSignatureVerifier {
    /// @inheritdoc ISuperSignatureVerifier
    function verifySignature(
        address signer,
        bytes32 message,
        bytes calldata signature
    ) external pure returns (bool) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        address recoveredSigner = ECDSA.recover(ethSignedMessageHash, signature);
        return recoveredSigner == signer;
    }
    
    /// @inheritdoc ISuperSignatureVerifier
    function recoverSigner(
        bytes32 message,
        bytes calldata signature
    ) external pure returns (address) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        return ECDSA.recover(ethSignedMessageHash, signature);
    }
    
    /// @inheritdoc ISuperSignatureVerifier
    function signatureTypeId() external pure returns (bytes32) {
        return keccak256("ECDSA_SIGNATURE");
    }
}