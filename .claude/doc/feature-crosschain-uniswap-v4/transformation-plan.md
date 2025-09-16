# CrosschainWithDestinationSwapTests UniswapV4 Hook Transformation Plan

## Overview

This document provides a comprehensive implementation plan for transforming `CrosschainWithDestinationSwapTests.sol` from using 0x swap integration to UniswapV4 hook integration. The transformation removes all 0x-related code and replaces it with production-ready UniswapV4 hook functionality.

## Current State Analysis

### Existing 0x Integration (Lines to Replace)
- **Line 305**: `dstHookAddresses[1] = _getHookAddress(ETH, SWAP_0X_HOOK_KEY);`
- **Lines 320-335**: 0x API quote generation and hook data creation
- **Line 315**: `ALLOWANCE_HOLDER_ADDRESS` approval pattern
- **Line 321**: `ZeroExQuoteResponse memory quote = getZeroExQuote(...)`
- **Line 331**: `createHookDataFromQuote(quote, ...)`

### Current Hook Chain Structure
1. **Hook 0**: Approve WETH to AllowanceHolder (with fee reduction)
2. **Hook 1**: Swap WETH→USDC via 0x ⬅️ **TARGET FOR REPLACEMENT**
3. **Hook 2**: Approve USDC to vault
4. **Hook 3**: Deposit USDC to vault

## Transformation Strategy

### 1. Infrastructure Setup Required

#### Add New Imports
```solidity
// Remove 0x-related imports (none found in current file)

// Add UniswapV4 imports
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { UniswapV4Parser } from "../../utils/parsers/UniswapV4Parser.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
```

#### Add New Contract Variables
```solidity
// Add after existing contract variables (around line 141)
SwapUniswapV4Hook public uniswapV4Hook;
UniswapV4Parser public uniswapV4Parser;
IPoolManager public poolManager;

// UniswapV4 pool configuration
PoolKey public wethUsdcPoolKey;
uint24 public constant FEE_MEDIUM = 3000; // 0.3%
int24 public constant TICK_SPACING_MEDIUM = 60;
```

#### Setup Method Additions
```solidity
// Add to setUp() method after line 258
// -- UniswapV4 setup
poolManager = IPoolManager(MAINNET_V4_POOL_MANAGER);
uniswapV4Hook = new SwapUniswapV4Hook(address(poolManager));
uniswapV4Parser = new UniswapV4Parser();

// Setup WETH/USDC pool key for ETH mainnet
wethUsdcPoolKey = PoolKey({
    currency0: Currency.wrap(underlyingETH_USDC), // USDC
    currency1: Currency.wrap(underlyingETH_WETH), // WETH  
    fee: FEE_MEDIUM,
    tickSpacing: TICK_SPACING_MEDIUM,
    hooks: IHooks(address(0))
});

vm.label(address(uniswapV4Hook), "UniswapV4Hook");
vm.label(address(uniswapV4Parser), "UniswapV4Parser");
```

### 2. Core Hook Replacement

#### Replace Hook Address (Line 305)
```solidity
// BEFORE:
dstHookAddresses[1] = _getHookAddress(ETH, SWAP_0X_HOOK_KEY);

// AFTER:
dstHookAddresses[1] = address(uniswapV4Hook);
```

### 3. Approval Pattern Change

#### Modify Hook 0 - WETH Approval (Lines 312-318)
```solidity
// BEFORE:
dstHookData[0] = _createApproveHookData(
    getWETHAddress(), // WETH (received from bridge)
    ALLOWANCE_HOLDER_ADDRESS, // Approve to 0x AllowanceHolder
    adjustedWETHAmount, // amount (the exact amount that will be received from bridge after fees)
    false // usePrevHookAmount = false
);

// AFTER:
dstHookData[0] = _createApproveHookData(
    getWETHAddress(), // WETH (received from bridge)
    address(uniswapV4Hook), // Approve to UniswapV4 hook
    adjustedWETHAmount, // amount (the exact amount that will be received from bridge after fees)
    false // usePrevHookAmount = false
);
```

### 4. Quote Generation Replacement

