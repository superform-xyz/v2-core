// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IEVC
/// @notice Minimal interface for the Ethereum Vault Connector used by Euler EVK vaults
/// @dev Only includes the functions needed by Superform hooks. The canonical EVC is
///      GPL-2.0-licensed; this minimal interface avoids license conflict.
///      msg.sender rules: an account is the owner of its own 19-byte address prefix; calling
///      enableCollateral / enableController / disableCollateral with `account == msg.sender`
///      self-authenticates. Superform hooks always use the plain executing account (subaccount 0)
///      and never pass subaccount, operator, or alternate-owner identities.
///      NOTE: `EVC.disableController(address account)` is intentionally OMITTED from this
///      interface — only the controller vault itself may call it. Disabling a controller must go
///      through the vault's own `IEVault.disableController()` path.
interface IEVC {
    /// @notice Returns an array of collaterals enabled for an account
    /// @param account The address of the account
    /// @return An array of addresses of the enabled collaterals
    function getCollaterals(address account) external view returns (address[] memory);

    /// @notice Returns whether a collateral is enabled for an account
    /// @param account The address of the account
    /// @param vault The address of the collateral vault
    /// @return True if the collateral is enabled
    function isCollateralEnabled(address account, address vault) external view returns (bool);

    /// @notice Enables a collateral for an account
    /// @dev Owner/operator only; enabling a duplicate is a no-op; at most 10 collaterals
    /// @param account The account for which the collateral is enabled
    /// @param vault The address of the collateral vault
    function enableCollateral(address account, address vault) external payable;

    /// @notice Disables a collateral for an account
    /// @dev Owner/operator only; runs the account status check
    /// @param account The account for which the collateral is disabled
    /// @param vault The address of the collateral vault
    function disableCollateral(address account, address vault) external payable;

    /// @notice Returns an array of controllers enabled for an account
    /// @dev At most one controller may remain enabled when an account status check settles
    /// @param account The address of the account
    /// @return An array of addresses of the enabled controllers
    function getControllers(address account) external view returns (address[] memory);

    /// @notice Returns whether a controller is enabled for an account
    /// @param account The address of the account
    /// @param vault The address of the controller vault
    /// @return True if the controller is enabled
    function isControllerEnabled(address account, address vault) external view returns (bool);

    /// @notice Enables a controller for an account
    /// @dev Owner/operator only; enabling a duplicate is a no-op
    /// @param account The account for which the controller is enabled
    /// @param vault The address of the controller vault
    function enableController(address account, address vault) external payable;
}
