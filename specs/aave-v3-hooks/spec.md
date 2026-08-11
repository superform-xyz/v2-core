# Aave V3 Hooks Spec

## Metadata
- Project: Superform v2-core
- Milestone: Lending hook coverage (Aave V3)
- Linear Issue: N/A
- Interview Date: 2026-08-05
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary
Add a suite of seven `NONACCOUNTING` Superform hooks (plus a shared base) integrating Aave V3 lending,
mirroring the existing Aave V4 suite but targeting the Aave V3 `IPool` interface. Aave V3 is the dominant
money market on nearly every chain (V4 is Ethereum-only), so this unlocks cross-chain lending strategies
on Arbitrum, Base, Optimism, Polygon, and Ethereum's multiple V3 markets.

The hooks build the `Execution[]` the user's ERC-7579 account runs; they custody no funds. The key
design choice is passing the Aave `pool` address in hook calldata (like V4's `spoke`), so a single hook
deployment serves every V3 market (Core/Prime/EtherFi) on every chain instead of one deployment per market.

## Requirements

### Functional
1. Seven hooks: Supply, Withdraw, Borrow, Repay, SupplyAndBorrow, RepayAndWithdraw, RepayWithATokens, over a shared `BaseAaveV3LoanHook`.
2. `pool` address and `interestRateMode` byte carried in hook data; `onBehalfOf`/`to` = account; `referralCode` = 0.
3. `interestRateMode` validated `== 2` (variable); revert `INVALID_RATE_MODE` otherwise (stable removed in V3.2).
4. `type(uint256).max` sentinel for full withdraw/repay/repayWithATokens (avoids interest dust).
5. `usePrevHookAmount` chaining with V4-style balance-delta accounting.
6. Vendored minimal `IPool` (+ `ReserveDataLegacy`) under `src/vendor/aave-v3/`.

### Non-Functional
- Single deployment usable across all V3 markets/chains (pool-in-data).
- SafeERC20 approval bracketing with allowance reset to 0 after supply/repay (incl. `repay(max)`).
- Solidity 0.8.30; MIT-compatible vendored interface.

## Technical Design

### Architecture
`BaseAaveV3LoanHook` (extends `BaseHook`, `NONACCOUNTING`, `HookSubTypes.LOAN`) owns shared decoding
(`loanToken@52`, `collateralToken@72`, `pool@92` — the `@52/@72` offsets are mandated by the base) and the
`approve0 → forceApprove → poolCall → approve0` build pattern. Each hook overrides `_buildHookExecutions`.
V3 keys on the asset address, so V4's two reserveId slots are removed and replaced by `pool` + a rate byte.

### Data Model
No storage. Per-hook calldata layouts (final offsets confirmed in `/work`):
- Supply/Withdraw: `…loanToken@52, collateralToken@72, pool@92, amount@112, usePrevHookAmount@144`
- Borrow/Repay/RepayWithATokens: `…pool@92, interestRateMode(uint8)@112, amount@113, usePrevHookAmount@145`
- Combined: two amounts (supply+borrow / repay+withdraw) after the rate byte.

### API Changes
- New `src/hooks/loan/aave-v3/` (8 files). New `src/vendor/aave-v3/IPool.sol` (+ DataTypes).
- New `AAVE_V3_*` Pool constants + `*_HOOK_KEY` strings; `_deployAaveV3HooksSet`; 7 manifest entries.

## Implementation Plan

### Phase 1: Interface + Base
- [ ] Vendor `IPool` + `ReserveDataLegacy` (MIT, 0.8.30)
- [ ] `BaseAaveV3LoanHook` (decode, vars, pipe/accounting, approval helpers, `INVALID_RATE_MODE`)

### Phase 2: Hooks
- [ ] Supply, Withdraw, Borrow, Repay
- [ ] SupplyAndBorrow, RepayAndWithdraw, RepayWithATokens

### Phase 3: Tests + Deploy
- [ ] Unit tests per hook (mirror `AaveV4LoanHooks.t.sol`)
- [ ] No-mock fork integration tests per chain (pinned blocks), positions via aToken/variableDebtToken
- [ ] `AAVE_V3_*` constants; deploy script + manifest entries

## Test Plan
- [ ] Unit tests for: each hook's decode, execution build, `usePrevHookAmount`, `INVALID_RATE_MODE`, zero-amount reverts
- [ ] Integration tests for: supply→borrow, repay→withdraw, swap→supply chains; full lifecycle; `repay(max)`; `repayWithATokens`
- [ ] E2E fork tests for: Ethereum (Core), Arbitrum, Base, Optimism, Polygon; multi-asset market; isolation/paused-reserve revert cases

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Lingering infinite allowance to user-supplied `pool` | Access Control / Token | Low | High | Reset allowance to 0 after every supply/repay incl. `repay(max)`; optional pool allowlist | LiFi 2022 unvalidated calldata |
| `interestRateMode = 1` (stable) reverts | Business Logic | Med | Low | Validate `== 2`, `INVALID_RATE_MODE`; revert test | Aave V3.2 stable removal |
| Full repay/withdraw dust keeps position open | Business Logic | Med | Low | `type(uint256).max` sentinel | — |
| Missing-return tokens (USDT) silent failure | Token Behavior | Med | Med | `SafeERC20.forceApprove`/`safeTransfer` | vuln DB §10.3 |
| Fee-on-transfer amount mismatch | Token Behavior | Low | Med | Balance-delta accounting (as V4) | vuln DB §10.1 |
| Isolation/siloed/paused/cap reverts strand routes | Operational | Med | Low | Fork tests + docs (no cheap build-time precheck) | — |
| Oracle/bad-debt, first-depositor, liquidation MEV | Oracle/Vault | — | — | **Out of scope** — protocol-owned, hook cannot introduce | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| One Pool for all V3 markets? | No — one Pool per market; multiple per chain. Solved by pool-in-data (one deployment). | Interview |
| interestRateMode handling | Byte kept in data but **validated `== 2`** (revised from "configurable"); stable removed in V3.2 | Research + recommendation (pending final pod sign-off) |
| repayWithATokens as 7th hook | Yes | Interview |
| Collateral toggle hook | No — rely on Aave auto-enable | Interview |
| Target chains | Ethereum + Arbitrum, Base, Optimism, Polygon | Interview |

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
After approval, run: `/superform:work specs/aave-v3-hooks/technical-spec.md`
