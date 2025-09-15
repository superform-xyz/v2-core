// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title DynamicMinAmountCalculator
/// @author Superform Labs
/// @notice Library for calculating dynamic minAmountOut with ratio-based protection
/// @dev Implements the core logic for recalculating minAmountOut when amountIn changes
///      while ensuring the ratio change stays within acceptable bounds
library DynamicMinAmountCalculator {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the ratio deviation exceeds the maximum allowed
    /// @param actualDeviation The actual ratio deviation in basis points
    /// @param maxAllowed The maximum allowed deviation in basis points
    error ExcessiveSlippageDeviation(uint256 actualDeviation, uint256 maxAllowed);

    /// @notice Thrown when original amounts are zero or invalid
    error InvalidOriginalAmounts();

    /// @notice Thrown when actual amount is zero
    error InvalidActualAmount();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for dynamic minAmount recalculation
    /// @param originalAmountIn The original user-provided amountIn
    /// @param originalMinAmountOut The original user-provided minAmountOut
    /// @param actualAmountIn The actual amountIn (potentially changed by bridges/hooks)
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points (e.g., 100 = 1%)
    struct RecalculationParams {
        uint256 originalAmountIn;
        uint256 originalMinAmountOut;
        uint256 actualAmountIn;
        uint256 maxSlippageDeviationBps;
    }

    /*//////////////////////////////////////////////////////////////
                            CALCULATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates new minAmountOut ensuring ratio protection
    /// @dev Formula: newMinAmount = originalMinAmount * (actualAmountIn / originalAmountIn)
    ///      Validates that ratio change doesn't exceed maxSlippageDeviationBps
    /// @param params The recalculation parameters
    /// @return newMinAmountOut The calculated minAmountOut with ratio protection
    function calculateDynamicMinAmount(
        RecalculationParams memory params
    ) 
        internal 
        pure 
        returns (uint256 newMinAmountOut) 
    {
        // Input validation
        if (params.originalAmountIn == 0 || params.originalMinAmountOut == 0) {
            revert InvalidOriginalAmounts();
        }
        if (params.actualAmountIn == 0) {
            revert InvalidActualAmount();
        }

        // Calculate the ratio of actual to original amount (using 1e18 precision)
        uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;
        
        // Calculate new minAmountOut proportionally
        newMinAmountOut = (params.originalMinAmountOut * amountRatio) / 1e18;
        
        // Calculate ratio deviation in basis points
        uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);
        
        // Validate ratio deviation is within allowed bounds
        if (ratioDeviationBps > params.maxSlippageDeviationBps) {
            revert ExcessiveSlippageDeviation(ratioDeviationBps, params.maxSlippageDeviationBps);
        }
    }

    /// @notice Validates that the ratio change is within acceptable bounds
    /// @dev Helper function to check if a given ratio change is acceptable
    /// @param originalAmountIn The original amount
    /// @param actualAmountIn The actual amount
    /// @param maxSlippageDeviationBps Maximum allowed deviation in basis points
    /// @return isValid True if the ratio change is within bounds
    function validateRatioChange(
        uint256 originalAmountIn,
        uint256 actualAmountIn, 
        uint256 maxSlippageDeviationBps
    )
        internal
        pure
        returns (bool isValid)
    {
        if (originalAmountIn == 0 || actualAmountIn == 0) {
            return false;
        }

        uint256 amountRatio = (actualAmountIn * 1e18) / originalAmountIn;
        uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);
        
        isValid = ratioDeviationBps <= maxSlippageDeviationBps;
    }

    /// @notice Gets the expected new minAmountOut without validation
    /// @dev Pure calculation function for preview/estimation purposes
    /// @param originalAmountIn The original amount in
    /// @param originalMinAmountOut The original minimum amount out
    /// @param actualAmountIn The actual amount in
    /// @return expectedMinAmountOut The expected minimum amount out
    function getExpectedMinAmountOut(
        uint256 originalAmountIn,
        uint256 originalMinAmountOut,
        uint256 actualAmountIn
    )
        internal
        pure
        returns (uint256 expectedMinAmountOut)
    {
        if (originalAmountIn == 0) {
            return 0;
        }
        
        expectedMinAmountOut = (originalMinAmountOut * actualAmountIn) / originalAmountIn;
    }

    /// @notice Gets the ratio deviation in basis points for a given ratio
    /// @dev Calculates how much the ratio deviates from 1:1 (no change)
    /// @param amountRatio The ratio in 1e18 precision (1e18 = no change)
    /// @return ratioDeviationBps The deviation in basis points
    function getRatioDeviationBps(uint256 amountRatio) internal pure returns (uint256 ratioDeviationBps) {
        ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to calculate ratio deviation in basis points
    /// @dev Handles both increases and decreases from the 1:1 ratio
    /// @param amountRatio The ratio in 1e18 precision
    /// @return ratioDeviationBps The deviation in basis points
    function _calculateRatioDeviationBps(uint256 amountRatio) private pure returns (uint256 ratioDeviationBps) {
        if (amountRatio > 1e18) {
            // Ratio increased (more actual than original)
            ratioDeviationBps = ((amountRatio - 1e18) * 10000) / 1e18;
        } else {
            // Ratio decreased (less actual than original)  
            ratioDeviationBps = ((1e18 - amountRatio) * 10000) / 1e18;
        }
    }
}