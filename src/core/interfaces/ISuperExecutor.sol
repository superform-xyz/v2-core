// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperExecutor
/// @author Superform Labs
/// @notice Interface for the SuperExecutor contract that executes hooks
interface ISuperExecutor {
    struct ExecutorEntry {
        address[] hooksAddresses;
        bytes[] hooksData;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error NOT_INITIALIZED();
    error ADDRESS_NOT_VALID();
    error ALREADY_INITIALIZED();
    error FEE_NOT_TRANSFERRED();
    error INSUFFICIENT_BALANCE_FOR_FEE();
    error EXECUTION_LENGTH_LIMIT_EXCEEDED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute

    function execute(bytes memory data) external;
}
