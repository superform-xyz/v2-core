# ERC-7540 Oracle Research for SuperVault

## Date: 2026-04-27
## Status: Research Complete

---

## Context

SuperVaults want to deploy capital into EIP-7540 vaults (e.g., yoETH, yoUSD on Base). Some PT underlying tokens are shares of 7540 vaults — the only way to fully exit such investments is to redeem these shares on the 7540 vault for the SuperVault's primary asset. This creates an async redemption flow that the PPS oracle must account for.

## The Core Problem

`totalAssets()` must account for three types of value:
1. **Liquid assets** held by the SV
2. **Positions in UYS** (valued via oracles)
3. **Pending receivables** — shares burned, assets not yet delivered (NEW with 7540)

Without tracking category 3, every async redeem creates a temporary hole in `totalAssets()` that makes PPS drop artificially — exploitable via deposit at deflated PPS, wait for claim to settle, profit from rebound.

## State Machine

| State | Onchain Reality | Risk |
|-------|----------------|------|
| Pre-request | SV holds X shares in UYS | None |
| Requested (t0) | Shares burned/escrowed, no assets yet | **Understated PPS** if pending not tracked |
| Pending tracked | Claim for Y assets on the books | Correct if Y is accurate |
| Fulfilled but not claimed | Assets received AND claim still on books | **Overstated PPS** (double-count) |
| Cleared | Assets in balance, claim deleted | None |

## Current Oracle Architecture

### Existing Oracles in `src/accounting/oracles/`

| Oracle | For | Pending Tracking | Interface |
|--------|-----|-----------------|-----------|
| `SuperVaultYieldSourceOracle` | SuperVault shares | NO | `ISuperVault` (ERC4626 + 7540 redeem) |
| `YoYieldSourceOracle` | Yo Vaults | YES (pending redeems) | `IYoVault` (non-standard) |
| `ERC4626YieldSourceOracle` | Standard ERC-4626 | N/A (sync) | `IERC4626` |
| `ERC5115YieldSourceOracle` | ERC-5115 | N/A | `IERC5115` |
| `PendlePTYieldSourceOracle` | Pendle PT | N/A | Pendle |

### Why Existing Oracles Don't Work for Generic 7540

**`YoYieldSourceOracle`** uses `IYoVault.pendingRedeemRequest(address owner)` → returns `(uint256 assets, uint256 shares)`:
- Address-based accumulator (no requestId)
- Returns pending ASSETS (locked at request time, stable)
- Yo-specific interface, not standard ERC-7540

**Standard ERC-7540** uses `pendingRedeemRequest(uint256 requestId, address controller)` → returns `uint256 pendingShares`:
- RequestId-based (supports multiple concurrent requests)
- Returns pending SHARES (not assets!) — must convert via PPS
- Rate NOT locked at request time in the spec

### The Gap

Need a new `ERC7540YieldSourceOracle` that:
- Uses standard `IERC7540Redeem` interface
- Includes pending redeems in TVL: `held_value + (pendingShares × currentPPS)`
- Handles requestId (hooks use `requestId = 0` convention)
- Also considers `claimableRedeemRequest` (fulfilled but not yet claimed)

## Answers to Outstanding Questions

### Q1: Settlement Rate Determinism

- **Standard 7540 spec**: Rate is NOT locked at request time. `pendingRedeemRequest` returns shares, not assets. The actual asset amount depends on fulfillment rate.
- **Yo Vaults**: Rate IS locked — `pendingRedeemRequest(owner)` returns fixed `(assets, shares)` at request time.
- **Implication for oracle**: For standard 7540, pending value = `pendingShares × currentPPS` (fluctuates). For Yo, pending value = `pendingAssets` (stable).

### Q2: Atomicity at t0

YES — `requestRedeem()` executes and `pendingRedeemRequest()` reflects it in the same block. The oracle reads onchain state, so if the keeper reads PPS after t0, the pending amount is already visible. The undercount gap is **zero from the oracle's perspective** because `pendingRedeemRequest` is immediately queryable.

### Q3: Detection of Fulfillment (t1)

- Poll `claimableRedeemRequest(requestId, controller)` — goes from 0 → positive when fulfilled
- `RedeemClaimable` event emitted by vault
- Well-behaved vaults decrement `pendingRedeemRequest` atomically when moving to claimable
- Overcount window = time between fulfillment and `claimRedeem` TX

### Q4: Atomic Claim Deletion + Asset Claiming

YES — `redeem(shares, receiver, controller)` in 7540 serves as the claim function. Atomically:
- Moves assets from vault → receiver
- Reduces `claimableRedeemRequest` to 0
- Burns any remaining locked shares

No overcount gap at claim time.

### Q5: Yo Vault Hybrid Sync/Async

When sync (enough liquidity): `requestRedeem()` returns immediately, `pendingRedeemRequest` stays 0, assets returned same TX. When async: goes into pending state, `pendingRedeemRequest` reflects it.

Oracle doesn't need branching logic — `heldValue + pendingAssets` handles both paths. If sync, pending = 0 and everything is in heldValue.

### Q6: Multiple Concurrent Redeems & requestId Design

- Each 7540 UYS position is tracked independently (different `yieldSource` addresses)
- Within a single 7540 UYS: depends on vault's requestId model
- Current hooks hardcode `requestId = 0` (accumulated pattern)

**Problem**: 7540 explicitly allows non-zero requestIds (per-request NFT-style tokens, Maple MPL-20 pattern, some Centrifuge configurations). Hardcoding `requestId = 0` works for accumulated-request vaults but breaks for per-request vaults. Cheap to add now, expensive post-deployment (oracle redeploy + governance migration).

**Decision: R1 — constructor parameter.**

