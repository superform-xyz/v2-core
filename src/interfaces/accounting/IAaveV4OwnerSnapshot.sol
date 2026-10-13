// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4OwnerSnapshot
/// @notice Complete raw Aave accounting inputs for an owner on a specified set of spokes.
/// @dev Values stay in underlying token units. Consumers normalize, classify and net them.
interface IAaveV4OwnerSnapshot {
    struct OwnerPosition {
        address sourceKey;
        address spoke;
        uint256 reserveId;
        address underlying;
        uint8 underlyingDecimals;
        uint8 side;
        uint256 assets;
        string symbol; // Optional display metadata; empty when unavailable or malformed.
    }

    struct WalletBalance {
        address token;
        uint8 decimals;
        uint256 balance;
    }

    /// @notice The binding of one requested market, returned so a caller can verify coverage and both
    ///         expected legs without a second round trip — including legs whose balance is zero.
    /// @param marketKey The requested market key, as passed in
    /// @param spoke The spoke holding both reserves
    /// @param supplyReserveId The collateral reserve id
    /// @param borrowReserveId The loan reserve id
    /// @param supplyKey `computeReserveKey(spoke, supplyReserveId)` — the collateral position's key in `positions`
    /// @param debtKey `computeDebtKey(spoke, borrowReserveId)` — the debt position's key in `positions`
    struct MarketBinding {
        address marketKey;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        address supplyKey;
        address debtKey;
    }

    /// @notice Resolve registered MARKET keys into de-duplicated accounting legs, discover every other
    ///         active debt on covered spokes, and read eligible wallet cash — one block-pinned call.
    /// @dev THE INPUT IS MARKET IDENTITY, THE OUTPUT IS ACCOUNTING IDENTITY (SUP-21256). A strategy's
    ///      yield-source list holds the market keys the V2 LOAN hooks name; this call resolves each through
    ///      `getMarketInfo` and returns the underlying `(spoke, reserveId, side)` legs, so the caller never
    ///      has to register or pass accounting legs itself.
    ///      DE-DUPLICATION IS THE POINT. Aave V4 positions are reserve-granular, so one reserve participates
    ///      in N markets: on Base MAG7 all seven equity markets borrow the one USDC reserve. Legs are
    ///      therefore deduplicated across the WHOLE requested set before any read, so seven markets return
    ///      seven collateral positions and ONE shared USDC debt position. That is only possible in a batched
    ///      call that sees the whole list — summing independent per-market reads double counts the shared
    ///      leg, which is why this, not `getMarketPosition`, is the portfolio valuation path.
    ///      Duplicate market keys in `marketKeys` collapse to one binding and change nothing else.
    ///      STRICT, NO FALLBACK: an unregistered market reverts `MARKET_NOT_REGISTERED`, a missing leg
    ///      reverts `RESERVE_NOT_REGISTERED`, and a reserve key passed as a market reverts. Nothing degrades
    ///      to zero and nothing retries through the old reserve-key input.
    /// @param owner Strategy/account whose positions and wallet balances are read.
    /// @param marketKeys Registered market keys from the strategy's source list.
    /// @param configuredSpokes Additional spokes to cover for debt discovery, independent of the markets.
    /// @param cashTokens Explicit tokens to keep tracking after full repayment.
    /// @param vaultAsset Token already counted as idle vault cash by the consumer.
    /// @param maxReservesPerSpoke Maximum permitted reserve count; exceeding it reverts, never truncates.
    /// @return markets One binding per UNIQUE requested market, in request order, with both derived leg keys.
    /// @return positions Unique legs of the requested markets — zero balances included — followed by any
    ///         additional active debt AND any residual supplied collateral discovered on the covered spokes
    ///         (SUP-21259: discovery is symmetric, so collateral no requested market covers is returned
    ///         rather than silently omitted; if its SUPPLY leg is unregistered the call reverts
    ///         `UNCOVERED_COLLATERAL` instead). Consumers must therefore accept supply rows they did not
    ///         request — count each leg once, as always.
    /// @return balances Unique non-vault cash balances; all amounts are non-negative raw token units.
    function getOwnerSnapshot(
        address owner,
        address[] calldata marketKeys,
        address[] calldata configuredSpokes,
        address[] calldata cashTokens,
        address vaultAsset,
        uint256 maxReservesPerSpoke
    )
        external
        view
        returns (MarketBinding[] memory markets, OwnerPosition[] memory positions, WalletBalance[] memory balances);
}
