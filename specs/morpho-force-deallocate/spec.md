# Morpho Force Deallocate Hook Spec

## Metadata
- Project: Superform V2
- Milestone: Morpho Vault V2 Integration
- Linear Issue: N/A
- Interview Date: 2026-05-21
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create two NONACCOUNTING hooks (`ForceDeallocateMorphoHook` and `ApproveAndForceDeallocateMorphoHook`) that call Morpho Vault V2's permissionless `forceDeallocate` function. This enables emergency extraction of assets from compromised or underperforming adapters back to the vault's idle balance. The hooks include penalty tolerance (`maxPenaltyBps`) and deadline protection to guard against unexpected penalty costs and stale execution.

Morpho Vault V2 is deployed on all target chains via CREATE2. The penalty mechanism charges up to 2% of extracted assets by burning vault shares from the caller, redistributing value to remaining shareholders.

## Requirements

### Functional
1. `ForceDeallocateMorphoHook` calls `forceDeallocate(adapter, data, assets, account)` on Morpho Vault V2
2. `ApproveAndForceDeallocateMorphoHook` wraps the call with token approval lifecycle (zero-approve-action-zero)
3. Revert if penalty exceeds `maxPenaltyBps` (pre-checked via `forceDeallocatePenalty(adapter)` view call)
4. Revert if `block.timestamp > deadline` (deadline=0 means no check)
5. Support `usePrevHookAmount` for chaining with previous hooks
6. `onBehalf` hardcoded to `msg.sender` (smart account) — never configurable
7. Validate: vault != address(0), adapter != address(0), assets > 0

### Non-Functional
- Gas-efficient: pre-check penalty via view call, no storage writes
- Fork-tested against real Morpho Vault V2 on Ethereum mainnet
- Follows `MetaMorphoReallocateHook` conventions exactly

## Technical Design

### Architecture

```
SmartAccount (Nexus)
    └── SuperExecutor
        └── ForceDeallocateMorphoHook.build()
            ├── Validate: deadline, penalty, addresses, amounts
            ├── Static call: vault.forceDeallocatePenalty(adapter)
            └── Return Execution: vault.forceDeallocate(adapter, data, assets, account)
```

### Data Model

New vendor interface: `src/vendor/morpho/IMorphoVaultV2.sol` with `forceDeallocate()` and `forceDeallocatePenalty()`.

### API Changes

**ForceDeallocateMorphoHook data layout:**
| Offset | Type | Field |
|--------|------|-------|
| 0 | bytes32 | placeholder (yieldSourceOracleId) |
| 32 | address | morphoVaultV2 |
| 52 | address | adapter |
| 72 | uint256 | assets |
| 104 | uint256 | deadline |
| 136 | uint256 | maxPenaltyBps |
| 168 | bool | usePrevHookAmount |
| 169 | bytes | adapterData (raw tail) |

**ApproveAndForceDeallocateMorphoHook** adds `address token` at offset 52, shifting subsequent fields by 20 bytes.

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `src/vendor/morpho/IMorphoVaultV2.sol`
- [ ] Create `src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol`
- [ ] Create `src/hooks/vaults/metamorpho/ApproveAndForceDeallocateMorphoHook.sol`
- [ ] Add hook key constants to `script/utils/Constants.sol`

### Phase 2: Testing
- [ ] Unit tests: `test/unit/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.t.sol`
- [ ] Fork E2E tests: `test/integration/metamorpho/ForceDeallocateMorphoHookE2E.t.sol`
- [ ] Verify ApproveAndForce variant necessity (token approval may be no-op)

### Phase 3: Deployment
- [ ] Update `script/DeployV2OtherHooks.s.sol` with deployment logic
- [ ] Update `script/run/regenerate_bytecode.sh`
- [ ] Update `script/run/deploy_v2_other_hooks_staging_prod.sh`
- [ ] Deploy to staging (Ethereum, Base, Optimism, Arbitrum, BNB)

## Test Plan
- [ ] Unit tests for: constructor, build, deadline, penalty, usePrevHookAmount, inspect, fuzz
- [ ] Integration tests for: fork mainnet happy path, penalty enforcement, zero penalty, approve variant
- [ ] E2E tests for: full UserOp execution flow via SuperExecutor

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Penalty exceeds user expectation | Business Logic | Medium | High | maxPenaltyBps pre-check | Morpho V2 Sherlock audit |
| Stale execution | MEV | High | Medium | deadline parameter | Standard DeFi pattern |
| Share price manipulation | Flash Loan | Low | Medium | 2% cap + maxPenaltyBps | Euler 2023 - $197M |
| Adapter compromise | Operational | Low | High | Vault-level concern; hook cannot mitigate | — |
| ApproveAndForce variant unnecessary | Business Logic | Medium | Low | Include per requirements; verify in tests | — |
| Vault V2 not deployed on target chain | Operational | Low | High | Verify before hook deployment | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| V1 or V2? | V2 only | Cosmin |
| Emergency or routine? | Emergency extraction | Cosmin |
| ACCOUNTING or NONACCOUNTING? | NONACCOUNTING | Cosmin |
| Approve variant? | Both base + approve | Cosmin |
| Penalty validation? | maxPenaltyBps parameter (BPS) | Cosmin |
| Reentrancy guard? | Trust vault's guards | Cosmin |
| Deadline? | Yes, add deadline parameter | Cosmin |
| onBehalf configurable? | No, always msg.sender | Cosmin |
| Testing approach? | Fork mainnet | Cosmin |
| Penalty time-based? | No, static per-adapter value | Research |
| Penalty enforcement how? | Pre-check via view call | SpecFlow analysis |

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
After approval, run: `/superform:work specs/morpho-force-deallocate/technical-spec.md`
