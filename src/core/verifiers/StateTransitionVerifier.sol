// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ISuperStateVerifier } from "../interfaces/ISuperStateVerifier.sol";

/// @title StateTransitionVerifier
/// @author Superform Labs
/// @notice Implementation of state transition verification using Merkle proofs
/// @dev This implementation uses Merkle proofs to verify state transitions
contract StateTransitionVerifier is ISuperStateVerifier {
    /// @inheritdoc ISuperStateVerifier
    function verifyStateTransition(
        bytes calldata initialState,
        bytes calldata finalState,
        bytes calldata executionData,
        bytes calldata proof
    ) external pure returns (bool isValid) {
        // Step 1: Hash all inputs to create the expected leaf
        bytes32 transitionHash = keccak256(abi.encode(
            initialState,
            finalState,
            executionData
        ));
        
        // Step 2: Decode the Merkle proof
        (bytes32 root, bytes32[] memory merkleProof) = abi.decode(proof, (bytes32, bytes32[]));
        
        // Step 3: Verify the Merkle proof against the leaf
        if (!MerkleProof.verify(merkleProof, root, transitionHash)) {
            return false;
        }
        
        return true;
    }
    
    /// @inheritdoc ISuperStateProver
    function proverTypeId() external pure returns (bytes32) {
        return keccak256("STATE_TRANSITION_PROVER");
    }
}
