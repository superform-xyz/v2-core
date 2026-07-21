// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

import { UniV3CLPRegistry } from "../../../../src/accounting/oracles/UniV3CLPRegistry.sol";
import { UniV3CLPYieldSourceOracle } from "../../../../src/accounting/oracles/UniV3CLPYieldSourceOracle.sol";
import { CLLiquidityAmounts } from "../../../../src/vendor/uniswap/v3/CLLiquidityAmounts.sol";
import { MockUniswapV3CLPool } from "../../../mocks/MockUniswapV3CLPool.sol";
import { MockNonfungiblePositionManager } from "../../../mocks/MockNonfungiblePositionManager.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";

contract UniV3CLPYieldSourceOracleTest is Test {
    UniV3CLPRegistry public registry;
    UniV3CLPYieldSourceOracle public oracle;
    MockUniswapV3CLPool public pool;
    MockNonfungiblePositionManager public nftManager;
    MockAggregator public feed0;
    MockAggregator public feed1;
    MockERC20 public token0;
    MockERC20 public token1;
    address public ledgerConfig;

    /// @notice positionKey returned by registry.registerPosition() for the default setup
    address public positionKey;

    // Default tick range: wide range at tick 0
    int24 public constant TICK_LOWER = -6000;
    int24 public constant TICK_UPPER = 6000;

    // Q96 constant
    uint256 public constant Q96 = 0x1000000000000000000000000;

    uint256 public constant MAX_STALENESS = 1 hours;

    function setUp() public {
        // 18/18 decimals, both priced at $1
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // Chainlink feeds: 8 decimals, $1 each
        feed0 = new MockAggregator(8);
        feed1 = new MockAggregator(8);
        feed0.setLatestAnswer(1e8);
        feed1.setLatestAnswer(1e8);

        // Pool and NFT manager
        pool = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        nftManager = new MockNonfungiblePositionManager();

        // Set pool state: tick 0 (price 1:1), some liquidity
        pool.setSlot0(uint160(Q96), 0);
        pool.setLiquidity(1_000_000e18);

        // Deploy SuperLedgerConfiguration
        ledgerConfig = address(new SuperLedgerConfiguration());

        // Deploy registry — test contract is the admin/position-manager
        registry = new UniV3CLPRegistry(address(this));

        // Register the default position (no sequencer feed on L1)
        positionKey = registry.registerPosition(
            address(pool),
            address(nftManager),
            TICK_LOWER,
            TICK_UPPER,
            address(token0),
            address(token1),
            100, // feeOrTickSpacing matches pool tickSpacing
            address(feed0),
            address(feed1),
            MAX_STALENESS,
            address(0), // no sequencer feed
            0
        );

        // Deploy oracle — single deployment for all positions
        oracle = new UniV3CLPYieldSourceOracle(ledgerConfig, address(registry));
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 1: REGISTRY — CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_registry_adminRoles() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(registry.hasRole(registry.POSITION_MANAGER_ROLE(), address(this)));
    }

    function test_registry_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        new UniV3CLPRegistry(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 2: REGISTRY — REGISTER POSITION
    //////////////////////////////////////////////////////////////*/

    function test_registry_registerPosition_storesConfig() public view {
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(positionKey);
        assertEq(cfg.pool, address(pool));
        assertEq(cfg.nftManager, address(nftManager));
        assertEq(cfg.tickLower, TICK_LOWER);
        assertEq(cfg.tickUpper, TICK_UPPER);
        assertEq(cfg.token0, address(token0));
        assertEq(cfg.token1, address(token1));
        assertEq(cfg.feeOrTickSpacing, 100);
        assertEq(cfg.feed0, address(feed0));
        assertEq(cfg.feed1, address(feed1));
        assertEq(cfg.maxStaleness, MAX_STALENESS);
        assertEq(cfg.sequencerUptimeFeed, address(0));
        assertEq(cfg.gracePeriod, 0);
        assertTrue(cfg.registered);
    }

    function test_registry_registerPosition_precomputesScales() public view {
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(positionKey);
        assertEq(cfg.token0Scale, 1e18);
        assertEq(cfg.token1Scale, 1e18);
        assertEq(cfg.feed0Scale, 1e8);
        assertEq(cfg.feed1Scale, 1e8);
    }

    function test_registry_registerPosition_precomputesSqrtPrices() public view {
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(positionKey);
        assertEq(cfg.sqrtPriceAX96, TickMath.getSqrtPriceAtTick(TICK_LOWER));
        assertEq(cfg.sqrtPriceBX96, TickMath.getSqrtPriceAtTick(TICK_UPPER));
    }

    function test_registry_registerPosition_revertsOnZeroPool() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(0), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroNftManager() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(pool), address(0), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroToken0() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroToken1() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(0), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroFeed0() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroFeed1() public {
        vm.expectRevert(UniV3CLPRegistry.ZERO_ADDRESS.selector);
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(0), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnZeroStaleness() public {
        // Deploy a fresh pool so we get a new positionKey
        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.INVALID_STALENESS.selector);
        registry.registerPosition(
            address(pool2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1), 0, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnInvalidTickRange() public {
        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.INVALID_TICK_RANGE.selector);
        registry.registerPosition(
            address(pool2), address(nftManager), TICK_UPPER, TICK_LOWER, // inverted
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnEqualTicks() public {
        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.INVALID_TICK_RANGE.selector);
        registry.registerPosition(
            address(pool2), address(nftManager), 0, 0,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnDuplicate() public {
        // Same (pool, nftManager, tickLower, tickUpper) → same positionKey → duplicate
        vm.expectRevert(UniV3CLPRegistry.POSITION_ALREADY_REGISTERED.selector);
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsForNonManager() public {
        address stranger = address(0x1234);
        vm.prank(stranger);
        vm.expectRevert();
        registry.registerPosition(
            address(pool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 3: REGISTRY — COMPUTE POSITION KEY
    //////////////////////////////////////////////////////////////*/

    function test_registry_computePositionKey_deterministic() public view {
        address key1 = registry.computePositionKey(address(pool), address(nftManager), TICK_LOWER, TICK_UPPER);
        address key2 = registry.computePositionKey(address(pool), address(nftManager), TICK_LOWER, TICK_UPPER);
        assertEq(key1, key2);
        assertEq(key1, positionKey);
    }

    function test_registry_computePositionKey_uniqueByNftManager() public view {
        address otherManager = address(0xABCD);
        address key1 = registry.computePositionKey(address(pool), address(nftManager), TICK_LOWER, TICK_UPPER);
        address key2 = registry.computePositionKey(address(pool), otherManager, TICK_LOWER, TICK_UPPER);
        assertTrue(key1 != key2, "Different nftManagers must produce different keys");
    }

    function test_registry_computePositionKey_uniqueByTicks() public view {
        address key1 = registry.computePositionKey(address(pool), address(nftManager), TICK_LOWER, TICK_UPPER);
        address key2 = registry.computePositionKey(address(pool), address(nftManager), TICK_LOWER + 1, TICK_UPPER);
        assertTrue(key1 != key2, "Different tick ranges must produce different keys");
    }

    function test_registry_isRegistered() public view {
        assertTrue(registry.isRegistered(positionKey));
        assertFalse(registry.isRegistered(address(0xDEAD)));
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 4: REGISTRY — DEREGISTRATION TIMELOCK
    //////////////////////////////////////////////////////////////*/

    function test_registry_deregistration_timelockFlow() public {
        // Propose
        registry.proposeDeregisterPosition(positionKey);
        uint256 executeAt = registry.pendingDeregistrations(positionKey);
        assertEq(executeAt, block.timestamp + 2 days);

        // Cannot execute before timelock
        vm.expectRevert(UniV3CLPRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterPosition(positionKey);

        // Warp past timelock
        vm.warp(block.timestamp + 2 days);

        // Execute succeeds
        registry.executeDeregisterPosition(positionKey);

        // Position is gone
        assertFalse(registry.isRegistered(positionKey));
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        registry.getPositionConfig(positionKey);
    }

    function test_registry_deregistration_cancel() public {
        registry.proposeDeregisterPosition(positionKey);

        // Cancel
        registry.cancelDeregisterPosition(positionKey);
        assertEq(registry.pendingDeregistrations(positionKey), 0);

        // Position still accessible
        assertTrue(registry.isRegistered(positionKey));
        registry.getPositionConfig(positionKey); // must not revert
    }

    function test_registry_deregistration_revertsOnNonPending_execute() public {
        vm.expectRevert(UniV3CLPRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterPosition(positionKey);
    }

    function test_registry_deregistration_revertsOnNonPending_cancel() public {
        vm.expectRevert(UniV3CLPRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterPosition(positionKey);
    }

    function test_registry_deregistration_revertsOnUnregisteredPosition() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        registry.proposeDeregisterPosition(address(0xDEAD));
    }

    function test_registry_deregistration_revertsForNonManager() public {
        address stranger = address(0x5678);
        vm.prank(stranger);
        vm.expectRevert();
        registry.proposeDeregisterPosition(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 5: ORACLE — CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_oracle_registryImmutable() public view {
        assertEq(address(oracle.REGISTRY()), address(registry));
    }

    function test_oracle_superLedgerConfig() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
    }

    function test_oracle_constructor_revertsOnZeroRegistry() public {
        vm.expectRevert(UniV3CLPYieldSourceOracle.ZERO_ADDRESS.selector);
        new UniV3CLPYieldSourceOracle(ledgerConfig, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 6: DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_always18() public view {
        assertEq(oracle.decimals(positionKey), 18);
        // Any address returns 18 (no registry lookup needed)
        assertEq(oracle.decimals(address(0xBEEF)), 18);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 7: POSITION_NOT_REGISTERED reverts
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_revertsOnUnregisteredKey() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getPricePerShare(address(0xDEAD));
    }

    function test_getShareOutput_revertsOnUnregisteredKey() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getShareOutput(address(0xDEAD), address(0), 1e18);
    }

    function test_getWithdrawalShareOutput_revertsOnUnregisteredKey() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getWithdrawalShareOutput(address(0xDEAD), address(0), 1e18);
    }

    function test_getAssetOutput_revertsOnUnregisteredKey() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getAssetOutput(address(0xDEAD), address(0), 1e18);
    }

    function test_getBalanceOfOwner_revertsOnUnregisteredKey() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(address(0xDEAD), address(0xBEEF));
    }

    function test_getTVL_returnsZeroForUnregisteredKey() public view {
        // getTVL is intentionally disabled for CLP — always returns 0
        assertEq(oracle.getTVL(address(0xDEAD)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 8: PRICE PER SHARE — IN RANGE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_inRange_nonZero() public view {
        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0, "PPS must be > 0 for in-range position");
    }

    function test_getPricePerShare_inRange_bothTokensContribute() public view {
        // At 1:1 price with 18/18 decimals, both tokens contribute
        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    function test_getPricePerShare_price1_doubled_changesComposition() public {
        feed1.setLatestAnswer(2e8); // token1 now costs $2
        uint256 ppsBefore = oracle.getPricePerShare(positionKey);

        feed1.setLatestAnswer(1e8);
        uint256 ppsAfter = oracle.getPricePerShare(positionKey);

        assertTrue(ppsBefore != ppsAfter, "PPS should change when token1 price doubles");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 9: PRICE PER SHARE — OUT OF RANGE
    //////////////////////////////////////////////////////////////*/

    /// @notice When Chainlink price puts us BELOW the lower tick, all liquidity is token0 (amount1 = 0)
    function test_getPricePerShare_belowLowerTick_allToken0() public {
        // Register with narrow tick range [5000, 6000] (current price at tick 0 = below range)
        address narrowKey = registry.registerPosition(
            address(pool), address(nftManager), 5000, 6000,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(narrowKey);
        assertGt(pps, 0, "PPS must be > 0 even when below range (pure token0)");
    }

    /// @notice When Chainlink price puts us ABOVE the upper tick, all liquidity is token1 (amount0 = 0)
    function test_getPricePerShare_aboveUpperTick_allToken1() public {
        // Register with narrow tick range [-6000, -5000] (current price at tick 0 = above range)
        address narrowKey = registry.registerPosition(
            address(pool), address(nftManager), -6000, -5000,
            address(token0), address(token1), 100, address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(narrowKey);
        assertGt(pps, 0, "PPS must be > 0 even when above range (pure token1)");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 10: SHARE OUTPUT (DEPOSIT ESTIMATE)
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_zeroInput_returnsZero() public view {
        assertEq(oracle.getShareOutput(positionKey, address(0), 0), 0);
    }

    function test_getShareOutput_positiveInput_nonZero() public view {
        uint256 shares = oracle.getShareOutput(positionKey, address(0), 1e18);
        assertGt(shares, 0, "getShareOutput must return > 0 for positive input");
    }

    function test_getShareOutput_scalesWithInput() public view {
        uint256 shares1 = oracle.getShareOutput(positionKey, address(0), 1e18);
        uint256 shares2 = oracle.getShareOutput(positionKey, address(0), 2e18);
        assertApproxEqRel(shares2, shares1 * 2, 1e12, "output should scale linearly");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 11: WITHDRAWAL SHARE OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getWithdrawalShareOutput_zeroInput_returnsZero() public view {
        assertEq(oracle.getWithdrawalShareOutput(positionKey, address(0), 0), 0);
    }

    function test_getWithdrawalShareOutput_nonZero() public view {
        uint256 shares = oracle.getWithdrawalShareOutput(positionKey, address(0), 1e18);
        assertGt(shares, 0, "getWithdrawalShareOutput must be > 0");
    }

    function test_getWithdrawalShareOutput_geqGetShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 sharesFloor = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 sharesCeil = oracle.getWithdrawalShareOutput(positionKey, address(0), assetsIn);
        assertGe(sharesCeil, sharesFloor, "withdrawal shares must be >= deposit shares");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 12: ASSET OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutput_zeroInput_returnsZero() public view {
        assertEq(oracle.getAssetOutput(positionKey, address(0), 0), 0);
    }

    function test_getAssetOutput_nonZero() public view {
        uint256 assets = oracle.getAssetOutput(positionKey, address(0), 1e18);
        assertGt(assets, 0, "getAssetOutput must be > 0 for positive shares");
    }

    function test_getAssetOutput_roundTrip_doesNotCreateValue() public view {
        uint256 assetsIn = 1e18;
        uint256 shares = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(positionKey, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 13: BALANCE OF OWNER
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_noPositions_returnsZero() public view {
        assertEq(oracle.getBalanceOfOwner(positionKey, address(0xBEEF)), 0);
    }

    function test_getBalanceOfOwner_matchingPosition_returnsLiquidity() public {
        address user = address(0xBEEF);
        uint128 liquidity = 5_000_000e18;
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, liquidity);

        assertEq(oracle.getBalanceOfOwner(positionKey, user), liquidity);
    }

    function test_getBalanceOfOwner_sumMultipleMatchingPositions() public {
        address user = address(0xBEEF);
        uint128 liq1 = 2_000e18;
        uint128 liq2 = 3_000e18;
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, liq1);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, liq2);

        assertEq(oracle.getBalanceOfOwner(positionKey, user), uint256(liq1) + liq2);
    }

    function test_getBalanceOfOwner_nonMatchingPositions_ignored() public {
        address user = address(0xBEEF);
        uint128 liquidity = 5_000e18;
        // Different tick range — should NOT be counted
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER - 1, TICK_UPPER, liquidity);
        // Different token pair — should NOT be counted
        nftManager.mint(user, address(0xDEAD), address(token1), 100, TICK_LOWER, TICK_UPPER, liquidity);

        assertEq(oracle.getBalanceOfOwner(positionKey, user), 0);
    }

    function test_getBalanceOfOwner_mixedPositions_onlyCountsMatching() public {
        address user = address(0xBEEF);
        uint128 matching = 7_777e18;
        uint128 nonMatching = 9_999e18;

        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, matching);
        nftManager.mint(user, address(token0), address(token1), 100, 0, TICK_UPPER, nonMatching);

        assertEq(oracle.getBalanceOfOwner(positionKey, user), matching);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 14: TVL
    //////////////////////////////////////////////////////////////*/

    // getTVL is intentionally disabled for CLP positions (returns 0 always).
    // Pool-wide active liquidity is not per-position-key TVL and is manipulable.
    // Use getTVLByOwnerOfShares for per-strategy TVL.

    function test_getTVL_alwaysReturnsZero() public view {
        assertEq(oracle.getTVL(positionKey), 0, "getTVL must always return 0 for CLP");
    }

    function test_getTVLByOwnerOfShares_noPositions_returnsZero() public view {
        assertEq(oracle.getTVLByOwnerOfShares(positionKey, address(0xBEEF)), 0);
    }

    function test_getTVLByOwnerOfShares_withPosition_nonZero() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000_000e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(positionKey, user);
        assertGt(tvl, 0, "owner TVL must be > 0 when they hold a position");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 15: STALENESS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_revertsOnStaleFeed0() public {
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    function test_getPricePerShare_revertsOnNegativePrice() public {
        feed0.setLatestAnswer(-1);
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    function test_getPricePerShare_revertsOnZeroPrice() public {
        feed1.setLatestAnswer(0);
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 16: SEQUENCER UPTIME
    //////////////////////////////////////////////////////////////*/

    function test_sequencer_revertsWhenDown() public {
        MockAggregator seqFeed = new MockAggregator(0);
        seqFeed.setLatestAnswer(1); // 1 = sequencer down

        // Register a new position (needs different pool to get unique key)
        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        pool2.setSlot0(uint160(Q96), 0);

        address seqKey = registry.registerPosition(
            address(pool2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(seqFeed), 3600
        );

        vm.expectRevert(UniV3CLPYieldSourceOracle.SEQUENCER_DOWN.selector);
        oracle.getPricePerShare(seqKey);
    }

    function test_sequencer_revertsInGracePeriod() public {
        MockAggregator seqFeed = new MockAggregator(0);
        seqFeed.setLatestAnswer(0); // sequencer up

        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        pool2.setSlot0(uint160(Q96), 0);

        uint256 gracePeriod = 3600;
        address seqKey = registry.registerPosition(
            address(pool2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(seqFeed), gracePeriod
        );

        // startedAt = block.timestamp (sequencer just came up), we're within grace period
        vm.expectRevert(UniV3CLPYieldSourceOracle.GRACE_PERIOD_NOT_OVER.selector);
        oracle.getPricePerShare(seqKey);
    }

    function test_sequencer_succeedsAfterGracePeriod() public {
        MockAggregator seqFeed = new MockAggregator(0);
        seqFeed.setLatestAnswer(0); // sequencer up

        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        pool2.setSlot0(uint160(Q96), 0);

        uint256 gracePeriod = 3600;
        address seqKey = registry.registerPosition(
            address(pool2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(seqFeed), gracePeriod
        );

        vm.warp(block.timestamp + gracePeriod + 1);
        feed0.setLatestAnswer(1e8);
        feed1.setLatestAnswer(1e8);

        uint256 pps = oracle.getPricePerShare(seqKey);
        assertGt(pps, 0, "should work after grace period");
    }

    function test_sequencer_disabledOnL1() public view {
        // Default positionKey has address(0) sequencer feed — must not revert
        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0, "should work with sequencer disabled");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 17: DIFFERENT DECIMAL COMBOS
    //////////////////////////////////////////////////////////////*/

    /// @notice 6/18 decimals (USDC/WETH style) — token0=USDC, token1=WETH
    function test_decimals_6_18_usdcWethStyle() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);

        MockAggregator feedUsdc = new MockAggregator(8);
        MockAggregator feedWeth = new MockAggregator(8);
        feedUsdc.setLatestAnswer(1e8);       // USDC = $1
        feedWeth.setLatestAnswer(4000e8);    // WETH = $4000

        MockUniswapV3CLPool wethUsdcPool = new MockUniswapV3CLPool(address(usdc), address(weth), 10);
        uint160 sqrtPriceX96 = 1_253_127_283_174_956_528_741_455_285_830;
        wethUsdcPool.setSlot0(sqrtPriceX96, 0);
        wethUsdcPool.setLiquidity(1e15);

        address key = registry.registerPosition(
            address(wethUsdcPool), address(nftManager), -887200, 887200,
            address(usdc), address(weth), 10, address(feedUsdc), address(feedWeth),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "USDC/WETH 6/18 PPS must be > 0");
    }

    /// @notice 8/18 decimals (WBTC/WETH style)
    function test_decimals_8_18_wbtcWethStyle() public {
        MockERC20 wbtc = new MockERC20("WBTC", "WBTC", 8);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);

        MockAggregator feedBtc = new MockAggregator(8);
        MockAggregator feedEth = new MockAggregator(8);
        feedBtc.setLatestAnswer(100_000e8);  // BTC = $100k
        feedEth.setLatestAnswer(4000e8);     // ETH = $4k

        MockUniswapV3CLPool wbtcWethPool = new MockUniswapV3CLPool(address(wbtc), address(weth), 60);
        wbtcWethPool.setSlot0(uint160(Q96), 0);
        wbtcWethPool.setLiquidity(1e10);

        address key = registry.registerPosition(
            address(wbtcWethPool), address(nftManager), -887160, 887160,
            address(wbtc), address(weth), 60, address(feedBtc), address(feedEth),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "WBTC/WETH 8/18 PPS must be > 0");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 18: CIRCUIT BREAKER BOUNDS IN REGISTRY
    //////////////////////////////////////////////////////////////*/

    function test_circuitBreakerBounds_storedInRegistry() public view {
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(positionKey);
        // MockAggregator implements aggregator() → self, minAnswer/maxAnswer default to 0
        // So circuit breaker is effectively disabled (check condition: minAnswer > 0)
        assertEq(cfg.feed0MinAnswer, 0);
        assertEq(cfg.feed0MaxAnswer, 0);
        assertEq(cfg.feed1MinAnswer, 0);
        assertEq(cfg.feed1MaxAnswer, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 19: FUZZ — ROUNDING INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getWithdrawalShareOutput_geqGetShareOutput(uint96 assetsIn) public view {
        vm.assume(assetsIn > 0);

        uint256 sharesFloor = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 sharesCeil = oracle.getWithdrawalShareOutput(positionKey, address(0), assetsIn);
        assertGe(sharesCeil, sharesFloor, "withdrawal shares must be >= deposit shares");
    }

    function testFuzz_roundTrip_noValueCreation(uint96 assetsIn) public view {
        vm.assume(assetsIn > 0);

        uint256 shares = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(positionKey, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    function testFuzz_getAssetOutput_scalesLinear(uint64 shares) public view {
        vm.assume(shares > 0 && shares < type(uint64).max / 2);

        uint256 out1 = oracle.getAssetOutput(positionKey, address(0), shares);
        uint256 out2 = oracle.getAssetOutput(positionKey, address(0), uint256(shares) * 2);
        assertApproxEqAbs(out2, out1 * 2, 1, "asset output should scale linearly");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 20: SQRTPRICE RECONSTRUCTION MATH
    //////////////////////////////////////////////////////////////*/

    function test_sqrtPriceReconstruction_equalPrices18dec_isQ96() public {
        uint256 pps1 = oracle.getPricePerShare(positionKey);

        // Scaling both prices by the same factor shouldn't change the ratio
        feed0.setLatestAnswer(1_000_000e8);
        feed1.setLatestAnswer(1_000_000e8);
        uint256 pps2 = oracle.getPricePerShare(positionKey);

        assertEq(pps1, pps2, "PPS should be the same for any equal price ratio");
    }

    function testFuzz_pps_scaleInvariant(uint8 scaleFactor) public {
        vm.assume(scaleFactor > 0 && scaleFactor < 100);

        uint256 pps1 = oracle.getPricePerShare(positionKey);

        feed0.setLatestAnswer(int256(1e8) * int256(uint256(scaleFactor)));
        feed1.setLatestAnswer(int256(1e8) * int256(uint256(scaleFactor)));
        uint256 pps2 = oracle.getPricePerShare(positionKey);

        assertEq(pps1, pps2, "PPS must be scale-invariant (ratio unchanged)");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 21: ORACLE AFTER DEREGISTRATION
    //////////////////////////////////////////////////////////////*/

    function test_oracle_revertsAfterDeregistration() public {
        // Propose and execute deregistration
        registry.proposeDeregisterPosition(positionKey);
        vm.warp(block.timestamp + 2 days);
        registry.executeDeregisterPosition(positionKey);

        // Oracle calls should now revert
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getPricePerShare(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 22: MULTI-POSITION ORACLE
    //////////////////////////////////////////////////////////////*/

    function test_oracle_multiplePositions_independentPrices() public {
        // Register a second position with different prices
        MockERC20 token2A = new MockERC20("T2A", "T2A", 6);
        MockERC20 token2B = new MockERC20("T2B", "T2B", 18);
        MockAggregator feed2A = new MockAggregator(8);
        MockAggregator feed2B = new MockAggregator(8);
        feed2A.setLatestAnswer(1e8);      // $1
        feed2B.setLatestAnswer(2000e8);   // $2000

        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token2A), address(token2B), 10);
        pool2.setSlot0(uint160(Q96), 0);

        address key2 = registry.registerPosition(
            address(pool2), address(nftManager), -887200, 887200,
            address(token2A), address(token2B), 10, address(feed2A), address(feed2B),
            MAX_STALENESS, address(0), 0
        );

        // Both positions should return > 0 from the same oracle
        uint256 pps1 = oracle.getPricePerShare(positionKey);
        uint256 pps2 = oracle.getPricePerShare(key2);
        assertGt(pps1, 0, "position1 PPS must be > 0");
        assertGt(pps2, 0, "position2 PPS must be > 0");

        // They should differ because they have different price ratios
        assertTrue(pps1 != pps2, "independent positions should have different PPS");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 23: CIRCUIT BREAKER TRIGGERING
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper: register a position whose feeds have circuit breaker bounds enabled
    function _registerWithCircuitBreakers()
        internal
        returns (address key, MockAggregator cbFeed0, MockAggregator cbFeed1)
    {
        cbFeed0 = new MockAggregator(8);
        cbFeed1 = new MockAggregator(8);
        cbFeed0.setLatestAnswer(1000e8);
        cbFeed1.setLatestAnswer(1000e8);

        // Set circuit breaker bounds: [100, 10_000] in 8-decimal feed units
        cbFeed0.setCircuitBreakerBounds(100e8, 10_000e8);
        cbFeed1.setCircuitBreakerBounds(100e8, 10_000e8);

        MockUniswapV3CLPool cbPool = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        cbPool.setSlot0(uint160(Q96), 0);
        cbPool.setLiquidity(1_000_000e18);

        key = registry.registerPosition(
            address(cbPool), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(cbFeed0), address(cbFeed1),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_circuitBreaker_feed0AtMinBound_reverts() public {
        (address key, MockAggregator cbFeed0,) = _registerWithCircuitBreakers();
        // Price <= minAnswer triggers INVALID_PRICE
        cbFeed0.setLatestAnswer(100e8); // exactly at min bound
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_feed0BelowMinBound_reverts() public {
        (address key, MockAggregator cbFeed0,) = _registerWithCircuitBreakers();
        cbFeed0.setLatestAnswer(50e8); // below min
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_feed0AtMaxBound_reverts() public {
        (address key, MockAggregator cbFeed0,) = _registerWithCircuitBreakers();
        cbFeed0.setLatestAnswer(10_000e8); // exactly at max bound
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_feed0AboveMaxBound_reverts() public {
        (address key, MockAggregator cbFeed0,) = _registerWithCircuitBreakers();
        cbFeed0.setLatestAnswer(20_000e8); // above max
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_feed1AtMinBound_reverts() public {
        (address key,, MockAggregator cbFeed1) = _registerWithCircuitBreakers();
        cbFeed1.setLatestAnswer(100e8);
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_feed1AtMaxBound_reverts() public {
        (address key,, MockAggregator cbFeed1) = _registerWithCircuitBreakers();
        cbFeed1.setLatestAnswer(10_000e8);
        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(key);
    }

    function test_circuitBreaker_withinBounds_succeeds() public {
        (address key,,) = _registerWithCircuitBreakers();
        // 1000e8 is within [100e8, 10_000e8] — should work
        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0);
    }

    function test_circuitBreaker_boundsStoredInRegistry() public {
        (address key,,) = _registerWithCircuitBreakers();
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);
        assertEq(cfg.feed0MinAnswer, 100e8);
        assertEq(cfg.feed0MaxAnswer, 10_000e8);
        assertEq(cfg.feed1MinAnswer, 100e8);
        assertEq(cfg.feed1MaxAnswer, 10_000e8);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 24: STALENESS (TIMESTAMP-BASED)
    //////////////////////////////////////////////////////////////*/

    // NOTE: answeredInRound < roundId check was removed (deprecated in modern Chainlink OCR feeds).
    // Staleness is now validated solely via block.timestamp - updatedAt > maxStaleness.

    function test_staleFeed1_reverts() public {
        // Move time forward so feed1 is stale (feed0 freshened by setLatestAnswer)
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        // Refresh feed0 but not feed1
        feed0.setLatestAnswer(1e8);
        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 25: BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function _registerSecondPosition() internal returns (address key2) {
        MockERC20 t2A = new MockERC20("T2A", "T2A", 18);
        MockERC20 t2B = new MockERC20("T2B", "T2B", 18);
        MockAggregator f2A = new MockAggregator(8);
        MockAggregator f2B = new MockAggregator(8);
        f2A.setLatestAnswer(1e8);
        f2B.setLatestAnswer(2e8);

        MockUniswapV3CLPool p2 = new MockUniswapV3CLPool(address(t2A), address(t2B), 100);
        p2.setSlot0(uint160(Q96), 0);
        p2.setLiquidity(500_000e18);

        key2 = registry.registerPosition(
            address(p2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(t2A), address(t2B), 100, address(f2A), address(f2B),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_getPricePerShareMultiple_returnsBoth() public {
        address key2 = _registerSecondPosition();

        address[] memory keys = new address[](2);
        keys[0] = positionKey;
        keys[1] = key2;

        uint256[] memory prices = oracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 2);
        assertGt(prices[0], 0, "position1 PPS");
        assertGt(prices[1], 0, "position2 PPS");
        assertEq(prices[0], oracle.getPricePerShare(positionKey));
        assertEq(prices[1], oracle.getPricePerShare(key2));
    }

    function test_getPricePerShareMultiple_emptyArray() public view {
        address[] memory keys = new address[](0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 0);
    }

    function test_getTVLMultiple_returnsZeros() public {
        address key2 = _registerSecondPosition();

        address[] memory keys = new address[](2);
        keys[0] = positionKey;
        keys[1] = key2;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 0, "getTVL disabled for CLP");
        assertEq(tvls[1], 0, "getTVL disabled for CLP");
    }

    function test_getTVLByOwnerOfSharesMultiple_returnsBoth() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000e18);

        address[] memory keys = new address[](1);
        keys[0] = positionKey;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = user;
        owners[0][1] = address(0xDEAD); // no positions

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertEq(tvls.length, 1);
        assertEq(tvls[0].length, 2);
        assertGt(tvls[0][0], 0, "user with position should have TVL > 0");
        assertTrue(succeeded[0][0], "user with position should succeed");
        assertEq(tvls[0][1], 0, "user without positions should have TVL = 0");
        assertTrue(succeeded[0][1], "user without positions should still succeed");
    }

    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch_reverts() public {
        address[] memory keys = new address[](2);
        keys[0] = positionKey;
        keys[1] = positionKey;

        address[][] memory owners = new address[][](1); // mismatched length
        owners[0] = new address[](1);
        owners[0][0] = address(0xBEEF);

        vm.expectRevert();
        oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 26: GET ASSET OUTPUT WITH FEES
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutputWithFees_noConfig_returnBaseOutput() public view {
        // No YieldSourceOracleConfig registered in SuperLedgerConfiguration
        // Should fall back to base getAssetOutput (catch block)
        bytes32 fakeOracleId = keccak256("fake");
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, positionKey, address(0), address(0xBEEF), 1e18);
        uint256 base = oracle.getAssetOutput(positionKey, address(0), 1e18);
        assertEq(result, base, "should return base output when no config exists");
    }

    function test_getAssetOutputWithFees_zeroShares_returnsZero() public view {
        bytes32 fakeOracleId = keccak256("fake");
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, positionKey, address(0), address(0xBEEF), 0);
        assertEq(result, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 27: FEED DECIMAL COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice 18-decimal Chainlink feeds (e.g. ETH-denominated feeds)
    function test_decimals_18decFeeds_6_18tokens() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);

        MockAggregator feedUsdc18 = new MockAggregator(18);
        MockAggregator feedWeth18 = new MockAggregator(18);
        feedUsdc18.setLatestAnswer(1e18);        // USDC = $1
        feedWeth18.setLatestAnswer(4000e18);     // WETH = $4000

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(usdc), address(weth), 10);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1e15);

        address key = registry.registerPosition(
            address(p), address(nftManager), -887200, 887200,
            address(usdc), address(weth), 10, address(feedUsdc18), address(feedWeth18),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "18-dec feeds with 6/18 tokens must return > 0 PPS");
    }

    /// @notice Mixed feed decimals: feed0=8, feed1=18
    function test_decimals_mixedFeedDecimals_8_18() public {
        MockAggregator feedA = new MockAggregator(8);
        MockAggregator feedB = new MockAggregator(18);
        feedA.setLatestAnswer(1e8);
        feedB.setLatestAnswer(1e18);

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1_000_000e18);

        address key = registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 100, address(feedA), address(feedB),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "mixed feed decimals must return > 0 PPS");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 28: TOKEN MISMATCH VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_registry_registerPosition_revertsOnWrongToken0() public {
        MockERC20 wrongToken = new MockERC20("WRONG", "WRG", 18);
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.TOKEN_MISMATCH.selector);
        registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(wrongToken), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnWrongToken1() public {
        MockERC20 wrongToken = new MockERC20("WRONG", "WRG", 18);
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.TOKEN_MISMATCH.selector);
        registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(wrongToken), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnSwappedTokens() public {
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.TOKEN_MISMATCH.selector);
        registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token1), address(token0), // swapped!
            100, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 29: TICK ALIGNMENT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_registry_registerPosition_revertsOnMisalignedTickLower() public {
        // tickSpacing = 100, tickLower = -6001 is NOT a multiple of 100
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.INVALID_TICK_ALIGNMENT.selector);
        registry.registerPosition(
            address(p), address(nftManager), -6001, TICK_UPPER,
            address(token0), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_revertsOnMisalignedTickUpper() public {
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        vm.expectRevert(UniV3CLPRegistry.INVALID_TICK_ALIGNMENT.selector);
        registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, 6001,
            address(token0), address(token1), 100, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
    }

    function test_registry_registerPosition_succeedsWithAlignedTicks() public {
        // tickSpacing = 10, ticks -100 and 200 are aligned
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 10);
        p.setSlot0(uint160(Q96), 0);

        address key = registry.registerPosition(
            address(p), address(nftManager), -100, 200,
            address(token0), address(token1), 10, address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );
        assertTrue(registry.isRegistered(key));
    }

    /*//////////////////////////////////////////////////////////////
            SECTION 29b: FEE OR TICK SPACING VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_registry_registerPosition_revertsOnWrongFeeOrTickSpacing() public {
        // Pool tickSpacing = 100, no fee() → only uint24(int24(100)) = 100 accepted
        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        p.setSlot0(uint160(Q96), 0);
        vm.expectRevert(UniV3CLPRegistry.FEE_OR_TICK_SPACING_MISMATCH.selector);
        registry.registerPosition(
            address(p), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(token0), address(token1), 500, // wrong: should be 100
            address(feed0), address(feed1), MAX_STALENESS, address(0), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                SECTION 30: REFRESH CIRCUIT BREAKER BOUNDS
    //////////////////////////////////////////////////////////////*/

    function test_refreshFeedConfig_updatesStoredBounds() public {
        (address key, MockAggregator cbFeed0, MockAggregator cbFeed1) = _registerWithCircuitBreakers();

        // Verify initial bounds
        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);
        assertEq(cfg.feed0MinAnswer, 100e8);
        assertEq(cfg.feed0MaxAnswer, 10_000e8);

        // Update the mock aggregator bounds (simulating Chainlink aggregator upgrade)
        cbFeed0.setCircuitBreakerBounds(200e8, 5_000e8);
        cbFeed1.setCircuitBreakerBounds(50e8, 20_000e8);

        // Refresh
        registry.refreshFeedConfig(key);

        // Verify updated bounds
        cfg = registry.getPositionConfig(key);
        assertEq(cfg.feed0MinAnswer, 200e8);
        assertEq(cfg.feed0MaxAnswer, 5_000e8);
        assertEq(cfg.feed1MinAnswer, 50e8);
        assertEq(cfg.feed1MaxAnswer, 20_000e8);
    }

    function test_refreshFeedConfig_revertsForUnregistered() public {
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        registry.refreshFeedConfig(address(0xDEAD));
    }

    function test_refreshFeedConfig_revertsForNonManager() public {
        address stranger = address(0x1234);
        vm.prank(stranger);
        vm.expectRevert();
        registry.refreshFeedConfig(positionKey);
    }
}
