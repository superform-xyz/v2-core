// // SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.8.28;

// // external
// import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// // modulekit
// import { ModeLib } from "erc7579/lib/ModeLib.sol";
// import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
// import { IERC7579Account, Execution } from "modulekit/Accounts.sol";

// // Superform
// import { ApproveERC20 } from "src/hooks/ApproveERC20.sol";
// import { IntentBase } from "src/intents/IntentBase.sol";
// import { LendingProtocolHook } from "src/hooks/LendingProtocolHook.sol";
// import { ILendingAndBorrowMock } from "src/interfaces/mocks/ILendingAndBorrowMock.sol";

// import "forge-std/console.sol";

// contract AddCollateralToMockProtocolIntent is ERC7579ExecutorBase, IntentBase {
//     address private _mockProtocol;

//     error AMOUNT_ZERO();

//     constructor(address mockProtocol_, address registry_) IntentBase(registry_) {
//         _mockProtocol = mockProtocol_;
//     }

//     function onInstall(bytes calldata) external { }
//     function onUninstall(bytes calldata) external { }
//     function isInitialized(address) external view returns (bool) { }

//     function name() external pure returns (string memory) {
//         return "AddCollateralToMockProtocolIntent";
//     }

//     function version() external pure returns (string memory) {
//         return "0.0.1";
//     }

//     function isModuleType(uint256 typeID) external pure override returns (bool) {
//         return typeID == TYPE_EXECUTOR;
//     }

//     function execute(bytes calldata data) external {
//         (address account, uint256 amount) = abi.decode(data, (address, uint256));
//         if (amount == 0) revert AMOUNT_ZERO();

//         uint256 amountBefore = ILendingAndBorrowMock(_mockProtocol).balanceOf(account);
//         console.log("           |____________");
//         console.log("           execution started; collateral before %s", amountBefore);

//         IERC20 asset = IERC20(address(ILendingAndBorrowMock(_mockProtocol).tokenIn()));
//         // execute the approval
//         _approveAction(asset, account, amount);
//         console.log("                approve asset");

//         // execute the deposit
//         _depositAction(account, amount);
//         console.log("                deposit collateral");
//         amountBefore = ILendingAndBorrowMock(_mockProtocol).balanceOf(account);
//         console.log("           execution ended; collateral after %s", amountBefore);
//         console.log("           _|");
//     }

//     function _approveAction(IERC20 asset, address account, uint256 amount) private {
//         _execute(account, ApproveERC20.hook(asset, address(_mockProtocol), amount));
//     }

//     function _depositAction(address account, uint256 amount) private {
//         Execution[] memory executions = new Execution[](1);
//         executions[0] = LendingProtocolHook.addCollateralHook(ILendingAndBorrowMock(_mockProtocol), account, amount);

//         _execute(account, executions);
//     }
// }
