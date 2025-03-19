// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { BaseLedger } from "./BaseLedger.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ERC5115Ledger
/// @author Superform Labs
/// @notice 5115 vaults ledger implementation
contract ERC5115Ledger is BaseLedger {
    constructor(address registry_) BaseLedger(registry_) { }

    function _getOutflowProcessVolume(uint256 amountSharesOrAssets, uint256 usedShares, uint256 pps, uint8 decimals) internal pure override returns(uint256 amountAssets)
    {
        return Math.mulDiv(usedShares, pps, 10 ** decimals);
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
//                feeAmount = _processOutflow(user, yieldSource, usedShares, config);

                uint256 ppsNow = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);

                uint256 decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource);

                feeAmount = _processOutflow(user, yieldSource, usedShares * ppsNow / (10 ** decimals), usedShares, config);

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }


    // Copy pasted from
    // https://github.com/superform-xyz/v2-contracts/blob/dev/src/core/accounting/BaseLedger.sol#L132
    struct OutflowVars {
        uint256 remainingShares;
        uint256 costBasis;
        uint256 len;
        uint256 currentIndex;
        uint256 lastIndex;
        uint256 lastSharesConsumed;
        uint256 decimals;
    }

    // Copy pasted from
    // https://github.com/superform-xyz/v2-contracts/blob/dev/src/core/accounting/BaseLedger.sol#L142
    function _processOutflow(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
    internal
    override
    returns (uint256 feeAmount)
    {
        Ledger storage ledger = userLedger[user][yieldSource];

        OutflowVars memory vars = OutflowVars({
            remainingShares: usedShares,
            costBasis: 0,
            len: ledger.entries.length,
            currentIndex: userLedger[user][yieldSource].unconsumedEntries,
            lastIndex: 0,
            lastSharesConsumed: 0,
            decimals: IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource)
        });

        if (vars.len == 0) return 0;
        vars.lastIndex = vars.currentIndex;

        while (vars.remainingShares > 0) {
            if (vars.currentIndex >= vars.len) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = ledger.entries[vars.currentIndex];
            uint256 availableShares = entry.amountSharesAvailableToConsume;

            if (availableShares == 0) {
                unchecked {
                    ++vars.currentIndex;
                }
                continue;
            }

            uint256 sharesConsumed = availableShares > vars.remainingShares ? vars.remainingShares : availableShares;

            vars.lastIndex = vars.currentIndex;
            vars.lastSharesConsumed = sharesConsumed;
            vars.remainingShares -= sharesConsumed;

            vars.costBasis += sharesConsumed * entry.price / (10 ** vars.decimals);

            if (sharesConsumed == availableShares) {
                unchecked {
                    ++vars.currentIndex;
                }
            }
        }

        ledger.entries[vars.lastIndex].amountSharesAvailableToConsume -= vars.lastSharesConsumed;
        userLedger[user][yieldSource].unconsumedEntries = vars.currentIndex;

        uint256 profit = amountAssets > vars.costBasis ? amountAssets - vars.costBasis : 0;

        if (profit > 0) {
            if (config.feePercent == 0) revert FEE_NOT_SET();

            feeAmount = (profit * config.feePercent) / 10_000;
        }
    }

    //    struct OutflowContext {
//        uint256 remainingShares;
//        uint256 profit;
//        uint256 currentIndex;
//        uint256 decimals;
//    }


//    function _processOutflow5115(
//        address user,
//        address yieldSource,
//        uint256 usedShares,
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
//    )
//        internal
//        virtual
//        returns (uint256 feeAmount)
//    {
//        Ledger storage ledger = userLedger[user][yieldSource];
//        uint256 len = ledger.entries.length;
//        if (len == 0) return 0;
//
//        OutflowContext memory ctx;
//        ctx.remainingShares = usedShares;
//        ctx.currentIndex = userLedger[user][yieldSource].unconsumedEntries;
//        ctx.decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource);
//
//        while (ctx.remainingShares > 0) {
//            if (ctx.currentIndex >= len) revert INSUFFICIENT_SHARES();
//
//            LedgerEntry storage entry = ledger.entries[ctx.currentIndex];
//            uint256 availableShares = entry.amountSharesAvailableToConsume;
//
//            // If no shares available in current entry, move to the next
//            if (availableShares == 0) {
//                unchecked {
//                    ++ctx.currentIndex;
//                }
//                continue;
//            }
//
//            // Remove from current entry
//            uint256 sharesConsumed = availableShares > ctx.remainingShares ? ctx.remainingShares : availableShares;
//            entry.amountSharesAvailableToConsume -= sharesConsumed;
//            ctx.remainingShares -= sharesConsumed;
//
//            // amount of assets in the entry price (registered at the INFLOW operation)
//            uint256 entryBasis = sharesConsumed * entry.price / (10 ** ctx.decimals);
//
//            // current price of the yield source
//            uint256 ppsNow = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);
//            // amount of assets in the current price
//            uint256 currentBasis = sharesConsumed * ppsNow / (10 ** ctx.decimals);
//
//            // if pps increased => currentBasis > entryBasis
//            //   otherwise profit = 0 because the current price is lower than INFLOW price of the entry
//            if (currentBasis > entryBasis) {
//                ctx.profit += (currentBasis - entryBasis);
//            }
//
//            if (sharesConsumed == availableShares) {
//                unchecked {
//                    ++ctx.currentIndex;
//                }
//            }
//        }
//        userLedger[user][yieldSource].unconsumedEntries = ctx.currentIndex;
//        if (ctx.profit > 0) {
//            if (config.feePercent == 0) revert FEE_NOT_SET();
//
//            // Calculate fee in assets but don't transfer - let the executor handle it
//            feeAmount = (ctx.profit * config.feePercent) / 10_000;
//        }
//    }
}
