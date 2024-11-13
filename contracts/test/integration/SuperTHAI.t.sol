// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DlnOrderLib } from "src/libraries/vendors/deBridge/DlnOrderLib.sol";
import { DlnExternalCallLib } from "src/libraries/vendors/deBridge/DlnExternalCallLib.sol";
// modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";

import { Execution } from "modulekit/external/ERC7579.sol";

import { SuperModules } from "src/settings/SuperModules.sol";
import { SuperExecutor } from "src/executors/SuperExecutor.sol";
import { ModulesShared } from "test/shared/ModulesShared.t.sol";
import { Deposit4626Module } from "src/modules/Deposit4626Module.sol";
import { DeBridgeValidator } from "src/validators/DeBridgeValidator.sol";
import { DeBridgeOrderModule } from "src/modules/DeBridgeOrderModule.sol";
import "forge-std/console.sol";

import { Vm } from "forge-std/Vm.sol";

contract SuperTHAITests is ModulesShared {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function test_deposit4626MintSuperPositions(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);
        uint256 totalAssetsBefore = wethVault.totalAssets();
        uint256 balanceVaultBefore = IERC20(address(wethVault)).balanceOf(address(instance.account));

        // it should deposit to the vault
        UserOpData memory userOpData = instance.getExecOps({
            target: address(deposit4626Module),
            value: 0,
            callData: abi.encodeWithSelector(
                Deposit4626Module.execute.selector, abi.encode(address(wethVault), address(instance.account), amount)
            ),
            txValidator: address(instance.defaultValidator)
        });
        // Get the last emitted event
        Vm.Log[] memory entries = userOpData.execUserOps();

        // module assertions
        uint256 totalAssetsAfter = wethVault.totalAssets();
        uint256 balanceVaultAfter = IERC20(address(wethVault)).balanceOf(address(instance.account));
        assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        assertEq(balanceVaultAfter, balanceVaultBefore + amount);
        // Find the Msg event
        bytes32 msgEventSignature = keccak256("Msg(uint64,address,bytes)");

        Vm.Log memory msgEvent;
        bool foundMsgEvent = false;
        uint256 msgEventIndex;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == msgEventSignature) {
                msgEvent = entries[i];
                msgEventIndex = i;
                foundMsgEvent = true;
                break;
            }
        }

        require(foundMsgEvent, "Msg event not found");

        // Extract the relayer data from the event
        bytes memory relayerData = abi.decode(entries[msgEventIndex].data, (bytes));
        vm.stopPrank();
        // Simulate relayer picking up the event and calling receiveRelayerData
        vm.selectFork(arbitrumFork);
        vm.prank(RELAYER);
        relayerSentinelDst.receiveRelayerData(address(superPositions), relayerData);
    }

    // simulate a receiver call through superExecutor
    function test_executeDeposit4626_superExecutor(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);

        vm.selectFork(mainnetFork);
        SuperModules superModules = new SuperModules(address(superRegistrySrc));
        vm.label(address(superModules), "superModules");
        SuperExecutor superExecutor = new SuperExecutor(address(superRegistrySrc));
        vm.label(address(superExecutor), "superExecutor");
        // simulate a relayer sentinel call
        superRegistrySrc.setAddress(superRegistrySrc.RELAYER_SENTINEL_ID(), address(this));
        // register module
        superRegistrySrc.setAddress(superRegistrySrc.SUPER_MODULES_ID(), address(superModules));
        superRbacSrc.setRole(address(this), superRbacSrc.SUPER_MODULE_CONFIGURATOR(), true);
        superModules.registerModule(address(deposit4626Module));
        superModules.acceptModuleRegistration(address(deposit4626Module));

        uint256 totalAssetsBefore = wethVault.totalAssets();
        uint256 balanceVaultBefore = IERC20(address(wethVault)).balanceOf(address(instance.account));

        bytes memory callData = abi.encodeWithSelector(
            Deposit4626Module.execute.selector, abi.encode(address(wethVault), address(instance.account), amount)
        );
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        address[] memory modules = new address[](1);
        modules[0] = address(deposit4626Module);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // execute calls
        superExecutor.execute(abi.encode(instance, modules, callDatas, values));

        uint256 totalAssetsAfter = wethVault.totalAssets();
        uint256 balanceVaultAfter = IERC20(address(wethVault)).balanceOf(address(instance.account));
        assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        assertEq(balanceVaultAfter, balanceVaultBefore + amount);
    }

    // isolated test
    function test_executeThroughDeBridgeHook(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);

        vm.selectFork(mainnetFork);
        SuperModules superModules = new SuperModules(address(superRegistrySrc));
        vm.label(address(superModules), "superModules");
        SuperExecutor superExecutor = new SuperExecutor(address(superRegistrySrc));
        vm.label(address(superExecutor), "superExecutor");

        // set roles & registry
        superRegistrySrc.setAddress(superRegistrySrc.SUPER_MODULES_ID(), address(superModules));
        superRbacSrc.setRole(address(this), superRbacSrc.BRIDGE_VALIDATOR_CONFIGURATOR(), true);
        superRbacSrc.setRole(address(this), superRbacSrc.SUPER_MODULE_CONFIGURATOR(), true);
        superRbacSrc.setRole(address(this), superRbacSrc.EXECUTOR_CONFIGURATOR(), true);

        // register 4626 module
        superModules.registerModule(address(deposit4626Module));
        superModules.acceptModuleRegistration(address(deposit4626Module));

        // configure validator and executor
        deBridgeValidator.setSuperExecutor(address(superExecutor));
        superExecutor.setBridgeValidator(address(deBridgeValidator));

        // it should create the order
        bytes memory orderData = _createDefaultOrder(amount, address(superExecutor), instance);
        UserOpData memory userOpData = instance.getExecOps({
            target: address(deBridgeOrderModule),
            value: 1 ether,
            callData: abi.encodeWithSelector(DeBridgeOrderModule.execute.selector, abi.encode(instance.account, orderData)),
            txValidator: address(instance.defaultValidator)
        });
        Vm.Log[] memory entries = userOpData.execUserOps();

        bytes32 msgEventSignature = keccak256("DebridgeOrderCreated(address)");
        bool foundEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == msgEventSignature) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent);
    }

    function _createDefaultOrder(
        uint256 amount,
        address executorAddress,
        AccountInstance memory instance
    )
        internal
        returns (bytes memory)
    {
        DlnOrderLib.OrderCreation memory orderCreation = DlnOrderLib.OrderCreation({
            giveTokenAddress: address(0),
            giveAmount: 0,
            takeTokenAddress: abi.encodePacked(address(0)),
            takeAmount: 0,
            takeChainId: 1,
            receiverDst: abi.encodePacked(instance.account),
            givePatchAuthoritySrc: address(0),
            orderAuthorityAddressDst: abi.encodePacked(address(0)),
            allowedTakerDst: abi.encodePacked(address(0)),
            externalCall: abi.encodePacked(address(0)),
            allowedCancelBeneficiarySrc: abi.encodePacked(address(0))
        });

        bytes memory callData = abi.encodeWithSelector(
            Deposit4626Module.execute.selector, abi.encode(address(wethVault), instance.account, amount)
        );
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        address[] memory modules = new address[](1);
        modules[0] = address(deposit4626Module);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes memory superExecutorCalldata = abi.encode(instance, modules, callDatas, values);

        DlnExternalCallLib.ExternalCallPayload memory payload =
            DlnExternalCallLib.ExternalCallPayload({ to: executorAddress, txGas: 0, callData: superExecutorCalldata });
        DlnExternalCallLib.ExternalCallEnvelopV1 memory envelope = DlnExternalCallLib.ExternalCallEnvelopV1({
            fallbackAddress: address(0),
            executorAddress: executorAddress,
            executionFee: 0,
            allowDelayedExecution: false,
            requireSuccessfullExecution: true,
            payload: abi.encode(payload)
        });

        uint8 version = 1;
        bytes memory envelopeData = abi.encode(envelope);

        bytes memory externalCall = abi.encodePacked(version, envelopeData);
        orderCreation.externalCall = externalCall;

        return abi.encode(orderCreation, 0, 0, "");
    }
}
