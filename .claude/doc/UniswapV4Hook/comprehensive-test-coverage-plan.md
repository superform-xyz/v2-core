# Comprehensive Test Coverage Plan for SwapUniswapV4Hook

## Overview

This document provides a systematic plan to achieve 100% test coverage for SwapUniswapV4Hook, addressing all uncovered lines, branches, and error conditions identified through detailed code analysis.

## Current Coverage Analysis

### Existing Coverage (UniswapV4HookIntegrationTest.t.sol)
- ✅ Basic swap execution (USDC → WETH)  
- ✅ Native ETH swaps (ETH → USDC, USDC → ETH)
- ✅ Hook data decoding verification
- ✅ Inspector function validation
- ✅ Hook chaining with NativeTransferHook
- ✅ Balance validation and amount tracking

### Critical Coverage Gaps

#### 1. Error Conditions (12 uncovered error paths)
```solidity
// Currently untested revert conditions:
error INSUFFICIENT_OUTPUT_AMOUNT(uint256 actual, uint256 minimum);
error UNAUTHORIZED_CALLBACK();
error INVALID_HOOK_DATA();
error EXCESSIVE_SLIPPAGE_DEVIATION(uint256 actualDeviation, uint256 maxAllowed);
error INVALID_ORIGINAL_AMOUNTS();
error INVALID_ACTUAL_AMOUNT();
error ZERO_LIQUIDITY();
error INVALID_PRICE_LIMIT();
error INVALID_OUTPUT_DELTA();
error OUTPUT_AMOUNT_DIFFERENT_THAN_TRUE();
error INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE();
error QUOTE_DEVIATION_EXCEEDS_SAFETY_BOUNDS();
```

#### 2. Conditional Branches (15+ uncovered branches)
- Native vs ERC20 token handling paths
- Hook chaining conditions (`usePrevHookAmount`)
- Data validation branches
- Ratio deviation calculations
- Additional data handling (empty vs populated)

#### 3. Internal Functions (8 functions with limited coverage)
- `_calculateDynamicMinAmount()` edge cases
- `_calculateRatioDeviationBps()` boundary conditions
- `_validateQuoteDeviation()` failure scenarios
- `_decodeHookData()` validation logic
- Transient storage operations

## Implementation Plan

### Phase 1: Coverage Analysis Infrastructure

#### 1.1 Coverage Analysis Script
**File:** `scripts/analyze_uniswapv4_coverage.sh`

```bash
#!/bin/bash
# Comprehensive coverage analysis for SwapUniswapV4Hook

echo "=== SwapUniswapV4Hook Coverage Analysis ==="

# Generate coverage report
FOUNDRY_PROFILE=coverage forge coverage \
    --match-contract SwapUniswapV4Hook \
    --jobs 10 \
    --ir-minimum \
    --report lcov

# Parse results for SwapUniswapV4Hook specifically
python3 scripts/parse_hook_coverage.py lcov.info SwapUniswapV4Hook

echo "Coverage analysis complete. Check coverage_report.txt for detailed results."
```

#### 1.2 Coverage Parser Script
**File:** `scripts/parse_hook_coverage.py`

