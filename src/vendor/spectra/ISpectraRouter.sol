// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface ISpectraRouter {
    function execute(bytes calldata _commands, bytes[] calldata _inputs) external payable;

    function execute(bytes calldata _commands, bytes[] calldata _inputs, uint256 _deadline) external payable;
}
