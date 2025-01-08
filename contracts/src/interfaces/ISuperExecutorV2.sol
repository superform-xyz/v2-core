// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISuperExecutorV2 {
    struct ExecutorEntry {
        uint256 actionId;
        address finalTarget;
        bytes[] hooksData;
        address[] nonMainActionHooks;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();
    error NOT_AUTHORIZED();
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();
    error FINAL_TARGET_NOT_ZERO();
    error ACTION_TYPE_MISMATCH();
    error INVALID_HOOK_TYPE();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the actions registry address
    function superActions() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(address account, bytes memory data) external;

    /// @notice Execute a batch of calls from the bridge gateway
    /// @param data The data to execute
    function executeFromGateway(address account, bytes memory data) external;
}