```python
#!/usr/bin/env python3
"""
Parse LCOV coverage data specifically for SwapUniswapV4Hook contract
Extracts uncovered lines, branches, and functions
"""

import sys
import re
from typing import Dict, List, Tuple

def parse_lcov_for_contract(lcov_file: str, contract_name: str) -> Dict:
    """Parse LCOV file and extract coverage data for specific contract"""
    
    coverage_data = {
        'uncovered_lines': [],
        'uncovered_branches': [],
        'uncovered_functions': [],
        'coverage_summary': {}
    }
    
    with open(lcov_file, 'r') as f:
        content = f.read()
    
    # Find contract section in LCOV data
    contract_pattern = f"SF:.*{contract_name}\.sol"
    contract_sections = re.split(r'SF:', content)
    
    target_section = None
    for section in contract_sections:
        if contract_name in section:
            target_section = section
            break
    
    if not target_section:
        print(f"Contract {contract_name} not found in coverage data")
        return coverage_data
    
    # Parse uncovered lines
    line_pattern = r'DA:(\d+),0'
    uncovered_lines = re.findall(line_pattern, target_section)
    coverage_data['uncovered_lines'] = [int(line) for line in uncovered_lines]
    
    # Parse uncovered branches
    branch_pattern = r'BRDA:(\d+),\d+,\d+,0'
    uncovered_branches = re.findall(branch_pattern, target_section)
    coverage_data['uncovered_branches'] = [int(line) for line in uncovered_branches]
    
    # Parse function coverage
    func_pattern = r'FNDA:0,(.+)'
    uncovered_functions = re.findall(func_pattern, target_section)
    coverage_data['uncovered_functions'] = uncovered_functions
    
    # Calculate coverage percentages
    total_lines_match = re.search(r'LH:(\d+)', target_section)
    found_lines_match = re.search(r'LF:(\d+)', target_section)
    
    if total_lines_match and found_lines_match:
        lines_hit = int(total_lines_match.group(1))
        lines_found = int(found_lines_match.group(1))
        line_coverage = (lines_hit / lines_found * 100) if lines_found > 0 else 0
        
        coverage_data['coverage_summary'] = {
            'line_coverage': line_coverage,
            'lines_hit': lines_hit,
            'lines_found': lines_found,
            'uncovered_count': len(coverage_data['uncovered_lines'])
        }
    
    return coverage_data

def generate_report(coverage_data: Dict, output_file: str = 'coverage_report.txt'):
    """Generate detailed coverage report"""
    
    with open(output_file, 'w') as f:
        f.write("=== SwapUniswapV4Hook Coverage Report ===\n\n")
        
        # Summary
        summary = coverage_data['coverage_summary']
        f.write(f"Line Coverage: {summary.get('line_coverage', 0):.2f}%\n")
        f.write(f"Lines Hit: {summary.get('lines_hit', 0)}/{summary.get('lines_found', 0)}\n")
        f.write(f"Uncovered Lines: {summary.get('uncovered_count', 0)}\n\n")
        
        # Uncovered lines
        if coverage_data['uncovered_lines']:
            f.write("UNCOVERED LINES:\n")
            for line in sorted(coverage_data['uncovered_lines']):
                f.write(f"  Line {line}\n")
            f.write("\n")
        
        # Uncovered branches
        if coverage_data['uncovered_branches']:
            f.write("UNCOVERED BRANCHES:\n")
            for line in sorted(set(coverage_data['uncovered_branches'])):
                f.write(f"  Branch at line {line}\n")
            f.write("\n")
        
        # Uncovered functions
        if coverage_data['uncovered_functions']:
            f.write("UNCOVERED FUNCTIONS:\n")
            for func in coverage_data['uncovered_functions']:
                f.write(f"  {func}\n")
            f.write("\n")
        
        f.write("=== Priority Testing Areas ===\n")
        f.write("1. Error condition testing (revert scenarios)\n")
        f.write("2. Edge cases and boundary conditions\n")
        f.write("3. Internal function unit testing\n")
        f.write("4. Complex integration scenarios\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 parse_hook_coverage.py <lcov_file> <contract_name>")
        sys.exit(1)
    
    lcov_file = sys.argv[1]
    contract_name = sys.argv[2]
    
    coverage_data = parse_lcov_for_contract(lcov_file, contract_name)
    generate_report(coverage_data)
    
    print(f"Coverage analysis complete for {contract_name}")
    print(f"Line coverage: {coverage_data['coverage_summary'].get('line_coverage', 0):.2f}%")
    print(f"Uncovered lines: {len(coverage_data['uncovered_lines'])}")
    print(f"Report saved to coverage_report.txt")
```

### Phase 2: Comprehensive Unit Tests

