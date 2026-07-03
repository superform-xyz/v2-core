# Morpho Blue Market Oracle Spec

## Metadata
- Project: v2-core
- Milestone: Morpho Blue Integration
- Linear Issue: N/A
- Interview Date: 2026-06-26
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

---

## Summary

Morpho Blue markets have no contract address — they are identified by a `MarketParams` struct. Superform's oracle system requires a `yieldSourceAddress` (an `address`). This spec introduces two contracts to bridge that gap:

**`MorphoBlueMarketRegistry`** is a permissioned singleton registry (AccessControl with `MARKET_MANAGER_ROLE`) that maps pseudo-addresses to `MarketParams`. The pseudo-address is derived from the lower 20 bytes of the 32-byte keccak256 Morpho market ID: `address(uint160(uint256(Id.unwrap(marketId))))`. It enforces an IRM whitelist to prevent rogue IRMs from corrupting PPS, and uses a 2-day timelock for deregistration.

**`MorphoBlueYieldSourceOracle`** is an `AbstractYieldSourceOracle` implementation that reads Morpho's on-chain state and replicates interest accrual in a **pure view context** (calling `IIrm.borrowRateView` + `MathLib.wTaylorCompounded`) to return fresh, accurate price-per-share and share/asset conversions for supply-side (lender) positions.

Scope: supply-side only, all chains where Morpho Blue is deployed, standalone (no `SuperLedgerConfiguration` registration yet).

**Accounting unit:** All values (PPS, TVL, asset conversions) are denominated in the market's **loanToken** — the token suppliers deposit and earn interest on. This is a Morpho supply-position oracle, not an equity/NAV oracle. It does not report collateral token value, USD prices, or the Morpho market oracle price used for LTV calculations. If downstream surfaces need USD or collateral-denominated values, an additional price feed must be composed on top.

---

## Requirements

### Functional

1. `MorphoBlueMarketRegistry` is a permissioned singleton — only `MARKET_MANAGER_ROLE` can register/deregister markets; IRMs must be pre-approved via `setIrmApproval` (zero-IRM markets are always permitted)
2. Market deregistration requires a 2-day timelock (`proposeDeregisterMarket` → wait → `executeDeregisterMarket`) to prevent accidental removal
3. `MorphoBlueYieldSourceOracle` implements all 8 abstract methods of `AbstractYieldSourceOracle` using accrued (not stale) market state
4. `decimals()` returns `loanToken.decimals() + 6` to account for Morpho's `VIRTUAL_SHARES = 1e6` offset, ensuring PPS has sufficient precision for low-decimal tokens
5. Price-per-share reflects real accrued interest at `block.timestamp` even when Morpho's stored state hasn't been updated
6. Rounding favors the protocol in all conversions: `toSharesDown` for deposits, `toSharesUp` for withdrawals, `toAssetsDown` for value display
7. Zero-IRM markets (no borrowers) return stored state without reverting
8. The oracle is chain-agnostic — one deployment per chain, works for any registered market

### Non-Functional

- No storage writes in the oracle — fully view-only, reentrancy-safe by design
- Bit-exact parity: `_getAccruedMarketState` output matches `MorphoBalancesLib.expectedMarketBalances` for any market at any block
- Zero additional gas overhead compared to directly querying Morpho (no state-changing calls)

---

## Technical Design

### Architecture

```
User/Monitoring ──► MorphoBlueYieldSourceOracle
                         │
                         ▼ (reads registry)
                   MorphoBlueMarketRegistry
                         │  (stores MarketParams + morpho address)
                         ▼
                   IMorphoStaticTyping (Morpho Blue singleton)
                         │
                         ▼ (IRM call for borrow rate)
                   IIrm.borrowRateView (AdaptiveCurveIRM)
```

### Market Identity

Markets are keyed by a pseudo-address: `address(uint160(uint256(Id.unwrap(marketId))))` — the lower 20 bytes of the 32-byte keccak256 Morpho market ID. Collision probability via birthday paradox is negligible (~2^-80 for 2^20 markets); a collision merely prevents registration of the second market.

### Data Flow — `_getAccruedMarketState`

1. Read `MarketParams` and `morpho` address from `MorphoBlueMarketRegistry.getMarketInfo(yieldSourceAddress)`
2. Read stale market state: `IMorphoStaticTyping.market(id)` → (`totalSupplyAssets`, `totalSupplyShares`, `totalBorrowAssets`, `totalBorrowShares`, `lastUpdate`, `fee`)
3. Compute `elapsed = block.timestamp - lastUpdate`; cap at 365 days
4. If `elapsed > 0 && totalBorrowAssets > 0 && irm != address(0)`:
   - `borrowRate = IIrm(irm).borrowRateView(marketParams, market)`
   - `interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed))`
   - `totalSupplyAssets += interest`; `totalBorrowAssets += interest`
   - If `fee > 0`: mint `feeShares = feeAmount.toSharesDown(totalSupplyAssets - feeAmount, totalSupplyShares)`; `totalSupplyShares += feeShares`