```solidity
uint256 public immutable REQUEST_ID;

constructor(address ledgerConfig_, uint256 requestId_) AbstractYieldSourceOracle(ledgerConfig_) {
    REQUEST_ID = requestId_;
}
```

Why R1 over R2 (sum-across-requestIds view):
- Matches existing pattern: one oracle instance per yield source, registered via `SuperYieldSourceOracle.setYieldSourceOracle(yieldSource, oracle)`. A vault using requestId=5 gets its own instance.
- No API surface change — `getTVLByOwnerOfShares` / `getRedemptionStateBreakdown` signatures stay the same. requestId is internal.
- R2 requires someone to maintain the list of active requestIds — state management the oracle shouldn't own.
- Multiple concurrent requestIds for the same controller (different tranches) maps to separate yield source entries in the strategy, which is how multi-position tracking already works.

**Default**: `REQUEST_ID = 0` for backward compatibility with all existing hooks and accumulated-request vaults.

### Q7: Onchain vs Offchain

**Maintain 100% onchain pricing.** The pending receivables tracking IS fully onchain — `pendingRedeemRequest()` and `claimableRedeemRequest()` are view functions on vault contracts. Oracle just reads them. Pattern:

```
Onchain oracle (view function) → Offchain keeper reads → Pushes PPS onchain
```

No offchain computation needed. The Veda differentiator holds.

## New Oracle Design: ERC7540YieldSourceOracle

### Key Methods

```solidity
// getTVLByOwnerOfShares — THE KEY METHOD
// Five-component TVL: held shares + pending redeems + claimable redeems + pending deposits + claimable deposits
function getTVLByOwnerOfShares(address yieldSource, address owner) returns (uint256) {
    IERC7540 vault = IERC7540(yieldSource);

    // Component 1: Value of held shares (current rate — correct for active positions)
    uint256 heldShares = vault.balanceOf(owner);
    uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

    // Component 2: Pending redeems (shares not yet fulfilled)
    // Standard 7540 returns pendingShares, not assets — must convert at current rate
    // This is an approximation: actual fulfillment rate is unknown until epoch settles
    uint256 pendingRedeemValue;
    try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
        pendingRedeemValue = pendingShares > 0 ? vault.convertToAssets(pendingShares) : 0;
    } catch {}

    // Component 3: Claimable redeems (fulfilled but not yet claimed)
    // USE maxWithdraw — NOT convertToAssets(claimableShares)
    // Reason: Centrifuge V3 locks per-controller redeemPrice at fulfillment.
    // maxWithdraw() returns the exact locked asset amount — correct for all vault subtypes.
    uint256 claimableRedeemValue;
    try vault.maxWithdraw(owner) returns (uint256 withdrawable) {
        claimableRedeemValue = withdrawable;
    } catch {}

    // Component 4: Pending deposits (assets sent to vault, no shares yet)
    // pendingDepositRequest returns ASSETS directly — no conversion needed.
    // These assets left the SV idle balance and sit at the underlying.
    uint256 pendingDepositValue;
    try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
        pendingDepositValue = pendingAssets;
    } catch {}

    // Component 5: Claimable deposits (fulfilled, shares allocated but unclaimed)
    // claimableDepositRequest returns ASSETS — the original deposit amount.
    // Shares have been allocated at fulfillment rate but aren't in balanceOf yet.
    // Using the asset amount is a reasonable approximation — claimable state is transient.
    uint256 claimableDepositValue;
    try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
        claimableDepositValue = claimableAssets;
    } catch {}

    return heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue;
}

// getAsyncStateBreakdown — FREE INSTRUMENTATION
// Returns all 5 components computed by getTVLByOwnerOfShares, pre-summed.
// Zero marginal cost — the terms are already computed.
function getAsyncStateBreakdown(address yieldSource, address owner)
    external view
    returns (
        uint256 held,
        uint256 pendingRedeem,
        uint256 claimableRedeem,
        uint256 pendingDeposit,
        uint256 claimableDeposit
    )
{
    IERC7540 vault = IERC7540(yieldSource);

    uint256 heldShares = vault.balanceOf(owner);
    held = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

    try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
        pendingRedeem = pendingShares > 0 ? vault.convertToAssets(pendingShares) : 0;
    } catch {}

    try vault.maxWithdraw(owner) returns (uint256 withdrawable) {
        claimableRedeem = withdrawable;
    } catch {}

    try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
        pendingDeposit = pendingAssets;
    } catch {}

    try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
        claimableDeposit = claimableAssets;
    } catch {}
}
```

### Async Deposit Tracking Rationale

Centrifuge V3 (under active eval), Firelight/Bizantine FXRP both have async deposit flows:
`requestDeposit → pendingDepositRequest → claimableDepositRequest → deposit (claim)`

When a SuperVault calls `requestDeposit`, assets leave idle balance and sit at the underlying with no shares to show. Without tracking, TVL understates — same exploit vector as async redeem but in reverse.

**Why the deposit side is simpler than redeem:**
- `pendingDepositRequest(requestId, c)` returns **assets** directly (not shares) — no `convertToAssets` conversion needed, no Centrifuge rate mismatch issue
- `claimableDepositRequest(requestId, c)` also returns **assets** — the original deposit amount. Shares have been allocated at the fulfillment rate but using the original asset amount is acceptable because: (a) the claimable state is transient (claimed quickly), (b) the delta between original assets and `convertToAssets(claimable_shares)` is bounded by one epoch's yield

**Marginal cost**: Near zero — two additional try/catch calls in the same view function. Retrofitting later = oracle redeploy + governance migration + potential re-audit.

### Monitoring Alerts via getAsyncStateBreakdown

The breakdown feeds the C1/C2/C3 risk engine directly:

