// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// superform
import { BaseLedger } from "./BaseLedger.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

/// @title FlatFeeLedger
/// @author Superform Labs
/// @notice Specialized ledger implementation that applies a flat fee to reward distributions
/// @dev Extends BaseLedger to modify the fee calculation logic for reward scenarios
///      Unlike the base implementation, this ledger ignores the cost basis and treats the
///      entire amount as profit subject to the fee percentage
contract FlatFeeLedger is BaseLedger {
    /// @notice Initializes the FlatFeeLedger with configuration and executor permissions
    /// @param ledgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param allowedExecutors_ Array of addresses authorized to execute accounting operations
    constructor(
        address ledgerConfiguration_,
        address[] memory allowedExecutors_
    )
        BaseLedger(ledgerConfiguration_, allowedExecutors_)
    { }

    /// @notice Processes outflow operations with a flat fee calculation
    /// @dev Overrides the base implementation to apply fees to the entire amount
    ///      Sets the cost basis to zero, treating the entire amount as profit
    ///      This is suitable for reward distributions where the entire amount is considered yield
    /// @param amountAssets The total asset amount being processed
    /// @param config The yield source oracle configuration containing fee settings
    /// @return feeAmount The calculated fee amount based on the full asset amount
    function _processOutflow(
        address,
        address,
        uint256 amountAssets,
        uint256,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        virtual
        override
        returns (uint256 feeAmount)
    {
        // Apply fee to the entire amount by using zero cost basis
        // This treats the entire amount as profit subject to the fee percentage
        feeAmount = _calculateFees(0, amountAssets, config.feePercent);
    }
}
