# Uniswap V3 Hook - Interview Notes

**Date:** 2026-01-30
**Interviewer:** Claude Code
**Interviewee:** Cosmin G.

## Context

The Superform v2-periphery will be deployed on Hyperliquid, which uses Uniswap V3 (not V4). Project X (prjx.com) is the primary DEX on Hyperliquid, which is a Uniswap V3 fork with a 20% protocol fee enabled by default.

**Reference:** https://github.com/hl-x-org/v3-core

## Requirements Summary

### Swap Operations
- **Scope:** `exactInputSingle` only (single-hop swaps with exact input amount)
- **Router:** Use the official SwapRouter (not direct pool interaction)
- **Rationale:** Simplest and most common use case; SwapRouter handles deadline, native ETH support

### Native ETH Support
- **Decision:** Support native ETH swaps with automatic WETH wrapping/unwrapping
- **Rationale:** Better UX for end users

### Slippage Handling
- **Decision:** Dynamic slippage recalculation (matching V4 hook pattern)
- **Rationale:** Essential for chained hooks where input amount may change from previous hook output
- **Implementation:** Recalculate `minAmountOut` proportionally when actual input differs from original

### Router Configuration
- **Decision:** Immutable constructor parameter
- **Rationale:** Gas efficient, simpler, one hook deployment per router instance

### Fee Tiers
- **Decision:** Pass fee tier in hook data (allow any fee tier)
- **Rationale:** Hyperliquid's Project X may have different tiers than standard Uniswap; flexibility for other chains

### Hook Variants
- **Decision:** Create both variants like Odos hooks:
  1. `SwapUniswapV3Hook` - assumes token is already approved/transferred
  2. `ApproveAndSwapUniswapV3Hook` - handles approval internally before swap
- **Rationale:** Flexibility for different use cases

### Data Format
- **Decision:** BytesLib packed format (like V4 hook)
- **Rationale:** Gas efficient, consistent with existing hooks in codebase

### Deadline
- **Decision:** Include deadline parameter in hook data
- **Rationale:** MEV protection for users

### Events
- **Decision:** No custom events needed
- **Rationale:** Rely on SwapRouter events; keep hook minimal

### Testing
- **Primary:** Hyperliquid (Project X)
- **Secondary:** Integration tests against other chains (Ethereum mainnet, Arbitrum) for standard Uni V3 compatibility

## Technical Decisions

### Hook Data Structure (Proposed)
Following the BytesLib packed format pattern from SwapUniswapV4Hook:

```
address tokenIn           = BytesLib.toAddress(data, 0);      // 20 bytes
address tokenOut          = BytesLib.toAddress(data, 20);     // 20 bytes
uint24 fee                = uint24(BytesLib.toUint32(data, 40)); // 3 bytes (padded to 4)
address recipient         = BytesLib.toAddress(data, 44);     // 20 bytes
uint256 deadline          = BytesLib.toUint256(data, 64);     // 32 bytes
uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 96)); // 20 bytes (padded to 32)
uint256 originalAmountIn  = BytesLib.toUint256(data, 128);    // 32 bytes
uint256 originalMinAmountOut = BytesLib.toUint256(data, 160); // 32 bytes
uint256 maxSlippageDeviationBps = BytesLib.toUint256(data, 192); // 32 bytes
bool usePrevHookAmount    = _decodeBool(data, 224);           // 1 byte
```

Total: 225 bytes minimum

### Files to Create
1. `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`
2. `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol`
3. `src/vendor/uniswap-v3/ISwapRouter.sol` (if not importing from lib)
4. `test/unit/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.t.sol`
5. `test/unit/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.t.sol`
6. `test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol`

### Key Dependencies
- `BaseHook` from `src/hooks/BaseHook.sol`
- `BytesLib` from `src/vendor/BytesLib.sol`
- `HookSubTypes` from `src/libraries/HookSubTypes.sol`
- `ISuperHook` interfaces
- OpenZeppelin `IERC20`, `Math`

### External References
- Project X (Hyperliquid): https://github.com/hl-x-org/v3-core
- Uniswap V3 SwapRouter: `ISwapRouter.exactInputSingle`
- Existing V4 hook for reference: `src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol`

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| V3 or V4? | V3 - Project X is Uni V3 fork | Cosmin |
| Swap types | exactInputSingle only | Cosmin |
| Router vs Pool | SwapRouter | Cosmin |
| Native ETH | Yes, support native ETH | Cosmin |
| Slippage | Dynamic recalculation | Cosmin |
| Router config | Immutable constructor | Cosmin |
| Fee tiers | Any (in hook data) | Cosmin |
| Hook variants | Both (Swap + ApproveAndSwap) | Cosmin |
| Data format | BytesLib packed | Cosmin |
| Deadline | Yes, in hook data | Cosmin |
| Events | No custom events | Cosmin |
| Testing | Hyperliquid primary + other chains | Cosmin |

## Risks & Considerations

1. **Protocol Fee Difference:** Project X has 20% protocol fee enabled by default (vs 0% on standard Uni V3). This affects expected output amounts but shouldn't impact hook logic.

2. **SwapRouter Address:** Different on each chain - need to deploy separate hook instances per chain/router.

3. **Native ETH Handling:** Requires careful handling of msg.value and WETH wrapping.

4. **Dynamic Slippage:** Must validate that ratio deviation doesn't exceed `maxSlippageDeviationBps` to prevent griefing attacks.
