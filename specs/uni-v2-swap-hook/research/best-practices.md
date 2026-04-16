# Uniswap V2 Integration Best Practices

## 1. Security Considerations

### Deadline Handling
- Never pass `block.timestamp` as deadline (equivalent to no deadline)
- Validate deadline in hook before building executions (fail fast)
- Let router validate internally too (belt and suspenders)

### Slippage Protection
- Always require meaningful `amountOutMin`
- Use `HookDataUpdater.getUpdatedOutputAmount()` for proportional scaling with `usePrevHookAmount`
- Never rely on on-chain `getAmountsOut()` for slippage calculation

### Path Validation
- Minimum path length: 2
- For native swaps: path[0] must be WETH for ETH input, path[last] must be WETH for ETH output
- Trust off-chain bundler for path safety (per interview decision)

### Native ETH Handling
- Use configurable NATIVE sentinel address (KyberSwap pattern)
- Set `value` field on Execution struct for native input
- Use `account.balance` for native token balance tracking
- Skip approval steps when input is native

### Approval Pattern (USDT-compatible)
- approve(0) -> approve(amount) -> swap -> approve(0)
- Each approve costs ~5,000-24,000 gas
- SwapXxx variant skips approvals entirely

## 2. Fork Compatibility

All major Uni V2 forks use identical interface:
- SparkDex (Flare) - standard UniswapV2Router02
- SushiSwap - direct fork
- PancakeSwap - direct fork

A single hook parameterized by router address works across all.

## 3. Known Vulnerabilities

### Fee-on-Transfer Tokens
- Standard swap functions will revert with fee-on-transfer tokens
- Use `SupportingFeeOnTransferTokens` variants (no return values)
- Balance-diff pattern in _preExecute/_postExecute handles this

### Sandwich Attacks
- Bounded by slippage tolerance but not eliminated
- Set tight slippage tolerances off-chain

### Reentrancy (ERC-777 callbacks)
- BaseHook provides transient storage protection
- Execution context mutex prevents re-entry

### Rebasing Tokens
- Balance-tracking pattern handles correctly (measures actual delta)

## 4. Gas Optimization
- Let router handle multi-hop internally (don't decompose)
- Tight packing of hook data minimizes calldata costs
- Don't call getAmountsOut() on-chain
- Each additional hop adds ~60,000-80,000 gas

## Which Swap Function to Use

| Input | Output | Function |
|-------|--------|----------|
| ERC20 | ERC20 | swapExactTokensForTokens |
| Native | ERC20 | swapExactETHForTokens (payable) |
| ERC20 | Native | swapExactTokensForETH |
