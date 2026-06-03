// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IERC7540 } from "../../vendor/vaults/7540/IERC7540.sol";

/// @title SpectraMetaVaultOracle
/// @author Superform Labs
/// @notice Oracle for Spectra MetaVaultWrapper (ERC-7540 async vault over Amphor AsyncVault)
/// @dev Fixes two issues in the generic ERC7540YieldSourceOracle for MetaVaultWrapper:
///      1. getTVL uses convertToAssets(totalSupply()) instead of totalAssets() — MetaVaultWrapper
///         does not override totalAssets(), so it returns idle USDC (0) instead of vault NAV.
///      2. Component 3 (claimable redeem) uses claimableRedeemRequest → convertToAssets instead
///         of maxWithdraw — MetaVaultWrapper does not override maxWithdraw(), so it uses OZ
///         _convertToAssets (totalAssets/totalSupply ratio) instead of the epoch snapshot rate.
///      All other behavior (Components 1, 2, 4, 5, PPS, share token discovery) is identical
///      to ERC7540YieldSourceOracle.
contract SpectraMetaVaultOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The requestId used for accumulated-pattern 7540 vaults
    /// @dev Most 7540 vaults use requestId=0 (accumulated pattern). Set via constructor
    ///      to allow separate oracle instances for vaults using per-request IDs.
    uint256 public immutable REQUEST_ID;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor to set the SuperLedgerConfiguration address and request ID
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param requestId_ The requestId to use for pending/claimable queries (typically 0)
    constructor(
        address superLedgerConfiguration_,
        uint256 requestId_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        REQUEST_ID = requestId_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the decimals of the 7540 vault's share token
    /// @dev Uses ERC-7575 share() to discover the share token, falling back to the vault
    ///      address itself for ERC-4626-style vaults where vault IS the share token.
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address shareToken = _getShareToken(yieldSourceAddress);
        return IERC20Metadata(shareToken).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns expected shares from depositing assets
    /// @dev Uses convertToShares() (not previewDeposit) — previewDeposit may revert on async vaults
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
        return IERC7540(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns shares needed to withdraw a specific amount of assets
    /// @dev Manually calculates using convertToAssets() with vault's share decimals.
    ///      Uses Ceil rounding to favor the vault (user pays slightly more shares).
    ///      Cannot use previewWithdraw() as it reverts for async redeems.
    ///      R1: Reverts when convertToAssets returns 0 (unsettled epoch / invalid vault state).
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
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);
        uint256 shareDecimals = IERC20Metadata(shareToken).decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        require(assetsPerShare > 0, "SpectraMetaVaultOracle: PPS unavailable");

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns assets redeemable for a given amount of shares
    /// @dev Uses convertToAssets() (not previewRedeem) — previewRedeem reverts on async 7540 vaults
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
        return IERC7540(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns price per share in asset terms
    /// @dev R1: Hard revert. PPS must be correct or absent — returning 0/stale causes incorrect fees.
    ///      Converts one full share (10^decimals) to assets using vault's convertToAssets.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);
        uint256 _decimals = IERC20Metadata(shareToken).decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns share balance of a given owner
    /// @dev Uses ERC-7575 share() or falls back to vault address for share token discovery
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256)
    {
        address shareToken = _getShareToken(yieldSourceAddress);
        return IERC20(shareToken).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total value locked (in assets) for a given share owner
    /// @dev R2: Graceful degradation. Each async component wrapped in try/catch.
    ///      On failure, component = 0 (drops individually, never reverts entirely).
    ///      Five components: held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = getAsyncStateBreakdown(yieldSourceAddress, ownerOfShares);

        return heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total assets managed by the vault
    /// @dev Uses convertToAssets(totalSupply()) instead of totalAssets().
    ///      MetaVaultWrapper does not override totalAssets() from OZ ERC4626Upgradeable,
    ///      so the OZ default returns asset.balanceOf(vault) = idle USDC (typically 0)
    ///      instead of the actual vault NAV.
    ///      NOTE: Does not include pending or claimable deposits (assets not yet minted as shares).
    ///      getTVL may be less than sum(getTVLByOwnerOfShares) when deposits are pending settlement.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);
        return vault.convertToAssets(IERC20(shareToken).totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 SPECIFIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all 5 TVL components individually for monitoring instrumentation
    /// @dev Component 3 uses claimableRedeemRequest → convertToAssets instead of maxWithdraw.
    ///      MetaVaultWrapper does not override maxWithdraw(), so it uses OZ _convertToAssets
    ///      (totalAssets/totalSupply ratio) which gives a meaningless value when totalAssets = 0.
    ///      Each async component (2-5) is wrapped in try/catch for graceful degradation (R2).
    ///      Inner convertToAssets calls are also wrapped to prevent a revert in one component
    ///      from taking down the entire breakdown.
    ///      Component 1 (held shares) is not wrapped — if balanceOf reverts,
    ///      the vault is misconfigured and should not be registered.
    /// @param yieldSourceAddress The ERC-7540 vault address
    /// @param owner The smart account whose position to value (must be controller in 7540 terms)
    /// @return heldValue Value of shares in balanceOf (assets)
    /// @return pendingRedeemValue Value of shares in pending redeem state (assets)
    /// @return claimableRedeemValue Value of claimable redeem via claimableRedeemRequest (assets)
    /// @return pendingDepositValue Assets in pending deposit state
    /// @return claimableDepositValue Assets in claimable deposit state
    function getAsyncStateBreakdown(
        address yieldSourceAddress,
        address owner
    )
        public
        view
        returns (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        )
    {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);

        // Component 1: Held shares value (R1 — no try/catch, misconfigured vault should revert)
        uint256 heldShares = IERC20(shareToken).balanceOf(owner);
        if (heldShares > 0) {
            heldValue = vault.convertToAssets(heldShares);
        }

        // Component 2: Pending redeem value (shares → assets via convertToAssets)
        try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
            if (pendingShares > 0) {
                try vault.convertToAssets(pendingShares) returns (uint256 value) {
                    pendingRedeemValue = value;
                } catch { } // R2: convertToAssets revert → component defaults to 0
            }
        } catch { } // R2: pendingRedeemRequest not supported → component defaults to 0

        // Component 3: Claimable redeem value
        // Uses claimableRedeemRequest → convertToAssets instead of maxWithdraw.
        // maxWithdraw uses OZ _convertToAssets (totalAssets/totalSupply ratio = 0).
        try vault.claimableRedeemRequest(REQUEST_ID, owner) returns (uint256 claimableShares) {
            if (claimableShares > 0) {
                try vault.convertToAssets(claimableShares) returns (uint256 value) {
                    claimableRedeemValue = value;
                } catch { } // R2: convertToAssets revert → component defaults to 0
            }
        } catch { } // R2: claimableRedeemRequest not supported → component defaults to 0

        // Component 4: Pending deposit value (already in assets)
        try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
            pendingDepositValue = pendingAssets;
        } catch { } // R2: pendingDepositRequest not supported → component defaults to 0

        // Component 5: Claimable deposit value (already in assets)
        try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
            claimableDepositValue = claimableAssets;
        } catch { } // R2: claimableDepositRequest not supported → component defaults to 0
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Discovers the share token for a vault
    /// @dev Tries ERC-7575 share() first. If not implemented (reverts) or returns address(0),
    ///      falls back to treating the vault address itself as the share token (ERC-4626 pattern
    ///      where the vault contract IS the ERC-20 share token).
    /// @param yieldSourceAddress The vault address
    /// @return The share token address
    function _getShareToken(address yieldSourceAddress) internal view returns (address) {
        try IERC7540(yieldSourceAddress).share() returns (address shareToken) {
            if (shareToken != address(0)) return shareToken;
            return yieldSourceAddress;
        } catch {
            return yieldSourceAddress;
        }
    }
}