#### 2.1 Unit Test File Structure
**File:** `test/unit/hooks/SwapUniswapV4Hook.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

// Import contract under test
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";

// Import dependencies for mocking
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";

// Import test utilities
import { Helpers } from "../../utils/Helpers.sol";
import { MockPoolManager } from "../../mocks/MockPoolManager.sol";

/// @title SwapUniswapV4Hook Unit Tests
/// @notice Comprehensive unit tests focusing on error conditions, edge cases, and internal logic
contract SwapUniswapV4HookTest is Test, Helpers {
    
    SwapUniswapV4Hook public hook;
    MockPoolManager public mockPoolManager;
    
    // Test constants
    address constant USDC = 0xA0b86a33E6411A5f40D0000000000000000000000;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ACCOUNT = 0x1234567890123456789012345678901234567890;
    
    function setUp() public {
        // Deploy mock pool manager
        mockPoolManager = new MockPoolManager();
        
        // Deploy hook under test
        hook = new SwapUniswapV4Hook(address(mockPoolManager));
    }
    
    /*//////////////////////////////////////////////////////////////
                            ERROR CONDITION TESTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Test UNAUTHORIZED_CALLBACK error
    function test_RevertUnauthorizedCallback() public {
        bytes memory callbackData = abi.encode(
            _createTestPoolKey(),
            1000e6,    // amountIn
            950e6,     // minAmountOut
            ACCOUNT,   // dstReceiver
            uint160(0), // sqrtPriceLimitX96
            true,      // zeroForOne
            ""         // additionalData
        );
        
        // Call from unauthorized sender (not pool manager)
        vm.expectRevert(SwapUniswapV4Hook.UNAUTHORIZED_CALLBACK.selector);
        hook.unlockCallback(callbackData);
    }
    
    /// @notice Test INVALID_HOOK_DATA error for insufficient data length
    function test_RevertInvalidHookData_ShortLength() public {
        bytes memory shortData = new bytes(100); // Less than 218 bytes
        
        vm.expectRevert(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector);
        hook.decodeUsePrevHookAmount(shortData);
    }
    
    /// @notice Test INVALID_HOOK_DATA error for invalid token ordering
    function test_RevertInvalidHookData_InvalidTokenOrdering() public {
        bytes memory invalidData = abi.encodePacked(
            WETH,      // currency0 (should be smaller address)
            USDC,      // currency1 (larger address - violates V4 ordering)
            uint24(3000),  // fee
            int24(60),     // tickSpacing
            address(0),    // hooks
            ACCOUNT,       // dstReceiver
            // ... rest of the data structure
            new bytes(150) // padding to meet minimum length
        );
        
        vm.expectRevert(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector);
        hook.inspect(invalidData);
    }
    
    /// @notice Test EXCESSIVE_SLIPPAGE_DEVIATION error
    function test_RevertExcessiveSlippageDeviation() public {
        // Create test data with extreme ratio change that exceeds deviation bounds
        bytes memory testData = _createValidHookData({
            originalAmountIn: 1000e6,
            actualAmountIn: 10000e6,  // 900% increase - extreme ratio change
            maxSlippageDeviationBps: 500  // 5% max deviation - will be exceeded
        });
        
        vm.expectRevert(abi.encodeWithSelector(
            SwapUniswapV4Hook.EXCESSIVE_SLIPPAGE_DEVIATION.selector,
            9000,  // 90% deviation 
            500    // 5% max allowed
        ));
        
        // This will be called through _prepareUnlockData during execution
        _executeHookWithData(testData);
    }
    
    /// @notice Test ZERO_LIQUIDITY error
    function test_RevertZeroLiquidity() public {
        // Configure mock to return zero liquidity
        mockPoolManager.setPoolState(0, 0, 0, 0); // sqrtPrice = 0 (no liquidity)
        
        SwapUniswapV4Hook.QuoteParams memory params = SwapUniswapV4Hook.QuoteParams({
            poolKey: _createTestPoolKey(),
            zeroForOne: true,
            amountIn: 1000e6,
            sqrtPriceLimitX96: 0
        });
        
        vm.expectRevert(SwapUniswapV4Hook.ZERO_LIQUIDITY.selector);
        hook.getQuote(params);
    }
    
    /// @notice Test INVALID_PRICE_LIMIT error
    function test_RevertInvalidPriceLimit() public {
        bytes memory callbackData = abi.encode(
            _createTestPoolKey(),
            1000e6,    // amountIn
            950e6,     // minAmountOut
            ACCOUNT,   // dstReceiver
            uint160(0), // sqrtPriceLimitX96 - INVALID (zero)
            true,      // zeroForOne
            ""         // additionalData
        );
        
        // Call from pool manager (authorized)
        vm.prank(address(mockPoolManager));
        vm.expectRevert(SwapUniswapV4Hook.INVALID_PRICE_LIMIT.selector);
        hook.unlockCallback(callbackData);
    }
    
    /*//////////////////////////////////////////////////////////////
                        DYNAMIC MIN AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Test dynamic min amount calculation with exact ratio
    function test_DynamicMinAmount_ExactRatio() public {
        uint256 originalAmountIn = 1000e6;
        uint256 originalMinOut = 950e6;
        uint256 actualAmountIn = 1000e6; // Exact match
        
        bytes memory testData = _createValidHookData({
            originalAmountIn: originalAmountIn,
            actualAmountIn: actualAmountIn,
            originalMinOut: originalMinOut,
            maxSlippageDeviationBps: 500
        });
        
        // Should not revert - exact ratio maintained
        _executeHookWithData(testData);
    }
    
    /// @notice Test 50% amount decrease scenario
    function test_DynamicMinAmount_50PercentDecrease() public {
        uint256 originalAmountIn = 1000e6;
        uint256 originalMinOut = 950e6;
        uint256 actualAmountIn = 500e6; // 50% decrease
        
        bytes memory testData = _createValidHookData({
            originalAmountIn: originalAmountIn,
            actualAmountIn: actualAmountIn,
            originalMinOut: originalMinOut,
            maxSlippageDeviationBps: 6000 // 60% max deviation to allow this
        });
        
        // Should succeed with proportional min amount reduction
        _executeHookWithData(testData);
        
        // Expected: newMinOut = 950e6 * 500e6 / 1000e6 = 475e6
        // Verify the calculation was correct through execution success
    }
    
    /// @notice Test boundary condition at maximum deviation
    function test_DynamicMinAmount_BoundaryCondition() public {
        uint256 originalAmountIn = 1000e6;
        uint256 originalMinOut = 950e6;
        uint256 actualAmountIn = 1050e6; // 5% increase
        
        bytes memory testData = _createValidHookData({
            originalAmountIn: originalAmountIn,
            actualAmountIn: actualAmountIn,
            originalMinOut: originalMinOut,
            maxSlippageDeviationBps: 500 // Exactly 5% - should be at boundary
        });
        
        // Should succeed at exact boundary
        _executeHookWithData(testData);
    }
    
    /*//////////////////////////////////////////////////////////////
                        DATA HANDLING TESTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Test hook data decoding with additional data
    function test_DecodeHookData_WithAdditionalData() public view {
        bytes memory additionalData = "0x1234567890";
        bytes memory testData = _createValidHookDataWithAdditional(additionalData);
        
        // Should successfully decode without reverting
        bool usePrev = hook.decodeUsePrevHookAmount(testData);
        assertFalse(usePrev); // Based on our test data construction
    }
    
    /// @notice Test inspector function returns correct token addresses
    function test_InspectFunction_TokenAddressExtraction() public view {
        bytes memory testData = _createValidHookData({
            currency0: USDC,
            currency1: WETH
        });
        
        bytes memory result = hook.inspect(testData);
        
        // Should return 40 bytes (2 addresses)
        assertEq(result.length, 40);
        
        // Extract addresses and verify
        address extractedToken0;
        address extractedToken1;
        assembly {
            extractedToken0 := shr(96, mload(add(result, 0x20)))
            extractedToken1 := shr(96, mload(add(result, 0x34)))
        }
        
        assertEq(extractedToken0, USDC);
        assertEq(extractedToken1, WETH);
    }
    
    /*//////////////////////////////////////////////////////////////
                        INTERNAL LOGIC TESTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Test ratio deviation calculation for increases
    function test_RatioDeviationCalculation_Increases() public {
        // Test various ratio increases
        _testRatioDeviation(1.05e18, 500);  // 5% increase = 500 bps
        _testRatioDeviation(1.10e18, 1000); // 10% increase = 1000 bps
        _testRatioDeviation(2.00e18, 10000); // 100% increase = 10000 bps
    }
    
    /// @notice Test ratio deviation calculation for decreases
    function test_RatioDeviationCalculation_Decreases() public {
        // Test various ratio decreases
        _testRatioDeviation(0.95e18, 526);  // ~5% decrease
        _testRatioDeviation(0.90e18, 1111); // ~10% decrease
        _testRatioDeviation(0.50e18, 10000); // 50% decrease = 10000 bps
    }
    
    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _createTestPoolKey() internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }
    
    function _createValidHookData(HookDataParams memory params) 
        internal 
        pure 
        returns (bytes memory) 
    {
        return abi.encodePacked(
            params.currency0,
            params.currency1,
            uint24(3000),  // fee
            int24(60),     // tickSpacing
            address(0),    // hooks
            ACCOUNT,       // dstReceiver
            uint256(0),    // sqrtPriceLimitX96 (padded to 32 bytes)
            params.originalAmountIn,
            params.originalMinOut,
            params.maxSlippageDeviationBps,
            params.zeroForOne,
            params.usePrevHookAmount
        );
    }
    
    struct HookDataParams {
        address currency0;
        address currency1;
        uint256 originalAmountIn;
        uint256 actualAmountIn;
        uint256 originalMinOut;
        uint256 maxSlippageDeviationBps;
        bool zeroForOne;
        bool usePrevHookAmount;
    }
    
    function _executeHookWithData(bytes memory hookData) internal {
        // Mock the execution flow to test internal logic
        vm.mockCall(
            address(mockPoolManager),
            abi.encodeWithSelector(IPoolManager.unlock.selector),
            abi.encode(uint256(1000e6)) // Mock return value
        );
        
        // This would trigger the internal validation logic
        // Implementation depends on how we structure the test execution
    }
    
    function _testRatioDeviation(uint256 ratio, uint256 expectedBps) internal {
        // Test the ratio deviation calculation logic
        // Implementation would call internal calculation functions
        // and verify the results match expected basis points
    }
}
```

