// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { ISuperVault } from "../../vendor/superform/ISuperVault.sol";
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title SuperVaultYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for SuperVault (ERC4626 + ERC7540 async redeem)
/// @dev Specifically handles SuperVault's unique characteristics:
///      - Synchronous deposits using previewDeposit() (includes management fees)
///      - Asynchronous redeems using convertToAssets() (previewRedeem reverts)
///      - Uses vault's own decimals for calculations (not hardcoded 1e18)
contract SuperVaultYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the decimals of the SuperVault share token
    /// @dev SuperVault is its own share token, so we call decimals() directly
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return ISuperVault(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns expected shares from depositing assets (includes management fees)
    /// @dev Uses previewDeposit() which accounts for management fees charged by SuperVault
    ///      This provides accurate post-fee share amounts users will receive
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
        return ISuperVault(yieldSourceAddress).previewDeposit(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns shares needed to withdraw a specific amount of assets
    /// @dev Cannot use previewWithdraw() as it reverts for async redeems
    ///      Manually calculates using convertToAssets() with vault's actual decimals
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
        ISuperVault vault = ISuperVault(yieldSourceAddress);
        uint256 shareDecimals = vault.decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns assets redeemable for a given amount of shares
    /// @dev Uses convertToAssets() as previewRedeem() reverts for async redeems
    ///      Actual redeem amounts may differ due to async fulfillment pricing
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
        return ISuperVault(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns price per share in asset terms
    /// @dev Converts one full share (10^decimals) to assets using vault's stored PPS
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        ISuperVault vault = ISuperVault(yieldSourceAddress);
        uint256 _decimals = vault.decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns share balance of a given owner
    /// @dev SuperVault is its own share token (ERC20)
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total value locked (in assets) for a given share owner
    /// @dev Converts owner's share balance to asset amount using vault's convertToAssets
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        ISuperVault vault = ISuperVault(yieldSourceAddress);
        uint256 shares = IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return vault.convertToAssets(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total assets managed by the vault
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return ISuperVault(yieldSourceAddress).totalAssets();
    }
}
