// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { ILedgerFees } from "../interfaces/accounting/ILedgerFees.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import "forge-std/console.sol";
contract SuperLedger is ISuperLedger, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct ProcessOutflowVars {
        uint256 remainingShares;
        uint256 costBasis;
        uint256 lastEntrySharesToRemove;
        uint256 lastEntryIndex;
        uint256 currentIndex;
        address yieldSourceOracle;
        uint256 decimals;
    }

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) private userLedger;

    /// @notice Yield source oracle configurations
    mapping(bytes32 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfig;

    modifier onlyExecutor() {
        if (_getAddress(keccak256("SUPER_EXECUTOR_ID")) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperLedger
    function updateAccounting(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        onlyExecutor
        returns (uint256 feeAmount)
    {
        console.log("---------A");
        YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracleId];
        console.log("---------B");

        if (config.manager == address(0)) revert MANAGER_NOT_SET();
        console.log("---------C");

        if (isInflow) {
        console.log("---------D");
            // Get price from oracle
            uint256 pps = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);
        console.log("---------E");
            if (pps == 0) revert INVALID_PRICE();

            // Always inscribe in the ledger, even if feePercent is set to 0
            userLedger[user][yieldSource].entries.push(
                LedgerEntry({ amountSharesAvailableToConsume: amountSharesOrAssets, price: pps })
            );
        console.log("---------F");
            emit AccountingInflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, pps);
            return 0;
        } else {
            // Only process outflow if feePercent is not set to 0
        console.log("---------G");
            if (config.feePercent != 0) {
        console.log("---------H");
                feeAmount = _processOutflow(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets, usedShares);
        console.log("---------I");

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }

    /// @inheritdoc ISuperLedger
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external {
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length;) {
            YieldSourceOracleConfigArgs calldata config = configs[i];
            _setYieldSourceOracleConfig(
                config.yieldSourceOracleId, config.yieldSourceOracle, config.feePercent, config.feeRecipient, config.feeHelper
            );
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
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
        Ledger storage ledger = userLedger[user][yieldSource];
        return (ledger.entries, ledger.unconsumedEntries);
    }

    /// @inheritdoc ISuperLedger
    function getYieldSourceOracleConfig(bytes32 yieldSourceOracleId)
        external
        view
        returns (YieldSourceOracleConfig memory)
    {
        return yieldSourceOracleConfig[yieldSourceOracleId];
    }

    /// @inheritdoc ISuperLedger
    function getYieldSourceOracleConfigs(bytes32[] calldata yieldSourceOracleIds)
        external
        view
        returns (YieldSourceOracleConfig[] memory configs)
    {
        uint256 length = yieldSourceOracleIds.length;

        configs = new YieldSourceOracleConfig[](length);
        for (uint256 i; i < length;) {
            configs[i] = yieldSourceOracleConfig[yieldSourceOracleIds[i]];
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _setYieldSourceOracleConfig(
        bytes32 yieldSourceOracleId,
        address yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient,
        address feeHelper
    )
        private
    {
        if (yieldSourceOracle == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feeRecipient == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feePercent > 10_000) revert INVALID_FEE_PERCENT();
        if (yieldSourceOracleId == bytes32(0)) revert ZERO_ID_NOT_ALLOWED();

        // Only allow updates if no config exists or if caller is the manager
        YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[yieldSourceOracleId];
        if (existingConfig.manager != address(0) && msg.sender != existingConfig.manager) revert NOT_MANAGER();

        yieldSourceOracleConfig[yieldSourceOracleId] = YieldSourceOracleConfig({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            manager: msg.sender,
            feeHelper: feeHelper
        });

        emit YieldSourceOracleConfigSet(yieldSourceOracleId, yieldSourceOracle, feePercent, msg.sender, feeRecipient);
    }


    function _processOutflow(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        uint256 amountAssets,
        uint256 usedShares
    ) private returns (uint256 feeAmount) {
        ProcessOutflowVars memory vars;
        vars.remainingShares = usedShares;
        vars.currentIndex = userLedger[user][yieldSource].unconsumedEntries;
        vars.yieldSourceOracle = yieldSourceOracleConfig[yieldSourceOracleId].yieldSourceOracle;
        vars.decimals = IYieldSourceOracle(vars.yieldSourceOracle).decimals(yieldSource);

        LedgerEntry[] storage entries = userLedger[user][yieldSource].entries;
        uint256 len = entries.length;
        if (len == 0) return 0;

        while (vars.remainingShares > 0) {
            if (vars.currentIndex >= len) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = entries[vars.currentIndex];
            uint256 availableShares = entry.amountSharesAvailableToConsume;

            // If no shares available, move to the next entry
            if (availableShares == 0) {
                unchecked {
                    ++vars.currentIndex;
                }
                continue;
            }

            // Determine shares to consume
            uint256 sharesConsumed = availableShares > vars.remainingShares ? vars.remainingShares : availableShares;
            vars.remainingShares -= sharesConsumed;

            vars.costBasis += sharesConsumed * entry.price / (10 ** vars.decimals);
            vars.lastEntrySharesToRemove = sharesConsumed;
            vars.lastEntryIndex = vars.currentIndex;

            if (sharesConsumed == availableShares) {
                unchecked {
                    ++vars.currentIndex;
                }
            }
        }

        // Update storage
        userLedger[user][yieldSource].unconsumedEntries = vars.currentIndex;
        entries[vars.lastEntryIndex].amountSharesAvailableToConsume -= vars.lastEntrySharesToRemove;

        // Compute fees
        feeAmount = ILedgerFees(yieldSourceOracleConfig[yieldSourceOracleId].feeHelper).computeFees(
            vars.costBasis, amountAssets, yieldSourceOracleConfig[yieldSourceOracleId].feePercent
        );
    }


    function _getAddress(bytes32 id_) private view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
