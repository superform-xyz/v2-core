// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";

/**
 * @author Superform Labs
 * @title IncentiveCalculationContract
 * @notice A stateless contract for calculating incentives.
 */
contract IncentiveCalculationContract is IIncentiveCalculationContract {
    using Math for uint256;

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant PERC = 100e18;

    // --- View Functions ---
    /// @inheritdoc IIncentiveCalculationContract
    function energy(
        uint256[] memory currentAllocation,
        uint256[] memory allocationTarget,
        uint256[] memory weights,
        uint256 totalCurrentAllocation,
        uint256 totalAllocationTarget
    ) public pure returns (uint256 res) {
        if (currentAllocation.length != allocationTarget.length || currentAllocation.length != weights.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        uint256 length = currentAllocation.length;
        for (uint256 i; i < length; i++) {
            uint256 _currentAllocation = Math.mulDiv(currentAllocation[i], PERC, totalCurrentAllocation);
            uint256 _targetAllocation = Math.mulDiv(allocationTarget[i], PERC, totalAllocationTarget);
            int256 diff = int256(_currentAllocation) - int256(_targetAllocation);
            // Square the difference and maintain precision
            uint256 diff2 = Math.mulDiv(uint256(diff * diff), 1, PRECISION);
            // Apply weight and maintain precision
            res += Math.mulDiv(diff2, weights[i], PRECISION);
        }
        return res;
    }

    /// @inheritdoc IIncentiveCalculationContract
    function calculateIncentive(
        uint256[] memory allocationPreOperation,
        uint256[] memory allocationPostOperation,
        uint256[] memory allocationTarget,
        uint256[] memory weights,
        uint256 totalAllocationPreOperation,
        uint256 totalAllocationPostOperation,
        uint256 totalAllocationTarget,
        uint256 energyToUSDExchangeRatio
    ) public pure returns (int256 incentiveUSD) {
        if (allocationPreOperation.length != allocationPostOperation.length || allocationPreOperation.length != allocationTarget.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        uint256 energyBefore = energy(
            allocationPreOperation, 
            allocationTarget, 
            weights,
            totalAllocationPreOperation, 
            totalAllocationTarget
            );
        uint256 energyAfter = energy(
            allocationPostOperation, 
            allocationTarget, 
            weights,
            totalAllocationPostOperation, 
            totalAllocationTarget
            );
        
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
