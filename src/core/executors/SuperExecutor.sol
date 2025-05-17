// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { SuperExecutorBase } from "./SuperExecutorBase.sol";

/// @title SuperExecutor
/// @author Superform Labs
/// @notice Standard implementation of the Superform hook executor for local chain operations
/// @dev This is the primary executor for non-cross-chain operations, implementing the logic
///      defined in SuperExecutorBase without adding additional functionality
contract SuperExecutor is SuperExecutorBase {
    /// @notice Initializes the SuperExecutor with ledger configuration
    /// @param ledgerConfiguration_ Address of the ledger configuration contract for fee calculations
    constructor(address ledgerConfiguration_) SuperExecutorBase(ledgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function name() external pure override returns (string memory) {
        return "SuperExecutor";
    }

    function version() external pure override returns (string memory) {
        return "0.0.1";
    }
}
