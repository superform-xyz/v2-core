# Spark PSM Hook - SpecFlow Analysis

## User Flow Overview

The Spark PSM Hook feature introduces four hooks that function as atomic swap units within Superform's modular hook chain. Each hook is stateless between transactions and executes as part of a larger `build()` sequence assembled by `SuperExecutor`.

### Flow 1: SwapSparkPSMExactInHook - Standalone (usePrevHookAmount = false)

```
User signs intent with hook chain
  -> SuperExecutor.execute()
    -> SwapSparkPSMExactInHook.build()
      -> Execution[0]: this.preExecute()  // stores assetOut balance of account
      -> Execution[1]: PSM.swapExactIn(assetIn, assetOut, amountIn, minAmountOut, account, referralCode)
      -> Execution[2]: this.postExecute() // sets outAmount = finalBalance - initialBalance
```

### Flow 2: SwapSparkPSMExactInHook - Chained (usePrevHookAmount = true)

```
PreviousHook completes, sets outAmount on transient storage
  -> SwapSparkPSMExactInHook.build()
    -> amountIn = ISuperHookResult(prevHook).getOutAmount(account)
    -> minAmountOut scaled via HookDataUpdater.getUpdatedOutputAmount(newAmountIn, originalAmountIn, originalMinAmountOut)
    -> Execution[0]: this.preExecute()
    -> Execution[1]: PSM.swapExactIn(assetIn, assetOut, amountIn_updated, minAmountOut_scaled, account, referralCode)
    -> Execution[2]: this.postExecute() // outAmount passed to next hook
```

### Flow 3: ApproveAndSwapSparkPSMExactInHook - Standalone

```
  -> ApproveAndSwapSparkPSMExactInHook.build()
    -> Execution[0]: this.preExecute()
    -> Execution[1]: assetIn.approve(PSM, 0)          // reset for USDT-like tokens
    -> Execution[2]: assetIn.approve(PSM, amountIn)   // set exact approval
    -> Execution[3]: PSM.swapExactIn(...)
    -> Execution[4]: assetIn.approve(PSM, 0)          // revoke
    -> Execution[5]: this.postExecute()
```

### Flow 4: ApproveAndSwapSparkPSMExactInHook - Chained

Same as Flow 3 but amountIn is replaced by prevHook.getOutAmount(account) and the approval at Execution[2] uses this updated amount.

### Flow 5: SwapSparkPSMExactOutHook - Standalone

```
  -> Execution[0]: this.preExecute()  // stores assetOut balance
  -> Execution[1]: PSM.swapExactOut(assetIn, assetOut, amountOut, maxAmountIn, account, referralCode)
  -> Execution[2]: this.postExecute() // outAmount = delta in assetOut balance
```

### Flow 6: SwapSparkPSMExactOutHook - Chained (usePrevHookAmount = true)

```
prevHook.getOutAmount(account) -> amountOut (replaces the fixed desired output)
maxAmountIn scaled: HookDataUpdater.getUpdatedOutputAmount(newAmountOut, originalAmountOut, originalMaxAmountIn)
  -> PSM.swapExactOut(assetIn, assetOut, amountOut_updated, maxAmountIn_scaled, account, referralCode)
```

### Flow 7: ApproveAndSwapSparkPSMExactOutHook - Standalone

```
  -> Execution[0]: this.preExecute()
  -> Execution[1]: assetIn.approve(PSM, 0)
  -> Execution[2]: assetIn.approve(PSM, maxAmountIn)   // NOTE: must approve maxAmountIn, not amountOut
  -> Execution[3]: PSM.swapExactOut(...)
  -> Execution[4]: assetIn.approve(PSM, 0)
  -> Execution[5]: this.postExecute()
```

### Flow 8: Cross-chain composition (PSM swap on Base -> Morpho vault)

```
UserOp hook chain:
  Hook 1: BatchTransferFromHook (pull USDC from user via Permit2)
  Hook 2: ApproveAndSwapSparkPSMExactInHook (USDC -> USDS, usePrevHookAmount=true)
  Hook 3: ApproveAndDeposit4626VaultHook (USDS -> Morpho vault, usePrevHookAmount=true)
  Hook 4: MintSuperPositionsHook (mint SP tokens)
```

### Flow 9: Redemption path (Morpho -> PSM -> USDC)

