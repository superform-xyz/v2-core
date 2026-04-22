// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4Spoke
/// @notice Minimal interface for Aave V4 Spoke contracts
/// @dev Only includes the 4 functions needed by Superform hooks.
///      The actual Aave V4 Spoke is BUSL-licensed; this minimal interface avoids license conflict.
///      Spoke functions are protected by onlyPositionManager(onBehalfOf), but self-calls
///      (msg.sender == onBehalfOf) are allowed without registration.
interface IAaveV4Spoke {
    /// @notice Supply assets to a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to supply
    /// @param onBehalfOf The address that will receive the supply position
    /// @return shares The amount of shares minted
    /// @return fee The fee charged (if any)
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Withdraw assets from a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to withdraw (use type(uint256).max for full withdrawal)
    /// @param onBehalfOf The address that owns the supply position
    /// @return withdrawnAmount The actual amount withdrawn
    /// @return fee The fee charged (if any)
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Borrow assets from a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to borrow
    /// @param onBehalfOf The address that will receive the borrowed assets and incur the debt
    /// @return borrowedAmount The actual amount borrowed
    /// @return fee The fee charged (if any)
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Repay borrowed assets to a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to repay (use type(uint256).max for full repayment)
    /// @param onBehalfOf The address whose debt will be repaid
    /// @return repaidAmount The actual amount repaid
    /// @return fee The fee charged (if any)
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Enable or disable a supplied reserve as collateral
    /// @dev Must be called after supply to enable borrowing against the position.
    ///      Aave V4 does NOT auto-enable collateral on supply (unlike V3).
    ///      Protected by onlyPositionManager(onBehalfOf), but self-calls are allowed.
    /// @param reserveId The reserve identifier within this Spoke
    /// @param useAsCollateral True to enable, false to disable
    /// @param onBehalfOf The address whose collateral setting is being changed
    function setUsingAsCollateral(uint256 reserveId, bool useAsCollateral, address onBehalfOf) external;
}
