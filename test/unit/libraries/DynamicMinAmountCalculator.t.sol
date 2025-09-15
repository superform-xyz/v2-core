// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Testing framework
import { Test } from "forge-std/Test.sol";

// Library under test
import { DynamicMinAmountCalculator } from "../../../src/libraries/uniswap-v4/DynamicMinAmountCalculator.sol";

/// @title DynamicMinAmountCalculatorTest
/// @author Superform Labs
/// @notice Comprehensive unit tests for DynamicMinAmountCalculator library
/// @dev Tests all functions including edge cases and error conditions
contract DynamicMinAmountCalculatorTest is Test {
    using DynamicMinAmountCalculator for DynamicMinAmountCalculator.RecalculationParams;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant BASE_AMOUNT_IN = 1_000_000; // 1 USDC
    uint256 private constant BASE_MIN_AMOUNT_OUT = 500_000; // 0.5 USDC worth of WETH
    uint256 private constant DEFAULT_MAX_DEVIATION_BPS = 100; // 1%

    /*//////////////////////////////////////////////////////////////
                            BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_calculateDynamicMinAmount_ProportionalIncrease() external {
        // Test: 20% increase in amount should result in 20% increase in minAmountOut
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 1_200_000, // 20% increase
            maxSlippageDeviationBps: 2000 // 20% max allowed deviation
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        // Expected: 500_000 * (1_200_000 / 1_000_000) = 600_000
        assertEq(result, 600_000, "Should calculate proportional increase correctly");
    }

    function test_calculateDynamicMinAmount_ProportionalDecrease() external {
        // Test: 25% decrease in amount should result in 25% decrease in minAmountOut
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 750_000, // 25% decrease
            maxSlippageDeviationBps: 2500 // 25% max allowed deviation
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        // Expected: 500_000 * (750_000 / 1_000_000) = 375_000
        assertEq(result, 375_000, "Should calculate proportional decrease correctly");
    }

    function test_calculateDynamicMinAmount_NoChange() external {
        // Test: No change in amount should result in no change in minAmountOut
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: BASE_AMOUNT_IN, // No change
            maxSlippageDeviationBps: DEFAULT_MAX_DEVIATION_BPS
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        assertEq(result, BASE_MIN_AMOUNT_OUT, "Should return original minAmountOut when no change");
    }

    /*//////////////////////////////////////////////////////////////
                            DEVIATION PROTECTION
    //////////////////////////////////////////////////////////////*/

    function test_calculateDynamicMinAmount_ExcessiveIncreaseReverts() external {
        // Test: Large increase beyond allowed deviation should revert
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 1_500_000, // 50% increase
            maxSlippageDeviationBps: 100 // Only 1% max allowed deviation
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                DynamicMinAmountCalculator.ExcessiveSlippageDeviation.selector,
                5000, // 50% actual deviation in bps
                100   // 1% max allowed in bps
            )
        );

        DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
    }

    function test_calculateDynamicMinAmount_ExcessiveDecreaseReverts() external {
        // Test: Large decrease beyond allowed deviation should revert
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 500_000, // 50% decrease
            maxSlippageDeviationBps: 100 // Only 1% max allowed deviation
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                DynamicMinAmountCalculator.ExcessiveSlippageDeviation.selector,
                5000, // 50% actual deviation in bps
                100   // 1% max allowed in bps
            )
        );

        DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
    }

    function test_calculateDynamicMinAmount_EdgeCaseMaxDeviation() external {
        // Test: Amount change exactly at max deviation boundary should succeed
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 1_010_000, // Exactly 1% increase
            maxSlippageDeviationBps: 100 // 1% max allowed deviation
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        // Expected: 500_000 * (1_010_000 / 1_000_000) = 505_000
        assertEq(result, 505_000, "Should succeed at exact deviation boundary");
    }

    /*//////////////////////////////////////////////////////////////
                                ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_calculateDynamicMinAmount_ZeroOriginalAmountIn() external {
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: 0, // Invalid
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: BASE_AMOUNT_IN,
            maxSlippageDeviationBps: DEFAULT_MAX_DEVIATION_BPS
        });

        vm.expectRevert(DynamicMinAmountCalculator.InvalidOriginalAmounts.selector);
        DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
    }

    function test_calculateDynamicMinAmount_ZeroOriginalMinAmountOut() external {
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: 0, // Invalid
            actualAmountIn: BASE_AMOUNT_IN,
            maxSlippageDeviationBps: DEFAULT_MAX_DEVIATION_BPS
        });

        vm.expectRevert(DynamicMinAmountCalculator.InvalidOriginalAmounts.selector);
        DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
    }

    function test_calculateDynamicMinAmount_ZeroActualAmountIn() external {
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: BASE_AMOUNT_IN,
            originalMinAmountOut: BASE_MIN_AMOUNT_OUT,
            actualAmountIn: 0, // Invalid
            maxSlippageDeviationBps: DEFAULT_MAX_DEVIATION_BPS
        });

        vm.expectRevert(DynamicMinAmountCalculator.InvalidActualAmount.selector);
        DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION HELPER
    //////////////////////////////////////////////////////////////*/

    function test_validateRatioChange_ValidIncrease() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            BASE_AMOUNT_IN,
            1_050_000, // 5% increase
            500 // 5% max allowed
        );

        assertTrue(result, "Should validate acceptable ratio increase");
    }

    function test_validateRatioChange_ValidDecrease() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            BASE_AMOUNT_IN,
            950_000, // 5% decrease
            500 // 5% max allowed
        );

        assertTrue(result, "Should validate acceptable ratio decrease");
    }

    function test_validateRatioChange_InvalidIncrease() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            BASE_AMOUNT_IN,
            1_100_000, // 10% increase
            500 // Only 5% max allowed
        );

        assertFalse(result, "Should reject excessive ratio increase");
    }

    function test_validateRatioChange_InvalidDecrease() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            BASE_AMOUNT_IN,
            900_000, // 10% decrease
            500 // Only 5% max allowed
        );

        assertFalse(result, "Should reject excessive ratio decrease");
    }

    function test_validateRatioChange_ZeroOriginalAmount() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            0, // Invalid
            BASE_AMOUNT_IN,
            DEFAULT_MAX_DEVIATION_BPS
        );

        assertFalse(result, "Should return false for zero original amount");
    }

    function test_validateRatioChange_ZeroActualAmount() external {
        bool result = DynamicMinAmountCalculator.validateRatioChange(
            BASE_AMOUNT_IN,
            0, // Invalid
            DEFAULT_MAX_DEVIATION_BPS
        );

        assertFalse(result, "Should return false for zero actual amount");
    }

    /*//////////////////////////////////////////////////////////////
                            ESTIMATION HELPER
    //////////////////////////////////////////////////////////////*/

    function test_getExpectedMinAmountOut_ProportionalCalculation() external {
        uint256 result = DynamicMinAmountCalculator.getExpectedMinAmountOut(
            BASE_AMOUNT_IN,
            BASE_MIN_AMOUNT_OUT,
            1_300_000 // 30% increase
        );

        // Expected: 500_000 * (1_300_000 / 1_000_000) = 650_000
        assertEq(result, 650_000, "Should calculate expected output proportionally");
    }

    function test_getExpectedMinAmountOut_ZeroOriginalAmount() external {
        uint256 result = DynamicMinAmountCalculator.getExpectedMinAmountOut(
            0, // Zero original
            BASE_MIN_AMOUNT_OUT,
            BASE_AMOUNT_IN
        );

        assertEq(result, 0, "Should return zero for zero original amount");
    }

    /*//////////////////////////////////////////////////////////////
                            RATIO DEVIATION
    //////////////////////////////////////////////////////////////*/

    function test_getRatioDeviationBps_NoDeviation() external {
        uint256 deviation = DynamicMinAmountCalculator.getRatioDeviationBps(1e18); // 1:1 ratio
        assertEq(deviation, 0, "Should return zero deviation for 1:1 ratio");
    }

    function test_getRatioDeviationBps_PositiveDeviation() external {
        uint256 deviation = DynamicMinAmountCalculator.getRatioDeviationBps(1.1e18); // 10% increase
        assertEq(deviation, 1000, "Should return 1000 bps for 10% increase");
    }

    function test_getRatioDeviationBps_NegativeDeviation() external {
        uint256 deviation = DynamicMinAmountCalculator.getRatioDeviationBps(0.9e18); // 10% decrease
        assertEq(deviation, 1000, "Should return 1000 bps for 10% decrease");
    }

    function test_getRatioDeviationBps_LargePositiveDeviation() external {
        uint256 deviation = DynamicMinAmountCalculator.getRatioDeviationBps(2e18); // 100% increase
        assertEq(deviation, 10000, "Should return 10000 bps for 100% increase");
    }

    function test_getRatioDeviationBps_LargeNegativeDeviation() external {
        uint256 deviation = DynamicMinAmountCalculator.getRatioDeviationBps(0.5e18); // 50% decrease
        assertEq(deviation, 5000, "Should return 5000 bps for 50% decrease");
    }

    /*//////////////////////////////////////////////////////////////
                            PRECISION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_calculateDynamicMinAmount_HighPrecision() external {
        // Test with very small amounts to ensure precision
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: 1000, // Very small amount
            originalMinAmountOut: 999,
            actualAmountIn: 1001, // Tiny increase
            maxSlippageDeviationBps: 1000 // 10% max allowed
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        // Expected: 999 * (1001 / 1000) = 999.999... rounded to 999
        assertEq(result, 999, "Should handle high precision calculations");
    }

    function test_calculateDynamicMinAmount_VeryLargeAmounts() external {
        // Test with very large amounts
        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: 1e24, // Very large amount
            originalMinAmountOut: 5e23,
            actualAmountIn: 11e23, // 10% increase
            maxSlippageDeviationBps: 1000 // 10% max allowed
        });

        uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);

        // Expected: 5e23 * (11e23 / 1e24) = 5.5e23
        assertEq(result, 55e22, "Should handle very large amounts");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_calculateDynamicMinAmount_ValidInputs(
        uint256 originalAmountIn,
        uint256 originalMinAmountOut,
        uint256 actualAmountIn,
        uint256 maxDeviationBps
    ) external {
        // Bound inputs to reasonable ranges
        originalAmountIn = bound(originalAmountIn, 1, 1e30);
        originalMinAmountOut = bound(originalMinAmountOut, 1, 1e30);
        actualAmountIn = bound(actualAmountIn, 1, 1e30);
        maxDeviationBps = bound(maxDeviationBps, 0, 10000); // 0-100%

        // Calculate expected ratio deviation
        uint256 ratio = (actualAmountIn * 1e18) / originalAmountIn;
        uint256 expectedDeviation;
        if (ratio > 1e18) {
            expectedDeviation = ((ratio - 1e18) * 10000) / 1e18;
        } else {
            expectedDeviation = ((1e18 - ratio) * 10000) / 1e18;
        }

        DynamicMinAmountCalculator.RecalculationParams memory params = DynamicMinAmountCalculator.RecalculationParams({
            originalAmountIn: originalAmountIn,
            originalMinAmountOut: originalMinAmountOut,
            actualAmountIn: actualAmountIn,
            maxSlippageDeviationBps: maxDeviationBps
        });

        if (expectedDeviation <= maxDeviationBps) {
            // Should succeed
            uint256 result = DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
            
            // Verify proportional calculation
            uint256 expected = (originalMinAmountOut * actualAmountIn) / originalAmountIn;
            assertEq(result, expected, "Should calculate proportionally");
        } else {
            // Should revert
            vm.expectRevert(
                abi.encodeWithSelector(
                    DynamicMinAmountCalculator.ExcessiveSlippageDeviation.selector,
                    expectedDeviation,
                    maxDeviationBps
                )
            );
            DynamicMinAmountCalculator.calculateDynamicMinAmount(params);
        }
    }

    function testFuzz_validateRatioChange(
        uint256 originalAmount,
        uint256 actualAmount,
        uint256 maxDeviationBps
    ) external {
        // Bound inputs to reasonable ranges
        originalAmount = bound(originalAmount, 1, 1e30);
        actualAmount = bound(actualAmount, 1, 1e30);
        maxDeviationBps = bound(maxDeviationBps, 0, 10000);

        bool result = DynamicMinAmountCalculator.validateRatioChange(
            originalAmount,
            actualAmount,
            maxDeviationBps
        );

        // Calculate expected deviation
        uint256 ratio = (actualAmount * 1e18) / originalAmount;
        uint256 deviation = ratio > 1e18
            ? ((ratio - 1e18) * 10000) / 1e18
            : ((1e18 - ratio) * 10000) / 1e18;

        assertEq(result, deviation <= maxDeviationBps, "Validation should match manual calculation");
    }
}