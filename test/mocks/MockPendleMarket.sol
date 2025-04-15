// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockPendleMarket {
    address public syToken;
    address public ptToken;
    address public ytToken;

    constructor(address syToken_, address ptToken_, address ytToken_) {
        ptToken = ptToken_;
        syToken = syToken_;
        ytToken = ytToken_;
    }

    function readTokens() external view returns (address, address, address) {
        return (syToken, ptToken, ytToken);
    }
}
