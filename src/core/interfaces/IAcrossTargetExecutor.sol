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
    event AcrossTargetExecutorFailed(string reason);
    event AcrossTargetExecutorFailedLowLevel(bytes lowLevelData);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the nonce for an account
    /// @param account The account to get the nonce for
    /// @return The nonce for the account
    function nonces(address account) external view returns (uint256);
}
