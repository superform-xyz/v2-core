// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

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
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockPendleRouter {
    address public pt;
    address public yt;
    address public token;

    constructor(address token_, address pt_, address yt_) {
        pt = pt_;
        yt = yt_;
        token = token_;
    }

    function swapExactTokenForPt(
        address,
        address,
        uint256,
        ApproxParams calldata,
        TokenInput calldata,
        LimitOrderData calldata
    )
        external
        payable
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm)
    {
        IERC20(pt).transfer(msg.sender, 1e18);
        return (1e18, 0, 0);
    }

    function mintPyFromToken(
        address receiver,
        address, //yt
        uint256, //minPyOut
        TokenInput calldata //tokenInput
    )
        external
        payable
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm)
    {
        IERC20(token).transferFrom(msg.sender, address(this), 1e18);
        IERC20(pt).transfer(receiver, 1e18);
        return (1e18, 0, 0);
    }

    function swapExactPtForToken(
        address,
        address,
        uint256,
        TokenOutput calldata,
        LimitOrderData calldata
    )
        external
        pure
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm)
    {
        return (1e18, 0, 0);
    }

    function redeemPyToToken(
        address receiver,
        address, //yt
        uint256 amount,
        TokenOutput calldata //tokenOutput
    )
        external
        payable
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm)
    {
        IERC20(token).transfer(receiver, amount);
        IERC20(pt).transferFrom(msg.sender, address(this), amount);
        return (amount, 0, 0);
    }
}
