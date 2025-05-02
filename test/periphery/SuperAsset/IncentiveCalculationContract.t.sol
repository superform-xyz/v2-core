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
}
