// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IFirelightVault } from "../../vendor/vaults/firelight/IFirelightVault.sol";

/// @title FirelightYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Firelight stXRP vault on Flare with period-based async withdrawal tracking
/// @dev The Firelight vault uses ERC-4626 signatures but async withdrawals:
///      - redeem() burns shares and creates a WithdrawRequest for currentPeriod() + 1
///      - Assets only move on claimWithdraw() after cooldown (~2 days per period)
///      - getTVLByOwnerOfShares accounts for pending/unclaimed withdrawals across periods
///      Uses convertToShares/convertToAssets (not preview functions) since async vaults
///      may revert on previewDeposit/previewRedeem/previewWithdraw.
contract FirelightYieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of past periods to scan for unclaimed withdrawals
    /// @dev Covers ~2000 days (~5.5 years) at ~2 days per period. For vaults with fewer
    ///      periods than this cap, the scan starts from period 0 (full coverage).
    ///      Gas cost: ~1.34M gas at 1000 periods (view function, called off-chain).
    uint256 public constant MAX_LOOKBACK = 1000;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IFirelightVault(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses convertToShares (not previewDeposit) — safe for async vaults
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
        return IFirelightVault(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Manual inverse of convertToAssets with ceil rounding (favors vault).
    ///      Cannot use previewWithdraw — reverts on async vaults.
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
        IFirelightVault vault = IFirelightVault(yieldSourceAddress);
        uint256 shareDecimals = vault.decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses convertToAssets (not previewRedeem) — safe for async vaults
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
        return IFirelightVault(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IFirelightVault vault = IFirelightVault(yieldSourceAddress);
        uint256 _decimals = vault.decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IFirelightVault(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Includes both held share value AND pending/unclaimed withdrawal value.
    ///      Without this, after redeem() shares are burned and balanceOf → 0,
    ///      causing artificial PPS drops during the ~2 day cooldown.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        IFirelightVault vault = IFirelightVault(yieldSourceAddress);

        // Component 1: Value of held shares
        uint256 heldShares = vault.balanceOf(ownerOfShares);
        uint256 heldValue;
        if (heldShares > 0) {
            heldValue = vault.convertToAssets(heldShares);
        }

        // Component 2: Pending/unclaimed withdrawal value across periods
        uint256 pendingValue = _getPendingWithdrawalValue(vault, ownerOfShares);

        return heldValue + pendingValue;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IFirelightVault(yieldSourceAddress).totalAssets();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates total pending/unclaimed withdrawal value across relevant periods
    /// @dev Scans from max(0, currentPeriod - MAX_LOOKBACK) through currentPeriod + 1.
    ///      For young vaults (currentPeriod < MAX_LOOKBACK), this covers every period from 0.
    ///      Optimized: checks withdrawalsOf first (cheap if 0) to skip isWithdrawClaimed call.
    /// @param vault The Firelight vault to query
    /// @param owner The account to check pending withdrawals for
    /// @return pending Total asset value of unclaimed withdrawals
    function _getPendingWithdrawalValue(
        IFirelightVault vault,
        address owner
    )
        internal
        view
        returns (uint256 pending)
    {
        uint256 currentPeriod = vault.currentPeriod();

        uint256 startPeriod;
        if (currentPeriod > MAX_LOOKBACK) {
            startPeriod = currentPeriod - MAX_LOOKBACK;
        }

        uint256 endPeriod = currentPeriod + 1;

        for (uint256 p = startPeriod; p <= endPeriod; ++p) {
            uint256 amount = vault.withdrawalsOf(p, owner);
            if (amount > 0 && !vault.isWithdrawClaimed(p, owner)) {
                pending += amount;
            }
        }
    }
}
