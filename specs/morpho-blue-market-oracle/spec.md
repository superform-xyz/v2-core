# Morpho Blue Market Oracle Spec

## Metadata
- Project: v2-core
- Milestone: Morpho Blue Integration
- Linear Issue: N/A
- Interview Date: 2026-06-26
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

---

## Summary

Morpho Blue markets have no contract address — they are identified by a `MarketParams` struct. Superform's oracle system requires a `yieldSourceAddress` (an `address`). This spec introduces two contracts to bridge that gap:

**`MorphoBlueMarketWrapper`** is a zero-storage immutable wrapper that gives any Morpho Blue market an addressable identity. It is permissionlessly deployable by anyone; its constructor validates the market exists on Morpho via `idToMarketParams`.

**`MorphoBlueYieldSourceOracle`** is an `AbstractYieldSourceOracle` implementation that reads Morpho's on-chain state and replicates interest accrual in a **pure view context** (calling `IIrm.borrowRateView` + `MathLib.wTaylorCompounded`) to return fresh, accurate price-per-share and share/asset conversions for supply-side (lender) positions.

Scope: supply-side only, all chains where Morpho Blue is deployed, standalone (no `SuperLedgerConfiguration` registration yet).

---

## Requirements

### Functional

1. A `MorphoBlueMarketWrapper` can be deployed by anyone for any valid Morpho Blue market; it stores `MarketParams` as immutables and reverts construction for non-existent markets
2. `MorphoBlueYieldSourceOracle` implements all 8 abstract methods of `AbstractYieldSourceOracle` using accrued (not stale) market state
3. Price-per-share reflects real accrued interest at `block.timestamp` even when Morpho's stored state hasn't been updated
4. Rounding favors the protocol in all conversions: `toSharesDown` for deposits, `toSharesUp` for withdrawals, `toAssetsDown` for value display
5. Zero-IRM markets (no borrowers) return stored state without reverting
6. The oracle is chain-agnostic — one deployment per chain, works for any market via its wrapper

### Non-Functional

- No storage writes — fully view-only, reentrancy-safe by design
- Bit-exact parity: `_getAccruedMarketState` output matches `MorphoBalancesLib.expectedMarketBalances` for any market at any block
- Zero additional gas overhead compared to directly querying Morpho (no state-changing calls)

---

## Technical Design

### Architecture

```
User/Monitoring ──► MorphoBlueYieldSourceOracle
                         │
                         ▼ (reads wrapper)
                   MorphoBlueMarketWrapper
                         │  (validates at construction)
                         ▼
                   IMorphoStaticTyping (Morpho Blue singleton)
                         │
                         ▼ (IRM call for borrow rate)
                   IIrm.borrowRateView (AdaptiveCurveIRM)
```

### Data Flow — `_getAccruedMarketState`

1. Read `MarketParams` from wrapper (5 immutables)
2. Read stale market state: `IMorphoStaticTyping.market(id)` → (`totalSupplyAssets`, `totalSupplyShares`, `totalBorrowAssets`, `totalBorrowShares`, `lastUpdate`, `fee`)
3. Compute `elapsed = block.timestamp - lastUpdate`
4. If `elapsed > 0 && totalBorrowAssets > 0 && irm != address(0)`:
   - `borrowRate = IIrm(irm).borrowRateView(marketParams, market)`
   - `interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed))`
   - `totalSupplyAssets += interest`; `totalBorrowAssets += interest`
   - If `fee > 0`: mint `feeShares = feeAmount.toSharesDown(totalSupplyAssets - feeAmount, totalSupplyShares)`; `totalSupplyShares += feeShares`
5. Return `AccruedState`

---

## Implementation Plan

### Phase 1: Contracts ✅
- [x] `src/accounting/oracles/MorphoBlueMarketWrapper.sol`
- [x] `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol`
- [x] **Fixed**: Added `&& mp.irm != address(0)` third condition + inner scoped blocks (stack-too-deep)

### Phase 2: Fork Tests ✅
- [x] `test/integration/morpho/MorphoBlueMarketFork.t.sol` — wrapper + oracle isolation tests
- [x] E2E hook lifecycle tests: `MorphoLendHook` supply → oracle → `MorphoWithdrawHook` withdraw (2 markets)
- [x] Fuzz tests: round-trip, PPS monotonic, supply invariant, rounding, TVL consistency
- **39/39 tests passing**

### Phase 3: Deployment (deferred)
- Deployment script not needed yet — oracle is standalone (no SuperLedgerConfiguration registration at this stage)
- When registration is added in the future, a single `DeployMorphoBlueOracle.s.sol` script handles all supported chains

---

## Test Plan

- [x] Unit/fork: wrapper stores params, computes correct ID, rejects invalid market, has no storage
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
| IRM doesn't implement `borrowRateView` | Oracle | Very Low | DoS for that market | Document; governance-whitelisted IRMs only | — |
| `wrapper.morpho()` pointing to fake Morpho | Access Control | Low | Wrong PPS from fake data | Registry must validate canonical Morpho address | — |
| IRM upgrade turns malicious (inflate PPS) | Oracle | Extremely Low | PPS manipulation → wrong TVL | Production AdaptiveCurveIRM is immutable | PAXG/USDC oracle misconfiguration $230K (2024) |
| `elapsed` accumulation on dormant market produces uint128 divergence | Business Logic | Very Low | Silent PPS overstatement for bricked markets | Add inline comment; test realistic bounds | — |
| ERC-777 loan token view reentrancy | Reentrancy | Very Low | Mid-supply inconsistency | Morpho explicitly unsupports re-entrant tokens | dForce $3.7M read-only reentrancy (2023) |

---

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Supply-side only or also borrow? | Supply-side only | Interview |
| Who deploys wrappers? | Permissionless | Interview |
| Stale state vs view replication? | View replication (borrowRateView) | Interview |
| Which chains? | All chains where Morpho Blue exists | Interview |
| Zero-IRM behavior? | Return stored state, no accrual | Interview |
| Register in SuperLedgerConfiguration? | Standalone only for now | Interview |
| Market scope? | Generic — any market via wrapper | Interview |
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
