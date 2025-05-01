// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GasBenchmarkingSignatureStorage {
    bytes32 public leafHash;
    uint256 public constant SIGNATURE_IDENTIFIER_MOCK = uint256(123);
    bytes32 internal constant SIGNATURE_KEY_STORAGE = keccak256("transient.signature.bytes.mapping");
    
    error INVALID_PROOF();

    constructor(bytes32 leafHashSimulation) {
        leafHash = leafHashSimulation;
    }

    struct SignatureData {
        uint48 validUntil;
        bytes32 merkleRoot;
        bytes32[] proof;
        bytes signature;
    }

    function validateAndExecute(PackedUserOperation calldata userOp, bytes32) external {
        (uint48 validUntil, bytes32 merkleRoot, bytes32[] memory proof, bytes memory signature) =
            abi.decode(userOp.signature, (uint48, bytes32, bytes32[], bytes));
        SignatureData memory sigData = SignatureData(validUntil, merkleRoot, proof, signature);
        _processSignatureAndVerifyLeaf(sigData);
        _store(SIGNATURE_IDENTIFIER_MOCK, userOp.signature);
    }

    function loadSignature() external view returns (bytes memory) {
        return _load(SIGNATURE_IDENTIFIER_MOCK);
    }


    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData
    )
        private
        view
        returns (address signer, bytes32 leaf)
    {
        leaf = _createLeaf(sigData.validUntil);
        if (!MerkleProof.verify(sigData.proof, sigData.merkleRoot, leaf)) revert INVALID_PROOF();
        // Get signer
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    function _createLeaf(uint48 validUntil) private view returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(leafHash, validUntil))));
    }

    function _createMessageHash(bytes32 merkleRoot) internal pure returns (bytes32) {
        return keccak256(abi.encode("GasBenchmarkingSignatureStorage", merkleRoot));
    }


    // ---- SIGNATURE STORAGE ----

    function _makeKey(uint256 identifier) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(SIGNATURE_KEY_STORAGE, identifier));
    }

    function _store(uint256 identifier, bytes calldata data) private {
        bytes32 storageKey = _makeKey(identifier);
        uint256 len = data.length;

        assembly {
            tstore(storageKey, len)
        }

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := calldataload(add(data.offset, i))
                tstore(add(storageKey, div(add(i, 32), 32)), word)
            }
        }
    }

    function _load(uint256 identifier) private view returns (bytes memory out) {
        bytes32 storageKey = _makeKey(identifier);
        uint256 len;
        assembly {
            len := tload(storageKey)
        }

        out = new bytes(len);

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := tload(add(storageKey, div(add(i, 32), 32)))
            }

            assembly {
                mstore(add(add(out, 0x20), i), word)
            }
        }
    }
}