| Alert | Condition | Meaning |
|-------|-----------|---------|
| **A1** (C2) | `pendingRedeem` grows across epochs but `claimableRedeem` stays 0 | Underlying vault operator failing to fulfill redeems — liquidity risk |
| **A2** (C3) | `claimableRedeem` grows but isn't claimed (persists across blocks) | SV execution layer failing to call `claimRedeem` — operational risk |
| **A3** (C1) | `pendingRedeem / underlying.totalAssets() > X%` | SV is dominant exit pressure on the underlying — concentration risk |
| **A4** (C2) | `pendingDeposit` grows across epochs but `claimableDeposit` stays 0 | Underlying vault operator failing to fulfill deposits — capital lockup risk |
| **A5** (C3) | `claimableDeposit` grows but isn't claimed (persists across blocks) | SV execution layer failing to call `deposit` (claim) — idle capital risk |

Keeper or Hypernative monitors call `getAsyncStateBreakdown` per yield source on each cycle and flag threshold breaches.

### Why maxWithdraw for Claimable (Centrifuge redeemPrice Discovery)

**Problem**: `convertToAssets(claimableRedeemRequest(0, c))` is incorrect for Centrifuge-style vaults.

Centrifuge V3 `InvestmentManager` stores a per-controller `redeemPrice` locked at epoch fulfillment:
```
state.redeemPrice = _calculatePrice(vault, cumulativeAssets, cumulativeShares)
state.maxWithdraw = state.maxWithdraw + assets
```

The chain of calls:
1. `claimableRedeemRequest(0, c)` → `maxRedeem(c)` → `_calculateShares(state.maxWithdraw, state.redeemPrice)` → returns shares S
2. `convertToAssets(S)` applies `latestPrice` (current global rate from `PoolManager.getTranchePrice()`)
3. Result: `(maxWithdraw / redeemPrice_locked) * latestPrice_current`
4. This equals `maxWithdraw` ONLY when `latestPrice == redeemPrice_locked` — virtually never true for accruing RWA vaults

**Solution**: `maxWithdraw(c)` returns `state.maxWithdraw` directly — the exact locked asset amount. No price conversion, no rate mismatch. Standard ERC-4626 method, available on all vaults.

**Why no double-count**: For async 7540 vaults, `maxWithdraw` only returns claimable assets. Held shares can't be withdrawn directly (need `requestRedeem` first), so `maxWithdraw` excludes them.

| Vault Subtype | `convertToAssets(claimable)` | `maxWithdraw(c)` | Correct? |
|---------------|------------------------------|-------------------|----------|
| Vanilla (live PPS) | shares × currentPPS | shares × currentPPS | Both equivalent |
| Centrifuge (locked rate) | shares × latestPrice (WRONG) | exact locked assets | Only `maxWithdraw` |
| Yo-style (locked at request) | shares × currentPPS | exact locked assets | Only `maxWithdraw` |

### Fee Inclusion Analysis: convertToAssets vs previewRedeem vs maxWithdraw

Per ERC-4626 spec:
- `convertToAssets(shares)` — pure exchange rate, **excludes redemption fees**
- `previewRedeem(shares)` — actual redemption output, **includes fees** (spec mandates it)
- `maxWithdraw(owner)` — maximum withdrawable assets, **includes fees + constraints**

