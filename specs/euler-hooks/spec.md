# Euler V2 Lending Hooks Spec

## Metadata
- Project: Superform v2-core
- Milestone: Euler V2 Integration
- Linear Issue: N/A
- Interview Date: 2026-08-16
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Build a complete set of Euler V2 lending hooks for Superform v2-core, mirroring the existing Morpho hook architecture. The deliverable is 6 Euler hooks (4 individual + 2 composite), 2 vendor interfaces (IEVC, IEVault), and 2 corrected Morpho V2 composite hooks. All Euler hooks follow the Aave V3 deployment pattern (no constructor args, protocol addresses from calldata) for single-deployment-per-chain flexibility.

The hooks integrate with Euler's EVC (Ethereum Vault Connector) and EVault system to deposit collateral, borrow, repay, and withdraw across any Euler V2 market. Composite hooks additionally validate position health via `accountLiquidity` and enforce liquidation capacity caps set by the strategy sizer.

## Requirements

### Functional
1. 4 individual Euler hooks: DepositCollateral, Borrow, Repay, WithdrawCollateral
2. 2 composite Euler hooks: DepositCollateralAndBorrow, RepayAndWithdraw
3. 2 vendor interfaces: IEVC.sol, IEVault.sol
4. 2 corrected Morpho V2 hooks: SupplyAndBorrowHookV2 (independent amounts), RepayAndWithdrawHookV2 (post-accrual repay)
5. Config validation (oracle/IRM/unitOfAccount) at build time
6. Controller uniqueness enforcement (zero-or-one controller)
7. Full repayment includes `disableController()` cleanup
8. Repay-only path (secondaryAmount=0) for emergency repayment
9. `usePrevHookAmount = false` enforced for launch
10. Deploy on all chains where Euler V2 is available

### Non-Functional
- No constructor args (Aave V3 pattern)
- No `BaseEulerLoanHook` abstraction (direct `BaseLoanHook` inheritance)
- Dual-amount sizing (`primaryAmount` + `secondaryAmount`) for composite hooks
- Gas cost comparable to existing Aave V3 hooks

## Technical Design

### Architecture

```
BaseLoanHook (AMOUNT_POSITION=132, USE_PREV=196)
    ├── EulerDepositCollateralHook      (single amount, 4 executions)
    ├── EulerBorrowHook                 (single amount, 3 executions)
    ├── EulerRepayHook                  (single amount, 4-5 executions)
    ├── EulerWithdrawCollateralHook     (single amount, 1 execution)
    ├── EulerDepositCollateralAndBorrowHook  (dual amount, 7 executions)
    └── EulerRepayAndWithdrawHook           (dual amount, 4-6 executions)
```

### Data Model

Shared prefix (197 bytes): `configId(32) | collateralVault(20) | debtAsset(20) | collateralAsset(20) | evc(20) | controllerVault(20) | primaryAmount(32) | secondaryAmount(32) | usePrevHookAmount(1)`

Composite hook tails add config validation fields (oracle/IRM/unitOfAccount) and caps (maxPostDebt, maxLiqCapUtilBps).

### API Changes

New contracts (no existing contract modifications):
- `src/vendor/euler/IEVC.sol` - enableCollateral, enableController, disableCollateral, getControllers, etc.
- `src/vendor/euler/IEVault.sol` - deposit, withdraw, borrow, repay, disableController, debtOf, accountLiquidity, etc.
- 6 hook contracts in `src/hooks/loan/euler/`
- 2 corrected hooks in `src/hooks/loan/morpho/`

Deployment script modifications:
- `script/utils/Constants.sol` - 8 new hook key constants
- `script/DeployV2OtherHooks.s.sol` - Euler deployment section

## Implementation Plan

### Phase 1: Vendor Interfaces + Individual Hooks
- [ ] Create `src/vendor/euler/IEVC.sol`
- [ ] Create `src/vendor/euler/IEVault.sol`
- [ ] Implement `EulerDepositCollateralHook` (mirrors MorphoSupplyHook)
- [ ] Implement `EulerBorrowHook` (mirrors MorphoBorrowHook)
- [ ] Implement `EulerRepayHook` (mirrors MorphoRepayHook)
- [ ] Implement `EulerWithdrawCollateralHook`

### Phase 2: Composite Hooks
- [ ] Implement `EulerDepositCollateralAndBorrowHook` with config validation + liquidity caps
- [ ] Implement `EulerRepayAndWithdrawHook` with full repay, repay-only, and cleanup paths

### Phase 3: Morpho V2 Corrections
- [ ] Implement `MorphoSupplyAndBorrowHookV2` (independent exact amounts)
- [ ] Implement `MorphoRepayAndWithdrawHookV2` (post-accrual full repayment)

### Phase 4: Tests
- [ ] Unit tests with MockEVC/MockEVault (data decoding, execution arrays, errors)
- [ ] Fork tests against real Euler V2 on Base (full lifecycle)
- [ ] Morpho V2 unit tests (regression against V1 behavior)

### Phase 5: Deployment
- [ ] Add hook key constants to `Constants.sol`
- [ ] Add deployment logic to `DeployV2OtherHooks.s.sol` (no constructor args)
- [ ] Update `regenerate_bytecode.sh`

## Test Plan
- [ ] Unit tests for: all 6 Euler hooks (data decode, exec array, errors), 2 Morpho V2 hooks
- [ ] Integration tests for: full position lifecycle (open -> partial ops -> full close)
- [ ] Fork tests for: real Euler V2 on Base chain, config validation, controller enforcement

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| `accountLiquidity` API differs | Business Logic | Low | High | Verify via `cast interface` pre-implementation; fallback to manual calculation | - |
| Interest accrual drift | Business Logic | Medium | Low | P1-3 documented; bundler minimizes latency | General lending pattern |
| Full repayment front-running | MEV | Low | Low | P1-2 documented; residual debt is negligible | MorphoRepayHook P1-2 |
| Controller conflict | Access Control | Medium | Medium | Uniqueness check in `_buildHookExecutions` | Euler V1 2023 - $197M |
| Oracle governance change | Operational | Low | High | Config validation reverts on mismatch | Compound 2022 - $100M |
| EVC callback reentrancy | Reentrancy | Low | Low | EVC lock + transient storage mutexes + ReentrancyGuard | - |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Scope of hooks | Full Morpho mirror (6 Euler + 2 Morpho V2) | Interview |
| Deployment pattern | No constructor args (Aave V3) | Interview |
| Base abstraction | No BaseEulerLoanHook | Interview |
| Deployment chains | All chains where Euler V2 available | Interview |
| Reentrancy protection | Transient storage isolation (existing) | Interview |
| MEV protection | Sizing + cap parameters sufficient | Interview |
| `accountLiquidity` return order | `(collateralValue, liabilityValue)` -- collateral FIRST | API Research |
| `disableController` pattern | Called on EVault with NO params | API Research |
| Testing approach | Unit tests + fork tests with discovered addresses | Interview |

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
After approval, run: `/superform:work specs/euler-hooks/technical-spec.md`
