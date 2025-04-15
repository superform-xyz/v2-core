// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { IPPYLpOracle } from "../../../vendor/pendle/IPPYLpOracle.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol"; // Already inherited via

/// @title PendlePtYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for pricing Pendle Principal Tokens (PT) using the official Pendle oracle.
/// @dev Assumes yieldSourceAddress corresponds to the Pendle Market address (IPendleMarket).
contract PendlePtYieldSourceOracle is AbstractYieldSourceOracle {
    //using PendlePtOracleLib for IPendleMarket; // Import SCALE from library

    /// @notice The Pendle PT/YT/LP oracle contract.
    IPPYLpOracle public immutable PENDLE_ORACLE;

    /// @notice The Time-Weighted Average Price duration used for Pendle oracle queries.
    uint32 public immutable TWAP_DURATION;

    /// @notice Default TWAP duration set to 15 minutes.
    uint32 private constant DEFAULT_TWAP_DURATION = 900; // 15 * 60

    /// @notice Emitted when the TWAP duration is updated (though currently immutable).
    event TwapDurationSet(uint32 newDuration);

    error ADDRESS_ZERO();
    error INVALID_ASSET();

    /// @notice Constructor
    /// @param _oracleRegistry The address of the Superform oracle registry.
    /// @param _pendleOracle The address of the Pendle PT/YT/LP oracle.
    constructor(address _oracleRegistry, address _pendleOracle) AbstractYieldSourceOracle(_oracleRegistry) {
        if (_pendleOracle == address(0)) revert ADDRESS_ZERO();
        PENDLE_ORACLE = IPPYLpOracle(_pendleOracle);
        TWAP_DURATION = DEFAULT_TWAP_DURATION; // Set default duration
        emit TwapDurationSet(DEFAULT_TWAP_DURATION);
    }

    // --- IYieldSourceOracle Implementation ---

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the decimals of the PT token associated with the market.
    function decimals(address market) external view override returns (uint8) {
        IERC20 pt = IERC20(pt(market));
        return pt.decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Calculates the amount of PT shares received for a given amount of  asset.
    /// @dev Uses the current PT price derived from the oracle. PT shares = assetsIn / pricePerShare.
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
        uint8 assetDecimals = IERC20(assetIn).decimals();
        uint8 ptDecimals = IERC20(pt(market)).decimals();

        // Scale assetsIn to 18 decimals before dividing by price (which is 1e18)
        uint256 assetsIn18 = assetsIn * (10 ** (uint256(18) - assetDecimals));

        // Result is in 1e18 terms, scale to PT decimals
        sharesOut = (assetsIn18 * (10 ** uint256(ptDecimals))) / pricePerShare;
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Calculates the amount of underlying asset received for redeeming PT shares.
    /// @dev Uses the current PT price derived from the oracle. assetsOut = sharesIn * pricePerShare.
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
        uint8 ptDecimals = IERC20(pt(market)).decimals();
        uint8 assetDecimals = IERC20(assetOut).decimals();

        // Calculate asset value in 1e18 terms, then scale to asset decimals
        // assetsOut18 = sharesIn * pricePerShare / 10^ptDecimals
        uint256 assetsOut18 = (sharesIn * pricePerShare) / (10 ** uint256(ptDecimals));

        // Scale from 18 decimals to asset's decimals
        assetsOut = assetsOut18 / (10 ** (uint256(18) - assetDecimals));
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the price of 1 PT share in terms of the underlying asset, scaled to 1e18.
    /// @dev Uses the Pendle oracle's getPtToAssetRate function.
    function getPricePerShare(address market) public view override returns (uint256 price) {
        // Pendle returns the rate scaled to 1e18
        price = PENDLE_ORACLE.getPtToAssetRate(address(market), TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the underlying asset balance of a specific owner's PT shares.
    /// @dev TVL = ptBalance * pricePerShare (adjusted for decimals).
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256 tvl)
    {
        IPendleMarket market = IPendleMarket(yieldSourceAddress);
        IERC20 pt = IERC20(market.pt());
        address underlyingAsset = market.underlyingAsset();
        uint256 ptBalance = pt.balanceOf(ownerOfShares);

        if (ptBalance == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(yieldSourceAddress, underlyingAsset, ptBalance);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the total underlying asset value locked in the PT contract.
    /// @dev TVL = ptTotalSupply * pricePerShare (adjusted for decimals).
    function getTVL(address yieldSourceAddress) public view override returns (uint256 tvl) {
        IPendleMarket market = IPendleMarket(yieldSourceAddress);
        IERC20 pt = IERC20(market.pt());
        address underlyingAsset = market.underlyingAsset();
        uint256 ptTotalSupply = pt.totalSupply();

        if (ptTotalSupply == 0) return 0;

        // Use getAssetOutput for consistency in calculation logic
        tvl = getAssetOutput(yieldSourceAddress, underlyingAsset, ptTotalSupply);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the PT balance of a specific owner for the given market.
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256 balance)
    {
        IPendleMarket market = IPendleMarket(yieldSourceAddress);
        IERC20 pt = IERC20(market.pt());
        balance = pt.balanceOf(ownerOfShares);
    }

    // --- Internal Helpers ---

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Validates if the provided base asset matches the market's underlying asset.
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        IPendleMarket market = IPendleMarket(yieldSourceAddress);
        if (base != market.underlyingAsset()) {
            revert INVALID_BASE_ASSET();
        }
    }

    function pt(address market) public view returns (address pt) {
        (, pt,) = IPendleMarket(market).readTokens();
    }
}
