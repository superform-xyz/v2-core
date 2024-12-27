// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ForkedTestBase } from "./ForkedTestBase.t.sol";

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

// external
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { 
  RhinestoneModuleKit, 
  ModuleKitHelpers, 
  AccountInstance, 
  UserOpData 
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

contract SameChainDepositRedeemFlowTest is ForkedTestBase, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    ERC4626 public vaultInstance;
    AccountInstance public instance;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperActions public superActions;
    ISuperExecutorV2 public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;

    mapping(bytes32 name => uint256 actionId) public ACTION;

    address public constant ENTRY_POINT = address(1);

    uint256[] public allActions;

    function setUp() public override {
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

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        vm.deal(instance.account, LARGE);
        vm.label(instance.account, "SuperformAccount");

        // Register action
        _performRegistrations();

        vm.selectFork(chainIds[0]);
        vaultInstance = ERC4626(realVaultAddresses[1]["ERC4626"]["YearnDaiYVault"]["DAI"]);
    }

    function test_Deposit_Redeem_Flow() public {
        address finalTarget = address(vaultInstance);
        uint256 amount = 1e18;
        bytes[] memory depositHooksData = _createDepositActionData(finalTarget, amount);
        bytes[] memory redeemHooksData = _createWithdrawActionData(finalTarget, amount);

        vm.prank(deployer);
        vaultInstance.deposit(amount, deployer);
        address dai = existingUnderlyingTokens[1]["DAI"];
        _getTokens(dai, instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](2);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            finalTarget: finalTarget,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            finalTarget: finalTarget,
            hooksData: redeemHooksData,
            nonMainActionHooks: new address[](0)
        });

        vm.expectEmit(true, true, true, true);
        emit ISuperActions.AccountingUpdated(
            instance.account, ACTION["4626_WITHDRAW"], finalTarget, false, amount, 1e18
        );
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _createDepositActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(address(mockERC20), finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
    }

    function _createWithdrawActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encode(finalTarget, instance.account, instance.account, amount);
    }

    function _performRegistrations() internal {
        vm.startPrank(SUPER_ACTIONS_CONFIGURATOR);

        // Configure ERC4626 yield source
        ISuperActions.YieldSourceConfig memory erc4626Config = ISuperActions.YieldSourceConfig({
            yieldSourceId: "ERC4626",
            metadataOracle: address(depositRedeem4626ActionOracle),
            actions: new ISuperActions.ActionConfig[](2)
        });

        // Deposit action (approve + deposit)
        address[] memory depositHooks = new address[](2);
        depositHooks[0] = address(approveErc20Hook);
        depositHooks[1] = address(deposit4626VaultHook);

        erc4626Config.actions[0] = ISuperActions.ActionConfig({
            hooks: depositHooks,
            actionType: ISuperActions.ActionType.INFLOW,
            shareDeltaHookIndex: 1 // deposit4626VaultHook provides share delta
         });

        // Withdraw action
        address[] memory withdrawHooks = new address[](1);
        withdrawHooks[0] = address(withdraw4626VaultHook);

        erc4626Config.actions[1] = ISuperActions.ActionConfig({
            hooks: withdrawHooks,
            actionType: ISuperActions.ActionType.OUTFLOW,
            shareDeltaHookIndex: 0 // withdraw4626VaultHook provides share delta
         });

        // Register ERC4626 actions
        uint256[] memory erc4626ActionIds = superActions.registerYieldSourceAndActions(erc4626Config);

        // Store action IDs in mapping
        ACTION["4626_DEPOSIT"] = erc4626ActionIds[0];
        ACTION["4626_WITHDRAW"] = erc4626ActionIds[1];

        // Add to allActions array
        allActions.push(erc4626ActionIds[0]);
        allActions.push(erc4626ActionIds[1]);

        // Log action IDs
        console.log("4626_DEPOSIT", erc4626ActionIds[0]);
        console.log("4626_WITHDRAW", erc4626ActionIds[1]);

        // approve + 4626 deposit + across
        // uses separate register method because yield source is already registered
        /// @dev WARNING: the last 2 hooks here should not be part of this main action (which is really just
        /// 4626_DEPOSIT) TODO
        address[] memory hooks = new address[](4);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(approveErc20Hook);
        hooks[3] = address(acrossExecuteOnDestinationHook);
        ACTION["4626_DEPOSIT_ACROSS"] =
            superActions.registerAction(hooks, "ERC4626", ISuperActions.ActionType.INFLOW, 1);
        allActions.push(ACTION["4626_DEPOSIT_ACROSS"]);
        console.log("4626_DEPOSIT_ACROSS", ACTION["4626_DEPOSIT_ACROSS"]);
        vm.stopPrank();
    }
}
