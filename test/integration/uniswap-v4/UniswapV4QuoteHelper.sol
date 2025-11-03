// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";
import { SwapMath } from "v4-core/libraries/SwapMath.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

/// @title UniswapV4QuoteHelper
/// @notice Helper library for generating quotes for Uniswap V4 swaps (testing only)
/// @dev NOTE: This is a simplified single-step quote that may be optimistic for large swaps.
///      For large swaps that cross multiple ticks, the actual swap may execute less than amountIn
///      if it hits the price limit early. This function is for testing purposes only.
///      For production use, consider using off-chain quoters or accepting the optimistic nature.
library UniswapV4QuoteHelper {
    /// @notice Parameters for quote calculation
    struct QuoteParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Result of a quote calculation
    struct QuoteResult {
        uint256 amountOut;
        uint160 sqrtPriceX96After;
    }

    /// @notice Generate on-chain quote using pool state and real V4 math
    /// @dev NOTE: This is a simplified single-step quote that may be optimistic for large swaps.
    ///      For large swaps that cross multiple ticks, the actual swap may execute less than amountIn
    ///      if it hits the price limit early. This function is primarily for testing purposes.
    ///      For production use, consider using off-chain quoters or accepting the optimistic nature.
    /// @param poolManager The PoolManager contract
    /// @param params The quote parameters
    /// @return result The quote result with expected amounts
    function getQuote(
        IPoolManager poolManager,
        QuoteParams memory params
    )
        internal
        view
        returns (QuoteResult memory result)
    {
        PoolId poolId = params.poolKey.toId();

        // Get current pool state using StateLibrary
        (uint160 sqrtPriceX96,, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(poolManager, poolId);

        // Validate pool has liquidity
        require(sqrtPriceX96 != 0, "ZERO_LIQUIDITY");

        // Get pool liquidity
        uint128 liquidity = StateLibrary.getLiquidity(poolManager, poolId);

        // Calculate target price (simplified - use current price if no limit)
        uint160 sqrtPriceTargetX96 = params.sqrtPriceLimitX96 == 0
            ? (params.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1)
            : params.sqrtPriceLimitX96;

        // Use real V4 SwapMath for single-step quote (may be optimistic for large swaps)
        // This computes only one step - large swaps may hit price limits and execute partially
        (uint160 sqrtPriceNextX96,, uint256 amountOut,) = SwapMath.computeSwapStep(
            sqrtPriceX96,
            sqrtPriceTargetX96,
            liquidity,
            -int256(params.amountIn), // Negative for exact input
            lpFee + protocolFee
        );

        result.amountOut = amountOut;
        result.sqrtPriceX96After = sqrtPriceNextX96;
    }
}

