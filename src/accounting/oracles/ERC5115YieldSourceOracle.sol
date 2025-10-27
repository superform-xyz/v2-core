// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IStandardizedYield } from "../../vendor/pendle/IStandardizedYield.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC5115YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 5115 Vaults
contract ERC5115YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// exchangeRate() returns price scaled to 1e18 precision, independent of SY token or asset decimals.
    /// This ensures correct normalization in mulDiv operations.
    /// See https://eips.ethereum.org/EIPS/eip-5115#methods -> exchangeRate()
    /// The name decimals() here is ambiguous because it is a function used in other areas of the code for scaling (but
    /// it doesn't refer to the SY decimals) 
    /// Calculation Examples in the Oracle:
    /// - In getTVL: Math.mulDiv(totalShares, yieldSource.exchangeRate(), 1e18). Here, totalShares is in SY decimals
    /// (D), exchangeRate is (totalAssets * 1e18) / totalShares (per EIP, with totalAssets in asset decimals A). This
    /// simplifies to totalAssets, correctly outputting the asset amount regardless of D or A.
    /// - In getWithdrawalShareOutput: previewRedeem(assetIn, 1e18) gets assets for 1e18 SY share units, then
    /// mulDiv(assetsIn, 1e18, assetsPerShare, Ceil) computes the required share units. The 1e18 acts as a precision
    /// scaler (matching EIP), not an assumption about D. For example, with a 6-decimal SY (like Pendle's SY-syrupUSDC)
    /// and initial 1:1 rate, it correctly computes shares without issues.
    /// - This pattern holds for other functions like getAssetOutput (direct previewRedeem without scaling assumptions).
    function decimals(
        address /*yieldSourceAddress*/
    )
        public
        pure
        override
        returns (uint8)
    {
        return 18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        return IStandardizedYield(yieldSourceAddress).previewDeposit(assetIn, assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        uint256 assetsPerShare = IStandardizedYield(yieldSourceAddress).previewRedeem(assetIn, 1e18);
        if (assetsPerShare == 0) return 0;
        return Math.mulDiv(assetsIn, 1e18, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(
        address yieldSourceAddress,
        address assetOut,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        return IStandardizedYield(yieldSourceAddress).previewRedeem(assetOut, sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return IStandardizedYield(yieldSourceAddress).exchangeRate();
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
        return IStandardizedYield(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return Math.mulDiv(shares, yieldSource.exchangeRate(), 1e18);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 totalShares = yieldSource.totalSupply();
        if (totalShares == 0) return 0;
        return Math.mulDiv(totalShares, yieldSource.exchangeRate(), 1e18);
    }
}
