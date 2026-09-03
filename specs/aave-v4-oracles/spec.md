# Aave V4 Oracles Spec

## Metadata
- Project: SuperVaults strategies support
- Milestone: Aave V4 / Base tokenized-equities integration
- Linear Issue: SUP-20854
- Interview Date: 2026-09-02
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Aave V4 has no Superform accounting oracle on either side, leaving V4 positions (including the new Base tokenized-equities markets) invisible to SuperLedger-family consumers. This spec adds three contracts: **`AaveV4DebtOracle`** (Euler-shaped identity-PPS oracle over `getUserDebt` drawn+premium), **`AaveV4SupplyYieldSourceOracle`** (identity-PPS asset-denominated; fee view bypass-overridden for the standalone phase per PR #997 review F1), and **`AaveV4ReserveRegistry`** (hash-derived pseudo-address keys for `(spoke, reserveId)` pairs, MorphoBlueMarketRegistry governance model). Plus a two-function extension of the vendored `IAaveV4Spoke` for reserve-level TVL aggregates.

Scope-defining finding from research: **all loan hooks are `NONACCOUNTING`** — no loan hook calls `SuperLedger.updateAccounting` today, and the deployed Euler/MorphoBlue debt oracles are equally hook-unwired. These are therefore **standalone accounting oracles** (monitoring/periphery/off-chain consumption), precedent-identical; live fee-pipeline wiring is explicitly out of scope (follow-up ticket). This also forces the supply oracle to identity/asset-denomination (hooks measure wallet deltas in asset units; V4 has no share token).

## Requirements

### Functional
1. Debt oracle reports accrued debt (drawn + premium) in borrow-asset units; identity PPS; reserve-level `getTVL` via `getReserveDebt`; fee-bypass override on `getAssetOutputWithFees`.
2. Supply oracle reports supplied assets; identity PPS; reserve-level `getTVL` via `getReserveSuppliedAssets`; `getAssetOutputWithFees` bypass-overridden for the standalone phase (REVISED per PR #997 F1 — no cost-basis snapshots exist without hook wiring, so the inherited fee view could fee principal); feePercent = 0 operational invariant applies to BOTH oracles until accounting hooks exist.
3. Registry: hash-derived keys (`keccak256(spoke, reserveId)` → pseudo-address, rebinding impossible by construction), `computeReserveKey` preview, register-time on-chain validation, add-only + 2-day timelocked deregistration, typed errors, shared by both oracles.
4. Unregistered keys revert typed on every view (never return 0).

### Non-Functional
- View-only, immutable, constructor-light oracles; registry is the only writable surface (role-gated).
- No price feeds anywhere (own-asset denomination; equity trading-hours staleness stays at Aave's layer).
- feePercent = 0 operational invariant on the debt oracle (NatSpec + runbook + executable test; no on-chain guard, per precedent).
- Fresh generated + locked-bytecode artifacts (PR #990 R1 lesson); house style per MorphoBlue security-report checklist.

## Technical Design

### Architecture
Registry-first: `MARKET_MANAGER_ROLE` registers `(spoke, reserveId)` → validated via `spoke.getReserve(reserveId)` → stored with `underlying`/`decimals`. Both oracles resolve keys through the shared registry and read the same spoke views the V2 loan hooks use (`getUserDebt`, `getUserSuppliedAssets`), keeping hook-side and oracle-side numbers definitionally consistent. Full diagram + contract specs in [technical-spec.md](./technical-spec.md).

### Data Model
Registry storage: `mapping(address key => ReserveInfo{spoke, reserveId, underlying, decimals})` + deregistration proposals. No oracle storage beyond immutables.

### API Changes
`IAaveV4Spoke` + `getReserveDebt(uint256)`, `getReserveSuppliedAssets(uint256)` (both verified upstream).

## Implementation Plan

### Phase 0: Gate (question list: [joao-call-sheet.md](./joao-call-sheet.md); PR #997 review F2 blocks on these)
- [ ] Joao call: confirm Base equities use plain `ISpoke`, NOT `TokenizationSpoke` (if TokenizationSpoke → existing `ERC4626YieldSourceOracle` covers it, deliverable shrinks)
- [ ] Collect Base equities spoke address + reserve ids

### Phase 1: Contracts
- [ ] Extend `IAaveV4Spoke`; write registry + both oracles per technical spec

### Phase 2: Tests
- [ ] Unit suite (T1–T9: fee-misconfig demo, zero edges, unregistered-key, registry lifecycle/validation, decimals independence, batch known-issue, hook-consistency anchor)
- [ ] Fork suite (F1–F4: in-view accrual, repay-to-zero consistency with SUP-20842, pause-liveness, real-market registration; Ethereum spoke now, Base when known)

### Phase 3: Tooling & review
- [ ] Bytecode regeneration + locked-dev twins; Constants keys/salts; DeployV2Core wiring; verification records; per-chain outputs
- [ ] Ledger-config runbook (debt id feePercent = 0); deployment matrix of live-spoke chains
- [ ] 3-agent security review → `specs/security-reports/`

## Test Plan
- [ ] Unit tests for: both oracles (all views, fee paths, zero/fuzz edges), registry (lifecycle, validation, key derivation property)
- [ ] Integration tests for: pinned-block fork reads against the live spoke (accrual, hook-consistency, pause behavior)
- [ ] E2E tests for: registration → hook-executed position → oracle reads match hook-observed state (fork)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| feePercent > 0 on debt oracle | Vault Accounting | Low | High | Override + NatSpec + runbook + executable test; inert until future wiring | Compound Prop 62 — $80M+ |
| TokenizationSpoke for equities | Business Logic | Medium | High | Phase 0 gate | — |
| Registry key rebinding | Access Control | ~0 | High | Hash-derived keys by construction | Morpho registry |
| V4 API drift (pre-hardening) | Operational | Medium | Medium | Interface pinning + fork tests + spoke-upgrade monitoring | — |
| Views revert when paused | Operational | Low | Medium | Fork test F3 + Joao confirmation | Venus/LUNA 2022 |
| Same reserve under two spokes | Operational | Low | Medium | Documented accepted risk + runbook rule | — |
| Read-only reentrancy | Reentrancy | Low | Low | No ratio math; reads inside own executor flow; documented | Sentiment 2023 — $1M |
| Deregister with live positions | Operational | Low | High | SAFETY INVARIANT + 2-day timelock | Morpho registry |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Scope | Debt + supply pair; V3 out | Cosmin (interview) |
| Keying | Registry, MorphoBlue model; hash-derived keys mandatory | Cosmin + security research |
| Accounting wiring | Standalone oracles; wiring = follow-up ticket | SpecFlow Finding A + precedent |
| Supply oracle shape | Identity/asset-denominated (forced by hook architecture) | SpecFlow Finding C |
| Debt fee guard | Operational invariant + Morpho-style view-path override | Cosmin + security review P2-1 precedent |
| Supply fees | Fee-capable shape; config decides; yield fees await wiring | Cosmin (interview) |
| Valuation | Own-asset units, no price feeds | Cosmin (interview) |
| Chains | All chains with live V4 spokes; Base first | Cosmin (interview) |
| RWA caveats | Documented risks only; hook-layer | Cosmin (interview) |

**Still open (Joao call 2026-09-03):** plain-Spoke-vs-TokenizationSpoke (gate); Base spoke address/ids; premium rounding; bad-debt socialization in supply reads; view liveness under pause; B20 transfer hooks; reserveId permanence guarantees; incentive mechanism.

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
After approval, run: `/superform:work specs/aave-v4-oracles/technical-spec.md`
