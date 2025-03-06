// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title RuggableVault
 * @notice A mock ERC4626 vault that can simulate a rug pull by not transferring assets or shares
 * @dev This is for testing purposes only to simulate malicious behavior
 */
contract RuggableVault is ERC20, IERC4626 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _decimals;

    // Rug pull configuration
    bool public rugOnDeposit;
    bool public rugOnWithdraw;
    uint256 public rugPercentage; // 0-10000, where 10000 = 100%

    // Events for testing
    event RugPull(string action, address user, uint256 amount, uint256 ruggedAmount);

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        bool rugOnDeposit_,
        bool rugOnWithdraw_,
        uint256 rugPercentage_
    )
        ERC20(name_, symbol_)
    {
        _asset = asset_;
        _decimals = IERC20Metadata(address(asset_)).decimals();

        rugOnDeposit = rugOnDeposit_;
        rugOnWithdraw = rugOnWithdraw_;
        rugPercentage = rugPercentage_ > 10_000 ? 10_000 : rugPercentage_;
    }

    // Configuration functions
    function setRugOnDeposit(bool value) external {
        rugOnDeposit = value;
    }

    function setRugOnWithdraw(bool value) external {
        rugOnWithdraw = value;
    }

    function setRugPercentage(uint256 percentage) external {
        rugPercentage = percentage > 10_000 ? 10_000 : percentage;
    }

    // Calculate rugged amount
    function calculateRuggedAmount(uint256 amount) public view returns (uint256) {
        return amount * rugPercentage / 10_000;
    }

    // ERC4626 implementation
    function asset() public view override returns (address) {
        return address(_asset);
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        uint256 totalAssets_ = totalAssets();
        return supply == 0 || totalAssets_ == 0 ? assets : assets.mulDiv(supply, totalAssets_, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDiv(totalAssets(), supply, Math.Rounding.Floor);
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
        uint256 supply = totalSupply();
        uint256 totalAssets_ = totalAssets();
        return supply == 0 || totalAssets_ == 0 ? shares : shares.mulDiv(totalAssets_, supply, Math.Rounding.Ceil);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        uint256 totalAssets_ = totalAssets();
        return supply == 0 || totalAssets_ == 0 ? assets : assets.mulDiv(supply, totalAssets_, Math.Rounding.Ceil);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 shares = previewDeposit(assets);

        // Take assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        if (rugOnDeposit) {
            // Calculate how much to rug
            uint256 ruggedShares = calculateRuggedAmount(shares);
            uint256 actualShares = shares - ruggedShares;

            // Mint only a portion of the shares
            _mint(receiver, actualShares);

            emit RugPull("deposit", receiver, shares, ruggedShares);
            return actualShares;
        } else {
            // Normal behavior
            _mint(receiver, shares);
            return shares;
        }
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = previewMint(shares);

        // Take assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        if (rugOnDeposit) {
            // Calculate how much to rug
            uint256 ruggedShares = calculateRuggedAmount(shares);
            uint256 actualShares = shares - ruggedShares;

            // Mint only a portion of the shares
            _mint(receiver, actualShares);

            emit RugPull("mint", receiver, shares, ruggedShares);
            return assets;
        } else {
            // Normal behavior
            _mint(receiver, shares);
            return assets;
        }
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);

        if (rugOnWithdraw) {
            // Calculate how much to rug
            uint256 ruggedAssets = calculateRuggedAmount(assets);
            uint256 actualAssets = assets - ruggedAssets;

            // Transfer only a portion of the assets
            _asset.safeTransfer(receiver, actualAssets);

            emit RugPull("withdraw", receiver, assets, ruggedAssets);
            return shares;
        } else {
            // Normal behavior
            _asset.safeTransfer(receiver, assets);
            return shares;
        }
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 assets = previewRedeem(shares);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        _burn(owner, shares);

        if (rugOnWithdraw) {
            // Calculate how much to rug
            uint256 ruggedAssets = calculateRuggedAmount(assets);
            uint256 actualAssets = assets - ruggedAssets;

            // Transfer only a portion of the assets
            _asset.safeTransfer(receiver, actualAssets);

            emit RugPull("redeem", receiver, assets, ruggedAssets);
            return actualAssets;
        } else {
            // Normal behavior
            _asset.safeTransfer(receiver, assets);
            return assets;
        }
    }
}