```
  Hook 1: Redeem4626VaultHook (burn Morpho shares, receive USDS)
  Hook 2: ApproveAndSwapSparkPSMExactInHook (USDS -> USDC, usePrevHookAmount=true)
  Hook 3: OfframpTokensHook or TransferERC20Hook (send USDC to user)
```

### Flow 10: sUSDS swap path

```
  Hook 1: SwapSparkPSMExactInHook (USDC -> sUSDS, usePrevHookAmount=false, oracle-based rate)
  Hook 2: MintSuperPositionsHook
```

---

## Flow Permutations Matrix

| Dimension | SwapExactIn | ApproveAndSwapExactIn | SwapExactOut | ApproveAndSwapExactOut |
|---|---|---|---|---|
| usePrevHookAmount=false | Uses amountIn as-is | Uses amountIn as-is | Uses amountOut as-is | Uses amountOut as-is |
| usePrevHookAmount=true | amountIn=prevOut, minOut scaled | amountIn=prevOut, approve(prevOut), minOut scaled | amountOut=prevOut, maxIn scaled | amountOut=prevOut, approve(maxIn scaled), maxIn scaled |
| prevHook amount > original | minOut increases proportionally | approve(larger amount) | maxIn increases proportionally | approve(larger maxIn) |
| prevHook amount < original | minOut decreases proportionally | approve(smaller amount) | maxIn decreases proportionally | approve(smaller maxIn) |
| prevHook amount = 0 | amountIn=0, PSM will likely revert | approve(0), PSM reverts | amountOut=0, PSM may succeed returning 0 | approve(0) is first step anyway |
| USDC <-> USDS | 1:1 rate, decimal adjust | same | same | same |
| USDC <-> sUSDS | oracle rate (1e27) | same | same | same |
| sUSDS <-> USDS | oracle rate (1e27) | same | same | same |
| PSM drained | Reverts with PSM error | Reverts at swap step | Same | Same |
| Hook data < 157 bytes | Should revert INVALID_HOOK_DATA | same | same | same |

---

## Identified Gaps

### Critical Gaps

**Gap 3 - ExactOut Approve Amount:** For `ApproveAndSwapSparkPSMExactOutHook`, the approval must be `maxAmountIn` (not `amountOut`). The PSM pulls a variable `amountIn <= maxAmountIn`. If approval is set to `amountOut` instead, the hook fails at runtime for sUSDS pairs where `actualAmountIn > amountOut`.

**Gap 4 - ExactOut Chained Approve:** With `usePrevHookAmount=true`, the scaled `maxAmountIn` must be used for the approval, not the original value.

**Gap 5 - ExactOut Chaining Semantics:** When chaining into ExactOut, the previous hook's `outAmount` becomes `amountOut`. But if the previous hook delivered `assetIn` tokens (not `assetOut`), using that quantity as `amountOut` is semantically wrong. The spec must define what the upstream hook must deliver.

### Important Gaps

**Gap 1 - Receiver Field:** The `receiver` field in hook data (offset 104) is always overridden to `account`. The field exists only for byte offset alignment.

**Gap 7 - Decimal Mismatch Warning:** USDC (6 dec) vs USDS/sUSDS (18 dec) - HookDataUpdater scales raw integers correctly, but integrators need to be warned about decimal implications.

**Gap 8 - Zero Amount Propagation:** No guard against `prevHook.getOutAmount()=0`, which could silently propagate zeros through the chain.

**Gap 13 - sUSDS Slippage Guidance:** No recommendation for appropriate slippage % for sUSDS swaps.

**Gap 14 - Preview Rounding:** Preview functions don't round the same way as actual swaps. Off-chain quoting must add a buffer.

**Gap 15 - Data Length Guard:** Hooks should check `data.length >= 157` and revert with `INVALID_HOOK_DATA`.

### Answers to Critical Questions (Default Assumptions)

1. **ExactOut approve amount** → `maxAmountIn` (the upper bound on input consumption)
2. **ExactOut chained approve** → Uses scaled `maxAmountIn` (same value passed to swap)
3. **Zero amount handling** → No guard, pass through (matches existing hook behavior)
4. **ExactOut chaining semantic** → Only valid when previous hook delivers the desired output asset quantity
5. **Data length check** → Yes, 157 bytes minimum
6. **assetIn != assetOut validation** → No, let PSM revert
7. **referralCode size** → `uint256` (32 bytes), matching PSM interface
