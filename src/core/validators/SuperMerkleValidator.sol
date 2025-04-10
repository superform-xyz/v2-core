// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { SuperValidatorBase } from "./SuperValidatorBase.sol";

/// @title SuperMerkleValidator
/// @author Superform Labs
/// @notice A userOp validator contract
contract SuperMerkleValidator is SuperValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validate a user operation
    /// @param _userOp The user operation to validate
    function validateUserOp(
        PackedUserOperation calldata _userOp,
        bytes32 _userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        if (!_initialized[_userOp.sender]) revert NOT_INITIALIZED();

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, _userOpHash);

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, sigData.validUntil);

        return _packValidationData(!isValid, sigData.validUntil, 0);
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(
        address sender,
        bytes32 dataHash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();

        // Decode data
        bytes memory sigDataRaw = abi.decode(data, (bytes));
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, dataHash);

        // Validate
        bool isValid = _isSignatureValid(signer, sender, sigData.validUntil);

        return isValid ? bytes4(0x1626ba7e) : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperMerkleValidator-v0.0.1";
    }

    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        bytes32 userOpHash = abi.decode(data, (bytes32));
        return keccak256(bytes.concat(keccak256(abi.encode(userOpHash, validUntil))));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData,
        bytes32 userOpHash
    )
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        leaf = _createLeaf(abi.encode(userOpHash), sigData.validUntil);
        if (!MerkleProof.verify(sigData.proof, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Get signer
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }
}
