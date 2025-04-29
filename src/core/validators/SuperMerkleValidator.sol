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
    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);

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
        address,
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
        bool isValid = _isSignatureValid(signer, msg.sender, sigData.validUntil);

        return isValid ? VALID_SIGNATURE : bytes4("");
    }

    // this functions extracts the execution callData from the userOp calldata
    function extractExecutionCalldata(bytes memory callData) external pure returns (bytes memory) {
        // Skip the function selector (first 4 bytes)
        bytes memory functionCalldata = new bytes(callData.length - 4);
            for (uint256 i = 0; i < functionCalldata.length; i++) {
                functionCalldata[i] = callData[i + 4];
            }

            // Decode the parameters
            (, bytes memory executionCalldata) = abi.decode(functionCalldata, (bytes32, bytes));

            return executionCalldata;
    }

    // this function extracts the superExecutor calldata from the execution calldata
    function extractSuperExecutorCalldata(bytes calldata userOpCalldata) external pure returns (
        bytes memory superExecutorCalldata
    ) {
        // first extract the executionCallData from the userOp.callData
        bytes memory executionCallData = extractExecutionCalldata(userOpCalldata);

        // first 20 bytes are the superExecutor address
        // next 32 bytes are the value
        // the rest is the calldata
        superExecutorCalldata = executionCallData[52:];
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperMerkleValidator-v0.0.1";
    }

    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        PackedUserOperation memory userOp = abi.decode(data, (PackedUserOperation));
        
        bytes memory superExecutorCalldata = extractSuperExecutorCalldata(userOp.callData);

        // now we need to extract the source hooks and destination hooks and create the leaf using source hooks and (bridging hook - signature)
        uint256 sourceHooksLen = BytesLib.toUint256(data, 0);

        (address bridgingHook, bytes memory bridgingHookData) = abi.decode(data[32: 32 + sourceHooksLen], (address, bytes));

        // assuming signature is placed in last 20 bytes we remove that as it is inserted later
        bytes memory bridgingHooksDataToUse = bridgingHookData[-20: 0]

        return keccak256(bytes.concat(keccak256(abi.encode(superExecutorCalldata[0: 32 + sourceHooksLen], bridgingHook, bridgingHooksDataToUse, validUntil))));
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