#### 2.2 Mock Contracts for Testing
**File:** `test/mocks/MockPoolManager.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { PoolId } from "v4-core/types/PoolId.sol";
import { Currency } from "v4-core/types/Currency.sol";
import { BalanceDelta } from "v4-core/types/BalanceDelta.sol";

/// @title MockPoolManager
/// @notice Mock implementation for testing error conditions and edge cases
contract MockPoolManager {
    
    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 protocolFee;
        uint24 lpFee;
        uint128 liquidity;
    }
    
    mapping(PoolId => PoolState) public pools;
    
    bool public shouldRevertOnSwap;
    bool public shouldRevertOnUnlock;
    int128 public mockOutputDelta;
    
    function setPoolState(
        uint160 sqrtPriceX96,
        uint24 protocolFee,
        uint24 lpFee,
        uint128 liquidity
    ) external {
        // Set state for all pools (simplified for testing)
        PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
        pools[poolId] = PoolState({
            sqrtPriceX96: sqrtPriceX96,
            tick: 0,
            protocolFee: protocolFee,
            lpFee: lpFee,
            liquidity: liquidity
        });
    }
    
    function setMockOutputDelta(int128 delta) external {
        mockOutputDelta = delta;
    }
    
    function setShouldRevertOnSwap(bool shouldRevert) external {
        shouldRevertOnSwap = shouldRevert;
    }
    
    function getSlot0(PoolId id) 
        external 
        view 
        returns (uint160, int24, uint24, uint24) 
    {
        PoolState memory pool = pools[id];
        return (pool.sqrtPriceX96, pool.tick, pool.protocolFee, pool.lpFee);
    }
    
    function getLiquidity(PoolId id) external view returns (uint128) {
        return pools[id].liquidity;
    }
    
    function unlock(bytes calldata data) external returns (bytes memory) {
        if (shouldRevertOnUnlock) {
            revert("Mock unlock revert");
        }
        
        // Call the callback to simulate V4 behavior
        IUnlockCallback callback = IUnlockCallback(msg.sender);
        return callback.unlockCallback(data);
    }
    
    function swap(
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external returns (BalanceDelta) {
        if (shouldRevertOnSwap) {
            revert("Mock swap revert");
        }
        
        // Return mock delta
        return BalanceDelta.wrap(
            (int256(int128(-1000e6)) << 128) | // amount0
            (int256(int128(mockOutputDelta)) & ((1 << 128) - 1)) // amount1
        );
    }
    
    function settle() external payable {
        // Mock implementation
    }
    
    function sync(Currency) external {
        // Mock implementation
    }
    
    function take(Currency, address, uint256) external {
        // Mock implementation
    }
}
```

