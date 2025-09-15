# sqrtPriceLimitX96 Calculation Implementation Plan

## Overview

This implementation plan addresses the critical issue where the UniswapV4 hook's `unlockCallback` function validates that `sqrtPriceLimitX96 != 0`, but the current test is passing `sqrtPriceLimitX96 = 0`, causing PriceLimitOutOfBounds errors.

## Current Problem Analysis

### Issue Context
1. **Stack Too Deep Fixed**: The unlock execution has been successfully moved to `_postExecute` 
2. **Validation Error**: The hook validates `sqrtPriceLimitX96 != 0` in `unlockCallback` (line 210-212 of SwapUniswapV4Hook.sol)
3. **Test Failure**: Integration test passes `sqrtPriceLimitX96: 0` causing INVALID_PRICE_LIMIT error
4. **Missing Helper**: No test helper exists to calculate proper price limits based on current pool price and slippage

### Current Hook Validation
```solidity
// From SwapUniswapV4Hook.sol line 209-212
if (sqrtPriceLimitX96 == 0) {
    revert INVALID_PRICE_LIMIT();
}
```

### Current Test Usage
```solidity
// From UniswapV4HookIntegrationTest.t.sol line 208
sqrtPriceLimitX96: 0,  // ❌ This causes the error
```

## Implementation Requirements

### 1. Mathematical Foundation

**Core Formula for Price Limits with Slippage:**

For a swap with slippage tolerance `S` (as a percentage):

- **zeroForOne = true** (token0 → token1, price goes down):
  ```
  sqrtPriceLimitX96 = currentSqrtPriceX96 * sqrt(1 - S)
  ```

- **zeroForOne = false** (token1 → token0, price goes up):
  ```
  sqrtPriceLimitX96 = currentSqrtPriceX96 * sqrt(1 + S)
  ```

**Precision-Safe Implementation:**
```solidity
// For 0.5% slippage (500 bps)
uint256 slippageBps = 500;
uint256 slippageFactor = zeroForOne 
    ? 10000 - slippageBps  // 9950 for 0.5% down
    : 10000 + slippageBps; // 10050 for 0.5% up
    
// Apply square root to the slippage factor
uint256 sqrtSlippageFactor = sqrt(slippageFactor * 1e18 / 10000);
sqrtPriceLimitX96 = uint160(currentSqrtPriceX96 * sqrtSlippageFactor / 1e9);
```

### 2. Helper Function Implementation

**Location**: Add to `UniswapV4HookIntegrationTest.t.sol`

```solidity
/// @notice Calculate appropriate sqrtPriceLimitX96 based on current pool price and slippage tolerance
/// @param poolKey The pool to get current price from
/// @param zeroForOne Direction of the swap
/// @param slippageToleranceBps Slippage tolerance in basis points (e.g., 50 = 0.5%)
/// @return sqrtPriceLimitX96 The calculated price limit
function _calculatePriceLimit(
    PoolKey memory poolKey,
    bool zeroForOne,
    uint256 slippageToleranceBps
) internal view returns (uint160 sqrtPriceLimitX96) {
    PoolId poolId = poolKey.toId();
    
    // Get current pool price
    (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
    
    // Handle uninitialized pools
    if (currentSqrtPriceX96 == 0) {
        // For testing, we can use a reasonable default price
        // In production, this should revert or use initialization logic
        currentSqrtPriceX96 = 79228162514264337593543950336; // 1:1 price ratio
    }
    
    // Calculate slippage factor (precision: 10000 = 100%)
    uint256 slippageFactor;
    if (zeroForOne) {
        // Price goes down: apply negative slippage
        slippageFactor = 10000 - slippageToleranceBps;
    } else {
        // Price goes up: apply positive slippage  
        slippageFactor = 10000 + slippageToleranceBps;
    }
    
    // Apply square root to slippage (since we're dealing with sqrt prices)
    uint256 adjustedSqrtPrice = (uint256(currentSqrtPriceX96) * _sqrt(slippageFactor * 1e18 / 10000)) / 1e9;
    
    // Ensure bounds compliance with TickMath limits
    if (adjustedSqrtPrice < TickMath.MIN_SQRT_PRICE + 1) {
        sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE + 1;
    } else if (adjustedSqrtPrice > TickMath.MAX_SQRT_PRICE - 1) {
        sqrtPriceLimitX96 = TickMath.MAX_SQRT_PRICE - 1;
    } else {
        sqrtPriceLimitX96 = uint160(adjustedSqrtPrice);
    }
}

/// @notice Calculate integer square root using Babylonian method
/// @param y The number to find square root of
/// @return z The square root
function _sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
        z = y;
        uint256 x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    } else if (y != 0) {
        z = 1;
    }
}
```

### 3. Import Requirements

**Add to UniswapV4HookIntegrationTest.t.sol imports:**
```solidity
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
```

### 4. Test Integration Updates

**Update the swap test to use proper price limits:**

```solidity
function test_UniswapV4SwapWithAmountTracking() public {
    console2.log("=== UniswapV4Hook Swap Test ===");
    
    SwapTestParams memory params;
    params.sellAmount = 1000e6; // 1000 USDC
    params.zeroForOne = CHAIN_1_USDC < CHAIN_1_WETH;
    
    // ✅ CALCULATE PROPER PRICE LIMIT
    uint160 calculatedPriceLimit = _calculatePriceLimit(
        testPoolKey,
        params.zeroForOne,
        50 // 0.5% slippage tolerance
    );
    
    console2.log("Calculated sqrtPriceLimitX96:", calculatedPriceLimit);
    
    // Get realistic minimum using hook's quote
    SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
        SwapUniswapV4Hook.QuoteParams({
            poolKey: testPoolKey,
            zeroForOne: params.zeroForOne,
            amountIn: params.sellAmount,
            sqrtPriceLimitX96: calculatedPriceLimit  // ✅ Use calculated limit
        })
    );
    params.expectedMinOut = quote.amountOut * 995 / 1000;
    
    // ... rest of test logic ...
    
    // Generate swap calldata with proper price limit
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: params.account,
            sqrtPriceLimitX96: calculatedPriceLimit,  // ✅ Use calculated limit
            originalAmountIn: params.sellAmount,
            originalMinAmountOut: params.expectedMinOut,
            maxSlippageDeviationBps: 500,
            zeroForOne: params.zeroForOne,
            additionalData: ""
        }),
        false
    );
    
    // ... rest of test execution ...
}
```

