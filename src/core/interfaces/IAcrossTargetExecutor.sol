// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title IAcrossTargetExecutor
/// @author Superform Labs
/// @notice Interface for the AcrossTargetExecutor contract that executes hooks
/// @dev Use `ISuperExecutor` for the base methods
interface IAcrossTargetExecutor {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AcrossTargetExecutorReceivedButNoHooks();
    event AcrossTargetExecutorExecuted(address indexed account);
    event AcrossTargetExecutorReceivedButNotEnoughBalance(address indexed account);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function nonce() external view returns (uint256);
}
