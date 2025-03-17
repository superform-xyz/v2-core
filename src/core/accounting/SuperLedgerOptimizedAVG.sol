// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BaseLedger } from "./BaseLedger.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { SuperLedgerConfiguration } from "./SuperLedgerConfiguration.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";


// NOTE: Atm we can leave these here for testing, we'll look for a better place later
struct LedgerEntryAlternative {
    uint256 accumulatorShares;
    uint256 accumulatorCostBasis;
}

struct LedgerAlternative {
    LedgerEntryAlternative[] entries;
    uint256 unconsumedEntries;
}


/// @title SuperLedger
/// @author Superform Labs
/// @notice Default ISuperLedger implementation
contract SuperLedgerOptimizedAVG is BaseLedger {

    constructor(address registry_) BaseLedger(registry_) { }

    mapping(address user => mapping(address yieldSource => LedgerAlternative ledger)) internal userLedgerAlternative;


    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
//////////////////////////////////////////////////////////////*/

    function _takeSnapshot(
        address user,
        address yieldSource,
        uint256 amountShares,
        uint256 pps,
        uint256 decimals
    ) override internal {
        // Always inscribe in the ledger, even if feePercent is set to 0
        // NOTE: Assuming `amountSharesOrAssets` is actually an amount of shares like in the original code
        uint256 prevAccumulatorShares = userLedgerAlternative[user][yieldSource].entries.length == 0 ? 0 : userLedgerAlternative[user][yieldSource].entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorShares;

        uint256 prevAccumulatorCostBasis = userLedgerAlternative[user][yieldSource].entries.length == 0 ? 0 : userLedgerAlternative[user][yieldSource].entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorCostBasis;

//        uint256 costBasis = amountSharesOrAssets * pps / (10 ** IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource));

        uint256 costBasis = amountShares * pps / (10 ** decimals);

        userLedgerAlternative[user][yieldSource].entries.push(
            LedgerEntryAlternative({ accumulatorShares: prevAccumulatorShares + amountShares, accumulatorCostBasis: prevAccumulatorCostBasis + costBasis })
        );
    }

    function _calculateAvgCostBasisView(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) internal view returns (uint256 costBasis) {
        LedgerAlternative storage ledger = userLedgerAlternative[user][yieldSource];
        if (ledger.entries.length == 0) {
            return 0;
        }
        uint256 accumulatorShares = ledger.entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorShares;
        uint256 accumulatorCostBasis = ledger.entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorCostBasis;

        // TODO: Check if good error message
        if(usedShares > accumulatorShares) revert("INSUFFICIENT_SHARES");

        // avgEntryPrice = accumulatorCostBasis / accumulatorShares
        // TODO: Adjust precision?
        costBasis = accumulatorCostBasis * usedShares / accumulatorShares;
    }

    function _calculateAvgCostBasis(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) internal returns (uint256 costBasis) {
        costBasis = _calculateAvgCostBasisView(user, yieldSource, amountAssets, usedShares, config);

        // Update the ledger if necessary
        if (userLedgerAlternative[user][yieldSource].entries.length > 0) {
            LedgerAlternative storage ledger = userLedgerAlternative[user][yieldSource];

            ledger.entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorShares -= usedShares;

            ledger.entries[userLedgerAlternative[user][yieldSource].entries.length - 1].accumulatorCostBasis -= costBasis;
        }
    }

    function calculateCostBasisView(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) override public view
    returns (uint256 costBasis) {
        costBasis = _calculateAvgCostBasisView(user, yieldSource, amountAssets, usedShares, config);
    }

    function _calculateCostBasis(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) override internal
    returns (uint256 costBasis) {
        costBasis = _calculateAvgCostBasis(user, yieldSource, amountAssets, usedShares, config);
    }

}
