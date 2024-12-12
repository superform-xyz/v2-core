// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract Mock5115Vault {
  constructor(
    IERC20 asset_,
    string memory name_,
    string memory symbol_
  ) {}

  function previewDeposit(address tokenIn, uint256 amountTokenToDeposit) external view returns (uint256 amountSharesOut) {
    amountSharesOut = amountTokenToDeposit;
  }
}

