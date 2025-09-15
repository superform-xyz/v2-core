# Uniswap V4 Hook Implementation Plan for Superform v2-core

## Executive Summary

This plan outlines the implementation of a comprehensive Uniswap V4 hook architecture in Superform v2-core to elegantly solve the minAmountOut patching challenges currently faced with 0x Protocol. Unlike 0x's complex transaction patching requirements, V4's architecture enables real-time dynamic slippage protection through its hook lifecycle events and flash accounting system.

## Current Problem Analysis

### 0x Protocol Challenges
Our current `Swap0xV2Hook` faces significant complexity due to 0x's architecture:

1. **Circular Dependency Issue**: 0x API quotes require exact amounts, but bridge fee reductions (e.g., 20% Across V3 reduction) change actual amounts
2. **Complex Transaction Patching**: Current solution requires `ZeroExTransactionPatcher` to patch deep into Settler actions:
   - Must parse AllowanceHolder.exec → Settler.execute → action arrays
   - Must patch `bps` parameters in 6+ protocol types (BASIC, UNISWAPV2, UNISWAPV3, etc.)
   - Must handle TRANSFER_FROM permit amount scaling
   - ~800-1200 lines of complex calldata manipulation

3. **Maintenance Burden**: 0x frequently adds new protocols, requiring constant patcher updates
4. **Gas Inefficiency**: Deep calldata parsing and re-encoding operations are gas-intensive

### Why Uniswap V4 Solves These Problems

1. **Real-time Amount Calculation**: V4's unlock/callback pattern allows dynamic amount calculations during execution
2. **Hook Lifecycle Events**: `beforeSwap` and `afterSwap` hooks enable oracle-based dynamic slippage protection
3. **Flash Accounting**: Transient storage reduces gas costs and revert risks compared to 0x's multiple allowance operations
4. **Native Architecture**: No complex transaction patching required - amounts can be calculated and validated in real-time

## V4 Architecture Overview

### Core Components Available
- **PoolManager**: Singleton contract managing all pools and swaps
- **unlock/callback Pattern**: Batched operations with net settlement
- **Hook System**: beforeSwap, afterSwap lifecycle events for custom logic
- **Flash Accounting**: EIP-1153 transient storage for temporary balances
- **Native ETH Support**: Direct ETH handling without WETH wrapping complexity

### Key Advantages Over 0x
1. **Dynamic Execution**: Real-time amount calculations vs. pre-computed quotes
2. **Simplified Integration**: Direct PoolManager calls vs. complex AllowanceHolder → Settler → Action flows
3. **Better Gas Efficiency**: Flash accounting reduces external calls and state changes
4. **Fewer Reverts**: Net settlement at unlock vs. individual transaction failures

## Proposed Implementation Architecture

### 1. SwapUniswapV4Hook Design

```solidity
contract SwapUniswapV4Hook is BaseHook, ISuperHookContextAware, IUnlockCallback {
    IPoolManager immutable POOL_MANAGER;
    
    constructor(address poolManager_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        POOL_MANAGER = IPoolManager(poolManager_);
    }
}
```

**Hook Data Structure (68+ bytes):**
```solidity
/// @dev data has the following structure
/// @notice         PoolKey poolKey = abi.decode(data[0:160], (PoolKey));           // V4 pool identifier
/// @notice         address dstReceiver = address(bytes20(data[160:180]));         // Token recipient (0 = account) 
/// @notice         uint160 sqrtPriceLimitX96 = uint160(bytes20(data[180:200]));   // Price limit for swap
/// @notice         uint256 minAmountOut = uint256(bytes32(data[200:232]));        // Minimum output (oracle-based)
/// @notice         bool usePrevHookAmount = _decodeBool(data, 232);               // Hook chaining flag
/// @notice         bytes hookData = data[233:];                                   // Additional hook data
```

### 2. Dynamic MinAmountOut Calculation

Instead of 0x's pre-computed quotes, implement real-time calculation:

