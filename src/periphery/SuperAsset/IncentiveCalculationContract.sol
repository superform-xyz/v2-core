// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IIncentiveCalculationContract } from "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import { console } from "forge-std/console.sol";


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
    ) public pure returns (uint256 res, bool isSuccess) {
        if (currentAllocation.length != allocationTarget.length || currentAllocation.length != weights.length) {
            // NOTE: This is a really corner a case that should never happen, this is why we let it revert even though in general we do not allow view and pure functions to revert. 
            revert INVALID_ARRAY_LENGTH();
        }

        // NOTE: This is to ensure we won't divide by zero in the subsequent calculations
        if(totalCurrentAllocation == 0 || totalAllocationTarget == 0) {
            return (0, false);
        }

        console.log("Energy() totalCurrentAllocation = ", totalCurrentAllocation);
        console.log("Energy() totalAllocationTarget = ", totalAllocationTarget);

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
        return (res, true);
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
    ) public pure returns (int256 incentiveUSD, bool isSuccess) {
        if (allocationPreOperation.length != allocationPostOperation.length || allocationPreOperation.length != allocationTarget.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        uint256 energyBefore;
        uint256 energyAfter;
        bool _isSuccess;

        (energyBefore, _isSuccess) = energy(
            allocationPreOperation, 
            allocationTarget, 
            weights,
            totalAllocationPreOperation, 
            totalAllocationTarget
            );

        if (!_isSuccess) {
            return (0, false);
        }

        (energyAfter, _isSuccess) = energy(
            allocationPostOperation, 
            allocationTarget, 
            weights,
            totalAllocationPostOperation, 
            totalAllocationTarget
            );

        if (!_isSuccess) {
            return (0, false);
        }

        // Calculate energy difference first
        int256 energyDiff = int256(energyBefore) - int256(energyAfter);
        
        // Handle positive and negative cases separately for safe multiplication
        if (energyDiff >= 0) {
            incentiveUSD = int256(Math.mulDiv(uint256(energyDiff), energyToUSDExchangeRatio, PRECISION));
        } else {
            incentiveUSD = -int256(Math.mulDiv(uint256(-energyDiff), energyToUSDExchangeRatio, PRECISION));
        }
        return (incentiveUSD, true);
    }
}
