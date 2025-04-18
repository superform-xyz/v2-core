// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
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

    function _wrap_unwrap_ETH(address tokenIn, address tokenOut, uint256 netTokenIn) internal {
        if (tokenIn == NATIVE) IWETH(tokenOut).deposit{value: netTokenIn}();
        else IWETH(tokenIn).withdraw(netTokenIn);
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


interface IPYieldToken is IERC20Metadata {
    event NewInterestIndex(uint256 indexed newIndex);

    event Mint(
        address indexed caller,
        address indexed receiverPT,
        address indexed receiverYT,
        uint256 amountSyToMint,
        uint256 amountPYOut
    );

    event Burn(address indexed caller, address indexed receiver, uint256 amountPYToRedeem, uint256 amountSyOut);

    event RedeemRewards(address indexed user, uint256[] amountRewardsOut);

    event RedeemInterest(address indexed user, uint256 interestOut);

    event CollectRewardFee(address indexed rewardToken, uint256 amountRewardFee);

    function mintPY(address receiverPT, address receiverYT) external returns (uint256 amountPYOut);

    function redeemPY(address receiver) external returns (uint256 amountSyOut);

    function redeemPYMulti(
        address[] calldata receivers,
        uint256[] calldata amountPYToRedeems
    ) external returns (uint256[] memory amountSyOuts);

    function redeemDueInterestAndRewards(
        address user,
        bool redeemInterest,
        bool redeemRewards
    ) external returns (uint256 interestOut, uint256[] memory rewardsOut);

    function rewardIndexesCurrent() external returns (uint256[] memory);

    function pyIndexCurrent() external returns (uint256);

    function pyIndexStored() external view returns (uint256);

    function getRewardTokens() external view returns (address[] memory);

    function SY() external view returns (address);

    function PT() external view returns (address);

    function factory() external view returns (address);

    function expiry() external view returns (uint256);

    function isExpired() external view returns (bool);

    function doCacheIndexSameBlock() external view returns (bool);

    function pyIndexLastUpdatedBlock() external view returns (uint128);
}

interface IWETH is IERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

struct SwapData {
    SwapType swapType;
    address extRouter;
    bytes extCalldata;
    bool needScale;
}

struct SwapDataExtra {
    address tokenIn;
    address tokenOut;
    uint256 minOut;
    SwapData swapData;
}

enum SwapType {
    NONE,
    KYBERSWAP,
    ODOS,
    // ETH_WETH not used in Aggregator
    ETH_WETH,
    OKX,
    ONE_INCH,
    RESERVE_1,
    RESERVE_2,
    RESERVE_3,
    RESERVE_4,
    RESERVE_5
}

interface IPSwapAggregator {
    event SwapSingle(SwapType indexed swapType, address indexed tokenIn, uint256 amountIn);

    function swap(address tokenIn, uint256 amountIn, SwapData calldata swapData) external payable;
}