# SwapUniswapV4Hook Data Structure Refactor Plan

## Overview
This document provides a comprehensive implementation plan to refactor the SwapUniswapV4Hook data structure from using `PoolKey` struct encoding to following Superform's standard pattern with individual field encoding using BytesLib.

## Current Implementation Analysis

### Current Data Structure (298+ bytes)
The current implementation uses `abi.encode(params.poolKey)` for the PoolKey struct, which violates Superform's standard patterns:

```solidity
/// @dev data has the following structure
/// @notice         PoolKey poolKey = abi.decode(data[0:160], (PoolKey));
/// @notice         address dstReceiver = address(bytes20(data[160:180]));
/// @notice         uint160 sqrtPriceLimitX96 = uint160(bytes20(data[180:200]));
/// @notice         uint256 originalAmountIn = uint256(bytes32(data[200:232]));
/// @notice         uint256 originalMinAmountOut = uint256(bytes32(data[232:264]));
/// @notice         uint256 maxSlippageDeviationBps = uint256(bytes32(data[264:296]));
/// @notice         bool zeroForOne = _decodeBool(data, 296);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 297);
/// @notice         bytes additionalData = data.length > 298 ? data[298:] : "";
```

### PoolKey Struct Components
From Uniswap V4 core, PoolKey contains:
```solidity
struct PoolKey {
    Currency currency0;   // address type (20 bytes)
    Currency currency1;   // address type (20 bytes) 
    uint24 fee;          // 3 bytes
    int24 tickSpacing;   // 3 bytes
    IHooks hooks;        // address type (20 bytes)
}
```

## New Data Structure Design

### New Byte Layout (312+ bytes)
Following AcrossSendFundsAndExecuteOnDstHook pattern with individual fields:

| Field | Type | Size | Position | BytesLib Decoder |
|-------|------|------|----------|------------------|
| currency0 | address | 20 bytes | 0-20 | `BytesLib.toAddress(data, 0)` |
| currency1 | address | 20 bytes | 20-40 | `BytesLib.toAddress(data, 20)` |
| fee | uint24 | 4 bytes* | 40-44 | `BytesLib.toUint32(data, 40)` → cast to uint24 |
| tickSpacing | int24 | 4 bytes* | 44-48 | `BytesLib.toUint32(data, 44)` → cast to int24 |
| hooks | address | 20 bytes | 48-68 | `BytesLib.toAddress(data, 48)` |
| dstReceiver | address | 20 bytes | 68-88 | `BytesLib.toAddress(data, 68)` |
| sqrtPriceLimitX96 | uint160 | 32 bytes* | 88-120 | `BytesLib.toUint256(data, 88)` → cast to uint160 |
| originalAmountIn | uint256 | 32 bytes | 120-152 | `BytesLib.toUint256(data, 120)` |
| originalMinAmountOut | uint256 | 32 bytes | 152-184 | `BytesLib.toUint256(data, 152)` |
| maxSlippageDeviationBps | uint256 | 32 bytes | 184-216 | `BytesLib.toUint256(data, 184)` |
| zeroForOne | bool | 1 byte | 216 | `_decodeBool(data, 216)` |
| usePrevHookAmount | bool | 1 byte | 217 | `_decodeBool(data, 217)` |
| additionalData | bytes | variable | 218+ | `BytesLib.slice(data, 218, data.length - 218)` |

*Note: BytesLib doesn't have toUint24/toInt24/toUint160, so we use available functions and cast appropriately.

### New NatSpec Documentation Pattern
```solidity
/// @dev data has the following structure
/// @notice         address currency0 = BytesLib.toAddress(data, 0);
/// @notice         address currency1 = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice         int24 tickSpacing = int24(BytesLib.toUint32(data, 44));
/// @notice         address hooks = BytesLib.toAddress(data, 48);
/// @notice         address dstReceiver = BytesLib.toAddress(data, 68);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 88));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 120);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 152);
/// @notice         uint256 maxSlippageDeviationBps = BytesLib.toUint256(data, 184);
/// @notice         bool zeroForOne = _decodeBool(data, 216);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 217);
/// @notice         bytes additionalData = BytesLib.slice(data, 218, data.length - 218);
```

## Implementation Plan

### Phase 1: Hook Contract Changes

#### 1.1 Import BytesLib
Add the BytesLib import to SwapUniswapV4Hook.sol:
```solidity
import { BytesLib } from "../../../vendor/BytesLib.sol";
```

