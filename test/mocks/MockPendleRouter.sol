// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
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
import { IStandardizedYield } from "../../src/vendor/pendle/IStandardizedYield.sol";

contract MockPendleRouter {
    address internal constant NATIVE = address(0);

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

    function createSwapTypeNoAggregator() public pure returns (SwapData memory) {
        return SwapData({
            swapType: SwapType.NO_AGGREGATOR,
            aggregator: address(0),
            aggregatorData: bytes("")
        });
    }

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyInterm) {
        address SY = IPYieldToken(YT).SY();

        netSyInterm = _redeemPyToSy(SY, YT, netPyIn, 1);
        netTokenOut = _redeemSyToToken(receiver, SY, netSyInterm, output, false);
    }

    function _redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut) {
        address PT = IPYieldToken(YT).PT();

        _transferFrom(IERC20(PT), msg.sender, YT, netPyIn);

        bool needToBurnYt = (!IPYieldToken(YT).isExpired());
        if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn);

        netSyOut = IPYieldToken(YT).redeemPY(receiver);
        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
    }

    function _transferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (amount != 0) token.safeTransferFrom(from, to, amount);
    }

    function _redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata out,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        SwapType swapType = out.swapData.swapType;

        if (swapType == SwapType.NONE) {
            netTokenOut = __redeemSy(receiver, SY, netSyIn, out, doPull);
        } else if (swapType == SwapType.ETH_WETH) {
            netTokenOut = __redeemSy(address(this), SY, netSyIn, out, doPull); // ETH:WETH is 1:1

            _wrap_unwrap_ETH(out.tokenRedeemSy, out.tokenOut, netTokenOut);

            _transferOut(out.tokenOut, receiver, netTokenOut);
        } else {
            uint256 netTokenRedeemed = __redeemSy(out.pendleSwap, SY, netSyIn, out, doPull);

            IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.swapData);

            netTokenOut = _selfBalance(out.tokenOut);

            _transferOut(out.tokenOut, receiver, netTokenOut);
        }

        if (netTokenOut < out.minTokenOut) revert("Slippage: INSUFFICIENT_TOKEN_OUT");
    }

    function __redeemSy(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata out,
        bool doPull
    ) private returns (uint256 netTokenRedeemed) {
        if (doPull) {
            _transferFrom(IERC20(SY), msg.sender, SY, netSyIn);
        }

        netTokenRedeemed = IStandardizedYield(SY).redeem(receiver, netSyIn, out.tokenRedeemSy, 0, true);
    }

    function _transferOut(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        if (token == NATIVE) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "eth send failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }


    function _transferOut(address[] memory tokens, address to, uint256[] memory amounts) internal {
        uint256 numTokens = tokens.length;
        require(numTokens == amounts.length, "length mismatch");
        for (uint256 i = 0; i < numTokens; ) {
            _transferOut(tokens[i], to, amounts[i]);
            unchecked {
                i++;
            }
        }
    }

    function _selfBalance(address token) internal view returns (uint256) {
        return (token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this));
    }

    function _selfBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this));
    }
}