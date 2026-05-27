# Odos V3 Hook Spec

## Metadata
- Project: v2-core
- Milestone: Hook Integrations
- Linear Issue: N/A
- Interview Date: 2026-05-20
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Two new swap hooks (`SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook`) for the Odos V3 DEX aggregator router deployed at `0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05`. The V3 router replaces V2's `uint32 referralCode` with an inline `swapReferralInfo` struct containing `uint64 code`, `uint64 fee`, and `address feeRecipient`. The hooks add referral fee validation (max 2%, matching router cap) and extend the packed data layout by 32 bytes. V2 hooks remain unchanged for backward compatibility.

## Requirements

### Functional
1. `SwapOdosV3Hook` — single-execution swap hook (no approvals, supports native ETH)
2. `ApproveAndSwapOdosV3Hook` — approve-swap-revoke pattern (skips approvals for native ETH)
3. Both support `usePrevHookAmount` for hook chaining with proportional outputMin scaling
4. Balance delta tracking via pre/post execute (transient storage)
5. `inspect()` returns `abi.encodePacked(executor, feeRecipient)` for off-chain validation

### Non-Functional
- Solidity 0.8.30, NatSpec, custom errors
- Deploy via `DeployV2OtherHooks.s.sol` (post-audit path)
- Same router address on all EVM chains

## Technical Design

### Architecture

Mirrors V2 Odos hooks exactly, with three changes:
1. `IOdosRouterV3` interface with `swapReferralInfo` struct (uint64 code, uint64 fee, address feeRecipient)
2. Extended hook data layout: executor(20) + referralCode(8) + referralFee(8) + feeRecipient(20) = 56 bytes tail (vs V2's 24 bytes)
3. Fee validation in `_buildHookExecutions()`: `referralFee <= FEE_DENOM / 50` (2%)

### Data Model

New interface: `src/vendor/odos/IOdosRouterV3.sol`
New hooks: `src/hooks/swappers/odos/SwapOdosV3Hook.sol`, `ApproveAndSwapOdosV3Hook.sol`

### API Changes

No API changes. Hooks are used within the SuperExecutor execution flow via Merkle-validated userOps.

## Implementation Plan

### Phase 1: Interface & Hooks
- [ ] Create `IOdosRouterV3.sol` with swapReferralInfo struct
- [ ] Create `SwapOdosV3Hook.sol` (mirror V2, add fee validation)
- [ ] Create `ApproveAndSwapOdosV3Hook.sol` (mirror V2, add fee validation, native ETH conditional)
- [ ] Verify `forge build` passes

### Phase 2: Tests
- [ ] Create `MockOdosRouterV3.sol`
- [ ] Create `OdosV3UnitTests.t.sol` (fee cap, feeRecipient, inspect, native ETH, prevHookAmount)
- [ ] Add `_createOdosV3SwapHookData()` to InternalHelpers
- [ ] All tests pass

### Phase 3: Deployment Config
- [ ] Add constants to `ConstantsOtherHooks.sol`
- [ ] Add deploy function to `DeployV2OtherHooks.s.sol`
- [ ] Update `regenerate_bytecode.sh`

## Test Plan
- [ ] Unit tests: build execution count (3 for swap, 6 for approve+swap, 3 for approve+swap+nativeETH)
- [ ] Unit tests: fee cap enforcement (boundary + fuzz)
- [ ] Unit tests: feeRecipient validation
- [ ] Unit tests: inspect() returns 40 bytes
- [ ] Unit tests: usePrevHookAmount scaling
- [ ] Unit tests: native ETH input/output
- [ ] Integration tests: fork test against live Odos V3 (optional, P2)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Referral fee drain via feeRecipient | Token Behavior | Low | High | Fee cap at 2% + feeRecipient in inspect() | Kame Aggregator 2025 - $1.325M |
| Arbitrary executor stealing tokens | Access Control | Low | Critical | inspect() exposes executor for off-chain validation | SwapNet/Aperture 2026 - $17M |
| Opaque pathDefinition routing through malicious pools | Business Logic | Low | Medium | outputMin enforcement by Odos router | Transit Swap 2022 - $21M |
| Residual approval after failed swap | Token Behavior | Very Low | Medium | Atomic ERC-7579 execution + approve(0) cleanup | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Which V3 functions? | swap() only | User |
| Referral info handling? | Fully parameterized in data | User |
| Hook variants? | Both (Swap + ApproveAndSwap) | User |
| V2 coexistence? | Keep V2, add V3 alongside | User |
| Token compatibility? | Standard ERC-20 only | User |
| Fee validation? | Cap at router max (2%) | User + Research |
| MEV protection? | outputMin sufficient | User |
| Access control? | Same as V2 (SuperExecutor level) | User |

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
After approval, run: `/superform:work specs/odos-v3-hook/technical-spec.md`