#### Replace 0x API Quote with UniswapV4 Quote (Lines 320-335)
```solidity
// BEFORE:
// Hook 2: Get real 0x API quote for WETH -> USDC swap using the actual account
ZeroExQuoteResponse memory quote = getZeroExQuote(
    getWETHAddress(), // sell WETH
    underlyingETH_USDC, // buy USDC
    amountPerVault,
    accountToUse, // use the actual executing account
    1, // chainId (ETH mainnet)
    500, // slippage tolerance in basis points (5% slippage)
    ZEROX_API_KEY
);

dstHookData[1] = createHookDataFromQuote(
    quote,
    address(0), // dstReceiver (0 = account)
    true // usePrevHookAmount = true (use approved WETH amount from previous hook)
);

// AFTER:
// Hook 2: Generate UniswapV4 quote and calldata for WETH -> USDC swap
bool zeroForOne = getWETHAddress() < underlyingETH_USDC; // Determine swap direction based on token ordering

// Calculate appropriate price limit with 1% slippage tolerance
uint160 priceLimit = _calculatePriceLimit(wethUsdcPoolKey, zeroForOne, 100);

// Get realistic minimum using UniswapV4 on-chain quote
SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
    SwapUniswapV4Hook.QuoteParams({
        poolKey: wethUsdcPoolKey,
        zeroForOne: zeroForOne,
        amountIn: adjustedWETHAmount,
        sqrtPriceLimitX96: priceLimit
    })
);
uint256 expectedMinUSDC = quote.amountOut * 995 / 1000; // Apply 0.5% additional slippage buffer

// Generate swap calldata using the parser
dstHookData[1] = uniswapV4Parser.generateSingleHopSwapCalldata(
    UniswapV4Parser.SingleHopParams({
        poolKey: wethUsdcPoolKey,
        dstReceiver: accountToUse,
        sqrtPriceLimitX96: priceLimit,
        originalAmountIn: adjustedWETHAmount,
        originalMinAmountOut: expectedMinUSDC,
        maxSlippageDeviationBps: 500, // 5% max deviation
        zeroForOne: zeroForOne,
        additionalData: ""
    }),
    true // usePrevHookAmount = true (use approved WETH amount from previous hook)
);
```

### 5. Helper Functions Required

#### Add Price Limit Calculation Function
```solidity
// Add this helper function to the contract (after line 503)
/// @notice Calculate appropriate sqrtPriceLimitX96 based on current pool price and slippage tolerance
/// @param poolKey The pool to get current price from
/// @param zeroForOne Direction of the swap
/// @param slippageToleranceBps Slippage tolerance in basis points (e.g., 50 = 0.5%)
/// @return sqrtPriceLimitX96 The calculated price limit
function _calculatePriceLimit(
    PoolKey memory poolKey,
    bool zeroForOne,
    uint256 slippageToleranceBps
)
    internal
    view
    returns (uint160 sqrtPriceLimitX96)
{
    PoolId poolId = PoolIdLibrary.toId(poolKey);
    
    // Get current pool price
    (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
    
    // Handle uninitialized pools - use a reasonable default
    if (currentSqrtPriceX96 == 0) {
        currentSqrtPriceX96 = 79_228_162_514_264_337_593_543_950_336; // 1:1 price ratio
    }
    
    // Calculate slippage factor (10000 = 100%)
    uint256 slippageFactor = zeroForOne
        ? 10_000 - slippageToleranceBps // Price goes down
        : 10_000 + slippageToleranceBps; // Price goes up
    
    // Apply square root to slippage factor (since we're dealing with sqrt prices)
    uint256 sqrtSlippageFactor = _sqrt(slippageFactor * 1e18 / 10_000);
    uint256 adjustedPrice = (uint256(currentSqrtPriceX96) * sqrtSlippageFactor) / 1e9;
    
    // Enforce TickMath boundaries
    if (zeroForOne) {
        sqrtPriceLimitX96 = adjustedPrice < TickMath.MIN_SQRT_PRICE + 1 
            ? TickMath.MIN_SQRT_PRICE + 1 
            : uint160(adjustedPrice);
    } else {
        sqrtPriceLimitX96 = adjustedPrice > TickMath.MAX_SQRT_PRICE - 1 
            ? TickMath.MAX_SQRT_PRICE - 1 
            : uint160(adjustedPrice);
    }
}

/// @notice Integer square root using Babylonian method
/// @param x The number to calculate square root of
/// @return The square root of x
function _sqrt(uint256 x) internal pure returns (uint256) {
    if (x == 0) return 0;
    uint256 z = (x + 1) / 2;
    uint256 y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
    return y;
}
```

### 6. Constants Cleanup

#### Remove 0x-Related Constants
```solidity
// REMOVE:
address public constant ALLOWANCE_HOLDER_ADDRESS = 0x0000000000001fF3684f28c67538d4D072C22734;
```

