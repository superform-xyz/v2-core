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
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct UserOpData {
        address sender;
        uint256 nonce;
        bytes callData;
        bytes initCode;
        bytes32 gasFees;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes paymasterAndData;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validate a user operation
    /// @param _userOp The user operation to validate
    function validateUserOp(
        PackedUserOperation calldata _userOp,
        bytes32
    )
        external
        view
        override
        returns (ValidationData)
    {
        if (!_initialized[_userOp.sender]) revert NOT_INITIALIZED();

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);
        UserOpData memory userOpData = UserOpData({
            sender: _userOp.sender,
            nonce: _userOp.nonce,
            callData: _userOp.callData,
            initCode: _userOp.initCode,
            gasFees: _userOp.gasFees,
            accountGasLimits: _userOp.accountGasLimits,
            preVerificationGas: _userOp.preVerificationGas,
            paymasterAndData: _userOp.paymasterAndData
        });

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, userOpData);

        // Validate
        bool isValid =
            _isSignatureValid(signer, userOpData.sender, sigData.validUntil);

        return _packValidationData(!isValid, sigData.validUntil, 0);
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(
        address sender,
        bytes32,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        if (!_initialized[sender]) revert NOT_INITIALIZED();

        // Decode data
        (SignatureData memory sigData, UserOpData memory userOpData) = _decodeSignatureAndUserOpData(data, sender);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, userOpData);

        // Validate
        bool isValid = _isSignatureValid(signer, sender, sigData.validUntil);

        return isValid ? bytes4(0x1626ba7e) : bytes4("");
    }

    /// @notice Validate a signature with data
    function validateSignatureWithData(
        bytes32,
        bytes calldata sigDataRaw,
        bytes calldata userOpDataRaw
    )
        external
        view
        virtual
        returns (bool validSig)
    {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();

        // Decode signature and user operation data
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);
        UserOpData memory userOpData = _decodeUserOpData(userOpDataRaw, msg.sender);

        // Process signature
        (address signer, ) = _processSignatureAndVerifyLeaf(sigData, userOpData);

        return _isSignatureValid(signer, msg.sender, sigData.validUntil);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperMerkleValidator-v0.0.1";
    }

    function _createLeaf(bytes memory data, uint48 validUntil) internal view override returns (bytes32) {
        UserOpData memory userOpData = abi.decode(data, (UserOpData));
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        userOpData.callData,
                        userOpData.gasFees,
                        userOpData.sender,
                        userOpData.nonce,
                        validUntil,
                        block.chainid,
                        userOpData.initCode,
                        userOpData.accountGasLimits,
                        userOpData.preVerificationGas,
                        userOpData.paymasterAndData
                    )
                )
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData,
        UserOpData memory userOpData
    )
        private
        view
        returns (address signer, bytes32 leaf)
    {

        leaf = _createLeaf(abi.encode(userOpData), sigData.validUntil);
        if (!MerkleProof.verify(sigData.proof, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Get signer
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    function _decodeUserOpData(bytes memory userOpDataRaw, address sender) private pure returns (UserOpData memory) {
        (uint256 nonce, bytes memory callData, bytes32 gasFees, bytes memory initCode, bytes32 accountGasLimits, uint256 preVerificationGas, bytes memory paymasterAndData) =
            abi.decode(userOpDataRaw, (uint256, bytes, bytes32, bytes, bytes32, uint256, bytes));
        return UserOpData(sender, nonce, callData, initCode, gasFees, accountGasLimits, preVerificationGas, paymasterAndData);
    }

    function _decodeSignatureAndUserOpData(
        bytes memory data,
        address sender
    )
        private
        pure
        returns (SignatureData memory, UserOpData memory)
    {
        (bytes memory sigDataRaw, bytes memory userOpDataRaw) = abi.decode(data, (bytes, bytes));
        return (_decodeSignatureData(sigDataRaw), _decodeUserOpData(userOpDataRaw, sender));
    }
}
