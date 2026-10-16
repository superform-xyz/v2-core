// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMorphoMarketPosition
/// @notice All three raw legs of one Morpho Blue market for an owner, resolved from its market key.
/// @dev Morpho Blue markets are ISOLATED: `position(id, owner)` is specific to a single market, so a leg is
///      never shared across markets and the legs are NEVER netted here. Lending and debt are denominated in
///      the market's `loanToken`; collateral in its `collateralToken` (which may be `address(0)` for a
///      lending-only market). This oracle has no price feed, so the legs are returned side by side for the
///      caller to price, classify and net. Values stay in raw token units.
interface IMorphoMarketPosition {
    /// @param morpho The Morpho Blue singleton holding the market
    /// @param marketId The full Morpho market id (keccak of the market params)
    /// @param loanToken The lending/debt token
    /// @param collateralToken The collateral token (`address(0)` for lending-only markets)
    /// @param loanDecimals Decimals of `loanToken`
    /// @param collateralDecimals Decimals of `collateralToken` (0 when `collateralToken` is `address(0)`)
    /// @param suppliedAssets Owner's accrued supplied assets, loanToken units, rounded DOWN (conservative asset)
    /// @param collateral Owner's posted collateral, collateralToken units, raw
    /// @param debtAssets Owner's accrued borrow assets, loanToken units, rounded UP (conservative liability)
    /// @param supplyShares Owner's raw supply shares (diagnostics; the asset figure is `suppliedAssets`)
    /// @param borrowShares Owner's raw borrow shares (diagnostics; the asset figure is `debtAssets`)
    struct MarketPosition {
        address morpho;
        bytes32 marketId;
        address loanToken;
        address collateralToken;
        uint8 loanDecimals;
        uint8 collateralDecimals;
        uint256 suppliedAssets;
        uint256 collateral;
        uint256 debtAssets;
        uint256 supplyShares;
        uint256 borrowShares;
    }

    /// @notice Resolve a registered market key into all three of its raw legs for `owner`
    /// @dev Reverts `MARKET_NOT_REGISTERED` for an unregistered key (no fallback, no zero substitution) and
    ///      `ZERO_ADDRESS` for a zero owner. Zero lending shares never suppress collateral or debt: the
    ///      three legs are read independently from one `position(id, owner)` call, then supply/debt are
    ///      interest-accrued to `block.timestamp`.
    /// @param marketKey The registered market key (pseudo-address) in the MorphoBlueMarketRegistry
    /// @param owner The account whose position is read
    /// @return position All three legs plus the market binding and decimals needed to price them
    function getMarketPosition(address marketKey, address owner) external view returns (MarketPosition memory position);
}