#### 1.2 Update _decodeHookData Function
Replace the current implementation with BytesLib-based decoding:

```solidity
function _decodeHookData(bytes calldata data)
    internal
    pure
    returns (
        PoolKey memory poolKey,
        address dstReceiver,
        uint160 sqrtPriceLimitX96,
        uint256 originalAmountIn,
        uint256 originalMinAmountOut,
        uint256 maxSlippageDeviationBps,
        bool zeroForOne,
        bool usePrevHookAmount,
        bytes memory additionalData
    )
{
    // Validate minimum data length (218 bytes minimum)
    if (data.length < 218) {
        revert INVALID_HOOK_DATA();
    }

    // Decode individual PoolKey components using BytesLib
    poolKey.currency0 = Currency.wrap(BytesLib.toAddress(data, 0));
    poolKey.currency1 = Currency.wrap(BytesLib.toAddress(data, 20));
    poolKey.fee = uint24(BytesLib.toUint32(data, 40));
    poolKey.tickSpacing = int24(uint24(BytesLib.toUint32(data, 44))); // Cast to avoid sign issues
    poolKey.hooks = IHooks(BytesLib.toAddress(data, 48));
    
    // Decode remaining fields
    dstReceiver = BytesLib.toAddress(data, 68);
    sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 88));
    originalAmountIn = BytesLib.toUint256(data, 120);
    originalMinAmountOut = BytesLib.toUint256(data, 152);
    maxSlippageDeviationBps = BytesLib.toUint256(data, 184);
    zeroForOne = _decodeBool(data, 216);
    usePrevHookAmount = _decodeBool(data, 217);
    
    // Additional data (if present)
    if (data.length > 218) {
        additionalData = BytesLib.slice(data, 218, data.length - 218);
    }
    
    // Add validation for PoolKey components
    _validatePoolKeyComponents(poolKey);
}
```

#### 1.3 Add PoolKey Validation Helper
Create a helper function to validate the decoded PoolKey components:

```solidity
/// @notice Validates PoolKey components after decoding
/// @param poolKey The decoded pool key
function _validatePoolKeyComponents(PoolKey memory poolKey) private pure {
    if (Currency.unwrap(poolKey.currency0) == address(0) && Currency.unwrap(poolKey.currency1) == address(0)) {
        revert INVALID_POOL_KEY();
    }
    if (poolKey.fee == 0) {
        revert INVALID_POOL_KEY();
    }
    if (poolKey.tickSpacing == 0) {
        revert INVALID_POOL_KEY();
    }
    // Ensure proper token ordering (currency0 < currency1)
    if (Currency.unwrap(poolKey.currency0) >= Currency.unwrap(poolKey.currency1)) {
        revert INVALID_TOKEN_ORDERING();
    }
}
```

#### 1.4 Update Helper Functions
Update functions that currently decode minimal data to use new structure:

```solidity
function _getTransferParams(
    address prevHook,
    address account,
    bytes calldata data
)
    internal
    view
    returns (address inputToken, uint256 amountIn)
{
    // Decode using new structure
    address currency0 = BytesLib.toAddress(data, 0);
    address currency1 = BytesLib.toAddress(data, 20);
    bool zeroForOne = _decodeBool(data, 216);
    bool usePrevHookAmount = _decodeBool(data, 217);
    
    // Get input token
    inputToken = zeroForOne ? currency0 : currency1;
    
    if (usePrevHookAmount) {
        amountIn = ISuperHookResult(prevHook).getOutAmount(account);
    } else {
        amountIn = BytesLib.toUint256(data, 120); // originalAmountIn
    }
}
```

#### 1.5 Update _getOutputToken Function
```solidity
function _getOutputToken(bytes calldata data) internal pure returns (address outputToken) {
    address currency0 = BytesLib.toAddress(data, 0);
    address currency1 = BytesLib.toAddress(data, 20);
    bool zeroForOne = _decodeBool(data, 216);
    
    outputToken = zeroForOne ? currency1 : currency0;
}
```

