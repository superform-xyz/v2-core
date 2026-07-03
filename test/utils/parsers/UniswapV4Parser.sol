// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { BaseAPIParser } from "./BaseAPIParser.sol";

// Real Uniswap V4 imports
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { CurrencyLibrary } from "v4-core/types/Currency.sol";

/// @title UniswapV4Parser
/// @author Superform Labs
/// @notice Parser for generating Uniswap V4 hook calldata without external API dependencies
/// @dev Provides on-chain calldata generation for V4 swaps following Superform patterns
contract UniswapV4Parser is BaseAPIParser {
    using CurrencyLibrary for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when token path is invalid for multi-hop
    error InvalidTokenPath();

    /// @notice Thrown when fees array doesn't match token path
    error InvalidFeesArray();

    /// @notice Thrown when tokens are identical
    error IdenticalTokens();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for single-hop V4 swap
    /// @param poolKey Pool key for the V4 pool
    /// @param dstReceiver Recipient of output tokens
    /// @param sqrtPriceLimitX96 Price limit (0 for no limit)
    /// @param originalAmountIn Input amount
    /// @param originalMinAmountOut Minimum output amount
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points
    /// @param zeroForOne Whether swapping token0 for token1
    /// @param additionalData Additional data for the swap
    struct SingleHopParams {
        PoolKey poolKey;
        address dstReceiver;
        uint160 sqrtPriceLimitX96;
        uint256 originalAmountIn;
        uint256 originalMinAmountOut;
        uint256 maxSlippageDeviationBps;
        bool zeroForOne;
        bytes additionalData;
    }

    /*//////////////////////////////////////////////////////////////
                        SINGLE-HOP GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Get tick spacing for a given fee tier
    /// @param fee The fee tier
    /// @return tickSpacing The tick spacing for the fee tier
    function getTickSpacing(uint24 fee) public pure returns (int24 tickSpacing) {
        if (fee == 500) {
            tickSpacing = 10;
        } else if (fee == 3000) {
            tickSpacing = 60;
        } else if (fee == 10_000) {
            tickSpacing = 200;
        } else {
            revert("Unsupported fee tier");
        }
    }

    /// @notice Check if two tokens need to be swapped for proper pool ordering
    /// @dev V4 pools require token0 < token1
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return token0 The lower address token
    /// @return token1 The higher address token
    /// @return swapped Whether the tokens were swapped from input order
    function _sortTokens(
        address tokenA,
        address tokenB
    )
        internal
        pure
        returns (address token0, address token1, bool swapped)
    {
        require(tokenA != tokenB, "Identical tokens");

        if (tokenA < tokenB) {
            (token0, token1, swapped) = (tokenA, tokenB, false);
        } else {
            (token0, token1, swapped) = (tokenB, tokenA, true);
        }
    }

    /// @notice Generate hook data for single-hop V4 swap
    /// @dev Creates properly encoded data matching SwapUniswapV4Hook expectations
    /// @param params The swap parameters
    /// @param usePrevHookAmount Whether to use previous hook's output
    /// @return hookData Encoded hook data ready for execution
    function generateSingleHopSwapCalldata(
        SingleHopParams memory params,
        bool usePrevHookAmount
    )
        public
        pure
        returns (bytes memory hookData)
    {
        // Split into two encodePacked calls to avoid stack-too-deep
        // Header + pool key fields (bytes 0-119)
        bytes memory part1 = abi.encodePacked(
            bytes32(0), // 32 bytes (0-31): yieldSourceOracleId (header)
            address(0), // 20 bytes (32-51): yieldSource (header)
            params.poolKey.currency0, // 20 bytes (52-71): currency0
            params.poolKey.currency1, // 20 bytes (72-91): currency1
            uint32(params.poolKey.fee), // 4 bytes (92-95): fee (padded from uint24)
            uint32(int32(params.poolKey.tickSpacing)), // 4 bytes (96-99): tickSpacing (padded from int24)
            params.poolKey.hooks // 20 bytes (100-119): hooks address
        );
        // Remaining swap params (bytes 120-269+)
        bytes memory part2 = abi.encodePacked(
            params.dstReceiver, // 20 bytes (120-139): dstReceiver
            uint256(params.sqrtPriceLimitX96), // 32 bytes (140-171): sqrtPriceLimitX96 (padded from uint160)
            params.originalAmountIn, // 32 bytes (172-203): originalAmountIn
            params.originalMinAmountOut, // 32 bytes (204-235): originalMinAmountOut
            params.maxSlippageDeviationBps, // 32 bytes (236-267): maxSlippageDeviationBps
            params.zeroForOne ? bytes1(0x01) : bytes1(0x00), // 1 byte (268): zeroForOne flag
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00), // 1 byte (269): usePrevHookAmount flag
            params.additionalData // Additional data (270+)
        );
        hookData = abi.encodePacked(part1, part2);
    }
}