```solidity
function _calculateDynamicMinAmountOut(
    PoolKey memory poolKey,
    bool zeroForOne,
    uint256 amountIn,
    uint256 slippageToleranceBps
) internal view returns (uint256 minAmountOut) {
    // Get current pool price
    (uint160 sqrtPriceX96,,,) = POOL_MANAGER.getSlot0(PoolId.wrap(keccak256(abi.encode(poolKey))));
    
    // Calculate expected output based on current price
    uint256 expectedAmountOut = _calculateExpectedOutput(sqrtPriceX96, amountIn, zeroForOne);
    
    // Apply slippage tolerance
    minAmountOut = (expectedAmountOut * (10_000 - slippageToleranceBps)) / 10_000;
}
```

### 3. Hook Chaining Integration

Support `usePrevHookAmount` pattern similar to 0x hook:

```solidity
function _buildHookExecutions(
    address prevHook,
    address account,
    bytes calldata data
) internal view override returns (Execution[] memory executions) {
    // Decode hook data
    (PoolKey memory poolKey, address dstReceiver, uint160 sqrtPriceLimitX96, 
     uint256 baseMinAmountOut, bool usePrevHookAmount, bytes memory hookData) = _decodeHookData(data);
    
    // Get actual swap amount
    uint256 amountIn = usePrevHookAmount ? 
        ISuperHookResult(prevHook).getOutAmount(account) : 
        IERC20(Currency.unwrap(poolKey.currency0)).balanceOf(account);
    
    // Calculate dynamic minAmountOut based on actual amount
    uint256 dynamicMinAmountOut = _calculateDynamicMinAmountOut(
        poolKey, true, amountIn, _getSlippageToleranceFromOracle()
    );
    
    // Create unlock call with calculated parameters
    bytes memory unlockData = abi.encode(poolKey, amountIn, dynamicMinAmountOut, dstReceiver);
    
    executions = new Execution[](1);
    executions[0] = Execution({
        target: address(POOL_MANAGER),
        value: 0,
        callData: abi.encodeWithSelector(IPoolManager.unlock.selector, unlockData)
    });
}
```

### 4. Unlock Callback Implementation

Handle the actual swap execution with dynamic validation:

```solidity
function unlockCallback(bytes calldata data) external override returns (bytes memory) {
    require(msg.sender == address(POOL_MANAGER), "UNAUTHORIZED");
    
    (PoolKey memory poolKey, uint256 amountIn, uint256 minAmountOut, address dstReceiver) = 
        abi.decode(data, (PoolKey, uint256, uint256, address));
    
    // Take tokens from account and settle with PoolManager
    POOL_MANAGER.take(poolKey.currency0, address(this), amountIn);
    POOL_MANAGER.settle(poolKey.currency0);
    
    // Execute swap with dynamic parameters
    IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
        zeroForOne: true,
        amountSpecified: -int256(amountIn), // Exact input
        sqrtPriceLimitX96: _calculatePriceLimit(poolKey, minAmountOut)
    });
    
    BalanceDelta swapDelta = POOL_MANAGER.swap(poolKey, swapParams, "");
    
    // Validate minimum output in real-time
    uint256 amountOut = uint256(int256(-swapDelta.amount1()));
    require(amountOut >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");
    
    // Transfer output tokens to receiver
    POOL_MANAGER.take(poolKey.currency1, dstReceiver, amountOut);
    
    return abi.encode(amountOut);
}
```

## Comparison: V4 vs 0x Approach

| Aspect | 0x Protocol | Uniswap V4 |
|--------|-------------|-------------|
| **Quote Timing** | Pre-computed (circular dependency) | Real-time calculation |
| **Amount Patching** | Complex transaction parsing (~800-1200 LOC) | Direct parameter passing |
| **Slippage Protection** | Static minAmountOut from API | Dynamic oracle-based calculation |
| **Gas Efficiency** | Multiple allowances + deep parsing | Flash accounting + single unlock |
| **Maintenance** | 29+ protocol patchers needed | Single V4 PoolManager integration |
| **Revert Risk** | High (arithmetic underflow) | Low (net settlement) |
| **Hook Chaining** | Complex bps parameter scaling | Native amount passing |

