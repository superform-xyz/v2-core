// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

/// @title MockUniswapV3CLPool
/// @notice Mock for unit testing UniV3CLPYieldSourceOracle
contract MockUniswapV3CLPool {
    address public token0;
    address public token1;

    uint160 private _sqrtPriceX96;
    int24 private _tick;
    uint128 private _liquidity;
    int24 public tickSpacing;

    constructor(address token0_, address token1_, int24 tickSpacing_) {
        token0 = token0_;
        token1 = token1_;
        tickSpacing = tickSpacing_;
    }

    function setSlot0(uint160 sqrtPriceX96_, int24 tick_) external {
        _sqrtPriceX96 = sqrtPriceX96_;
        _tick = tick_;
    }

    function setLiquidity(uint128 liquidity_) external {
        _liquidity = liquidity_;
    }

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick) {
        return (_sqrtPriceX96, _tick);
    }

    function liquidity() external view returns (uint128) {
        return _liquidity;
    }
}
