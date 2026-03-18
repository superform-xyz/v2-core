# Spark PSM Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Hook Integrations
- Linear Issue: N/A
- Interview Date: 2026-03-09
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Four Solidity hooks enabling USDC/USDS/sUSDS swaps through Sky.money's Spark PSM (Peg Stability Module) within Superform v2's modular hook chain. The PSM provides zero-fee, deterministic pricing and is the primary venue for stablecoin swaps on Base. These hooks enable Superform to route swaps before/after vault operations (e.g., USDC → USDS → Morpho vault deposit).

The hooks follow the established swap hook pattern (UniswapV3, Odos): `BaseHook(NONACCOUNTING, SWAP)` with balance tracking via pre/post deltas and `usePrevHookAmount` chaining support.

## Requirements

### Functional
1. `SwapSparkPSMExactInHook` — swapExactIn, assumes pre-approved (3 executions)
2. `ApproveAndSwapSparkPSMExactInHook` — approve + swapExactIn + revoke (6 executions)
3. `SwapSparkPSMExactOutHook` — swapExactOut, assumes pre-approved (3 executions)
4. `ApproveAndSwapSparkPSMExactOutHook` — approve + swapExactOut + revoke (6 executions)
5. Hook chaining via `usePrevHookAmount` for both ExactIn and ExactOut
6. Support all 3 PSM tokens: USDC, USDS, sUSDS
7. Referral code passed as `uint256` parameter in hook data
8. Constructor validates PSM address != address(0)
9. `inspect()` returns `assetOut` address
10. Data length guard: revert `INVALID_HOOK_DATA` on < 157 bytes

### Non-Functional
- Deploy wherever PSM is available (Base confirmed, others via address(0) skip)
- Gas: ~80-120k (swap-only), ~155-195k (approve-and-swap)
- Follow existing swap hook patterns exactly (UniswapV3, Odos)

## Technical Design

### Architecture

```
src/vendor/spark/IPSM3.sol                              (vendor interface)
src/hooks/swappers/spark-psm/
    SwapSparkPSMExactInHook.sol                          (ExactIn, pre-approved)
    ApproveAndSwapSparkPSMExactInHook.sol                (ExactIn, approve+revoke)
    SwapSparkPSMExactOutHook.sol                         (ExactOut, pre-approved)
    ApproveAndSwapSparkPSMExactOutHook.sol               (ExactOut, approve+revoke)
test/mocks/MockPSM3.sol                                  (test mock)
test/unit/hooks/swappers/spark-psm/
    SparkPSMExactInUnitTests.t.sol
    SparkPSMExactOutUnitTests.t.sol
```

### Data Model

Hook data layout (157 bytes, tightly packed):
```
[0:20]    address assetIn
[20:40]   address assetOut
[40:72]   uint256 amount          (amountIn or amountOut)
[72:104]  uint256 slippageParam   (minAmountOut or maxAmountIn)
[104:124] address receiver        (IGNORED - forced to account)
[124:156] uint256 referralCode
[156:157] bool    usePrevHookAmount
```

### Key Design Decisions

1. **Receiver forced to account** — balance tracking requires output tokens in account
2. **ExactOut approves maxAmountIn** — PSM pulls variable amountIn ≤ maxAmountIn
3. **No token validation** — let PSM revert on invalid tokens
4. **uint256 referralCode** — matches PSM interface (not uint32 like Odos)
5. **Approve pattern**: approve(0) → approve(exact) → swap → approve(0)

## Implementation Plan

### Phase 1: Foundation
- [ ] Create IPSM3 vendor interface
- [ ] Create MockPSM3 test contract

### Phase 2: ExactIn Hooks + Tests
- [ ] SwapSparkPSMExactInHook
- [ ] ApproveAndSwapSparkPSMExactInHook
- [ ] SparkPSMExactInUnitTests

### Phase 3: ExactOut Hooks + Tests
- [ ] SwapSparkPSMExactOutHook
- [ ] ApproveAndSwapSparkPSMExactOutHook
- [ ] SparkPSMExactOutUnitTests

### Phase 4: Deployment Config
- [ ] PSM address constants per chain
- [ ] Hook key constants in Constants.sol
- [ ] Conditional deployment logic

## Test Plan
- [ ] Unit tests: constructor, build, preExecute, postExecute, inspect, decodeUsePrevHookAmount (all 4 hooks)
- [ ] Fuzz tests: slippage recalculation with HookDataUpdater
- [ ] Edge cases: zero amount, data length < 157, ExactOut approve(maxAmountIn)
- [ ] Integration: hook chaining usePrevHookAmount for both ExactIn and ExactOut

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Receiver not forced to account | Business Logic | Low | Critical | Hardcode receiver=account in all hooks | UniswapV3 hook pattern |
| ExactOut approves wrong amount | Business Logic | Medium | High | Approve maxAmountIn, not amountOut | - |
| PSM drainage DoS | Operational | Low | Low | Temporary; PSM replenished by Spark | ChainSecurity PSM audit |
| sUSDS rate drift | Oracle | Medium | Low | minAmountOut/maxAmountIn slippage | - |
| Preview rounding mismatch | Business Logic | Medium | Low | Bundler adds 1-2 wei buffer | ChainSecurity PSM audit |
| Transient storage collision | Reentrancy | Very Low | Critical | keccak256-keyed slots in BaseHook | SIR.trading 2025 ($355k) |
| Residual approval on revert | Token Behavior | Low | Low | ERC-7579 atomic batch rollback | Li.Fi 2024 ($9.7M) |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| How many hooks? | 4 (ExactIn + ExactOut × Swap + ApproveAndSwap) | Interview |
| Referral code type? | uint256, passed in hook data | Interview (PSM interface) |
| Token validation? | None - let PSM revert | Interview |
| Deployment chains? | Wherever PSM available, address(0) skip | Interview |
| ExactOut chaining? | prevHook output → amountOut, maxAmountIn scaled | Interview |
| sUSDS support? | Yes, all 3 tokens (USDC, USDS, sUSDS) | Interview |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)
- [repo-analysis.md](./research/repo-analysis.md) — Codebase patterns and conventions
- [best-practices.md](./research/best-practices.md) — PSM integration best practices
- [specflow-analysis.md](./research/specflow-analysis.md) — User flows and edge cases
- [evm-security.md](./research/evm-security.md) — Security vulnerability analysis

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/spark-psm-hook/technical-spec.md`
