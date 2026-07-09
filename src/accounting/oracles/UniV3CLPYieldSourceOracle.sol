// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";

// Superform vendor
import { CLLiquidityAmounts } from "../../vendor/uniswap/v3/CLLiquidityAmounts.sol";
import { IUniswapV3CLPool } from "../../vendor/uniswap/v3/IUniswapV3CLPool.sol";
import { INonfungiblePositionManager } from "../../vendor/uniswap/v3/INonfungiblePositionManager.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { UniV3CLPRegistry } from "./UniV3CLPRegistry.sol";

/// @title UniV3CLPYieldSourceOracle
/// @author Superform Labs
/// @notice Singleton oracle for Uniswap V3-style concentrated liquidity LP positions.
/// @dev Backed by a UniV3CLPRegistry that maps positionKey → PositionConfig.
///      The `yieldSourceAddress` parameter in all oracle methods is a `positionKey`
///      returned by UniV3CLPRegistry.registerPosition().
///
///      SUPPORTS:
///        - Uniswap V3 (Ethereum, Arbitrum, BSC) — fully compatible
///        - Aerodrome Slipstream (Base) — fully compatible (tickSpacing in fee field, same ABI)
///
///      NOT SUPPORTED:
///        - Algebra / SparkDEX — different positions() ABI (no fee/tickSpacing field)
///          A separate AlgebraCLPYieldSourceOracle is needed for those forks.
///
///      PRICING MECHANISM (manipulation resistant):
///        Step 1 — liquidity → (amount0, amount1):
///          Reconstructs sqrtPriceX96 from Chainlink cross-rate (NOT the pool's live slot0).
///          sqrtPrice = sqrt(price0 * feed1Scale * token1Scale / (price1 * feed0Scale * token0Scale)) * Q96
///          Clamps to [sqrtPriceAtTick(tickLower), sqrtPriceAtTick(tickUpper)].
///          Calls getAmountsForLiquidity with the fixed range and the Chainlink-derived price.
///          This prevents flash-loan price manipulation of the oracle.
///
///        Step 2 — (amount0, amount1) → token0 value:
///          amount1InToken0 = amount1 * price1 * feed0Scale * token0Scale
///                           / (price0 * feed1Scale * token1Scale)
///          PPS = amount0 + amount1InToken0
///
///      SHARE UNIT: 1 "share" = 1e18 liquidity units (consistent with UniV2 LP oracle).
///
///      SINGLETON: A single deployment of this contract serves all positions registered in
///      the UniV3CLPRegistry. Add new pools/tick-ranges by calling registry.registerPosition().
contract UniV3CLPYieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided (registry address in constructor)
    error ZERO_ADDRESS();

    /// @notice Thrown when a Chainlink price is non-positive, at circuit breaker bounds, or cross-rate is zero
    error INVALID_PRICE();

    /// @notice Thrown when a Chainlink feed has not been updated within the registered maxStaleness
    error STALE_PRICE();

    /// @notice Thrown when the L2 sequencer is currently down
    error SEQUENCER_DOWN();

    /// @notice Thrown when the L2 sequencer just restarted and the grace period has not elapsed
    error GRACE_PERIOD_NOT_OVER();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Share decimals (1 share = 1e18 liquidity units)
    uint8 private constant SHARE_DECIMALS = 18;

    /// @notice One share in liquidity units
    uint128 private constant ONE_SHARE_LIQUIDITY = 1e18;

    /// @notice Q96 constant (2^96) used for sqrtPriceX96 construction
    uint256 private constant FIXED_POINT_96_Q96 = 0x1000000000000000000000000;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry holding all position configurations
    UniV3CLPRegistry public immutable REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param superLedgerConfiguration_ SuperLedgerConfiguration address
    /// @param registry_ UniV3CLPRegistry address (must be non-zero)
    constructor(
        address superLedgerConfiguration_,
        address registry_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = UniV3CLPRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns 18 — share decimals are always 18 (1 share = 1e18 liquidity units)
    function decimals(address) external pure override returns (uint8) {
        return SHARE_DECIMALS;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the estimated liquidity units receivable for assetsIn token0 (floor rounded)
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
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
        // shares_out = assetsIn * ONE_SHARE / pps  (floor)
        return Math.mulDiv(assetsIn, uint256(ONE_SHARE_LIQUIDITY), pps);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the liquidity units to burn for a withdrawal of assetsIn token0 (ceil rounded)
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
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
        return Math.mulDiv(assetsIn, uint256(ONE_SHARE_LIQUIDITY), pps, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the token0 value of sharesIn liquidity units
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
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
        return Math.mulDiv(sharesIn, pps, uint256(ONE_SHARE_LIQUIDITY));
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the fair price of ONE_SHARE_LIQUIDITY (1e18) liquidity units in token0 terms
    /// @dev Pricing steps:
    ///      1. Load PositionConfig from registry (reverts POSITION_NOT_REGISTERED for unknown keys)
    ///      2. Check L2 sequencer liveness (no-op when sequencerUptimeFeed is address(0))
    ///      3. Fetch and validate Chainlink prices for token0/USD and token1/USD
    ///      4. Reconstruct sqrtPriceX96 from cross-rate (flash-loan resistant)
    ///      5. Clamp to [sqrtPriceAX96, sqrtPriceBX96] (precomputed tick boundaries)
    ///      6. Call getAmountsForLiquidity for ONE_SHARE_LIQUIDITY
    ///      7. Convert amount1 to token0 terms and return amount0 + amount1InToken0
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        UniV3CLPRegistry.PositionConfig memory cfg = REGISTRY.getPositionConfig(yieldSourceAddress);

        _checkSequencer(cfg.sequencerUptimeFeed, cfg.gracePeriod);

        (uint256 price0, uint256 price1) = _getPrices(cfg);

        // Reconstruct sqrtPriceX96 from Chainlink cross-rate
        // sqrtPriceX96 = sqrt(token1_atoms_per_token0_atom) * 2^96
        // where token1_atoms_per_token0_atom = price0 * feed1Scale * token1Scale
        //                                      / (price1 * feed0Scale * token0Scale)
        // Use sqrt(num) * Q96 / sqrt(den) to avoid 2^192 overflow
        uint256 sqrtNum = Math.sqrt(price0 * cfg.feed1Scale * cfg.token1Scale);
        uint256 sqrtDen = Math.sqrt(price1 * cfg.feed0Scale * cfg.token0Scale);
        if (sqrtDen == 0) revert INVALID_PRICE();

        uint160 sqrtPriceCL = uint160(Math.mulDiv(sqrtNum, FIXED_POINT_96_Q96, sqrtDen));

        // Clamp to tick range boundaries:
        //   below lower → all liquidity in token0
        //   above upper → all liquidity in token1
        uint160 sqrtPriceForCalc = sqrtPriceCL < cfg.sqrtPriceAX96
            ? cfg.sqrtPriceAX96
            : (sqrtPriceCL > cfg.sqrtPriceBX96 ? cfg.sqrtPriceBX96 : sqrtPriceCL);

        // Get token0 and token1 amounts for ONE_SHARE_LIQUIDITY at the Chainlink-derived price
        (uint256 amount0, uint256 amount1) = CLLiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceForCalc, cfg.sqrtPriceAX96, cfg.sqrtPriceBX96, ONE_SHARE_LIQUIDITY
        );

        // Convert amount1 to token0 terms using Chainlink cross-rate:
        // p1InToken0 = price1 * feed0Scale * token0Scale / (price0 * feed1Scale * token1Scale)
        // amount1InToken0 = amount1 * p1InToken0 / token1Scale
        //                 = amount1 * price1 * feed0Scale * token0Scale
        //                   / (price0 * feed1Scale * token1Scale)
        // (token1Scale appears once in denominator: once for the price conversion, consumed by p1InToken0)
        uint256 amount1InToken0;
        if (amount1 > 0) {
            amount1InToken0 = Math.mulDiv(
                amount1 * price1,
                cfg.feed0Scale * cfg.token0Scale,
                price0 * cfg.feed1Scale * cfg.token1Scale
            );
        }

        return amount0 + amount1InToken0;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the total liquidity (in share units) held by an owner across all matching positions
    /// @dev Iterates over all NFT positions owned by ownerOfShares.
    ///      Matches positions where (token0, token1, tickLower, tickUpper) equals the registry config.
    ///      O(N) in number of positions held by ownerOfShares — acceptable for view-only accounting.
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256)
    {
        UniV3CLPRegistry.PositionConfig memory cfg = REGISTRY.getPositionConfig(yieldSourceAddress);

        INonfungiblePositionManager nftManager = INonfungiblePositionManager(cfg.nftManager);
        uint256 nftBalance = nftManager.balanceOf(ownerOfShares);
        if (nftBalance == 0) return 0;

        uint256 totalLiquidity;
        address t0 = cfg.token0;
        address t1 = cfg.token1;
        int24 tL = cfg.tickLower;
        int24 tU = cfg.tickUpper;

        for (uint256 i; i < nftBalance; ++i) {
            uint256 tokenId = nftManager.tokenOfOwnerByIndex(ownerOfShares, i);
            (
                ,
                ,
                address posToken0,
                address posToken1,
                ,
                int24 posTickLower,
                int24 posTickUpper,
                uint128 posLiquidity,
                ,
                ,
                ,
            ) = nftManager.positions(tokenId);

            if (posToken0 == t0 && posToken1 == t1 && posTickLower == tL && posTickUpper == tU) {
                totalLiquidity += posLiquidity;
            }
        }

        return totalLiquidity;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the token0 value of an owner's matching LP positions
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = this.getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
        if (shares == 0) return 0;
        return getAssetOutput(yieldSourceAddress, address(0), shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the value of the pool's current active liquidity in token0 terms
    /// @dev Returns non-zero only when the current tick is within [tickLower, tickUpper).
    ///      Uses pool.liquidity() which is the active liquidity at the current tick.
    ///      This includes all in-range LPs, not just a single strategy's positions.
    ///      For per-strategy TVL, use getTVLByOwnerOfShares() instead.
    /// @param yieldSourceAddress positionKey from UniV3CLPRegistry.registerPosition()
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        UniV3CLPRegistry.PositionConfig memory cfg = REGISTRY.getPositionConfig(yieldSourceAddress);

        (, int24 currentTick) = IUniswapV3CLPool(cfg.pool).slot0();

        if (currentTick < cfg.tickLower || currentTick >= cfg.tickUpper) return 0;

        uint128 activeLiquidity = IUniswapV3CLPool(cfg.pool).liquidity();
        if (activeLiquidity == 0) return 0;

        return getAssetOutput(yieldSourceAddress, address(0), uint256(activeLiquidity));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fetches and validates both Chainlink prices from the registry config
    function _getPrices(UniV3CLPRegistry.PositionConfig memory cfg)
        internal
        view
        returns (uint256 price0, uint256 price1)
    {
        price0 = _getChainlinkPrice(
            IAggregatorV3(cfg.feed0), cfg.feed0MinAnswer, cfg.feed0MaxAnswer, cfg.maxStaleness
        );
        price1 = _getChainlinkPrice(
            IAggregatorV3(cfg.feed1), cfg.feed1MinAnswer, cfg.feed1MaxAnswer, cfg.maxStaleness
        );
    }

    /// @notice Fetches and validates a single Chainlink price feed answer
    function _getChainlinkPrice(
        IAggregatorV3 feed,
        int192 minAnswer,
        int192 maxAnswer,
        uint256 maxStaleness
    )
        internal
        view
        returns (uint256)
    {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        if (answer <= 0) revert INVALID_PRICE();
        if (answeredInRound < roundId) revert STALE_PRICE();
        if (block.timestamp - updatedAt > maxStaleness) revert STALE_PRICE();
        if (minAnswer > 0 && answer <= int256(minAnswer)) revert INVALID_PRICE();
        if (maxAnswer > 0 && answer >= int256(maxAnswer)) revert INVALID_PRICE();
        return uint256(answer);
    }

    /// @notice Checks L2 sequencer liveness; no-op when sequencerFeed is address(0)
    function _checkSequencer(address sequencerFeed, uint256 gracePeriod) internal view {
        if (sequencerFeed == address(0)) return;
        (, int256 answer,, uint256 startedAt,) = IAggregatorV3(sequencerFeed).latestRoundData();
        if (answer != 0) revert SEQUENCER_DOWN();
        if (block.timestamp - startedAt <= gracePeriod) revert GRACE_PERIOD_NOT_OVER();
    }
}
