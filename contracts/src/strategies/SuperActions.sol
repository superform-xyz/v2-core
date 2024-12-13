// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";

contract SuperActions is ISuperActions, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 actionId => ActionLogic logic) private actionLogic;
    mapping(address user => mapping(uint256 actionId => mapping(address finalTarget => LedgerEntry[]))) private
        userLedgerEntries;
    mapping(address user => mapping(uint256 actionId => mapping(address finalTarget => uint256))) private
        unconsumedEntries;
    mapping(uint256 actionId => mapping(address finalTarget => uint256 feePercent)) private feePercentPerStrategy;

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyActionsConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SUPER_ACTIONS_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    modifier onlyExecutor() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.EXECUTOR())) revert NOT_AUTHORIZED();
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
        // Implementation needed
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

        // Implementation needed
        emit BatchAccountingUpdated(user_, actionIds_, finalTargets_, isDeposits_, amountsShares_, pps_);
    }

    /// @inheritdoc ISuperActions
    function registerAction(
        address[] memory hooks_,
        address metadataOracle_
    )
        external
        onlyActionsConfigurator
        returns (uint256 actionId_)
    {
        actionId_ = _validateHooks(hooks_);
        ActionLogic memory logic = actionLogic[actionId_];
        // Check if action already exists
        if (logic.metadataOracle != address(0)) revert ACTION_ALREADY_EXISTS();

        // Validate inputs
        if (metadataOracle_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        _validateHooks(hooks_);

        actionLogic[actionId_] = ActionLogic({ metadataOracle: metadataOracle_, hooks: hooks_ });
        emit ActionRegistered(actionId_, hooks_, metadataOracle_);
    }

    /// @inheritdoc ISuperActions
    function batchRegisterActions(
        address[][] memory hooks_,
        address[] memory metadataOracles_
    )
        external
        onlyActionsConfigurator
        returns (uint256[] memory actionIds_)
    {
        uint256 len = hooks_.length;
        if (len != metadataOracles_.length) revert INVALID_ARRAY_LENGTH();

        actionIds_ = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            actionIds_[i] = _validateHooks(hooks_[i]);

            ActionLogic memory logic = actionLogic[actionIds_[i]];
            if (logic.metadataOracle != address(0)) revert ACTION_ALREADY_EXISTS();
            if (metadataOracles_[i] == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

            actionLogic[actionIds_[i]] = ActionLogic({ metadataOracle: metadataOracles_[i], hooks: hooks_[i] });
        }

        emit ActionBatchRegistered(actionIds_);
    }

    /// @inheritdoc ISuperActions
    function updateAction(
        uint256 actionId_,
        address metadataOracle_,
        address[] memory newHooks_
    )
        external
        onlyActionsConfigurator
    {
        ActionLogic storage logic = _getActionLogicOrRevert(actionId_);
        if (metadataOracle_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

        _validateHooks(newHooks_);

        logic.metadataOracle = metadataOracle_;
        logic.hooks = newHooks_;

        emit ActionOracleUpdated(actionId_, metadataOracle_);
        emit ActionHooksUpdated(actionId_, newHooks_);
    }

    /// @inheritdoc ISuperActions
    function batchUpdateAction(
        uint256[] memory actionIds_,
        address[] memory metadataOracles_,
        address[][] memory newHooks_
    )
        external
        onlyActionsConfigurator
    {
        uint256 len = actionIds_.length;
        if (len != metadataOracles_.length || len != newHooks_.length) revert INVALID_ARRAY_LENGTH();

        for (uint256 i = 0; i < len; i++) {
            ActionLogic storage logic = _getActionLogicOrRevert(actionIds_[i]);
            if (metadataOracles_[i] == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

            _validateHooks(newHooks_[i]);

            logic.metadataOracle = metadataOracles_[i];
            logic.hooks = newHooks_[i];

            emit ActionOracleUpdated(actionIds_[i], metadataOracles_[i]);
            emit ActionHooksUpdated(actionIds_[i], newHooks_[i]);
        }
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

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperActions
    function getHooksForAction(uint256 actionId_) external view returns (address[] memory hooks_) {
        return getActionLogic(actionId_).hooks;
    }

    /// @inheritdoc ISuperActions
    function getActionLogic(uint256 actionId_) public view returns (ActionLogic memory) {
        ActionLogic memory logic = actionLogic[actionId_];
        if (logic.metadataOracle == address(0)) revert ACTION_NOT_FOUND();
        return logic;
    }

    /// @inheritdoc ISuperActions
    function getHooksForActions(uint256[] memory actionIds_)
        external
        view
        returns (address[][] memory hooksForActions_)
    {
        uint256 len = actionIds_.length;
        hooksForActions_ = new address[][](len);
        for (uint256 i = 0; i < len; i++) {
            ActionLogic memory logic = actionLogic[actionIds_[i]];
            if (logic.metadataOracle == address(0)) revert ACTION_NOT_FOUND();
            hooksForActions_[i] = logic.hooks;
        }
        return hooksForActions_;
    }

    /// @inheritdoc ISuperActions
    function getOracleForAction(uint256 actionId_) external view returns (address oracle_) {
        ActionLogic memory logic = actionLogic[actionId_];
        if (logic.metadataOracle == address(0)) revert ACTION_NOT_FOUND();
        return logic.metadataOracle;
    }

    /// @inheritdoc ISuperActions
    function isActionActive(uint256 actionId_) external view returns (bool) {
        return actionLogic[actionId_].metadataOracle != address(0);
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
        uint256 actionId_,
        address finalTarget_
    )
        external
        view
        returns (LedgerEntry[] memory)
    {
        return userLedgerEntries[user_][actionId_][finalTarget_];
    }

    /// @inheritdoc ISuperActions
    function getUnconsumedEntries(
        address user_,
        uint256 actionId_,
        address finalTarget_
    )
        external
        view
        returns (uint256)
    {
        return unconsumedEntries[user_][actionId_][finalTarget_];
    }

    /// @inheritdoc ISuperActions
    function getFeePercentForStrategy(uint256 actionId_, address finalTarget_) external view returns (uint256) {
        return feePercentPerStrategy[actionId_][finalTarget_];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateHooks(address[] memory hooks_) internal pure returns (uint256 actionId_) {
        uint256 len = hooks_.length;
        if (len == 0) revert INVALID_HOOKS_LENGTH();

        for (uint256 i = 0; i < len; i++) {
            if (hooks_[i] == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        }

        // Hash the hooks addresses to generate actionId
        actionId_ = uint256(keccak256(abi.encode(hooks_)));
    }

    function _transferToPaymaster() internal {
        // Implementation needed
    }

    function _getActionLogicOrRevert(uint256 actionId_) internal view returns (ActionLogic storage) {
        ActionLogic storage logic = actionLogic[actionId_];
        if (logic.metadataOracle == address(0)) revert ACTION_NOT_FOUND();
        return logic;
    }
}
