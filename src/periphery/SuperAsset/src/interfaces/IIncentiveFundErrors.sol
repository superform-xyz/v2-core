// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IIncentiveFundErrors
 * @notice Interface defining all custom errors used by the IncentiveFund contract
 */
interface IIncentiveFundErrors {
    /// @notice Thrown when an address parameter is zero
    error ZERO_ADDRESS();

    /// @notice Thrown when amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when incentive token is not configured
    error TOKEN_NOT_CONFIGURED();

    /// @notice Thrown when any circuit breaker is triggered during price check
    error CIRCUIT_BREAKER_TRIGGERED();
}
