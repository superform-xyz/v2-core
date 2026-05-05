# ERC7540Oracle Interview Notes

## Date: 2026-04-27 through 2026-04-29
## Source: Extensive research and design sessions (documented in `.claude/doc/ERC7540Oracle/research.md`)
## Status: Complete — all design decisions resolved

---

## Feature Summary

Build an `ERC7540YieldSourceOracle` that tracks the full value of smart account positions in ERC-7540 async vaults. The existing oracle infrastructure only tracks `balanceOf` (held shares), missing pending redemptions, claimable redemptions, pending deposits, and claimable deposits. This creates artificial PPS drops exploitable via deposit/withdraw timing.

## Problem Statement

When a SuperVault strategy calls `requestRedeem()` on a 7540 vault:
1. Shares leave `balanceOf(strategy)` and enter pending state
2. Existing oracles see TVL = 0 for that position (only read `balanceOf`)
3. Keeper computes lower totalAssets → pushes lower PPS
4. Attacker deposits at deflated PPS, waits for claim, profits from PPS rebound

Same problem in reverse for async deposits: assets leave idle balance, no shares yet, TVL understates.

## Requirements

### Functional
1. Five-component TVL: `held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit`
2. `getPricePerShare()` delegates to `convertToAssets(10^decimals)` — identical to ERC4626
3. `getTVLByOwnerOfShares()` reads all 5 components from the 7540 vault
4. `getAsyncStateBreakdown()` returns 5 components individually (monitoring instrumentation)
5. Supports Vanilla 7540, Centrifuge V3 (locked redeemPrice), and Yo-style (rate locked at request) vaults
6. `maxWithdraw(controller)` for claimable redeems (not `convertToAssets(claimableShares)`)
7. `REQUEST_ID` as immutable constructor param (default 0, matches existing hooks)
8. Hybrid R1/R2 error handling: `getPricePerShare` hard reverts, async calls wrapped in try/catch

### Non-Functional
- View-only oracle — no state mutations, no storage writes
- Gas efficient — single `eth_call` to read all 5 components
- Compatible with `SuperYieldSourceOracle.setYieldSourceOracle()` registration
- Extends `AbstractYieldSourceOracle` base class

## Technical Decisions

### D1: maxWithdraw for Claimable Component
**Decision**: Use `maxWithdraw(controller)` instead of `convertToAssets(claimableRedeemRequest(0, c))`.
**Rationale**: Centrifuge V3 locks per-controller `redeemPrice` at epoch fulfillment. `convertToAssets(claimableShares)` applies the wrong global rate. `maxWithdraw` returns the exact locked asset amount. Standard ERC-4626 method, works for all vault subtypes.

### D2: REQUEST_ID as Constructor Parameter
**Decision**: Immutable `REQUEST_ID` set in constructor (default 0).
**Rationale**: All existing hooks use requestId=0 (accumulated pattern). Constructor param allows future per-requestId oracle instances without code changes. Matches existing pattern of one oracle instance per yield source.

### D3: Hybrid Error Handling (R1/R2)
**Decision**: `getPricePerShare()` hard reverts (R1). `getTVLByOwnerOfShares()` wraps async calls in try/catch (R2).
**Rationale**: PPS must be correct or absent — returning 0/stale causes incorrect fee calculations. TVL should degrade gracefully — drop components individually rather than reverting entirely.

### D4: Five-Component Formula (Including Async Deposits)
**Decision**: Include `pendingDepositRequest` and `claimableDepositRequest` in TVL.
**Rationale**: Centrifuge V3 and Firelight/Bizantine FXRP have async deposit flows. Assets leave idle balance with no shares to show — TVL understates. Marginal cost is near zero (two additional try/catch calls). Retrofitting later = redeploy + governance migration.

### D5: Fee Inclusion Tradeoff
**Decision**: Accept that `convertToAssets` excludes redemption fees for held + pending components.
**Rationale**: `previewRedeem` includes fees per spec but reverts/returns 0 on async 7540 vaults (can't sync-redeem held shares). The overstatement is bounded by vault exit fee (typically 0-0.5%). Same tradeoff all existing oracles make.

### D6: No Nested Flash Loans in MEV Mitigation (Deferred)
**Decision**: Asymmetric pricing (bid/ask spread) for MEV protection deferred to follow-up.
**Rationale**: Attack requires predicting underlying yield events AND front-running validator updates. Low practical risk for institutional 7540 vaults. Track as follow-up, not blocker.

## Security Concerns Discussed

1. **Double-count risk**: Held, pending, claimable pools must be mutually exclusive per 7540 spec. Validated by INV-4 invariant test.
2. **PPS manipulation via async state**: Artificial PPS drop when shares enter pending — this is THE problem the oracle solves.
3. **Overcount risk**: Fulfilled-but-not-claimed state could double-count if `pendingRedeemRequest` doesn't decrement atomically with fulfillment. Well-behaved vaults handle this; tested per vault at onboarding.
4. **MEV cadence mismatch**: Validator PPS update cadence vs underlying's `convertToAssets()` cadence diverge. Pending bucket amplifies front-runnable step. Mitigated by asymmetric pricing (follow-up).
5. **Vault non-compliance**: 2025 audits found many vaults don't properly implement `previewRedeem` fee inclusion. Case-by-case vault assessment at whitelisting is the primary defense.

## Testing Strategy

Three layers:
1. **Unit**: Individual methods, edge cases, fuzz — against mock 7540 vaults
2. **Invariant**: 8 properties (INV-1 through INV-8) across 3 mock vault implementations (Vanilla, Centrifuge, YoStyle)
3. **Integration**: Fork Base mainnet, test against real Centrifuge/Yo vaults

Key invariants:
- INV-1: TVL >= maxWithdraw (lower bound)
- INV-2: Sum of per-controller TVLs <= vault totalAssets (no over-attribution)
- INV-3: State transitions preserve value (round-trip)
- INV-4: Held + pending + claimable pools mutually exclusive (no double-count)
- INV-5: Claimable component == maxWithdraw exactly
- INV-7: Graceful degradation when async calls revert

## Risks & Tradeoffs

| Risk | Severity | Mitigation |
|------|----------|------------|
| Vault non-compliance with 7540 spec | Medium | Per-vault validation at onboarding |
| Fee overstatement (convertToAssets excludes fees) | Low | Bounded by exit fee (0-0.5%), same as all oracles |
| MEV via PPS cadence mismatch | Low | Asymmetric pricing (deferred follow-up) |
| Centrifuge redeemPrice mismatch | High | Solved: use maxWithdraw instead of convertToAssets |
| Double-count on fulfillment | Medium | INV-4 invariant test, per-vault atomic fulfillment verification |
| requestId != 0 vaults | Low | Constructor param, separate oracle instance per requestId |

## Key Files Referenced

- `src/accounting/oracles/AbstractYieldSourceOracle.sol` — base class
- `src/accounting/oracles/YoYieldSourceOracle.sol` — reference implementation with pending tracking
- `src/accounting/oracles/ERC4626YieldSourceOracle.sol` — existing 4626 oracle (held-only)
- `src/vendor/standards/ERC7540/IERC7540Vault.sol` — standard interfaces
- `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol` — deleted oracle (4626 clone, no async tracking)
