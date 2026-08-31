// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IEVault
/// @notice Minimal interface for Euler Vault Kit (EVK) vaults
/// @dev Only includes the functions needed by Superform hooks. The canonical EVK is
///      GPL-2.0-licensed; this minimal interface avoids license conflict.
///      Call-through semantics: every state-changing function below (except disableController)
///      carries EVK's `callThroughEVC` modifier — when the caller is not the EVC, the vault
///      re-routes itself through `evc.call`, making each direct call its own checks-deferred
///      context whose account/vault status checks run at the end of that call. Superform hooks
///      therefore call vault functions DIRECTLY from the smart account; no `evc.call` wrapping.
///      Interest accrual is timestamp-based and every view below virtually accrues, so within one
///      transaction `debtOf`, `previewWithdraw`, `maxDeposit` and `cash` are stable.
interface IEVault {
    /// @notice The vault's underlying asset
    /// @return The address of the underlying asset
    function asset() external view returns (address);

    /// @notice The EVC this vault is attached to
    /// @return The address of the EVC
    function EVC() external view returns (address);

    /// @notice Balance of a particular account, in vault shares
    /// @param account The address of the account
    /// @return The account's share balance
    function balanceOf(address account) external view returns (uint256);

    /// @notice Maximum amount of underlying assets the account can deposit
    /// @dev Supply-cap-limited; returns 0 when the deposit operation is disabled/paused
    /// @param account The address of the depositing account
    /// @return The maximum depositable amount of underlying assets
    function maxDeposit(address account) external view returns (uint256);

    /// @notice Amount of vault shares that would be burned to withdraw an asset amount
    /// @param assets The amount of underlying assets to withdraw
    /// @return The amount of shares that would be burned
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Deposits underlying assets into the vault
    /// @dev Pulls `amount` assets from the caller (prior approval required)
    /// @param amount The amount of underlying assets to deposit
    /// @param receiver The account to receive the minted shares
    /// @return The amount of shares minted
    function deposit(uint256 amount, address receiver) external returns (uint256);

    /// @notice Withdraws underlying assets from the vault
    /// @dev Burns shares from `owner`, sends exactly `amount` assets to `receiver`; the account
    ///      status (health) check runs at the end of the call
    /// @param amount The amount of underlying assets to withdraw
    /// @param receiver The account to receive the assets
    /// @param owner The account whose shares are burned
    /// @return The amount of shares burned
    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256);

    /// @notice Balance of underlying assets held directly by the vault (available liquidity)
    /// @return The amount of underlying assets held by the vault
    function cash() external view returns (uint256);

    /// @notice Debt owed by an account, in underlying asset units
    /// @dev Virtually accrued to the current timestamp and ROUNDED UP; repaying exactly this
    ///      amount clears the debt (EVK forgives sub-asset dust)
    function debtOf(address account) external view returns (uint256);

    /// @notice Borrows underlying assets from the vault
    /// @dev Requires this vault to be the account's enabled controller (E_ControllerDisabled
    ///      otherwise); reverts E_InsufficientCash when amount exceeds cash; the account health
    ///      check (collateral value at LTVBorrow vs liability) runs at the end of the call
    /// @param amount The amount of underlying assets to borrow
    /// @param receiver The account to receive the borrowed assets
    /// @return The amount of assets borrowed
    function borrow(uint256 amount, address receiver) external returns (uint256);

    /// @notice Repays debt to the vault
    /// @dev CAUTION: EVK names the second parameter `receiver`, but it is the DEBTOR whose debt is
    ///      reduced (onBehalf semantics). Assets are pulled from the CALLER (prior approval
    ///      required). Repay is controller-neutral: it requires no controller/collateral
    ///      configuration from the caller and runs no health check. EVK accepts a max-uint
    ///      sentinel upstream, but Superform hooks never use it — they pass exact amounts
    ///      resolved as min(cap, debtOf).
    /// @param amount The amount of underlying assets to repay
    /// @param receiver The account whose debt is reduced (the debtor)
    /// @return The amount of assets repaid
    function repay(uint256 amount, address receiver) external returns (uint256);

    /// @notice Borrow LTV of a collateral vault, in 1e4 scale
    /// @param collateral The address of the collateral vault
    function LTVBorrow(address collateral) external view returns (uint16);

    /// @notice Liquidation LTV of a collateral vault, in 1e4 scale
    /// @param collateral The address of the collateral vault
    function LTVLiquidation(address collateral) external view returns (uint16);

    /// @notice Risk-adjusted collateral and liability values for an account
    /// @param account The address of the account
    /// @param liquidation True for liquidation LTVs, false for borrow LTVs
    /// @return collateralValue The risk-adjusted collateral value
    /// @return liabilityValue The liability value
    function accountLiquidity(
        address account,
        bool liquidation
    )
        external
        view
        returns (uint256 collateralValue, uint256 liabilityValue);

    /// @notice Disables this vault as the caller's controller
    /// @dev The ONLY supported controller-disable path: the account calls this directly on the
    ///      controller vault (no callThroughEVC), and the vault invokes `evc.disableController`
    ///      internally. Reverts E_OutstandingDebt while any debt remains.
    function disableController() external;
}
