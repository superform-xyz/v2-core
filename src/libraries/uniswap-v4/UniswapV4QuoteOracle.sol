// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External imports
import { PoolKey, PoolId, IPoolManagerSuperform } from "../../interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";
import { PoolIdLibrary } from "../../interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";

/// @title UniswapV4QuoteOracle
/// @author Superform Labs
/// @notice Library for generating on-chain quotes using Uniswap V4 pool state
/// @dev Provides quote generation without executing swaps, eliminating API dependencies
///      Uses pool state and math libraries to simulate swap execution results
library UniswapV4QuoteOracle {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the pool has zero liquidity
    error ZeroLiquidity();

    /// @notice Thrown when the quote calculation fails
    error QuoteCalculationFailed();

    /// @notice Thrown when the price impact exceeds safe bounds
    error ExcessivePriceImpact();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for quote calculation
    /// @param poolKey The pool key to quote against
    /// @param zeroForOne Whether swapping token0 for token1
    /// @param amountIn The input amount for the swap
    /// @param sqrtPriceLimitX96 Optional price limit for the swap (0 for no limit)
    struct QuoteParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Result of a quote calculation
    /// @param amountOut The expected output amount
    /// @param sqrtPriceX96After The expected price after the swap
    /// @param initializedTicksCrossed Number of initialized ticks crossed
    /// @param gasEstimate Estimated gas cost for the swap
    struct QuoteResult {
        uint256 amountOut;
        uint160 sqrtPriceX96After;
        uint32 initializedTicksCrossed;
        uint256 gasEstimate;
    }

    /// @notice Parameters for quote validation
    /// @param expectedMinOut The expected minimum output amount
    /// @param maxDeviationBps Maximum allowed deviation in basis points
    struct ValidationParams {
        uint256 expectedMinOut;
        uint256 maxDeviationBps;
    }

    /*//////////////////////////////////////////////////////////////
                            QUOTE GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generate on-chain quote using pool state without executing swap
    /// @dev Uses current pool state to simulate swap execution
    /// @param poolManager The Uniswap V4 pool manager
    /// @param params The quote parameters
    /// @return result The quote result with expected amounts and price impact
    function getQuote(
        IPoolManagerSuperform poolManager,
        QuoteParams memory params
    ) 
        internal 
        view 
        returns (QuoteResult memory result) 
    {
        PoolId poolId = params.poolKey.toId();
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 lpFee) = 
            poolManager.getSlot0(poolId);
        
        // Validate pool has liquidity
        if (sqrtPriceX96 == 0) {
            revert ZeroLiquidity();
        }

        // Calculate quote based on current pool state and parameters
        result = _simulateSwap(
            sqrtPriceX96,
            tick,
            params.amountIn,
            params.zeroForOne,
            params.sqrtPriceLimitX96,
            lpFee,
            protocolFee
        );
    }

    /// @notice Generate multiple quotes for different amount scenarios
    /// @dev Useful for finding optimal swap amounts or analyzing price impact
    /// @param poolManager The Uniswap V4 pool manager
    /// @param baseParams Base parameters for the quotes
    /// @param amounts Array of amounts to quote
    /// @return results Array of quote results
    function getBatchQuotes(
        IPoolManagerSuperform poolManager,
        QuoteParams memory baseParams,
        uint256[] memory amounts
    )
        internal
        view
        returns (QuoteResult[] memory results)
    {
        results = new QuoteResult[](amounts.length);
        
        for (uint256 i = 0; i < amounts.length; i++) {
            QuoteParams memory params = baseParams;
            params.amountIn = amounts[i];
            results[i] = getQuote(poolManager, params);
        }
    }

    /// @notice Validate quote deviation from expected output
    /// @dev Ensures on-chain quote aligns with user expectations within tolerance
    /// @param poolManager The pool manager contract
    /// @param poolKey The pool key to validate against
    /// @param amountIn The input amount
    /// @param validation The validation parameters
    /// @return isValid True if the quote is within acceptable bounds
    function validateQuoteDeviation(
        IPoolManagerSuperform poolManager,
        PoolKey memory poolKey,
        uint256 amountIn,
        ValidationParams memory validation
    ) 
        internal 
        view 
        returns (bool isValid) 
    {
        QuoteResult memory quote = getQuote(
            poolManager,
            QuoteParams({
                poolKey: poolKey,
                zeroForOne: true, // Assuming token0 -> token1 for validation
                amountIn: amountIn,
                sqrtPriceLimitX96: 0 // No price limit for quote validation
            })
        );
        
        // Calculate deviation percentage in basis points
        uint256 deviationBps = quote.amountOut > validation.expectedMinOut 
            ? ((quote.amountOut - validation.expectedMinOut) * 10000) / quote.amountOut
            : ((validation.expectedMinOut - quote.amountOut) * 10000) / validation.expectedMinOut;
            
        isValid = deviationBps <= validation.maxDeviationBps;
    }

    /// @notice Get the price impact of a swap in basis points
    /// @dev Calculates how much the swap will move the pool price
    /// @param poolManager The pool manager contract
    /// @param params The quote parameters
    /// @return priceImpactBps Price impact in basis points
    function getPriceImpact(
        IPoolManagerSuperform poolManager,
        QuoteParams memory params
    )
        internal
        view
        returns (uint256 priceImpactBps)
    {
        PoolId poolId = params.poolKey.toId();
        
        // Get current price
        (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        // Get quote with price after swap
        QuoteResult memory result = getQuote(poolManager, params);
        
        // Calculate price impact
        if (currentSqrtPriceX96 > result.sqrtPriceX96After) {
            priceImpactBps = ((currentSqrtPriceX96 - result.sqrtPriceX96After) * 10000) / currentSqrtPriceX96;
        } else {
            priceImpactBps = ((result.sqrtPriceX96After - currentSqrtPriceX96) * 10000) / currentSqrtPriceX96;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to simulate swap execution
    /// @dev Simulates the swap using pool math without state changes
    /// @param currentSqrtPriceX96 Current pool price
    /// @param currentTick Current pool tick
    /// @param amountIn Input amount for the swap
    /// @param zeroForOne Direction of the swap
    /// @param sqrtPriceLimitX96 Price limit for the swap
    /// @param lpFee LP fee tier of the pool
    /// @param protocolFee Protocol fee of the pool
    /// @return result Simulated swap result
    function _simulateSwap(
        uint160 currentSqrtPriceX96,
        int24 currentTick,
        uint256 amountIn,
        bool zeroForOne,
        uint160 sqrtPriceLimitX96,
        uint24 lpFee,
        uint16 protocolFee
    ) 
        private 
        pure 
        returns (QuoteResult memory result) 
    {
        // For now, implement a simplified calculation
        // In production, this would use Uniswap V4's math libraries:
        // - TickMath for tick/price conversions
        // - SqrtPriceMath for price calculations
        // - SwapMath for exact simulation
        
        // Simplified calculation for demonstration
        // This should be replaced with proper V4 math library integration
        
        // Calculate approximate output based on current price
        // This is a placeholder - real implementation would use V4's swap math
        uint256 priceRatio = uint256(currentSqrtPriceX96) * uint256(currentSqrtPriceX96);
        
        if (zeroForOne) {
            // Selling token0 for token1
            result.amountOut = (amountIn * priceRatio) / (2**192);
        } else {
            // Selling token1 for token0  
            result.amountOut = (amountIn * (2**192)) / priceRatio;
        }
        
        // Apply fees (simplified)
        uint256 totalFeeBps = lpFee + protocolFee;
        result.amountOut = (result.amountOut * (10000 - totalFeeBps)) / 10000;
        
        // Set other result fields
        result.sqrtPriceX96After = _calculateNewPrice(currentSqrtPriceX96, amountIn, zeroForOne);
        result.initializedTicksCrossed = _estimateTicksCrossed(currentTick, result.sqrtPriceX96After);
        result.gasEstimate = _estimateGasUsage(result.initializedTicksCrossed);
    }

    /// @notice Calculate new price after swap (simplified)
    /// @dev Placeholder function - should use V4 math libraries in production
    function _calculateNewPrice(
        uint160 currentSqrtPriceX96,
        uint256 amountIn,
        bool zeroForOne
    ) 
        private 
        pure 
        returns (uint160 newSqrtPriceX96) 
    {
        // Simplified price impact calculation
        // Real implementation would use SqrtPriceMath.getNextSqrtPriceFromInput
        uint256 priceImpact = amountIn / 1000000; // Very rough approximation
        
        if (zeroForOne) {
            newSqrtPriceX96 = uint160(uint256(currentSqrtPriceX96) - priceImpact);
        } else {
            newSqrtPriceX96 = uint160(uint256(currentSqrtPriceX96) + priceImpact);
        }
    }

    /// @notice Estimate ticks crossed during swap
    /// @dev Placeholder function for gas estimation
    function _estimateTicksCrossed(
        int24 startTick,
        uint160 endSqrtPriceX96
    ) 
        private 
        pure 
        returns (uint32 ticksCrossed) 
    {
        // Simplified estimation - real implementation would use TickMath
        // This is just for gas estimation purposes
        ticksCrossed = uint32(uint256(int256(startTick > 0 ? startTick : -startTick)) / 60);
        if (ticksCrossed == 0) ticksCrossed = 1;
    }

    /// @notice Estimate gas usage based on ticks crossed
    /// @dev Provides rough gas estimate for the swap
    function _estimateGasUsage(uint32 ticksCrossed) private pure returns (uint256 gasEstimate) {
        // Base gas cost for a swap + additional cost per tick
        gasEstimate = 150000 + (ticksCrossed * 20000);
    }
}