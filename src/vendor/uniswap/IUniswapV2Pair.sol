// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IUniswapV2Pair
/// @notice Interface for Uniswap V2 pair contracts
/// @dev Includes ERC20 methods needed for LP token oracle (totalSupply, balanceOf, decimals).
///      Compatible with all V2 forks (SushiSwap, PancakeSwap, etc.)
interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function decimals() external pure returns (uint8);
}
