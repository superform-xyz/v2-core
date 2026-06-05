# Stargate Compose Data Minimization Spec

## Metadata
- Project: Superform V2 Core
- Milestone: Stargate V2 Bridge Optimization
- Linear Issue: N/A
- Interview Date: 2026-06-05
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

The current Stargate hook/adapter compose message duplicates `executorCalldata` (1-5 KB), `account`, `dstTokens`, and `intentAmounts` — these exist at the top level AND inside `sigData.proofDst[i].info`. This pushes complex operations past LayerZero's 10k byte message limit (confirmed by Tenderly simulation on Flare chain).

The fix reduces the compose message from `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)` to `abi.encode(initData, sigData)`. The V2 adapter extracts the redundant fields from sigData on the destination chain. No changes to executor or validator contracts (locked bytecode).

## Requirements

### Functional
1. V2 compose message uses compact `abi.encode(initData, sigData)` format
2. V2 adapter extracts account, executorCalldata, dstTokens, intentAmounts from sigData's DstProof.info
3. V2 adapter calls `processBridgedExecution` with identical parameters as V1
4. Modes 0 (taxi), 1 (bus), and 2 (OFT) supported
5. Failed transfer + claim flow works identically to V1
6. All V1 security checks preserved

### Non-Functional
- Compose message size reduced by 1.5-5.5 KB (eliminates duplicate executorCalldata)
- Destination gas cost within 10% of V1

## Technical Design

### Architecture

```
Source Chain                          LZ Wire (< 10k)              Destination Chain
────────────                         ───────────────              ─────────────────
StargateSendHookV2                                                StargateAdapterV2
  input: initData only               abi.encode(                    decode(initData, sigData)
  retrieve sigData from                initData,                    extract from sigData:
    transient storage                  sigData                       - account
  output: abi.encode(               )                                - executorCalldata
    initData, sigData)                                               - dstTokens
                                                                     - intentAmounts
                                                                   call executor (same as V1)
```

### Data Model
- No new storage — same `failedTransfers` mapping
- New event: `NoDstProofForChain(bytes32 guid, uint64 chainId)`
- SignatureData struct coupling: adapter now imports `ISuperValidator` types

### New Contracts
1. `src/adapters/StargateAdapterV2.sol`
2. `src/hooks/bridges/stargate/StargateSendHookV2.sol`
3. `src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol`

## Implementation Plan

### Phase 1: Core Contracts
- [ ] Create `StargateAdapterV2.sol` — compact decode + sigData extraction
- [ ] Create `StargateSendHookV2.sol` — compact encode (initData only + sigData from storage)
- [ ] Create `ApproveAndStargateSendHookV2.sol` — same with approval pattern

### Phase 2: Tests
- [ ] Unit tests for V2 hooks (modes, prevHookAmount, reverts, inspect)
- [ ] Integration/fork tests for V2 adapter (lzCompose flow, sigData extraction, edge cases)
- [ ] Test no-matching-DstProof graceful handling
- [ ] Test V1→V2 / V2→V1 version mismatch (fails gracefully)

### Phase 3: Deployment
- [ ] Add V2 constants to `Constants.sol`
- [ ] Add deployment logic (separate script or DeployV2Core update)
- [ ] Generate locked bytecodes

## Test Plan
- [ ] Unit tests for: V2 hooks (all modes, encoding, reverts)
- [ ] Integration tests for: V2 adapter (lzCompose, sigData extraction, failed transfers, claims)
- [ ] E2E tests for: Full source→destination flow with compact encoding

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| No matching DstProof for chain | Cross-Chain | Low | Medium | Emit event + return (no revert) | — |
| Malformed sigData gas bomb | DOS | Low | Medium | try/catch absorbs OOG via EIP-150 | abi.decode gas bomb research |
| V2 hook → V1 adapter mismatch | Operational | Medium | Low | Caught by try/catch, tokens claimable | — |
| sigData format change in future | Business Logic | Low | High | Adapter coupled to validator — update together | — |
| Compose spoofing via permissionless sendCompose | Cross-Chain | Low | High | Retain pool registration check | CrossCurve $3M (2026) |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Which modes to optimize? | Modes 0-2 only (mode 3 excluded) | Interview |
| Strip proofSrc/filter DstProof? | No, keep sigData as-is | Interview |
| New contracts or replace? | New V2 contracts alongside V1 | Interview |
| Security model change? | Same trust model — transfer before validation | Interview |

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
After approval, run: `/superform:work specs/stargate-compose-data-minimization/technical-spec.md`
