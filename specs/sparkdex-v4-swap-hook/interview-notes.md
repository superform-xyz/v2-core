# SparkDEX V4 / Algebra Integral Swap Hook - Interview Notes

## Date: 2026-04-22

## Context
Byzantine requested integration with SparkDEX on Flare chain (chainId 14).
Address `0x2a91D9296ee2fe4139b49c7071b2f29f59a9f9aE` is SparkDEX V4 router built on Algebra Integral.

Existing Uniswap V3 hook is NOT compatible because Algebra Integral has a different `ExactInputSingleParams` struct:
- No `fee` field (Algebra uses dynamic fees, pools identified by token pair only)
- Uses `limitSqrtPrice` instead of `sqrtPriceLimitX96`
- Different ABI encoding = different function selector

## Decisions

### Swap Scope
- **Single-hop only** (`exactInputSingle`) - matches current UniV3 hook scope

### Hook Variants
- **Both variants** - `ApproveAndSwapAlgebraIntegralHook` + `SwapAlgebraIntegralHook` (mirrors UniV3 pattern)

### Data Layout
- **New compact layout** - remove `fee` field entirely. Shorter calldata, cleaner design. Off-chain tooling needs to handle this as a different hook type anyway.

### Token Handling
- **Same as UniV3** - block `address(0)` for native tokens, require wrapped native (e.g., WFLR on Flare)

### Chain Scope
- **Chain-agnostic** - generic Algebra Integral hook that can be deployed anywhere with an Algebra router (SparkDEX on Flare, QuickSwap on Polygon, Camelot on Arbitrum, etc.)
- Name: `AlgebraIntegralSwapHook` / `ApproveAndSwapAlgebraIntegralHook`

### Testing Strategy
- **Both fork + unit tests**
  - Unit tests with mocked router interface
  - Fork integration tests against live SparkDEX V4 router on Flare

## Data Layout (New Compact - No Fee Field)

```
Offset  Size  Field
0       20    tokenIn (address)
20      20    tokenOut (address)
40      20    recipient (address)
60      32    deadline (uint256)
92      32    limitSqrtPrice (uint160, packed as uint256)
124     32    originalAmountIn (uint256)
156     32    originalMinAmountOut (uint256)
188     1     usePrevHookAmount (bool)
```

Total minimum data length: 189 bytes (vs 193 for UniV3 hook)

## Algebra Integral ExactInputSingleParams

```solidity
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 limitSqrtPrice;
}
```

## Security Considerations
- Same security model as UniV3 hook (non-accounting, swap type)
- Approval reset pattern (approve(0) -> approve(amount) -> swap -> approve(0))
- Deadline validation
- Recipient forced to account for balance tracking
- No fee field reduces attack surface slightly
