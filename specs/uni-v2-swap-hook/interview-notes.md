# Uni V2 Swap Hook - Interview Notes

## Date: 2026-04-14

## Feature Summary
Implement a generic Uniswap V2-compatible swap hook that works with any Uni V2 router (SparkDex on Flare being the initial target). The hook should be reusable across chains and Uni V2 forks.

## Technical Decisions

### Target & Scope
- **Generic Uni V2 hook** - not SparkDex-specific
- Works with any Uni V2-compatible router on any chain
- Single contract per router instance (router address in constructor)

### Routing
- **Multi-hop paths** supported via variable-length path encoding
- Path encoded as: pathLength + path addresses
- Final output slippage validation only (trust router for intermediate hops)

### Native Token Support
- **Configurable NATIVE sentinel address** (like KyberSwap pattern)
- Pass NATIVE address in constructor
- Detect native vs ERC20 at runtime
- Use router's swapExactETHForTokens / swapExactTokensForETH for native swaps

### Interface
- **Assumed standard UniswapV2Router02** interface
- Need to verify SparkDex compatibility (user unsure)
- Key function: `swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline)`
- Native variants: `swapExactETHForTokens`, `swapExactTokensForETH`

### Approval Pattern
- Follow exact same pattern as Uni V3 hook:
  - approve(0) -> approve(amountIn) -> swap -> approve(0)
- 4-execution pattern for USDT-compatibility

### Deadline
- **Hook-level validation** (fail fast before building executions)
- Also let router validate internally

### Security
- No path validation - trust bundler/off-chain system
- Output amount validation via amountOutMinimum
- Standard reentrancy protection from BaseHook

### Deployment
- Single contract per router per chain
- Constructor takes router address and NATIVE sentinel address

## Hook Data Layout (proposed)

### SwapUniV2Hook
```
address tokenOut       = BytesLib.toAddress(data, 0);        // 20 bytes
uint256 deadline       = BytesLib.toUint256(data, 20);       // 32 bytes
uint256 amountIn       = BytesLib.toUint256(data, 52);       // 32 bytes
uint256 amountOutMin   = BytesLib.toUint256(data, 84);       // 32 bytes
bool usePrevHookAmount = _decodeBool(data, 116);             // 1 byte
uint256 pathLength     = BytesLib.toUint256(data, 117);      // 32 bytes (number of addresses)
address[] path         = decoded from (149, pathLength * 20) // variable
```

## Contracts to Create
1. `SwapUniV2Hook.sol` - Swap assuming pre-approval
2. `ApproveAndSwapUniV2Hook.sol` - Swap with approval handling
3. `interfaces/IUniswapV2Router.sol` - Minimal Uni V2 Router interface

## Testing
- Unit tests following existing swap hook test patterns
- Test single-hop and multi-hop paths
- Test native token swaps (ETH/FLR input and output)
- Test usePrevHookAmount chaining
- Test deadline validation
- Test approval patterns (USDT-like tokens)
