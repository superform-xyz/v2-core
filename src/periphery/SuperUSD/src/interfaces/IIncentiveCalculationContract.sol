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
     * @param allocationPostOperation The allocation after the operation.
     * @param allocationTarget The target allocation.
     * @param weights The weights for each asset.
     * @param energyToTokenExchangeRatio The ratio for energy to token exchange.
     * @return incentive The calculated incentive.
     */
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget,
        uint256[] memory weights,
        uint256 energyToTokenExchangeRatio
    ) external view returns (int256 incentive);
}
