// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperValidator
/// @author Superform Labs
interface ISuperValidator {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the sender account has not been initialized
    error INVALID_SENDER();
    error NOT_INITIALIZED();
    error NOT_IMPLEMENTED();
    error PROOF_NOT_FOUND();
    error INVALID_CHAIN_ID();
}
