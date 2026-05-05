# YoOracle Interview Notes

**Date:** 2026-02-23
**Feature:** YoYieldSourceOracle - Oracle for Yo Vaults with async redemption support

---

## Feature Summary

Create a new oracle (`YoYieldSourceOracle`) that inherits from `AbstractYieldSourceOracle` to correctly value Yo Vault positions in SuperVaults. Unlike standard ERC-4626 vaults, Yo Vaults support async redemptions where shares are burned but assets are not immediately received.

## Problem Statement

The existing ERC-4626 oracle cannot be used for Yo Vaults because:
1. Yo Vaults work asynchronously - redemptions may be queued
2. During async redemption transitions, yoToken shares have been burned but underlying assets have not yet been received by the SuperVault
3. This creates a PPS discontinuity if only `balanceOf * convertToAssets` is used

## Target SuperVaults

Initially applicable to:
- **SuperWETH** (yoETH position)
- **SuperUSDC** (yoUSDC position)

---

## Valuation Formula

The total value of a SuperVault's position in a Yo Vault is:

```
yo_position_value = held_value + pending_value
```

Where:
- `held_value = yoShares_held × yo_PPS`
- `pending_value = pendingRedeemRequest(SV_address).assets`

### Components

| Component | Source | Description |
|-----------|--------|-------------|
| `yoShares_held` | `yoVault.balanceOf(SV_address)` | Current yoToken balance |
| `yo_PPS` | `yoVault.convertToAssets(10^decimals)` | Price per share |
| `pendingRedeemRequest().assets` | `yoVault.pendingRedeemRequest(SV_address)` | Assets owed from async redeems |

Both `held_value` and `pending_value` are denominated in the Yo Vault's underlying asset (WETH or USDC).

---

## Required Yo Vault Interface

The oracle must call these functions:

| Function | Returns | Purpose |
|----------|---------|---------|
| `balanceOf(address)` | `uint256` shares | yoToken balance held by SV |
| `convertToAssets(uint256)` | `uint256` assets | Yo vault PPS derivation |
| `pendingRedeemRequest(address)` | `(uint256 assets, uint256 shares)` | Value of outstanding async redeems |
| `decimals()` | `uint8` | Token decimals |

### Optional Functions (for sanity checks)
- `totalPendingAssets()` - Aggregate pending across all users
- `maxRedeem(address)` - Available instant liquidity

---

## State Transition Analysis

### 4.1 Steady State (no pending redeems)
```
State:  SV holds N yoShares, no pending requests
Value:  N × yo_PPS + 0 = N × yo_PPS
```
Standard ERC-4626 behavior. `pendingRedeemRequest().assets = 0`.

### 4.2 Sync Redeem (sufficient liquidity)
```
Before: SV holds N yoShares, liquid_assets = L
TX:     SV calls redeem(X shares) → succeeds, receives Y underlying
After:  SV holds (N-X) yoShares, liquid_assets = L + Y

Value before: N × yo_PPS + 0 + L
Value after:  (N-X) × yo_PPS + 0 + (L + Y)
```
Net change: zero (since `Y = X × yo_PPS`).

### 4.3 Async Redeem — Request Phase (t0)
```
Before: SV holds N yoShares, pendingRedeemRequest().assets = 0
TX:     SV calls requestRedeem(X shares) → shares burned, request queued
After:  SV holds (N-X) yoShares, pendingRedeemRequest().assets = Y

Value before: N × yo_PPS + 0
Value after:  (N-X) × yo_PPS + Y
```
**Net change: zero** (since `Y = X × yo_PPS` at request time). No PPS discontinuity.

### 4.4 Async Redeem — Fulfillment Phase (t1)
```
Before: SV holds M yoShares, pendingRedeemRequest().assets = Y, liquid_assets = L
TX:     Yo keeper calls fulfillRedeem() → Y assets pushed to SV
After:  SV holds M yoShares, pendingRedeemRequest().assets = 0, liquid_assets = L + Y

Value before: M × yo_PPS + Y + L
Value after:  M × yo_PPS + 0 + (L + Y)
```
Net change: zero.

### 4.5 Partial Fulfillment
```
Before: pendingRedeemRequest().assets = Y, liquid_assets = L
TX:     Yo keeper fulfills Z assets (Z < Y)
After:  pendingRedeemRequest().assets = Y - Z, liquid_assets = L + Z
```
Net change: zero. Formula works for partial fulfillments.

### 4.6 Multiple Requests Before Fulfillment
```
TX1:    requestRedeem(X1) → burns X1 shares, pending += Y1
TX2:    requestRedeem(X2) → burns X2 shares, pending += Y2

pendingRedeemRequest().assets = Y1 + Y2  (single accumulated slot)
```
The oracle reads the aggregate. No per-request tracking needed.

