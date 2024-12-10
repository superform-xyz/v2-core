// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "src/utils/BaseExecutorModule.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";

contract SuperExecutorV2 is BaseExecutorModule, ERC7579ExecutorBase, ISuperExecutorV2 {
    constructor(address registry_) BaseExecutorModule(registry_) { }

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
    }
}