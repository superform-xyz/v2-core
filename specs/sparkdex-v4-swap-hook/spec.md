# Algebra Integral Swap Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: SparkDEX / Flare Integration
- Linear Issue: N/A
- Interview Date: 2026-04-22
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create a chain-agnostic swap hook for Algebra Integral v1.2 DEX routers, requested by Byzantine for SparkDEX V4 on Flare. The hook mirrors the existing Uniswap V3 swap hook pattern but adapts for Algebra's different router interface: no `fee` field, adds `deployer` field (for custom pool deployers), and renames `sqrtPriceLimitX96` to `limitSqrtPrice`.

**Critical discovery during research**: The address Byzantine provided (`0x2a91D9296ee2fe4139b49c7071b2f29f59a9f9aE`) is NOT the V4 SwapRouter. The actual SparkDEX V4 SwapRouter on Flare is `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F`. Also, Algebra Integral v1.2 (used by SparkDEX V4) has a `deployer` field in `ExactInputSingleParams` that wasn't initially anticipated.

## Requirements

### Functional
1. Two hook variants: `SwapAlgebraIntegralHook` and `ApproveAndSwapAlgebraIntegralHook`
2. Single-hop swaps only (`exactInputSingle`)
3. Chain-agnostic deployment (SparkDEX on Flare, any future Algebra v1.2+ DEX)
4. Hook chaining via `usePrevHookAmount` with proportional slippage scaling
5. Balance-delta output tracking via pre/post execute

### Non-Functional
- Follow existing codebase conventions exactly (same as UniV3 hook)
- Solidity 0.8.30, Apache-2.0 license

## Technical Design

### Architecture

Same architecture as UniV3 swap hooks. Extends `BaseHook` with `HookType.NONACCOUNTING` + `HookSubTypes.SWAP`. Immutable router address set in constructor.

### Data Layout (209 bytes)

```
Offset  Size  Field
0       20    tokenIn
20      20    tokenOut
40      20    deployer          (pool deployer, address(0) for base pools)
60      20    recipient         (IGNORED - forced to account)
80      32    deadline
112     32    limitSqrtPrice    (0 = no price limit)
144     32    originalAmountIn
176     32    originalMinAmountOut
208     1     usePrevHookAmount
```

### Key Differences from UniV3 Hook
- No `fee` field (Algebra uses dynamic fees)
- Added `deployer` field (Algebra v1.2 custom pool deployers)
- `limitSqrtPrice` instead of `sqrtPriceLimitX96`
- 209 bytes minimum vs 193 for UniV3

## Implementation Plan

### Phase 1: Core Hook + Interface
- [ ] Create `src/hooks/swappers/algebra-integral/interfaces/IAlgebraSwapRouter.sol`
- [ ] Create `src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol`
- [ ] Create `src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol`
- [ ] Add constants to `test/utils/Constants.sol` and `script/utils/Constants.sol`

### Phase 2: Tests
- [ ] Create `test/unit/hooks/swappers/algebra-integral/AlgebraIntegralUnitTests.t.sol`
- [ ] Create fork integration test against SparkDEX V4 on Flare

## Test Plan
- [ ] Unit tests: constructor, build, pre/post execute, decode, inspect, data length, deadline, native rejection, recipient forcing, fuzz
- [ ] Fork integration test: WFLR -> USDC swap via SparkDEX V4 on Flare (chainId 14)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Sandwich attack on swap | MEV | Medium | Medium | amountOutMinimum + limitSqrtPrice | Standard DEX risk |
| Approval drain | Token Behavior | Low | High | approve(0)->approve(exact)->swap->approve(0) | Li.Fi 2024 - $11M |
| Wrong router address from Byzantine | Operational | Confirmed | High | Verified correct address from SparkDEX docs | N/A |
| Fee-on-transfer input token | Token Behavior | Low | Low | Router reverts; balance-delta handles output | Standard DEX risk |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Single-hop or multi-hop? | Single-hop only | User |
| One or both variants? | Both (Swap + ApproveAndSwap) | User |
| Data layout with or without fee? | Compact (no fee), but discovered `deployer` field needed | Research |
| Chain-specific or agnostic? | Chain-agnostic | User |
| Test strategy? | Both unit + fork tests | User |
| Correct router address? | `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F` (not Byzantine's address) | Research |

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
After approval, run: `/superform:work specs/sparkdex-v4-swap-hook/technical-spec.md`
