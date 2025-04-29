// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IIncentiveFundErrors
 * @notice Interface defining all custom errors used by the IncentiveFundContract
 */
interface IIncentiveFundErrors {
    /// @notice Thrown when an address parameter is zero
    error ZERO_ADDRESS();

    /// @notice Thrown when amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when caller is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when token is not properly configured
    error TOKEN_NOT_CONFIGURED();

    /// @notice Thrown when transfer fails
    error TRANSFER_FAILED();

    /// @notice Thrown when insufficient balance for operation
    error INSUFFICIENT_BALANCE();
}
