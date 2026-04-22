---
title: Adding DEX Swap Hooks (Uni V2 Pattern)
category: integration-issues
tags: [hooks, swappers, uniswap-v2, dex-integration, native-tokens]
date: 2026-04-14
severity: informational
component: src/hooks/swappers/
---

# Adding DEX Swap Hooks - Pattern Guide

## Problem

How to add a new DEX swap hook to Superform v2-core following established patterns.

## Solution: Dual-Hook Pattern

Every DEX integration requires **two contracts**:

1. **`SwapXxxHook`** - Assumes tokens pre-approved (1 inner execution)
2. **`ApproveAndSwapXxxHook`** - Handles approval lifecycle (4 inner executions for ERC-20, 1 for native)

Both inherit `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)` and implement `ISuperHookContextAware`.

## Key Patterns

### Data Layout Convention

Both variants should share the **same data layout** (follows Uni V3 precedent). Include `tokenIn` at offset 0 even in the non-approve variant - this enables:
- Consistent encoding between variants
- Native token detection without path parsing
- Fixed offset for all fields

### Native Token Support (3 approaches in codebase)

| Pattern | Used By | How |
|---------|---------|-----|
| **NATIVE sentinel** | KyberSwap, **UniV2** | Constructor `native_` param, `0xEeee...` sentinel, `account.balance` for tracking |
| **address(0) rejection** | Uniswap V3 | `revert NATIVE_ETH_NOT_SUPPORTED()` |
| **address(0) as native** | Odos, Uniswap V4 | `address(0)` means native |

**Recommendation**: Use the NATIVE sentinel pattern for new hooks that need native support. Store WETH in constructor for path validation.

### Conditional Approval in ApproveAndSwap

When `tokenIn == NATIVE`, skip all approval steps:
```solidity
if (tokenIn == NATIVE) {
    executions = new Execution[](1); // just the swap with value
} else {
    executions = new Execution[](4); // approve(0) + approve(amt) + swap + approve(0)
}
```

### Balance-Delta Tracking

All swap hooks use this pattern:
```solidity
_preExecute:  _setOutAmount(balance_before, account)
_postExecute: _setOutAmount(balance_after - balance_before, account)
```

For native output: `account.balance` instead of `IERC20.balanceOf()`.

### usePrevHookAmount Chaining

Always use `HookDataUpdater.getUpdatedOutputAmount()` for proportional amountOutMin scaling (not KyberSwapScaler, which is KyberSwap-specific).

### Router Function Selection for Uni V2

Detection uses tokenIn/tokenOut sentinel fields, NOT the path array:
- `tokenIn == NATIVE` → `swapExactETHForTokens` (value = amountIn)
- `tokenOut == NATIVE` → `swapExactTokensForETH`
- Otherwise → `swapExactTokensForTokens`

Path always contains real addresses (WETH), never the NATIVE sentinel.

## Checklist for Adding a New Swap Hook

- [ ] Create directory `src/hooks/swappers/<dex-name>/`
- [ ] Create minimal router interface in `interfaces/`
- [ ] Implement `Swap<Name>Hook.sol` with 1 inner execution
- [ ] Implement `ApproveAndSwap<Name>Hook.sol` with conditional approval logic
- [ ] Both use `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)`
- [ ] Both implement `ISuperHookContextAware`
- [ ] Both implement `inspect()` returning `abi.encodePacked(tokenOut)`
- [ ] Add `_getBalance()` helper for native support
- [ ] Add deadline validation (fail fast before building executions)
- [ ] Add data length validation
- [ ] Force recipient to `account` (not from data)
- [ ] Run `forge build` to verify

## References

- Uni V3 hook (canonical pattern): `src/hooks/swappers/uniswap-v3/`
- KyberSwap hook (NATIVE pattern): `src/hooks/swappers/kyberswap/`
- Uni V2 hook (multi-hop + native): `src/hooks/swappers/uniswap-v2/`
- HookDataUpdater: `src/libraries/HookDataUpdater.sol`
- BaseHook: `src/hooks/BaseHook.sol`
