// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ISuperProofVerifier } from "../interfaces/ISuperProofVerifier.sol";

/// @title MerkleProofVerifier
/// @author Superform Labs
/// @notice Implementation of Merkle tree proof verification
contract MerkleProofVerifier is ISuperProofVerifier {
    /// @inheritdoc ISuperProofVerifier
    function verifyProof(
        bytes32 commitment,
        bytes calldata message,
        bytes calldata proof
    ) external pure returns (bool) {
        bytes32 leaf = keccak256(message);
        bytes32[] memory proofArray = abi.decode(proof, (bytes32[]));
        return MerkleProof.verify(proofArray, commitment, leaf);
    }
    
    /// @inheritdoc ISuperProofVerifier
    function batchVerifyProofs(
        bytes32[] calldata commitments,
        bytes[] calldata messages,
        bytes[] calldata proofs
    ) external pure returns (uint256 validProofs) {
        uint256 length = commitments.length;
        if (length != messages.length || length != proofs.length) revert("Array length mismatch");
        
        validProofs = 0;
        
        for (uint256 i = 0; i < length; i++) {
            bytes32 leaf = keccak256(messages[i]);
            bytes32[] memory proofArray = abi.decode(proofs[i], (bytes32[]));
            
            if (MerkleProof.verify(proofArray, commitments[i], leaf)) {
                // Set the i-th bit if valid
                validProofs |= (1 << i);
            }
        }
        
        return validProofs;
    }
    
    /// @inheritdoc ISuperProofVerifier
    function proofTypeId() external pure returns (bytes32) {
        return keccak256("MERKLE_PROOF");
    }
}