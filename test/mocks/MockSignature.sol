// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MockSignature {
    // a mock example of an operation
    struct Execution {
        address to;
        uint256 value;
        bytes data;
    }

    bytes32 public merkleRoot;
    bytes32[] public proofs;
    uint256 public nonce;

    string public constant DOMAIN_NAMESPACE = "MockSignature";

    // setters
    function setMerkleRoot(bytes32 _merkleRoot) external {
        merkleRoot = _merkleRoot;
    }

    function setProofs(bytes32[] calldata _proofs) external {
        proofs = _proofs;
    }

    function incrementNonce() external {
        nonce++;
    }

    // view
    function validateSignature(address smartAccount, Execution[] calldata executions, bytes calldata signature)
        external
        view
        returns (bool)
    {
        bytes32 messageHash =
            keccak256(abi.encode(DOMAIN_NAMESPACE, merkleRoot, proofs, smartAccount, nonce, executions));

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (address recoveredSigner, bool valid) = _recoverSigner(ethSignedMessageHash, signature);

        return valid && recoveredSigner == smartAccount;
    }

    function isOperationValid(address account, Execution calldata execution) public view returns (bool) {
        bytes32 leaf =
            keccak256(bytes.concat(keccak256(abi.encode(account, execution.to, execution.value, execution.data))));
        return MerkleProof.verify(proofs, merkleRoot, leaf);
    }

    // private
    function _recoverSigner(bytes32 hash, bytes memory signature) private pure returns (address, bool) {
        if (signature.length != 65) {
            return (address(0), false);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return (address(0), false);
        }

        address signer = ecrecover(hash, v, r, s);
        return (signer, signer != address(0));
    }
}
