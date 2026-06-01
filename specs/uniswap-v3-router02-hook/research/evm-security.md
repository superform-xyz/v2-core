# EVM Security Analysis: Uniswap V3 Router02 Swap Hook

## Actionable Recommendations

| Priority | Finding | Recommendation |
|----------|---------|----------------|
| CRITICAL | SwapRouter02 uses different struct without `deadline` | Use `IV3SwapRouter` interface, remove `deadline` from struct |
| HIGH | No `amountIn == 0` check when `usePrevHookAmount` is true | Add `if (amountIn == 0) revert AMOUNT_NOT_VALID()` |
| MEDIUM | No `tokenIn == tokenOut` check | Add `if (tokenIn == tokenOut) revert INVALID_HOOK_DATA()` (from Algebra hook) |
| LOW | No `amountOutMinimum == 0` check | Consider non-zero minimum output validation |
| INFO | Fee-on-transfer / rebasing tokens unsupported | Document in NatSpec |
| INFO | Deadline removal acceptable | SECURITY.md item 10 already accepts infinite deadline |
| INFO | Approval pattern is sound | Atomic approve(0)->approve(N)->swap->approve(0) is correct |
| INFO | Recipient forced to `account` | Critical and correct - do not change |

## Key Findings

### 1. Reentrancy: Low Risk
- SuperExecutorBase uses `nonReentrant` modifier
- BaseHook uses transient storage mutexes for pre/post execute
- SwapRouter02 handles Uniswap V3 callbacks internally
- `validateHookCompliance` prevents hook re-entry mid-execution

### 2. Sandwich/MEV: Infrastructure-Layer Concern
- `amountOutMinimum` provides slippage protection
- `sqrtPriceLimitX96` provides price bound protection
- SuperBundler expected to use MEV-protected channels
- Hook cannot enforce MEV protection itself

### 3. Balance Manipulation: Mitigated by Atomicity
- _preExecute/_postExecute pattern measures actual balance delta
- Atomic execution within single transaction prevents donation attacks between measurements
- Correctly handles fee-on-transfer tokens (measures actual received amount)

### 4. Deadline Removal: Acceptable
- SECURITY.md item 10 already documents infinite deadline as accepted trade-off
- Using `block.timestamp` as deadline provides zero protection anyway (always passes)
- SwapRouter02 doesn't support deadline in struct
- `amountOutMinimum` provides actual economic protection
- Bundler/validator layer handles time constraints

### 5. Token Compatibility
- Fee-on-transfer: Uniswap V3 does NOT support them (swap reverts with STF)
- Rebasing: Uniswap V3 does NOT support them
- Zero-approve revert tokens: Rare in V3 pools, acceptable risk
- Document unsupported token types in NatSpec

### 6. Approval Pattern: Sound
- approve(0) first handles USDT-like tokens requiring zero-reset
- Atomic execution prevents race conditions
- Post-swap approve(0) is defensive (exactInputSingle consumes exact amountIn)
- If swap reverts, entire batch reverts including approvals

### 7. Known Exploits
- Cork Protocol ($11M): V4 hook callback manipulation - not applicable (different architecture)
- Recipient manipulation: Mitigated by forcing `recipient = account`
- Struct mismatch: The exact issue we're fixing with the new Router02 hook
