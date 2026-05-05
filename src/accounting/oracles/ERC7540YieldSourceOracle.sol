// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IERC7540 } from "../../vendor/vaults/7540/IERC7540.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for ERC-7540 async vaults with full lifecycle TVL tracking
/// @dev Accounts for 5 TVL components: held shares + pending redeem + claimable redeem
///      + pending deposit + claimable deposit.
///      Discovers share token via ERC-7575 share(). Falls back to treating vault as the
///      share token (ERC-4626 pattern) when share() is not implemented.
///      Uses maxWithdraw() for claimable redeem (handles Centrifuge locked redeemPrice).
///      Error handling: getPricePerShare hard reverts (R1), getTVLByOwnerOfShares wraps
///      async calls in try/catch for graceful degradation (R2).
contract ERC7540YieldSourceOracle is AbstractYieldSourceOracle {
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
        if (assetsPerShare == 0) return 0;

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
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC7540(yieldSourceAddress).totalAssets();
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 SPECIFIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all 5 TVL components individually for monitoring instrumentation
    /// @dev Each async component (2-5) is wrapped in try/catch for graceful degradation.
    ///      Component 1 (held shares) is not wrapped — if balanceOf reverts,
    ///      the vault is misconfigured and should not be registered.
    /// @param yieldSourceAddress The ERC-7540 vault address
    /// @param owner The smart account whose position to value (must be controller in 7540 terms)
    /// @return heldValue Value of shares in balanceOf (assets)
    /// @return pendingRedeemValue Value of shares in pending redeem state (assets)
    /// @return claimableRedeemValue Value of claimable redeem via maxWithdraw (assets)
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

        // Component 1: Held shares value
        uint256 heldShares = IERC20(shareToken).balanceOf(owner);
        if (heldShares > 0) {
            heldValue = vault.convertToAssets(heldShares);
        }

        // Component 2: Pending redeem value (shares → assets via convertToAssets)
        try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
            if (pendingShares > 0) {
                pendingRedeemValue = vault.convertToAssets(pendingShares);
            }
        } catch { }

        // Component 3: Claimable redeem value (uses maxWithdraw — handles locked redeemPrice)
        try vault.maxWithdraw(owner) returns (uint256 withdrawable) {
            claimableRedeemValue = withdrawable;
        } catch { }

        // Component 4: Pending deposit value (already in assets)
        try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
            pendingDepositValue = pendingAssets;
        } catch { }

        // Component 5: Claimable deposit value (already in assets)
        try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
            claimableDepositValue = claimableAssets;
        } catch { }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Discovers the share token for a vault
    /// @dev Tries ERC-7575 share() first. If not implemented (reverts), falls back to
    ///      treating the vault address itself as the share token (ERC-4626 pattern where
    ///      the vault contract IS the ERC-20 share token).
    /// @param yieldSourceAddress The vault address
    /// @return The share token address
    function _getShareToken(address yieldSourceAddress) internal view returns (address) {
        try IERC7540(yieldSourceAddress).share() returns (address shareToken) {
            return shareToken;
        } catch {
            return yieldSourceAddress;
        }
    }
}
