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

//    mapping(address user => mapping(address yieldSource => LedgerAlternative ledger)) internal userLedgerAlternative;

    mapping(address user => uint256) public usersAccumulatorShares;
    mapping(address user => uint256) public usersAccumulatorCostBasis;


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
        usersAccumulatorShares[user] += amountShares;
        usersAccumulatorCostBasis[user] += amountShares * pps / (10 ** decimals);
    }

    function _calculateAvgCostBasisView(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) internal view returns (uint256 costBasis) {
        uint256 accumulatorShares = usersAccumulatorShares[user];
        uint256 accumulatorCostBasis = usersAccumulatorCostBasis[user];

        // TODO: Check if this is a good error message
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

        usersAccumulatorShares[user] -= usedShares;
        usersAccumulatorCostBasis[user] -= costBasis;
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
