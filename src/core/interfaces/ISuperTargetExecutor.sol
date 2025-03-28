// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperTargetExecutor
/// @author Superform Labs
/// @notice Interface for the SuperTargetExecutor contract that executes hooks
/// @dev Use `ISuperExecutor` for the base methods
interface ISuperTargetExecutor {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function nonce() external view returns (uint256);
}