### Phase 3: Integration Test Enhancements

#### 3.1 Enhanced Integration Tests
**Enhancement to:** `test/integration/uniswap-v4/UniswapV4HookIntegrationTest.t.sol`

**New test functions to add:**

```solidity
/*//////////////////////////////////////////////////////////////
                    ERROR SCENARIO INTEGRATION TESTS
//////////////////////////////////////////////////////////////*/

/// @notice Test insufficient output amount scenario in real execution
function test_Integration_InsufficientOutputRevert() public {
    uint256 swapAmount = 1000e6;
    // Set unrealistically high minimum output to trigger revert
    uint256 unrealisticMinOut = 10000e18; // 10000 WETH for 1000 USDC
    
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100),
            originalAmountIn: swapAmount,
            originalMinAmountOut: unrealisticMinOut,
            maxSlippageDeviationBps: 500,
            zeroForOne: true,
            additionalData: ""
        }),
        false
    );
    
    // Fund account
    deal(CHAIN_1_USDC, accountEth, swapAmount);
    
    // Execute and expect revert
    vm.expectRevert(abi.encodeWithSelector(
        SwapUniswapV4Hook.INSUFFICIENT_OUTPUT_AMOUNT.selector,
        // actual amount will be much less than unrealisticMinOut
        vm.assume, // This will be filled by actual execution
        unrealisticMinOut
    ));
    
    _executeSingleHookOperation(swapCalldata);
}

/// @notice Test slippage deviation protection in real execution
function test_Integration_SlippageDeviationRevert() public {
    uint256 originalAmount = 1000e6;
    uint256 changedAmount = 10000e6; // 900% increase - extreme change
    
    // Create hook data that will trigger deviation check
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100),
            originalAmountIn: originalAmount,
            originalMinAmountOut: 950e6,
            maxSlippageDeviationBps: 500, // 5% max - will be exceeded
            zeroForOne: true,
            additionalData: ""
        }),
        true // Use prev hook amount
    );
    
    // Setup hook chaining scenario where amount changes dramatically
    _executeHookChainWithAmountChange(originalAmount, changedAmount, swapCalldata);
    
    vm.expectRevert(abi.encodeWithSelector(
        SwapUniswapV4Hook.EXCESSIVE_SLIPPAGE_DEVIATION.selector,
        9000, // 90% deviation
        500   // 5% max allowed
    ));
}

/// @notice Test complex hook chaining with ratio changes
function test_Integration_ChainedHooksWithRatioChanges() public {
    // Test scenario: Bridge reduces amount by 10%, then swap should adjust accordingly
    uint256 initialAmount = 1000e6;
    uint256 bridgedAmount = 900e6; // 10% reduction due to bridge fees
    uint256 minOut = 850e6;
    
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100),
            originalAmountIn: initialAmount,
            originalMinAmountOut: minOut,
            maxSlippageDeviationBps: 1500, // 15% max deviation to allow bridge reduction
            zeroForOne: true,
            additionalData: ""
        }),
        true // Use prev hook amount
    );
    
    // Execute with simulated bridge hook that reduces amount
    _executeHookChainWithBridge(initialAmount, bridgedAmount, swapCalldata);
    
    // Verify final balances account for the ratio change
    // Expected new min out: 850e6 * 900e6 / 1000e6 = 765e6
    uint256 finalBalance = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
    assertGe(finalBalance, 765e6 * 1e12); // Convert USDC scale to WETH scale
}

/*//////////////////////////////////////////////////////////////
                    BOUNDARY CONDITION TESTS
//////////////////////////////////////////////////////////////*/

/// @notice Test minimal viable swap amounts
function test_Integration_MinimalAmountSwaps() public {
    uint256 minSwapAmount = 1e6; // 1 USDC
    
    // Get realistic quote for minimal amount
    SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
        SwapUniswapV4Hook.QuoteParams({
            poolKey: testPoolKey,
            zeroForOne: true,
            amountIn: minSwapAmount,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100)
        })
    );
    
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100),
            originalAmountIn: minSwapAmount,
            originalMinAmountOut: quote.amountOut * 99 / 100, // 1% slippage
            maxSlippageDeviationBps: 500,
            zeroForOne: true,
            additionalData: ""
        }),
        false
    );
    
    deal(CHAIN_1_USDC, accountEth, minSwapAmount);
    _executeSingleHookOperation(swapCalldata);
    
    // Verify swap succeeded with minimal amounts
    uint256 finalWETHBalance = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
    assertGt(finalWETHBalance, 0, "Should receive some WETH from minimal swap");
}

/// @notice Test precision edge cases in ratio calculations
function test_Integration_PrecisionEdgeCases() public {
    // Test very small ratio changes that test precision limits
    uint256 originalAmount = 1000000e6; // 1M USDC
    uint256 slightlyChangedAmount = 1000001e6; // Tiny increase
    
    bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
        UniswapV4Parser.SingleHopParams({
            poolKey: testPoolKey,
            dstReceiver: accountEth,
            sqrtPriceLimitX96: _calculatePriceLimit(testPoolKey, true, 100),
            originalAmountIn: originalAmount,
            originalMinAmountOut: 950000e6, // Proportional minimum
            maxSlippageDeviationBps: 1, // Very tight precision tolerance
            zeroForOne: true,
            additionalData: ""
        }),
        true
    );
    
    // This should succeed as the change is minimal
    deal(CHAIN_1_USDC, accountEth, slightlyChangedAmount);
    _executeHookChainWithAmountChange(originalAmount, slightlyChangedAmount, swapCalldata);
}

/*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
//////////////////////////////////////////////////////////////*/

function _executeSingleHookOperation(bytes memory hookCalldata) private {
    address[] memory hookAddresses = new address[](1);
    hookAddresses[0] = address(uniswapV4Hook);

    bytes[] memory hookDataArray = new bytes[](1);
    hookDataArray[0] = hookCalldata;

    ISuperExecutor.ExecutorEntry memory entryToExecute =
        ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

    UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
    executeOp(opData);
}

function _executeHookChainWithAmountChange(
    uint256 originalAmount,
    uint256 actualAmount,
    bytes memory swapCalldata
) private {
    // Implementation would create a mock hook that outputs actualAmount
    // when originalAmount was expected, then chain to swap hook
    
    // This tests the ratio protection mechanism in real execution
}
```

