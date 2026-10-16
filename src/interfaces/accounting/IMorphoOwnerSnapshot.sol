// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMorphoOwnerSnapshot
/// @notice Complete raw Morpho Blue accounting inputs for an owner across a supplied set of market keys.
/// @dev THE INPUT IS MARKET IDENTITY, THE OUTPUT IS ACCOUNTING IDENTITY: a strategy's yield-source list
///      holds the market keys the V2 loan hooks name; this call resolves each through the registry and
///      expands it into its economic legs — lending, collateral and debt — so the caller never registers
///      accounting legs itself. Values stay in raw token units; the caller normalizes, classifies and nets.
///
///      ISOLATION, NOT DE-DUPLICATION: unlike Aave V4 (reserve-granular, so one reserve is shared by many
///      markets), Morpho Blue markets are isolated. Each market id has its own `(supplyShares, borrowShares,
///      collateral)` for an owner, so legs are NEVER merged across markets — two markets that happen to use
///      the same loan token keep DISTINCT debt legs. The only de-duplication is collapsing literal duplicate
///      market keys in the request to one binding.
///
///      COVERAGE IS THE CALLER'S: neither the registry nor Morpho enumerates an owner's markets, so this
///      snapshot covers EXACTLY the supplied `marketKeys` and never claims more. The caller must keep
///      supplying keys for markets where the owner still holds collateral or debt after lending is withdrawn
///      (residual positions, zero-lending borrowers). Zero lending shares never suppress the collateral or
///      debt legs.
interface IMorphoOwnerSnapshot {
    /// @notice Which economic leg of a market a position row represents.
    enum Side {
        Lending,
        Collateral,
        Debt
    }

    /// @notice One economic leg of one market for the owner.
    /// @dev Accounting identity is `(morpho, marketId, side)`; chain and owner come from the request context.
    /// @param marketKey The registered market key this leg was resolved from (as supplied)
    /// @param morpho The Morpho Blue singleton holding the market
    /// @param marketId The full Morpho market id
    /// @param side Lending / Collateral / Debt
    /// @param token The token this leg is denominated in (loanToken for Lending/Debt, collateralToken for Collateral)
    /// @param tokenDecimals Decimals of `token`
    /// @param assets Accrued assets (Lending down, Debt up) or raw collateral, in `token` units; may be zero
    /// @param shares Raw supply/borrow shares for Lending/Debt (diagnostics); always 0 for Collateral
    struct OwnerPosition {
        address marketKey;
        address morpho;
        bytes32 marketId;
        Side side;
        address token;
        uint8 tokenDecimals;
        uint256 assets;
        uint256 shares;
    }

    /// @notice The binding of one requested market, returned so a caller can verify coverage without a
    ///         second round trip.
    /// @param marketKey The requested market key, as supplied
    /// @param morpho The Morpho Blue singleton holding the market
    /// @param marketId The full Morpho market id
    /// @param loanToken The lending/debt token
    /// @param collateralToken The collateral token (`address(0)` for lending-only markets)
    struct MarketBinding {
        address marketKey;
        address morpho;
        bytes32 marketId;
        address loanToken;
        address collateralToken;
    }

    /// @notice Resolve supplied market keys into their de-duplicated bindings and per-leg accounting rows.
    /// @dev STRICT, NO FALLBACK: an unregistered market key reverts `MARKET_NOT_REGISTERED` and a zero owner
    ///      reverts `ZERO_ADDRESS`; nothing degrades to a zero-valued position. Duplicate keys collapse to one
    ///      binding and one set of legs. For each unique market this returns the Lending and Debt legs always
    ///      (loanToken, zero balances included) and the Collateral leg only when the market has a collateral
    ///      token — a lending-only market (collateralToken == address(0)) emits no collateral leg because it
    ///      cannot be denominated, rather than a misleading zero in an undefined token.
    /// @param owner The account whose positions are read
    /// @param marketKeys Registered market keys from the strategy's source list (the covered universe)
    /// @return markets One binding per UNIQUE requested market, in first-seen request order
    /// @return positions The economic legs of those markets — zero balances included — never netted
    function getOwnerSnapshot(
        address owner,
        address[] calldata marketKeys
    )
        external
        view
        returns (MarketBinding[] memory markets, OwnerPosition[] memory positions);
}
