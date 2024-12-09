// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";

// Just a mock for the moment
// Testing transient storage
contract SuperModuleExecutor is ERC7579ExecutorBase, SuperRegistryImplementer {
    bool transient boolStorage;
    int256 transient intStorage;
    uint256 transient uintStorage;
    address transient addressStorage;
    bytes32 transient bytes32Storage;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }  

    error DATA_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function strategiesRegistry() public view returns (address) {
        return superRegistry.getAddress(superRegistry.STRATEGIES_REGISTRY_ID());
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "SuperModuleExecutor";
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

    function execute(bytes calldata data) external {
        (address strategyId, bytes[] memory hooksData) = abi.decode(data, (address, bytes[]));

        // retrieve hooks for this strategy
        address[] memory hooks = IStrategiesRegistry(strategiesRegistry()).getHooksForStrategy(strategyId);
        
        // checks
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0 || hooksLength != hooksData.length) revert DATA_NOT_VALID();
        
        // execute each hook
        for (uint256 i; i < hooksLength;) {
            _execute(ISuperHook(hooks[i]).build(hooksData[i]));
            
            unchecked {
                ++i;
            }
        }

        /**
        // create user ops
        uint256 totalOps;
        for (uint256 i; i < hooksLength;) {
            totalOps += ISuperHook(hooks[i]).totalOps();

            unchecked {
                ++i;
            }
        }

        Execution[] memory executions = _build(totalOps, hooks, hooksData);
        _execute(account,executions);
         */
    }

        /**
    function _build(uint256 len, address[] memory hooks, bytes[] memory hooksData) private view returns (Execution[] memory executions) {
        executions = new Execution[](len);
        for (uint256 i; i < len;) {
            Execution[] memory hookExecutions = ISuperHook(hooks[i]).build(hooksData[i]);
            for (uint256 j; j < hookExecutions.length;) {
                executions[i] = hookExecutions[j];

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }
         */

}  
