// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MockAccountingVault is ERC4626 {
    address public immutable _asset;
    IERC20 private immutable assetInstance;

    bool public useCustomConversions;
    uint256 public pps; //price per share

    error AMOUNT_NOT_VALID();

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC4626(asset_) ERC20(name_, symbol_) {
        assetInstance = asset_;
        _asset = address(asset_);
        pps = 1e18;
    }

    // VIEW METHODS
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function totalAssets() public view override returns (uint256) {
        return assetInstance.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        if (useCustomConversions) {
            return (assets * (10 ** decimals())) / pps;
        }
        uint256 supply = totalSupply();
        return (supply == 0 || totalAssets() == 0) ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        if (useCustomConversions) {
            return (shares * pps) / (10 ** decimals());
        }
        uint256 supply = totalSupply();
        return (supply == 0 || totalAssets() == 0) ? shares : (shares * totalAssets()) / supply;
    }

    function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 shares) public view override returns (uint256 assets) {
        return convertToAssets(shares);
    }

    // WRITE METHODS
    function setUseCustomConversions(bool useCustomConversions_) external {
        useCustomConversions = useCustomConversions_;
    }

    function setCustomPps(uint256 pps_) external {
        pps = pps_;
        useCustomConversions = true;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, "AMOUNT_NOT_VALID");
        shares = convertToShares(assets);

        assetInstance.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, "AMOUNT_NOT_VALID");
        require(shares <= balanceOf(owner), "INSUFFICIENT_SHARES");

        assets = convertToAssets(shares);
        _burn(owner, shares);
        assetInstance.transfer(receiver, assets);
    }
}
