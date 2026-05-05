# SpecFlow Analysis: MorphoLendHook

## Critical Issues Found

### 1. MorphoWithdrawHook outAmount Bug (CRITICAL)
MorphoWithdrawHook._preExecute/_postExecute tracks collateralToken balance.
But withdraw() sends loanToken to receiver. For lending withdrawal, outAmount = 0.
Any downstream hook using usePrevHookAmount will get zero.
**Decision needed: Create MorphoLendWithdrawHook or fix existing?**

### 2. HookType Classification (CRITICAL)
BaseLoanHook forces NONACCOUNTING. If INFLOW is needed, can't use BaseLoanHook.
INFLOW requires yieldSourceOracleId + yieldSource in data layout (first 52 bytes).
Current layout has loanToken at [0:20] which would collide.
**Decision: NONACCOUNTING initially (no oracle yet). Oracle later.**

### 3. Data Layout Collision
If ever changed to INFLOW, data layout needs yieldSourceOracleId(32) + yieldSource(20) prefix.
Current layout incompatible with INFLOW HookType.

## User Flows
1. Standard lend (fixed amount)
2. Lend using previous hook output (usePrevHookAmount)
3. Full withdrawal via shares
4. Partial withdrawal via assets
5. Lend-then-withdraw across transactions

## Edge Cases Identified
- usePrevHookAmount=true with prevHook=address(0) -> opaque revert
- Non-existent market -> Morpho-level revert
- Insufficient liquidity on withdrawal -> revert
- USDT approval needs reset pattern
