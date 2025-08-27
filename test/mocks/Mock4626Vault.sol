// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import "forge-std/console2.sol";

contract Mock4626Vault is ERC4626 {
    uint256 public _totalAssets;
    uint256 public _totalShares;
    mapping(address => uint256) public amountOf;

    bool public lessAmount;

    address public _asset;
    IERC20 private immutable assetInstance;

    uint256 public yield;
    uint256 public yield_precision = 1e5;

    // Track deposit timestamps for yield calculation
    mapping(address => uint256) public depositTimestamps;

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_
    )
        ERC4626(IERC20(asset_))
        ERC20(name_, symbol_)
    {
        assetInstance = IERC20(asset_);
        _asset = address(asset_);
    }

    function setAsset(address _a) external {
        _asset = _a;
    }

    function setYield(uint256 yield_) external {
        yield = yield_;
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

    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        // If yield is set, calculate accrued yield based on time
        if (yield > 0 && msg.sender != address(0) && depositTimestamps[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - depositTimestamps[msg.sender];
            uint256 yieldFactor = yield * timeElapsed / (365 days);
            return shares + (shares * yieldFactor / yield_precision);
        }
        return shares;
    }

    function convertToShares(uint256 assets) public pure override returns (uint256 shares) {
        return assets;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        console2.log("------------A", assets);
        require(assets > 0, AMOUNT_NOT_VALID());
        uint256 amount = lessAmount ? assets / 2 : assets;
        shares = amount; // 1:1 ratio for simplicity in case lessAmount is false
        _totalAssets += amount;
        _totalShares += shares;
        amountOf[receiver] += amount;

        // Record deposit timestamp for yield calculation
        depositTimestamps[receiver] = block.timestamp;

        IERC20(_asset).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, AMOUNT_NOT_VALID());
        require(shares <= _totalShares, AMOUNT_NOT_VALID());

        // Calculate assets with potential yield
        if (yield > 0 && depositTimestamps[owner] > 0) {
            uint256 timeElapsed = block.timestamp - depositTimestamps[owner];
            uint256 yieldFactor = yield * timeElapsed / (365 days);
            assets = shares + (shares * yieldFactor / yield_precision);
        } else {
            assets = shares; // 1:1 ratio for simplicity when no yield
        }

        _totalAssets -= assets;
        _totalShares -= shares;
        amountOf[owner] -= assets;

        // Reset deposit timestamp
        depositTimestamps[owner] = 0;

        IERC20(_asset).transfer(receiver, assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function exchangeRate() external pure returns (uint256) {
        return 1e18;
    }

    function readTokens() external view returns (address sy, address pt, address yt) {
        return (_asset, _asset, _asset);
    }

    function expiry() external pure returns (uint256) {
        return 1e18;
    }

    function observe(uint32[] calldata) external pure returns (uint216[] memory, uint216[] memory) {
        uint216[] memory logImpliedRates = new uint216[](2);
        uint216[] memory logPYIndexes = new uint216[](2);
        
        // Return mock values
        logImpliedRates[0] = uint216(1e18);
        logImpliedRates[1] = uint216(1e18);
        logPYIndexes[0] = uint216(1e18);
        logPYIndexes[1] = uint216(1e18);
        
        return (logImpliedRates, logPYIndexes);
    }

    function totalAssets() public view override returns (uint256) {
        // For simplicity, we don't include accrued yield in totalAssets
        return _totalAssets;
    }
}
