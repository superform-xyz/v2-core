// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IEVC
/// @notice Minimal Ethereum Vault Connector interface for Superform Euler V2 hooks
/// @dev Only includes functions needed by Euler lending hooks.
///      disableController(address) is NOT included — it is only callable by the controller vault itself.
interface IEVC {
    /// @notice Enable a vault as collateral for an account
    /// @param account The account to enable collateral for
    /// @param vault The vault to enable as collateral
    function enableCollateral(address account, address vault) external;

    /// @notice Enable a vault as controller for an account
    /// @param account The account to enable the controller for
    /// @param vault The vault to enable as controller
    function enableController(address account, address vault) external;

    /// @notice Disable a vault as collateral for an account
    /// @param account The account to disable collateral for
    /// @param vault The vault to disable as collateral
    function disableCollateral(address account, address vault) external;

    /// @notice Get the list of controllers enabled for an account
    /// @param account The account to query
    /// @return The array of controller vault addresses
    function getControllers(address account) external view returns (address[] memory);

    /// @notice Get the list of collateral vaults enabled for an account
    /// @param account The account to query
    /// @return The array of collateral vault addresses
    function getCollaterals(address account) external view returns (address[] memory);

    /// @notice Check if a vault is enabled as collateral for an account
    /// @param account The account to query
    /// @param vault The vault to check
    /// @return True if the vault is enabled as collateral
    function isCollateralEnabled(address account, address vault) external view returns (bool);

    /// @notice Check if a vault is enabled as controller for an account
    /// @param account The account to query
    /// @param vault The vault to check
    /// @return True if the vault is enabled as controller
    function isControllerEnabled(address account, address vault) external view returns (bool);
}
