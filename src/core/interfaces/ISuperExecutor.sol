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
    error NOT_INITIALIZED();
    error ADDRESS_NOT_VALID();
    error ALREADY_INITIALIZED();
    error INSUFFICIENT_BALANCE_FOR_FEE();
    error FEE_NOT_TRANSFERRED();

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

