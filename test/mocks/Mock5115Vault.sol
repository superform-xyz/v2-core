// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Mock5115Vault {
    enum AssetType {
        ERC20,
        AMM_LIQUIDITY_TOKEN,
        BRIDGED_YIELD_BEARING_TOKEN
    }

    MockERC20 public asset;
    uint8 public _decimals;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) {
        if (address(asset_) == address(0)) {
            asset = new MockERC20(name_, symbol_, 18);
        } else {
            asset = MockERC20(address(asset_));
        }
        _decimals = uint8(asset.decimals());
    }

    function setDecimals(uint8 _decimals_) external {
        _decimals = _decimals_;
    }

    function assetInfo() external view returns (AssetType assetType, address asset_, uint8 decimals_) {
        assetType = AssetType.ERC20;
        asset_ = address(asset);
        decimals_ = uint8(asset.decimals());
    }

    function exchangeRate() external pure returns (uint256) {
        return 1e18;
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

    function deposit(
        address,
        address,
        uint256 amountTokenToDeposit,
        uint256
    )
        external
        payable
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = amountTokenToDeposit;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1e18;
    }

    function getTokensIn() external view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(asset);
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
