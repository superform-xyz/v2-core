# ERC7540YieldSourceOracle Spec

## Metadata
- Project: Superform v2-core
- Milestone: Accounting Hardening
- Linear Issue: N/A
- Interview Date: 2026-04-27 through 2026-04-29
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Build an `ERC7540YieldSourceOracle` that tracks the full value of smart account positions in ERC-7540 async vaults using a five-component formula: `held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit`. The existing oracle infrastructure only tracks `balanceOf` (held shares), creating artificial PPS drops when shares enter async redemption or deposit states — exploitable via deposit/withdraw timing.

The oracle extends `AbstractYieldSourceOracle`, uses `maxWithdraw(controller)` for the claimable redeem component (handles Centrifuge locked redeemPrice), and implements hybrid error handling where `getPricePerShare` hard reverts while `getTVLByOwnerOfShares` wraps each async component in try/catch for graceful degradation.

## Requirements

### Functional
1. Five-component TVL: held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit
2. `getPricePerShare()` delegates to `convertToAssets(10^decimals)` — hard revert on failure
3. `getTVLByOwnerOfShares()` reads all 5 components with per-component try/catch
4. `getAsyncStateBreakdown()` returns 5 components individually (monitoring instrumentation)
5. `maxWithdraw(controller)` for claimable redeem value (not `convertToAssets(claimableShares)`)
6. `REQUEST_ID` as immutable constructor param (default 0)
7. Uses ERC-7575 `share()` for separate share token discovery
8. `convertToShares` for `getShareOutput` (not `previewDeposit` — may revert on async)
9. Manual inverse for `getWithdrawalShareOutput` (previewWithdraw reverts on async)

### Non-Functional
- View-only oracle — no state mutations, no storage writes
- Extends `AbstractYieldSourceOracle` base class
- Handles vanilla 7540 + Centrifuge V3 (Yo vaults keep existing `YoYieldSourceOracle`)
- Solidity 0.8.30, NatSpec, custom errors

## Technical Design

### Architecture

```
ERC7540YieldSourceOracle
  ├── extends AbstractYieldSourceOracle
  ├── immutable REQUEST_ID (constructor param)
  ├── immutable SUPER_LEDGER_CONFIGURATION (from base)
  │
  ├── R1 methods (hard revert):
  │   ├── getPricePerShare() → convertToAssets(10^decimals)
  │   ├── decimals() → share().decimals()
  │   └── getTVL() → totalAssets()
  │
  ├── R2 methods (try/catch per component):
  │   ├── getTVLByOwnerOfShares() → sum of 5 components
  │   └── getAsyncStateBreakdown() → 5 individual components
  │
  └── Standard methods:
      ├── getShareOutput() → convertToShares()
      ├── getWithdrawalShareOutput() → Math.mulDiv inverse
      ├── getAssetOutput() → convertToAssets()
      └── getBalanceOfOwner() → share.balanceOf()
```

### Data Model

No new storage. The oracle is fully view-only, reading 5 components from the 7540 vault per call. The `REQUEST_ID` is an immutable set at deployment.

### Key Design Decision: maxWithdraw for Claimable

Centrifuge V3 locks per-controller `redeemPrice` at epoch fulfillment. `convertToAssets(claimableShares)` applies the wrong global rate. `maxWithdraw(controller)` returns the exact locked asset amount.

## Implementation Plan

### Phase 1: Oracle Contract
- [x] Create `src/accounting/oracles/ERC7540YieldSourceOracle.sol`
- [x] 7 abstract method implementations + `getAsyncStateBreakdown()`
- [x] Constructor with `superLedgerConfiguration_` and `requestId_`

### Phase 2: Mock + Unit Tests
- [ ] Create `test/mocks/MockERC7540Vault.sol` (comprehensive mock)
- [ ] Create `test/unit/accounting/ERC7540YieldSourceOracle.t.sol`
- [ ] Test all 7 abstract methods + getAsyncStateBreakdown
- [ ] Test R1 vs R2 error handling boundary
- [ ] Fuzz tests for arithmetic edge cases

### Phase 3: Invariant Tests
- [ ] Create `test/invariant/ERC7540OracleInvariant.t.sol`
- [ ] VanillaHandler + CentrifugeHandler
- [ ] INV-1 through INV-7 invariant properties

### Phase 4: Fork Integration
- [ ] Create `test/integration/accounting/ERC7540OracleIntegration.t.sol`
- [ ] Fork Ethereum against real Centrifuge vault (CHAIN_1_CENTRIFUGE_USDC)

## Test Plan
- [x] Unit tests for: all 8 public methods, error handling modes, edge cases, fuzz
- [ ] Invariant tests for: 7 properties across 2 mock vault types (Vanilla, Centrifuge)
- [ ] Integration tests for: real Centrifuge vault on Ethereum mainnet fork

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Donation attack on convertToAssets | Oracle | Medium | High | Per-vault onboarding validation, keeper rate limits | Euler 2023 - $197M research |
| Double-count (non-compliant vault) | Vault Accounting | Low | Critical | INV-4 invariant test, per-vault validation | N/A |
| Vault non-compliance (pending not decremented) | Vault Accounting | Low | High | Per-vault validation at onboarding | Centrifuge C4rena 2023 |
| Keeper key compromise → arbitrary PPS | Access Control | Very Low | Critical | On-chain PPS bounds, multi-sig (out of scope) | N/A |
| Sandwich keeper oracle read | MEV | Medium | Medium | Private mempool, PPS rate limits | $700K oracle exploit 2025 |
| Try/catch forced revert undercount | Oracle | Low | Medium | Keeper monitoring, PPS rate limits | N/A |
| Cancel-in-flight TVL undercount | Vault Accounting | Medium | Low | Brief transient window, documented limitation | N/A |
| Fee overstatement (convertToAssets) | Business Logic | High | Low | Bounded by exit fee 0-0.5%, same as all oracles | N/A |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| How to handle Centrifuge locked redeemPrice? | Use `maxWithdraw(controller)` (D1) | Research + interview |
| Include async deposits in TVL? | Yes — marginal cost near zero, retrofitting = redeploy (D4) | Interview |
| Error handling strategy? | Hybrid R1/R2 — PPS hard reverts, TVL graceful degradation (D3) | Interview |
| What about Yo vault compatibility? | Keep separate `YoYieldSourceOracle` — different function selector | SpecFlow analysis |
| REQUEST_ID handling? | Immutable constructor param, default 0 (D2) | Interview |
| Fee inclusion? | Accept `convertToAssets` excludes fees, bounded by 0-0.5% (D5) | Interview |
| MEV protection? | Deferred to follow-up — asymmetric pricing (D6) | Interview |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)
- [repo-analysis.md](./research/repo-analysis.md) — Repository patterns and conventions
- [best-practices.md](./research/best-practices.md) — ERC-7540 standard analysis
- [framework-docs.md](./research/framework-docs.md) — Foundry testing patterns
- [evm-security.md](./research/evm-security.md) — Security vulnerability analysis
- [specflow-analysis.md](./research/specflow-analysis.md) — User flow and gap analysis

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/ERC7540Oracle/technical-spec.md`
