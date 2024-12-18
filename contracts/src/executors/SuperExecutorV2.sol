// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "./BaseExecutorModule.sol";

import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISentinel } from "../interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "../interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "../interfaces/strategies/ISuperActions.sol";

import { console } from "forge-std/console.sol";

contract SuperExecutorV2 is BaseExecutorModule, ERC7579ExecutorBase, ISuperExecutorV2 {
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
    /// @inheritdoc ISuperExecutorV2
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

    /// @inheritdoc ISuperExecutorV2
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
        address[] memory hooks;
        if (entry.actionId == type(uint256).max) {
            if (entry.finalTarget != address(0)) {
                revert FINAL_TARGET_NOT_ZERO();
            }
            hooks = entry.nonMainActionHooks;
        } else {
            if (entry.nonMainActionHooks.length > 0) {
                revert MAIN_ACTION_WITH_NON_MAIN_ACTION_HOOKS();
            }
            // retrieve hooks for this action
            hooks = ISuperActions(superActions()).getHooksForAction(entry.actionId);
        }
        uint256 hooksLength = hooks.length;

        _processHooks(account, entry, hooks, hooksLength);
        console.log(entry.actionId);
        if (entry.actionId != type(uint256).max) {
            console.log("HELL");
            /// @dev I added this at the end of each action execution to update the accounting for that strategy
            /// @dev In terms of value of shares being minted it is using the last value obtained in uintStore
            if (typeOfMainAction == keccak256("DEPOSIT")) {
                console.log("DEPOSIT");
                _updateAccounting(account, entry.actionId, entry.finalTarget, true, shareDelta);
            } else if (typeOfMainAction == keccak256("WITHDRAW")) {
                console.log("WITHDRAW");
                _updateAccounting(account, entry.actionId, entry.finalTarget, false, shareDelta);
            }
        }

        /// @dev reset transient storage
        typeOfMainAction = bytes32(0);
        shareDelta = 0;

        /*
        Commented because this will be performed directly inside unlock/lock shares hooks in _processHooks
        TODO Remove
        // all hooks have been executed; act on SuperPositions changes for current strategy
        _notifySuperPosition(entry, spSharesMint_, spSharesBurn_);
        */
    }

    function _processHooks(
        address account,
        ExecutorEntry memory entry,
        address[] memory hooks,
        uint256 hooksLength
    )
        private
    {
        for (uint256 j; j < hooksLength;) {
            ISuperHook hook = ISuperHook(hooks[j]);

            // update any hook's internal transient storage
            hook.preExecute(entry.hooksData[j]);

            // execute the hook in the context of the SCAL
            _execute(account, hook.build(entry.hooksData[j]));

            (, uint256 shareDelta_, bytes32 hookType_,) = hook.postExecute(entry.hooksData[j]);

            /// @dev the following sets the type of main action in transient storage
            if (
                typeOfMainAction == bytes32(0)
                    && (hookType_ == keccak256("DEPOSIT") || hookType_ == keccak256("WITHDRAW"))
            ) {
                /// @dev if the type of main action is unset and hook type is a main deposit or withdraw hook
                typeOfMainAction = hookType_;
            } else if (typeOfMainAction != bytes32(0) && hookType_ != bytes32(0) && typeOfMainAction != hookType_) {
                /// @dev if the type of main action is already set, and hookType_ is returned and is different than the
                /// already set
                /// @dev notice, this assumes there can only be two types of actions to be priced: deposit and withdraw
                revert ACTION_TYPE_MISMATCH();
            }

            /// @dev This means the last hooks' provided share difference (must be accurate) is added to uint
            /// @dev Warning: If there is a malicious action, accounting will be performed improperly and will result in
            /// a fee loss
            if (shareDelta_ != 0) {
                shareDelta = shareDelta_;
            }

            /*
            Commented because this will be performed directly inside unlock/lock shares hooks
            TODO Remove
            // update the total mint and burn values
            if (bytes32Storage == keccak256("DEPOSIT")) {
                spSharesMint_ += uintStorage;
            } else if (bytes32Storage == keccak256("WITHDRAW")) {
                spSharesBurn_ += uintStorage;
            }
            */

            unchecked {
                ++j;
            }
        }
    }

    function _updateAccounting(
        address account,
        uint256 actionId,
        address finalTarget,
        bool isDeposit,
        uint256 amountShares
    )
        private
    {
        ISuperActions(superActions()).updateAccounting(account, actionId, finalTarget, isDeposit, amountShares);
    }

    function _notifySuperPosition(ExecutorEntry memory entry, uint256 _spSharesMint, uint256 _spSharesBurn) private {
        if (_spSharesMint > _spSharesBurn) {
            ISentinel(_getSuperPositionSentinel()).notify(
                entry.actionId, entry.finalTarget, abi.encode(_spSharesMint - _spSharesBurn, true)
            );
        } else if (_spSharesBurn > _spSharesMint) {
            ISentinel(_getSuperPositionSentinel()).notify(
                entry.actionId, entry.finalTarget, abi.encode(_spSharesBurn - _spSharesMint, false)
            );
        }
    }
}
