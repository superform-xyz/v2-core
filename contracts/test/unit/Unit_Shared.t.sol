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
import {MODULE_TYPE_EXECUTOR} from "modulekit/external/ERC7579.sol";    

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { IHooksRegistry } from "src/interfaces/registries/IHooksRegistry.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISuperGatewayExecutorV2 } from "src/interfaces/ISuperGatewayExecutorV2.sol";
import { IStrategiesRegistry } from "src/interfaces/registries/IStrategiesRegistry.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";

import { SuperRbac } from "src/settings/SuperRbac.sol";
import { SharedState } from "src/state/SharedState.sol";
import { SuperRegistry } from "src/settings/SuperRegistry.sol";
import { HooksRegistry } from "src/settings/HooksRegistry.sol";
import { SuperExecutorV2 } from "src/executors/SuperExecutorV2.sol";
import { StrategiesRegistry } from "src/settings/StrategiesRegistry.sol";
import { SuperPositionSentinel } from "src/sentinels/SuperPositionSentinel.sol";
import { SuperGatewayExecutorV2 } from "src/executors/SuperGatewayExecutorV2.sol";
import { SuperPositionSentinel } from "src/sentinels/SuperPositionSentinel.sol";

import { AcrossBridgeGateway } from "src/bridges/AcrossBridgeGateway.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Mock4626Vault } from "test/mocks/Mock4626Vault.sol";

import { BaseTest } from "test/BaseTest.t.sol";

abstract contract Unit_Shared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    IHooksRegistry public hooksRegistry;
    IStrategiesRegistry public strategiesRegistry;

    ISuperExecutorV2 public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;
    ISuperGatewayExecutorV2 public superGatewayExecutor;
    AcrossBridgeGateway public acrossBridgeGateway;

    AccountInstance public instance;

    MockERC20 public mockERC20;
    Mock4626Vault public mock4626Vault;

    address[] public stratIds;

    address public constant ENTRY_POINT = address(1);

    function setUp() public virtual override {
        super.setUp();

        sharedState = new SharedState();
        vm.label(address(sharedState), "sharedState");
        sharedStateReader = ISharedStateReader(address(sharedState));
        sharedStateWriter = ISharedStateWriter(address(sharedState));

        superRbac = ISuperRbac(address(new SuperRbac(address(this))));
        vm.label(address(superRbac), "superRbac");

        hooksRegistry = IHooksRegistry(address(new HooksRegistry(address(superRegistry))));
        vm.label(address(hooksRegistry), "hooksRegistry");

        strategiesRegistry = IStrategiesRegistry(address(new StrategiesRegistry(address(superRegistry))));
        vm.label(address(strategiesRegistry), "strategiesRegistry");

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        superExecutor = ISuperExecutorV2(address(new SuperExecutorV2(address(superRegistry))));
        vm.label(address(superExecutor), "superExecutor");

        superGatewayExecutor =
            ISuperGatewayExecutorV2(address(new SuperGatewayExecutorV2(address(superRegistry))));
        vm.label(address(superGatewayExecutor), "superGatewayExecutor");

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        mockERC20 = _deployToken("MockERC20", "MRC20", 18);
        mock4626Vault = new Mock4626Vault(address(mockERC20));
        vm.label(address(mock4626Vault), "mock4626Vault");

        acrossBridgeGateway = new AcrossBridgeGateway(address(superRegistry), address(spokePoolV3Mock));
        vm.label(address(acrossBridgeGateway), "acrossBridgeGateway");

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "SuperformAccount");

        // register on SuperRegistry
        _setSuperRegistryAddresses();

        // register strategies
        stratIds = _registerSameChainStrategies();

    }

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier addRole(bytes32 role_) {
        superRbac.setRole(address(this), role_, true);
        _;
    }
    
    modifier addRoleTo(bytes32 role_, address addr_) {
        superRbac.setRole(addr_, role_, true);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _setSuperRegistryAddresses() internal {
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_RBAC_ID(), address(superRbac));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.HOOKS_REGISTRY_ID(), address(hooksRegistry));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.STRATEGIES_REGISTRY_ID(), address(strategiesRegistry));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_POSITION_SENTINEL_ID(), address(superPositionSentinel));
    }

    function _registerSameChainStrategies() internal returns (address[] memory) {
        address[] memory _stratIds = new address[](4);

        address[] memory hooks = new address[](2);
        // approve + 4626 deposit
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        _stratIds[0] = strategiesRegistry.registerStrategy(hooks);

        // 4626 withdraw  
        hooks = new address[](1);
        hooks[0] = address(withdraw4626VaultHook);
        _stratIds[1] = strategiesRegistry.registerStrategy(hooks);

        // approve + 4626 deposit + 4626 withdraw
        hooks = new address[](3);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(withdraw4626VaultHook);
        _stratIds[2] = strategiesRegistry.registerStrategy(hooks);

        // approve + 4626 deposit + across 
        hooks = new address[](3);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(acrossExecuteOnDestinationHook);
        _stratIds[3] = strategiesRegistry.registerStrategy(hooks);

        return _stratIds;
    }
}

