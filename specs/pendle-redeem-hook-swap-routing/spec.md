# PendleUnifiedHook Spec

## Metadata
- Project: v2-core
- Milestone: Hook Improvements
- Linear Issue: N/A
- Interview Date: 2026-02-02
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Merge `PendleRouterRedeemHook` and `PendleRouterSwapHook` into a unified `PendleUnifiedHook` that fixes a critical validation bug preventing swap routing for redemptions to non-accounting tokens.

The current `PendleRouterRedeemHook` validates `tokenOut` against `SY.isValidTokenOut()`, but this blocks legitimate use cases where users want to redeem PT to tokens that require swap routing (e.g., redeem PT-eUSDe → USDC via Odos). The fix validates `tokenRedeemSy` instead of `tokenOut` when `swapData.swapType != SwapType.NONE`, enabling atomic redemption + swap operations with single slippage management.

## Requirements

### Functional
1. Support `redeemPyToToken` with swap routing (tokenOut != tokenRedeemSy)
2. Support all current functionality from both existing hooks (redeem, swapExactTokenForPt, swapExactPtForToken)
3. Maintain `usePrevHookAmount` chaining for hook composition
4. Support native ETH as input for swapExactTokenForPt
5. Keep data format similar to current hooks for smooth off-chain transition

### Non-Functional
- Comprehensive test coverage (refactor existing + add new tests)
- Deprecate old hooks without breaking changes
- Gas-efficient validation and execution

## Technical Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PendleUnifiedHook                        │
├─────────────────────────────────────────────────────────────┤
│ Supported Selectors:                                        │
│ ├── redeemPyToToken      (with/without swap routing)        │
│ ├── swapExactTokenForPt  (token → PT)                       │
│ └── swapExactPtForToken  (PT → token)                       │
├─────────────────────────────────────────────────────────────┤
│ Core Fix:                                                   │
│ When swapData.swapType != NONE:                             │
│   → Validate tokenRedeemSy (not tokenOut)                   │
│   → Validate extRouter != address(0)                        │
└─────────────────────────────────────────────────────────────┘
```

### Data Layout

```
Offset 0-31:   bytes32 placeholder (yieldSourceOracleId)
Offset 32-51: address yieldSource (market or YT)
Offset 52:    bool usePrevHookAmount
Offset 53-84: uint256 value
Offset 85+:   bytes txData (raw Pendle router calldata)
```

### Validation Fix

```solidity
if (output.swapData.swapType != SwapType.NONE) {
    // Swap routing: validate tokenRedeemSy
    if (!SY.isValidTokenOut(output.tokenRedeemSy)) revert TOKEN_REDEEM_SY_NOT_VALID();
    if (output.swapData.extRouter == address(0)) revert INVALID_EXT_ROUTER();
} else {
    // Direct redemption: validate tokenOut
    if (!SY.isValidTokenOut(output.tokenOut)) revert TOKEN_OUT_NOT_LISTED();
}
```

## Implementation Plan

### Phase 1: Implementation
- [ ] Create `PendleUnifiedHook.sol` with all 3 selectors
- [ ] Implement tokenRedeemSy validation fix
- [ ] Implement selector-specific execution building
- [ ] Implement inspect() for Merkle tree compatibility

### Phase 2: Testing
- [ ] Refactor existing tests from both hooks
- [ ] Add swap routing validation tests
- [ ] Add integration test with SuperVault executeHooks
- [ ] Fuzzing for amounts/parameters

### Phase 3: Migration
- [ ] Deploy and register new hook
- [ ] Update off-chain bundler
- [ ] Mark old hooks as @deprecated

## Test Plan
- [ ] Unit tests for: all 3 selectors, validation logic, balance tracking
- [ ] Integration tests for: SuperVault executeHooks, hook chaining
- [ ] Edge case tests for: ETH handling, zero amounts, invalid selectors

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| External router malicious | Low | High | Non-zero check; trust Pendle ecosystem |
| Off-chain transition issues | Medium | Medium | Keep data format similar |
| Regression in existing flows | Medium | High | Comprehensive test refactoring |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Modify existing or create new? | Merge into PendleUnifiedHook | Interview |
| extRouter validation? | Non-zero check only | Interview |
| inspect() format? | Keep simple, fixed data | Interview |
| Data format? | Selector-specific, similar to current | Interview |
| Old hooks? | Deprecate | Interview |

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
After approval, run: `/superform:work specs/pendle-redeem-hook-swap-routing/technical-spec.md`
