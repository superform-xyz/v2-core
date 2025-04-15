// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC5115YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 5115 Vaults
contract ERC5115YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

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
        address assetIn,
        uint256 sharesIn
    )
        external
        view
        override
        returns (uint256)
    {
        return IStandardizedYield(yieldSourceAddress).previewRedeem(assetIn, sharesIn);
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
        external
        view
        override
        returns (bool)
    {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        address[] memory tokensIn = yieldSource.getTokensIn();
        address[] memory tokensOut = yieldSource.getTokensOut();

        bool foundInTokensIn = false;
        for (uint256 i = 0; i < tokensIn.length; ++i) {
            if (tokensIn[i] == expectedUnderlying) {
                foundInTokensIn = true;
                break;
            }
        }

        if (!foundInTokensIn) return false;

        bool foundInTokensOut = false;
        for (uint256 i = 0; i < tokensOut.length; ++i) {
            if (tokensOut[i] == expectedUnderlying) {
                foundInTokensOut = true;
                break;
            }
        }

        return foundInTokensOut;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        address[] memory tokensIn = IStandardizedYield(yieldSourceAddress).getTokensOut();
        bool isValid = false;

        for (uint256 i = 0; i < tokensIn.length; ++i) {
            if (tokensIn[i] == base) {
                isValid = true;
                break;
            }
        }

        if (!isValid) revert INVALID_BASE_ASSET();
    }
}
