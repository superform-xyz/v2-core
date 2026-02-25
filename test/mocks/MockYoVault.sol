// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IYoVault } from "../../src/vendor/yo/IYoVault.sol";

/// @title MockYoVault
/// @notice Mock implementation of Yo Vault for testing YoYieldSourceOracle
/// @dev Simulates async redemption behavior with configurable pending requests
contract MockYoVault is ERC20, IYoVault {
    IERC20 public immutable asset;
    uint8 private immutable _decimals;

    uint256 public _totalAssets;
    uint256 public pricePerShare = 1e18; // 1:1 by default for 18 decimal tokens

    // Pending redemption tracking (address-based accumulator pattern)
    mapping(address => uint256) public pendingAssets;
    mapping(address => uint256) public pendingShares;

    // Claimable assets tracking (fulfilled but not yet claimed)
    mapping(address => uint256) public claimableAssets;

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    )
        ERC20(name_, symbol_)
    {
        asset = IERC20(asset_);
        _decimals = decimals_;
        // Set price per share to match decimals (e.g., 1e18 for 18 decimals, 1e6 for 6 decimals)
        pricePerShare = 10 ** decimals_;
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the price per share for testing
    /// @param pps New price per share (scaled by decimals)
    function setPricePerShare(uint256 pps) external {
        pricePerShare = pps;
    }

    /// @notice Set pending redeem request for an address (for testing)
    /// @param owner The address to set pending request for
    /// @param assets_ The pending assets amount
    /// @param shares_ The pending shares amount
    function setPendingRedeemRequest(address owner, uint256 assets_, uint256 shares_) external {
        pendingAssets[owner] = assets_;
        pendingShares[owner] = shares_;
    }

    /// @notice Simulate a deposit
    /// @param to Recipient of shares
    /// @param assets_ Amount of assets to deposit
    function simulateDeposit(address to, uint256 assets_) external {
        asset.transferFrom(msg.sender, address(this), assets_);
        uint256 shares_ = convertToShares(assets_);
        _totalAssets += assets_;
        _mint(to, shares_);
    }

    /// @notice Simulate an async redeem request (burns shares, adds to pending)
    /// @param owner Owner of shares
    /// @param shares_ Shares to redeem
    function simulateRequestRedeem(address owner, uint256 shares_) external {
        require(balanceOf(owner) >= shares_, "Insufficient shares");
        uint256 assets_ = convertToAssets(shares_);
        _burn(owner, shares_);
        pendingAssets[owner] += assets_;
        pendingShares[owner] += shares_;
    }

    /// @notice Simulate fulfillment of pending redemption
    /// @param owner Owner with pending redemption
    function simulateFulfillRedeem(address owner) external {
        uint256 assets_ = pendingAssets[owner];
        require(assets_ > 0, "No pending redemption");
        pendingAssets[owner] = 0;
        pendingShares[owner] = 0;
        _totalAssets -= assets_;
        asset.transfer(owner, assets_);
    }

    /// @notice Simulate partial fulfillment
    /// @param owner Owner with pending redemption
    /// @param assetsToFulfill Amount of assets to fulfill
    function simulatePartialFulfillRedeem(address owner, uint256 assetsToFulfill) external {
        require(pendingAssets[owner] >= assetsToFulfill, "Exceeds pending");
        pendingAssets[owner] -= assetsToFulfill;
        // Note: pendingShares reduction would be proportional in real implementation
        _totalAssets -= assetsToFulfill;
        asset.transfer(owner, assetsToFulfill);
    }

    /*//////////////////////////////////////////////////////////////
                            IYoVault IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYoVault
    function balanceOf(address account) public view override(ERC20, IYoVault) returns (uint256) {
        return super.balanceOf(account);
    }

    /// @inheritdoc IYoVault
    function decimals() public view override(ERC20, IYoVault) returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IYoVault
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 oneShare = 10 ** _decimals;
        return (shares * pricePerShare) / oneShare;
    }

    /// @inheritdoc IYoVault
    function convertToShares(uint256 assets_) public view override returns (uint256) {
        uint256 oneShare = 10 ** _decimals;
        if (pricePerShare == 0) return 0;
        return (assets_ * oneShare) / pricePerShare;
    }

    /// @inheritdoc IYoVault
    function pendingRedeemRequest(address owner) external view override returns (uint256 assets_, uint256 shares_) {
        return (pendingAssets[owner], pendingShares[owner]);
    }

    /// @inheritdoc IYoVault
    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    /// @inheritdoc ERC20
    /// @dev Override to satisfy both ERC20 and IYoVault interfaces
    function totalSupply() public view override(ERC20, IYoVault) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IYoVault
    function previewDeposit(uint256 assets_) external view override returns (uint256) {
        return convertToShares(assets_);
    }

    /// @inheritdoc IYoVault
    /// @notice Request async redemption of shares
    /// @dev In mock, this simulates the async redemption by burning shares and adding to pending.
    ///      Pending is tracked by owner (not receiver) to match pendingRedeemRequest(owner) semantics.
    ///      The receiver parameter indicates who will receive assets when fulfilled, but the
    ///      pending request is associated with the owner for TVL tracking purposes.
    function requestRedeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        require(balanceOf(owner) >= shares, "Insufficient shares");
        uint256 assets_ = convertToAssets(shares);
        _burn(owner, shares);
        // Track pending by owner to match pendingRedeemRequest(owner) lookup
        pendingAssets[owner] += assets_;
        pendingShares[owner] += shares;
        // Note: receiver is stored separately in real vault for fulfillment, not needed for mock
        return assets_;
    }

    /// @inheritdoc IYoVault
    /// @notice Returns claimable assets from fulfilled redeem requests
    function claimableRedeemRequest(address owner) external view override returns (uint256) {
        return claimableAssets[owner];
    }

    /*//////////////////////////////////////////////////////////////
                            TESTING HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set claimable assets for an address (for testing)
    /// @param owner The address to set claimable assets for
    /// @param assets_ The claimable assets amount
    function setClaimableRedeemRequest(address owner, uint256 assets_) external {
        claimableAssets[owner] = assets_;
    }

    /// @notice Mint shares to an address (for testing)
    /// @param to Recipient of shares
    /// @param amount Amount of shares to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn shares from an address (for testing)
    /// @param from Address to burn from
    /// @param amount Amount of shares to burn
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @notice Set total assets directly (for testing)
    /// @param amount Total assets to set
    function setTotalAssets(uint256 amount) external {
        _totalAssets = amount;
    }
}
