// // SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.8.28;

// // external
// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// // exchange rate is 1:1
// contract LendingAndBorrowingProtocolMock {
//     using SafeERC20 for IERC20;

//     address public tokenIn;
//     address public tokenOut;

//     mapping(address => uint256) public balanceOf;
//     mapping(address => uint256) public borrowBalanceOf;

//     error Borrowing_InsufficientBalance();

//     constructor(address tokenIn_, address tokenOut_) {
//         tokenIn = tokenIn_;
//         tokenOut = tokenOut_;
//     }

//     function deposit(uint256 amount, address to) external {
//         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amount);
//         balanceOf[to] += amount;
//     }

//     function borrow(uint256 amount, address to) external {
//         if (balanceOf[msg.sender] < amount) revert Borrowing_InsufficientBalance();
//         borrowBalanceOf[msg.sender] += amount;
//         IERC20(tokenOut).safeTransfer(to, amount);
//     }

//     function repay(uint256 amount) external {
//         borrowBalanceOf[msg.sender] -= amount;
//         IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amount);
//     }

//     function withdraw(uint256 amount) external {
//         balanceOf[msg.sender] -= amount;
//         IERC20(tokenIn).safeTransfer(msg.sender, amount);
//     }
// }
