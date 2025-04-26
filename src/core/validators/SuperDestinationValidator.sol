// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ISuperDestinationValidator } from "../interfaces/ISuperDestinationValidator.sol";
import { SuperValidatorBase } from "./SuperValidatorBase.sol";

/// @title SuperDestinationValidator
/// @author Superform Labs
/// @notice A validator for destination chain operations with abstracted proof verification
contract SuperDestinationValidator is SuperValidatorBase, ISuperDestinationValidator {
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
    function isValidDestinationSignature(
        address account,
        bytes calldata data
    ) external view override returns (bytes4) {
        if (!_initialized[account]) revert NOT_INITIALIZED();
        
        // Decode the data into user signature data and destination data
        (bytes memory userSignatureData, bytes memory destinationData) = abi.decode(data, (bytes, bytes));
        
        // Decode the proof data from user signature data
        ProofData memory proofData = _decodeProofData(userSignatureData);
        
        // Verify proof
        bool isProofValid = _verifyProof(
            proofVerifier,
            proofData.commitment,
            destinationData,
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
        bool isValid = _isSignatureValid(signer, account, proofData.validUntil);
        
        return isValid ? VALID_SIGNATURE : bytes4("");
    }
    
    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperDestinationValidator-v0.0.1";
    }
}