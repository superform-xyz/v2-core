// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {
    ISuperHook, ISuperHookResult, ISuperHookResultOutflow, Execution
} from "../../src/core/interfaces/ISuperHook.sol";

contract MockHook is ISuperHook, ISuperHookResult, ISuperHookResultOutflow {
    HookType public hookType;
    uint256 public outAmount;
    uint256 public usedShares;
    address public asset;
    bool public preExecuteCalled;
    bool public postExecuteCalled;
    Execution[] public executions;

    constructor(HookType _hookType, address _asset) {
        hookType = _hookType;
        asset = _asset;
    }

    function setOutAmount(uint256 _outAmount) external {
        outAmount = _outAmount;
    }

    function setUsedShares(uint256 _usedShares) external {
        usedShares = _usedShares;
    }

    function setExecutions(Execution[] memory _executions) external {
        delete executions;
        for (uint256 i = 0; i < _executions.length; i++) {
            executions.push(_executions[i]);
        }
    }

    function preExecute(address, address, bytes memory) external override {
        preExecuteCalled = true;
    }

    function build(address, address, bytes memory) external view override returns (Execution[] memory) {
        Execution[] memory result = new Execution[](executions.length);
        for (uint256 i = 0; i < executions.length; i++) {
            result[i] = executions[i];
        }
        return result;
    }

    function postExecute(address, address, bytes memory) external override {
        postExecuteCalled = true;
    }

    function lockForSP() external pure override returns (bool) {
        return false;
    }

    function spToken() external pure override returns (address) {
        return address(0);
    }
}
