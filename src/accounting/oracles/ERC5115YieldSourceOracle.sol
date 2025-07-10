// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IStandardizedYield } from "../../vendor/pendle/IStandardizedYield.sol";

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
    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address /*yieldSourceAddress*/ ) public pure override returns (uint8) {
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
        return (shares * yieldSource.exchangeRate()) / 1e18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 totalShares = yieldSource.totalSupply();
        if (totalShares == 0) return 0;
        return (totalShares * yieldSource.exchangeRate()) / 1e18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAsset(
        address yieldSourceAddress,
        address expectedUnderlying
    )
        public
        view
        override
        returns (bool)
    {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        address[] memory tokensIn = yieldSource.getTokensIn();
        address[] memory tokensOut = yieldSource.getTokensOut();
        uint256 tokensInLength = tokensIn.length;
        uint256 tokensOutLength = tokensOut.length;
        bool foundInTokensIn = false;
        for (uint256 i; i < tokensInLength; ++i) {
            if (tokensIn[i] == expectedUnderlying) {
                foundInTokensIn = true;
                break;
            }
        }

        if (!foundInTokensIn) return false;

        bool foundInTokensOut = false;
        for (uint256 i; i < tokensOutLength; ++i) {
            if (tokensOut[i] == expectedUnderlying) {
                foundInTokensOut = true;
                break;
            }
        }

        return foundInTokensOut;
    }
}
