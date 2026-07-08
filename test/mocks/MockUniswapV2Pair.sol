// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

/// @title MockUniswapV2Pair
/// @notice Mock for unit testing UniV2LPYieldSourceOracle
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        _reserve0 = reserve0_;
        _reserve1 = reserve1_;
        _blockTimestampLast = uint32(block.timestamp);
    }

    function setTotalSupply(uint256 totalSupply_) external {
        _totalSupply = totalSupply_;
    }

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
