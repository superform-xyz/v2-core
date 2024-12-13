// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "src/utils/BaseExecutorModule.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";

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
    function strategiesRegistry() public view returns (address) {
        return _strategiesRegistry();
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

    /// @inheritdoc ISuperExecutorV2
    function execute(address account,bytes calldata data) external {
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
        uint256 stratLen = entries.length;
        if (stratLen == 0) revert DATA_NOT_VALID();

        // execute each strategy
        for (uint256 i; i < stratLen;) {
            ExecutorEntry memory entry = entries[i];

            // retrieve hooks for this strategy
            address[] memory hooks = IStrategiesRegistry(strategiesRegistry()).getHooksForStrategy(entry.strategyId);

            // verify hook
            uint256 hooksLength = hooks.length;
            if (hooksLength == 0 || hooksLength != entry.hooksData.length) revert DATA_NOT_VALID();

            uint256 _spSharesMint; // SuperPosition shares to be minted for this strategy   
            uint256 _spSharesBurn; // SuperPosition shares to be burned for this strategy

            // execute each hook from this strategy
            for (uint256 j; j < hooksLength;) {
                ISuperHook hook = ISuperHook(hooks[j]);

                // update any hook's internal transient storage
                hook.preExecute(entry.hooksData[j]);
                
                // execute the hook in the context of the SCAL
                _execute(account, hook.build(entry.hooksData[j]));

                // get updated transient values
                // for deposit or withdraw hooks, uintStorage represents the amount of shares to mint or burn
                //                                bytes32Storage is the keccak256 of the hook type (keccak256("DEPOSIT")
                (,uintStorage, bytes32Storage,) = hook.postExecute(entry.hooksData[j]);

                // update the total mint and burn values
                if (bytes32Storage == keccak256("DEPOSIT")) {
                    _spSharesMint += uintStorage;
                } else if (bytes32Storage == keccak256("WITHDRAW")) {
                    _spSharesBurn += uintStorage;
                }
                
                unchecked {
                    ++j;
                }
            }

            // TODO: call updateAccounting for this strategy

            // all hooks have been executed; act on SuperPositions changes for current strategy
            if (_spSharesMint > _spSharesBurn) {
                ISentinel(_getSuperPositionSentinel()).notify(
                    entry.strategyId,
                    abi.encode(_spSharesMint - _spSharesBurn, true, address(0)) // TODO: get spAddress
                );
            } else if (_spSharesBurn > _spSharesMint) {
                ISentinel(_getSuperPositionSentinel()).notify(
                    entry.strategyId,
                    abi.encode(_spSharesBurn - _spSharesMint, false, address(0)) // TODO: get spAddress
                );
            }

            // execute the next strategy
            unchecked {
                ++i;
            }
        }
    }

}