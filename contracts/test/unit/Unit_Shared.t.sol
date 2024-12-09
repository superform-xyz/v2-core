// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";


// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { IRegistry } from "src/interfaces/registries/IRegistry.sol";
import { IHooksRegistry } from "src/interfaces/registries/IHooksRegistry.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISuperGatewayExecutor } from "src/interfaces/ISuperGatewayExecutor.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";
import { ISharedStateOperations } from "src/interfaces/state/ISharedStateOperations.sol";

import { SuperRbac } from "src/settings/SuperRbac.sol";
import { SharedState } from "src/state/SharedState.sol";
import { HooksRegistry } from "src/settings/HooksRegistry.sol";
import { SuperRegistry } from "src/settings/SuperRegistry.sol";   
import { SuperSentinel } from "src/sentinels/SuperSentinel.sol";
import { SuperExecutor } from "src/executors/SuperExecutor.sol";
import { StrategiesRegistry } from "src/settings/StrategiesRegistry.sol";
import { SuperGatewayExecutor } from "src/executors/SuperGatewayExecutor.sol";

import { BaseTest } from "test/BaseTest.t.sol";

abstract contract Unit_Shared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperRegistry public superRegistry;
    IHooksRegistry public hooksRegistry;
    IStrategiesRegistry public strategiesRegistry;

    ISentinel public superSentinel;
    ISuperExecutor public superExecutor;
    ISuperGatewayExecutor public superGatewayExecutor;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;
    ISharedStateOperations public sharedStateOperations;

    AccountInstance public instance;

    address public constant ENTRY_POINT = address(1);

    function setUp() public override virtual {
        super.setUp();

        sharedState = new SharedState();
        vm.label(address(sharedState), "sharedState");
        sharedStateReader = ISharedStateReader(address(sharedState));
        sharedStateWriter = ISharedStateWriter(address(sharedState));
        sharedStateOperations = ISharedStateOperations(address(sharedState));

        superRbac = ISuperRbac(address(new SuperRbac(address(this))));
        vm.label(address(superRbac), "superRbac");

        superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
        vm.label(address(superRegistry), "superRegistry");

        hooksRegistry = IHooksRegistry(address(new HooksRegistry(address(superRegistry))));
        vm.label(address(hooksRegistry), "hooksRegistry");

        strategiesRegistry = IStrategiesRegistry(address(new StrategiesRegistry(address(superRegistry))));
        vm.label(address(strategiesRegistry), "strategiesRegistry");

        superSentinel = ISentinel(address(new SuperSentinel(address(superRegistry))));
        vm.label(address(superSentinel), "superSentinel");

        superExecutor = ISuperExecutor(address(new SuperExecutor(address(superRegistry))));
        vm.label(address(superExecutor), "superExecutor");

        superGatewayExecutor = ISuperGatewayExecutor(address(new SuperGatewayExecutor(address(superRegistry), ENTRY_POINT)));
        vm.label(address(superGatewayExecutor), "superGatewayExecutor");    

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        vm.label(instance.account, "SuperformAccount");
    }
}
