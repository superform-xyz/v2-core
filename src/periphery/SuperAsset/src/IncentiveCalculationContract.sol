// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title IncentiveCalculationContract
 * @notice A stateless contract for calculating incentives.
 */
contract IncentiveCalculationContract {
    using Math for uint256;

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant PERC = 100e18;

    // --- View Functions ---
    /**
     * @notice Calculates the energy function.
     * @param currentAllocation The current allocation.
     * @param totalCurrentAllocation The total current allocation.
     * @param allocationTarget The target allocation.
     * @param totalAllocationTarget The total target allocation.
     * @param weights The weights for each allocation in the energy calculation.
     * @return energy The calculated energy.
     */
    function energy(
        uint256[] memory currentAllocation,
        uint256 totalCurrentAllocation,
        uint256[] memory allocationTarget,
        uint256 totalAllocationTarget,
        uint256[] memory weights
    ) public pure returns (uint256 res) {
        require(currentAllocation.length == allocationTarget.length &&
        currentAllocation.length == weights.length,
            "ICC: Input arrays must have the same length");

        uint256 length = currentAllocation.length;
        uint256 i;
        for (; i < length; i++) {
            //  Safe subtraction to avoid underflow
            // Calculate Percentage just in time
            int256 _currentAllocation = Math.mulDiv(currentAllocation[i], PERC, totalCurrentAllocation);
            // Calculate Percentage just in time
            int256 _targetAllocation = Math.mulDiv(allocationTarget[i], PERC, totalAllocationTarget);
            int256 diff = _currentAllocation - _targetAllocation;
            uint256 diff2 = uint256(diff * diff);
            res += (diff2 * weights[i]); // Simplified square
        }
        return res;
    }

    /**
     * @notice Calculates the incentive.
     * @param allocationPreOperation The allocation before the operation.
     * @param totalAllocationPreOperation The total allocation before the operation.
     * @param allocationPostOperation The allocation after the operation.
     * @param totalAllocationPostOperation The total allocation after the operation.
     * @param allocationTarget The target allocation.
     * @param totalAllocationTarget The total target allocation.
     * @param weights The weights for each allocation in the energy calculation.
     * @param energyToUSDExchangeRatio The ratio to convert energy units to USD (scaled by PRECISION).
     * @return incentiveUSD The calculated incentive in USD (scaled by PRECISION).
     */
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256 totalAllocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256 totalAllocationPostOperation,
        uint256[] memory allocationTarget,
        uint256 totalAllocationTarget,
        uint256[] memory weights,
        uint256 energyToUSDExchangeRatio
    ) public view returns (int256 incentiveUSD) {
        require(allocationPreOperation.length == allocationPostOperation.length &&
        allocationPreOperation.length == allocationTarget.length,
            "ICC: Input arrays must have the same length");

        uint256 energyBefore = energy(allocationPreOperation, totalAllocationPreOperation, allocationTarget, totalAllocationTarget, weights);
        uint256 energyAfter = energy(allocationPostOperation, totalAllocationPostOperation, allocationTarget, totalAllocationTarget, weights);
        
        // Calculate energy difference first
        int256 energyDiff = int256(energyBefore) - int256(energyAfter);
        
        // Handle positive and negative cases separately for safe multiplication
        if (energyDiff >= 0) {
            incentiveUSD = int256(Math.mulDiv(uint256(energyDiff), energyToUSDExchangeRatio, PRECISION));
        } else {
            incentiveUSD = -int256(Math.mulDiv(uint256(-energyDiff), energyToUSDExchangeRatio, PRECISION));
        }
    }
}
