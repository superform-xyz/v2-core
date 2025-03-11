// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Mock4626Vault is ERC4626 {
    uint256 public _totalAssets;
    uint256 public _totalShares;
    mapping(address => uint256) public amountOf;

    bool public lessAmount;

    address public _asset;
    IERC20 private immutable assetInstance;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC4626(asset_) ERC20(name_, symbol_) {
        assetInstance = asset_;
        _asset = address(asset_);
    }

    function setLessAmount(bool lessAmount_) external {
        lessAmount = lessAmount_;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    error AMOUNT_NOT_VALID();

    function previewDeposit(uint256 assets) public pure override returns (uint256 shares) {
        return assets;
    }

    function previewWithdraw(uint256 shares) public pure override returns (uint256 assets) {
        return shares;
    }

    function previewRedeem(uint256 shares) public pure override returns (uint256 assets) {
        return shares;
    }

    function convertToAssets(uint256 shares) public pure override returns (uint256 assets) {
        return shares;
    }

    function convertToShares(uint256 assets) public pure override returns (uint256 shares) {
        return assets;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, AMOUNT_NOT_VALID());
        uint256 amount = lessAmount ? assets / 2 : assets;
        shares = amount; // 1:1 ratio for simplicity in case lessAmount is false
        _totalAssets += amount;
        _totalShares += shares;
        amountOf[receiver] += amount;
        IERC20(_asset).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, AMOUNT_NOT_VALID());
        require(shares <= _totalShares, AMOUNT_NOT_VALID());

        assets = shares; // 1:1 ratio for simplicity
        _totalAssets -= assets;
        _totalShares -= shares;
        amountOf[owner] -= assets;
        IERC20(_asset).transfer(receiver, assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }
}
