// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

// Superform vendor
import { IUniswapV3CLPool } from "../../vendor/uniswap/v3/IUniswapV3CLPool.sol";
import { IChainlinkProxy, IChainlinkAggregator } from "../../vendor/chainlink/IChainlinkProxyAggregator.sol";

/// @title UniV3CLPRegistry
/// @author Superform Labs
/// @notice Singleton registry for UniV3-style concentrated liquidity position configurations.
/// @dev Replaces per-deployment immutables with a single registry that maps a derived
///      `positionKey` (pseudo-address) to a precomputed `PositionConfig`.
///
///      A positionKey is:
///        address(uint160(uint256(keccak256(abi.encode(pool, nftManager, tickLower, tickUpper)))))
///
///      Both `pool` and `nftManager` are in the key so UniV3 (Ethereum/Arbitrum/BSC) and
///      Aerodrome Slipstream (Base) can coexist on the same chain even if they happen to
///      share a pool address but use different NFT managers.
///
///      All per-position values that are expensive to compute on every oracle call are
///      precomputed at registration time:
///        - Token/feed decimal scales (10**decimals())
///        - Chainlink circuit breaker bounds (minAnswer/maxAnswer from aggregator proxy)
///        - Tick-boundary sqrtPriceX96 values (TickMath.getSqrtPriceAtTick)
///
///      Deregistration is gated by a 2-day timelock to prevent accidental removal.
contract UniV3CLPRegistry is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided where a valid address is required
    error ZERO_ADDRESS();

    /// @notice Thrown when attempting to register a positionKey that already exists
    error POSITION_ALREADY_REGISTERED();

    /// @notice Thrown when querying or acting on a positionKey that is not registered
    error POSITION_NOT_REGISTERED();

    /// @notice Thrown when attempting to execute/cancel a deregistration that was never proposed
    error DEREGISTRATION_NOT_PENDING();

    /// @notice Thrown when the 2-day deregistration timelock has not elapsed yet
    error DEREGISTRATION_TIMELOCK_NOT_ELAPSED();

    /// @notice Thrown when maxStaleness is zero (would make all oracle reads revert immediately)
    error INVALID_STALENESS();

    /// @notice Thrown when tickLower >= tickUpper (invalid range)
    error INVALID_TICK_RANGE();

    /// @notice Thrown when tickLower or tickUpper is not a multiple of pool.tickSpacing()
    error INVALID_TICK_ALIGNMENT();

    /// @notice Thrown when the provided token0 or token1 does not match the pool's tokens
    error TOKEN_MISMATCH();
    /// @notice Thrown when feeOrTickSpacing does not match pool.fee() or uint24(int24(pool.tickSpacing()))
    error FEE_OR_TICK_SPACING_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role required to register and deregister positions
    bytes32 public constant POSITION_MANAGER_ROLE = keccak256("POSITION_MANAGER_ROLE");

    /// @notice Minimum delay between proposing and executing a deregistration
    uint256 public constant DEREGISTER_DELAY = 2 days;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Complete configuration for a CLP position, with all expensive values precomputed
    struct PositionConfig {
        address pool;
        address nftManager;
        int24 tickLower;
        int24 tickUpper;
        address token0;
        address token1;
        uint24 feeOrTickSpacing;    // stored at registration: fee() for UniV3, tickSpacing for Slipstream
        uint256 token0Scale;        // precomputed: 10**token0.decimals()
        uint256 token1Scale;        // precomputed: 10**token1.decimals()
        address feed0;
        address feed1;
        uint256 feed0Scale;         // precomputed: 10**feed0.decimals()
        uint256 feed1Scale;         // precomputed: 10**feed1.decimals()
        int192 feed0MinAnswer;      // circuit breaker lower bound (0 = disabled)
        int192 feed0MaxAnswer;      // circuit breaker upper bound (0 = disabled)
        int192 feed1MinAnswer;
        int192 feed1MaxAnswer;
        uint256 maxStaleness;
        address sequencerUptimeFeed;
        uint256 gracePeriod;
        uint160 sqrtPriceAX96;     // precomputed: TickMath.getSqrtPriceAtTick(tickLower)
        uint160 sqrtPriceBX96;     // precomputed: TickMath.getSqrtPriceAtTick(tickUpper)
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from positionKey to PositionConfig
    mapping(address positionKey => PositionConfig) private _positions;

    /// @notice Mapping from positionKey to earliest timestamp at which deregistration can execute
    mapping(address positionKey => uint256 executeAt) public pendingDeregistrations;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new CLP position is registered in the registry
    /// @param positionKey The derived pseudo-address key for this position
    /// @param pool The UniV3-compatible pool address
    /// @param nftManager The NonfungiblePositionManager for this pool's DEX
    /// @param tickLower Lower tick of the strategy's range
    /// @param tickUpper Upper tick of the strategy's range
    /// @param token0 The address of token0
    /// @param token1 The address of token1
    event PositionRegistered(
        address indexed positionKey,
        address indexed pool,
        address indexed nftManager,
        int24 tickLower,
        int24 tickUpper,
        address token0,
        address token1
    );

    /// @notice Emitted when a position deregistration is proposed, starting the timelock
    /// @param positionKey The position key being proposed for deregistration
    /// @param executeAt The earliest timestamp at which deregistration can execute
    event PositionDeregistrationProposed(address indexed positionKey, uint256 executeAt);

    /// @notice Emitted when a pending position deregistration is cancelled
    /// @param positionKey The position key whose deregistration was cancelled
    event PositionDeregistrationCancelled(address indexed positionKey);

    /// @notice Emitted when a position is deregistered after the timelock elapses
    /// @param positionKey The position key that was deregistered
    event PositionDeregistered(address indexed positionKey);

    /// @notice Emitted when circuit breaker bounds are refreshed for a position
    /// @param positionKey The position key whose bounds were refreshed
    event CircuitBreakerBoundsRefreshed(address indexed positionKey);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and POSITION_MANAGER_ROLE
    constructor(address admin) {
        if (admin == address(0)) revert ZERO_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(POSITION_MANAGER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a CLP position configuration, precomputing all expensive values.
    /// @dev PPS and TVL are denominated in token0 (lower address). Ensure ledger configs use token0
    ///      as the asset denomination.
    /// @param pool            UniV3-compatible pool address
    /// @param nftManager      NonfungiblePositionManager for this pool's DEX
    /// @param tickLower       Lower tick of the strategy's range (must be < tickUpper)
    /// @param tickUpper       Upper tick of the strategy's range
    /// @param token0          token0 of the pool (must match pool.token0())
    /// @param token1          token1 of the pool
    /// @param feeOrTickSpacing The value the NFT stores for position matching: fee() for UniV3, tickSpacing for
    /// Slipstream
    /// @param feed0           Chainlink price feed for token0/USD
    /// @param feed1           Chainlink price feed for token1/USD
    /// @param maxStaleness    Max seconds since last Chainlink update before reverting (must be > 0)
    /// @param sequencerUptimeFeed L2 sequencer uptime feed (address(0) to disable on L1)
    /// @param gracePeriod     Seconds to wait after sequencer restart before accepting prices
    /// @return positionKey    Derived pseudo-address key for this position
    function registerPosition(
        address pool,
        address nftManager,
        int24 tickLower,
        int24 tickUpper,
        address token0,
        address token1,
        uint24 feeOrTickSpacing,
        address feed0,
        address feed1,
        uint256 maxStaleness,
        address sequencerUptimeFeed,
        uint256 gracePeriod
    )
        external
        onlyRole(POSITION_MANAGER_ROLE)
        returns (address positionKey)
    {
        if (
            pool == address(0) || nftManager == address(0) || token0 == address(0) || token1 == address(0)
                || feed0 == address(0) || feed1 == address(0)
        ) revert ZERO_ADDRESS();
        if (maxStaleness == 0) revert INVALID_STALENESS();
        if (tickLower >= tickUpper) revert INVALID_TICK_RANGE();
        if (token0 != IUniswapV3CLPool(pool).token0() || token1 != IUniswapV3CLPool(pool).token1()) {
            revert TOKEN_MISMATCH();
        }
        {
            int24 spacing = IUniswapV3CLPool(pool).tickSpacing();
            if (tickLower % spacing != 0 || tickUpper % spacing != 0) revert INVALID_TICK_ALIGNMENT();

            // Validate feeOrTickSpacing matches the pool: accept pool.fee() (UniV3) or
            // uint24(tickSpacing) (Slipstream). Prevents operator typo from silently zeroing all reads.
            bool valid;
            try IUniswapV3CLPool(pool).fee() returns (uint24 poolFee) {
                valid = (feeOrTickSpacing == poolFee || feeOrTickSpacing == uint24(int24(spacing)));
            } catch {
                valid = (feeOrTickSpacing == uint24(int24(spacing)));
            }
            if (!valid) revert FEE_OR_TICK_SPACING_MISMATCH();
        }

        positionKey = computePositionKey(pool, nftManager, tickLower, tickUpper);
        if (_positions[positionKey].registered) revert POSITION_ALREADY_REGISTERED();

        // Write base fields directly to storage via pointer (avoids local variable accumulation)
        _writeBaseFields(positionKey, pool, nftManager, tickLower, tickUpper, token0, token1);
        _positions[positionKey].feeOrTickSpacing = feeOrTickSpacing;
        _writeFeedAndMetaFields(positionKey, feed0, feed1, maxStaleness, sequencerUptimeFeed, gracePeriod);

        // Precompute derived values (reads from already-stored fields; separate frame keeps stack depth low)
        _precomputeDerivedFields(positionKey);

        emit PositionRegistered(positionKey, pool, nftManager, tickLower, tickUpper, token0, token1);
    }

    /// @notice Proposes deregistration of a position, starting the 2-day timelock
    function proposeDeregisterPosition(address positionKey) external onlyRole(POSITION_MANAGER_ROLE) {
        if (!_positions[positionKey].registered) revert POSITION_NOT_REGISTERED();
        uint256 executeAt = block.timestamp + DEREGISTER_DELAY;
        pendingDeregistrations[positionKey] = executeAt;
        emit PositionDeregistrationProposed(positionKey, executeAt);
    }

    /// @notice Executes a deregistration after the timelock has elapsed
    function executeDeregisterPosition(address positionKey) external onlyRole(POSITION_MANAGER_ROLE) {
        uint256 executeAt = pendingDeregistrations[positionKey];
        if (executeAt == 0) revert DEREGISTRATION_NOT_PENDING();
        if (block.timestamp < executeAt) revert DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
        delete pendingDeregistrations[positionKey];
        delete _positions[positionKey];
        emit PositionDeregistered(positionKey);
    }

    /// @notice Cancels a pending deregistration before it executes
    /// @param positionKey The position key whose deregistration to cancel
    function cancelDeregisterPosition(address positionKey) external onlyRole(POSITION_MANAGER_ROLE) {
        if (pendingDeregistrations[positionKey] == 0) revert DEREGISTRATION_NOT_PENDING();
        delete pendingDeregistrations[positionKey];
        emit PositionDeregistrationCancelled(positionKey);
    }

    /// @notice Refreshes the cached feed scales and circuit breaker bounds from the current Chainlink aggregator
    /// @dev Feed scales and circuit breaker bounds are snapshotted at registration time. If Chainlink upgrades
    ///      the aggregator behind the proxy, the cached values become stale. Call this function to
    ///      re-read the current scales and bounds from the proxy.
    /// @param positionKey The registered position key to refresh
    function refreshFeedConfig(address positionKey) external onlyRole(POSITION_MANAGER_ROLE) {
        PositionConfig storage cfg = _positions[positionKey];
        if (!cfg.registered) revert POSITION_NOT_REGISTERED();
        cfg.feed0Scale = 10 ** IAggregatorV3(cfg.feed0).decimals();
        cfg.feed1Scale = 10 ** IAggregatorV3(cfg.feed1).decimals();
        (cfg.feed0MinAnswer, cfg.feed0MaxAnswer) = _readCircuitBreakerBounds(cfg.feed0);
        (cfg.feed1MinAnswer, cfg.feed1MaxAnswer) = _readCircuitBreakerBounds(cfg.feed1);
        emit CircuitBreakerBoundsRefreshed(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes the deterministic positionKey for a (pool, nftManager, tick range) tuple
    /// @dev Both pool and nftManager are in the key so UniV3 and Aerodrome Slipstream can
    ///      coexist on the same chain even if they happen to share a pool address.
    function computePositionKey(
        address pool,
        address nftManager,
        int24 tickLower,
        int24 tickUpper
    )
        public
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encode(pool, nftManager, tickLower, tickUpper)))));
    }

    /// @notice Returns the configuration for a registered position
    /// @dev Reverts with POSITION_NOT_REGISTERED for unknown keys
    function getPositionConfig(address positionKey) external view returns (PositionConfig memory) {
        PositionConfig memory cfg = _positions[positionKey];
        if (!cfg.registered) revert POSITION_NOT_REGISTERED();
        return cfg;
    }

    /// @notice Returns whether a positionKey is registered
    function isRegistered(address positionKey) external view returns (bool) {
        return _positions[positionKey].registered;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Writes pool/token base fields. Separate function to keep stack depth bounded.
    function _writeBaseFields(
        address positionKey,
        address pool,
        address nftManager,
        int24 tickLower,
        int24 tickUpper,
        address token0,
        address token1
    )
        private
    {
        PositionConfig storage cfg = _positions[positionKey];
        cfg.pool = pool;
        cfg.nftManager = nftManager;
        cfg.tickLower = tickLower;
        cfg.tickUpper = tickUpper;
        cfg.token0 = token0;
        cfg.token1 = token1;
    }

    /// @dev Writes feed + meta fields. Separate function to keep stack depth bounded.
    function _writeFeedAndMetaFields(
        address positionKey,
        address feed0,
        address feed1,
        uint256 maxStaleness,
        address sequencerUptimeFeed,
        uint256 gracePeriod
    )
        private
    {
        PositionConfig storage cfg = _positions[positionKey];
        cfg.feed0 = feed0;
        cfg.feed1 = feed1;
        cfg.maxStaleness = maxStaleness;
        cfg.sequencerUptimeFeed = sequencerUptimeFeed;
        cfg.gracePeriod = gracePeriod;
    }

    /// @dev Precomputes all derived fields (scales, circuit breaker bounds, sqrtPrices) from stored addresses.
    ///      Reads from already-written storage so only needs the positionKey — minimises stack depth.
    function _precomputeDerivedFields(address positionKey) private {
        PositionConfig storage cfg = _positions[positionKey];

        // Token decimal scales
        cfg.token0Scale = 10 ** IERC20Metadata(cfg.token0).decimals();
        cfg.token1Scale = 10 ** IERC20Metadata(cfg.token1).decimals();

        // Feed decimal scales
        cfg.feed0Scale = 10 ** IAggregatorV3(cfg.feed0).decimals();
        cfg.feed1Scale = 10 ** IAggregatorV3(cfg.feed1).decimals();

        // Circuit breaker bounds from Chainlink aggregator proxy
        (cfg.feed0MinAnswer, cfg.feed0MaxAnswer) = _readCircuitBreakerBounds(cfg.feed0);
        (cfg.feed1MinAnswer, cfg.feed1MaxAnswer) = _readCircuitBreakerBounds(cfg.feed1);

        // Tick-boundary sqrtPriceX96 values
        cfg.sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(cfg.tickLower);
        cfg.sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(cfg.tickUpper);

        cfg.registered = true;
    }

    /// @notice Reads circuit breaker bounds from the Chainlink aggregator behind a proxy
    /// @dev Uses try/catch so that feeds without a proxy interface gracefully return (0, 0),
    ///      disabling the circuit breaker check for that feed
    function _readCircuitBreakerBounds(address feed) private view returns (int192 minAns, int192 maxAns) {
        try IChainlinkProxy(feed).aggregator() returns (address agg) {
            try IChainlinkAggregator(agg).minAnswer() returns (int192 min) {
                minAns = min;
            } catch { }
            try IChainlinkAggregator(agg).maxAnswer() returns (int192 max) {
                maxAns = max;
            } catch { }
        } catch { }
    }
}