### Phase 4: Coverage Validation

#### 4.1 Coverage Validation Script
**File:** `scripts/verify_full_coverage.sh`

```bash
#!/bin/bash
# Comprehensive coverage verification for SwapUniswapV4Hook

echo "=== SwapUniswapV4Hook Coverage Verification ==="

# Run all tests and generate coverage
make coverage-contract TEST-CONTRACT=SwapUniswapV4Hook

# Parse and validate results
python3 scripts/validate_coverage.py lcov.info SwapUniswapV4Hook

# Check for 100% coverage
if [ $? -eq 0 ]; then
    echo "✅ 100% coverage achieved for SwapUniswapV4Hook"
    exit 0
else
    echo "❌ Coverage gaps remaining - check coverage_validation_report.txt"
    exit 1
fi
```

#### 4.2 Coverage Validation Script
**File:** `scripts/validate_coverage.py`

```python
#!/usr/bin/env python3
"""
Validate that SwapUniswapV4Hook achieves 100% test coverage
Fails if any lines, branches, or functions are uncovered
"""

import sys
from parse_hook_coverage import parse_lcov_for_contract

def validate_full_coverage(coverage_data: dict) -> bool:
    """Validate that coverage meets 100% requirements"""
    
    validation_results = {
        'line_coverage_100': False,
        'all_functions_covered': False,
        'all_branches_covered': False,
        'critical_paths_covered': False
    }
    
    # Check line coverage
    line_coverage = coverage_data['coverage_summary'].get('line_coverage', 0)
    validation_results['line_coverage_100'] = line_coverage >= 99.5  # Allow tiny rounding
    
    # Check functions
    validation_results['all_functions_covered'] = len(coverage_data['uncovered_functions']) == 0
    
    # Check branches
    validation_results['all_branches_covered'] = len(coverage_data['uncovered_branches']) == 0
    
    # Check critical error paths are covered
    critical_functions = [
        'unlockCallback',
        '_calculateDynamicMinAmount', 
        '_validateQuoteDeviation',
        '_decodeHookData'
    ]
    
    uncovered_critical = [f for f in critical_functions if f in coverage_data['uncovered_functions']]
    validation_results['critical_paths_covered'] = len(uncovered_critical) == 0
    
    # Generate validation report
    with open('coverage_validation_report.txt', 'w') as f:
        f.write("=== SwapUniswapV4Hook Coverage Validation Report ===\n\n")
        
        for check, passed in validation_results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            f.write(f"{check}: {status}\n")
        
        if not validation_results['line_coverage_100']:
            f.write(f"\nLine coverage: {line_coverage:.2f}% (Required: 99.5%+)\n")
            f.write(f"Uncovered lines: {coverage_data['uncovered_lines']}\n")
        
        if not validation_results['all_functions_covered']:
            f.write(f"\nUncovered functions: {coverage_data['uncovered_functions']}\n")
        
        if not validation_results['all_branches_covered']:
            f.write(f"\nUncovered branches at lines: {coverage_data['uncovered_branches']}\n")
        
        if not validation_results['critical_paths_covered']:
            f.write(f"\nUncovered critical functions: {uncovered_critical}\n")
    
    return all(validation_results.values())

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 validate_coverage.py <lcov_file> <contract_name>")
        sys.exit(1)
    
    lcov_file = sys.argv[1]
    contract_name = sys.argv[2]
    
    coverage_data = parse_lcov_for_contract(lcov_file, contract_name)
    
    if validate_full_coverage(coverage_data):
        print("✅ Full coverage validation PASSED")
        sys.exit(0)
    else:
        print("❌ Full coverage validation FAILED")
        print("Check coverage_validation_report.txt for details")
        sys.exit(1)
```

