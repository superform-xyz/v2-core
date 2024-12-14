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
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISuperGatewayExecutorV2 } from "src/interfaces/ISuperGatewayExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";

import { SuperRbac } from "../../src/settings/SuperRbac.sol";
import { SharedState } from "../../src/state/SharedState.sol";
import { SuperRegistry } from "../../src/settings/SuperRegistry.sol";
import { SuperExecutorV2 } from "../../src/executors/SuperExecutorV2.sol";
import { SuperActions } from "../../src/strategies/SuperActions.sol";
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";
import { SuperGatewayExecutorV2 } from "../../src/executors/SuperGatewayExecutorV2.sol";
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { Mock4626Vault } from "../mocks/Mock4626Vault.sol";

import { BaseTest } from "../BaseTest.t.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";


abstract contract Unit_Shared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperActions public superActions;
    ISuperExecutorV2 public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;
    ISuperGatewayExecutorV2 public superGatewayExecutor;

    AccountInstance public instance;

    MockERC20 public mockERC20;
    Mock4626Vault public mock4626Vault;

    uint256[] public actionIds;

    address public constant ENTRY_POINT = address(1);

    function setUp() public virtual override {
        super.setUp();

        sharedState = new SharedState();
        vm.label(address(sharedState), "sharedState");
        sharedStateReader = ISharedStateReader(address(sharedState));
        sharedStateWriter = ISharedStateWriter(address(sharedState));

        superRbac = ISuperRbac(address(new SuperRbac(address(this))));
        vm.label(address(superRbac), "superRbac");

        superActions = ISuperActions(address(new SuperActions(address(superRegistry))));
        vm.label(address(superActions), "superActions");

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        superExecutor = ISuperExecutorV2(address(new SuperExecutorV2(address(superRegistry))));
        vm.label(address(superExecutor), "superExecutor");

        superGatewayExecutor = ISuperGatewayExecutorV2(address(new SuperGatewayExecutorV2(address(superRegistry))));
        vm.label(address(superGatewayExecutor), "superGatewayExecutor");

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        mockERC20 = _deployToken("MockERC20", "MRC20", 18);
        mock4626Vault = new Mock4626Vault(
            IERC20(address(mockERC20)),
            "Mock4626Vault",
            "MRC4626"
        );
        vm.label(address(mock4626Vault), "mock4626Vault");

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "SuperformAccount");

        // register on SuperRegistry
        _setSuperRegistryAddresses();

        // set roles
        _setRoles();

        // register strategies
        actionIds = _registerSameChainActions();
    }

    function _setSuperRegistryAddresses() internal {
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_ACTIONS_ID(), address(superActions));
        SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.SUPER_POSITION_SENTINEL_ID(), address(superPositionSentinel)
        );
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_RBAC_ID(), address(superRbac));
    }

    function _setRoles() internal {
        superRbac.setRole(SUPER_ACTIONS_CONFIGURATOR, superRbac.SUPER_ACTIONS_CONFIGURATOR(), true);
    }

    function _registerSameChainActions() internal returns (uint256[] memory) {
        vm.startPrank(SUPER_ACTIONS_CONFIGURATOR);
        uint256[] memory _actionIds = new uint256[](3);

        address[] memory hooks = new address[](2);
        // approve + 4626 deposit
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        _actionIds[0] = superActions.registerAction(hooks, ACTION_ORACLE_TEMP);

        // 4626 withdraw
        hooks = new address[](1);
        hooks[0] = address(withdraw4626VaultHook);
        _actionIds[1] = superActions.registerAction(hooks, ACTION_ORACLE_TEMP);

        // approve + 4626 deposit + 4626 withdraw
        hooks = new address[](3);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(withdraw4626VaultHook);
        _actionIds[2] = superActions.registerAction(hooks, ACTION_ORACLE_TEMP);

        vm.stopPrank();
        return _actionIds;
    }
}
