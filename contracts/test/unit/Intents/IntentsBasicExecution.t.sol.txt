// // SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.8.28;

// // external
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// // modulekit
// import {
//     RhinestoneModuleKit,
//     ModuleKitHelpers,
//     ModuleKitUserOp,
//     AccountInstance,
//     UserOpData
// } from "modulekit/ModuleKit.sol";

// import { Execution } from "modulekit/external/ERC7579.sol";

// import { IntentsShared } from "test/unit/shared/IntentsShared.t.sol";
// import { BorrowFromMockProtocolIntent } from "src/intents/BorrowFromMockProtocolIntent.sol";
// import { DepositToSuperformVaultIntent } from "src/intents/DepositToSuperformVaultIntent.sol";
// import { AddCollateralToMockProtocolIntent } from "src/intents/AddCollateralToMockProtocolIntent.sol";

// import "forge-std/console.sol";

// contract IntentsBasicExecution is IntentsShared {
//     using ModuleKitHelpers for *;
//     using ModuleKitUserOp for *;

//     modifier whenTheDepositToSuperformVaultExecutorIsCalled() {
//         _;
//     }

//     function test_GivenAssetsWereDepositedToTheSmartAccount(uint256 amount)
//         external
//         whenTheDepositToSuperformVaultExecutorIsCalled
//         whenAccountHasTokens
//     {
//         amount = bound(amount, SMALL, LARGE);
//         uint256 totalAssetsBefore = wethVault.totalAssets();
//         uint256 balanceVaultBefore = IERC20(address(wethVault)).balanceOf(address(instance.account));

//         // it should deposit to the vault
//         UserOpData memory userOpData = instance.getExecOps({
//             target: address(depositToSuperformVaultIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 DepositToSuperformVaultIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();

//         uint256 totalAssetsAfter = wethVault.totalAssets();
//         uint256 balanceVaultAfter = IERC20(address(wethVault)).balanceOf(address(instance.account));
//         assertEq(totalAssetsAfter, totalAssetsBefore + amount);
//         assertEq(balanceVaultAfter, balanceVaultBefore + amount);
//     }

//     function test_WhenTheAddCollateralExecutorIsCalled(uint256 amount) external whenAccountHasTokens {
//         amount = bound(amount, SMALL, LARGE);
//         UserOpData memory userOpData = instance.getExecOps({
//             target: address(depositToSuperformVaultIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 DepositToSuperformVaultIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();

//         // it should increase collateral for user
//         uint256 collateralBefore =
// IERC20(address(lendingAndBorrowingProtocolMock)).balanceOf(address(instance.account));

//         userOpData = instance.getExecOps({
//             target: address(addCollateralToMockProtocolIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 AddCollateralToMockProtocolIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();

//         uint256 collateralAfter =
// IERC20(address(lendingAndBorrowingProtocolMock)).balanceOf(address(instance.account));
//         assertEq(collateralAfter, collateralBefore + amount);
//     }

//     function test_WhenBorrowExecutorIsCalled(uint256 amount) external whenAccountHasTokens {
//         amount = bound(amount, SMALL, LARGE);
//         UserOpData memory userOpData = instance.getExecOps({
//             target: address(depositToSuperformVaultIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 DepositToSuperformVaultIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();

//         userOpData = instance.getExecOps({
//             target: address(addCollateralToMockProtocolIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 AddCollateralToMockProtocolIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();

//         uint256 borrowBalanceBefore = lendingAndBorrowingProtocolMock.borrowBalanceOf(address(instance.account));
//         // it should increase tokenOut for account
//         userOpData = instance.getExecOps({
//             target: address(borrowFromMockProtocolIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 BorrowFromMockProtocolIntent.execute.selector, abi.encode(address(instance.account), amount)
//             ),
//             txValidator: address(instance.defaultValidator)
//         });
//         userOpData.execUserOps();
//         uint256 borrowBalanceAfter = lendingAndBorrowingProtocolMock.borrowBalanceOf(address(instance.account));
//         assertEq(borrowBalanceAfter, borrowBalanceBefore + amount);
//     }

//     function test_WhenAllAreCalledTogether(uint256 amount) external whenAccountHasTokens {
//         amount = bound(amount, SMALL, LARGE);
//         console.log("Executing the following Intents through the Smart Account:");
//         console.log("   - Deposit to the Superform Vault deployed at: %s", address(wethVault));
//         console.log(
//             "   - Add Collateral to the Mock Protocol deployed at: %s", address(lendingAndBorrowingProtocolMock)
//         );
//         console.log("   - Borrow from the Mock Protocol deployed at: %s", address(lendingAndBorrowingProtocolMock));
//         console.log("   - Deposit to the Superform Vault deployed at: %s", address(wethVault));
//         console.log("");
//         console.log("[+] Expected result: perform a 2x leverage on the Superform Vault");
//         console.log("");
//         console.log("");
//         console.log("Preparing calls. Initial deposited amount %s", amount);
//         console.log("--------------");
//         console.log("");
//         console.log("");

//         // it should leverage twice
//         Execution[] memory executions = new Execution[](4);

//         executions[0] = Execution({
//             target: address(depositToSuperformVaultIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 DepositToSuperformVaultIntent.execute.selector, abi.encode(address(instance.account), amount)
//             )
//         });
//         console.log("Added `DepositToSuperformVaultIntent`");
//         console.log("   * deposit to Superform Vault");
//         executions[1] = Execution({
//             target: address(addCollateralToMockProtocolIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 AddCollateralToMockProtocolIntent.execute.selector, abi.encode(address(instance.account), amount)
//             )
//         });
//         console.log("Added `AddCollateralToMockProtocolIntent`");
//         console.log("   * add collateral to the mock protocol");
//         executions[2] = Execution({
//             target: address(borrowFromMockProtocolIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 BorrowFromMockProtocolIntent.execute.selector, abi.encode(address(instance.account), amount * 70 /
// 100)
//             )
//         });
//         console.log("Added `BorrowFromMockProtocolIntent`");
//         console.log("   * borrow from the mock protocol at 70% CR");
//         executions[3] = Execution({
//             target: address(depositToSuperformVaultIntent),
//             value: 0,
//             callData: abi.encodeWithSelector(
//                 DepositToSuperformVaultIntent.execute.selector, abi.encode(address(instance.account), amount * 70 /
// 100)
//             )
//         });
//         console.log("Added `DepositToSuperformVaultIntent`");
//         console.log("   * deposit to Superform Vault");

//         console.log("");
//         console.log("");
//         console.log("Executing calls...");
//         UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
//         userOpData.execUserOps();

//         console.log("   [+] Total Superform vault shares obtained %s", wethVault.totalAssets());
//         console.log("   [+] Initial amount deposited was          %s", amount);
//         console.log("Calls executed");

//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");
//         console.log("");

//         //assertTrue(false);

//         // check leverage factor
//         assertGt(wethVault.totalAssets(), amount);
//     }
// }
