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

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperModules } from "src/interfaces/ISuperModules.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";

import "forge-std/console.sol";

interface ISuperExecutor {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_DATA();
    error INVALID_MODULE();
    error ADDRESS_NOT_VALID();
    error NOT_RELAYER_SENTINEL();
}

contract SuperExecutor is ISuperExecutor {
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

    modifier onlyRelayerSentinel() {
        if (msg.sender != superRegistry.getAddress(superRegistry.RELAYER_SENTINEL_ID())) {
            revert NOT_RELAYER_SENTINEL();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function execute(bytes memory data) external onlyRelayerSentinel {
        //TODO: add initiator validation
        console.log("execute A");
        (AccountInstance memory instance, address[] memory modules, bytes[] memory callDatas) =
            abi.decode(data, (AccountInstance, address[], bytes[]));
        console.log("execute B");

        uint256 len = modules.length;
        if (len == 0) revert INVALID_DATA();
        if (len != callDatas.length) revert INVALID_DATA();
        console.log("execute C");

        for (uint256 i = 0; i < len; i++) {
            console.log("execute D");
            address module = modules[i];
            if (!_isValidModule(module)) revert INVALID_MODULE();
            console.log("execute E");

            _executeModule(instance, module, callDatas[i]);
            console.log("execute F");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _isValidModule(address module_) private view returns (bool) {
        ISuperModules superModules = ISuperModules(superRegistry.getAddress(superRegistry.SUPER_MODULES_ID()));
        return superModules.isActive(module_);
    }

    function _executeModule(AccountInstance memory instance_, address module_, bytes memory callData_) private {
        UserOpData memory userOpData = instance_.getExecOps({
            target: module_,
            value: 0, //todo: receive value
            callData: callData_,
            txValidator: address(instance_.defaultValidator)
        });

        userOpData.execUserOps();
    }
}
