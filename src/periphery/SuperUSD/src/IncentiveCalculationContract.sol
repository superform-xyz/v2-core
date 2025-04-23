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
        uint256[] memory currentAllocation,
        uint256[] memory allocationTarget,
        uint256[] memory weights
    ) public pure returns (uint256 res) {
        require(currentAllocation.length == allocationTarget.length &&
        currentAllocation.length == weights.length,
            "ICC: Input arrays must have the same length");

        for (uint256 i = 0; i < currentAllocation.length; i++) {
            //  Safe subtraction to avoid underflow
            int256 diff = int256(currentAllocation[i]) - int256(allocationTarget[i]);
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
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget,
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

        uint256 energyBefore = energy(allocationPreOperation, allocationTarget, weights);
        uint256 energyAfter = energy(allocationPostOperation, allocationTarget, weights);
        //  Positive incentive means the user earns the incentive
        incentive = int256(energyToTokenExchangeRatio) * (int256(energyBefore) - int256(energyAfter));
    }
}


