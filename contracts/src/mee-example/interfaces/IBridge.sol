// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface IBridge {
    function send(bytes memory data) external payable;
}