## Implementation Strategy

### Phase 1: Core V4 Hook Implementation (Week 1-2)

**Files to Create:**
1. `/src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol` - Main hook implementation
2. `/src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol` - V4 interface extensions
3. `/src/libraries/uniswap-v4/V4SwapCalculations.sol` - Price and slippage calculation library

**Core Features:**
- Basic unlock/callback pattern implementation
- Dynamic minAmountOut calculation using current pool state
- Hook chaining support with `usePrevHookAmount`
- Native ETH and ERC20 token support

### Phase 2: Advanced Slippage Protection (Week 3)

**Files to Modify:**
1. `/src/libraries/uniswap-v4/V4SwapCalculations.sol` - Add oracle integration
2. `/src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol` - Add beforeSwap/afterSwap hooks

**Advanced Features:**
- Oracle-based dynamic slippage calculation
- Multi-hop swap support for complex routes
- MEV protection through hook lifecycle events
- Emergency fallback mechanisms

### Phase 3: Multi-hop and Complex Routing (Week 4)

**Files to Create:**
1. `/src/libraries/uniswap-v4/V4PathEncoding.sol` - Multi-hop path encoding
2. `/src/hooks/swappers/uniswap-v4/SwapUniswapV4MultiHopHook.sol` - Multi-hop variant

**Complex Features:**
- Multi-hop swap routing through multiple V4 pools
- Path optimization based on real-time liquidity
- Split routing for large trades
- Advanced MEV protection strategies

### Phase 4: Testing and Integration (Week 5-6)

**Test Strategy:**
1. **Unit Tests**: Test dynamic calculation logic and edge cases
2. **Integration Tests**: Full hook chaining with bridge and vault operations
3. **Fork Tests**: Test against mainnet V4 deployments when available
4. **Gas Benchmarking**: Compare gas costs vs 0x implementation

## Hook Data Encoding Examples

### Simple Single-hop Swap
```solidity
// PoolKey structure (160 bytes)
PoolKey memory poolKey = PoolKey({
    currency0: Currency.wrap(WETH),
    currency1: Currency.wrap(USDC), 
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(address(0))
});

// Hook data encoding
bytes memory hookData = abi.encodePacked(
    abi.encode(poolKey),                    // 160 bytes: Pool identifier
    dstReceiver,                           // 20 bytes: Recipient address
    sqrtPriceLimitX96,                     // 20 bytes: Price limit  
    minAmountOut,                          // 32 bytes: Min output
    usePrevHookAmount                      // 1 byte: Hook chaining flag
);
```

### Multi-hop Swap Example
```solidity
// Path: WETH → USDC → DAI
bytes memory path = abi.encodePacked(
    WETH,
    uint24(3000),  // 0.3% fee
    USDC,
    uint24(500),   // 0.05% fee  
    DAI
);

bytes memory hookData = abi.encodePacked(
    path,                                  // Variable: Encoded path
    dstReceiver,                          // 20 bytes: Recipient
    minAmountOut,                         // 32 bytes: Min final output
    usePrevHookAmount                     // 1 byte: Hook chaining
);
```

## Integration with Existing Superform Architecture

### Hook Registration
```solidity
// In SuperRegistry
function registerV4Hook() external onlyOwner {
    address v4Hook = address(new SwapUniswapV4Hook(UNISWAP_V4_POOL_MANAGER));
    _registerHook(HookSubTypes.SWAP_UNISWAP_V4, v4Hook);
}
```

### Cross-chain Flow Example
```solidity
// Bridge + V4 Swap + Deposit flow
UserOperation memory userOp = UserOperation({
    hooks: [
        acrossHook,      // Bridge WETH from Base to Ethereum
        uniswapV4Hook,   // Swap WETH → USDC using V4
        depositHook      // Deposit USDC to vault
    ],
    // ... other parameters
});
```

## Security Considerations

