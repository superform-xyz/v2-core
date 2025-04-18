// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order,
    SwapData,
    SwapType,
    OrderType
} from "../../src/vendor/pendle/IPendleRouterV4.sol";

contract MockPendleRouter {
    function swapExactTokenForPt(
        address,
        address,
        uint256,
        ApproxParams calldata,
        TokenInput calldata,
        LimitOrderData calldata 
    ) external payable returns (
        uint256 netPtOut,
        uint256 netSyFee,
        uint256 netSyInterm
    ) {
        return (0, 0, 0);
    }

    function swapExactPtForToken(
        address,
        address,
        uint256,
        TokenOutput calldata,
        LimitOrderData calldata
    ) external pure returns (
        uint256 netTokenOut,
        uint256 netSyFee,
        uint256 netSyInterm
    ) {
        return (0, 0, 0);
    }

    /// @dev Creates a TokenOutput struct without using any swap aggregator
/// @param tokenOut must be one of the SY's tokens out (obtain via `IStandardizedYield#getTokensOut`)
/// @param minTokenOut minimum amount of token out
function createTokenOutputSimple(address tokenOut, uint256 minTokenOut) external pure returns (TokenOutput memory) {
    return
        TokenOutput({
            tokenOut: tokenOut,
            minTokenOut: minTokenOut,
            tokenRedeemSy: tokenOut,
            pendleSwap: address(0),
            swapData: createSwapTypeNoAggregator()
        });
}
}