// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

import {BaseLedger} from "./BaseLedger.sol";

/// @notice Default ISuperLedger implementation
contract SuperLedger is BaseLedger, ISuperLedger {
    constructor(address registry_) BaseLedger(registry_) { }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedger
    function getLedger(
        address user,
        address yieldSource
    )
        external
        view
        returns (LedgerEntry[] memory entries, uint256 unconsumedEntries)
    {
        return _getLedger(user, yieldSource);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedger
    function updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        onlyExecutor
        returns (uint256 feeAmount)
    {
        return _updateAccounting(user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares);
    }


    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = superLedgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);

        if (config.manager == address(0)) revert MANAGER_NOT_SET();

        if (isInflow) {
            // Get price from oracle
            uint256 pps = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);
            if (pps == 0) revert INVALID_PRICE();

            // Always inscribe in the ledger, even if feePercent is set to 0
            userLedger[user][yieldSource].entries.push(
                LedgerEntry({ amountSharesAvailableToConsume: amountSharesOrAssets, price: pps })
            );
            emit AccountingInflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, pps);
            return 0;
        } else {
            // Only process outflow if feePercent is not set to 0
            if (config.feePercent != 0) {
                feeAmount = _processOutflow(user, yieldSource, amountSharesOrAssets, usedShares, config);

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }

    function _processOutflow(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        uint256 remainingShares = usedShares;
        uint256 costBasis;

        Ledger storage ledger = userLedger[user][yieldSource];
        uint256 len = ledger.entries.length;
        if (len == 0) return 0;

        uint256 currentIndex = userLedger[user][yieldSource].unconsumedEntries;

        while (remainingShares > 0) {
            if (currentIndex >= len) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = ledger.entries[currentIndex];
            uint256 availableShares = entry.amountSharesAvailableToConsume;

            // if no shares available on current entry, move to the next
            if (availableShares == 0) {
                unchecked {
                    ++currentIndex;
                }
                continue;
            }

            uint256 decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource);

            // remove from current entry
            uint256 sharesConsumed = availableShares > remainingShares ? remainingShares : availableShares;

            entry.amountSharesAvailableToConsume -= sharesConsumed;
            remainingShares -= sharesConsumed;

            costBasis += sharesConsumed * entry.price / (10 ** decimals);

            if (sharesConsumed == availableShares) {
                unchecked {
                    ++currentIndex;
                }
            }
        }

        userLedger[user][yieldSource].unconsumedEntries = currentIndex;

        uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;

        if (profit > 0) {
            if (config.feePercent == 0) revert FEE_NOT_SET();

            // Calculate fee in assets but don't transfer - let the executor handle it
            feeAmount = (profit * config.feePercent) / 10_000;
        }
    }
}