### 1. Oracle Manipulation Protection
- Use TWAP (Time-Weighted Average Price) for slippage calculations
- Implement price deviation limits from multiple oracle sources
- Add circuit breakers for extreme price movements

### 2. Hook Lifecycle Security
- Validate all beforeSwap and afterSwap hook returns
- Implement reentrancy protection in unlock callbacks
- Ensure proper balance accounting throughout execution

### 3. MEV Protection
- Use commit-reveal scheme for large swaps
- Implement dynamic fee adjustments based on market conditions
- Add randomized execution delays for sensitive operations

## Gas Optimization Strategies

### 1. Batch Operations
- Combine multiple swaps in single unlock call
- Use EIP-1153 transient storage for temporary data
- Minimize external calls through flash accounting

### 2. Efficient Encoding
- Pack hook data efficiently to reduce calldata costs
- Use bit manipulation for boolean flags
- Optimize struct layouts for gas efficiency

### 3. Precomputed Values
- Cache frequently used calculations
- Precompute common pool parameters
- Use lookup tables for standard configurations

## Migration Strategy

### Phase 1: Parallel Deployment
- Deploy V4 hooks alongside existing 0x hooks
- Implement feature flags for gradual rollout
- Maintain backward compatibility during transition

### Phase 2: Performance Comparison
- A/B testing between 0x and V4 approaches
- Gas cost analysis and optimization
- Success rate and slippage comparison

### Phase 3: Gradual Migration
- Start with small amounts and low-risk operations
- Expand to larger trades based on performance metrics
- Eventually deprecate 0x hooks for supported pairs

## Success Metrics

### Technical Metrics
1. **Gas Efficiency**: 20-30% reduction vs 0x implementation
2. **Slippage Protection**: Better execution prices through real-time calculation
3. **Failure Rate**: <1% transaction failures vs current 0x challenges
4. **Code Complexity**: 70-80% reduction in codebase size vs ZeroExTransactionPatcher

### Business Metrics
1. **User Experience**: Faster execution and better pricing
2. **Maintenance Cost**: Reduced engineering overhead
3. **Protocol Coverage**: Support for all major token pairs on V4
4. **Cross-chain Efficiency**: Seamless integration with bridge operations

## Risk Assessment and Mitigation

### High-Risk Areas
1. **V4 Protocol Maturity**: Early-stage protocol with potential bugs
   - **Mitigation**: Extensive testing, gradual rollout, emergency pause mechanisms

2. **Liquidity Availability**: V4 may have lower liquidity than aggregated 0x sources
   - **Mitigation**: Hybrid approach, fallback to 0x for large trades

3. **Smart Contract Risk**: Complex unlock/callback pattern
   - **Mitigation**: Formal verification, comprehensive audits

### Medium-Risk Areas
1. **Oracle Dependency**: Dynamic slippage relies on price feeds
   - **Mitigation**: Multiple oracle sources, fallback mechanisms

2. **Hook Complexity**: beforeSwap/afterSwap logic adds complexity
   - **Mitigation**: Extensive testing, code reviews

## Conclusion

The Uniswap V4 hook implementation provides an elegant solution to the complex minAmountOut patching challenges faced with 0x Protocol. By leveraging V4's real-time execution model and hook lifecycle events, we can achieve:

1. **Elimination of Circular Dependencies**: Real-time amount calculation vs pre-computed quotes
2. **Dramatic Code Simplification**: Single PoolManager integration vs complex transaction patching
3. **Better Gas Efficiency**: Flash accounting vs multiple allowance operations  
4. **Enhanced Slippage Protection**: Oracle-based dynamic calculation vs static API quotes
5. **Reduced Maintenance Burden**: Single protocol integration vs 29+ protocol patchers

The implementation follows Superform's established hook patterns while taking advantage of V4's advanced architecture to solve fundamental challenges in DeFi swap execution. This approach positions Superform at the forefront of next-generation DEX integration while maintaining the security and modularity principles of the v2-core system.

**Recommendation**: Proceed with Phase 1 implementation to validate the approach, followed by gradual migration from 0x hooks based on performance metrics and V4 ecosystem maturity.