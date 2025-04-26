// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperExecutorBase } from "./SuperExecutorBase.sol";

/// @title SuperExecutor
/// @author Superform Labs
/// @notice Executor for Superform
/// @dev Implements the SuperExecutorBase with proof-based execution capabilities
contract SuperExecutor is SuperExecutorBase {
    constructor(
        address ledgerConfiguration_,
        address stateVerifier_,
        address resultVerifier_,
        bool requireProofsForSkippedExecution_
    ) SuperExecutorBase(
        ledgerConfiguration_,
        stateVerifier_,
        resultVerifier_,
        requireProofsForSkippedExecution_
    ) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function name() external pure override returns (string memory) {
        return "SuperExecutor";
    }

    function version() external pure override returns (string memory) {
        return "0.0.2";
    }
}
