// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

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
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";

import { AcrossBridgeGateway } from "../../src/bridges/AcrossBridgeGateway.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { Mock4626Vault } from "../mocks/Mock4626Vault.sol";

import { BaseTest } from "../BaseTest.t.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import { console } from "forge-std/console.sol";

abstract contract Unit_Shared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperActions public superActions;
    ISuperExecutorV2 public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;
    AcrossBridgeGateway public acrossBridgeGateway;

    AccountInstance public instance;

    MockERC20 public mockERC20;
    Mock4626Vault public mock4626Vault;

    mapping(bytes32 name => uint256 actionId) public ACTION;

    uint256[] public allActions;

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

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        mockERC20 = _deployToken("MockERC20", "MRC20", 18);
        mock4626Vault = new Mock4626Vault(IERC20(address(mockERC20)), "Mock4626Vault", "MRC4626");
        vm.label(address(mock4626Vault), "mock4626Vault");

        acrossBridgeGateway = new AcrossBridgeGateway(address(superRegistry), address(spokePoolV3Mock));
        vm.label(address(acrossBridgeGateway), "acrossBridgeGateway");
        spokePoolV3Mock.setAcrossBridgeGateway(address(acrossBridgeGateway));

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "SuperformAccount");

        // register on SuperRegistry
        _setSuperRegistryAddresses();

        // set roles
        _setRoles();

        // register action
        _performRegistrations();
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
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_ACTIONS_ID(), address(superActions));
        SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.SUPER_POSITION_SENTINEL_ID(), address(superPositionSentinel)
        );
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_RBAC_ID(), address(superRbac));
        SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.ACROSS_GATEWAY_ID(), address(acrossBridgeGateway)
        );
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_EXECUTOR_ID(), address(superExecutor));
    }

    function _setRoles() internal {
        superRbac.setRole(SUPER_ACTIONS_CONFIGURATOR, superRbac.SUPER_ACTIONS_CONFIGURATOR(), true);
    }

    function getAction(string memory _name) internal view returns (uint256) {
        return ACTION[bytes32(bytes(_name))];
    }

    function _performRegistrations() internal {
        vm.startPrank(SUPER_ACTIONS_CONFIGURATOR);
        /// register yieldSources
        superActions.registerYieldSource("ERC4626", address(depositRedeem4626ActionOracle));
        superActions.registerYieldSource("ERC5115", address(depositRedeem5115ActionOracle));

        /// register actions
        mapping(bytes32 name => uint256 actionId) storage actionIds = ACTION;
        address[] memory hooks = new address[](2);
        // approve + 4626 deposit
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        actionIds["4626_DEPOSIT"] = superActions.registerAction(hooks, "ERC4626");
        allActions.push(actionIds["4626_DEPOSIT"]);
        console.log("4626_DEPOSIT", actionIds["4626_DEPOSIT"]);

        // 4626 withdraw
        hooks = new address[](1);
        hooks[0] = address(withdraw4626VaultHook);
        actionIds["4626_WITHDRAW"] = superActions.registerAction(hooks, "ERC4626");
        allActions.push(actionIds["4626_WITHDRAW"]);
        console.log("4626_WITHDRAW", actionIds["4626_WITHDRAW"]);

        // approve + 4626 deposit + across
        /// @dev WARNING: the last 2 hooks here should not be part of this main action (which is really just
        /// 4626_DEPOSIT) TODO
        hooks = new address[](4);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(approveErc20Hook);
        hooks[3] = address(acrossExecuteOnDestinationHook);
        actionIds["4626_DEPOSIT_ACROSS"] = superActions.registerAction(hooks, "ERC4626");
        allActions.push(actionIds["4626_DEPOSIT_ACROSS"]);
        console.log("4626_DEPOSIT_ACROSS", actionIds["4626_DEPOSIT_ACROSS"]);
        vm.stopPrank();
    }
}
