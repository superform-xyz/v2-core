// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "./BaseExecutorModule.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";

contract SuperExecutorV2 is BaseExecutorModule, ERC7579ExecutorBase, ISuperExecutorV2 {
    constructor(address registry_) BaseExecutorModule(registry_) { }

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

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSuperPositionSentinel() private view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_POSITION_SENTINEL_ID());
    }

    function _execute(address account, ExecutorEntry[] memory entries) private {
        uint256 stratLen = entries.length;
        if (stratLen == 0) revert DATA_NOT_VALID();

        // execute each strategy
        for (uint256 i; i < stratLen;) {
            ExecutorEntry memory entry = entries[i];

            // retrieve hooks for this action
            address[] memory hooks = ISuperActions(superActions()).getHooksForAction(entry.actionId);

            uint256 hooksLength = hooks.length;

            uint256 _spSharesMint;
            uint256 _spSharesBurn;
            // execute each hook from this strategy
            for (uint256 j; j < hooksLength;) {
                ISuperHook hook = ISuperHook(hooks[j]);
                hook.preExecute(entry.hooksData[j]);
                _execute(account, hook.build(entry.hooksData[j]));
                (, uintStorage,, boolStorage) = hook.postExecute(entry.hooksData[j]);
                if (boolStorage) {
                    _spSharesMint += uintStorage;
                } else {
                    _spSharesBurn += uintStorage;
                }

                unchecked {
                    ++j;
                }
            }

            // TODO: call updateAccounting

            if (_spSharesMint > _spSharesBurn) {
                ISentinel(_getSuperPositionSentinel()).notify(
                    entry.actionId, entry.finalTarget, abi.encode(_spSharesMint - _spSharesBurn, true)
                );
            } else if (_spSharesBurn > _spSharesMint) {
                ISentinel(_getSuperPositionSentinel()).notify(
                    entry.actionId, entry.finalTarget, abi.encode(_spSharesBurn - _spSharesMint, false)
                );
            }
            // If _spSharesMint == _spSharesBurn, no action is taken.

            unchecked {
                ++i;
            }
        }
    }
}
