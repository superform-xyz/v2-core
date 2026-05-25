# rFLR Claiming Hook Spec

## Metadata
- Project: Superform V2
- Milestone: Flare rFLR Integration
- Linear Issue: N/A
- Interview Date: 2026-05-14
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Two NONACCOUNTING hooks for Flare mainnet (chain 14) to claim and withdraw rFLR rewards from Flare's RNat contract. ClaimRFLRHook wraps `IRNat.claimRewards()` with fee handling (feeBPS/feeReceiver, max 50%). WithdrawRFLRHook wraps `IRNat.withdrawAll(true)` to convert rFLR to WFLR. Both follow established patterns (MerklClaimRewardHook for fees, TransferERC20Hook for balance tracking) and deploy alongside existing Firelight hooks on Flare.

## Requirements

### Functional
1. ClaimRFLRHook claims rFLR rewards for encoded projectIds and month with optional fee deduction
2. WithdrawRFLRHook converts entire rFLR balance to WFLR via withdrawAll(wrap=true)
3. Both hooks track balance deltas via pre/post execution snapshots
4. Fee handling: feeBPS capped at 5000 (50%), zero-value transfers skipped
5. RNAT address as immutable constructor arg for both hooks

### Non-Functional
- Deploy on Flare mainnet only (chain 14), chain-gated in DeployV2OtherHooks
- Follow existing NONACCOUNTING + CLAIM subtype pattern
- Vendor interface at src/vendor/flare/IRNat.sol (minimal, 2 functions)

## Technical Design

### Architecture
```
ClaimRFLRHook (NONACCOUNTING, CLAIM)
├── Constructor: address rNat_ → immutable RNAT
├── Data: feeReceiver(20) + feeBPS(32) + month(32) + expectedAmount(32) + projectIdsLen(32) + projectIds(N×32)
├── Build: [claimRewards, optional feeTransfer]
├── PreExec: snapshot rFLR balance
└── PostExec: compute rFLR delta

WithdrawRFLRHook (NONACCOUNTING, CLAIM)
├── Constructor: address rNat_, address wflr_ → immutables RNAT, WFLR
├── Data: (none — all hardcoded)
├── Build: [withdrawAll(true)]
├── PreExec: snapshot WFLR balance
└── PostExec: compute WFLR delta
```

### Data Model
- Vendor interface: `src/vendor/flare/IRNat.sol` (claimRewards, withdrawAll)
- No new storage — immutables only

### API Changes
- New hook keys: `CLAIM_RFLR_HOOK_KEY`, `WITHDRAW_RFLR_HOOK_KEY`
- New constants: `RNAT_FLARE`, `WFLR_FLARE` in ConstantsOtherHooks.sol

## Implementation Plan

### Phase 1: Core
- [ ] Create IRNat vendor interface
- [ ] Implement ClaimRFLRHook
- [ ] Implement WithdrawRFLRHook
- [ ] Verify forge build

### Phase 2: Tests
- [ ] Unit tests for ClaimRFLRHook (constructor, build, reverts, pre/post, inspect, fee edge cases)
- [ ] Unit tests for WithdrawRFLRHook (constructor, build, pre/post, inspect)

### Phase 3: Deployment
- [ ] Add constants and deployment logic to scripts
- [ ] Regenerate bytecode, copy to locked folders
- [ ] Simulate staging deployment

## Test Plan
- [ ] Unit tests for: ClaimRFLRHook, WithdrawRFLRHook
- [ ] Fee calculation tests: zero fee, max fee, small amounts rounding to zero
- [ ] Revert tests: invalid feeBPS, zero addresses, empty projectIds
- [ ] Balance delta tests: pre/post execute snapshots

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Fee > MAX_FEE_BPS | Access Control | Low | Medium | Validate feeBPS <= 5000 at build time | MerklClaimRewardHook pattern |
| 50% penalty on locked withdrawal | Business Logic | Medium | Medium | NatSpec docs + off-chain bundler warning | IRNat design (by Flare) |
| Zero-value transfer revert | Token Behavior | Medium | Low | Skip fee transfer when fee = 0 | Concur 2022 audit finding |
| Reentrancy via IRNat calls | Reentrancy | Low | Medium | BaseHook mutexes + balance snapshots | PenPie $27M (Sep 2024) |
| Claim + Withdraw same tx | Business Logic | Low | High | Off-chain bundler prevents chaining | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Hook type? | NONACCOUNTING | User (interview) |
| Separate or combined hooks? | Two separate hooks | User (interview) |
| Withdraw mode? | Always withdrawAll with wrap=true | User (interview) |
| Fee handling? | Same as MerklClaimRewardHook (feeBPS + feeReceiver) | User (interview) |
| Chain target? | Flare mainnet only (chain 14) | User (interview) |

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
After approval, run: `/superform:work specs/rflr-claiming-hook/technical-spec.md`
