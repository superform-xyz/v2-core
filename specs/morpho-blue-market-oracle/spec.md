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

Before executing `executeDeregisterMarket(marketKey)`:

1. **Check SuperLedgerConfiguration**: Is this oracle registered for fee calculation on any SuperVault referencing this `marketKey`?
2. **Check active positions**: Query `oracle.getBalanceOfOwner(marketKey, account)` for all accounts with positions. If any return non-zero supply shares, those accounts hold active positions.
3. **If positions exist**: Do NOT deregister. The oracle reverting post-deregistration will brick performance fee calculations on outflows — users cannot withdraw through SuperLedger without the oracle returning a valid PPS.
4. **Safe to proceed**: Only deregister when no active Superform-managed positions reference the market, OR the oracle is not registered in SuperLedgerConfiguration.

The 2-day timelock provides a window to catch mistakes via monitoring alerts on `MarketDeregistrationProposed` events.

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
