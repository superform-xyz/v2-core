# EVM Security Research: Uniswap V2 Swap Hook

## 1. Relevant Vulnerability Patterns

### 1.1 Reentrancy via Native Token Callbacks (MEDIUM-HIGH)
- `swapExactTokensForETH` sends native ETH to `to` address via low-level call
- Mitigated by BaseHook transient storage mutexes and V2 pair `lock` modifier

### 1.2 Approval Race Conditions (LOW - mitigated)
- approve(0)->approve(amount)->swap->approve(0) pattern handles this
- ERC-7579 execution model makes these atomic

### 1.3 Native ETH Handling (MEDIUM)
- Execution `value` field must match `amountIn` exactly for ETH input
- Smart account must accept ETH for ETH output swaps
- Balance tracking interference from other hooks in same tx
- NATIVE sentinel must be translated to WETH in path

## 2. Exploit Precedents

- **SparkDEX Perps Reentrancy (Aug 2025)** - reentrancy via fallback during profit distribution
- **STA/Balancer Pool Drain** - fee-on-transfer token drained ~$500K
- **ERC-777 Uniswap Exploit** - callback reentrancy (V2 pair lock prevents)
- **SIR.trading Transient Storage** - EIP-1153 slot collision

## 3. Attack Surface Map

### Input Validation (HIGH)
- Malformed path array, zero-length path, pathLength overflow
- NATIVE sentinel in intermediate position
- amountOutMin set to zero

### Native Token Handling (MEDIUM-HIGH)
- ETH sent with ERC-20 swap, missing receive(), balance interference
- NATIVE not translated to WETH in path

### MEV (HIGH)
- Sandwich attacks bounded by slippage tolerance
- Multi-hop amplifies exposure

### Token-Specific (HIGH)
- Fee-on-transfer in multi-hop path
- Rebasing tokens corrupt balance delta

## 4. Key Security Recommendations

1. **Path validation**: length >= 2, bounds check, NATIVE/WETH consistency
2. **Force recipient to account**: hardcode `to` parameter
3. **Skip approvals for native**: no approve() when tokenIn == NATIVE
4. **WETH in constructor**: for path validation without router call
5. **No fee-on-transfer support**: document limitation
6. **Cap path length**: prevent gas griefing
7. **Comprehensive fuzz testing**: path encoding, amounts, native branching

## 5. Testing Recommendations

### Fuzz Scenarios
- F1: Path length (0-256), F2: Amount boundaries, F3: Native token decision
- F4: usePrevHookAmount chaining, F5: Deadline boundaries

### Invariants
- I1: No residual approvals, I2: Output balance delta accuracy
- I3: No ETH stuck in hook, I4: Recipient always account
- I5: Path-function consistency (native vs ERC-20)
