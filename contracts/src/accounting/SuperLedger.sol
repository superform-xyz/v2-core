// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperLedger is ISuperLedger, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) private userLedger;

    /// @notice Yield source oracle configurations
    mapping(address yieldSourceOracle => YieldSourceOracleConfig config) private yieldSourceOracleConfig;

    modifier onlyExecutor() {
        console2.log("msg.sender", msg.sender);
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
        address yieldSourceOracle,
        address yieldSource,
        bool isInflow,
        uint256 amount
    )
        external
        onlyExecutor
        returns (uint256 pps)
    {
        YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracle];
        if (config.manager == address(0)) revert MANAGER_NOT_SET();

        // Get price from oracle
        pps = IYieldSourceOracle(yieldSourceOracle).getPricePerShare(yieldSource);
        if (pps == 0) revert INVALID_PRICE();

        if (isInflow) {
            userLedger[user][yieldSource].entries.push(
                LedgerEntry({ amountSharesAvailableToConsume: amount, price: pps })
            );
        } else {
            _processOutflow(user, yieldSource, yieldSourceOracle, amount, pps);
        }

        emit AccountingUpdated(user, yieldSourceOracle, yieldSource, isInflow, amount, pps);
    }

    /// @inheritdoc ISuperLedger
    function setYieldSourceOracles(HookRegistrationConfig[] calldata configs) external {
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length;) {
            HookRegistrationConfig calldata config = configs[i];
            _setYieldSourceOracleConfig(
                config.mainHooks,
                config.yieldSourceOracle,
                config.feePercent,
                config.vaultShareToken,
                config.feeRecipient
            );
            unchecked {
                ++i;
            }
        }
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
        Ledger storage ledger = userLedger[user][yieldSource];
        return (ledger.entries, ledger.unconsumedEntries);
    }

    /// @inheritdoc ISuperLedger
    function getYieldSourceOracleConfig(address yieldSourceOracle)
        external
        view
        returns (YieldSourceOracleConfig memory)
    {
        return yieldSourceOracleConfig[yieldSourceOracle];
    }

    /// @inheritdoc ISuperLedger
    function getYieldSourceOracleConfigs(address[] calldata yieldSourceOracles)
        external
        view
        returns (YieldSourceOracleConfig[] memory configs)
    {
        uint256 length = yieldSourceOracles.length;

        configs = new YieldSourceOracleConfig[](length);
        for (uint256 i; i < length;) {
            configs[i] = yieldSourceOracleConfig[yieldSourceOracles[i]];
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setYieldSourceOracleConfig(
        address[] calldata mainHooks,
        address yieldSourceOracle,
        uint256 feePercent,
        address vaultShareToken,
        address feeRecipient
    )
        internal
    {
        if (yieldSourceOracle == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feeRecipient == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feePercent > 10_000) revert INVALID_FEE_PERCENT();

        // Only allow updates if no config exists or if caller is the manager
        YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[yieldSourceOracle];
        if (existingConfig.manager != address(0) && msg.sender != existingConfig.manager) revert NOT_MANAGER();

        yieldSourceOracleConfig[yieldSourceOracle] = YieldSourceOracleConfig({
            mainHooks: mainHooks,
            feePercent: feePercent,
            vaultShareToken: vaultShareToken,
            feeRecipient: feeRecipient,
            manager: msg.sender
        });

        emit YieldSourceOracleConfigSet(yieldSourceOracle, feePercent, vaultShareToken, msg.sender, feeRecipient);
    }

    function _processOutflow(
        address user,
        address yieldSource,
        address yieldSourceOracle,
        uint256 amountShares,
        uint256 pps
    )
        internal
    {
        uint256 remainingShares = amountShares;
        uint256 totalValue = amountShares * pps;
        uint256 costBasis;

        uint256 currentIndex = userLedger[user][yieldSource].unconsumedEntries;
        LedgerEntry[] storage entries = userLedger[user][yieldSource].entries;

        while (remainingShares > 0) {
            if (currentIndex >= entries.length) revert INSUFFICIENT_SHARES();

            LedgerEntry storage entry = entries[currentIndex];
            uint256 available = entry.amountSharesAvailableToConsume;

            if (available == 0) {
                unchecked {
                    ++currentIndex;
                }
                continue;
            }

            uint256 sharesConsumed = remainingShares > available ? available : remainingShares;
            costBasis += sharesConsumed * entry.price;
            remainingShares -= sharesConsumed;
            entry.amountSharesAvailableToConsume -= sharesConsumed;

            if (sharesConsumed == available) {
                unchecked {
                    ++currentIndex;
                }
            }
        }

        userLedger[user][yieldSource].unconsumedEntries = currentIndex;

        uint256 profit = totalValue > costBasis ? totalValue - costBasis : 0;
        if (profit > 0) {
            YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracle];
            if (config.feePercent == 0) revert FEE_NOT_SET();

            uint256 feeAmount = (profit * config.feePercent) / 10_000;
            address vaultShareToken = config.vaultShareToken != address(0) ? config.vaultShareToken : yieldSource;
            _transferToFeeRecipient(config.feeRecipient, feeAmount, vaultShareToken);
        }
    }

    function _transferToFeeRecipient(address feeRecipient, uint256 feeAmount, address vaultShareToken) internal {
        IERC20(vaultShareToken).safeTransfer(feeRecipient, feeAmount);
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
