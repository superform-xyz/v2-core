// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface ISuperSenderCreator {
    function createSender(bytes calldata initCode) external returns (address sender);
}
