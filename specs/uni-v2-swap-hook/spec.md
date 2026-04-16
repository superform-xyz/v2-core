# Uni V2 Swap Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Flare Chain Integration
- Linear Issue: N/A
- Interview Date: 2026-04-14
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Implement a generic Uniswap V2-compatible swap hook that works with any UniswapV2Router02-compatible DEX. SparkDex on Flare is the initial deployment target, but the hook is reusable across all Uni V2 forks (SushiSwap, PancakeSwap, etc.) by parameterizing the router address at deployment.

Two hook variants following the established dual-hook pattern: `SwapUniV2Hook` (pre-approved tokens) and `ApproveAndSwapUniV2Hook` (handles approval lifecycle). Both support multi-hop paths, native token swaps, and hook chaining via `usePrevHookAmount`.

## Requirements

### Functional
1. Execute swaps via `swapExactTokensForTokens` (ERC-20 to ERC-20)
2. Execute native input swaps via `swapExactETHForTokens` (detected by tokenIn == NATIVE sentinel)
3. Execute native output swaps via `swapExactTokensForETH` (detected by tokenOut == NATIVE sentinel)
4. Support multi-hop paths via variable-length address array in hook data
5. Support hook chaining via `usePrevHookAmount` with proportional `amountOutMin` scaling
6. Handle USDT-compatible approval pattern: approve(0) -> approve(amount) -> swap -> approve(0)
7. Skip approval steps when input is native token
8. Force recipient to smart account address for balance tracking integrity

### Non-Functional
- Compatible with any UniswapV2Router02 fork on any chain
- Gas efficient via tightly-packed BytesLib encoding
- Follows all established Superform hook patterns

## Technical Design

### Architecture

Three new files in `src/hooks/swappers/uniswap-v2/`:

| File | Purpose |
|------|---------|
| `IUniswapV2Router.sol` | Minimal interface (3 swap functions) |
| `SwapUniV2Hook.sol` | Swap without approval (1 inner execution) |
| `ApproveAndSwapUniV2Hook.sol` | Swap with approval (4 inner executions, or 1 for native input) |

Constructor: `(address router_, address native_, address weth_)` - three immutables.

### Data Model

Both variants share identical hook data layout:

| Field | Offset | Size | Description |
|-------|--------|------|-------------|
| tokenIn | 0 | 20 | Input token (NATIVE sentinel for native) |
| tokenOut | 20 | 20 | Output token (NATIVE sentinel for native) |
| deadline | 40 | 32 | Expiry timestamp |
| amountIn | 72 | 32 | Input amount |
| amountOutMin | 104 | 32 | Minimum output (slippage protection) |
| usePrevHookAmount | 136 | 1 | Chain from previous hook |
| pathLength | 137 | 32 | Number of addresses in path |
| path | 169 | pathLength*20 | Token addresses (always real, never NATIVE) |

### API Changes

No API changes. Hooks are passed via existing `ExecutorEntry.hooksAddresses[]` mechanism.

## Implementation Plan

### Phase 1: Core Contracts
- [ ] Create `IUniswapV2Router.sol` interface
- [ ] Implement `SwapUniV2Hook.sol` with native token support
- [ ] Implement `ApproveAndSwapUniV2Hook.sol` with conditional approval logic

### Phase 2: Testing
- [ ] Unit tests (single-hop, multi-hop, native in/out, chaining, approvals)
- [ ] Fuzz tests (path length, amounts, deadline boundaries)
- [ ] Edge cases (path length < 2, data truncation, native + usePrevHookAmount)

### Phase 3: Deployment
- [ ] Add deployment config (router/NATIVE/WETH addresses per chain)
- [ ] Deploy on Flare (SparkDex router: `0x4a1E5A90...`)
- [ ] Verify SparkDex router.WETH() returns WFLR address

## Test Plan
- [ ] Unit tests for: SwapUniV2Hook, ApproveAndSwapUniV2Hook
- [ ] Integration tests for: multi-hop paths, native swaps, hook chaining
- [ ] Fuzz tests for: path encoding boundaries, amount edge cases, deadline validation

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Sandwich attacks on AMM swaps | MEV | High | Medium | amountOutMin enforcement + off-chain calculation | Standard AMM risk |
| Fee-on-transfer tokens in path | Token Behavior | Medium | High | Not supported; document limitation | STA/Balancer 2020 ~$500K |
| Native balance interference in batch | Operational | Low | Medium | Document as known limitation | N/A |
| Reentrancy via native ETH callback | Reentrancy | Low | High | BaseHook mutex + V2 pair lock | SparkDEX Perps Aug 2025 |
| NATIVE sentinel passed to router path | Business Logic | Low | High | Path uses real WETH; sentinel for detection only | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| SparkDex interface compatibility? | Standard UniswapV2Router02 (QuickSwap fork) | Research |
| How to detect native input? | tokenIn == NATIVE sentinel; path uses real WETH | SpecFlow analysis |
| Shared data layout between variants? | Yes, both use same layout (follows Uni V3 pattern) | Codebase convention |
| Fee-on-transfer support? | Not in initial version; can add later | Interview |
| Approval skip for native? | Yes, conditional execution count (1 vs 4) | Interview |

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
After approval, run: `/superform:work specs/uni-v2-swap-hook/technical-spec.md`
