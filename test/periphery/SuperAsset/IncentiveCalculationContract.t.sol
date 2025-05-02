// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IncentiveCalculationContract} from "../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import {IIncentiveCalculationContract} from "../../../src/periphery/interfaces/SuperAsset/IIncentiveCalculationContract.sol";

contract IncentiveCalculationContractTest is Test {
    IncentiveCalculationContract public calculator;
    uint256 constant PRECISION = 1e18;
    uint256 constant PERC = 100e18;

    function setUp() public {
        calculator = new IncentiveCalculationContract();
    }

    function test_Energy_NormalCase() public {
        uint256[] memory currentAllocation = new uint256[](3);
        currentAllocation[0] = 300e18; // 30%
        currentAllocation[1] = 500e18; // 50%
        currentAllocation[2] = 200e18; // 20%

        uint256[] memory allocationTarget = new uint256[](3);
        allocationTarget[0] = 400e18; // 40%
        allocationTarget[1] = 400e18; // 40%
        allocationTarget[2] = 200e18; // 20%

        uint256[] memory weights = new uint256[](3);
        weights[0] = PRECISION;
        weights[1] = PRECISION;
        weights[2] = PRECISION;

        uint256 totalCurrentAllocation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;

        uint256 energy = calculator.energy(
            currentAllocation,
            allocationTarget,
            weights,
            totalCurrentAllocation,
            totalAllocationTarget
        );

        // Expected result:
        // (30-40)^2 * 1 + (50-40)^2 * 1 + (20-20)^2 * 1 = 200 * PRECISION
        assertEq(energy, 200 * PRECISION);
    }

    function test_Energy_ZeroAllocations() public {
        uint256[] memory currentAllocation = new uint256[](2);
        currentAllocation[0] = 0;
        currentAllocation[1] = 0;

        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 0;
        allocationTarget[1] = 0;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 energy = calculator.energy(
            currentAllocation,
            allocationTarget,
            weights,
            1, // Avoid division by zero by using 1 as total when actual total is 0
            1
        );

        assertEq(energy, 0);
    }

    function test_Energy_RevertOnMismatchedLengths() public {
        uint256[] memory currentAllocation = new uint256[](2);
        uint256[] memory allocationTarget = new uint256[](3);
        uint256[] memory weights = new uint256[](2);

        vm.expectRevert(IIncentiveCalculationContract.INVALID_ARRAY_LENGTH.selector);
        calculator.energy(
            currentAllocation,
            allocationTarget,
            weights,
            1000e18,
            1000e18
        );
    }

    function test_Energy_DifferentWeights() public {
        uint256[] memory currentAllocation = new uint256[](2);
        currentAllocation[0] = 600e18; // 60%
        currentAllocation[1] = 400e18; // 40%

        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18; // 50%
        allocationTarget[1] = 500e18; // 50%

        uint256[] memory weights = new uint256[](2);
        weights[0] = 2 * PRECISION; // Higher weight
        weights[1] = PRECISION;

        uint256 totalCurrentAllocation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;

        uint256 energy = calculator.energy(
            currentAllocation,
            allocationTarget,
            weights,
            totalCurrentAllocation,
            totalAllocationTarget
        );

        // Expected result:
        // (60-50)^2 * 2 + (40-50)^2 * 1 = 300 * PRECISION
        assertEq(energy, 300 * PRECISION);
    }

    function test_CalculateIncentive_PositiveCase() public {
        // Initial state: 60-40 split
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 600e18;
        allocationPreOperation[1] = 400e18;

        // Final state: 50-50 split (closer to target)
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 500e18;
        allocationPostOperation[1] = 500e18;

        // Target state: 50-50 split
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = 2 * PRECISION; // 2 USD per energy unit

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Pre-operation energy: (60-50)^2 + (40-50)^2 = 200
        // Post-operation energy: (50-50)^2 + (50-50)^2 = 0
        // Energy difference: 200
        // Incentive: 200 * 2 = 400 USD
        assertEq(incentive, 400 * int256(PRECISION));
    }

    function test_CalculateIncentive_NegativeCase() public {
        // Initial state: 50-50 split (at target)
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 500e18;
        allocationPreOperation[1] = 500e18;

        // Final state: 60-40 split (away from target)
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 600e18;
        allocationPostOperation[1] = 400e18;

        // Target state: 50-50 split
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = 2 * PRECISION; // 2 USD per energy unit

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Pre-operation energy: (50-50)^2 + (50-50)^2 = 0
        // Post-operation energy: (60-50)^2 + (40-50)^2 = 200
        // Energy difference: -200
        // Incentive: -200 * 2 = -400 USD
        assertEq(incentive, -400 * int256(PRECISION));
    }

    function test_CalculateIncentive_NoChange() public {
        // Both pre and post states: 60-40 split
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 600e18;
        allocationPreOperation[1] = 400e18;

        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 600e18;
        allocationPostOperation[1] = 400e18;

        // Target state: 50-50 split
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = 2 * PRECISION;

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Pre-operation energy equals post-operation energy
        // Energy difference: 0
        // Incentive: 0 USD
        assertEq(incentive, 0);
    }

    function test_CalculateIncentive_RevertOnMismatchedLengths() public {
        uint256[] memory allocationPreOperation = new uint256[](2);
        uint256[] memory allocationPostOperation = new uint256[](3);
        uint256[] memory allocationTarget = new uint256[](2);
        uint256[] memory weights = new uint256[](2);

        vm.expectRevert(IIncentiveCalculationContract.INVALID_ARRAY_LENGTH.selector);
        calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            1000e18,
            1000e18,
            1000e18,
            PRECISION
        );
    }

    function test_CalculateIncentive_DifferentWeights() public {
        // Initial state: 60-40 split
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 600e18;
        allocationPreOperation[1] = 400e18;

        // Final state: 50-50 split (closer to target)
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 500e18;
        allocationPostOperation[1] = 500e18;

        // Target state: 50-50 split
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 2 * PRECISION; // Higher weight for first asset
        weights[1] = PRECISION;     // Normal weight for second asset

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = PRECISION; // 1 USD per energy unit

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Pre-operation energy: (60-50)^2 * 2 + (40-50)^2 * 1 = 300
        // Post-operation energy: (50-50)^2 * 2 + (50-50)^2 * 1 = 0
        // Energy difference: 300
        // Incentive: 300 * 1 = 300 USD
        assertEq(incentive, 300 * int256(PRECISION));
    }

    function test_CalculateIncentive_DifferentTotalAllocations() public {
        // Initial state: total = 1000, 60-40 split
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 600e18;
        allocationPreOperation[1] = 400e18;

        // Final state: total = 2000, still 60-40 split but doubled
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 1200e18;
        allocationPostOperation[1] = 800e18;

        // Target state: 50-50 split with total 1000
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 2000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = PRECISION;

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Energy should be the same before and after since percentages didn't change
        assertEq(incentive, 0);
    }

    function test_CalculateIncentive_SmallChange() public {
        // Initial state: Slightly off 50-50
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 501e18;
        allocationPreOperation[1] = 499e18;

        // Final state: Perfect 50-50
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 500e18;
        allocationPostOperation[1] = 500e18;

        // Target state: 50-50
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = PRECISION;

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Small positive incentive since we improved slightly
        assertTrue(incentive > 0);
        // The incentive should be very small given the tiny improvement
        assertTrue(incentive < int256(PRECISION)); // Less than 1 USD
    }

    function test_CalculateIncentive_LargeValues() public {
        // Initial state: Far from target with large values
        uint256[] memory allocationPreOperation = new uint256[](2);
        allocationPreOperation[0] = 900e18;
        allocationPreOperation[1] = 100e18;

        // Final state: Much closer to target
        uint256[] memory allocationPostOperation = new uint256[](2);
        allocationPostOperation[0] = 550e18;
        allocationPostOperation[1] = 450e18;

        // Target state: 50-50
        uint256[] memory allocationTarget = new uint256[](2);
        allocationTarget[0] = 500e18;
        allocationTarget[1] = 500e18;

        uint256[] memory weights = new uint256[](2);
        weights[0] = PRECISION;
        weights[1] = PRECISION;

        uint256 totalAllocationPreOperation = 1000e18;
        uint256 totalAllocationPostOperation = 1000e18;
        uint256 totalAllocationTarget = 1000e18;
        uint256 energyToUSDExchangeRatio = PRECISION;

        int256 incentive = calculator.calculateIncentive(
            allocationPreOperation,
            allocationPostOperation,
            allocationTarget,
            weights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );

        // Pre-operation energy: (90-50)^2 + (10-50)^2 = 1600 + 1600 = 3200
        // Post-operation energy: (55-50)^2 + (45-50)^2 = 25 + 25 = 50
        // Energy difference: 3150
        // Incentive: 3150 USD
        assertEq(incentive, 3150 * int256(PRECISION));
    }
}
