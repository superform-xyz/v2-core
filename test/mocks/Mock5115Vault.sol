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

    constructor(IERC20 asset_, string memory name_, string memory symbol_) {
        if (address(asset_) == address(0)) {
            asset = new MockERC20(name_, symbol_, 18);
        } else {
            asset = MockERC20(address(asset_));
        }
    }

    function assetInfo() external view returns (AssetType assetType, address asset_, uint8 decimals) {
        assetType = AssetType.ERC20;
        asset_ = address(asset);
        decimals = uint8(asset.decimals());
    }

    function getTokensOut() external view returns (address[] memory tokensOut) {
        tokensOut = new address[](1);
        tokensOut[0] = address(asset);
    }

    function previewDeposit(
        address, //tokenIn
        uint256 amountTokenToDeposit
    )
        external
        pure
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = amountTokenToDeposit;
    }

    function previewRedeem(
        address, //tokenOut
        uint256 amountSharesToRedeem
    )
        external
        pure
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = amountSharesToRedeem;
    }
}
