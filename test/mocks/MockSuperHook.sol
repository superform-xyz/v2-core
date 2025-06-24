// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Execution } from "../../src/core/interfaces/ISuperHook.sol";

/// @notice Mock SuperHook implementation for testing
contract MockSuperHook {
    // Events for testing
    event PreExecuteCalled(address prevHook, address sender, bytes data);
    event PostExecuteCalled(address prevHook, address sender, bytes data);

    // Control parameters
    bool public shouldFailBuild;
    bool public shouldReturnEmptyExecutions;
    address public targetToReturn;
    bytes public callDataToReturn;
    address public caller;

    constructor(address _targetToReturn) {
        targetToReturn = _targetToReturn;
        callDataToReturn = abi.encodeWithSignature("execute()");
    }

    function setShouldFailBuild(bool _shouldFail) external {
        shouldFailBuild = _shouldFail;
    }

    function setShouldReturnEmptyExecutions(bool _shouldReturnEmpty) external {
        shouldReturnEmptyExecutions = _shouldReturnEmpty;
    }

    function setCallData(bytes calldata _callData) external {
        callDataToReturn = _callData;
    }

    function preExecute(address prevHook, address sender, bytes calldata data) external {
        emit PreExecuteCalled(prevHook, sender, data);
    }

    function build(address, address, bytes calldata) external view returns (Execution[] memory) {
        if (shouldFailBuild) {
            revert("MockSuperHook: build failed");
        }

        if (shouldReturnEmptyExecutions) {
            return new Execution[](0);
        }

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: targetToReturn, value: 0, callData: callDataToReturn });

        return executions;
    }

    function postExecute(address prevHook, address sender, bytes calldata data) external {
        emit PostExecuteCalled(prevHook, sender, data);
    }

    /// @notice Resets execution state - ONLY callable by executor after accounting
    function resetExecutionState(address) external { }

    function setExecutionContext(address _caller) external {
        caller = _caller;
    }
}