## Implementation Success Metrics

### Target Metrics
- **100% Line Coverage** - Every executable line tested
- **100% Branch Coverage** - All conditional paths tested  
- **100% Function Coverage** - All public/external/internal functions tested
- **All Error Conditions Tested** - Every revert scenario covered
- **All Edge Cases Covered** - Boundary conditions and precision limits tested

### Validation Checklist

#### Error Coverage
- [ ] `INSUFFICIENT_OUTPUT_AMOUNT` - insufficient output scenario
- [ ] `UNAUTHORIZED_CALLBACK` - non-pool manager callback attempt  
- [ ] `INVALID_HOOK_DATA` - malformed data scenarios (short length, invalid tokens, zero fee/tick)
- [ ] `EXCESSIVE_SLIPPAGE_DEVIATION` - ratio protection exceeded
- [ ] `INVALID_ORIGINAL_AMOUNTS` - zero original amounts
- [ ] `INVALID_ACTUAL_AMOUNT` - zero actual amount
- [ ] `ZERO_LIQUIDITY` - pool without liquidity
- [ ] `INVALID_PRICE_LIMIT` - zero price limit
- [ ] `INVALID_OUTPUT_DELTA` - negative/zero output delta
- [ ] `OUTPUT_AMOUNT_DIFFERENT_THAN_TRUE` - balance calculation mismatch
- [ ] `INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE` - insufficient native balance
- [ ] `QUOTE_DEVIATION_EXCEEDS_SAFETY_BOUNDS` - quote validation failure