| Component | `convertToAssets` | `previewRedeem` | `maxWithdraw` | Used |
|-----------|------------------|----------------|---------------|------|
| **Held** | Gross value, no fees | Reverts/0 on async vaults (can't sync-redeem held shares) | Only covers claimable, not held | `convertToAssets` — only viable option |
| **Pending** | Approximate (rate unknown until fulfillment) | Not applicable (shares in transit) | N/A | `convertToAssets` — only viable option |
| **Claimable** | Gross, wrong rate on Centrifuge | Would include fees but has Centrifuge rate mismatch | Exact post-fee amount, handles locked rates | `maxWithdraw` — correct and simpler |

**Fee overstatement**: Held + pending components overstate by the vault's exit fee because `convertToAssets` excludes fees. This is:
- The same tradeoff every existing oracle makes (`ERC4626YieldSourceOracle` uses `convertToAssets` too)
- Bounded by the vault's redemption fee (typically 0-0.5% for institutional 7540 vaults)
- A consistent bias on both deposit and withdrawal PPS reads — not an exploitable gap
- Unavoidable: `previewRedeem` is not usable for async positions (held shares can't be sync-redeemed, pending shares are in transit)

**Vault non-compliance risk**: 2025 audit reviews found that many vaults don't properly reflect fees in `previewRedeem` per spec. Even if we could use `previewRedeem`, it might not include fees due to vault non-compliance. This makes the case-by-case vault assessment at onboarding/whitelisting stage the primary defense — not the oracle design.

**Conclusion**: The formula `convertToAssets(held) + convertToAssets(pending) + maxWithdraw(c)` is the best achievable accuracy. The fee gap is a known, small, consistent overstatement on the first two terms, acceptable given no better alternative exists for async positions.

### Double-Count Risk Analysis

The formula `held + pending + maxWithdraw` is safe IF:
- Shares removed from `balanceOf` when entering pending state (standard requires this)
- Shares removed from pending when entering claimable state (well-behaved vaults do this)
- `maxWithdraw` reflects only claimable assets, not held shares (true for async 7540 vaults)
- `maxWithdraw` returns 0 after claim (standard requires this)

The three pools should be **mutually exclusive** in a correct 7540 implementation.

### Differences from YoYieldSourceOracle

| Aspect | YoYieldSourceOracle | ERC7540YieldSourceOracle (new) |
|--------|--------------------|---------------------------------|
| Interface | `IYoVault` (custom) | `IERC7540Redeem` (standard) |
| Pending returns | `(assets, shares)` — fixed assets | `pendingShares` — must convert |
| Rate stability | Stable (assets locked at t0) | Fluctuates with PPS |
| RequestId | None (address-based) | `requestId = 0` convention |
| Claimable tracking | Not in oracle (not needed — assets fixed) | YES — must include claimable |

## Existing 7540 Hooks (already implemented)

All 12 hooks in `src/hooks/vaults/7540/`:
- RequestDeposit, ApproveAndRequestDeposit, Deposit (claim)
- RequestRedeem, Redeem (claim), Withdraw (claim)
- CancelDepositRequest, CancelRedeemRequest
- ClaimCancelDepositRequest, ClaimCancelRedeemRequest
- SetOperator, SetSlippage

All hooks use `requestId = 0` convention.

## Investigation: Why Was The Oracle Never Built?

### Deleted Oracle Discovery

A generic `ERC7540YieldSourceOracle` existed but was **deliberately deleted** in commit `9fb71cc1` (Nov 2025, SUP-16180). It was moved to `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol`.

**Critical finding**: The deleted oracle had **NO pending/claimable tracking** — it was just a 4626 clone that only counted `balanceOf` shares. It was never designed to handle async redemptions.

### SuperVault PPS Architecture (from v2-periphery)

**SuperVault implementation lives in `v2-periphery/src/SuperVault/`**, NOT in v2-core.

The PPS flow:

```
1. Keeper (supervault-pricing Python service) calls onchain oracles:
   - SuperYieldSourceOracle.getTVLByOwnerOfSharesMultiple()
   - Routes to specific oracle per yield source (ERC4626, Yo, Pendle, etc.)

2. Each oracle.getTVLByOwnerOfShares(yieldSource, strategyAddress) → returns TVL in asset terms

3. Keeper computes: totalAssets = idle_balance + sum(yield_source_tvls)
                    PPS = totalAssets / totalSupply

4. Keeper pushes PPS via: SuperVaultAggregator.forwardPPS() (onlyPPSOracle)

5. SuperVault.totalAssets() = totalSupply × _getStoredPPS()  ← reads keeper-pushed PPS
```

**The PPS is NOT computed live onchain.** It's computed offchain by the keeper reading onchain oracle view functions, then pushed back onchain.

### Why The Oracle Gap Matters

When a SuperVault strategy holds shares in a 7540 yield source (e.g., yoETH):
1. Strategy calls `requestRedeem()` on the 7540 vault
2. Shares move from `balanceOf(strategy)` → pending state
3. **Without an oracle that tracks pending**, the keeper reads TVL = 0 for that position
4. Keeper computes lower totalAssets → pushes lower PPS → artificial PPS drop
5. Attacker deposits at deflated PPS, waits for claim, profits from rebound

### Why It Was Deleted (Probable Reason)

The deleted oracle was a 4626 clone — it didn't solve the actual problem (pending tracking). Since it was functionally identical to `ERC4626YieldSourceOracle`, it was redundant. The team likely deleted it as cleanup, not because the need went away.

**The need for a proper ERC7540YieldSourceOracle with pending+claimable tracking still exists.** It was never actually built.

### Two-Tier Impact

The oracle is needed at **two levels**:

1. **v2-core oracle** (`ERC7540YieldSourceOracle`): Used by the keeper to read TVL for any smart account (not just SuperVaults) that holds 7540 vault shares as a yield source position.

2. **SuperVault-specific**: SuperVault's own `totalAssets()` uses keeper-pushed PPS (stored in aggregator). When SV holds 7540 UYS positions, the keeper must get accurate TVL from the oracle → the new oracle directly fixes the keeper's computation.

### Escrow Architecture

SuperVault has an `escrow` contract. When redeem requests are fulfilled:
- Strategy calls `fulfillRedeemRequests()` which moves assets to escrow
- Users claim from escrow via `redeem()`/`withdraw()`
- This is the SV's OWN 7540 redeem flow (SV itself IS a 7540 vault)

This is SEPARATE from the oracle concern. The oracle tracks SV's positions in external 7540 vaults (upstream), not SV's own downstream redeem flow.

## MEV: PPS Cadence Mismatch (Follow-Up, Not Blocker)

### Analysis Date: 2026-04-28

### The Attack

The validator network signs `lastPPSUpdateTimestamp` on its own cadence. The underlying 7540 vault's `convertToAssets()` moves on the underlying's cadence (Centrifuge daily NAV, Pendle interest accrual). Between updates these diverge.

A sophisticated actor predicting an underlying yield event could:
1. Watch for the underlying's PPS jump (e.g., Centrifuge NAV update)
2. Front-run a SuperVault deposit before the validator re-signs
3. Capture the spread on the next validator update

This is an existing attack vector (documented in SECURITY.md as "front-running PPS updates"). The new oracle **does not introduce it** but **changes its magnitude**: pending bucket inclusion means more value is now priced via `convertToAssets()` (which tracks the underlying's live rate), amplifying the front-runnable step.

### Why It's Amplified

Before the oracle: only held shares tracked via `convertToAssets()`.
After the oracle: held + pending shares tracked via `convertToAssets()`, plus claimable via `maxWithdraw()`.

The pending bucket can be a significant fraction of TVL during active redemption cycles. If the underlying jumps 1% and pending = 40% of TVL, the front-runnable delta increases by 0.4% of TVL compared to held-only tracking.

### Proposed Mitigation: Asymmetric Pricing (Bid/Ask Spread)

Expose a sibling view function:

```solidity
/// @notice Rate-locked TVL — uses validator-signed snapshot for held+pending, maxWithdraw for claimable.
/// @dev For inflow (deposit) pricing only. Lags the underlying's live rate.
function getTVLByOwnerOfShares_RateLocked(address yieldSource, address owner) public view returns (uint256);
```

| Pricing Mode | Held + Pending | Claimable | Used For |
|-------------|---------------|-----------|----------|
| **Live** (`getTVLByOwnerOfShares`) | `convertToAssets()` — tracks underlying's live rate | `maxWithdraw()` | **Outflows** (withdrawal safety — don't underpay withdrawers) |
| **Rate-locked** (`getTVLByOwnerOfShares_RateLocked`) | Validator-signed snapshot (stale, lagging) | `maxWithdraw()` | **Inflows** (deposit protection — don't let front-runners buy at stale live prices) |

The bid/ask spread between live and rate-locked closes the front-running window:
- Depositors buy at the **ask** (rate-locked / stale → higher effective price if underlying jumped)
- Withdrawers sell at the **bid** (live → reflects underlying's current rate)
- Spread is bounded by the validator update frequency × maximum underlying rate change per period

### Implementation Considerations

1. **Validator-signed snapshot**: Needs a storage slot for the last-signed held+pending value per yield source. Updated by keeper when it pushes PPS.
2. **Which consumer calls which**: SuperVaultStrategy (or keeper logic) decides: live for outflow, rate-locked for inflow. The oracle just exposes both views.
3. **Not needed in v1**: The attack requires predicting underlying yield events AND front-running validator updates. Low practical risk for institutional 7540 vaults with small, predictable NAV movements. Track as follow-up.

## Edge Cases & Error Handling

### Analysis Date: 2026-04-28

### The Two Consumers

The oracle has two fundamentally different consumers with different error handling needs:

| Consumer | Method Called | Where | Revert Impact |
|----------|-------------|-------|---------------|
| **Keeper** (offchain) | `getTVLByOwnerOfShares()` | Python `eth_call` | Python exception → keeper handles, can skip/stale |
| **BaseLedger** (onchain) | `getPricePerShare()` | `_updateAccounting()` line 282 | **DoS — blocks all user inflow/outflow on that yield source** |

### Revert Surfaces

`getPricePerShare()` only calls `convertToAssets(10^decimals)` — **identical revert surface to ERC4626**. No new DoS risk to accounting path.

`getTVLByOwnerOfShares()` adds four NEW revert surfaces beyond ERC4626 (all wrapped in try/catch):
1. `pendingRedeemRequest(REQUEST_ID, owner)` — reverts if vault rejects non-controller callers, requestId invalid, or vault paused
2. `maxWithdraw(owner)` — reverts if vault paused or broken. Standard ERC-4626 method — same risk profile as `convertToAssets`
3. `pendingDepositRequest(REQUEST_ID, owner)` — same risk profile as `pendingRedeemRequest`
4. `claimableDepositRequest(REQUEST_ID, owner)` — same risk profile as `pendingRedeemRequest`

### Decision: Hybrid R1/R2

All existing oracles use **R1 (hard revert)** — no try/catch anywhere in `YoYieldSourceOracle`, `ERC4626YieldSourceOracle`, etc.

For the new `ERC7540YieldSourceOracle`:

| Method | Error Strategy | Rationale |
|--------|---------------|-----------|
| `getPricePerShare()` | **R1** (hard revert) | Same as all other oracles. Can't do accounting without PPS — returning 0/stale causes incorrect fees, worse than DoS. |
| `getTVLByOwnerOfShares()` — `convertToAssets()` | **R1** (hard revert) | If `convertToAssets` reverts, vault is truly broken. Same risk as ERC4626. |
| `getTVLByOwnerOfShares()` — `pendingRedeemRequest()` | **R2** (try/catch → 0) | Graceful degradation. Conservative undercount. Prevents one paused vault from poisoning `getTVLByOwnerOfSharesMultiple()` batch. |
| `getTVLByOwnerOfShares()` — `maxWithdraw()` | **R2** (try/catch → 0) | Same rationale. Standard ERC-4626 method — low risk of reverting in practice, but wrap for consistency. |
| `getTVLByOwnerOfShares()` — `pendingDepositRequest()` | **R2** (try/catch → 0) | Same rationale as `pendingRedeemRequest`. Conservative undercount of in-flight deposits. |
| `getTVLByOwnerOfShares()` — `claimableDepositRequest()` | **R2** (try/catch → 0) | Same rationale. Claimable deposit state is transient. |

### Edge Case Table

| Scenario | `convertToAssets` | Redeem calls | Deposit calls | Result |
|----------|------------------|-------------|--------------|--------|
| Normal | OK | OK | OK | All 5 components (accurate) |
| Vault paused | REVERTS | REVERTS | REVERTS | `getTVLByOwnerOfShares` reverts (same as ERC4626) |
| Redeem calls revert | OK | REVERTS | OK | `held + pendingDeposit + claimableDeposit` (conservative) |
| Deposit calls revert | OK | OK | REVERTS | `held + pendingRedeem + claimableRedeem` (conservative) |
| All async calls revert | OK | REVERTS | REVERTS | `held` only (degrades to ERC4626 behavior) |
| requestId unsupported | OK | REVERTS | REVERTS | `held + maxWithdraw` (`maxWithdraw` doesn't use requestId) |
| Sync-only vault (no async) | OK | returns 0 | returns 0 | `held` only (correct — no async state) |

### Event Limitation

`getTVLByOwnerOfShares()` is a `view` function — cannot emit events. Fallback detection options:
1. **Keeper-side**: Compare `getAsyncStateBreakdown()` components. If all async components are 0 AND the keeper knows there are active async operations → try/catch likely swallowed a revert.
2. **Separate probe function**: `hasAsyncSupport(address yieldSource, address owner) → (bool pendingRedeemOk, bool maxWithdrawOk, bool pendingDepositOk, bool claimableDepositOk)` — keeper calls this to validate.
3. **Hypernative alert**: Monitor for known 7540 vaults where async queries fail.

### Solidity Pattern

```solidity
function getTVLByOwnerOfShares(address yieldSource, address owner) public view override returns (uint256) {
    IERC7540 vault = IERC7540(yieldSource);

    // Same 5-component logic as the Key Methods section above.
    // See getTVLByOwnerOfShares() for the full implementation.
    // Omitted here to avoid duplication — refer to Key Methods section.
}
```

### Inner convertToAssets in try/catch blocks

Note: `convertToAssets(pendingShares)` inside the pending redeem `try` block is NOT wrapped in its own try/catch. If `pendingRedeemRequest` succeeds but `convertToAssets` reverts (e.g., vault paused between the two calls — extremely unlikely in same `eth_call`), the entire function reverts. This is acceptable because:
- If `convertToAssets` reverts, `getPricePerShare` also reverts → accounting is already broken
- Wrapping inner calls in nested try/catch adds complexity for a near-zero-probability race condition

Note: The claimable redeem component uses `maxWithdraw(owner)` directly — no `convertToAssets` needed. The deposit-side components (`pendingDepositRequest`, `claimableDepositRequest`) return assets directly — also no conversion needed.

## Testing Plan

### Analysis Date: 2026-04-28

### Overview

Three test layers. No invariant testing infrastructure exists in the codebase today — this is the first invariant test suite.

| Layer | Tool | What | Files |
|-------|------|------|-------|
| **Unit** | Foundry `Test` | Individual methods, edge cases, fuzz | `test/unit/accounting/oracles/ERC7540YieldSourceOracle.t.sol` |
| **Invariant** | Foundry invariant (upgrade path: Recon/Echidna) | Stateful property testing across 3 mock vaults | `test/invariant/oracles/ERC7540Oracle*.sol` |
| **Integration** | Foundry fork | Real vaults on Base mainnet | `test/integration/oracles/ERC7540YieldSourceOracleIntegration.t.sol` |

### Three Mock 7540 Vault Implementations

All mocks implement `IERC7540Redeem` + ERC4626 basics but with different internal accounting.

#### 1. Vanilla7540Vault (strict ERC-7540 spec)

- `pendingRedeemRequest(0, c)` returns pending shares at current rate
- `claimableRedeemRequest(0, c)` returns claimable shares at current rate
- `convertToAssets()` uses current PPS (fluctuates freely)
- Shares removed from `balanceOf` on `requestRedeem`, moved to pending
- Shares removed from pending on `fulfillRedeem`, moved to claimable
- Shares removed from claimable on `claimRedeem`, assets delivered
- **Key behavior**: Pending value fluctuates with PPS changes between request and fulfillment

#### 2. Centrifuge7540Vault (global pricing model)

- PPS set by admin via `setPricePerShare()` (oracle-pushed, not market-driven)
- Fulfillment happens at admin-set global rate
- `claimableRedeemRequest` shares map exactly to `maxWithdraw(c)` — no slippage
- Uses `share()` function returning a separate ERC20 token (per ERC-7575)
- **Key behavior**: Deterministic pricing — claimable value is exact, not approximate

#### 3. YoStyle7540Vault (rate locked at request time)

- On `requestRedeem`: locks the current PPS in a mapping per controller
- `pendingRedeemRequest(0, c)` returns shares (spec-compliant externally)
- Internally tracks `lockedAssets[c]` — the fixed asset value from request time
- Fulfillment uses the locked rate, NOT current PPS
- Hybrid sync/async: if vault has enough liquid assets, `requestRedeem` fulfills immediately (pending stays 0)
- **Key behavior**: Pending value is stable regardless of PPS changes. Oracle converts pending shares at current PPS but actual delivery uses locked rate — the oracle slightly over/under-counts during PPS drift, but this is the accepted tradeoff (see Q1 in research).

#### Mock Handler API (shared across all three)

Each mock exposes these functions for the invariant fuzzer:

```
// Deposit flow
requestDeposit(controller, assets)  → assets sent to vault, enter pending deposit
fulfillDeposit(controller)          → move pending deposit → claimable deposit (operator action)
claimDeposit(controller)            → claimable deposit → shares minted to controller

// Redeem flow
requestRedeem(controller, shares)   → burn shares, enter pending redeem
fulfillRedeem(controller)           → move pending redeem → claimable redeem (operator action)
claimRedeem(controller)             → claimable redeem → assets transferred out

// State manipulation
setPPS(newPPS)                      → change exchange rate (appreciation/depreciation)
setPendingReverts(bool)             → toggle revert behavior for pendingRedeemRequest + pendingDepositRequest
setMaxWithdrawReverts(bool)         → toggle revert behavior for maxWithdraw
setClaimableDepositReverts(bool)    → toggle revert behavior for claimableDepositRequest
```

### Invariant Properties

#### INV-1: TVL Lower Bound

```
oracle.getTVLByOwnerOfShares(vault, c) >= vault.maxWithdraw(c)
```

TVL includes held + pending + claimable. `maxWithdraw` only counts immediately withdrawable (held + claimable for sync, just claimable for pure async). TVL must always be at least as large.

**Applies to**: All three mocks.

#### INV-2: No Over-Attribution

```
Σ oracle.getTVLByOwnerOfShares(vault, ci) <= oracle.getTVL(vault)
```

Sum of per-controller TVLs must not exceed vault's `totalAssets()`. The gap is value held by controllers the fuzzer doesn't track.

**Implementation**: Handler maintains `address[] controllers` array tracking all controllers created during the run.

**Applies to**: All three mocks.

#### INV-3: State Transition Preservation (Round-Trip)

```
// Redeem request: TVL preserved within same block (same PPS)
tvl_before_requestRedeem == tvl_after_requestRedeem

// Redeem claim: total value preserved (oracle TVL + asset balance)
(tvl_before_claimRedeem + assetBal_before) == (tvl_after_claimRedeem + assetBal_after)

// Deposit request: total value preserved (oracle TVL + asset balance)
// Assets leave controller's balance → enter oracle's pending deposit tracking
(tvl_before_requestDeposit + assetBal_before) == (tvl_after_requestDeposit + assetBal_after)

// Deposit claim: TVL preserved within same block
// Pending/claimable deposit exits → held shares enter at same rate
tvl_before_claimDeposit == tvl_after_claimDeposit  (within 1 wei rounding)
```

Value shouldn't leak between states in either direction.

**Implementation**: Handler records `tvl + assetBalance` snapshots before/after each action. Invariant checks delta == 0 (within 1 wei rounding for integer division).

**Applies to**: All three mocks. For YoStyle, request preservation holds because both the oracle and the locked rate use the same PPS at request time.

#### INV-4: Mutual Exclusivity (No Double-Count)

```
vault.balanceOf(c) + pendingShares(c) + claimableShares(c) <= totalSharesMinted(c) - totalSharesDestroyed(c)
```

The three pools (held, pending, claimable) must be disjoint per the 7540 spec. Handler tracks cumulative shares minted (deposits) and destroyed (claims fulfilled) per controller.

**Applies to**: All three mocks. This is the formal version of the "mutually exclusive" assumption in the Double-Count Risk Analysis section.

#### INV-5: Claimable Exactness (maxWithdraw)

```
// The claimable component of TVL must always equal maxWithdraw exactly
// (since we use maxWithdraw directly, not convertToAssets(claimableShares))
claimableComponent == vault.maxWithdraw(c)
```

Where `claimableComponent = oracle.getTVLByOwnerOfShares(vault, c) - heldValue - pendingValue`. This validates that the oracle's claimable component uses `maxWithdraw` and not a price-converted approximation. For Centrifuge vaults, `convertToAssets(claimableShares)` diverges from `maxWithdraw` whenever `latestPrice != redeemPrice_locked` — this invariant catches that class of bug.

**Applies to**: All three mocks (all should use `maxWithdraw` for claimable).

#### INV-6: Decimal Round-Trip

```
delta = |vault.convertToShares(vault.convertToAssets(10^decimals)) - 10^decimals|
delta <= 1  // within 1 wei
```

Catches Pendle-class decimal mismatch bugs where `share()` token decimals differ from asset decimals in unexpected ways.

**Implementation**: Run across all three mocks with both 6-decimal (USDC-like) and 18-decimal (WETH-like) underlying assets.

**Applies to**: All three mocks, both decimal configurations.

#### INV-7: Graceful Degradation

```
// When all async calls revert:
oracle.getTVLByOwnerOfShares(vault, c) == vault.convertToAssets(vault.balanceOf(c))
// Degrades to ERC4626-equivalent (held only)

// When only redeem calls revert:
// TVL = held + pendingDeposit + claimableDeposit (deposit-side still counted)

// When only deposit calls revert:
// TVL = held + pendingRedeem + claimableRedeem (redeem-side still counted)

// Never reverts entirely (convertToAssets is R1, but if that reverts the vault is broken anyway)
```

The mock vaults expose `setPendingReverts(bool)` / `setMaxWithdrawReverts(bool)` / `setClaimableDepositReverts(bool)`. The handler randomly toggles these. The invariant verifies the oracle degrades gracefully — drops components individually rather than reverting entirely.

**Applies to**: All three mocks.

#### INV-8: PPS Consistency

```
oracle.getPricePerShare(vault) == vault.convertToAssets(10 ** oracle.decimals(vault))
```

Trivial but catches any oracle implementation bug where `getPricePerShare` diverges from the vault's `convertToAssets`.

**Applies to**: All three mocks.

### Invariant Test Architecture

```
test/invariant/oracles/
├── ERC7540OracleInvariant.t.sol       # Foundry invariant test contract
│   - Deploys oracle + all 3 mock vaults
│   - Configures targetContract = handler
│   - Contains invariant_* functions for INV-1 through INV-8
│
├── ERC7540OracleHandler.sol           # Stateful handler (fuzzer entry point)
│   - Maintains: address[] controllers, uint256[] deposits, snapshots
│   - Actions: requestDeposit, fulfillDeposit, claimDeposit, requestRedeem, fulfillRedeem, claimRedeem, setPPS, toggleReverts
│   - Each action bounded to valid ranges (can't redeem more than balance, etc.)
│   - Records before/after snapshots for INV-3
│   - Runs against all 3 vaults (parameterized or sequential)
│
└── mocks/
    ├── Vanilla7540Vault.sol
    ├── Centrifuge7540Vault.sol
    └── YoStyle7540Vault.sol
```

**Handler design**: Single handler contract that targets one vault at a time. The invariant test contract runs the full suite against each mock vault in separate test functions:

```solidity
function setUp() public {
    oracle = new ERC7540YieldSourceOracle(address(ledgerConfig));
    vanillaVault = new Vanilla7540Vault(address(asset), 18);
    centrifugeVault = new Centrifuge7540Vault(address(asset), 18);
    yoStyleVault = new YoStyle7540Vault(address(asset), 18);

    vanillaHandler = new ERC7540OracleHandler(oracle, vanillaVault, asset);
    centrifugeHandler = new ERC7540OracleHandler(oracle, centrifugeVault, asset);
    yoStyleHandler = new ERC7540OracleHandler(oracle, yoStyleVault, asset);

    // Target all handlers — fuzzer randomly picks actions across all 3
    targetContract(address(vanillaHandler));
    targetContract(address(centrifugeHandler));
    targetContract(address(yoStyleHandler));
}
```

### Unit Tests (Layer 1)

File: `test/unit/accounting/oracles/ERC7540YieldSourceOracle.t.sol`

Mirrors `YoYieldSourceOracleTest.t.sol` structure:

| Category | Tests |
|----------|-------|
| **Decimals** | 6 and 18 decimal vaults, `share()` token decimals match |
| **getShareOutput** | `convertToShares` delegation, fuzz amounts |
| **getWithdrawalShareOutput** | Ceil rounding, zero PPS edge case |
| **getAssetOutput** | `convertToAssets` delegation |
| **getPricePerShare** | 6/18 decimals, PPS changes reflected, zero check |
| **getBalanceOfOwner** | Excludes pending/claimable, uses `share()` token |
| **getTVLByOwnerOfShares** | No async (steady state), includes pendingRedeem, includes claimableRedeem (maxWithdraw), includes pendingDeposit, includes claimableDeposit, all 5 components, zero position |
| **Redeem round-trip** | TVL unchanged after requestRedeem (same block), TVL + balance unchanged after claimRedeem |
| **Deposit round-trip** | TVL + balance unchanged after requestDeposit, TVL unchanged after claimDeposit |
| **Try/catch degradation** | Redeem calls revert → held + deposit-side only, deposit calls revert → held + redeem-side only, all async revert → held only |
| **getAsyncStateBreakdown** | Returns 5 components matching getTVLByOwnerOfShares sum, each component correct individually |
| **Edge cases** | Small amounts (1 wei), large amounts (uint128.max), non-1:1 PPS, 6-decimal vault full cycle |
| **Fuzz** | `testFuzz_getTVLByOwnerOfShares(held, pendingRedeem, claimableRedeem, pendingDeposit, claimableDeposit)` |

### Integration Tests (Layer 3)

File: `test/integration/oracles/ERC7540YieldSourceOracleIntegration.t.sol`

Fork Base mainnet. Test against:
- **Centrifuge vaults** (if deployed on Base — `poolId`/`trancheId` based)
- **Yo vaults** (yoETH, yoUSD, yoBTC) via 7540 interface (Yo implements both IYoVault and ERC-7540)
- **Any other 7540 vault** deployed on Base

| Test | What |
|------|------|
| Interface compatibility | All IERC7540Redeem methods callable without revert |
| Oracle PPS matches vault | `getPricePerShare()` == `convertToAssets(10^decimals)` |
| Deposit → TVL tracking | Deposit real assets, verify TVL reflects position |
| RequestRedeem → TVL stability | Request redeem, verify TVL unchanged |
| Real pending/claimable holders | Query known strategy addresses for non-zero pending |
| Multi-vault batch query | `getTVLByOwnerOfSharesMultiple` across mixed vault types |

### Tooling: Foundry vs Recon/Echidna

**Phase 1 (now)**: Foundry invariant testing.
- Zero setup — same `forge test --mt invariant` workflow
- Handler pattern established
- Good for verifying 8 properties across 3 mocks
- Run time: minutes per CI run

**Phase 2 (if Recon subscription active)**: Port to Recon/Chimera.
- Same handler + invariant contracts, different runner
- Coverage-guided fuzzing finds deeper state sequences
- Corpus management for regression testing
- Run time: hours/days for thorough campaigns
- The Foundry handler doubles as a Chimera target with minimal changes

**Decision**: Start Foundry, upgrade to Recon only if Foundry fuzzing misses edge cases or we want longer campaigns for pre-audit confidence.

### Test File Summary

| File | Layer | Create/Modify |
|------|-------|---------------|
| `test/mocks/Vanilla7540Vault.sol` | Mock | Create |
| `test/mocks/Centrifuge7540Vault.sol` | Mock | Create |
| `test/mocks/YoStyle7540Vault.sol` | Mock | Create |
| `test/unit/accounting/oracles/ERC7540YieldSourceOracle.t.sol` | Unit | Create |
| `test/invariant/oracles/ERC7540OracleHandler.sol` | Invariant | Create |
| `test/invariant/oracles/ERC7540OracleInvariant.t.sol` | Invariant | Create |
| `test/integration/oracles/ERC7540YieldSourceOracleIntegration.t.sol` | Integration | Create |

## Key Files

- `src/accounting/oracles/YoYieldSourceOracle.sol` — reference implementation with pending tracking
- `src/accounting/oracles/SuperVaultYieldSourceOracle.sol` — needs pending tracking added
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` — base class for all oracles
- `src/vendor/standards/ERC7540/IERC7540Vault.sol` — standard 7540 interfaces
- `src/vendor/yo/IYoVault.sol` — Yo-specific interface (non-standard pending signature)
- `src/hooks/vaults/7540/*.sol` — all 12 existing 7540 hooks
- `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol` — deleted oracle (4626 clone, NO pending tracking)
- `v2-periphery/src/SuperVault/SuperVault.sol` — SuperVault impl (totalAssets uses stored PPS)
- `v2-periphery/src/SuperVault/SuperVaultAggregator.sol` — PPS storage + forwardPPS() entry point
- `v2-periphery/src/SuperVault/SuperVaultStrategy.sol` — strategy with yield source tracking
- `supervault-pricing/app/services/supervault.py` — keeper PPS computation
- `supervault-pricing/app/services/yield_source.py` — keeper calls getTVLByOwnerOfShares onchain
