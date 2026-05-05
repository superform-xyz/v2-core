# Aave V4 Hooks Spec

## Metadata
- Project: Superform v2-core
- Milestone: Aave V4 Integration
- Linear Issue: N/A
- Interview Date: 2026-04-21
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Build 6 lending protocol hooks for Aave V4's Hub-and-Spoke architecture on Ethereum mainnet, following the established Morpho loan hook patterns. Aave V4 launched March 30, 2026 with native share-based accounting (no stataTokens needed). All hooks are `HookType.NONACCOUNTING` per `BaseLoanHook` convention, with `LOAN` or `LOAN_REPAY` subtypes.

**BLOCKER**: Aave V4 Spoke functions are protected by `onlyPositionManager(onBehalfOf)`. Must verify whether Superform smart accounts can call Spoke directly before implementation begins.

## Requirements

### Functional
1. 6 hooks: AaveV4Supply, AaveV4Withdraw, AaveV4Borrow, AaveV4Repay, AaveV4SupplyAndBorrow, AaveV4RepayAndWithdraw
2. All hooks extend `BaseAaveV4LoanHook` which extends `BaseLoanHook`
3. Zero-approve-set-approve-zero pattern (P1-1) for supply/repay hooks
4. `usePrevHookAmount` support for hook chaining
5. `isFullRepayment` support for repay hooks
6. Balance-diff tracking in `_preExecute`/`_postExecute`
7. `onBehalfOf` hardcoded to `account` in all Spoke calls
8. `inspect()` returns encoded Spoke address
9. `decodeAmount()` and `decodeUsePrevHookAmount()` exposed

### Non-Functional
- Ethereum mainnet only (chain 1) initially
- WETH only (chain with WrapNativeHook for native ETH)
- Minimal interface (`IAaveV4Spoke.sol`) to avoid BUSL license conflict
- Generic Spoke support (Core, e-Mode, Isolation, RWA, Vault Spokes)

## Technical Design

### Architecture

```
BaseLoanHook (NONACCOUNTING, ISuperHookLoans)
  └── BaseAaveV4LoanHook (data layout, decode functions)
        ├── AaveV4SupplyHook          (LOAN)
        ├── AaveV4WithdrawHook        (LOAN_REPAY)
        ├── AaveV4BorrowHook          (LOAN)
        ├── AaveV4RepayHook           (LOAN_REPAY)
        ├── AaveV4SupplyAndBorrowHook (LOAN)
        └── AaveV4RepayAndWithdrawHook (LOAN_REPAY)
```

### Data Model

```
address loanToken            (position 0)   -- borrowed asset address
address collateralToken      (position 20)  -- collateral asset address
address spoke                (position 40)  -- Aave V4 Spoke address
uint256 supplyReserveId      (position 60)  -- collateral reserve ID
uint256 borrowReserveId      (position 92)  -- loan reserve ID
uint256 amount               (position 124) -- operation amount
bool    usePrevHookAmount    (position 156)
bool    isFullRepayment      (position 157) -- repay hooks only
```

### API Changes

Aave V4 Spoke interface (minimal):
```solidity
function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
```

## Implementation Plan

### Phase 0: Setup & Verify (Pre-Implementation)
- [ ] `forge install aave/aave-v4` — get exact interface files
- [ ] Read `ISpoke.sol`, `ISpokeBase.sol` — verify function signatures
- [ ] Test Position Manager access control — can smart account call Spoke directly?
- [ ] Get deployed Spoke addresses from aave-address-book
- [ ] Create `src/vendor/aave-v4/IAaveV4Spoke.sol`

### Phase 1: Base Hook
- [ ] Create `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol`
- [ ] Data layout constants, decode functions, address validation

### Phase 2: Individual Hooks (4 hooks)
- [ ] AaveV4SupplyHook — approve + supply + approve(0)
- [ ] AaveV4WithdrawHook — withdraw
- [ ] AaveV4BorrowHook — borrow
- [ ] AaveV4RepayHook — approve + repay + approve(0) + full repayment support

### Phase 3: Combined Hooks (2 hooks)
- [ ] AaveV4SupplyAndBorrowHook — supply + borrow
- [ ] AaveV4RepayAndWithdrawHook — repay + withdraw + full repayment support

### Phase 4: Deployment & Testing
- [ ] Constants.sol, ConstantsOtherHooks.sol, ConfigOtherHooks.sol updates
- [ ] DeployV2OtherHooks.s.sol deployment function
- [ ] Unit tests and integration tests (Ethereum mainnet fork)

## Test Plan
- [ ] Unit tests for: all 6 hooks (constructor, build, build revert, prev hook, pre/post execute, inspector, decode)
- [ ] Integration tests for: supply/withdraw cycle, borrow/repay cycle, full repayment with interest
- [ ] E2E tests for: multi-hook chains (Swap -> Supply -> Borrow), USDT approval edge case

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Position Manager access denied | Access Control | HIGH | BLOCKER | Verify before implementation; may need Aave governance proposal | - |
| Aave V4 BUSL license conflict | Operational | MEDIUM | HIGH | Use minimal interface, don't import V4 source | - |
| reserveId manipulation | Logic | MEDIUM | HIGH | Include expected token address in calldata, validate on-chain | Compound 2021 - $160M |
| Stale approval for full repayment | Token Behavior | MEDIUM | MEDIUM | Interest accrual in preExecute, approval buffer | - |
| Thin market share manipulation | Vault Accounting | LOW | MEDIUM | Off-chain bundler refuses thin markets | Radiant 2024 - $4.5M |
| Underlying collateral compromise | Operational | LOW | HIGH | Aave governance trust assumption | Aave rsETH 2026 - $196M |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Hook scope? | Full 6 hooks mirroring Morpho | Interview |
| Spoke target? | Generic — any Spoke address via calldata | Interview |
| Chain scope? | Ethereum only initially | Interview |
| Native ETH? | WETH only, chain with WrapNativeHook | Interview |
| Hook types? | All NONACCOUNTING (BaseLoanHook pattern) | Repo analysis correction |
| Approval target? | Spoke address | Research |
| Trust model? | Trust Aave governance | Interview |

## Open Questions (Unresolved)
| # | Question | Status |
|---|----------|--------|
| 1 | Can Superform smart accounts call Spoke directly, or is Position Manager registration needed? | OPEN — BLOCKER |
| 2 | How to derive borrow amount in SupplyAndBorrow? Oracle query? Off-chain computed? | OPEN |
| 3 | Does Aave V4 support `type(uint256).max` for full repayment like V3? | OPEN |
| 4 | Exact deployed Spoke/Hub addresses on mainnet? | OPEN — check aave-address-book |

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
After approval, run: `/superform:work specs/aave-v4-hooks/technical-spec.md`
