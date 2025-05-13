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
    error NO_HOOKS();
    error INVALID_FEE();
    error NOT_AUTHORIZED();
    error LENGTH_MISMATCH();
    error NOT_INITIALIZED();
    error MANAGER_NOT_SET();
    error INVALID_CHAIN_ID();
    error ADDRESS_NOT_VALID();
    error ALREADY_INITIALIZED();
    error FEE_NOT_TRANSFERRED();
    error INSUFFICIENT_BALANCE_FOR_FEE();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;
}
