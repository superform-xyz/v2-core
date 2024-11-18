// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperModules } from "src/interfaces/ISuperModules.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISuperformExecutionModule } from "src/interfaces/ISuperformExecutionModule.sol";

contract SuperModules is ISuperModules {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public superRegistry;

    address[] public modules;
    mapping(address => ModuleInfo) public pendingModules;
    mapping(address => ModuleInfo) public registeredModules;

    mapping(address => bool) private _votedForModule;

    constructor(address superRegistry_) {
        superRegistry = superRegistry_;
    }

    modifier onlySuperModuleConfigurator() {
        ISuperRegistry registry = ISuperRegistry(superRegistry);
        ISuperRbac rbac = ISuperRbac(registry.getAddress(registry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SUPER_MODULE_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperModules
    function isActive(address module_) external view returns (bool) {
        return registeredModules[module_].isActive;
    }

    /// @inheritdoc ISuperModules
    function votes(address module_) external view returns (uint128) {
        return registeredModules[module_].votes;
    }

    /// @inheritdoc ISuperModules
    function getModuleCount() external view returns (uint256) {
        return modules.length;
    }

    /// @inheritdoc ISuperModules
    function getModuleAtIndex(uint256 index_) external view returns (address) {
        return modules[index_];
    }

    /// @inheritdoc ISuperModules
    function getModuleInfo(address module_) external view returns (ModuleInfo memory) {
        return registeredModules[module_];
    }

    /// @inheritdoc ISuperModules
    function generateModuleId(address module_) public view returns (bytes32) {
        ISuperformExecutionModule executionModule = ISuperformExecutionModule(module_);
        return keccak256(
            abi.encodePacked(module_, executionModule.author(), executionModule.name(), executionModule.version())
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperModules
    function vote(address module_) external {
        if (module_ == address(0)) revert ADDRESS_NOT_VALID();
        if (!registeredModules[module_].isActive) revert MODULE_NOT_ACTIVE();

        _votedForModule[module_] = true;
        registeredModules[module_].votes++;
    }

    /// @inheritdoc ISuperModules
    function registerModule(address module_) external {
        if (module_ == address(0)) revert ADDRESS_NOT_VALID();
        if (registeredModules[module_].isActive) revert ALREADY_REGISTERED();
        if (pendingModules[module_].id != bytes32(0)) revert REGISTRATION_PENDING();

        bytes32 id = generateModuleId(module_);
        if (id == bytes32(0)) revert ID_NOT_VALID();

        pendingModules[module_] = ModuleInfo({ id: id, isActive: false, index: 0, votes: 0 });
    }

    /// @inheritdoc ISuperModules
    function acceptModuleRegistration(address module_) external onlySuperModuleConfigurator {
        if (module_ == address(0)) revert ADDRESS_NOT_VALID();
        if (pendingModules[module_].id == bytes32(0)) revert PENDING_REGISTRATION_NOT_VALID();

        // remove pending
        bytes32 _id = pendingModules[module_].id;
        delete pendingModules[module_];

        // add registered
        modules.push(module_);
        uint128 index = uint128(modules.length - 1);
        registeredModules[module_] = ModuleInfo({ id: _id, isActive: true, index: uint128(index), votes: 0 });
        emit ModuleRegistered(module_, _id, uint128(index));
    }

    /// @inheritdoc ISuperModules
    function delistModule(address module_) external onlySuperModuleConfigurator {
        if (!(registeredModules[module_].isActive || pendingModules[module_].id != bytes32(0))) {
            revert ADDRESS_NOT_VALID();
        }
        delete registeredModules[module_];
        delete pendingModules[module_];
    }
}
