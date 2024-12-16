// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

abstract contract Events {
    event SuperPositionMint(address indexed strategyId_, address indexed spAddress_, uint256 amount_);
    event SuperPositionBurn(address indexed strategyId_, address indexed spAddress_, uint256 amount_);
}
