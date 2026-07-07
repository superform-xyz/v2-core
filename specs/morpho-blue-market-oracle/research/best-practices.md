# Best Practices — Morpho Blue Interest Accrual Oracle

## Canonical `_accrueInterest` Replication (MorphoBalancesLib pattern)

The correct view-context replication of Morpho's `_accrueInterest`:

```solidity
uint256 elapsed = block.timestamp - market.lastUpdate;

// Three-condition skip (all must be true to accrue):
if (elapsed != 0 && market.totalBorrowAssets != 0 && marketParams.irm != address(0)) {
    uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
    uint256 interest = market.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));

    market.totalBorrowAssets += interest;
    market.totalSupplyAssets += interest;

    if (market.fee != 0) {
        uint256 feeAmount = interest.wMulDown(market.fee);
        // NOTE: subtract feeAmount from denominator — prices fee shares at pre-fee PPS
        uint256 feeShares = feeAmount.toSharesDown(
            market.totalSupplyAssets - feeAmount,
            market.totalSupplyShares
        );
        market.totalSupplyShares += feeShares;
    }
}
```

**Important**: The current `MorphoBlueYieldSourceOracle` checks only `elapsed > 0 && totalBorrowAssets > 0`, missing the third condition `irm != address(0)`. For markets with `irm == address(0)` and non-zero borrows (theoretical edge case), this would revert. The canonical MorphoBalancesLib includes all three conditions.

## SharesMathLib — Rounding Conventions

```
VIRTUAL_SHARES = 1e6  (added to totalShares denominator)
VIRTUAL_ASSETS = 1    (added to totalAssets numerator)
```

Golden rule: **rounding must favor the protocol** (against the user).

| Operation | Function | Why |
|---|---|---|
| Deposit (assets → shares minted) | `toSharesDown` | User gets fewer shares |
| Withdrawal (assets → shares burned) | `toSharesUp` | User must burn more shares |
| Redeem/TVL (shares → assets) | `toAssetsDown` | User gets fewer assets |
| Fee share minting | `toSharesDown` | Fee recipient bears rounding loss |

## `wTaylorCompounded` Math

Three-term Taylor expansion of `e^(rt) - 1`:
```
result = rt + (rt)^2/2 + (rt)^3/6
```
Where `r` = per-second borrow rate (WAD-scaled) and `t` = elapsed seconds.

**Practical accuracy**: At 10% APR for 1 year, error ≈ 4 ppm. At 100% APR for 1 year, error ≈ 1.7%. In practice `elapsed` is small (frequent market interactions), so accuracy is always good.

**Overflow risk**: `firstTerm = borrowRate * elapsed` (bare uint256 multiply). For the AdaptiveCurveIRM with its hard rate cap, this is safe. For custom IRMs with extreme rates, this can overflow and revert (which is safer than silent corruption).

## Virtual Offsets — Zero-Supply Safety

Without virtual offsets, a fresh market allows share inflation attacks. With `VIRTUAL_SHARES=1e6` and `VIRTUAL_ASSETS=1`:
- At zero supply: `toAssetsDown(1e6, 0, 0) = 1e6 * 1 / 1e6 = 1` — no revert, reasonable value
- Donation attack is capped: manipulator can only shift price by `X / (realAssets + 1)` where denominator is at least 1

The oracle doesn't need to special-case zero supply — SharesMathLib handles it automatically.

## Fee Denominator Subtraction — Critical Detail

When `fee > 0`, Morpho adds the full interest to `totalSupplyAssets` first, then mints fee shares. The fee shares must be priced **before** the fee was added to avoid double-counting:

```solidity
// WRONG: uses full totalSupplyAssets (including feeAmount already in it)
feeShares = feeAmount.toSharesDown(totalSupplyAssets, totalSupplyShares);

// CORRECT: subtract feeAmount from denominator
feeShares = feeAmount.toSharesDown(totalSupplyAssets - feeAmount, totalSupplyShares);
```

Omitting this subtraction underprices fee shares, causing the oracle to report a slightly higher PPS than reality for markets with active fees.

## `borrowRateView` vs `borrowRate`

- `borrowRate(MarketParams, Market) external returns (uint256)` — **mutates** IRM state (AdaptiveCurveIRM updates its internal rate reference)
- `borrowRateView(MarketParams, Market) external view returns (uint256)` — **read-only**, usable in view functions

Never call `borrowRate` from a view function — it will revert.

## `totalBorrowShares` in the Market Struct

The `Market` struct passed to `borrowRateView` needs `totalBorrowShares: 0` because the AdaptiveCurveIRM only uses the utilization ratio (`totalBorrowAssets / totalSupplyAssets`). This is a valid assumption for production AdaptiveCurveIRM deployments. A custom IRM that uses `totalBorrowShares` would receive incorrect data.

## Reference: MorphoBalancesLib

The canonical Morpho periphery library for view-context market state computation:
- GitHub: `morpho-org/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol`
- Function: `expectedMarketBalances(MarketParams, IMorpho, Id)`
- This is the authoritative reference for any view-context interest replication.

## Known Exploits (Morpho Ecosystem)

1. **PAXG/USDC $230K (2024)**: Market oracle misconfiguration — decimal scale factor mismatch. The `marketOracle` used for collateral pricing was wrong. **Not relevant to yield oracle** (yield oracle never calls `marketOracle.price()`).

2. **Pyth cbETH incident (March 2024)**: Stale collateral price oracle triggered erroneous liquidations. Same category — collateral oracle risk, not yield oracle risk.

3. **No yield-oracle-specific exploits found** for Morpho Blue supply-side PPS reporting.
