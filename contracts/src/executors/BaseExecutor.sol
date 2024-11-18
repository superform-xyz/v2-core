// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/external/ERC7579.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperModules } from "src/interfaces/ISuperModules.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "src/interfaces/executors/ISuperExecutor.sol";

abstract contract BaseExecutor is ISuperExecutor {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public superRegistry;

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();
        superRegistry = ISuperRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    modifier onlyExecutorConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.EXECUTOR_CONFIGURATOR())) revert NOT_EXECUTOR_CONFIGURATOR();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _executeAccountOp(bytes memory data) internal {
        (AccountInstance memory instance, address[] memory modules, bytes[] memory callDatas, uint256[] memory values) =
            abi.decode(data, (AccountInstance, address[], bytes[], uint256[]));

        uint256 len = modules.length;
        if (len == 0) revert INVALID_DATA();
        if (len != values.length) revert INVALID_DATA();
        if (len != callDatas.length) revert INVALID_DATA();

        Execution[] memory executions = new Execution[](len);
        // validate modules & create executions
        for (uint256 i = 0; i < len; i++) {
            address module = modules[i];
            if (!_isValidModule(module)) revert INVALID_MODULE();

            executions[i] = Execution({ target: module, value: values[i], callData: callDatas[i] });
        }

        // execute calls
        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        userOpData.execUserOps();
    }

    function _isValidModule(address module_) internal view returns (bool) {
        ISuperModules superModules = ISuperModules(superRegistry.getAddress(superRegistry.SUPER_MODULES_ID()));
        return superModules.isActive(module_);
    }
}