### 7. Test Method Updates

#### Update Test Documentation and Comments
```solidity
// Update line 268-272 comments:
/// @notice Test bridge from BASE to ETH with destination UniswapV4 swap and deposit
/// @dev Bridge USDC from BASE to ETH, swap WETH to USDC via UniswapV4, then deposit USDC to vault
/// @dev Real user flow: Bridge WETH, approve WETH (with 5% fee reduction), swap WETH to USDC via V4, approve USDC, deposit USDC
/// @dev This test demonstrates real UniswapV4 integration in crosschain context with proper hook chaining
function test_Bridge_To_ETH_With_UniswapV4_Swap_And_Deposit() public {
```

## Implementation Priority and Dependencies

### Phase 1: Infrastructure Setup
1. ✅ Add imports and contract variables
2. ✅ Add setUp() method configurations  
3. ✅ Add helper functions (_calculatePriceLimit, _sqrt)

### Phase 2: Core Replacement
4. ✅ Replace hook address (line 305)
5. ✅ Update WETH approval target (lines 312-318)
6. ✅ Replace 0x quote with UniswapV4 quote (lines 320-335)

### Phase 3: Cleanup and Testing
7. ✅ Remove 0x constants
8. ✅ Update test method name and documentation
9. ✅ Verify test execution

## Critical Requirements

### Pool Manager Integration
- Must use `MAINNET_V4_POOL_MANAGER` address from Constants
- Proper WETH/USDC pool configuration with correct token ordering
- Real pool state access for quote generation

### Hook Chaining Compatibility
- Maintain `usePrevHookAmount = true` for hook chaining
- Preserve fee reduction logic for bridge operations
- Ensure proper token flow: Bridge→Approve→Swap→Approve→Deposit

### Dynamic Slippage Protection
- Use UniswapV4Hook's dynamic minAmount recalculation
- Apply proper slippage tolerance (1% for price limit, 0.5% buffer on quote)
- Maintain maxSlippageDeviationBps for ratio protection

## Testing and Validation

### Pre-Implementation Verification
- Confirm `MAINNET_V4_POOL_MANAGER` is properly configured in BaseTest
- Verify WETH/USDC pool exists and has liquidity on mainnet fork
- Test pool token ordering (USDC < WETH) for proper zeroForOne calculation

### Post-Implementation Testing
- Run the transformed test to ensure successful execution
- Verify proper token balances at each step
- Confirm hook chaining works correctly
- Validate dynamic slippage calculations

## Risk Mitigation

### Key Risk Factors
1. **Pool Liquidity**: UniswapV4 pools may have different liquidity than 0x aggregated sources
2. **Price Deviation**: On-chain quotes may differ significantly from 0x aggregated quotes
3. **Gas Optimization**: UniswapV4 hook execution may have different gas patterns

### Mitigation Strategies
1. **Flexible Slippage**: Use generous slippage tolerances (5% maxSlippageDeviationBps)
2. **Quote Validation**: Implement quote deviation safety bounds (already in UniswapV4Hook)
3. **Fallback Testing**: Maintain ability to test with mock pools if mainnet pools are unavailable

## File Dependencies

### Files to Modify
- ✅ `/test/integration/CrosschainWithDestinationSwapTests.sol` - Main transformation target

### Files to Reference (No Changes)
- ✅ `/src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol` - Hook implementation
- ✅ `/test/utils/parsers/UniswapV4Parser.sol` - Calldata generation
- ✅ `/test/integration/uniswap-v4/UniswapV4HookIntegrationTest.t.sol` - Pattern reference
- ✅ `/test/utils/Constants.sol` - Hook key constants

## Expected Outcomes

### Successful Transformation Results
1. **Functional Replacement**: Complete removal of 0x dependencies with working UniswapV4 alternative
2. **Maintained Test Coverage**: Test continues to validate crosschain swap and deposit flow
3. **Production Readiness**: Uses real UniswapV4 pools and production-grade hook implementation
4. **Hook Chaining**: Preserves multi-hook execution pattern with proper amount passing

### Performance Expectations
- Similar or better swap rates compared to 0x (depending on pool liquidity)
- Reduced external dependencies (no API calls)
- On-chain quote generation for better reliability
- Gas-efficient execution through optimized V4 hooks

This transformation plan provides a comprehensive roadmap for replacing 0x integration with UniswapV4 hook integration while maintaining all existing functionality and improving the production readiness of the crosschain swap test.