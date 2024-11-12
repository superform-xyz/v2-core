// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
import { SuperExecutor } from "src/settings/SuperExecutor.sol";
import { ModulesShared } from "test/shared/ModulesShared.t.sol";
import { Deposit4626Module } from "src/modules/Deposit4626Module.sol";

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

        // execute calls
        superExecutor.execute(abi.encode(instance, modules, callDatas));

        uint256 totalAssetsAfter = wethVault.totalAssets();
        uint256 balanceVaultAfter = IERC20(address(wethVault)).balanceOf(address(instance.account));
        //assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        //assertEq(balanceVaultAfter, balanceVaultBefore + amount);
    }
}
