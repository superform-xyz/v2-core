# Stargate V2 Bridge Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Bridge Expansion
- Linear Issue: N/A
- Interview Date: 2026-05-05
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Add Stargate V2 (LayerZero) bridge support to Superform via two hook contracts: `StargateSendHook` (native ETH) and `ApproveAndStargateSendHook` (ERC20). Both follow the established bridge hook pattern with `usePrevHookAmount` chaining, validator signature injection for destination execution via LZ compose messages, and taxi/bus mode selection. Unlike Across (single SpokePool per chain), Stargate V2 has per-token pools, so the pool address is passed in hook data rather than stored in the constructor - making deployment simpler (only needs `validator_`).

## Requirements

### Functional
1. Send native tokens cross-chain via Stargate V2 pools (value = lzNativeFee + amountLD)
2. Send ERC20 tokens cross-chain with approval pattern (value = lzNativeFee only)
3. Support destination execution via LZ composeMsg with validator signature injection
4. Support `usePrevHookAmount` with proportional `minAmountLD` scaling via `Math.mulDiv`
5. Support taxi mode (immediate, `oftCmd = ""`) and bus mode (batched, `oftCmd = 0x01`)
6. Implement `ISuperHookContextAware` and `ISuperHookInspector` interfaces

### Non-Functional
- Gas efficient: tight packing with BytesLib (consistent with Across/deBridge)
- Chain-agnostic: bundler provides pool addresses and LZ endpoint IDs
- Minimal constructor: only `validator_` (deploys unconditionally on all chains)

## Technical Design

### Architecture

```
┌─────────────────────────────────────────────────┐
│ SuperBundler (off-chain)                        │
│ - Selects Stargate pool per token/chain         │
│ - Computes LZ fee via quoteSend()               │
│ - Builds extraOptions for compose gas           │
│ - Encodes hook data with tight packing          │
└──────────────────┬──────────────────────────────┘
                   │ hook data
                   ▼
┌──────────────────────────────────────────┐
│ StargateSendHook / ApproveAndStargate    │
│ - Decodes data via BytesLib              │
│ - Handles usePrevHookAmount scaling      │
│ - Appends validator signature to compose │
│ - Builds Execution → IStargate.sendToken │
└──────────────────┬───────────────────────┘
                   │ sendToken()
                   ▼
┌──────────────────────────────────┐
│ Stargate V2 Pool (per-token)     │
│ → LayerZero V2 messaging        │
│ → Destination Stargate Pool      │
│ → lzCompose (if composeMsg set)  │
│ → SuperDestinationExecutor       │
└──────────────────────────────────┘
```

### Data Model

Hook data layout (tight packed, 238 bytes minimum):

| Offset | Type | Size | Field |
|--------|------|------|-------|
| 0 | uint256 | 32 | lzNativeFee |
| 32 | address | 20 | stargatePool |
| 52 | address | 20 | inputToken |
| 72 | uint32 | 4 | dstEid |
| 76 | bytes32 | 32 | to (recipient) |
| 108 | uint256 | 32 | amountLD |
| 140 | uint256 | 32 | minAmountLD |
| 172 | bool | 1 | usePrevHookAmount |
| 173 | bool | 1 | isBusMode |
| 174 | uint256 | 32 | extraOptionsLength |
| 206 | bytes | var | extraOptions |
| 206+eol | uint256 | 32 | composeMsgLength |
| 238+eol | bytes | var | composeMsg |

### API Changes

New vendor interface: `IStargate` with `sendToken()`, `quoteSend()`, `token()` functions and `SendParam`, `MessagingFee`, `MessagingReceipt`, `OFTReceipt` structs.

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `src/vendor/bridges/stargate/IStargate.sol`
- [ ] Create `src/hooks/bridges/stargate/StargateSendHook.sol`
- [ ] Create `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`
- [ ] Create `test/unit/hooks/bridges/StargateHooks.t.sol`
- [ ] Add hook key constants to `script/utils/Constants.sol`
- [ ] Verify compilation with `forge build`
- [ ] Run tests

## Test Plan
- [ ] Unit tests: constructor validation, basic build (taxi/bus), usePrevHookAmount, validation reverts, composeMsg injection, inspector, approval pattern
- [ ] Integration tests: mock Stargate pool interaction

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| LZ fee manipulation | Business Logic | Low | Medium | Bundler pre-quotes fee; excess refunded to account | N/A |
| Approval race condition | Token Behavior | Low | Low | Approve 0 before/after pattern (same as Across) | N/A |
| composeMsg corruption | Cross-Chain | Low | High | Full decode/re-encode (not byte manipulation) | Same pattern proven in Across/deBridge |
| Bus mode encoding mismatch | Business Logic | Medium | Low | Verify against deployed Stargate V2 contracts | N/A |
| Dust removal changes amountSent | Vault Accounting | Low | Low | minAmountLD provides slippage floor | Stargate V2 design |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Pool in constructor vs data? | Data (per-token pools) | Architecture |
| Chain IDs vs LZ EIDs? | EIDs (uint32, bundler maps) | Stargate V2 API |
| Bus mode encoding? | `abi.encodePacked(uint8(1))` | Stargate V2 docs |
| Taxi or both? | Both, configurable flag | Interview |
| Fee handling? | Separate lzNativeFee field | Interview |

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
After approval, run: `/superform:work specs/stargate-bridge-hook/technical-spec.md`
