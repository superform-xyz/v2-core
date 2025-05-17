// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../src/vendor/1inch/I1InchAggregationRouterV6.sol";

contract MockDex {
    address public _token0;
    address public _token1;

    constructor(address token0_, address token1_) {
        _token0 = token0_;
        _token1 = token1_;
    }

    function token0() external view returns (address) {
        return _token0;
    }

    function token1() external view returns (address) {
        return _token1;
    }
}

contract Mock1InchRouter {
    uint256 public swappedAmount;

    function unoswapTo(Address, Address, uint256, uint256 minReturn, Address) external returns (uint256 returnAmount) {
        swappedAmount = minReturn;
        return minReturn;
    }

    function clipperSwapTo(
        IClipperExchange,
        address payable,
        Address,
        IERC20,
        uint256,
        uint256 outputAmount,
        uint256,
        bytes32,
        bytes32
    )
        external
        payable
        returns (uint256 returnAmount)
    {
        swappedAmount = outputAmount;
        return outputAmount;
    }

    function swap(
        IAggregationExecutor,
        I1InchAggregationRouterV6.SwapDescription calldata desc,
        bytes calldata
    )
        external
        payable
    {
        swappedAmount = desc.minReturnAmount;
    }
}
