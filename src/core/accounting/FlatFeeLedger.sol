// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// superform
import { BaseLedger } from "./BaseLedger.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

/// @title FlatFeeLedger
/// @author Superform Labs
/// @notice Rewards ledger
contract FlatFeeLedger is BaseLedger {
    constructor(address ledgerConfiguration_, address[] memory allowedExecutors_) BaseLedger(ledgerConfiguration_, allowedExecutors_) { }

    /// @dev override to use a flat fee out of `amountAssets`
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
        /// @dev flat fee out of `amountAssets` (rewards)
        ///      `costBasis` is 0 to use the full `amountAssets`
        feeAmount = _calculateFees(0, amountAssets, config.feePercent);
    }
}
