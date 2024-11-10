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

contract IntentsBasicExecution is ModulesShared {
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
        userOpData.execUserOps();

        uint256 totalAssetsAfter = wethVault.totalAssets();
        uint256 balanceVaultAfter = IERC20(address(wethVault)).balanceOf(address(instance.account));
        assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        assertEq(balanceVaultAfter, balanceVaultBefore + amount);
    }
}
