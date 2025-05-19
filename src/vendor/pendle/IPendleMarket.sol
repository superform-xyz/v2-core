// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28;

interface IPendleMarket {
    function readTokens() external view returns (address sy, address pt, address yt);
}
