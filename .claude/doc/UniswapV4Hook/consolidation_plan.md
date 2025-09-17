# UniswapV4 Hook Consolidation Implementation Plan

## Overview

This document outlines the consolidation of the UniswapV4 hook implementation to:
1. **Consolidate libraries** into the main hook contract for better organization
2. **Use real Uniswap V4 libraries** from `lib/v4-core` instead of mock implementations
3. **Replace custom interfaces** with official V4 interfaces
4. **Simplify testing** by removing library-specific unit tests

## Current Architecture Issues

### Problems with Current Implementation
1. **Over-fragmentation**: `DynamicMinAmountCalculator` and `UniswapV4QuoteOracle` as separate libraries adds unnecessary complexity
2. **Mock implementations**: Custom `IPoolManagerSuperform` and simplified math instead of real V4 libraries
3. **Testing complexity**: Unit tests for libraries that will be consolidated
4. **Import inconsistency**: Mix of custom and real V4 interfaces

## Target Architecture

### Consolidated SwapUniswapV4Hook Structure
```solidity
contract SwapUniswapV4Hook is BaseHook, IUnlockCallback {
    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    
    IPoolManager public immutable POOL_MANAGER;
    
    /*//////////////////////////////////////////////////////////////
                            DYNAMIC MIN AMOUNT LOGIC
    //////////////////////////////////////////////////////////////*/
    
    // Internal functions from DynamicMinAmountCalculator
    
    /*//////////////////////////////////////////////////////////////
                            QUOTE GENERATION LOGIC  
    //////////////////////////////////////////////////////////////*/
    
    // Internal functions from UniswapV4QuoteOracle using real V4 math
    
    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    
    // Core hook logic with consolidated functionality
}
```

## Implementation Steps

### Phase 1: Create Documentation and Setup ✅

1. **Create consolidated documentation** in `.claude/doc/UniswapV4Hook/`
2. **Update session context** with refactoring details

### Phase 2: Library Consolidation 

#### 2.1 Consolidate DynamicMinAmountCalculator
- **Target**: Move all logic into `SwapUniswapV4Hook` as internal functions
- **Preserve**: Critical ratio protection formula and validation logic
- **Organize**: Create dedicated section in hook contract

**Key Functions to Consolidate:**
```solidity
function _calculateDynamicMinAmount(RecalculationParams memory params) internal pure returns (uint256)
function _validateRatioChange(uint256 original, uint256 actual, uint256 maxDeviation) internal pure returns (bool)  
function _getRatioDeviationBps(uint256 amountRatio) internal pure returns (uint256)
```

#### 2.2 Consolidate UniswapV4QuoteOracle with Real V4 Math
- **Target**: Replace mock math with real V4 libraries
- **Use**: `SwapMath`, `TickMath`, `SqrtPriceMath` from `lib/v4-core/src/libraries/`
- **Implement**: Proper `SwapMath.computeSwapStep()` for accurate quotes

**Real V4 Integration:**
```solidity
import {SwapMath} from "v4-core/src/libraries/SwapMath.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol"; 
import {SqrtPriceMath} from "v4-core/src/libraries/SqrtPriceMath.sol";
```

### Phase 3: Interface Updates

#### 3.1 Replace Custom Interface
- **Delete**: `src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol`
- **Use**: `IPoolManager` from `lib/v4-core/src/interfaces/IPoolManager.sol`
- **Update**: All imports to use real V4 interfaces

#### 3.2 Update Type Imports  
```solidity
// Replace custom types with real V4 types
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
```

### Phase 4: Testing Updates

#### 4.1 Remove Library Unit Tests
- **Delete**: `test/unit/libraries/DynamicMinAmountCalculator.t.sol`
- **Reason**: Functionality now internal to hook contract

#### 4.2 Update Integration Tests
- **Update**: Import statements to use real V4 interfaces
- **Preserve**: All test logic and scenarios
- **Fix**: Any compilation issues from interface changes

#### 4.3 Update Mock Contracts
- **Update**: `MockPoolManager` to match real `IPoolManager` interface
- **Ensure**: Compatibility with real V4 function signatures

## Technical Implementation Details

### Dynamic MinAmount Recalculation 

**Core Formula Preservation:**
```solidity
newMinAmount = originalMinAmount * (actualAmountIn / originalAmountIn)
```

