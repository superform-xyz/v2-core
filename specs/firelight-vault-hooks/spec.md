# Firelight Vault Hooks Spec

## Metadata
- Project: Superform v2-core
- Milestone: Flare Chain Integration
- Linear Issue: N/A
- Interview Date: 2026-04-20
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

The Firelight stXRP vault on Flare (chain ID 14) uses ERC-4626 function signatures but with async withdrawal semantics — `redeem()` burns shares and creates a `WithdrawRequest` instead of transferring assets, and `claimWithdraw(requestId)` claims FXRP after a ~2 day cooldown. Existing 4626 and 7540 hooks are incompatible. This spec creates 2 custom hooks following the established Ethena cooldown/unstake pattern: a NONACCOUNTING redeem hook and an OUTFLOW claim hook. Deposits use existing `Deposit4626VaultHook`.

## Requirements

### Functional
1. `RedeemFirelightVaultHook` calls `redeem(shares, account, account)` on the Firelight vault, tracking share burn via balance delta
2. `ClaimWithdrawFirelightVaultHook` calls `claimWithdraw(requestId)` and tracks FXRP received via balance delta
3. Both hooks support `usePrevHookAmount` and `inspect()` for merkle tree compatibility
4. Custom `IFirelightVault` interface with `redeem`, `claimWithdraw`, `asset`

### Non-Functional
- No modifications to existing files
- Pragma locked to `0.8.30`
- Follow existing hook patterns (data encoding, pre/post execute, inspect)

## Technical Design

### Architecture

Two-phase async withdrawal following Ethena precedent:

```
Phase 1: RedeemFirelightVaultHook (NONACCOUNTING)
  redeem(shares, account, account) → burns stXRP, emits WithdrawRequest

  ~2 day cooldown

Phase 2: ClaimWithdrawFirelightVaultHook (OUTFLOW)
  claimWithdraw(requestId) → transfers FXRP to account
```

### New Files

| File | Type |
|------|------|
| `src/vendor/vaults/firelight/IFirelightVault.sol` | Interface |
| `src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol` | Hook (NONACCOUNTING) |
| `src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol` | Hook (OUTFLOW) |
| `test/unit/hooks/vaults/firelight/FirelightHooksTests.t.sol` | Tests |

### Data Model

Both hooks use the standard hookData layout:
```
bytes32 placeholder/oracleId  [0:32]
address yieldSource           [32:52]  — Firelight vault address
uint256 shares/requestId      [52:84]  — shares (redeem) or requestId (claim)
bool    usePrevHookAmount     [84:85]
```

## Implementation Plan

### Phase 1: Core
- [ ] Create `IFirelightVault` interface
- [ ] Implement `RedeemFirelightVaultHook` (NONACCOUNTING, ERC4626 subtype)
- [ ] Implement `ClaimWithdrawFirelightVaultHook` (OUTFLOW, ERC4626 subtype)
- [ ] Unit tests for both hooks (16 test cases)

## Test Plan
- [ ] Unit tests for: constructor, build, build reverts, usePrevHookAmount, decodeAmount, pre/post execute deltas, inspect, isAsyncCancelHook
- [ ] Integration tests for: end-to-end redeem → claim flow on Flare fork (if feasible)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Vault upgraded during cooldown | Proxy/Upgrade | Low | High | Off-chain monitoring of proxy admin | AllianceBlock 2024, Kinto 2025 |
| Vault paused between phases | Operational | Low | Medium | Monitor, retry after unpause | — |
| maxRedeem returns misleading values | Vault Accounting | Certain | Medium | Never rely on maxRedeem/maxWithdraw | Sherlock 2024 finding |
| FXRP has non-standard ERC-20 behavior | Token Behavior | Low | Medium | Balance-delta pattern, no return value trust | — |
| Flare lacks transient storage (EIP-1153) | Operational | Low | High | Verify before deployment | — |
| RequestId front-running | MEV | Low | Medium | Verify vault enforces claim ownership | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Hook type for redeem? | NONACCOUNTING (no assets flow) | User |
| RequestId source? | Encoded in hookData by off-chain keeper | User |
| Custom deposit hook needed? | No, use existing Deposit4626VaultHook | User |
| HookSubType? | ERC4626 for both hooks | User |
| Cancel support? | CancelationType.NONE | User |
| Custom interface? | Yes, IFirelightVault | User |
| Track FXRP delta in claim? | Yes, pre/post balanceOf | User |

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
After approval, run: `/superform:work specs/firelight-vault-hooks/technical-spec.md`
