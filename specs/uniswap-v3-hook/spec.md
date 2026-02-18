# Uniswap V3 Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Hyperliquid Deployment
- Linear Issue: N/A
- Interview Date: 2026-01-30
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create `SwapUniswapV3Hook` and `ApproveAndSwapUniswapV3Hook` to enable token swaps via Uniswap V3's SwapRouter on Hyperliquid (Project X DEX). This enables v2-periphery deployment on Hyperliquid, which only supports Uniswap V3.

The hooks follow existing patterns (Odos, 1inch) with BytesLib packed data format, dynamic slippage recalculation via `HookDataUpdater`, and support for hook chaining. Native ETH swaps require chaining with `DepositWETHHook`/`WithdrawWETHHook`.

## Requirements

### Functional
1. Execute `exactInputSingle` swaps via Uniswap V3 SwapRouter
2. Support hook chaining with `usePrevHookAmount` flag
3. Dynamically recalculate `minAmountOut` when chained (proportional to input change)
4. Two variants: SwapUniswapV3Hook (pre-approved) and ApproveAndSwapUniswapV3Hook (handles approval)
5. Work with Project X (Hyperliquid's Uniswap V3 fork)

### Non-Functional
- Gas usage within 10% of equivalent Odos hook operations
- BytesLib packed data format for gas efficiency
- Immutable router address in constructor

## Technical Design

### Architecture

```
                    ┌─────────────────────────────────────┐
                    │         SuperExecutor               │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │     SwapUniswapV3Hook               │
                    │  ┌─────────────────────────────┐    │
                    │  │  _buildHookExecutions()     │    │
                    │  │  _preExecute()              │    │
                    │  │  _postExecute()             │    │
                    │  └─────────────────────────────┘    │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │   Uniswap V3 SwapRouter             │
                    │   exactInputSingle()                │
                    └─────────────────────────────────────┘
```

### Data Model

BytesLib packed format (225 bytes):
- `tokenIn` (address): Input ERC-20 token
- `tokenOut` (address): Output ERC-20 token
- `fee` (uint24): Pool fee tier (500, 3000, 10000)
- `recipient` (address): Swap output recipient
- `deadline` (uint256): MEV protection timestamp
- `sqrtPriceLimitX96` (uint160): Price limit (0 = no limit)
- `originalAmountIn` (uint256): Original amount for slippage calc
- `originalMinAmountOut` (uint256): Original minimum output
- `reserved` (uint256): Reserved for future use
- `usePrevHookAmount` (bool): Use previous hook's output

### API Changes

New contracts:
- `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`
- `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol`

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `SwapUniswapV3Hook.sol` with exact Odos pattern
- [ ] Create `ApproveAndSwapUniswapV3Hook.sol` with approve-swap-cleanup cycle
- [ ] Copy/import ISwapRouter interface

### Phase 2: Testing
- [ ] Unit tests for data decoding
- [ ] Unit tests for usePrevHookAmount scenarios
- [ ] Unit tests for slippage recalculation
- [ ] Integration tests on forked Ethereum mainnet
- [ ] Integration tests on Hyperliquid (when testnet available)

### Phase 3: Deployment
- [ ] Deploy to Hyperliquid staging
- [ ] Verify with Project X router
- [ ] Deploy to production

## Test Plan
- [ ] Unit tests for: Data decoding, constructor, decodeUsePrevHookAmount, inspect
- [ ] Integration tests for: DAI->USDC swap, WETH->DAI swap, chained swaps
- [ ] E2E tests for: Full user flow with SuperExecutor on Hyperliquid

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Project X interface differs from V3 | Low | High | Verify before deployment |
| Fee-on-transfer token used | Medium | Medium | Document as unsupported |
| Approval cleanup fails | Low | Low | Transaction reverts atomically |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| V3 or V4? | V3 - Project X is V3 fork | Cosmin |
| Native ETH handling? | Manual chaining with WETH hooks | Cosmin |
| Slippage formula? | HookDataUpdater pattern | Cosmin |
| Fee validation? | No validation, let router handle | Cosmin |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)
- [repo-analysis.md](./research/repo-analysis.md)
- [best-practices.md](./research/best-practices.md)
- [framework-docs.md](./research/framework-docs.md)
- [specflow-analysis.md](./research/specflow-analysis.md)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/uniswap-v3-hook/technical-spec.md`
