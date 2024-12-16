// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Mock4626Vault is ERC4626 {
    uint256 public totalAssets;
    uint256 public totalShares;
    mapping(address => uint256) public amountOf;

    address public _asset;
    IERC20 private immutable assetInstance;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC4626(asset_) ERC20(name_, symbol_) {
        assetInstance = asset_;
        _asset = address(asset_);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

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

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, AMOUNT_NOT_VALID());
        shares = assets; // 1:1 ratio for simplicity
        totalAssets += assets;
        totalShares += shares;
        amountOf[receiver] += assets;
        IERC20(_asset).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, AMOUNT_NOT_VALID());
        require(shares <= totalShares, AMOUNT_NOT_VALID());

        assets = shares; // 1:1 ratio for simplicity
        totalAssets -= assets;
        totalShares -= shares;
        amountOf[owner] -= assets;
        IERC20(_asset).transfer(receiver, assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
