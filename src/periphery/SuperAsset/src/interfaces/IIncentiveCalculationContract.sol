// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IIncentiveCalculationContract {
    /**
     * @notice Calculates the energy function.
     * @param currentAllocation The current allocation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each allocation in the energy calculation.
     * @param totalCurrentAllocation The total current allocation.
     * @param totalAllocationTarget The total target allocation.
     * @return res The calculated energy value.
     */
    function energy(
        uint256[] memory currentAllocation,
        uint256[] memory allocationTarget,
        uint256[] memory weights,
        uint256 totalCurrentAllocation,
        uint256 totalAllocationTarget
    ) external pure returns (uint256 res);

    /**
     * @notice Calculates the incentive.
     * @param allocationPreOperation The allocation before the operation.
     * @param allocationPostOperation The allocation after the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each allocation in the energy calculation.
     * @param totalAllocationPreOperation The total allocation before the operation.
     * @param totalAllocationPostOperation The total allocation after the operation.
     * @param totalAllocationTarget The total target allocation.
     * @param energyToUSDExchangeRatio The ratio to convert energy units to USD (scaled by PRECISION).
     * @return incentiveUSD The calculated incentive in USD (scaled by PRECISION).
     */
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget,
        uint256[] memory weights,
        uint256 totalAllocationPreOperation,
        uint256 totalAllocationPostOperation,
        uint256 totalAllocationTarget,
        uint256 energyToUSDExchangeRatio
    ) external pure returns (int256 incentiveUSD);
}
