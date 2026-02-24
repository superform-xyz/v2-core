// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IYoVault } from "../../vendor/yo/IYoVault.sol";

/// @title YoYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Yo Vaults with async redemption support
/// @dev Accounts for both held shares and pending async redemption requests
///      Total position value = held_value + pending_value
///      Where:
///      - held_value = yoVault.convertToAssets(yoVault.balanceOf(owner))
///      - pending_value = yoVault.pendingRedeemRequest(owner).assets
contract YoYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the decimals of the Yo Vault share token
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IYoVault(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns expected shares from depositing assets
    /// @dev Uses previewDeposit() for accurate post-fee share amounts
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        return IYoVault(yieldSourceAddress).previewDeposit(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns shares needed to withdraw a specific amount of assets
    /// @dev Manually calculates using convertToAssets() with vault's actual decimals
    ///      Uses Ceil rounding to favor the vault (user pays slightly more shares)
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        IYoVault vault = IYoVault(yieldSourceAddress);
        uint256 shareDecimals = vault.decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns assets redeemable for a given amount of shares
    /// @dev Uses convertToAssets() for the conversion
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        return IYoVault(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns price per share in asset terms
    /// @dev Converts one full share (10^decimals) to assets
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IYoVault vault = IYoVault(yieldSourceAddress);
        uint256 _decimals = vault.decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns share balance of a given owner
    /// @dev Returns only held shares, NOT including pending redemptions
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IYoVault(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total value locked (in assets) for a given share owner
    /// @dev KEY METHOD: Includes both held shares value AND pending async redemption value
    ///      This ensures PPS stability during async redemption cycles
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        IYoVault vault = IYoVault(yieldSourceAddress);

        // Component 1: Value of held shares
        uint256 heldShares = vault.balanceOf(ownerOfShares);
        uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

        // Component 2: Value of pending async redemptions
        (uint256 pendingAssets,) = vault.pendingRedeemRequest(ownerOfShares);

        // Total position value
        return heldValue + pendingAssets;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total assets managed by the vault
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IYoVault(yieldSourceAddress).totalAssets();
    }
}
