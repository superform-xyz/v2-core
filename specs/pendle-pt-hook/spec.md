# PendlePTHook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Pendle Alignment
- Linear Issue: N/A
- Interview Date: 2026-07-28
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

PendlePTHook is a simplified Pendle hook for PT (Principal Token) operations. It derives the operation type entirely from header fields (`inputToken`/`outputToken`) and on-chain state (`yt.isExpired()`), eliminating the need for a selector in the payload. This produces a simpler hook with less payload overhead, no limit order support, and an on-chain expiry check that prevents selector-mismatch errors.

The hook supports three operations: buying PT via AMM swap, selling PT pre-maturity via AMM, and redeeming PT+YT post-maturity. It shares the same trust model, interfaces, and sizing support as PendleUnifiedHook.

## Requirements

### Functional
1. Route operations based on header tokens + YT expiry:
   - `outputToken == PT && inputToken != PT` → `swapExactTokenForPt`
   - `inputToken == PT && !yt.isExpired()` → `swapExactPtForToken`
   - `inputToken == PT && yt.isExpired()` → `redeemPyToToken`
   - Anything else → revert
2. No selector in payload — payload contains only routing params
3. No limit orders — pure AMM swaps + par redemption only
4. Derive PT/YT/SY from `IPendleMarket(yieldSource).readTokens()` (single call)
5. Same `inspect()` format: `abi.encodePacked(yieldSource, outputToken)` (40 bytes)
6. Implement `ISuperHookOutflow` for OMS sizing
7. Support `usePrevHookAmount` chaining
8. Support native ETH input for buy path

### Non-Functional
- Gas consumption comparable to or better than PendleUnifiedHook (fewer payload bytes, no limit order validation)
- Same security guarantees as PendleUnifiedHook

## Technical Design

### Architecture
Same contract inheritance as PendleUnifiedHook:
- `BaseHook` + `ISuperHookSwap` + `ISuperHookContextAware` + `ISuperHookInflowOutflow` + `ISuperHookOutflow` + `ISuperHookInspector`
- Immutable `PENDLE_ROUTER_V4` address
- HookSubType: `PTYT`

### Data Model
Standard swap calldata layout (Layer 0 + Layer 1 + Layer 2). Payload encoding per operation:

| Operation | Payload |
|-----------|---------|
| Buy PT | `abi.encode(tokenMintSy, pendleSwap, SwapData, ApproxParams)` |
| Sell PT | `abi.encode(tokenRedeemSy, pendleSwap, SwapData)` |
| Redeem PT | `abi.encode(tokenRedeemSy, pendleSwap, SwapData)` |

### Key Differences from PendleUnifiedHook
| Aspect | PendleUnifiedHook | PendlePTHook |
|--------|-------------------|--------------|
| Operation routing | `bytes4 selector` in payload | Header tokens + `yt.isExpired()` |
| Limit orders | Supported (`LimitOrderData`) | Not supported (always empty) |
| Payload prefix | `abi.encode(selector, routingParams)` | `abi.encode(routingParams)` only |
| Expiry validation | Off-chain (signer chooses selector) | On-chain (`yt.isExpired()`) |
| `readTokens()` calls | Once per builder (3x in worst case) | Once in dispatcher |

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `src/hooks/swappers/pendle/PendlePTHook.sol`
- [ ] Implement `_buildHookExecutions` with token-based routing + expiry check
- [ ] Implement `_buildSwapTokenForPtExecutions` (buy, no limit orders)
- [ ] Implement `_buildSwapPtForTokenExecutions` (sell, no limit orders)
- [ ] Implement `_buildRedeemExecutions` (redeem, same as PendleUnifiedHook minus limit orders)
- [ ] Implement ISuperHookSwap methods (encode/decode)
- [ ] Implement ISuperHookOutflow (decodeAmounts, amountRoles, replaceCalldataAmounts)
- [ ] Implement inspect() returning 40-byte packed format
- [ ] Add to hook-classification.yaml + Constants.sol

### Phase 2: Testing
- [ ] Unit tests: all 3 paths, error cases, sizing, inspect
- [ ] Integration tests: fork tests against real Pendle markets
- [ ] Bytecode generation and locking

## Test Plan
- [ ] Unit tests for: buy/sell/redeem paths, invalid token combinations, usePrevHookAmount, inspect, sizing
- [ ] Integration tests for: real Pendle market swaps/redeems on Ethereum fork
- [ ] Edge cases: expiry boundary, zero amounts, invalid SwapData, native ETH input

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Malicious market via `readTokens()` | Access Control | Low | High | Intent signer trust model (same as PendleUnifiedHook) | Penpie 2024 - $27M |
| Arbitrary `extRouter` calldata | Logic | Low | High | Pendle Router intermediary + intent signer trust | LI.FI 2024 - $9M |
| Expiry boundary race condition | Logic | Medium | Low | Correct by design — expired routes to redeem, Router rejects stale swaps | N/A |
| Precision loss in output scaling | Arithmetic | Low | Low | Zero-check on `scaledOutputMin`; documented in NatSpec | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Payload encoding? | `abi.encode(routingParams)` — no selector prefix | Cosmin |
| Limit orders? | No — pure AMM only | Cosmin |
| Inspect format? | Same as PendleUnifiedHook: `abi.encodePacked(yieldSource, outputToken)` | Cosmin |
| Sizing support? | Yes — ISuperHookOutflow with AMOUNT_POSITION at offset 92 | Cosmin |
| PT source? | Derived from `IPendleMarket(yieldSource).readTokens()` | Cosmin |
| Redeem mode? | `redeemPyToToken` (burns PT+YT pair) | Cosmin |
| Sell vs redeem differentiation? | `yt.isExpired()` on-chain check | Cosmin |

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
After approval, run: `/superform:work specs/pendle-pt-hook/technical-spec.md`
