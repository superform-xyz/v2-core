/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IPMarket } from "@pendle/interfaces/IPMarket.sol";
import { PendlePYOracleLib } from "@pendle/oracles/PtYtLpOracle/PendlePYOracleLib.sol";
// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol"; // Already inherited via

/// @title PendlePtYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for pricing Pendle Principal Tokens (PT) using the official Pendle oracle.
/// @dev Assumes yieldSourceAddress corresponds to the Pendle Market address (IPMarket).
contract PendlePtYieldSourceOracle is AbstractYieldSourceOracle {
    using PendlePYOracleLib for IPMarket; // Import SCALE from library

    /// @notice The Time-Weighted Average Price duration used for Pendle oracle queries.
    uint32 public immutable TWAP_DURATION;

    /// @notice Default TWAP duration set to 15 minutes.
    uint32 private constant DEFAULT_TWAP_DURATION = 900; // 15 * 60

    /// @notice Emitted when the TWAP duration is updated (though currently immutable).
    event TwapDurationSet(uint32 newDuration);

    error INVALID_ASSET();

    /// @notice Constructor
    /// @param _oracleRegistry The address of the Superform oracle registry.
    /// @param _pendleOracle The address of the Pendle PT/YT/LP oracle.
    constructor(address _oracleRegistry) AbstractYieldSourceOracle(_oracleRegistry) {
        TWAP_DURATION = DEFAULT_TWAP_DURATION; // Set default duration
        emit TwapDurationSet(DEFAULT_TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
    function decimals(address market) external view override returns (uint8) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        return pt.decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    function getShareOutput(
        address market,
        address assetIn,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256 sharesOut)
    {
        uint256 pricePerShare = getPricePerShare(market); // Price is PT/Asset in 1e18
        if (pricePerShare == 0) return 0; // Avoid division by zero

        // sharesOut = assetsIn * 1e18 / pricePerShare
        // Asset decimals might differ from 18, need to adjust. PT decimals also matter.
        uint8 assetDecimals = IERC20Metadata(assetIn).decimals();
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();

        // Scale assetsIn to 18 decimals before dividing by price (which is 1e18)
        uint256 assetsIn18 = assetsIn * (10 ** (uint256(18) - assetDecimals));

        // Result is in 1e18 terms, scale to PT decimals
        sharesOut = (assetsIn18 * (10 ** uint256(ptDecimals))) / pricePerShare;
    }

    /// @inheritdoc IYieldSourceOracle
    function getAssetOutput(
        address market,
        address assetOut,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256 assetsOut)
    {
        uint256 pricePerShare = getPricePerShare(market); // Price is PT/Asset in 1e18

        // assetsOut = sharesIn * pricePerShare / 1e(ptDecimals) / 1e(18 - assetDecimals)
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();
        uint8 assetDecimals = IERC20Metadata(assetOut).decimals();

        // Calculate asset value in 1e18 terms, then scale to asset decimals
        // assetsOut18 = sharesIn * pricePerShare / 10^ptDecimals
        uint256 assetsOut18 = (sharesIn * pricePerShare) / (10 ** uint256(ptDecimals));

        // Scale from 18 decimals to asset's decimals
        assetsOut = assetsOut18 / (10 ** (uint256(18) - assetDecimals));
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address market) public view override returns (uint256 price) {
        // Pendle returns the rate scaled to 1e18
        price = IPMarket(market).getPtToAssetRate(TWAP_DURATION);
    }
    
    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfShares(address market, address ownerOfShares) public view override returns (uint256 tvl) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        address underlyingAsset = IPMarket(market).underlyingAsset();
        uint256 ptBalance = pt.balanceOf(ownerOfShares);

        if (ptBalance == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(market, underlyingAsset, ptBalance);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address market) public view override returns (uint256 tvl) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        address underlyingAsset = IPMarket(market).underlyingAsset();
        uint256 ptTotalSupply = pt.totalSupply();

        if (ptTotalSupply == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(market, underlyingAsset, ptTotalSupply);
    }


    /// @inheritdoc IYieldSourceOracle
    function getBalanceOfOwner(
        address market,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256 balance)
    {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        balance = pt.balanceOf(ownerOfShares);
    }
    /*
    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Validates if the provided base asset matches the market's underlying asset.
    function _validateBaseAsset(address market, address base) internal view override {
        if (base != IPMarket(market).underlyingAsset()) {
            revert INVALID_BASE_ASSET();
        }
    }
    

    function _pt(address market) internal view returns (address ptAddress) {
        (, ptAddress,) = IPMarket(market).readTokens();
    }
}
    */