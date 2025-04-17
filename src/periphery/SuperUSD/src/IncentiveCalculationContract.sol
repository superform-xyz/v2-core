// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/**
 * @title Incentive Calculation Contract (ICC)
 * @notice A stateless contract for calculating incentives.
 */
contract IncentiveCalculationContract {
    // --- View Functions ---

    /**
     * @notice Calculates the energy function.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each asset.
     * @return energy The calculated energy.
     */
    function energy(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationTarget,
        uint256[]memory weights
    ) public pure returns (uint256 energy) {
        require(allocationPreOperation.length == allocationTarget.length &&
        allocationPreOperation.length == weights.length,
            "ICC: Input arrays must have the same length");

        for (uint256 i = 0; i < allocationPreOperation.length; i++) {
            //  Safe subtraction to avoid underflow
            uint256 diff;
            if (allocationPreOperation[i] > allocationTarget[i]) {
                diff = allocationPreOperation[i] - allocationTarget[i];
            } else {
                diff = allocationTarget[i] - allocationPreOperation[i];
            }
            energy += (diff * diff * weights[i]); // Simplified square
        }
    }

    /**
     * @notice Calculates the incentive.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationPostOperation The allocation after the operation.
     * @param allocationTarget The target allocation.
     * @return incentive The calculated incentive.
     */
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget
    ) public view returns (uint256 incentive) {
        require(allocationPreOperation.length == allocationPostOperation.length &&
        allocationPreOperation.length == allocationTarget.length,
            "ICC: Input arrays must have the same length");
        // Example weights (replace with actual weights)
        uint256[] memory weights = new uint256[](allocationPreOperation.length);
        for(uint i = 0; i < weights.length; i++){
            weights[i] = 1; // default weight
        }

        uint256 energyBefore = energy(allocationPreOperation, allocationTarget, weights);
        uint256 energyAfter = energy(allocationPostOperation, allocationTarget, weights);
        //  Simplified incentive calculation (replace with actual calculation)
        incentive = (energyBefore > energyAfter) ? (energyBefore - energyAfter) : 0;
        incentive = (incentive * 10) / 100; // Example: 10% of the energy difference
    }
}


