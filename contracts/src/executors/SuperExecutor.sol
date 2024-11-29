// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";

contract SuperExecutor is ISuperExecutor, SuperRegistryImplementer {
    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function strategiesRegistry() public view returns (address) {
        return superRegistry.getAddress(superRegistry.STRATEGIES_REGISTRY_ID());
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function execute(bytes memory data) external view returns (Execution[] memory executions) {
        (address strategyId, bytes[] memory hooksData) = abi.decode(data, (address, bytes[]));

        // retrieve hooks for this strategy
        address[] memory hooks = IStrategiesRegistry(strategiesRegistry()).getHooksForStrategy(strategyId);

        // checks
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0 || hooksLength != hooksData.length) revert DATA_NOT_VALID();

        // create user ops
        uint256 totalOps;
        for (uint256 i; i < hooksLength; i++) {
            totalOps += ISuperHook(hooks[i]).totalOps();
        }

        executions = new Execution[](totalOps);
        for (uint256 i; i < hooksLength; i++) {
            Execution[] memory hookExecutions = ISuperHook(hooks[i]).build(hooksData[i]);
            for (uint256 j; j < hookExecutions.length; j++) {
                executions[i] = hookExecutions[j];
            }
        }

        return executions;
    }
}
