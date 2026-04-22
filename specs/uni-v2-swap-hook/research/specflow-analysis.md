# SpecFlow Analysis: Uni V2 Swap Hook

## Critical Gaps Identified

### Data Layout Gaps
1. **tokenIn absent** - Original layout had no tokenIn field; needed for ApproveAndSwap approvals and native detection
2. **Native detection mechanism unspecified** - Must choose between NATIVE sentinel in path vs separate tokenIn field
3. **tokenOut vs path[last] consistency** - Two sources of truth for output token
4. **Minimum data length check missing** - No static validation specified
5. **pathLength semantics ambiguous** - Number of addresses vs byte length

### Resolution: Both variants share same layout with tokenIn included (follows Uni V3 pattern)

### Native Token Gaps
6. **NATIVE-to-WETH translation** - Path must contain WETH for router, not NATIVE sentinel
7. **Execution.value for native input** - Must match amountIn (including usePrevHookAmount case)
8. **ApproveAndSwap native input execution count** - 1 execution (skip approvals) vs 4

### Resolution: tokenIn/tokenOut fields use NATIVE sentinel for detection; path always uses real WETH address

### Missing Specifications
9. **inspect() function** - Not specified but required
10. **Error definitions** - INVALID_HOOK_DATA, INVALID_PATH_LENGTH, EXPIRED_DEADLINE needed
11. **Path length bounds** - No min (2) or max validation
12. **WETH constructor parameter** - Not specified how hook resolves WETH for path validation
13. **receive() requirement on smart account** - Not documented

## Flow Permutation Matrix

| Flow | tokenIn | tokenOut | usePrevHook | Variant | Inner Executions |
|------|---------|----------|-------------|---------|-----------------|
| ERC20→ERC20 single-hop | ERC20 | ERC20 | false | Swap | 1 |
| ERC20→ERC20 multi-hop | ERC20 | ERC20 | false | Swap | 1 |
| Native→ERC20 | NATIVE | ERC20 | false | Swap | 1 (value=amountIn) |
| ERC20→Native | ERC20 | NATIVE | false | Swap | 1 |
| ERC20→ERC20 chained | ERC20 | ERC20 | true | Swap | 1 |
| ERC20→ERC20 with approvals | ERC20 | ERC20 | false | ApproveAndSwap | 4 |
| Native→ERC20 with approvals | NATIVE | ERC20 | false | ApproveAndSwap | 1 (skip approvals) |
| ERC20→Native with approvals | ERC20 | NATIVE | false | ApproveAndSwap | 4 |
