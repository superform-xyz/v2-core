// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../../BaseTest.t.sol";

contract GasBenchmarkingSignatureHelper is BaseTest {
    function _createMerkleTree(bytes32 opHash, uint256 timestamp, string memory namespace, address signer, uint256 signerPrivateKey) internal pure returns (bytes memory signatureData, bytes32[][] memory merkleProof, bytes32 merkleRoot) {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(opHash, uint48(timestamp));
        (merkleProof, merkleRoot) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _createSignature(
            namespace,
            merkleRoot,
            signer,
            signerPrivateKey
        );
        signatureData =
            _createSignatureData_AcrossTargetExecutor(uint48(timestamp), merkleRoot, merkleProof[0], merkleProof[0], signature);

        return (signatureData, merkleProof, merkleRoot);
    }   
}