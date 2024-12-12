// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { BaseRegistry } from "src/utils/BaseRegistry.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";

contract StrategiesRegistry is SuperRegistryImplementer, BaseRegistry, IStrategiesRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => address[]) public hooksForStrategy;

    address public lastRegisteredStrategy;

    constructor(address registry_) SuperRegistryImplementer(registry_) BaseRegistry("StrategiesRegistry") { }

    modifier onlyStrategiesRegistryConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.STRATEGIES_REGISTRY_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategiesRegistry
    function getHooksForStrategy(address strategyId_) external view returns (address[] memory) {
        return hooksForStrategy[strategyId_];
    }

    /// @inheritdoc IStrategiesRegistry
    function delistStrategy(address strategyId_) external onlyStrategiesRegistryConfigurator {
        _delistItem(strategyId_);
    }

    /// @inheritdoc IStrategiesRegistry
    function registerStrategy(address[] memory hooks_) external returns (address) {
        address strategyId = _getNextAddress();
        _registerItem(strategyId, msg.sender);

        hooksForStrategy[strategyId] = hooks_;
        lastRegisteredStrategy = strategyId;
        return strategyId;
    }

    /// @inheritdoc IStrategiesRegistry
    function acceptStrategyRegistration(address strategyId_) external onlyStrategiesRegistryConfigurator {
        _acceptItemRegistration(strategyId_);
    }

    /// @inheritdoc IStrategiesRegistry
    function vote(address strategyId_) external {
        _vote(strategyId_);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getNextAddress() private view returns (address) {
        return address(uint160(lastRegisteredStrategy) + 1);
    }
}
