// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IPMarket} from "@pendle/interfaces/IPMarket.sol";
import {PendlePYOracleLib} from "@pendle/oracles/PtYtLpOracle/PendlePYOracleLib.sol";
import {IPPrincipalToken} from "@pendle/interfaces/IPPrincipalToken.sol";
import {IStandardizedYield} from "@pendle/interfaces/IStandardizedYield.sol";
// Superform
import {AbstractYieldSourceOracle} from "./AbstractYieldSourceOracle.sol";
import {IYieldSourceOracle} from "../../interfaces/accounting/IYieldSourceOracle.sol"; // Already inherited via

/// @title PendlePTYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for pricing Pendle Principal Tokens (PT) using the official Pendle oracle.
/// @dev Assumes yieldSourceAddress corresponds to the Pendle Market address (IPMarket).
contract PendlePTYieldSourceOracle is AbstractYieldSourceOracle {
    using PendlePYOracleLib for IPMarket; // Import SCALE from library

    /// @notice The Time-Weighted Average Price duration used for Pendle oracle queries.
    uint32 public immutable TWAP_DURATION;

    /// @notice Default TWAP duration set to 15 minutes.
    uint32 private constant DEFAULT_TWAP_DURATION = 900; // 15 * 60

    uint256 private constant PRICE_DECIMALS = 18;

    /// @notice Emitted when the TWAP duration is updated (though currently immutable).
    event TwapDurationSet(uint32 newDuration);

    error INVALID_ASSET();
    error NOT_AVAILABLE_ERC20_ON_CHAIN();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor() AbstractYieldSourceOracle() {
        TWAP_DURATION = DEFAULT_TWAP_DURATION; // Set default duration
        emit TwapDurationSet(DEFAULT_TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
    function decimals(address) external pure override returns (uint8) {
        return 18;
    }

    /// @inheritdoc IYieldSourceOracle
    function getShareOutput(address market, address, uint256 assetsIn)
        external
        view
        override
        returns (uint256 sharesOut)
    {
        uint256 pricePerShare = getPricePerShare(market); // Price is PT/Asset in 1e18
        if (pricePerShare == 0) return 0; // Avoid division by zero

        // sharesOut = assetsIn * 1e18 / pricePerShare
        // Asset decimals might differ from 18, need to adjust. PT decimals also matter.
        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (uint256 assetType, address assetAddress, uint8 assetDecimals) = _getAssetInfo(sY);
        if (assetType != 0) revert NOT_AVAILABLE_ERC20_ON_CHAIN();

        // ! if the SY token upgrades and asset stops being part of token in or out array this could revert
        if (!_validateAssetFoundInSY(sY, assetAddress)) revert INVALID_ASSET();

        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();

        // Scale assetsIn to Price Decimals (1e18) before calculating shares
        uint256 assetsIn18;
        if (assetDecimals <= PRICE_DECIMALS) {
            // Scale up if assetDecimals <= 18
            assetsIn18 = assetsIn * (10 ** (PRICE_DECIMALS - assetDecimals));
        } else {
            // Scale down if assetDecimals > 18
            // Avoids underflow in 10**(PRICE_DECIMALS - assetDecimals)
            assetsIn18 = assetsIn / (10 ** (assetDecimals - PRICE_DECIMALS));
        }

        // Result is in PT decimals: sharesOut = assetsIn18 * 1e(ptDecimals) / pricePerShare
        // pricePerShare is PT/Asset in 1e18
        sharesOut = (assetsIn18 * (10 ** uint256(ptDecimals))) / pricePerShare;
    }

    /// @inheritdoc IYieldSourceOracle
    function getAssetOutput(address market, address, uint256 sharesIn)
        public
        view
        override
        returns (uint256 assetsOut)
    {
        uint256 pricePerShare = getPricePerShare(market); // Price is PT/Asset in 1e18

        // assetsOut = sharesIn * pricePerShare / 1e(ptDecimals) / 1e(18 - assetDecimals)
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();
        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (uint256 assetType, address assetAddress, uint8 assetDecimals) = _getAssetInfo(sY);
        if (assetType != 0) revert NOT_AVAILABLE_ERC20_ON_CHAIN();

        // ! if the SY token upgrades and asset stops being part of token in or out array this could revert
        if (!_validateAssetFoundInSY(sY, assetAddress)) revert INVALID_ASSET();

        // Calculate asset value in 1e18 terms first
        // assetsOut18 = sharesIn * pricePerShare / 10^ptDecimals
        uint256 assetsOut18 = (sharesIn * pricePerShare) / (10 ** uint256(ptDecimals));

        // Scale from 1e18 representation (PRICE_DECIMALS) to asset's actual decimals
        if (assetDecimals >= PRICE_DECIMALS) {
            // Scale up if assetDecimals >= 18
            assetsOut = assetsOut18 * (10 ** (assetDecimals - PRICE_DECIMALS));
        } else {
            // Scale down if assetDecimals < 18
            // Avoids underflow in 10**(PRICE_DECIMALS - assetDecimals) which happens in the division below
            assetsOut = assetsOut18 / (10 ** (PRICE_DECIMALS - assetDecimals));
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address market) public view override returns (uint256 price) {
        // Pendle returns the rate scaled to 1e18
        price = IPMarket(market).getPtToAssetRate(TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfShares(address market, address ownerOfShares) public view override returns (uint256 tvl) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        uint256 ptBalance = pt.balanceOf(ownerOfShares);

        if (ptBalance == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(market, address(0), ptBalance);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address market) public view override returns (uint256 tvl) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        uint256 ptTotalSupply = pt.totalSupply();

        if (ptTotalSupply == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(market, address(0), ptTotalSupply);
    }

    /// @inheritdoc IYieldSourceOracle
    function getBalanceOfOwner(address market, address ownerOfShares)
        external
        view
        override
        returns (uint256 balance)
    {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        balance = pt.balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAsset(address market, address expectedUnderlying) public view override returns (bool) {
        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (uint256 assetType,,) = _getAssetInfo(sY);
        if (assetType != 0) revert NOT_AVAILABLE_ERC20_ON_CHAIN();

        return _validateAssetFoundInSY(sY, expectedUnderlying);
    }

    function _validateAssetFoundInSY(IStandardizedYield sY, address expectedUnderlying) internal view returns (bool) {
        address[] memory tokensIn = sY.getTokensIn();
        address[] memory tokensOut = sY.getTokensOut();
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

    function _getAssetInfo(IStandardizedYield sY) internal view returns (uint256, address, uint8) {
        (IStandardizedYield.AssetType assetType, address assetAddress, uint8 assetDecimals) = sY.assetInfo();

        return (uint256(assetType), assetAddress, assetDecimals);
    }

    function _pt(address market) internal view returns (address ptAddress) {
        (, IPPrincipalToken ptAddressInt,) = IPMarket(market).readTokens();

        ptAddress = address(ptAddressInt);
    }

    function _sy(address market) internal view returns (address sYAddress) {
        (IStandardizedYield sYAddressInt,,) = IPMarket(market).readTokens();

        sYAddress = address(sYAddressInt);
    }
}
