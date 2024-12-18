// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperActions } from "../interfaces/strategies/ISuperActions.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IActionOracle } from "../interfaces/strategies/IActionOracle.sol";

contract SuperActions is ISuperActions, SuperRegistryImplementer {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 actionId => ActionLogic) private actionLogic;
    mapping(bytes32 yieldSourceId => address oracle) private yieldSourceToOracle;
    mapping(address user => mapping(bytes32 yieldSourceId => mapping(address finalTarget => LedgerEntry[]))) private
        userLedgerEntries;
    mapping(address user => mapping(bytes32 yieldSourceId => mapping(address finalTarget => uint256))) private
        unconsumedEntries;
    mapping(bytes32 yieldSourceId => mapping(address finalTarget => StrategyConfig strategyConfig)) private
        strategyConfiguration;
    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyActionsConfigurator() {
        ISuperRbac rbac = ISuperRbac(_getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SUPER_ACTIONS_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperActions
    function updateAccounting(
        address user_,
        uint256 actionId_,
        address finalTarget_,
        bool isDeposit_,
        uint256 amountShares_
    )
        external
        onlyExecutor
        returns (uint256 pps_)
    {
        pps_ = _processAccounting(user_, actionId_, finalTarget_, isDeposit_, amountShares_);
        emit AccountingUpdated(user_, actionId_, finalTarget_, isDeposit_, amountShares_, pps_);
    }

    /// @inheritdoc ISuperActions
    function batchUpdateAccounting(
        address user_,
        uint256[] memory actionIds_,
        address[] memory finalTargets_,
        bool[] memory isDeposits_,
        uint256[] memory amountsShares_
    )
        external
        onlyExecutor
        returns (uint256[] memory pps_)
    {
        uint256 len = actionIds_.length;
        if (len != finalTargets_.length || len != isDeposits_.length || len != amountsShares_.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        pps_ = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            pps_[i] = _processAccounting(user_, actionIds_[i], finalTargets_[i], isDeposits_[i], amountsShares_[i]);
        }

        emit BatchAccountingUpdated(user_, actionIds_, finalTargets_, isDeposits_, amountsShares_, pps_);
    }

    /// @inheritdoc ISuperActions
    function registerAction(
        address[] memory hooks_,
        string calldata yieldSourceId_
    )
        external
        onlyActionsConfigurator
        returns (uint256 actionId_)
    {
        actionId_ = _registerSingleAction(hooks_, yieldSourceId_);
        emit ActionRegistered(actionId_, hooks_, yieldSourceId_);
    }

    // Update batch register to use string IDs
    function batchRegisterActions(
        address[][] memory hooks_,
        string[] calldata yieldSourceIds_
    )
        external
        onlyActionsConfigurator
        returns (uint256[] memory actionIds_)
    {
        uint256 len = hooks_.length;
        if (len != yieldSourceIds_.length) revert INVALID_ARRAY_LENGTH();

        actionIds_ = new uint256[](len);
        for (uint256 i; i < len;) {
            actionIds_[i] = _registerSingleAction(hooks_[i], yieldSourceIds_[i]);
            unchecked {
                ++i;
            }
        }

        emit ActionBatchRegistered(actionIds_, yieldSourceIds_);
    }

    /// @inheritdoc ISuperActions
    function updateAction(
        uint256 actionId_,
        string calldata yieldSourceId_,
        address[] memory newHooks_
    )
        external
        onlyActionsConfigurator
    {
        ActionLogic storage logic = _getActionLogicOrRevert(actionId_);
        bytes32 yieldSourceId = keccak256(abi.encode(yieldSourceId_));
        if (yieldSourceToOracle[yieldSourceId] == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        _validateHooks(newHooks_);

        logic.yieldSourceId = yieldSourceId;
        logic.hooks = newHooks_;

        emit ActionUpdated(actionId_, newHooks_, yieldSourceId_);
    }

    /// @inheritdoc ISuperActions
    function batchUpdateAction(
        uint256[] memory actionIds_,
        string[] calldata yieldSourceIds_,
        address[][] memory newHooks_
    )
        external
        onlyActionsConfigurator
    {
        uint256 len = actionIds_.length;
        if (len != yieldSourceIds_.length || len != newHooks_.length) revert INVALID_ARRAY_LENGTH();

        for (uint256 i = 0; i < len; i++) {
            ActionLogic storage logic = _getActionLogicOrRevert(actionIds_[i]);
            if (bytes(yieldSourceIds_[i]).length == 0) revert EMPTY_YIELD_SOURCE_ID();

            _validateHooks(newHooks_[i]);

            logic.yieldSourceId = keccak256(abi.encode(yieldSourceIds_[i]));
            logic.hooks = newHooks_[i];
        }
        emit ActionBatchUpdated(actionIds_, newHooks_, yieldSourceIds_);
    }

    /// @inheritdoc ISuperActions
    function delistAction(uint256 actionId_) external onlyActionsConfigurator {
        delete actionLogic[actionId_];
        emit ActionDelisted(actionId_);
    }

    /// @inheritdoc ISuperActions
    function batchDelistActions(uint256[] memory actionIds_) external onlyActionsConfigurator {
        for (uint256 i = 0; i < actionIds_.length; i++) {
            delete actionLogic[actionIds_[i]];
        }
        emit ActionBatchDelisted(actionIds_);
    }

    /// @inheritdoc ISuperActions
    function registerYieldSource(
        string calldata yieldSourceId_,
        address metadataOracle_
    )
        external
        onlyActionsConfigurator
    {
        _registerSingleYieldSource(yieldSourceId_, metadataOracle_);
    }

    /// @inheritdoc ISuperActions
    function batchRegisterYieldSources(
        string[] calldata yieldSourceIds_,
        address[] calldata metadataOracles_
    )
        external
        onlyActionsConfigurator
    {
        uint256 len = yieldSourceIds_.length;
        if (len != metadataOracles_.length) revert INVALID_ARRAY_LENGTH();

        for (uint256 i; i < len;) {
            _registerSingleYieldSource(yieldSourceIds_[i], metadataOracles_[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ISuperActions
    function setStrategyConfig(
        string calldata yieldSourceId_,
        address finalTarget_,
        uint256 feePercent_,
        address vaultShareToken_
    )
        external
        onlyActionsConfigurator
    {
        _setStrategyConfig(yieldSourceId_, finalTarget_, feePercent_, vaultShareToken_);
    }

    /// @inheritdoc ISuperActions
    function batchSetStrategyConfig(
        string[] calldata yieldSourceIds_,
        address[] memory finalTargets_,
        uint256[] memory feePercents_,
        address[] memory vaultShareTokens_
    )
        external
        onlyActionsConfigurator
    {
        uint256 len = yieldSourceIds_.length;
        if (len != finalTargets_.length || len != feePercents_.length || len != vaultShareTokens_.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        for (uint256 i = 0; i < len; i++) {
            _setStrategyConfig(yieldSourceIds_[i], finalTargets_[i], feePercents_[i], vaultShareTokens_[i]);
        }
    }
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperActions
    function getActionLogic(uint256 actionId_) public view returns (ActionLogic memory) {
        ActionLogic memory logic = actionLogic[actionId_];
        if (logic.yieldSourceId == bytes32(0)) revert ACTION_NOT_FOUND();
        return logic;
    }

    /// @inheritdoc ISuperActions
    function getHooksForAction(uint256 actionId_) external view returns (address[] memory) {
        return _getActionLogicOrRevert(actionId_).hooks;
    }

    /// @inheritdoc ISuperActions
    function getOracleForAction(uint256 actionId_) external view returns (address oracle_) {
        ActionLogic memory logic = _getActionLogicOrRevert(actionId_);
        return yieldSourceToOracle[logic.yieldSourceId];
    }

    /// @inheritdoc ISuperActions
    function isActionActive(uint256 actionId_) external view returns (bool) {
        return actionLogic[actionId_].hooks.length != 0;
    }

    /// @inheritdoc ISuperActions
    function getStrategiesMetadata(
        uint256[] memory actionIds_,
        address[] memory finalTargets_
    )
        external
        view
        returns (bytes[] memory result_)
    {
        // Implementation needed
    }
    /// @inheritdoc ISuperActions

    function getUserAccounting(
        address user_,
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (LedgerEntry[] memory)
    {
        bytes32 yieldSourceId = keccak256(abi.encode(yieldSourceId_));
        return userLedgerEntries[user_][yieldSourceId][finalTarget_];
    }

    /// @inheritdoc ISuperActions
    function getUnconsumedEntries(
        address user_,
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (uint256)
    {
        bytes32 yieldSourceId = keccak256(abi.encode(yieldSourceId_));
        return unconsumedEntries[user_][yieldSourceId][finalTarget_];
    }

    /// @inheritdoc ISuperActions
    function getStrategyConfig(
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (StrategyConfig memory)
    {
        bytes32 yieldSourceId = keccak256(abi.encode(yieldSourceId_));
        return strategyConfiguration[yieldSourceId][finalTarget_];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to validate hooks and return an action id
    /// @param hooks_ The hooks to validate
    /// @return actionId_ The ID of the action
    function _validateHooks(address[] memory hooks_) internal pure returns (uint256 actionId_) {
        uint256 len = hooks_.length;
        if (len == 0) revert INVALID_HOOKS_LENGTH();

        for (uint256 i = 0; i < len; i++) {
            if (hooks_[i] == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        }

        // Hash the hooks addresses to generate actionId
        actionId_ = uint256(keccak256(abi.encode(hooks_)));
    }

    /// @dev Internal function to register a single action
    /// @param hooks_ Array of hook addresses
    /// @param yieldSourceId_ Yield source identifier
    /// @return actionId_ The generated action ID
    function _registerSingleAction(
        address[] memory hooks_,
        string calldata yieldSourceId_
    )
        internal
        returns (uint256 actionId_)
    {
        actionId_ = _validateHooks(hooks_);
        bytes32 yieldSourceIdBytes = keccak256(abi.encode(yieldSourceId_));

        if (actionLogic[actionId_].hooks.length != 0) revert ACTION_ALREADY_EXISTS();
        if (yieldSourceToOracle[yieldSourceIdBytes] == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        actionLogic[actionId_] = ActionLogic({ yieldSourceId: yieldSourceIdBytes, hooks: hooks_ });
    }

    /// @dev Internal function to register a single yield source
    /// @param yieldSourceId_ The yield source identifier
    /// @param metadataOracle_ The oracle address
    function _registerSingleYieldSource(string calldata yieldSourceId_, address metadataOracle_) internal {
        if (metadataOracle_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

        bytes32 yieldSourceIdBytes = keccak256(abi.encode(yieldSourceId_));
        if (yieldSourceToOracle[yieldSourceIdBytes] != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

        yieldSourceToOracle[yieldSourceIdBytes] = metadataOracle_;
        emit YieldSourceRegistered(yieldSourceId_, metadataOracle_);
    }

    /// @dev Internal function to process accounting
    /// @param user_ The user address
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @param isDeposit_ Whether this is a deposit operation
    /// @param amountShares_ The amount of shares to process
    /// @return pps_ The price per share at which the accounting was updated
    function _processAccounting(
        address user_,
        uint256 actionId_,
        address finalTarget_,
        bool isDeposit_,
        uint256 amountShares_
    )
        internal
        returns (uint256 pps_)
    {
        ActionLogic memory logic = _getActionLogicOrRevert(actionId_);

        // Get current price from oracle
        pps_ = IActionOracle(yieldSourceToOracle[logic.yieldSourceId]).getStrategyPrice(finalTarget_);
        if (pps_ == 0) revert INVALID_PRICE();

        if (isDeposit_) {
            userLedgerEntries[user_][logic.yieldSourceId][finalTarget_].push(
                LedgerEntry({ amountSharesAvailableToConsume: amountShares_, price: pps_ })
            );
        } else {
            // For withdrawals, process FIFO accounting
            uint256 remainingShares = amountShares_;
            uint256 totalValue = amountShares_ * pps_;
            uint256 costBasis;

            LedgerEntry[] storage entries = userLedgerEntries[user_][logic.yieldSourceId][finalTarget_];
            uint256 currentIndex = unconsumedEntries[user_][logic.yieldSourceId][finalTarget_];

            while (remainingShares > 0) {
                if (currentIndex >= entries.length) revert INSUFFICIENT_SHARES();

                LedgerEntry storage entry = entries[currentIndex];
                uint256 availableShares = entry.amountSharesAvailableToConsume;

                if (availableShares == 0) {
                    unchecked {
                        ++currentIndex;
                    }
                    continue;
                }
                uint256 sharesConsumed = remainingShares > availableShares ? availableShares : remainingShares;

                costBasis += sharesConsumed * entry.price;
                remainingShares -= sharesConsumed;

                entry.amountSharesAvailableToConsume -= sharesConsumed;

                if (sharesConsumed == availableShares) {
                    unchecked {
                        ++currentIndex;
                    }
                }
            }

            unconsumedEntries[user_][logic.yieldSourceId][finalTarget_] = currentIndex;

            uint256 profit = totalValue > costBasis ? totalValue - costBasis : 0;
            if (profit > 0) {
                StrategyConfig memory config = strategyConfiguration[logic.yieldSourceId][finalTarget_];
                if (config.feePercent == 0) revert FEE_NOT_SET();

                uint256 feeAmount = (profit * config.feePercent) / 10_000;
                address vaultShareToken = config.vaultShareToken != address(0) ? config.vaultShareToken : finalTarget_;
                _transferToPaymaster(feeAmount, vaultShareToken);
            }
        }
    }

    /// @dev Internal function to transfer fee to paymaster
    /// @param feeAmount The amount of fee to transfer
    /// @param vaultShareToken The vault share token address
    function _transferToPaymaster(uint256 feeAmount, address vaultShareToken) internal {
        IERC20(vaultShareToken).safeTransfer(_getAddress(superRegistry.PAYMASTER_ID()), feeAmount);
    }

    /// @dev Internal function to get action logic or revert if not found
    /// @param actionId_ The ID of the action
    /// @return The action logic
    function _getActionLogicOrRevert(uint256 actionId_) internal view returns (ActionLogic storage) {
        ActionLogic storage logic = actionLogic[actionId_];
        if (logic.hooks.length == 0) revert ACTION_NOT_FOUND();
        return logic;
    }

    /// @dev Internal function to set strategy configuration
    /// @param yieldSourceId_ The yield source identifier
    /// @param finalTarget_ The target contract address
    /// @param feePercent_ The fee percentage for the strategy
    /// @param vaultShareToken_ The vault share token address
    function _setStrategyConfig(
        string calldata yieldSourceId_,
        address finalTarget_,
        uint256 feePercent_,
        address vaultShareToken_
    )
        internal
    {
        if (finalTarget_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (vaultShareToken_ != address(0) && vaultShareToken_ == finalTarget_) revert INVALID_VAULT_SHARE_TOKEN();

        bytes32 yieldSourceIdBytes = keccak256(abi.encode(yieldSourceId_));
        if (yieldSourceToOracle[yieldSourceIdBytes] == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        StrategyConfig memory config = StrategyConfig({ feePercent: feePercent_, vaultShareToken: vaultShareToken_ });
        strategyConfiguration[yieldSourceIdBytes][finalTarget_] = config;
        emit StrategyConfigSet(yieldSourceId_, finalTarget_, feePercent_, vaultShareToken_);
    }

    /// @dev Internal function to get address from super registry
    /// @param id_ The ID of the address
    /// @return The address
    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
