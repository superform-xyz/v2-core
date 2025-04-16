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
    /// @notice Checks if a merkle root has been used by an account
    /// @param user The user account to check
    /// @param merkleRoot The merkle root to check
    /// @return Whether the merkle root has been used
    function isMerkleRootUsed(address user, bytes32 merkleRoot) external view returns (bool);
}