**Ratio Protection Logic:**
```solidity
function _calculateDynamicMinAmount(
    uint256 originalAmountIn,
    uint256 originalMinAmountOut, 
    uint256 actualAmountIn,
    uint256 maxSlippageDeviationBps
) internal pure returns (uint256 newMinAmountOut) {
    // Calculate ratio with 1e18 precision
    uint256 amountRatio = (actualAmountIn * 1e18) / originalAmountIn;
    
    // Calculate new minAmountOut proportionally
    newMinAmountOut = (originalMinAmountOut * amountRatio) / 1e18;
    
    // Validate ratio deviation
    uint256 ratioDeviationBps = _getRatioDeviationBps(amountRatio);
    require(ratioDeviationBps <= maxSlippageDeviationBps, "ExcessiveSlippageDeviation");
}
```

### Real V4 Quote Generation

**Using SwapMath.computeSwapStep():**
```solidity
function _generateQuote(
    IPoolManager poolManager,
    PoolKey memory poolKey,
    bool zeroForOne,
    uint256 amountIn
) internal view returns (uint256 amountOut) {
    // Get current pool state
    (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(poolKey.toId());
    
    // Use real V4 math for quote generation
    (uint160 sqrtPriceNextX96, uint256 amountInStep, uint256 amountOutStep,) = SwapMath.computeSwapStep(
        sqrtPriceX96,
        sqrtPriceTargetX96, // Calculate using TickMath
        liquidity,          // Get from pool state
        int256(amountIn),
        fee
    );
    
    return amountOutStep;
}
```

### Hook Data Structure (Unchanged)

**297+ bytes structure preserved:**
```solidity
/// @dev data has the following structure  
/// @notice         PoolKey poolKey = abi.decode(data[0:160], (PoolKey));
/// @notice         address dstReceiver = address(bytes20(data[160:180]));
/// @notice         uint160 sqrtPriceLimitX96 = uint160(bytes20(data[180:200])); 
/// @notice         uint256 originalAmountIn = uint256(bytes32(data[200:232]));
/// @notice         uint256 originalMinAmountOut = uint256(bytes32(data[232:264]));
/// @notice         uint256 maxSlippageDeviationBps = uint256(bytes32(data[264:296]));
/// @notice         bool usePrevHookAmount = _decodeBool(data, 296);
/// @notice         bytes additionalData = data[297:];
```

## File Operations Summary

### Files to Delete:
- `src/libraries/uniswap-v4/DynamicMinAmountCalculator.sol`
- `src/libraries/uniswap-v4/UniswapV4QuoteOracle.sol` 
- `src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol`
- `test/unit/libraries/DynamicMinAmountCalculator.t.sol`

### Files to Modify:
- `src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol` - Consolidate all functionality
- `test/integration/uniswap-v4/UniswapV4HookIntegrationTest.t.sol` - Update imports
- `test/integration/uniswap-v4/UniswapV4MainnetForkTest.t.sol` - Update imports
- `test/mocks/MockPoolManager.sol` - Match real IPoolManager interface
- `test/utils/parsers/UniswapV4Parser.sol` - Update type imports

## Benefits of Consolidation

### 1. **Simplified Architecture**
- Single file contains all V4 hook logic
- Easier to understand and maintain
- Better code organization with clear sections

### 2. **Real V4 Integration**
- Uses official V4 math libraries for accuracy
- Compatible with actual V4 deployments  
- Eliminates mock implementation risks

### 3. **Reduced Complexity**
- Fewer files to manage
- Simplified imports and dependencies
- Consolidated testing approach

### 4. **Enhanced Maintainability**
- Single source of truth for V4 hook logic
- Easier to debug and extend
- Better alignment with V4 ecosystem updates

## Risk Mitigation

### Potential Issues:
1. **Integration complexity** - Real V4 libraries may have different behavior
2. **Test compatibility** - Existing tests may need updates
3. **Performance impact** - Consolidated contract may be larger

### Mitigation Strategies:
1. **Careful testing** - Thoroughly test all consolidated functionality
2. **Phased approach** - Implement and test each section independently  
3. **Documentation** - Clear organization with detailed comments
4. **Validation** - Ensure all existing functionality is preserved

## Success Criteria

### Technical Success:
- [ ] All library functionality consolidated into hook contract
- [ ] Real V4 libraries used for math operations
- [ ] All tests pass with updated architecture
- [ ] Hook maintains exact same external interface

### Quality Success:  
- [ ] Code is well-organized with clear sections
- [ ] Dynamic minAmount recalculation works identically  
- [ ] Quote generation uses real V4 math
- [ ] Integration tests demonstrate full functionality

This consolidation will result in a cleaner, more maintainable, and production-ready UniswapV4 hook that leverages the full power of Uniswap V4's math libraries while preserving all critical functionality.