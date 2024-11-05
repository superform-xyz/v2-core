// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// modulekit
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { IERC7579Account, Execution } from "modulekit/Accounts.sol";
import { ERC20Integration } from "modulekit/integrations/ERC20.sol";

// Superform
import { ILendingAndBorrowMock } from "src/interfaces/mocks/ILendingAndBorrowMock.sol";

import "forge-std/console.sol";

contract BorrowFromMockProtocolIntent is ERC7579ExecutorBase {
    address private _mockProtocol;

    error AMOUNT_ZERO();

    constructor(address mockProtocol_) {
        _mockProtocol = mockProtocol_;
    }

    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }
    function isInitialized(address) external view returns (bool) { }

    function name() external pure returns (string memory) {
        return "BorrowFromMockProtocolIntent";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function execute(bytes calldata data) external {
        (address account, uint256 amount) = abi.decode(data, (address, uint256));
        if (amount == 0) revert AMOUNT_ZERO();

        uint256 amountBefore = ILendingAndBorrowMock(_mockProtocol).borrowBalanceOf(account);
        console.log("           |_");
        console.log("           execution started; borrow balance before %s", amountBefore);

        // execute the borrow action
        _borrowAction(account, amount);
        console.log("                borrow vault asset in");

        amountBefore = ILendingAndBorrowMock(_mockProtocol).borrowBalanceOf(account);
        console.log("           execution ended; borrow balance after %s", amountBefore);
        console.log("           _|");
    }

    function _borrowAction(address account, uint256 amount) private {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(_mockProtocol),
            value: 0,
            callData: abi.encodeCall(ILendingAndBorrowMock.borrow, (amount, account))
        });

        _execute(account, executions);
    }
}
