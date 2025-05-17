// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { BaseLedger } from "./BaseLedger.sol";

/// @title SuperLedger
/// @author Superform Labs
/// @notice Default ISuperLedger implementation for standard yield source accounting
/// @dev This contract extends BaseLedger without modifying any of its functionality
///      It serves as the default ledger implementation that uses the standard yield
///      accounting mechanisms defined in the BaseLedger for typical use cases
contract SuperLedger is BaseLedger {
    /// @notice Initializes the SuperLedger with its configuration and executor permissions
    /// @param ledgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param allowedExecutors_ Array of addresses authorized to execute accounting operations
    constructor(
        address ledgerConfiguration_,
        address[] memory allowedExecutors_
    )
        BaseLedger(ledgerConfiguration_, allowedExecutors_)
    { }
}
