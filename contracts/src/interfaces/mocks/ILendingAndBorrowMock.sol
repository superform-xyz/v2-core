// // SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.8.28;

// interface ILendingAndBorrowMock {
//     /*//////////////////////////////////////////////////////////////
//                                  VIEW METHODS
//     //////////////////////////////////////////////////////////////*/
//     /// @notice The balance of the account.
//     /// @param account The address of the account.
//     function balanceOf(address account) external view returns (uint256);

//     /// @notice The borrow balance of the account.
//     /// @param account The address of the account.
//     function borrowBalanceOf(address account) external view returns (uint256);

//     /// @return The address of the token in.
//     function tokenIn() external view returns (address);

//     /// @return The address of the token out.
//     function tokenOut() external view returns (address);

//     /*//////////////////////////////////////////////////////////////
//                                  EXTERNAL METHODS
//     //////////////////////////////////////////////////////////////*/
//     /// @notice Deposit tokens into the lending and borrowing protocol.
//     /// @param amount The amount of tokens to deposit.
//     /// @param to The address to deposit the tokens to.
//     function deposit(uint256 amount, address to) external;

//     /// @notice Borrow tokens from the lending and borrowing protocol.
//     /// @param amount The amount of tokens to borrow.
//     /// @param to The address to receive `tokenOut`.
//     function borrow(uint256 amount, address to) external;

//     /// @notice Repay tokens to the lending and borrowing protocol.
//     /// @param amount The amount of tokens to repay.
//     function repay(uint256 amount) external;

//     /// @notice Withdraw tokens from the lending and borrowing protocol.
//     /// @param amount The amount of tokens to withdraw.
//     function withdraw(uint256 amount) external;
// }
