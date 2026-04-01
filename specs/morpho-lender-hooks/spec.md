# MorphoLendHook Spec

## Metadata
- Project: DeFi Lending Strategies
- Milestone: Morpho Lender-Side Hooks
- Linear Issue: N/A
- Interview Date: 2026-03-30
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create `MorphoLendHook` and `MorphoLendWithdrawHook` for the lender side of Morpho Blue markets. Unlike the existing borrower-side hooks (`MorphoSupplyHook` = `supplyCollateral()`, `MorphoBorrowHook` = `borrow()`), these hooks call `supply()` and `withdraw()` on Morpho Blue, enabling SuperVault strategies to lend assets directly to markets and earn interest from borrowers.

A new withdrawal hook is required because the existing `MorphoWithdrawHook` tracks `collateralToken` balance in `_preExecute`/`_postExecute`, but `withdraw()` returns `loanToken`. For lending withdrawals, `outAmount` would be zero, breaking any downstream hook using `usePrevHookAmount`.

## Requirements

### Functional
1. MorphoLendHook calls `supply(marketParams, amount, 0, account, "")` with correct loanToken approval
2. MorphoLendWithdrawHook calls `withdraw()` and tracks loanToken balance for outAmount
3. Both hooks extend BaseMorphoLoanHook, use HookSubTypes.LOAN / LOAN_REPAY
4. usePrevHookAmount works correctly when chained
5. Data encoding matches existing Morpho hook patterns
6. Generic — works with any Morpho Blue market

### Non-Functional
- HookType: NONACCOUNTING (oracle/accounting deferred to separate spec)
- USDT compatibility via approve(0) reset pattern
- No reentrancy risk (empty callback data)

## Technical Design

### Architecture

Two new hooks extending `BaseMorphoLoanHook`:

| Hook | Morpho Call | Token Tracked | outAmount |
|------|------------|---------------|-----------|
| MorphoLendHook | `supply()` | loanToken decrease | pre - post |
| MorphoLendWithdrawHook | `withdraw()` | loanToken increase | post - pre |

### Data Model

**MorphoLendHook** (same as MorphoSupplyHook):
```
loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|amount(32)|lltv(32)|usePrevHookAmount(1)
```

**MorphoLendWithdrawHook** (same as MorphoWithdrawHook):
```
loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|onBehalf(20)|recipient(20)|lltv(32)|assets(32)|shares(32)
```

### Key Differences from Existing Hooks

| Aspect | MorphoSupplyHook (existing) | MorphoLendHook (new) |
|--------|---------------------------|---------------------|
| Morpho call | `supplyCollateral()` | `supply()` |
| Token approved | collateralToken | loanToken |
| Yield | None | Interest from borrowers |
| outAmount tracks | collateralToken balance | loanToken balance |

| Aspect | MorphoWithdrawHook (existing) | MorphoLendWithdrawHook (new) |
|--------|------------------------------|------------------------------|
| outAmount tracks | collateralToken balance | loanToken balance |
| Use case | Withdraw collateral (borrower) | Withdraw lent assets (lender) |

## Implementation Plan

### Phase 1: Hooks
- [ ] Create `src/hooks/loan/morpho/MorphoLendHook.sol`
- [ ] Create `src/hooks/loan/morpho/MorphoLendWithdrawHook.sol`

### Phase 2: Testing
- [ ] Create `test/integration/morpho/MorphoLendE2E.t.sol`

## Test Plan
- [ ] E2E: Lend USDC to a Morpho Blue market via real SuperVaultStrategy
- [ ] E2E: Withdraw lent USDC + accrued interest via MorphoLendWithdrawHook
- [ ] E2E: Full cycle (lend -> time passes -> withdraw with interest)
- [ ] E2E: Chained hooks (swap -> lend) using usePrevHookAmount

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Wrong token tracked in outAmount | Business Logic | High | High | New MorphoLendWithdrawHook tracks loanToken | MorphoWithdrawHook bug |
| USDT approval failure | Token Behavior | Medium | Medium | approve(0) reset before approve(amount) | Standard pattern |
| Future INFLOW migration breaks data layout | Operational | Low | Medium | Deferred — will redesign layout when oracle added | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Oracle integration? | Deferred to separate spec | User |
| Reuse MorphoWithdrawHook for lending? | No — outAmount bug. New hook needed | User + Research |
| Simplified data layout (no lltv)? | No — lltv is required market identifier | Research |
| New base class? | No — extend existing BaseMorphoLoanHook | User |

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
After approval, run: `/superform:work specs/morpho-lender-hooks/technical-spec.md`
