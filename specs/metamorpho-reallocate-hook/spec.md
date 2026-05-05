# MetaMorpho Reallocate Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Hook Expansions
- Linear Issue: N/A
- Interview Date: 2026-04-07
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary
Create a NONACCOUNTING hook (`MetaMorphoReallocateHook`) that calls MetaMorpho's `reallocate()` function to redistribute funds between Morpho Blue markets within a single MetaMorpho vault. The hook is called through `executeHooks()` on SuperVaultStrategy by the vault manager (who is also a MetaMorpho allocator/curator). This is a net-zero operation with no accounting impact.

## Requirements

### Functional
1. Hook calls `reallocate(MarketAllocation[])` on any MetaMorpho vault (address in hook data)
2. Supports `usePrevHookAmount` to dynamically set one allocation's target assets
3. Validates vault address non-zero and allocations array non-empty
4. Uses standard hook data layout (bytes32 placeholder + address yieldSource + ...)
5. No pre/post execute needed (net-zero, no balance tracking)

### Non-Functional
- No constructor arguments (simple deployment)
- Compatible with both MetaMorpho v1 and v1.1

## Technical Design

### Architecture
Single hook contract + minimal vendor interface:
- `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol` - The hook
- `src/vendor/morpho/IMetaMorpho.sol` - Minimal interface (MarketAllocation struct + reallocate function)

### Data Model
```
data[0:32]  = bytes32 placeholder (oracle/yield source ID)
data[32:52] = address metaMorphoVault
data[52]    = bool usePrevHookAmount
data[53]    = uint8 prevHookAmountIndex
data[54:]   = abi.encode(MarketAllocation[])
```

### Execution Flow
1. Manager calls `SuperVaultExecutor.executeHooks(strategy, args)`
2. Hook's `build()` decodes data, generates single Execution
3. Execution calls `metaMorphoVault.reallocate(allocations)`
4. MetaMorpho redistributes funds between Morpho Blue markets (net-zero)

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `src/vendor/morpho/IMetaMorpho.sol`
- [ ] Create `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol`
- [ ] Create unit tests
- [ ] Verify `forge build` passes

## Test Plan
- [ ] Unit tests: constructor, hookType, subType verification
- [ ] Unit tests: build() execution generation with valid data
- [ ] Unit tests: usePrevHookAmount with valid/invalid index
- [ ] Unit tests: revert on zero vault, empty allocations
- [ ] Unit tests: inspect() and decodeUsePrevHookAmount()
- [ ] Unit tests: data encoding round-trip

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Stale allocations from interest accrual | Business Logic | Medium | Low | Use type(uint256).max on last allocation as catch-all | MetaMorpho docs |
| Access control gap on MetaMorpho | Access Control | Low | Medium | SuperVault manager must be MetaMorpho allocator - validated externally | N/A |
| ABI encoding mismatch | Business Logic | Low | High | Use abi.encodeCall for type-safe encoding | Morpho Bundler3 incident |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Hook type? | NONACCOUNTING | User |
| Vault address in constructor or data? | Hook data | User |
| usePrevHookAmount? | Yes, replaces allocation at specified index | User |
| Need native address? | No, reallocate is ERC20-only | Analysis |

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
After approval, run: `/superform:work specs/metamorpho-reallocate-hook/technical-spec.md`
