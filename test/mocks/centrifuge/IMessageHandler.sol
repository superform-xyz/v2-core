// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMessageHandler {
    function handleMessage(bytes memory message) external;
}
