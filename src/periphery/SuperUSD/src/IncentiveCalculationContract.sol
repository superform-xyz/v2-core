// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


/**
 * @title Incentive Calculation Contract (ICC)
 * @notice A stateless contract for calculating incentives.
 */
contract IncentiveCalculationContract {
    // --- View Functions ---

    // Add a constant equal to 10^6
    uint256 public constant PERC = 10**6; // TODO: Add this to SuperOracle

    /**
     * @notice Calculates the energy function.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each asset.
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

        for (uint256 i = 0; i < currentAllocation.length; i++) {
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
     * @notice Calculates the energy given the SuperUSD Contract, without the need to pass a bunch of parameters that could also change over time as we experiment with the energy function
     * @param SuperUSD The address of the SuperUSD contract.
     * @return energy The calculated energy.
     */
    function energy(address SuperUSD) {

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
        uint256 totalAllocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256 totalAllocationPostOperation,
        uint256[] memory allocationTarget,
        uint256 totalAllocationTarget,
        uint256[] memory weights,
        uint256 energyToTokenExchangeRatio
    ) public view returns (int256 incentive) {
        require(allocationPreOperation.length == allocationPostOperation.length &&
        allocationPreOperation.length == allocationTarget.length,
            "ICC: Input arrays must have the same length");
//        // Example weights (replace with actual weights)
//        uint256[] memory weights = new uint256[](allocationPreOperation.length);
//        for(uint i = 0; i < weights.length; i++){
//            weights[i] = 1; // default weight
//        }

        uint256 energyBefore = energy(allocationPreOperation, totalAllocationPreOperation, allocationTarget, totalAllocationTarget, weights);
        uint256 energyAfter = energy(allocationPostOperation, totalAllocationPostOperation, allocationTarget, totalAllocationTarget, weights);
        //  Positive incentive means the user earns the incentive
        incentive = int256(energyToTokenExchangeRatio) * (int256(energyBefore) - int256(energyAfter));
    }
}


