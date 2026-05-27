# StargateAdapter Spec

## Metadata
- Project: Superform v2-core
- Milestone: Stargate V2 Bridge Integration (Destination Side)
- Linear Issue: N/A
- Interview Date: 2026-05-26
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Implement a `StargateAdapter` contract that receives LayerZero V2 compose messages on the destination chain for Stargate V2 and generic OFT cross-chain transfers. The adapter implements `ILayerZeroComposer.lzCompose()`, decodes the OFTComposeMsgCodec payload, transfers received tokens (ERC20 or native ETH) to the target smart account, and calls `SuperDestinationExecutor.processBridgedExecution()`. This follows the identical pattern established by `AcrossV3Adapter` and `DebridgeAdapter`, completing the destination-side flow for the existing `StargateSendHook` and `ApproveAndStargateSendHook`.

## Requirements

### Functional
1. Receive ERC20 and native ETH compose messages via `lzCompose()` callback
2. Handle both Stargate pool compose (taxi/bus) and generic OFT compose (mode 2)
3. Decode OFTComposeMsgCodec (strip 76-byte header) and extract inner 6-tuple payload
4. Transfer full adapter token balance to target account before executor call
5. Call `processBridgedExecution()` with decoded payload
6. Accept native ETH via `receive()` for StargatePoolNative delivery

### Non-Functional
- Single immutable constructor (lzEndpoint, superDestinationExecutor)
- Deploy on all Superform chains (LZ endpoint same address everywhere)
- No governance or configuration required post-deployment

## Technical Design

### Architecture

```
Source Chain                          Destination Chain

StargateSendHook                     StargateAdapter
  sendToken(to=adapter,                lzCompose(_from, _guid, _message, ...)
    composeMsg=payload)                  |
  |                                      | 1. msg.sender == LZ_ENDPOINT
  v                                      | 2. Decode _message[76:]
Stargate Pool ──── LZ V2 ────>          | 3. token = _from.token()
                                         | 4. Transfer tokens to account
                                         | 5. processBridgedExecution()
                                         v
                                     SuperDestinationExecutor
```

### Data Model

**OFTComposeMsgCodec** (76-byte header + inner payload):
```
[nonce:8][srcEid:4][amountLD:32][composeFrom:32][composeMsg:var]
```

**Inner composeMsg** (standard 6-tuple, same as Across/deBridge):
```
abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)
```

### New Files
| File | Purpose |
|------|---------|
| `src/vendor/bridges/layerzero/ILayerZeroComposer.sol` | LZ V2 composer interface |
| `src/adapters/StargateAdapter.sol` | Compose receiver adapter |

### Modified Files
| File | Change |
|------|--------|
| `test/unit/adapters/AdaptersUnitTests.sol` | Add 12 test cases |
| `test/utils/Constants.sol` | Add `LZ_V2_ENDPOINT` constant |
| `script/run/regenerate_bytecode.sh` | Add to `CORE_CONTRACTS` |
| `test/BaseTest.t.sol` | Add deployment |

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `ILayerZeroComposer` vendor interface
- [ ] Implement `StargateAdapter` contract
- [ ] Add unit tests (constructor, sender validation, ERC20 path, ETH path, edge cases)
- [ ] Add infrastructure (constants, bytecode script, base test deployment)
- [ ] `forge build` + `forge test`

## Test Plan
- [ ] Unit tests: constructor validation, sender auth, message length, ERC20 compose, ETH compose, ETH failure, balance sweep, zero balance, dust accumulation, receive()
- [ ] Fuzz tests: message length, token amounts, ETH amounts
- [ ] Integration: fork test against real Stargate pool `token()` call (optional)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Dust from failed compose swept to wrong account | Token Behavior | Medium | Low | Accepted design trade-off. Document in NatSpec. | N/A |
| Token donation inflates transfer | Token Behavior | Low | Low | Extra tokens go to user account, attacker loses funds. | Solodit donation checklist |
| ETH forwarding reentrancy | Reentrancy | Low | Low | Layered defense: LZ compose hash + merkle root dedup + nonReentrant on executor | Consistent with DebridgeAdapter |
| LZ DVN/Executor compromise | Cross-Chain | Very Low | Critical | Trust assumption. Not adapter-level risk. | KelpDAO $292M (DVN misconfiguration) |
| Compose auth bypass | Access Control | Very Low | Critical | `msg.sender == LZ_ENDPOINT` (immutable CREATE2 deploy) | Nomad $190M (auth bypass) |
| `_from.token()` reverts | Operational | Low | Low | Compose retryable from LZ queue. Liveness issue only. | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Token flow: adapter receives all vs split? | Adapter receives all (same as Across) | Interview |
| Scope: Stargate only vs Stargate + OFT? | Stargate + OFT | Interview |
| Native ETH support? | Yes, both ERC20 + native | Interview |
| Sender validation approach? | Endpoint only (no whitelist) | Interview |
| Amount source: codec vs balance? | Full adapter balance | Interview |
| Token identification method? | `_from.token()` | Interview |
| Source hook changes needed? | No, bundler concern | Interview |
| Contract name? | StargateAdapter | Interview |

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
After approval, run: `/superform:work specs/stargate-compose-adapter/technical-spec.md`
