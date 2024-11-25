// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IERC5115 {
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut,
        bool depositFromInternalBalance
    )
        external
        returns (uint256 amountSharesOut);

    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut,
        bool burnFromInternalBalance
    )
        external
        returns (uint256 amountTokenOut);
}
