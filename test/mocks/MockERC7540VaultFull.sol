// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockERC20 } from "./MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockERC7540VaultFull
/// @notice Comprehensive mock for ERC-7540 vaults with settable state for all 5 TVL components
/// @dev Used for unit testing ERC7540YieldSourceOracle. Each component is independently configurable.
///      Supports simulating reverts on individual functions for R2 (graceful degradation) testing.
contract MockERC7540VaultFull {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    MockERC20 public assetToken;
    MockERC20 public shareToken;

    /// @dev Exchange rate: assets per 1e{shareDecimals} shares
    uint256 public assetsPerShare;

    /// @dev Per-controller pending redeem shares
    mapping(address => uint256) public pendingRedeemShares;

    /// @dev Per-controller max withdrawable assets (claimable redeem)
    mapping(address => uint256) public maxWithdrawAssets;

    /// @dev Per-controller pending deposit assets
    mapping(address => uint256) public pendingDepositAssets;

    /// @dev Per-controller claimable deposit assets
    mapping(address => uint256) public claimableDepositAssets;

    /// @dev Total assets managed by the vault
    uint256 public vaultTotalAssets;

    /// @dev Flags to simulate reverts on specific functions
    bool public revertOnPendingRedeemRequest;
    bool public revertOnMaxWithdraw;
    bool public revertOnPendingDepositRequest;
    bool public revertOnClaimableDepositRequest;
    bool public revertOnConvertToAssets;
    bool public revertOnConvertToShares;

    /// @dev When true, async request functions validate the requestId parameter
    bool public enforceRequestId;
    uint256 public expectedRequestId;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint8 assetDecimals_, uint8 shareDecimals_) {
        assetToken = new MockERC20("MockAsset", "MA", assetDecimals_);
        shareToken = new MockERC20("MockShare", "MS", shareDecimals_);
        // Default 1:1 exchange rate
        assetsPerShare = 10 ** assetDecimals_;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7575 INTERFACE
    //////////////////////////////////////////////////////////////*/

    function share() external view returns (address) {
        return address(shareToken);
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-4626 VIEW INTERFACE
    //////////////////////////////////////////////////////////////*/

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (revertOnConvertToAssets) revert("convertToAssets reverted");
        uint256 oneShare = 10 ** shareToken.decimals();
        if (oneShare == 0) return 0;
        return (shares * assetsPerShare) / oneShare;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (revertOnConvertToShares) revert("convertToShares reverted");
        if (assetsPerShare == 0) return 0;
        uint256 oneShare = 10 ** shareToken.decimals();
        return (assets * oneShare) / assetsPerShare;
    }

    function totalAssets() external view returns (uint256) {
        return vaultTotalAssets;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        if (revertOnMaxWithdraw) revert("maxWithdraw reverted");
        return maxWithdrawAssets[owner];
    }

    function maxRedeem(address) external pure returns (uint256) {
        return 0;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256) external pure returns (uint256) {
        revert("async vault: previewRedeem not supported");
    }

    function previewWithdraw(uint256) external pure returns (uint256) {
        revert("async vault: previewWithdraw not supported");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 VIEW INTERFACE
    //////////////////////////////////////////////////////////////*/

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256) {
        if (revertOnPendingRedeemRequest) revert("pendingRedeemRequest reverted");
        if (enforceRequestId && requestId != expectedRequestId) revert("wrong requestId");
        return pendingRedeemShares[controller];
    }

    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256) {
        if (revertOnPendingDepositRequest) revert("pendingDepositRequest reverted");
        if (enforceRequestId && requestId != expectedRequestId) revert("wrong requestId");
        return pendingDepositAssets[controller];
    }

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256) {
        if (revertOnClaimableDepositRequest) revert("claimableDepositRequest reverted");
        if (enforceRequestId && requestId != expectedRequestId) revert("wrong requestId");
        return claimableDepositAssets[controller];
    }

    function claimableRedeemRequest(uint256, address) external pure returns (uint256) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS (TEST ONLY)
    //////////////////////////////////////////////////////////////*/

    function setAssetsPerShare(uint256 assetsPerShare_) external {
        assetsPerShare = assetsPerShare_;
    }

    function setPendingRedeemShares(address controller, uint256 shares) external {
        pendingRedeemShares[controller] = shares;
    }

    function setMaxWithdrawAssets(address controller, uint256 assets) external {
        maxWithdrawAssets[controller] = assets;
    }

    function setPendingDepositAssets(address controller, uint256 assets) external {
        pendingDepositAssets[controller] = assets;
    }

    function setClaimableDepositAssets(address controller, uint256 assets) external {
        claimableDepositAssets[controller] = assets;
    }

    function setTotalAssets(uint256 totalAssets_) external {
        vaultTotalAssets = totalAssets_;
    }

    function setRevertOnPendingRedeemRequest(bool revert_) external {
        revertOnPendingRedeemRequest = revert_;
    }

    function setRevertOnMaxWithdraw(bool revert_) external {
        revertOnMaxWithdraw = revert_;
    }

    function setRevertOnPendingDepositRequest(bool revert_) external {
        revertOnPendingDepositRequest = revert_;
    }

    function setRevertOnClaimableDepositRequest(bool revert_) external {
        revertOnClaimableDepositRequest = revert_;
    }

    function setRevertOnConvertToAssets(bool revert_) external {
        revertOnConvertToAssets = revert_;
    }

    function setRevertOnConvertToShares(bool revert_) external {
        revertOnConvertToShares = revert_;
    }

    function setEnforceRequestId(bool enforce_, uint256 requestId_) external {
        enforceRequestId = enforce_;
        expectedRequestId = requestId_;
    }

    /// @notice Mint share tokens to an address (simulates holding shares)
    function mintShares(address to, uint256 amount) external {
        shareToken.mint(to, amount);
    }

    /// @notice Burn share tokens from an address (simulates redeem request)
    function burnShares(address from, uint256 amount) external {
        shareToken.burn(from, amount);
    }
}