5. Return `AccruedState`

---

## Implementation Plan

### Phase 1: Contracts
- [x] `src/accounting/oracles/MorphoBlueMarketRegistry.sol` — permissioned registry with IRM whitelist and timelocked deregistration
- [x] `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol` — singleton oracle reading from registry
- [x] **Fixed**: Added `&& mp.irm != address(0)` third condition + inner scoped blocks (stack-too-deep)
- [x] **Fixed (P1.1)**: `decimals()` returns `loanDec + 6`, `getPricePerShare()` prices `10^(loanDec+6)` shares

### Phase 2: Fork Tests
- [x] `test/integration/morpho/MorphoBlueMarketFork.t.sol` — registry + oracle isolation tests
- [x] E2E hook lifecycle tests: `MorphoLendHook` supply → oracle → `MorphoWithdrawHook` withdraw (2 markets)
- [x] Fuzz tests: round-trip, PPS monotonic, supply invariant, rounding, TVL consistency

### Phase 3: Deployment (deferred)
- Deployment script not needed yet — oracle is standalone (no SuperLedgerConfiguration registration at this stage)

---

## Test Plan

- [x] Unit/fork: registry stores params, computes correct market key, rejects invalid market, enforces IRM whitelist
- [x] Fork: decimals, PPS non-zero, PPS increases with time warp, TVL non-zero
- [x] Fork: conversions consistent, round-trip no value creation, balance zero for fresh address
- [x] Fork: supply reflects in oracle, supply doesn't change PPS, full supply+withdraw lifecycle
- [x] Fork: withdrawal shares >= deposit shares, batch methods
- [ ] Fork E2E: MorphoLendHook + oracle + MorphoWithdrawHook full lifecycle (2 markets)
- [ ] Fuzz: round-trip invariant, PPS monotonic, supply-PPS invariant, rounding, accrual bounds

---

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| IRM doesn't implement `borrowRateView` | Oracle | Very Low | DoS for that market | IRM whitelist in registry; document known limitation | — |
| Rogue IRM returns malicious `borrowRateView` | Oracle | Extremely Low | PPS manipulation | IRM whitelist enforced at registration; only pre-approved IRMs allowed | PAXG/USDC oracle misconfiguration $230K (2024) |
| `elapsed` accumulation on dormant market produces uint128 divergence | Business Logic | Very Low | Silent PPS overstatement | 365-day cap on elapsed in oracle | — |
| ERC-777 loan token view reentrancy | Reentrancy | Very Low | Mid-supply inconsistency | Morpho explicitly unsupports re-entrant tokens | dForce $3.7M read-only reentrancy (2023) |
| Market key collision (birthday paradox) | Registry | Negligible (~2^-80) | Cannot register second market | Collision only blocks registration; no overwrite | — |
| Deregistration bricks outflow accounting | Ops | Low | Performance fee reverts | Ops-runbook check: verify no active positions before deregistering (see below) | — |

---

## Ops Runbook — Market Deregistration

**Invariant: Do NOT deregister a market with active Superform accounting positions.**

A deregistered market makes the oracle revert `MARKET_NOT_REGISTERED` for that key. Any live read — PPS, TVL, fee preview, outflow accounting — will fail. Users cannot withdraw through SuperLedger without the oracle returning a valid PPS. The market must be fully migrated or deprecated before deregistration.

### Pre-execution checklist

Before calling `executeDeregisterMarket(marketKey)`, all of the following must be true:

1. **SuperLedgerConfiguration**: The oracle is NOT registered for fee calculation on any SuperVault referencing this `marketKey`. Unregister it first.
2. **SuperVault / monitoring configs**: No SuperVault strategy or monitoring config references this `marketKey`.
3. **Active positions**: Query `oracle.getBalanceOfOwner(marketKey, account)` for all accounts with positions. All must return zero supply shares (fully withdrawn or migrated).
4. **If any check fails**: Call `cancelDeregisterMarket(marketKey)` to abort.

### Monitoring

- Alert on `MarketDeregistrationProposed` events — the 2-day timelock window is the safety net.
- If a `MarketDeregistered` event fires for a market with active positions, immediately re-register the market via `registerMarket` with the same params to restore oracle reads.

---

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Supply-side only or also borrow? | Supply-side only | Interview |
| Permissionless wrappers or permissioned registry? | Permissioned registry (shipped design) | Implementation decision |
| Stale state vs view replication? | View replication (borrowRateView) | Interview |
| Which chains? | All chains where Morpho Blue exists | Interview |
| Zero-IRM behavior? | Return stored state, no accrual | Interview |
| Register in SuperLedgerConfiguration? | Standalone only for now | Interview |
| Precision requirement? | Bit-exact with MorphoBalancesLib | Interview |

---

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/morpho-blue-market-oracle/technical-spec.md`
