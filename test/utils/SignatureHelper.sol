// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract SignatureHelper is Test {
    function _createSignature(
        string memory hashNamespace,
        bytes32 merkleRoot,
        address signer,
        uint256 signerPrivateKey
    )
        internal
        pure
        returns (bytes memory signature)
    {
        if (signer == address(0) || signerPrivateKey == 0) revert("signer not set");

        bytes32 messageHash = keccak256(abi.encode(hashNamespace, merkleRoot));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        // test sig here; fail early if invalid
        address _expectedSigner = ECDSA.recover(ethSignedMessageHash, signature);
        assertEq(_expectedSigner, signer, "Signature should be valid");
    }
}
