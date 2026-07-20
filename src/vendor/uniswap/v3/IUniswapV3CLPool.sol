// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IUniswapV3CLPool
/// @notice Minimal interface for Uniswap V3-compatible concentrated liquidity pools
/// @dev Compatible with UniV3, Aerodrome Slipstream, and other UniV3 forks.
///      For Algebra (SparkDEX), globalState() replaces slot0() but tick/sqrtPrice are
///      accessible similarly — a separate oracle variant is needed for Algebra pools.
interface IUniswapV3CLPool {
    /// @notice The current state of the pool
    /// @return sqrtPriceX96 The current price as a sqrt(token1/token0) Q64.96 value
    /// @return tick The current tick
    /// @dev Only the first two return values are declared here; additional values (observationIndex,
    ///      observationCardinality, etc.) vary between UniV3 (7 fields) and Aerodrome Slipstream
    ///      (6 fields, no feeProtocol). Declaring only 2 fields is forward-compatible with both:
    ///      Solidity ABI decoder accepts return data that is larger than the declared size.
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);

    /// @notice The currently in-range liquidity available to the pool
    /// @dev Only reflects liquidity positions spanning the current tick
    function liquidity() external view returns (uint128);

    /// @notice The first of the two tokens of the pool, sorted by address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    function token1() external view returns (address);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value
    function tickSpacing() external view returns (int24);

    /// @notice The pool's fee tier in hundredths of a bip (e.g. 500 = 0.05%)
    /// @dev Present on Uniswap V3 pools. On Aerodrome Slipstream pools, fee() returns a dynamic
    ///      fee value that differs from tickSpacing — callers should prefer tickSpacing for
    ///      Slipstream position matching.
    function fee() external view returns (uint24);
}
