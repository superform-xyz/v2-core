// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISuperExecutor {
    struct ExecutorEntry {
        address[] hooksAddresses;
        bytes[] hooksData;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;
}
