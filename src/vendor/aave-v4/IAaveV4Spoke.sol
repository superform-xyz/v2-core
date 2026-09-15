// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4Spoke
/// @notice Minimal interface for Aave V4 Spoke contracts
/// @dev Only includes the functions needed by Superform hooks.
///      The actual Aave V4 Spoke is BUSL-licensed; this minimal interface avoids license conflict.
///      Spoke functions are protected by onlyPositionManager(onBehalfOf), but self-calls
///      (msg.sender == onBehalfOf) are allowed without registration.
///      Return-value semantics follow the canonical ISpoke interface: every money function
///      returns (shares, assets) — the share amount first, then the underlying asset amount.
interface IAaveV4Spoke {
    /// @notice Reserve level data (canonical ISpoke.Reserve)
    /// @dev `hub` is declared as `address` (canonically `IHubBase`) and `flags` as `uint8`
    ///      (canonically the wrapped user-defined value type `ReserveFlags`); both encodings are
    ///      ABI-identical for decoding purposes.
    /// @param underlying The address of the underlying asset
    /// @param hub The address of the associated Hub
    /// @param assetId The identifier of the asset in the Hub
    /// @param decimals The number of decimals of the underlying asset
    /// @param collateralRisk The risk associated with a collateral asset, expressed in BPS
    /// @param flags The packed boolean flags of the reserve (a wrapped uint8)
    /// @param dynamicConfigKey The key of the last reserve dynamic config
    struct Reserve {
        address underlying;
        address hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        uint8 flags;
        uint32 dynamicConfigKey;
    }

    /// @notice Supply assets to a reserve
    /// @dev The Spoke pulls the underlying asset from the caller, so prior token approval is required
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to supply
    /// @param onBehalfOf The address that will receive the supply position
    /// @return shares The amount of shares supplied
    /// @return assets The amount of assets supplied
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Withdraw assets from a reserve
    /// @dev Providing an amount greater than the maximum withdrawable value (e.g. type(uint256).max)
    ///      signals a full withdrawal
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to withdraw
    /// @param onBehalfOf The address that owns the supply position
    /// @return shares The amount of shares withdrawn
    /// @return assets The amount of assets withdrawn
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Borrow assets from a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to borrow
    /// @param onBehalfOf The address that will receive the borrowed assets and incur the debt
    /// @return shares The amount of shares borrowed
    /// @return assets The amount of assets borrowed
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Repay borrowed assets to a reserve
    /// @dev The Spoke pulls the underlying asset from the caller, so prior approval is required.
    ///      An amount greater than the outstanding debt (e.g. type(uint256).max) signals a full
    ///      repayment.
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to repay
    /// @param onBehalfOf The address whose debt will be repaid
    /// @return shares The amount of shares repaid
    /// @return assets The amount of assets repaid
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Enable or disable a supplied reserve as collateral
    /// @dev Must be called after supply to enable borrowing against the position.
    ///      Aave V4 does NOT auto-enable collateral on supply (unlike V3).
    ///      Protected by onlyPositionManager(onBehalfOf), but self-calls are allowed.
    /// @param reserveId The reserve identifier within this Spoke
    /// @param useAsCollateral True to enable, false to disable
    /// @param onBehalfOf The address whose collateral setting is being changed
    function setUsingAsCollateral(uint256 reserveId, bool useAsCollateral, address onBehalfOf) external;

    /// @notice Returns the reserve data for a given reserve identifier
    /// @dev Reverts if the reserve is not listed
    /// @param reserveId The identifier of the reserve
    /// @return The reserve data (see Reserve)
    function getReserve(uint256 reserveId) external view returns (Reserve memory);

    /// @notice Returns the debt of a specific user for a given reserve
    /// @dev The total debt of the user is the sum of drawn debt and premium debt
    /// @param reserveId The identifier of the reserve
    /// @param user The address of the user
    /// @return drawnDebt The amount of drawn debt
    /// @return premiumDebt The amount of premium debt
    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

    /// @notice Returns the amount of assets supplied by a specific user for a given reserve
    /// @param reserveId The identifier of the reserve
    /// @param user The address of the user
    /// @return The amount of assets supplied by the user
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Returns the reserve-level aggregate debt for a given reserve
    /// @dev The total reserve debt is the sum of drawn debt and premium debt (the totalBorrows
    ///      analog used by the Superform debt oracle's getTVL)
    /// @param reserveId The identifier of the reserve
    /// @return drawnDebt The aggregate amount of drawn debt
    /// @return premiumDebt The aggregate amount of premium debt
    function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

    /// @notice Returns the reserve-level aggregate supplied assets for a given reserve
    /// @param reserveId The identifier of the reserve
    /// @return The total amount of assets supplied to the reserve
    function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);
}
