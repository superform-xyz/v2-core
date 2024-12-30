// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "./BaseExecutorModule.sol";

import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperActions } from "../interfaces/strategies/ISuperActions.sol";

contract SuperExecutor is BaseExecutorModule, ERC7579ExecutorBase, ISuperExecutor {
    constructor(address registry_) BaseExecutorModule(registry_) { }

    // TODO: check if sender is bridge gateway; otherwise enforce at the logic level
    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_GATEWAY())) revert NOT_AUTHORIZED();
        _;
    }

    /// @inheritdoc ISuperExecutor
    function superActions() public view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_ACTIONS_ID());
    }

    function isInitialized(address) external pure returns (bool) {
        return _isInitialized();
    }

    function name() external pure returns (string memory) {
        return "SuperExecutor";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }

    function execute(address account, bytes calldata data) external {
        _execute(account, abi.decode(data, (ExecutorEntry[])));
    }

    /// @inheritdoc ISuperExecutor
    function executeFromGateway(address account, bytes calldata data) external onlyBridgeGateway {
        // check if we need anything else here
        _execute(account, abi.decode(data, (ExecutorEntry[])));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _execute(address account, ExecutorEntry[] memory entries) private {
        uint256 actionLen = entries.length;
        if (actionLen == 0) revert DATA_NOT_VALID();

        // execute each strategy
        address actionLastHook = address(0);
        for (uint256 i; i < actionLen;) {
            ExecutorEntry memory _entry = entries[i];

            // validate action
            _validateAction(_entry);

            // retrieve hooks
            address[] memory hooks = _getActionHooks(_entry);

            // execute action
            _executeAction(account, _entry, hooks, actionLastHook);

            // set last hook for next action
            actionLastHook = hooks[hooks.length - 1];
            unchecked {
                ++i;
            }
        }
    }

    function _validateAction(ExecutorEntry memory entry) private pure {
        if (entry.actionId == type(uint256).max && entry.yieldSourceAddress != address(0)) {
            revert FINAL_TARGET_NOT_ZERO();
        }
    }

    function _getActionHooks(ExecutorEntry memory entry) private view returns (address[] memory hooks) {
        if (entry.actionId != type(uint256).max) {
            return ISuperActions(superActions()).getActionLogic(entry.actionId).hooks;
        }
        return entry.nonMainActionHooks;
    }

    function _executeAction(
        address account,
        ExecutorEntry memory entry,
        address[] memory hooks,
        address prevActionHook
    )
        private
    {
        // execute all hooks for current action
        _executeActionHooks(account, hooks, entry.hooksData, prevActionHook);

        // update accounting for main action
        if (entry.actionId != type(uint256).max) {
            ISuperActions.ActionLogic memory actionLogic = ISuperActions(superActions()).getActionLogic(entry.actionId);
            uint256 accountingAmount = ISuperHook(hooks[actionLogic.shareDeltaHookIndex]).outAmount();
            ISuperActions(superActions()).updateAccounting(
                account,
                entry.actionId,
                entry.yieldSourceAddress,
                actionLogic.actionType == ISuperActions.ActionType.INFLOW,
                accountingAmount
            );
        }
    }

    function _executeActionHooks(
        address account,
        address[] memory hooks,
        bytes[] memory hooksData,
        address prevActionHook
    )
        private
    {
        uint256 hooksLength = hooks.length;
        for (uint256 i; i < hooksLength;) {
            // fill prevHook
            address prevHook = (i == 0) ? prevActionHook : hooks[i - 1];

            // execute current hook
            _processHook(account, ISuperHook(hooks[i]), prevHook, hooksData[i]);

            // go to next hook
            unchecked {
                ++i;
            }
        }
    }

    function _processHook(address account, ISuperHook hook, address prevHook, bytes memory hookData) private {
        // run hook preExecute
        hook.preExecute(prevHook, hookData);

        // run hook execute
        _execute(account, hook.build(prevHook, hookData));

        // run hook postExecute
        hook.postExecute(prevHook, hookData);
    }
}
