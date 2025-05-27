// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IHookExecutionData } from "./IHookExecutionData.sol";

/// @title ISuperBank
/// @author Superform Labs
/// @notice Interface for SuperBank, which compounds protocol revenue into sUP by executing registered hooks.
interface ISuperBank is IHookExecutionData {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Error thrown when an invalid address is provided.
    error INVALID_ADDRESS();
    /// @notice Error thrown when a transfer fails.
    error TRANSFER_FAILED();
    /// @notice Error thrown when an invalid UP amount is provided.
    error INVALID_UP_AMOUNT_TO_DISTRIBUTE();
    /// @notice Error thrown when an invalid bank manager is provided.
    error INVALID_BANK_MANAGER();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when revenue is distributed to sUP and Treasury.
    /// @param upToken The address of the UP token.
    /// @param supToken The address of the sUP token.
    /// @param treasury The address of the Treasury.
    /// @param supAmount The amount sent to sUP.
    /// @param treasuryAmount The amount sent to Treasury.
    event RevenueDistributed(
        address indexed upToken,
        address indexed supToken,
        address indexed treasury,
        uint256 supAmount,
        uint256 treasuryAmount
    );

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a batch of hooks, verifying each with a Merkle proof.
    /// @dev Each hook is verified against a Merkle root from SuperGovernor.
    /// @dev Hooks must implement the ISuperHook interface (preExecute, build, postExecute).
    /// @param executionData HookExecutionData struct containing arrays of hooks, data, and Merkle proofs.
    function executeHooks(HookExecutionData calldata executionData) external;

    /// @notice Distributes UP tokens based on governance-agreed revenue share.
    /// @dev Transfers X% (REVENUE_SHARE) of UP tokens to sUP, and the remainder to Superform Treasury.
    /// @param upAmount_ The amount of UP tokens to distribute.
    function distribute(uint256 upAmount_) external;
}