## Edge Cases & Boundary Conditions

### 1. Uninitialized Pools
```solidity
if (currentSqrtPriceX96 == 0) {
    // Use reasonable default or revert
    // For testing: use 1:1 price ratio
    currentSqrtPriceX96 = 79228162514264337593543950336;
}
```

### 2. Extreme Slippage Values
```solidity
// Validate slippage is reasonable (0.01% to 10%)
if (slippageToleranceBps < 1 || slippageToleranceBps > 1000) {
    revert InvalidSlippageTolerance();
}
```

### 3. TickMath Boundary Enforcement
```solidity
// Ensure calculated price doesn't exceed V4 bounds
if (adjustedSqrtPrice < TickMath.MIN_SQRT_PRICE + 1) {
    sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE + 1;
} else if (adjustedSqrtPrice > TickMath.MAX_SQRT_PRICE - 1) {
    sqrtPriceLimitX96 = TickMath.MAX_SQRT_PRICE - 1;
}
```

### 4. Direction Logic Validation
```solidity
// Ensure price limit makes sense for swap direction
if (zeroForOne && sqrtPriceLimitX96 >= currentSqrtPriceX96) {
    revert InvalidPriceLimitForDirection();
}
if (!zeroForOne && sqrtPriceLimitX96 <= currentSqrtPriceX96) {
    revert InvalidPriceLimitForDirection();
}
```

## Alternative Approaches Considered

### Approach 1: Tick-Based Calculation (Rejected)
**Pros**: More precise, aligns with V4 tick system
**Cons**: Complex conversion, potential rounding errors, harder to reason about

### Approach 2: Fixed Price Limits (Rejected) 
**Pros**: Simple implementation
**Cons**: Not responsive to current market conditions, poor UX

### Approach 3: Direct sqrt Price Manipulation (Selected) ✅
**Pros**: Direct calculation, easier to understand, maintains precision
**Cons**: Requires sqrt function implementation

## Implementation Checklist

### Phase 1: Helper Function Implementation
- [ ] Add `PoolId` and `TickMath` imports to test file
- [ ] Implement `_calculatePriceLimit` helper function
- [ ] Implement `_sqrt` utility function  
- [ ] Add boundary validation logic

### Phase 2: Test Integration
- [ ] Update `test_UniswapV4SwapWithAmountTracking` to use price limit calculation
- [ ] Update hook data decoding test to use non-zero price limits
- [ ] Update inspect function test to use proper price limits
- [ ] Add console logging for price limit values during testing

### Phase 3: Edge Case Testing  
- [ ] Test with uninitialized pools
- [ ] Test with extreme slippage values (boundary conditions)
- [ ] Test with both swap directions (zeroForOne true/false)
- [ ] Test with different fee tiers and tick spacings

### Phase 4: Validation & Refinement
- [ ] Verify calculated limits don't cause PriceLimitOutOfBounds errors
- [ ] Confirm swaps execute successfully with calculated limits
- [ ] Validate that limits provide appropriate slippage protection
- [ ] Test edge cases where limits approach TickMath boundaries

## Expected Test Behavior After Implementation

### Before (Current - Failing):
```
sqrtPriceLimitX96: 0
❌ unlockCallback reverts with INVALID_PRICE_LIMIT()
```

### After (Expected - Passing):
```
sqrtPriceLimitX96: 1587464847513386322249134947289  (calculated value)
✅ unlockCallback executes successfully
✅ Swap completes with appropriate slippage protection  
✅ Balance changes reflect successful swap execution
```

## Security Considerations

### 1. Price Manipulation Resistance
- Price limits calculated from current pool state are resistant to manipulation
- Slippage tolerance provides additional protection beyond minAmountOut

### 2. Boundary Protection
- Enforcing TickMath.MIN_SQRT_PRICE and TickMath.MAX_SQRT_PRICE bounds prevents arithmetic overflow
- Direction validation prevents nonsensical price limits

### 3. Precision Maintenance  
- Using integer square root maintains precision while avoiding floating point issues
- 18-decimal scaling preserves accuracy in intermediate calculations

## Gas Optimization Notes

### Helper Function Efficiency
- `_calculatePriceLimit` uses view function (no state changes)
- Single `getSlot0` call retrieves current pool state efficiently  
- Square root calculation uses optimized Babylonian method

### V4 Integration Efficiency
- Calculated limits align with V4's internal price validation
- No additional external calls required during swap execution
- Price limits enable V4's early termination optimization

## Future Enhancements

### 1. Dynamic Slippage Based on Volatility
- Calculate slippage tolerance based on historical price volatility
- Implement time-weighted average price (TWAP) integration

### 2. Multi-Hop Price Limit Support
- Extend calculation for complex multi-hop swaps
- Implement cumulative slippage protection across hops

### 3. Oracle Integration
- Use external price oracles for price limit validation
- Implement circuit breakers for extreme market conditions

This implementation plan provides a comprehensive solution to the sqrtPriceLimitX96 calculation issue while maintaining security, efficiency, and integration with the existing Superform v2-core architecture.