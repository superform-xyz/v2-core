// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Mock5115Vault {
  enum AssetType {
    ERC20,
    AMM_LIQUIDITY_TOKEN,
    BRIDGED_YIELD_BEARING_TOKEN
  }

  MockERC20 asset;

  constructor(
    IERC20 asset_,
    string memory name_,
    string memory symbol_
  ) {
    asset = new MockERC20(name_, symbol_, 18);
  }

  function previewDeposit(address tokenIn, uint256 amountTokenToDeposit) external view returns (uint256 amountSharesOut) {
    amountSharesOut = amountTokenToDeposit;
  }

  function previewRedeem(address tokenOut, uint256 amountSharesToRedeem) external view returns (uint256 amountTokenOut) {
    amountTokenOut = amountSharesToRedeem;
  }

  function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
    assetType = AssetType.ERC20;
    assetAddress = address(asset);
    assetDecimals = asset.decimals();
  }
}