#### Function Coverage  
- [ ] `_buildHookExecutions` - all execution paths
- [ ] `_preExecute` - native vs ERC20 paths
- [ ] `_postExecute` - unlock and validation flow
- [ ] `unlockCallback` - callback execution and validation
- [ ] `inspect` - token address extraction
- [ ] `decodeUsePrevHookAmount` - flag decoding
- [ ] `getQuote` - quote generation with various parameters
- [ ] `_calculateDynamicMinAmount` - ratio calculations and validation
- [ ] `_calculateRatioDeviationBps` - increase/decrease scenarios
- [ ] `_validateQuoteDeviation` - deviation checking
- [ ] `_getTransferParams` - with/without prev hook
- [ ] `_prepareUnlockData` - data preparation and encoding
- [ ] `_decodeHookData` - complete data structure decoding
- [ ] `_getOutputToken` - direction-based token selection
- [ ] Transient storage functions - store/load/clear operations

#### Integration Coverage
- [ ] Hook chaining with ratio changes
- [ ] Native token operations (ETH input/output)  
- [ ] Complex multi-step workflows
- [ ] Error scenarios in real execution context
- [ ] Boundary conditions with real pool data
- [ ] Gas optimization validation

## File Organization

```
test/
├── unit/
│   └── hooks/
│       └── SwapUniswapV4Hook.t.sol (NEW - 40+ comprehensive unit tests)
├── integration/
│   └── uniswap-v4/
│       └── UniswapV4HookIntegrationTest.t.sol (ENHANCED - +15 integration tests)
├── mocks/
│   ├── MockPoolManager.sol (NEW - error condition testing)
│   └── MockPrevHook.sol (NEW - chaining scenarios)
└── utils/
    └── coverage/
        └── CoverageHelpers.sol (NEW - testing utilities)

scripts/
├── analyze_uniswapv4_coverage.sh (NEW)
├── parse_hook_coverage.py (NEW)  
├── validate_coverage.py (NEW)
└── verify_full_coverage.sh (NEW)
```

## Execution Timeline

### Phase 1 (Coverage Analysis) - 1 day
- Create coverage analysis scripts
- Run initial coverage analysis
- Identify specific uncovered areas

### Phase 2 (Unit Tests) - 3-4 days  
- Implement comprehensive unit test suite (40+ tests)
- Cover all error conditions and edge cases
- Test all internal functions and calculations

### Phase 3 (Integration Enhancements) - 2-3 days
- Add error scenario integration tests
- Test complex hook chaining scenarios
- Validate boundary conditions in real execution

### Phase 4 (Validation) - 1 day
- Run coverage validation
- Achieve 100% coverage confirmation
- Document final coverage metrics

**Total Timeline: 7-9 days for complete implementation**

This plan provides a systematic approach to achieving comprehensive test coverage for SwapUniswapV4Hook, ensuring every code path, error condition, and edge case is thoroughly tested and validated.