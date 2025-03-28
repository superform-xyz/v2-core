// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { SuperExecutorBase } from "./SuperExecutorBase.sol";

/// @title SuperExecutor
/// @author Superform Labs
/// @notice Executor for Superform
contract SuperExecutor is SuperExecutorBase {
    constructor(address registry_) SuperExecutorBase(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _name() internal pure override returns (string memory) {
        return "SuperExecutor";
    }

    function _version() internal pure override returns (string memory) {
        return "0.0.1";
    }
}
