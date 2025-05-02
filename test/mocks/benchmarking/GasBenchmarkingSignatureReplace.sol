// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GasBenchmarkingSignatureReplace {
    bytes32 public leafHash;
        
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

    struct Info {
        uint256 hookIndex;
        uint128 startBytes;
        uint128 endBytes;
    }

    function validateAndExecute(PackedUserOperation calldata userOp, bytes32) external view {
        (uint48 validUntil, bytes32 merkleRoot, bytes32[] memory proof, bytes memory signature) =
            abi.decode(userOp.signature, (uint48, bytes32, bytes32[], bytes));
        SignatureData memory sigData = SignatureData(validUntil, merkleRoot, proof, signature);
        _processSignatureAndVerifyLeaf(sigData);

        bytes memory executorCalldata;
        // simulate executor flow1
        // extract executor entry data + the other fields to replace calldata with 
        {
            // get the replace info
            (Info[] memory infos, bytes memory sigDataRaw) = _extractExtraCalldata(userOp.callData);
            
            // we need to copy it in memory as calldata is immutable
            bytes memory modifiable = userOp.callData;

            // replace the modifiable with signature
            for (uint256 i; i < infos.length; i++) {
                uint256 start = uint256(infos[i].startBytes);
                uint256 end = uint256(infos[i].endBytes);
                uint256 length = end - start;

                assembly {
                    let modifiablePtr := add(modifiable, 32)
                    let signaturePtr := add(sigDataRaw, 32)

                    // source pointer = offset in sigDataRaw
                    let src := add(signaturePtr, start)
                    // destination pointer = offset in modifiable
                    let dst := add(modifiablePtr, start)

                    for { let j := 0 } lt(j, length) { j := add(j, 32) } {
                        mstore(add(dst, j), mload(add(src, j)))
                    }
                }
            }

            // get updated executor data
            executorCalldata = _sliceExecutorCalldata(modifiable);
        }
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
        return keccak256(abi.encode("GasBenchmarkingSignatureReplace", merkleRoot));
    }

    function _extractExtraCalldata(bytes calldata data) internal pure returns (Info[] memory, bytes calldata) {
        uint256 infoLen;
        uint256 sigLen;
        uint256 totalLen = data.length;

        assembly {
            infoLen := calldataload(sub(add(data.offset, totalLen), 64))
            sigLen := calldataload(sub(add(data.offset, totalLen), 32))
        }

        uint256 executorCalldataCut = totalLen - infoLen - sigLen - 64;
        uint256 infoCount = infoLen / 64; // 64 = 32 + 16 + 16 
        Info[] memory infos = new Info[](infoCount);
        for (uint256 i; i < infoCount; ++i) {
            uint256 base = executorCalldataCut + i * 64;

            Info memory info;

            assembly {
                // Read hookIndex (32 bytes)
                mstore(info, calldataload(add(data.offset, base)))

                // Read startBytes (16 bytes of lower half)
                let startWord := calldataload(add(data.offset, add(base, 32)))
                mstore(add(info, 32), and(startWord, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))

                // Read endBytes (16 bytes of lower half)
                let endWord := calldataload(add(data.offset, add(base, 48)))
                mstore(add(info, 48), and(endWord, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            }

            infos[i] = info;
        }

        uint256 sigStart = executorCalldataCut + infoLen;
        return (infos, data[sigStart:sigStart + sigLen]);
    }

    function _sliceExecutorCalldata(bytes memory data) public pure returns (bytes memory result) {
        assembly {
            let len := mload(data)
            let dataStart := add(data, 32)

            let infoLen := mload(sub(add(dataStart, len), 64))
            let sigLen := mload(sub(add(dataStart, len), 32))
            let cut := sub(sub(len, infoLen), add(sigLen, 64))

            result := mload(0x40)
            mstore(result, cut)

            let dest := add(result, 32)
            let src := dataStart
            let end := add(src, cut)

            for { } lt(src, end) { src := add(src, 32) dest := add(dest, 32) } {
                mstore(dest, mload(src))
            }

            mstore(0x40, and(add(dest, 31), not(31)))
        }
    }
}