### 4.7 Request Cancellation
```
Before: pendingRedeemRequest().assets = Y, yoShares = M
TX:     Yo admin calls cancelRedeem() → request cancelled, shares returned
After:  pendingRedeemRequest().assets = 0, yoShares = M + X_returned
```
If shares returned at same exchange rate, net effect is zero.

---

## Core Assumptions

| ID | Assumption | Impact if Violated |
|----|------------|-------------------|
| A1 | `pendingRedeemRequest().assets` is denominated in underlying asset | Incorrect valuation |
| A2 | `fulfillRedeem()` is atomic (pending decreases + transfer in same TX) | Overcount window |
| A3 | `pendingRedeemRequest()` reflects requests in same TX as `requestRedeem()` | Undercount window |
| A4 | Requests accumulate in single slot per receiver | Oracle would miss requests |
| A5 | `convertToAssets()` returns reliable PPS at all times | Incorrect held_value |

---

## Risk Analysis

### Risk: Atomicity Violation (A2)
If `fulfillRedeem()` is not fully atomic, there's a single-block window where pending is zeroed but transfer hasn't completed.

**Mitigation:** Solidity TX atomicity. Offchain keeper sanity bounds catch transient undercount.

### Risk: Yo Vault PPS Manipulation
Flash loan attacks affecting Yo Vault's internal accounting could manipulate `convertToAssets`.

**Mitigation:** Same class of risk as other ERC-4626 UYS. Existing sanity checks apply.

### Risk: Exchange Rate Drift on Pending Assets
If rate is locked at request time, pending value may diverge from current rate.

**Status:** Not a bug - correct economic representation of locked rate.

### Risk: Contract Upgrade
If Yo Vault upgrades and `pendingRedeemRequest()` interface changes, oracle breaks.

**Mitigation:** Monitor proxy admin for upgrades. Include ABI hash in config.

---

## Testing Checklist

| # | Scenario | Expected Outcome |
|---|----------|------------------|
| T1 | SV holds yoShares, no pending redeems | `yo_position_value = balanceOf × convertToAssets(1) / 1e18` |
| T2 | SV calls `redeem()` (sync path) | PPS unchanged before/after TX |
| T3 | SV calls `requestRedeem()` (async path) | PPS unchanged before/after TX |
| T4 | Yo keeper calls `fulfillRedeem()` | PPS unchanged before/after TX |
| T5 | Partial fulfillment | PPS unchanged; pending decreases, liquid increases |
| T6 | Multiple `requestRedeem()` before fulfillment | `pendingRedeemRequest().assets` reflects cumulative total |
| T7 | `cancelRedeem()` called | Shares restored; PPS impact only from rate drift |
| T8 | `redeem()` reverts with `UseRequestRedeem` | SV gracefully falls back to `requestRedeem()` |
| T9 | Cross-asset SV (e.g., SuperUSDC with yoETH) | Conversion rate correctly applied |
| T10 | Yo Vault PPS changes between oracle reads | `held_value` reflects new PPS; `pending_value` fixed |

---

## Implementation Pseudocode

```python
def compute_yo_position_value(sv_address, yo_vault_address):
    """
    Returns the total value of the SV's Yo Vault position,
    denominated in the Yo Vault's underlying asset.
    """
    # Component 1: held shares
    yo_shares = yo_vault.balanceOf(sv_address)
    held_value = yo_vault.convertToAssets(yo_shares)

    # Component 2: pending async redeems
    (pending_assets, _pending_shares) = yo_vault.pendingRedeemRequest(sv_address)

    return held_value + pending_assets
```

---

## Cross-Asset Conversion

If SV denomination differs from Yo Vault's underlying (e.g., SuperUSDC holding yoETH):

```
yo_position_value_in_sv_asset = yo_position_value × conversion_rate(yo_underlying → sv_asset)
```

The conversion rate source follows existing SV oracle infrastructure (Chainlink, Pendle TWAP, etc.). This is outside the scope of this oracle - it uses the same pattern as other cross-asset UYS positions.

---

## Open Questions

1. **Yo Vault Interface Confirmation:** Need to verify exact function signatures for `pendingRedeemRequest()` - does it return `(uint256 assets, uint256 shares)` or just `uint256`?

2. **Request ID Pattern:** Does Yo use request IDs like ERC-7540, or is it address-based only?

3. **Decimal Handling:** Confirm yoTokens use 18 decimals for both yoETH and yoUSDC.
