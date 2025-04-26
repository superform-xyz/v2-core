// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SuperValidatorBase } from "./SuperValidatorBase.sol";

/// @title SuperMerkleValidator
/// @author Superform Labs
/// @notice A userOp validator contract with abstracted proof and signature verification
contract SuperMerkleValidator is SuperValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);
    
    // Immutable verifiers for this validator instance
    address public immutable proofVerifier;
    address public immutable signatureVerifier;
    
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _proofVerifier, address _signatureVerifier) {
        if (_proofVerifier == address(0) || _signatureVerifier == address(0)) 
            revert ZERO_ADDRESS();
            
        proofVerifier = _proofVerifier;
        signatureVerifier = _signatureVerifier;
    }

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
        ProofData memory proofData = _decodeProofData(_userOp.signature);

        // Verify proof
        bool isProofValid = _verifyProof(
            proofVerifier,
            proofData.commitment,
            abi.encode(_userOpHash),
            proofData.proof
        );
        if (!isProofValid) revert INVALID_PROOF();

        // Get signer from signature
        address signer = _recoverSigner(
            signatureVerifier,
            _createMessageHash(proofData.commitment),
            proofData.signature
        );

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, proofData.validUntil);

        return _packValidationData(!isValid, proofData.validUntil, 0);
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
        ProofData memory proofData = _decodeProofData(sigDataRaw);

        // Verify proof
        bool isProofValid = _verifyProof(
            proofVerifier,
            proofData.commitment,
            abi.encode(dataHash),
            proofData.proof
        );
        if (!isProofValid) revert INVALID_PROOF();

        // Get signer from signature
        address signer = _recoverSigner(
            signatureVerifier,
            _createMessageHash(proofData.commitment),
            proofData.signature
        );

        // Validate
        bool isValid = _isSignatureValid(signer, msg.sender, proofData.validUntil);

        return isValid ? VALID_SIGNATURE : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperMerkleValidator-v0.0.1";
    }
}