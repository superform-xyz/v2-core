// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20Mock } from "./ERC20Mock.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Mock5115Vault {
  constructor(
    IERC20 asset_,
    string memory name_,
    string memory symbol_
  ) {}

  function previewDeposit(address tokenIn, uint256 amountTokenToDeposit) external view returns (uint256 amountSharesOut) {
    amountSharesOut = amountTokenToDeposit;
  }

  function previewRedeem(address tokenOut, uint256 amountSharesToRedeem) external view returns (uint256 amountTokenOut) {
    amountTokenOut = amountSharesToRedeem;
  }
}

