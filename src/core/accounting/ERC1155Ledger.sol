// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

import { BaseLedger } from "./BaseLedger.sol";

/// @notice 5115 vaults ledger implementation
contract ERC1155Ledger is BaseLedger {
    constructor(address registry_) BaseLedger(registry_) { }

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
        override
        onlyExecutor
        returns (uint256 feeAmount)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            superLedgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);

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
                feeAmount = _processOutflow(user, yieldSource, usedShares, config);

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }

    struct OutflowContext {
        uint256 remainingShares;
        uint256 profit;
        uint256 currentIndex;
        uint256 decimals;
    }

    function _processOutflow(
        address user,
        address yieldSource,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        Ledger storage ledger = userLedger[user][yieldSource];
        uint256 len = ledger.entries.length;
        if (len == 0) return 0;

        OutflowContext memory ctx;
        ctx.remainingShares = usedShares;
        ctx.currentIndex = userLedger[user][yieldSource].unconsumedEntries;
        ctx.decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource);

        while (ctx.remainingShares > 0) {
            if (ctx.currentIndex >= len) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = ledger.entries[ctx.currentIndex];
            uint256 availableShares = entry.amountSharesAvailableToConsume;

            // If no shares available in current entry, move to the next
            if (availableShares == 0) {
                unchecked {
                    ++ctx.currentIndex;
                }
                continue;
            }

            // Remove from current entry
            uint256 sharesConsumed = availableShares > ctx.remainingShares ? ctx.remainingShares : availableShares;
            entry.amountSharesAvailableToConsume -= sharesConsumed;
            ctx.remainingShares -= sharesConsumed;

            // amount of assets in the entry price (registered at the INFLOW operation)
            uint256 entryBasis = sharesConsumed * entry.price / (10 ** ctx.decimals);

            // current price of the yield source
            uint256 ppsNow = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);
            // amount of assets in the current price
            uint256 currentBasis = sharesConsumed * ppsNow / (10 ** ctx.decimals);

            // if pps increased => currentBasis > entryBasis
            //   otherwise profit = 0 because the current price is lower than INFLOW price of the entry
            if (currentBasis > entryBasis) {
                ctx.profit += (currentBasis - entryBasis);
            }

            if (sharesConsumed == availableShares) {
                unchecked {
                    ++ctx.currentIndex;
                }
            }
        }
        userLedger[user][yieldSource].unconsumedEntries = ctx.currentIndex;
        if (ctx.profit > 0) {
            if (config.feePercent == 0) revert FEE_NOT_SET();

            // Calculate fee in assets but don't transfer - let the executor handle it
            feeAmount = (ctx.profit * config.feePercent) / 10_000;
        }
    }
}
