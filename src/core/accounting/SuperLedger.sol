// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract SuperLedger is ISuperLedger, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) private userLedger;

    /// @notice Yield source oracle configurations
    mapping(bytes32 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfig;

    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
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
        YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracleId];

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
                feeAmount = _processOutflow(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets, usedShares);

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
                config.yieldSourceOracleId, config.yieldSourceOracle, config.feePercent, config.feeRecipient
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
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setYieldSourceOracleConfig(
        bytes32 yieldSourceOracleId,
        address yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient
    )
        internal
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
            manager: msg.sender
        });

        emit YieldSourceOracleConfigSet(yieldSourceOracleId, yieldSourceOracle, feePercent, msg.sender, feeRecipient);
    }

     function _processOutflow(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        uint256 amountAssets,
        uint256 usedShares
    )
        internal
        returns (uint256 feeAmount)

    {
        uint256 remainingShares = usedShares;
        uint256 costBasis;

        LedgerEntry[] storage entries = userLedger[user][yieldSource].entries;
        uint256 len = entries.length;
        if (len == 0) return 0;


        uint256 currentIndex = userLedger[user][yieldSource].unconsumedEntries;

        while (remainingShares > 0) {
            if (currentIndex >= len) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = entries[currentIndex];
            uint256 availableShares = entry.amountSharesAvailableToConsume;

            // if no shares available on current entry, move to the next
            if (availableShares == 0) {
                unchecked {
                    ++currentIndex;
                }
                continue;
            }
            
            address yieldSourceOracle = yieldSourceOracleConfig[yieldSourceOracleId].yieldSourceOracle;
            uint256 decimals = IYieldSourceOracle(yieldSourceOracle).decimals(yieldSource);

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
            YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracleId];
            if (config.feePercent == 0) revert FEE_NOT_SET();


            // Calculate fee in assets but don't transfer - let the executor handle it
            feeAmount = (profit * config.feePercent) / 10_000;
        }
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
