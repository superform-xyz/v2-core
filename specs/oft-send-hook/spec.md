# OFT Send Hook Spec

## Metadata
- Project: Superform V2 Core
- Milestone: OFT Bridge Support
- Linear Issue: N/A
- Interview Date: 2026-05-26
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Extend the existing `StargateSendHook` and `ApproveAndStargateSendHook` to support generic LayerZero V2 OFT/OFTAdapter tokens by adding a mode flag in calldata. The `isBusMode` byte (offset 225) is reinterpreted as `uint8 mode` where 0=Stargate taxi, 1=Stargate bus, 2=generic OFT. This enables cross-chain transfers of any IOFT-compatible token (immediate use case: UP OFT) while preserving backward compatibility for existing Stargate integrations.

## Requirements

### Functional
1. StargateSendHook supports `IOFT.send()` via mode=2 with `msg.value = lzNativeFee` only
2. ApproveAndStargateSendHook supports `IOFT.send()` via mode=2 with approval to OFT/OFTAdapter contract
3. Mode 0/1 behavior identical to current implementation (backward compatible)
4. Mode >2 reverts with `MODE_NOT_VALID()`
5. Compose message signature appending works in OFT mode
6. lzTokenFee payment supported in OFT mode

### Non-Functional
- No data layout offset changes (290 byte minimum preserved)
- Gas overhead from mode branching: ~100-300 gas (negligible vs bridge call)
- Same trust model as existing Stargate hooks (bundler trust + `token()` validation)

## Technical Design

### Architecture

The `stargatePool` field (offset 64) serves double duty: Stargate pool address in mode 0/1, OFT/OFTAdapter address in mode 2. Both `IStargate` and `IOFT` expose identical `SendParam` structs and `token()` methods — only the function selector differs (`sendToken` vs `send`).

### Data Model

No schema changes. Single byte reinterpretation:
- Offset 225: `bool isBusMode` → `uint8 mode` (0=taxi, 1=bus, 2=OFT)

### API Changes

New vendor interface: `src/vendor/bridges/layerzero/IOFT.sol`
- `IOFT.send(SendParam, MessagingFee, address)` — cross-chain OFT transfer
- `IOFT.token()` — underlying token address

## Implementation Plan

### Phase 1: Interface & Hook Changes
- [ ] Create `IOFT.sol` vendor interface
- [ ] Update `StargateSendHook.sol` — mode decoding, validation, branched execution building
- [ ] Update `ApproveAndStargateSendHook.sol` — same changes + approval target branching
- [ ] Update NatSpec and struct field names

### Phase 2: Testing
- [ ] Unit tests for mode=2 (both hooks, all lzTokenFee/compose/usePrevHookAmount combinations)
- [ ] Unit tests for mode>2 revert
- [ ] Regression: existing mode 0/1 tests pass unchanged
- [ ] Fork integration tests with UP OFTAdapter (Ethereum) and UP OFT (Base)

### Phase 3: Deployment
- [ ] Regenerate locked bytecode
- [ ] Deploy updated hooks (new CREATE2 addresses)
- [ ] Coordinate bundler update for new hook addresses

## Test Plan
- [ ] Unit tests for: StargateSendHook mode=2, ApproveAndStargateSendHook mode=2, invalid mode revert, mode=2 with composeMsg, mode=2 with lzTokenFee, mode=2 with usePrevHookAmount
- [ ] Integration tests for: UP OFTAdapter on Ethereum mainnet fork, UP OFT on Base fork
- [ ] E2E tests for: Full ERC-4337 flow with OFT send (if feasible)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Wrong msg.value in OFT mode (ETH stuck in OFT contract) | Cross-Chain | Low | Critical | Separate value computation per mode branch | N/A |
| Malicious IOFT drains approved tokens | Token Behavior | Low | High | `token()` validation + bundler trust (same as Stargate) | Calldata Injection Jan 2026 - $17M |
| Weak DVN config on generic OFT | Cross-Chain | Medium | High | Document in SECURITY.md; outside hook control | KelpDAO Apr 2026 - $292M |
| Mode flag injection attack | Access Control | Very Low | High | Merkle-signed calldata prevents modification | N/A |
| Destination executor rejects OFT compose | Operational | Medium | Medium | Whitelist OFT addresses in executor config | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| New hooks or extend existing? | Extend existing with mode flag | Interview |
| Backward compatibility needed? | No, bundler update coordinated | Interview |
| Separate IOFT interface or extend IStargate? | Separate IOFT.sol in vendor/bridges/layerzero/ | Research |
| Mode flag position? | Offset 225 (reuse isBusMode byte) | Research |
| Does IOFT SendParam have oftCmd? | Yes, identical struct to IStargate.SendParam | Framework docs research |
| lzTokenFee supported in Mode 2? | Yes, same pattern (approval to OFT address) | Specflow analysis |

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
After approval, run: `/superform:work specs/oft-send-hook/technical-spec.md`
