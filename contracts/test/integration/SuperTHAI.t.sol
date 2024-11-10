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

import { ModulesShared } from "test/shared/ModulesShared.t.sol";
import { Deposit4626Module } from "src/modules/Deposit4626Module.sol";

import "forge-std/console.sol";

import { Vm } from "forge-std/Vm.sol";

contract SuperTHAITests is ModulesShared {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function test_GivenAssetsWereDepositedToTheSmartAccount(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);
        uint256 totalAssetsBefore = wethVault.totalAssets();
        uint256 balanceVaultBefore = IERC20(address(wethVault)).balanceOf(address(instance.account));

        // it should deposit to the vault
        UserOpData memory userOpData = instance.getExecOps({
            target: address(deposit4626Module),
            value: 0,
            callData: abi.encodeWithSelector(
                Deposit4626Module.execute.selector, abi.encode(address(instance.account), amount)
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
}
