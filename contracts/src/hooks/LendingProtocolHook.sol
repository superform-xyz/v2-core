// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { ILendingAndBorrowMock } from "src/interfaces/mocks/ILendingAndBorrowMock.sol";

library LendingProtocolHook {
    function addCollateralHook(
        ILendingAndBorrowMock lendingProtocol,
        address account,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory)
    {
        return Execution({
            target: address(lendingProtocol),
            value: 0,
            callData: abi.encodeCall(ILendingAndBorrowMock.deposit, (amount, account))
        });
    }

    function borrowHook(
        ILendingAndBorrowMock lendingProtocol,
        address account,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory)
    {
        return Execution({
            target: address(lendingProtocol),
            value: 0,
            callData: abi.encodeCall(ILendingAndBorrowMock.borrow, (amount, account))
        });
    }
}
