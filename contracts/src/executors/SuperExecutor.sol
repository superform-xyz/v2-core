// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "./BaseExecutorModule.sol";

import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISentinel } from "../interfaces/sentinel/ISentinel.sol";
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

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function superActions() public view returns (address) {
        return _superActions();
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
        ExecutorEntry[] memory entries = abi.decode(data, (ExecutorEntry[]));
        _execute(account, entries);
    }

    /// @inheritdoc ISuperExecutor
    function executeFromGateway(address account, bytes calldata data) external onlyBridgeGateway {
        // check if we need anything else here
        ExecutorEntry[] memory entries = abi.decode(data, (ExecutorEntry[]));
        _execute(account, entries);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSuperPositionSentinel() private view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_POSITION_SENTINEL_ID());
    }

    function _execute(address account, ExecutorEntry[] memory entries) private {
        uint256 actionLen = entries.length;
        if (actionLen == 0) revert DATA_NOT_VALID();

        // execute each strategy
        for (uint256 i; i < actionLen;) {
            _executeAction(account, entries[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _executeAction(address account, ExecutorEntry memory entry) private {
        if (entry.actionId == type(uint256).max) {
            if (entry.yieldSourceAddress != address(0)) {
                revert FINAL_TARGET_NOT_ZERO();
            }
            // Process non-main action hooks directly
            _processNonMainActionHooks(account, entry);
        } else {
            ISuperActions.ActionLogic memory actionLogic = ISuperActions(superActions()).getActionLogic(entry.actionId);

            // Process main action hooks
            _processMainActionHooks(account, entry, actionLogic);

            // Update accounting based on action type
            _updateAccounting(
                account,
                entry.actionId,
                entry.yieldSourceAddress,
                actionLogic.actionType == ISuperActions.ActionType.INFLOW,
                shareDelta
            );
        }

        shareDelta = 0;
    }

    // New function for processing hooks with ActionInfo
    function _processMainActionHooks(
        address account,
        ExecutorEntry memory entry,
        ISuperActions.ActionLogic memory actionLogic
    )
        private
    {
        uint256 hooksLength = actionLogic.hooks.length;
        for (uint256 j; j < hooksLength;) {
            ISuperHook hook = ISuperHook(actionLogic.hooks[j]);

            hook.preExecute(entry.hooksData[j]);
            _execute(account, hook.build(entry.hooksData[j]));

            (, uint256 shareDelta_,,) = hook.postExecute(entry.hooksData[j]);

            // Only capture shareDelta from designated hook
            if (j == actionLogic.shareDeltaHookIndex) {
                shareDelta = shareDelta_;
            }
            unchecked {
                ++j;
            }
        }
    }

    // Modified to handle direct hook array
    function _processNonMainActionHooks(address account, ExecutorEntry memory entry) private {
        uint256 hooksLength = entry.nonMainActionHooks.length;
        for (uint256 j; j < hooksLength;) {
            ISuperHook hook = ISuperHook(entry.nonMainActionHooks[j]);

            hook.preExecute(entry.hooksData[j]);

            _execute(account, hook.build(entry.hooksData[j]));

            hook.postExecute(entry.hooksData[j]);

            unchecked {
                ++j;
            }
        }
    }

    function _updateAccounting(
        address account,
        uint256 actionId,
        address yieldSourceAddress,
        bool isDeposit,
        uint256 amountShares
    )
        private
    {
        ISuperActions(superActions()).updateAccounting(account, actionId, yieldSourceAddress, isDeposit, amountShares);
    }

    function _notifySuperPosition(ExecutorEntry memory entry, uint256 _spSharesMint, uint256 _spSharesBurn) private {
        if (_spSharesMint > _spSharesBurn) {
            ISentinel(_getSuperPositionSentinel()).notify(
                entry.actionId, entry.yieldSourceAddress, abi.encode(_spSharesMint - _spSharesBurn, true)
            );
        } else if (_spSharesBurn > _spSharesMint) {
            ISentinel(_getSuperPositionSentinel()).notify(
                entry.actionId, entry.yieldSourceAddress, abi.encode(_spSharesBurn - _spSharesMint, false)
            );
        }
    }
}
