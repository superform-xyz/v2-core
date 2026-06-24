// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IUniswapV2Pair } from "../../vendor/uniswap/IUniswapV2Pair.sol";

/// @title UniV2LPYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Uniswap V2 LP tokens using Alpha Homora fair pricing formula
/// @dev Supports all V2-compatible DEX forks (SushiSwap, PancakeSwap, etc.)
///      Prices LP tokens in token0 terms using:
///        LP_price = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
///      where p1_in_token0 is derived from two Chainlink USD feeds: price1USD / price0USD
///
///      Flash-loan resistant: sqrt(r0 * r1) is invariant under constant-product swaps.
///      External oracle prices (from Chainlink) are not manipulable within a single tx.
///
///      Fully immutable, no admin functions, no state changes.
///      All external calls are view functions. Oracle reverts propagate (hard revert pattern).
contract UniV2LPYieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided
    error ZERO_ADDRESS();

    /// @notice Thrown when the pool has zero total supply
    error ZERO_TOTAL_SUPPLY();

    /// @notice Thrown when a Chainlink price is non-positive or the cross-rate is zero
    error INVALID_PRICE();

    /// @notice Thrown when a Chainlink feed has not been updated within MAX_STALENESS
    error STALE_PRICE();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice LP token decimals (always 18 for UniV2)
    uint8 private constant LP_DECIMALS = 18;

    /// @notice One full LP token (10^18)
    uint256 private constant ONE_LP = 1e18;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Chainlink price feed for token0/USD
    IAggregatorV3 public immutable FEED0;

    /// @notice Chainlink price feed for token1/USD
    IAggregatorV3 public immutable FEED1;

    /// @notice 10 ** FEED0.decimals(), precomputed
    uint256 public immutable FEED0_SCALE;

    /// @notice 10 ** FEED1.decimals(), precomputed
    uint256 public immutable FEED1_SCALE;

    /// @notice 10 ** token0.decimals(), precomputed
    uint256 public immutable TOKEN0_SCALE;

    /// @notice token1.decimals(), stored for reserve conversion
    uint8 public immutable TOKEN1_DECIMALS;

    /// @notice Maximum allowed seconds since last Chainlink update
    uint256 public immutable MAX_STALENESS;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the UniV2 LP oracle with dual Chainlink feeds
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param feed0_ Chainlink price feed for token0/USD
    /// @param feed1_ Chainlink price feed for token1/USD
    /// @param token0_ Address of token0 in the pair
    /// @param token1_ Address of token1 in the pair
    /// @param maxStaleness_ Maximum seconds since last Chainlink update before reverting
    constructor(
        address superLedgerConfiguration_,
        address feed0_,
        address feed1_,
        address token0_,
        address token1_,
        uint256 maxStaleness_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (feed0_ == address(0) || feed1_ == address(0) || token0_ == address(0) || token1_ == address(0)) {
            revert ZERO_ADDRESS();
        }

        FEED0 = IAggregatorV3(feed0_);
        FEED1 = IAggregatorV3(feed1_);
        FEED0_SCALE = 10 ** IAggregatorV3(feed0_).decimals();
        FEED1_SCALE = 10 ** IAggregatorV3(feed1_).decimals();
        TOKEN0_SCALE = 10 ** IERC20Metadata(token0_).decimals();
        TOKEN1_DECIMALS = IERC20Metadata(token1_).decimals();
        MAX_STALENESS = maxStaleness_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP token decimals (always 18 for UniV2)
    function decimals(address) external pure override returns (uint8) {
        return LP_DECIMALS;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP tokens receivable for a given token0 amount
    /// @dev Estimates via fair price inversion: sharesOut = assetsIn * ONE_LP / pricePerShare
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
        if (assetsIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        if (pps == 0) return 0;

        return Math.mulDiv(assetsIn, ONE_LP, pps);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP tokens to burn for a given token0 withdrawal amount
    /// @dev Uses Ceil rounding to favor the protocol (user burns slightly more LP)
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
        if (assetsIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        if (pps == 0) return 0;

        return Math.mulDiv(assetsIn, ONE_LP, pps, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns token0 value for a given amount of LP tokens
    /// @dev assetsOut = sharesIn * pricePerShare / ONE_LP
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
        if (sharesIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        return Math.mulDiv(sharesIn, pps, ONE_LP);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the fair price of one LP token in token0 terms
    /// @dev Uses Alpha Homora formula: 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
    ///
    ///      Cross-rate derivation:
    ///        p1_in_token0 = (price1_USD / FEED1_SCALE) / (price0_USD / FEED0_SCALE) * TOKEN0_SCALE
    ///                     = price1 * FEED0_SCALE * TOKEN0_SCALE / (price0 * FEED1_SCALE)
    ///
    ///      Overflow handling:
    ///        r0 * r1ValueInToken0 can overflow uint256 for extreme reserve/price combos.
    ///        When overflow would occur, falls back to sqrt(r0) * sqrt(r1ValueInToken0)
    ///        which is slightly less precise but safe for all uint256 inputs.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(yieldSourceAddress);

        // Get pool state
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        if (totalSupply == 0) revert ZERO_TOTAL_SUPPLY();

        // Get Chainlink prices
        uint256 price0 = _getChainlinkPrice(FEED0);
        uint256 price1 = _getChainlinkPrice(FEED1);

        // Cross-rate: p1InToken0 = price1 * FEED0_SCALE * TOKEN0_SCALE / (price0 * FEED1_SCALE)
        // This gives the price of 1 full unit of token1 expressed in token0 units
        uint256 p1InToken0 = Math.mulDiv(price1 * FEED0_SCALE, TOKEN0_SCALE, price0 * FEED1_SCALE);
        if (p1InToken0 == 0) revert INVALID_PRICE();

        // Step 1: Convert r1 to token0 terms
        // r1ValueInToken0 = r1 * p1InToken0 / 10^token1Decimals -> token0Decimals precision
        uint256 r1ValueInToken0 = Math.mulDiv(uint256(reserve1), p1InToken0, 10 ** uint256(TOKEN1_DECIMALS));

        // Step 2: Compute sqrt(r0 * r1ValueInToken0) with overflow protection
        // Both r0 and r1ValueInToken0 are in token0Decimals precision
        // Their product has 2*token0Decimals precision, sqrt gives token0Decimals
        uint256 r0U = uint256(reserve0);
        uint256 sqrtValue;
        if (r1ValueInToken0 != 0 && r0U <= type(uint256).max / r1ValueInToken0) {
            // Direct multiplication is safe -- use for maximum precision
            sqrtValue = Math.sqrt(r0U * r1ValueInToken0);
        } else {
            // Would overflow -- fall back to split sqrt (slightly less precise)
            sqrtValue = Math.sqrt(r0U) * Math.sqrt(r1ValueInToken0);
        }

        // Step 3: PPS = 2 * sqrtValue * 1e18 / totalSupply
        return Math.mulDiv(2 * sqrtValue, ONE_LP, totalSupply);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP token balance of a given owner
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256)
    {
        return IUniswapV2Pair(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns TVL in token0 terms for a given LP token holder
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = IUniswapV2Pair(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return getAssetOutput(yieldSourceAddress, address(0), shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total TVL of the LP pair in token0 terms
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        uint256 totalSupply = IUniswapV2Pair(yieldSourceAddress).totalSupply();
        if (totalSupply == 0) return 0;
        return getAssetOutput(yieldSourceAddress, address(0), totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fetches and validates a Chainlink price feed answer
    /// @param feed The Chainlink aggregator to query
    /// @return The price as a uint256 (guaranteed positive)
    function _getChainlinkPrice(IAggregatorV3 feed) internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert INVALID_PRICE();
        if (block.timestamp - updatedAt > MAX_STALENESS) revert STALE_PRICE();
        return uint256(answer);
    }
}
