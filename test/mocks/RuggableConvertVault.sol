// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title RuggableConvertVault
 * @notice A mock ERC4626 vault that rugs by misreporting totalAssets and conversion functions
 * @dev This is for testing purposes only to simulate malicious behavior in price reporting
 */
contract RuggableConvertVault is ERC20, IERC4626 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _decimals;

    // Rug pull configuration
    uint256 public rugPercentage; // 0-10000, where 10000 = 100%
    bool public rugEnabled;

    // Events for testing
    event RugPull(string action, address user, uint256 realAmount, uint256 reportedAmount);

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint256 rugPercentage_,
        bool rugEnabled_
    )
        ERC20(name_, symbol_)
    {
        _asset = asset_;
        _decimals = IERC20Metadata(address(asset_)).decimals();
        rugPercentage = rugPercentage_ > 10_000 ? 10_000 : rugPercentage_;
        rugEnabled = rugEnabled_;
    }

    // Configuration functions
    function setRugEnabled(bool value) external {
        rugEnabled = value;
    }

    function setRugPercentage(uint256 percentage) external {
        rugPercentage = percentage > 10_000 ? 10_000 : percentage;
    }

    // ERC4626 implementation
    function asset() public view override returns (address) {
        return address(_asset);
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 actualAssets = _asset.balanceOf(address(this));

        if (rugEnabled) {
            // Apply rug factor to inflate reported assets
            return actualAssets * (10_000 + rugPercentage) / 10_000;
        } else {
            return actualAssets;
        }
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();

        if (supply == 0) {
            return assets;
        }

        uint256 actualAssets = _asset.balanceOf(address(this));

        if (rugEnabled) {
            // Apply rug factor to inflate reported assets
            uint256 inflatedAssets = actualAssets * (10_000 + rugPercentage) / 10_000;
            return assets * supply / inflatedAssets;
        } else {
            return assets * supply / actualAssets;
        }
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return shares;
        }

        uint256 actualAssets = _asset.balanceOf(address(this));

        if (rugEnabled) {
            // Apply rug factor to inflate reported assets
            uint256 inflatedAssets = actualAssets * (10_000 + rugPercentage) / 10_000;
            return shares * inflatedAssets / supply;
        } else {
            return shares * actualAssets / supply;
        }
    }

    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();

        if (supply == 0) {
            return 0;
        }

        uint256 actualAssets = _asset.balanceOf(address(this));

        if (rugEnabled) {
            // Apply rug factor to inflate reported assets
            uint256 inflatedAssets = actualAssets * (10_000 + rugPercentage) / 10_000;
            return assets * supply / inflatedAssets;
        } else {
            return assets * supply / actualAssets;
        }
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        rugEnabled = false;
        uint256 shares = previewDeposit(assets);
        rugEnabled = true;

        // Take assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Mint shares
        _mint(receiver, shares);

        emit RugPull("deposit", receiver, shares, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        rugEnabled = false;
        uint256 assets = previewMint(shares);
        rugEnabled = true;

        // Take assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Mint shares
        _mint(receiver, shares);

        emit RugPull("mint", receiver, assets, assets);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        rugEnabled = false;
        uint256 shares = previewWithdraw(assets);
        rugEnabled = true;

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);
        _asset.safeTransfer(receiver, assets);

        emit RugPull("withdraw", receiver, shares, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        rugEnabled = false;
        uint256 assets = previewRedeem(shares);
        rugEnabled = true;

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);
        _asset.safeTransfer(receiver, assets);

        emit RugPull("redeem", receiver, assets, assets);

        return assets;
    }
}
