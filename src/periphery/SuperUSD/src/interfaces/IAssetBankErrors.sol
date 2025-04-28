// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAssetBankErrors
 * @notice Interface defining all custom errors used by the AssetBank contract
 */
interface IAssetBankErrors {
    /// @notice Thrown when an address parameter is zero
    error ZeroAddress();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when transfer fails
    error TransferFailed();

    /// @notice Thrown when amount is zero
    error ZeroAmount();
}
