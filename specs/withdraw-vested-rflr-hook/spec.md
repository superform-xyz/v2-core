# WithdrawVestedRFLRHook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Flare rFLR Hooks
- Linear Issue: N/A
- Interview Date: 2026-05-26
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

The existing `WithdrawRFLRHook` calls `IRNat.withdrawAll(true)` which incurs a 50% penalty on any locked (unvested) rFLR. This new `WithdrawVestedRFLRHook` uses `IRNat.withdraw(uint128, bool)` combined with `getBalancesOf()` to withdraw only the vested portion — penalty-free. Both hooks will be deployed alongside each other, giving curators the choice.

The hook computes `vestedAmount = rNatBalance - lockedBalance`, safe-casts to uint128, and calls `withdraw(vestedAmount, true)` to receive WFLR. It reverts if nothing is vested, and supports optional minOut slippage protection.

## Requirements

### Functional
1. Add `withdraw(uint128, bool)` to `IRNat.sol` vendor interface
2. Compute vested amount from `getBalancesOf()` — guard against `lockedBalance >= rNatBalance`
3. Withdraw only vested tokens as WFLR via `withdraw(vestedAmount, true)`
4. Revert with `NOTHING_TO_WITHDRAW()` if vested amount is zero
5. SafeCast uint256 → uint128 (reverts on overflow)
6. Optional minOut slippage check via hook data `[0:32]`

### Non-Functional
- Deploy alongside existing `WithdrawRFLRHook` (not replacing)
- Same constructor signature: `(address rNat_, address wflr_)`
- Follow existing hook patterns (BaseHook, HookType.NONACCOUNTING, HookSubTypes.CLAIM)

## Technical Design

### Architecture

Same as `WithdrawRFLRHook` — single execution hook:
- `_buildHookExecutions`: reads `getBalancesOf(account)`, computes vested, builds `withdraw(amount, true)` call
- `_preExecute`: snapshots WFLR balance
- `_postExecute`: computes WFLR delta, enforces minOut, stores outAmount

### Data Layout
```
[0:32]  uint256 minOut (optional — no check if omitted or zero)
```

### Interface Change
```solidity
// Added to src/vendor/flare/IRNat.sol
function withdraw(uint128 _amount, bool _wrap) external;
```

## Implementation Plan

### Phase 1: Implementation
- [ ] Add `withdraw` to IRNat.sol interface
- [ ] Create `WithdrawVestedRFLRHook.sol`
- [ ] Create unit tests
- [ ] Add deploy pipeline (ConstantsOtherHooks, DeployV2OtherHooks, regenerate_bytecode.sh, deploy shell script)
- [ ] Generate and copy bytecode to locked folders

## Test Plan
- [ ] Unit tests: constructor, build, build revert (zero vested), pre/post execute delta, slippage pass/fail, SafeCast overflow, inspect
- [ ] Fork test against Flare mainnet RNat contract (if applicable)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| uint256→uint128 truncation | Arithmetic | Very Low | High | SafeCast.toUint128() | Cetus 2025 — $223M |
| lockedBalance >= rNatBalance underflow | Business Logic | Medium | Medium | Explicit guard + revert | N/A |
| View call staleness (build vs execute time) | Business Logic | Low | Low | Accepted — vesting only unlocks, never re-locks | N/A |
| Reentrancy via RNat.withdraw() | Reentrancy | Very Low | Low | BaseHook mutexes + trusted system contract | PenPie 2024 — $27M |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Withdraw exact vested or user-specified amount? | Exact vested | Cosmin |
| Revert or no-op on zero vested? | Revert | Cosmin |
| WFLR only or configurable wrap? | WFLR only | Cosmin |
| Keep minOut slippage check? | Yes | Cosmin |
| Safe cast for uint128? | Yes (SafeCast) | Cosmin |
| Deploy alongside or replace? | Alongside | Cosmin |

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
After approval, run: `/superform:work specs/withdraw-vested-rflr-hook/technical-spec.md`