#### 1.6 Update inspect Function
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    // Extract token addresses using BytesLib
    address currency0 = BytesLib.toAddress(data, 0);
    address currency1 = BytesLib.toAddress(data, 20);
    
    // Return packed token addresses for inspection
    return abi.encodePacked(currency0, currency1);
}
```

#### 1.7 Update decodeUsePrevHookAmount Function
```solidity
function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool usePrevHookAmount) {
    if (data.length < 218) {
        revert INVALID_HOOK_DATA();
    }
    usePrevHookAmount = _decodeBool(data, 217);
}
```

#### 1.8 Add New Custom Errors
```solidity
/// @notice Thrown when pool key components are invalid
error INVALID_POOL_KEY();

/// @notice Thrown when token ordering is incorrect (currency0 >= currency1)
error INVALID_TOKEN_ORDERING();
```

### Phase 2: Parser Updates

#### 2.1 Update UniswapV4Parser.sol

Replace the `generateSingleHopSwapCalldata` function to use individual field encoding:

```solidity
function generateSingleHopSwapCalldata(
    SingleHopParams memory params,
    bool usePrevHookAmount
)
    public
    pure
    returns (bytes memory hookData)
{
    // Validate token ordering
    if (Currency.unwrap(params.poolKey.currency0) >= Currency.unwrap(params.poolKey.currency1)) {
        revert("Invalid token ordering");
    }
    
    // Encode individual PoolKey components + other fields
    hookData = abi.encodePacked(
        Currency.unwrap(params.poolKey.currency0),      // 20 bytes: currency0
        Currency.unwrap(params.poolKey.currency1),      // 20 bytes: currency1
        uint32(params.poolKey.fee),                     // 4 bytes: fee (padded to 32-bit)
        uint32(uint24(params.poolKey.tickSpacing)),     // 4 bytes: tickSpacing (cast and pad)
        params.poolKey.hooks,                           // 20 bytes: hooks address
        params.dstReceiver,                             // 20 bytes: dstReceiver
        uint256(params.sqrtPriceLimitX96),              // 32 bytes: sqrtPriceLimitX96 (padded)
        params.originalAmountIn,                        // 32 bytes: originalAmountIn
        params.originalMinAmountOut,                    // 32 bytes: originalMinAmountOut  
        params.maxSlippageDeviationBps,                 // 32 bytes: maxSlippageDeviationBps
        params.zeroForOne ? bytes1(0x01) : bytes1(0x00), // 1 byte: zeroForOne flag
        usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),  // 1 byte: usePrevHookAmount flag
        params.additionalData                           // Variable: additional data
    );
}
```

### Phase 3: Test Updates

#### 3.1 Update Integration Tests
The integration test should work without changes since it uses the parser, but we should add specific tests for the new decoding logic:

```solidity
function test_UniswapV4Hook_NewDataStructureDecoding() external view {
    console2.log("=== New Data Structure Decoding Test ===");
    
    // Test that new structure properly decodes PoolKey components
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: 0,
            originalAmountIn: 1000e6,
            originalMinAmountOut: 300_000_000_000_000_000,
            maxSlippageDeviationBps: 500,
            zeroForOne: true,
            additionalData: ""
        }),
        false
    );
    
    // Verify the hook can decode individual fields correctly
    (
        PoolKey memory decodedPoolKey,
        address decodedReceiver,
        uint160 decodedPriceLimit,
        uint256 decodedAmountIn,
        uint256 decodedMinOut,
        uint256 decodedMaxDeviation,
        bool decodedZeroForOne,
        bool decodedUsePrevHookAmount,
        bytes memory decodedAdditionalData
    ) = uniswapV4Hook._decodeHookData(swapCalldata); // Make function public for testing
    
    // Verify all fields decoded correctly
    assertEq(Currency.unwrap(decodedPoolKey.currency0), Currency.unwrap(testPoolKey.currency0));
    assertEq(Currency.unwrap(decodedPoolKey.currency1), Currency.unwrap(testPoolKey.currency1));
    assertEq(decodedPoolKey.fee, testPoolKey.fee);
    assertEq(decodedPoolKey.tickSpacing, testPoolKey.tickSpacing);
    assertEq(address(decodedPoolKey.hooks), address(testPoolKey.hooks));
    assertEq(decodedReceiver, accountEth);
    assertEq(decodedAmountIn, 1000e6);
    assertEq(decodedMinOut, 300_000_000_000_000_000);
    assertEq(decodedMaxDeviation, 500);
    assertTrue(decodedZeroForOne);
    assertFalse(decodedUsePrevHookAmount);
    assertEq(decodedAdditionalData.length, 0);
    
    console2.log("New data structure decoding test passed");
}

