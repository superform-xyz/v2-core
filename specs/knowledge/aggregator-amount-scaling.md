# Aggregator Swap Calldata: Dynamic Amount Scaling for usePrevHookAmount

## Problem

When hooks are chained with `usePrevHookAmount=true`, the input amount to a swap hook changes based on the previous hook's output. DEX aggregator APIs (KyberSwap, 1inch, 0x) return encoded calldata **optimized for a specific input amount**. Changing the amount post-hoc risks:

1. **Mismatched token distribution** — KyberSwap's `srcAmounts[]` defines how much each pool executor receives. If `desc.amount` changes but `srcAmounts[]` doesn't, the router distributes wrong amounts.
2. **Stale multihop routing** — `targetData` (KyberSwap) / `data` (1inch) contain opaque routing instructions with potentially hardcoded intermediate amounts for each hop.
3. **Slippage reverts** — proportionally scaled `minReturnAmount` assumes linear price impact, but multihop with limited intermediate liquidity has non-linear slippage.

## Aggregator Safety Matrix

| Aggregator | Risk Level | Why |
|---|---|---|
| **Odos** | LOW | Amount separated from `pathDefinition`. Executor receives `amountsIn` as separate parameter — updating `inputAmount` in `swapTokenInfo` is sufficient. |
| **1inch `unoswapTo`** | LOW | Single-pool swap, amount is a direct parameter. Safe to re-encode. |
| **KyberSwap (with ScaleHelper)** | LOW | ScaleHelper decodes and re-scales `targetData` internals for multihop routes. |
| **KyberSwap (proportional fallback)** | MEDIUM | Scales `desc.amount`, `srcAmounts`, `feeAmounts`, `minReturnAmount`. Does NOT update `targetData` internals. Works for simple routes, risky for complex multihop. |
| **1inch generic `swap`** | MEDIUM-HIGH | Updates `desc.amount` and `desc.minReturnAmount` but NOT executor `data` blob. Executor may or may not adapt to actual balance. |
| **0x Settler** | NONE | Uses `bps` (basis-points of balance) pattern — amount resolved at execution time via `balanceOf()`. API: `sellEntireBalance=true`. |

## Solution: KyberSwap ScaleHelper Integration

### Architecture

```
_updateTxDataAmounts(txData, newAmount, originalAmount)
    │
    ├─ [Primary] ScaleHelper.getScaledInputData(txData, newAmount)
    │   └─ Decodes SwapExecutionParams, walks targetData to identify each
    │      DEX-specific sub-call, proportionally adjusts intermediate amounts.
    │      Returns isSuccess=false for non-scalable sources.
    │
    └─ [Fallback] Proportional scaling of desc-level fields only
        ├─ desc.amount = newAmount
        ├─ desc.minReturnAmount (via HookDataUpdater)
        ├─ desc.srcAmounts[i] = mulDiv(srcAmounts[i], newAmount, originalAmount)
        └─ desc.feeAmounts[i] = mulDiv(feeAmounts[i], newAmount, originalAmount)
```

### Key Details

- **ScaleHelper contract**: `0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D` (same on all chains)
- **Function**: `getScaledInputData(bytes calldata, uint256) → (bool, bytes)` — **view function**
- **Scaling window**: +/-5% of original amount (returns `isSuccess=false` beyond that)
- **Non-scalable sources**: Returns `isSuccess=false` when route contains DEX sources that can't be proportionally scaled (e.g., limit orders, RFQ quotes)
- **API parameter**: `onlyScalableSources=true` ensures all DEX sources in the route are scalable — but this is optional and may limit routing quality. Without it, ScaleHelper is a best-effort optimization.
- **Constructor**: Both hooks take `scaleHelper_` as second constructor arg. Pass `address(0)` to disable ScaleHelper (fallback-only mode).

### Why NOT `onlyScalableSources=true` by Default

Using `onlyScalableSources=true` in the KyberSwap API would exclude non-scalable DEX sources (limit orders, RFQ, etc.) from routing. This limits routing options and may produce worse prices. Instead:

- Generate routes normally (best routing quality)
- If `usePrevHookAmount` triggers, try ScaleHelper first
- If ScaleHelper fails, fall back to proportional scaling
- The off-chain system can optionally enable `onlyScalableSources=true` when it knows `usePrevHookAmount` will be active AND wants maximum safety

## Patterns Found in Other Protocols

### 0x Settler: BPS Pattern (Best-in-class)
```solidity
// Amount is fraction of current balance, resolved at execution time
uint256 amount = (sellToken.balanceOf(address(this)) * bps) / 10000;
```
- API parameter: `sellEntireBalance=true`
- No calldata patching needed — amount adapts automatically
- If we add 0x support, this eliminates the problem entirely

### Uniswap Universal Router: CONTRACT_BALANCE Sentinel
```solidity
uint256 constant CONTRACT_BALANCE = 1 << 255;
// When amountIn == CONTRACT_BALANCE: amountIn = token.balanceOf(address(this))
```

### Balancer V2: Zero Amount Sentinel
```solidity
// In batchSwap, amount=0 on step N means "use output from step N-1"
if (step.amount == 0) step.amount = previousAmountCalculated;
```

### Odos Router: Balance-based Mode
```solidity
// In swapRouterFunds, amountIn=0 means "use balanceOf"
if (amountIn == 0) amountIn = token.balanceOf(address(this));
```

## Files Modified

- `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol` — Added ScaleHelper primary + proportional fallback
- `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol` — Same
- `src/vendor/kyberswap/IScaleHelper.sol` — New interface for ScaleHelper contract

## Recommendations for Future Aggregator Hooks

1. **Prefer aggregators with native balance-based patterns** (0x, Uniswap) for `usePrevHookAmount` chains
2. **For KyberSwap**: Always deploy with ScaleHelper address; API callers should consider `onlyScalableSources=true` when dynamic amounts are expected
3. **For 1inch**: `unoswapTo` is safe; `swap()` has the opaque `data` issue — no ScaleHelper equivalent exists
4. **Off-chain re-quoting**: The bundler should re-quote with fresh API data when the amount delta exceeds 5%, rather than relying on on-chain calldata patching
5. **Never set `minReturnAmount = 0`** — it removes router-level slippage protection. A malfunctioning executor could drain tokens with zero output.
