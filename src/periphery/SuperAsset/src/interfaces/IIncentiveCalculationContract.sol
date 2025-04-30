// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IIncentiveCalculationContract {
    /**
     * @notice Calculates the energy function.
     * @param currentAllocation The allocation before the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each asset.
     * @return res The calculated energy.
     */
    function energy(
        uint256[] memory currentAllocation,
        uint256[] memory allocationTarget,
        uint256[] memory weights
    ) external pure returns (uint256 res);

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
    ) external view returns (int256 incentiveUSD);
}
