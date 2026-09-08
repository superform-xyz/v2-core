// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IEVaultDebt
/// @notice Minimal Euler EVK vault surface used by the debt oracle. Kept separate from the loan
///         hooks' IEVault so the accounting oracle and the hook suite evolve their vendored
///         interfaces independently.
interface IEVaultDebt {
    /// @notice Debt owed by the account in asset units (interest-accrued)
    function debtOf(address account) external view returns (uint256);

    /// @notice Aggregate outstanding borrows of the vault in asset units
    function totalBorrows() external view returns (uint256);

    /// @notice Vault share token decimals
    function decimals() external view returns (uint8);
}
