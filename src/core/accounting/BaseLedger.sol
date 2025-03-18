// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { SuperLedgerConfiguration } from "./SuperLedgerConfiguration.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

/// @title BaseLedger
/// @author Superform Labs
/// @notice Base ledger contract for managing user ledger entries
abstract contract BaseLedger is ISuperLedger {
    using SafeERC20 for IERC20;
    using Math for uint256;

    SuperLedgerConfiguration public immutable superLedgerConfiguration;

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) internal userLedger;

    mapping(address user => uint256) public usersAccumulatorShares;
    mapping(address user => uint256) public usersAccumulatorCostBasis;


    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        superLedgerConfiguration = SuperLedgerConfiguration(superLedgerConfiguration_);
    }

    modifier onlyExecutor() {
        if (_getAddress(keccak256("SUPER_EXECUTOR_ID")) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

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

    function updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        returns (uint256 feeAmount)
    {
        return _updateAccounting(user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getLedger(
        address user,
        address yieldSource
    )
        internal
        view
        virtual
        returns (LedgerEntry[] memory entries, uint256 unconsumedEntries)
    {
        Ledger storage ledger = userLedger[user][yieldSource];
        return (ledger.entries, ledger.unconsumedEntries);
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        ISuperRegistry registry = ISuperRegistry(superLedgerConfiguration.superRegistry());
        return registry.getAddress(id_);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/





    ///// AVG Implementation /////
    function _takeSnapshot(
        address user,
        address yieldSource,
        uint256 amountShares,
        uint256 pps,
        uint256 decimals
    ) virtual internal {
        usersAccumulatorShares[user] += amountShares;
        usersAccumulatorCostBasis[user] += amountShares * pps / (10 ** decimals);
    }

    function _calculateAvgCostBasisView(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) internal view returns (uint256 costBasis) {
        uint256 accumulatorShares = usersAccumulatorShares[user];
        uint256 accumulatorCostBasis = usersAccumulatorCostBasis[user];
        
        if(usedShares > accumulatorShares) revert INSUFFICIENT_SHARES();

        // avgEntryPrice = accumulatorCostBasis / accumulatorShares
//        costBasis = accumulatorCostBasis * usedShares / accumulatorShares;
        costBasis = Math.mulDiv(accumulatorCostBasis, usedShares, accumulatorShares);
    }

    function _calculateAvgCostBasis(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) internal returns (uint256 costBasis) {
        costBasis = _calculateAvgCostBasisView(user, yieldSource, amountAssets, usedShares);
        console.log("_calculateAvgCostBasis() costBasis", costBasis);

        usersAccumulatorShares[user] -= usedShares;
        usersAccumulatorCostBasis[user] -= costBasis;
    }

    function calculateCostBasisView(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) virtual public view
    returns (uint256 costBasis) {
            costBasis = _calculateAvgCostBasisView(user, yieldSource, amountAssets, usedShares
//                config
            );
    }

    function _calculateCostBasis(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) virtual internal
    returns (uint256 costBasis) {
        costBasis = _calculateAvgCostBasis(user, yieldSource, amountAssets, usedShares);
    }


    ///// FIFO Implementation /////
//    function _takeSnapshot(
//    address user,
//    address yieldSource,
//    uint256 amountShares,
//    uint256 pps, uint256 decimals
//    ) virtual internal {
//        // Always inscribe in the ledger, even if feePercent is set to 0
//        userLedger[user][yieldSource].entries.push(
//            LedgerEntry({ amountSharesAvailableToConsume: amountShares, price: pps })
//        );
//    }
//
//    struct OutflowVars {
//        uint256 remainingShares;
//        uint256 costBasis;
//        uint256 len;
//        uint256 currentIndex;
//        uint256 lastIndex;
//        uint256 lastSharesConsumed;
//        uint256 decimals;
//    }
//
//    function _calculateFIFOCostBasisView(
//        address user,
//        address yieldSource,
//        uint256 amountAssets,
//        uint256 usedShares,
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
//    ) internal view
//    returns (OutflowVars memory vars) {
//        Ledger storage ledger = userLedger[user][yieldSource];
//
//        vars = OutflowVars({
//            remainingShares: usedShares,
//            costBasis: 0,
//            len: ledger.entries.length,
//            currentIndex: userLedger[user][yieldSource].unconsumedEntries,
//            lastIndex: 0,
//            lastSharesConsumed: 0,
//            decimals: IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource)
//        });
//
//        if (vars.len == 0) return vars;
//        vars.lastIndex = vars.currentIndex;
//
//        while (vars.remainingShares > 0) {
//            if (vars.currentIndex >= vars.len) revert INSUFFICIENT_SHARES();
//
//            LedgerEntry storage entry = ledger.entries[vars.currentIndex];
//            uint256 availableShares = entry.amountSharesAvailableToConsume;
//
//            if (availableShares == 0) {
//                unchecked {
//                    ++vars.currentIndex;
//                }
//                continue;
//            }
//
//            uint256 sharesConsumed = availableShares > vars.remainingShares ? vars.remainingShares : availableShares;
//
//            vars.lastIndex = vars.currentIndex;
//            vars.lastSharesConsumed = sharesConsumed;
//            vars.remainingShares -= sharesConsumed;
//
//            vars.costBasis += sharesConsumed * entry.price / (10 ** vars.decimals);
//
//            if (sharesConsumed == availableShares) {
//                unchecked {
//                    ++vars.currentIndex;
//                }
//            }
//        }
//    }
//
//    function _calculateFIFOCostBasis(
//        address user,
//        address yieldSource,
//        uint256 amountAssets,
//        uint256 usedShares,
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
//    ) internal
//    returns (uint256 costBasis) {
//        OutflowVars memory vars = _calculateFIFOCostBasisView(user, yieldSource, amountAssets, usedShares, config);
//
//        costBasis = vars.costBasis;
//        console.log("_calculateFIFOCostBasis() costBasis = ", costBasis);
//
//        if(vars.len > 0) {
//            Ledger storage ledger = userLedger[user][yieldSource];
//
//            ledger.entries[vars.lastIndex].amountSharesAvailableToConsume -= vars.lastSharesConsumed;
//            userLedger[user][yieldSource].unconsumedEntries = vars.currentIndex;
//        }
//    }
//
//    function calculateCostBasisView(
//        address user,
//        address yieldSource,
//        uint256 amountAssets,
//        uint256 usedShares,
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
//    ) virtual public view
//    returns (uint256 costBasis) {
//        costBasis = _calculateFIFOCostBasisView(user, yieldSource, amountAssets, usedShares, config).costBasis;
//    }
//
//    function _calculateCostBasis(
//        address user,
//        address yieldSource,
//        uint256 amountAssets,
//        uint256 usedShares,
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
//    ) virtual internal
//    returns (uint256 costBasis) {
//        costBasis = _calculateFIFOCostBasis(user, yieldSource, amountAssets, usedShares, config);
//    }


    //////////////////// Fees ////////////////////

    function _calculateFees(
        uint256 costBasis,
        uint256 amountAssets,
        uint256 feePercent
    ) internal pure returns(uint256 feeAmount) {
        uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
        if (profit > 0) {
            if (feePercent == 0) revert FEE_NOT_SET();
//            feeAmount = (profit * feePercent) / 10_000;
            feeAmount = Math.mulDiv(profit, feePercent, 10_000);
        }
    }

    function previewFees(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        uint256 feePercent
//        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    ) public view returns(uint256 feeAmount) {
        uint256 costBasis = calculateCostBasisView(user, yieldSource, amountAssets, usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, feePercent);
    }


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
//            userLedger[user][yieldSource].entries.push(
//                LedgerEntry({ amountSharesAvailableToConsume: amountSharesOrAssets, price: pps })
//            );
            _takeSnapshot(user, yieldSource, amountSharesOrAssets, pps, IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource));

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
    virtual
    internal
    returns (uint256 feeAmount) {
        uint256 costBasis = _calculateCostBasis(user, yieldSource, amountAssets, usedShares);
            feeAmount = _calculateFees(costBasis, amountAssets, config.feePercent);
    }
}
