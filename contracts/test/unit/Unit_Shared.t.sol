// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_FALLBACK } from "modulekit/accounts/kernel/types/Constants.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISuperLedger } from "src/interfaces/accounting/ISuperLedger.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";

import { SuperRbac } from "../../src/settings/SuperRbac.sol";
import { SharedState } from "../../src/state/SharedState.sol";
import { SuperRegistry } from "../../src/settings/SuperRegistry.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";

import { AcrossBridgeGateway } from "../../src/bridges/AcrossBridgeGateway.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { Mock4626Vault } from "../mocks/Mock4626Vault.sol";
import { MockFallback } from "../mocks/MockFallbackModule.sol";

import { BaseTest } from "../BaseTest.t.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import { console } from "forge-std/console.sol";

contract Unit_Shared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperLedger public superLedger;
    ISuperExecutor public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;
    AcrossBridgeGateway public acrossBridgeGateway;

    MockFallback public mockFallback;
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

        superLedger = ISuperLedger(address(new SuperLedger(address(superRegistry))));
        vm.label(address(superLedger), "superLedger");

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");

        superExecutor = ISuperExecutor(address(new SuperExecutor(address(superRegistry))));
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
        mockFallback = new MockFallback();
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        //instance.installModule({ moduleTypeId: MODULE_TYPE_FALLBACK, module: address(mockFallback), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "SuperformAccount");

        // register on SuperRegistry
        _setSuperRegistryAddresses();

        // set roles
        _setRoles();

        // register action
        _setupSuperLedger();
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
    function _getExecOps(bytes memory data) internal returns (UserOpData memory) {
        return instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
    }

    function executeOp(UserOpData memory userOpData) public {
        userOpData.execUserOps();
    }

    function _setSuperRegistryAddresses() internal {
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_LEDGER_ID(), address(superLedger));
        SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.SUPER_POSITION_SENTINEL_ID(), address(superPositionSentinel)
        );
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_RBAC_ID(), address(superRbac));
        SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.ACROSS_GATEWAY_ID(), address(acrossBridgeGateway)
        );
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_EXECUTOR_ID(), address(superExecutor));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SHARED_STATE_ID(), address(sharedState));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.PAYMASTER_ID(), address(0x11111));
        SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_LEDGER_HOOK_ID(), address(superLedgerHook));
    }

    function _setRoles() internal { }

    function getAction(string memory _name) internal view returns (uint256) {
        return ACTION[bytes32(bytes(_name))];
    }

    function _setupSuperLedger() internal {
        vm.startPrank(MANAGER);
        address[] memory mainHooks = new address[](2);
        mainHooks[0] = address(deposit4626VaultHook);
        mainHooks[1] = address(withdraw4626VaultHook);
        ISuperLedger.HookRegistrationConfig[] memory configs = new ISuperLedger.HookRegistrationConfig[](1);
        configs[0] = ISuperLedger.HookRegistrationConfig({
            mainHooks: mainHooks,
            yieldSourceOracle: address(erc4626YieldSourceOracle),
            feePercent: 100,
            vaultShareToken: address(0), // this is auto set because its standardized yield
            feeRecipient: SuperRegistry(address(superRegistry)).getAddress(superRegistry.PAYMASTER_ID())
        });
        superLedger.setYieldSourceOracles(configs);
        vm.stopPrank();
    }
}
