# ClaimFailedTransferHook Spec

## Metadata
- Project: Superform v2-core
- Milestone: StargateAdapter improvements
- Linear Issue: N/A
- Interview Date: 2026-06-02
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

The StargateAdapter stores failed transfers in a `failedTransfers` mapping when token delivery fails during `lzCompose`. Smart accounts need a hook to call `claimFailedTransfer(address token, uint256 amount)` to recover those tokens. This is a minimal NONACCOUNTING hook that builds a single execution targeting the adapter.

## Requirements

### Functional
1. Hook calls `claimFailedTransfer(address,uint256)` on a bundler-specified StargateAdapter address
2. Supports both ERC20 tokens and native ETH (token = address(0))
3. Tracks outAmount via pre/post balance delta for downstream hook chaining

### Non-Functional
- No constructor args (adapter address in hook data)
- Single execution, no ISuperHookContextAware

## Technical Design

### Architecture
Simple claim hook extending `BaseHook` with `NONACCOUNTING` type and `CLAIM` subtype. 72-byte packed data: `adapter(20) + token(20) + amount(32)`.

### Data Model
No new storage. Uses transient outAmount from BaseHook.

### API Changes
New hook contract: `ClaimFailedTransferHook`

## Implementation Plan

### Phase 1: Hook + Tests
- [ ] Create `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
- [ ] Create `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`
- [ ] Add to deployment scripts (Constants, DeployV2Core, regenerate_bytecode.sh)
- [ ] Regenerate bytecode

## Test Plan
- [ ] Unit tests for: constructor, build (ERC20/ETH), calldata encoding, reverts, pre/post execute, inspector, fuzz
- [ ] Integration tests for: N/A (unit tests sufficient for this hook complexity)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Wrong adapter address | Operational | Low | None (reverts) | Bundler validation | N/A |
| Native ETH balance delta noise | Token Behavior | Low | Low | Accepted — pre/post captures net change | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Single or ApproveAndClaim? | Single only — no approval needed | User |
| Single or batch adapters? | Single per call, batch via userOp | User |
| Post-claim forwarding? | Just claim, use TransferHook after | User |
| Address validation? | Trust bundler | User |
| Native ETH support? | Yes, both ERC20 and ETH | User |

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
After approval, run: `/superform:work specs/claim-failed-transfer-hook/technical-spec.md`
