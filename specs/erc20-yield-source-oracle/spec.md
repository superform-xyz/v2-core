# ERC20YieldSourceOracle Spec

## Metadata
- Project: SuperMAG7 on BSC (SuperVaults)
- Milestone: BSC staging vault (tokenized stocks)
- Linear Issue: N/A
- Interview Date: 2026-09-15
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary
A ~120-line stateless identity-PPS oracle (`src/accounting/oracles/ERC20YieldSourceOracle.sol`)
so plain ERC20 tokens — first: BSC tokenized stocks NVDAb/TSLAb held directly by the SuperMAG7
strategy — can be whitelisted as SuperVault yield sources. The strategy's whitelist requires
every source to carry an `IYieldSourceOracle`; the stored oracle address doubles as the type
discriminator for the off-chain validator network, which prices
`getBalanceOfOwner(token, strategy)` against off-chain stock prices. One instance serves all
tokens (no registry, no admin, no state). All pricing stays off-chain; supervault-pricing and
periphery need zero code changes.

## Requirements

### Functional
1. Implement all 8 abstract `IYieldSourceOracle` views with identity semantics: decimals
   passthrough, PPS = 10^decimals, pure identity converters (assetIn ignored),
   balance/ownerTVL = `balanceOf`, TVL = `totalSupply` (monitoring-only, NatSpec-pinned).
2. `getAssetOutputWithFees` bypass override (post-PR-#997 shape) — never consults the ledger.
3. Constructor zero-check + interface-parity NatSpec; no other validation (decimals() probe is
   the natural non-ERC20 gate).
4. Fleet-wide deploy wiring (bytecode script, DeployV2Core oracle list, Constants key, verify
   script both cases, fresh artifacts).

### Non-Functional
- feePercent = 0 operational invariant triple-anchored (NatSpec + runbook + executable tests);
  FlatFeeLedger registration categorically forbidden.
- Rebasing / fee-on-transfer tokens documented out of scope; whitelister owns token
  due-diligence (single entry point, corporate actions, blocklist semantics).
- House style: 0.8.30, custom errors, `@inheritdoc`, stateless (no events).

## Technical Design

### Architecture
Pure view leaf extending `AbstractYieldSourceOracle`; structural template =
`ERC4626YieldSourceOracle` (global instance, registry-free) × Euler/AaveV4 identity math +
Morpho/AaveV4 fee-bypass. No on-chain consumer today; validator network + monitoring read it
off-chain via the strategy's stored (token → oracle) metadata. Full table + skeleton:
[technical-spec.md](./technical-spec.md).

### Data Model
None (stateless; one inherited immutable).

### API Changes
None to interfaces; new contract only.

## Implementation Plan

### Phase 1: Contract + tests
- [ ] ERC20YieldSourceOracle.sol per skeleton
- [ ] Unit suite T1–T8 (identity fuzz, decimals boundary, balance/TVL tracking, fee-bypass proof
      vs MockZeroCostBasisLedger AND FlatFeeLedger + hazard-documentation test, real-ledger
      round trip, non-ERC20 sweep, batch isolation/known-issue pins, rebasing doc test)
- [ ] Optional BSC fork parity test if B-token addresses confirmed (Venus VIP-654)

### Phase 2: Wiring + ops
- [ ] 6 mechanical deploy-tooling edits (verified locations in research/repo-analysis.md §4)
- [ ] Runbook: never register in SuperLedgerConfiguration; per-token whitelisting checklist;
      manager = multisig

## Test Plan
- [ ] Unit tests for: all 8 views, fee bypass (both ledgers), decimals boundary, batch behavior,
      non-ERC20 inputs, rebasing documentation — bar: EulerDebtOracle.t.sol suite
- [ ] Integration tests for: real SuperLedgerConfiguration + BaseLedger round trip (fee = 0 on
      principal)
- [ ] E2E/fork (optional): BSC B-token read parity + canonical-entry-point assertion

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Oracle id registered with fee > 0 (esp. FlatFeeLedger → full principal taxed) | Vault Accounting | Low | High | Bypass override (view path) + triple-anchored feePercent=0 invariant + executable hazard test | Compound Prop 62 ~$80M; Moonwell 2025 $1.8M (config-not-code); PR #997 F1 |
| Double-entry token whitelisted → off-chain double-count → PPS inflation → extraction via mint/redeem | Token Behavior | Low | High | Ops whitelisting checklist (single-entry verification) + executable canonical-entry check | Compound TUSD sweepToken 2021 |
| Rebasing/corporate-action (stock split) shifts balances between price snapshots | Token Behavior | Medium | Medium | Declared out of scope + executable doc test + issuer mechanism confirmed in writing pre-whitelist | Aave AMPL class |
| Blocklisted/paused strategy holdings still read as full NAV | Operational | Low | Medium | Documented; monitoring concern (reads live ≠ redeemable) | rsETH 2026 framing |
| One broken token poisons unisolated batch views | Operational | Medium | Low | Inherited fleet behavior; documented + known-issue test pin | — |
| Hostile token lies about balanceOf | Business Logic | Low | High | Trust model: manager whitelists (multisig, never hot EOA); garbage-in-garbage-out like whole fleet | Term Finance 2026 / KiloEx 2025 (role capture) |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| getTVL semantics | totalSupply(), monitoring-only, NatSpec-pinned | Cosmin (interview) |
| Fee view | Bypass override, post-#997 shape | Cosmin (interview) |
| Validation | decimals() probe only; trust model = manager | Cosmin (interview) |
| Deploy scope | Fleet-wide | Cosmin (interview) |
| assetIn | Ignored (fleet precedent) | Cosmin (interview) |
| Weird tokens | Rebasing + FoT documented out of scope | Cosmin (interview) |
| Delivery | Branch `feat/erc20-yield-source-oracle` off dev; no commit/push until approved | Cosmin (interview) |
| On-chain stock price path | Deferred to Binance conversation; UpdateOracle migration path exists | Vik/Kurisu (Slack) |

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
After approval, run: `/superform:work specs/erc20-yield-source-oracle/technical-spec.md`
