// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISuperExecutor {
    struct Hooks {
        address[] addresses;
        bytes[] data;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error NOT_INITIALIZED();
    error ALREADY_INITIALIZED();

    /*//////////////////////////////////////////////////////////////

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;

    /// @notice Execute a batch of calls from the bridge gateway
    /// @param data The data to execute
    function executeFromGateway(address account, bytes memory data) external;
}
