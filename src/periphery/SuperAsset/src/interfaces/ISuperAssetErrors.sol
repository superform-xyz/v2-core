// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISuperAssetErrors
 * @notice Interface defining all custom errors used by the SuperAsset contract
 */
interface ISuperAssetErrors {
    /// @notice Thrown when an address parameter is zero
    error ZeroAddress();

    /// @notice Thrown when token is not in the ERC20 whitelist
    error NotERC20Token();

    /// @notice Thrown when a token is not supported (neither vault nor ERC20)
    error NotSupportedToken();

    /// @notice Thrown when vault is not in the vault whitelist
    error NotVault();

    /// @notice Thrown when vault is already whitelisted
    error AlreadyWhitelisted();

    /// @notice Thrown when vault or token is not whitelisted
    error NotWhitelisted();

    /// @notice Thrown when swap fee percentage is too high
    error InvalidSwapFeePercentage();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when insufficient balance for operation
    error InsufficientBalance();

    /// @notice Thrown when insufficient allowance for transfer
    error InsufficientAllowance();

    /// @notice Thrown when slippage tolerance is exceeded
    error SlippageProtection();

    /// @notice Thrown when oracle price is invalid
    error InvalidOraclePrice();

    /// @notice Thrown when allocation is invalid
    error InvalidAllocation();

    /// @notice Thrown when the contract is paused
    error ContractPaused();

    /// @notice Thrown when emergency price is not set
    error EmergencyPriceNotSet();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when operation would result in invalid state
    error InvalidOperation();

    /// @notice Thrown when incentive calculation fails
    error IncentiveCalculationFailed();

    /// @notice Thrown when input arrays have mismatched lengths in batch operations
    error InvalidInput();

    /// @notice Thrown when the sum of all allocations exceeds 100% (PRECISION)
    error InvalidTotalAllocation();

}
