// SPDX-License-Identifier: MIT
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

abstract contract BaseLedger is ISuperLedger {
    using SafeERC20 for IERC20;

    SuperLedgerConfiguration public immutable superLedgerConfiguration;

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) internal userLedger;

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
        virtual
        view
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
    function _updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        internal
        onlyExecutor
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

    struct OutflowVars {
        uint256 remainingShares;
        uint256 costBasis;
        uint256 len;
        uint256 currentIndex;
        uint256 lastIndex;
        uint256 lastSharesConsumed;
        uint256 decimals;
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

}
