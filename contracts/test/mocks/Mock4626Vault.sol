// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mock4626Vault is ERC20 {
    uint256 public totalAssets;
    uint256 public totalShares;
    mapping(address => uint256) public amountOf;

  constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC4626(asset_) ERC20(name_, symbol_) {}
    constructor(address _asset) ERC20("Mock4626Vault", "M4626V") {
        asset = _asset;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    error AMOUNT_NOT_VALID();

    function previewDeposit(uint256 assets) external pure returns (uint256 shares) {
        return assets;
    }

    function previewWithdraw(uint256 shares) external pure returns (uint256 assets) {
        return shares;
    }
    
    function previewRedeem(uint256 shares) external pure returns (uint256 assets) {
        return shares;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, AMOUNT_NOT_VALID());
        shares = assets; // 1:1 ratio for simplicity
        totalAssets += assets;
        totalShares += shares;
        amountOf[receiver] += assets;
        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(shares > 0, AMOUNT_NOT_VALID());
        require(shares <= totalShares, AMOUNT_NOT_VALID());

        assets = shares; // 1:1 ratio for simplicity
        totalAssets -= assets;
        totalShares -= shares;
        amountOf[owner] -= assets;
        IERC20(asset).transfer(receiver, assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