function test_UniswapV4Hook_DataLengthValidation() external {
    console2.log("=== Data Length Validation Test ===");
    
    // Test with insufficient data length
    bytes memory shortData = new bytes(217); // 1 byte short
    
    vm.expectRevert(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector);
    uniswapV4Hook.inspect(shortData);
    
    console2.log("Data length validation test passed");
}
```

#### 3.2 Add Backwards Compatibility Tests
Add tests to ensure the refactored implementation produces the same results as the old implementation:

```solidity
function test_UniswapV4Hook_BackwardsCompatibilityQuoteResults() external view {
    console2.log("=== Backwards Compatibility Quote Results Test ===");
    
    // Test that refactored data structure produces same quote results
    uint256 swapAmountIn = 1000e6;
    bool zeroForOne = true;
    uint160 priceLimit = _calculatePriceLimit(testPoolKey, zeroForOne, 50);
    
    SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
        SwapUniswapV4Hook.QuoteParams({
            poolKey: testPoolKey,
            zeroForOne: zeroForOne,
            amountIn: swapAmountIn,
            sqrtPriceLimitX96: priceLimit
        })
    );
    
    // Quote should be non-zero and reasonable
    assertGt(quote.amountOut, 0, "Quote should produce non-zero output");
    assertGt(quote.sqrtPriceX96After, 0, "Price after should be non-zero");
    
    console2.log("Quote amountOut:", quote.amountOut);
    console2.log("Quote sqrtPriceX96After:", quote.sqrtPriceX96After);
    console2.log("Backwards compatibility test passed");
}
```

## Implementation Steps & Dependencies

### Step 1: Core Hook Contract Changes
1. Add BytesLib import
2. Update NatSpec documentation 
3. Implement new `_decodeHookData` function
4. Add `_validatePoolKeyComponents` helper
5. Update all helper functions (`_getTransferParams`, `_getOutputToken`, etc.)
6. Update `inspect` and `decodeUsePrevHookAmount` functions
7. Add new custom errors

### Step 2: Parser Updates  
1. Update `generateSingleHopSwapCalldata` function in UniswapV4Parser.sol
2. Ensure proper data packing with correct byte alignment
3. Add validation for token ordering and other constraints

### Step 3: Test Updates
1. Add new test cases for data structure validation
2. Add backwards compatibility tests
3. Update existing integration tests if needed
4. Add edge case tests for malformed data

### Step 4: Validation & Testing
1. Run full test suite to ensure no regressions
2. Test with both mock and real V4 contracts
3. Validate gas costs haven't significantly increased
4. Test all edge cases (zero values, malformed data, etc.)

## Risk Assessment & Mitigation

### High Risk
- **Breaking Change**: This is a breaking change to the data format
- **Integration Impact**: Any off-chain systems using the hook will need updates

### Medium Risk  
- **Gas Cost Changes**: New decoding pattern may have different gas costs
- **Validation Logic**: New validation could reject previously valid data

### Low Risk
- **Type Casting**: Using uint32 for uint24/int24 fields (safe due to size)
- **BytesLib Dependency**: Already widely used in codebase

### Mitigation Strategies
1. **Comprehensive Testing**: Extensive test coverage including edge cases
2. **Backwards Compatibility Validation**: Ensure same functional outcomes
3. **Gas Cost Analysis**: Compare before/after gas usage
4. **Documentation Updates**: Clear documentation of changes for integrators
5. **Staged Rollout**: Deploy to testnet first for validation

## Expected Benefits

### Consistency
- Follows established Superform patterns (AcrossSendFundsAndExecuteOnDstHook)
- Uses BytesLib throughout the codebase consistently
- Standardized data structure documentation

### Maintainability
- Easier to understand and modify individual fields
- Clear byte position documentation
- Explicit field validation

### Integration
- Easier for off-chain systems to construct data
- More predictable data layout
- Better alignment with other Superform hooks

## Post-Implementation Checklist

- [ ] All tests pass (unit, integration, fork tests)
- [ ] Gas costs analyzed and documented
- [ ] NatSpec documentation updated
- [ ] Integration tests with real V4 contracts successful  
- [ ] Error handling tested for all edge cases
- [ ] Code review completed
- [ ] Breaking change impacts documented for integrators

---

This comprehensive refactor plan ensures the SwapUniswapV4Hook follows Superform's established patterns while maintaining full functionality and adding better validation and maintainability.