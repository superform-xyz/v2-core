// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4MarketPosition
/// @notice Both raw legs of one Aave V4 market pair, resolved from its market key (SUP-21255).
/// @dev WHY THIS IS NOT PART OF `IYieldSourceOracle`: that surface returns ONE `uint256` in ONE asset per
///      key, and `SuperYieldSourceOracle` adds those numbers. A market's two legs are denominated in
///      different tokens with different decimals (on Base MAG7: an 8-decimal equity against 6-decimal
///      USDC) and this oracle has no price feed, so the legs cannot share that return value. They are
///      returned here instead, side by side and NEVER netted — pricing and netting stay with the caller.
interface IAaveV4MarketPosition {
    /// @param spoke The Aave V4 spoke holding both reserves
    /// @param supplyReserveId The collateral reserve id
    /// @param borrowReserveId The loan reserve id
    /// @param collateralToken The collateral reserve's underlying
    /// @param loanToken The loan reserve's underlying
    /// @param collateralDecimals Decimals of `collateralToken`
    /// @param loanDecimals Decimals of `loanToken`
    /// @param suppliedAssets Owner's accrued supplied assets on the collateral reserve, raw units
    /// @param debtAssets Owner's total debt on the loan reserve (drawn + premium), raw units
    struct MarketPosition {
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        address collateralToken;
        address loanToken;
        uint8 collateralDecimals;
        uint8 loanDecimals;
        uint256 suppliedAssets;
        uint256 debtAssets;
    }

    /// @notice Resolve a registered market key into both of its raw legs
    /// @dev Reverts `MARKET_NOT_REGISTERED` for an unregistered key AND for a reserve key — a loan pair has
    ///      exactly one yield source, its market key, and there is no fallback from one namespace to the
    ///      other in either direction.
    ///      SHARED DEBT: `debtAssets` is the owner's ENTIRE debt on that borrow reserve. Aave V4 has no
    ///      per-market debt, so a portfolio listing several markets that share a borrow reserve must
    ///      subtract that `(spoke, borrowReserveId)` debt ONCE. Independent per-market reads are therefore
    ///      NOT a portfolio valuation path — use the batched owner snapshot, which de-duplicates legs.
    /// @param marketKey The pseudo-address of a registered market
    /// @param owner The account whose position is read
    /// @return position Both legs plus the binding and decimals needed to price them
    function getMarketPosition(address marketKey, address owner) external view returns (MarketPosition memory position);
}
