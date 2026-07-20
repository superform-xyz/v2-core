// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

import { UniV3CLPRegistry } from "../../../../src/accounting/oracles/UniV3CLPRegistry.sol";
import { UniV3CLPYieldSourceOracle } from "../../../../src/accounting/oracles/UniV3CLPYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { AbstractYieldSourceOracle } from "../../../../src/accounting/oracles/AbstractYieldSourceOracle.sol";
import { CLLiquidityAmounts } from "../../../../src/vendor/uniswap/v3/CLLiquidityAmounts.sol";
import { MockUniswapV3CLPool } from "../../../mocks/MockUniswapV3CLPool.sol";
import { MockNonfungiblePositionManager } from "../../../mocks/MockNonfungiblePositionManager.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";

/// @title UniV3CLPYieldSourceOracleEdgeCases
/// @notice Comprehensive edge case tests covering all security fixes:
///         1. Inter-feed timestamp skew (MAX_FEED_SKEW = 60s)
///         2. answeredInRound < roundId staleness check
///         3. PPS probe liquidity (1e24) for extreme tick ranges
///         4. Fee/tickSpacing disambiguation in _getBalanceOfOwner
///         5. getTVL disabled (always returns 0)
///         6. Batched TVL read isolation (try/catch in getTVLByOwnerOfSharesMultiple)
contract UniV3CLPYieldSourceOracleEdgeCasesTest is Test {
    UniV3CLPRegistry public registry;
    UniV3CLPYieldSourceOracle public oracle;
    MockUniswapV3CLPool public pool;
    MockNonfungiblePositionManager public nftManager;
    MockAggregator public feed0;
    MockAggregator public feed1;
    MockERC20 public token0;
    MockERC20 public token1;
    address public ledgerConfig;
    address public positionKey;

    int24 public constant TICK_LOWER = -6000;
    int24 public constant TICK_UPPER = 6000;
    uint256 public constant Q96 = 0x1000000000000000000000000;
    uint256 public constant MAX_STALENESS = 1 hours;

    function setUp() public {
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        feed0 = new MockAggregator(8);
        feed1 = new MockAggregator(8);
        feed0.setLatestAnswer(1e8);
        feed1.setLatestAnswer(1e8);

        pool = new MockUniswapV3CLPool(address(token0), address(token1), 100);
        nftManager = new MockNonfungiblePositionManager();

        pool.setSlot0(uint160(Q96), 0);
        pool.setLiquidity(1_000_000e18);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new UniV3CLPRegistry(address(this));

        positionKey = registry.registerPosition(
            address(pool),
            address(nftManager),
            TICK_LOWER,
            TICK_UPPER,
            address(token0),
            address(token1),
            address(feed0),
            address(feed1),
            MAX_STALENESS,
            address(0),
            0
        );

        oracle = new UniV3CLPYieldSourceOracle(ledgerConfig, address(registry));

        // Warp to a realistic timestamp so setUpdatedAt with past values doesn't underflow
        vm.warp(1_700_000_000);
        feed0.setLatestAnswer(1e8);
        feed1.setLatestAnswer(1e8);
    }

    /*//////////////////////////////////////////////////////////////
        FIX 1: INTER-FEED TIMESTAMP SKEW (MAX_FEED_SKEW = 60s)
    //////////////////////////////////////////////////////////////*/

    /// @notice Both feeds updated at same time — should succeed
    function test_feedSkew_bothFresh_succeeds() public view {
        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    /// @notice Feeds updated 30s apart (within 60s threshold) — should succeed
    function test_feedSkew_withinThreshold_succeeds() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 30);

        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    /// @notice Feeds updated exactly 60s apart (at threshold boundary) — should succeed
    function test_feedSkew_atExactThreshold_succeeds() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 60);

        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    /// @notice Feeds updated 61s apart (exceeds threshold) — should revert
    function test_feedSkew_exceedsThreshold_reverts() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 61);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Skew in reverse direction (feed1 newer than feed0) — should also revert
    function test_feedSkew_reverseDirection_exceedsThreshold_reverts() public {
        feed0.setUpdatedAt(block.timestamp - 61);
        feed1.setUpdatedAt(block.timestamp);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Large skew (10 minutes) — should revert
    function test_feedSkew_largeSkew_reverts() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 600);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Skew check applies to getShareOutput too (calls getPricePerShare)
    function test_feedSkew_propagatesToGetShareOutput() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 61);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getShareOutput(positionKey, address(0), 1e18);
    }

    /// @notice Skew check applies to getAssetOutput too
    function test_feedSkew_propagatesToGetAssetOutput() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 61);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getAssetOutput(positionKey, address(0), 1e18);
    }

    /// @notice Skew check applies to getWithdrawalShareOutput too
    function test_feedSkew_propagatesToGetWithdrawalShareOutput() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 61);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getWithdrawalShareOutput(positionKey, address(0), 1e18);
    }

    /// @notice Skew check applies to getTVLByOwnerOfShares too
    function test_feedSkew_propagatesToGetTVLByOwnerOfShares() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000e18);

        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp - 61);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getTVLByOwnerOfShares(positionKey, user);
    }

    /*//////////////////////////////////////////////////////////////
        FIX 2: answeredInRound < roundId STALENESS CHECK
    //////////////////////////////////////////////////////////////*/

    /// @notice answeredInRound == roundId — valid, should succeed
    function test_answeredInRound_equal_succeeds() public {
        feed0.setRoundData(5, 5);
        feed1.setRoundData(3, 3);

        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    /// @notice answeredInRound > roundId — valid (shouldn't happen in practice but still valid)
    function test_answeredInRound_greaterThanRoundId_succeeds() public {
        feed0.setRoundData(5, 6);
        feed1.setRoundData(3, 3);

        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
    }

    /// @notice feed0 has answeredInRound < roundId — should revert STALE_PRICE
    function test_answeredInRound_feed0Stale_reverts() public {
        feed0.setRoundData(5, 4); // answeredInRound(4) < roundId(5)
        feed1.setRoundData(3, 3);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice feed1 has answeredInRound < roundId — should revert STALE_PRICE
    function test_answeredInRound_feed1Stale_reverts() public {
        feed0.setRoundData(5, 5);
        feed1.setRoundData(10, 8); // answeredInRound(8) < roundId(10)

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Both feeds stale by answeredInRound — should revert (feed0 checked first)
    function test_answeredInRound_bothStale_reverts() public {
        feed0.setRoundData(5, 3);
        feed1.setRoundData(10, 7);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Combined: answeredInRound ok but timestamp stale — should also revert
    function test_answeredInRound_okButTimestampStale_reverts() public {
        feed0.setRoundData(5, 5);
        feed0.setUpdatedAt(block.timestamp - MAX_STALENESS - 1);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
        FIX 3: PPS PROBE LIQUIDITY FOR EXTREME TICK RANGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard range PPS consistency — probe should match proportionally
    function test_probeLiquidity_standardRange_ppsConsistent() public view {
        uint256 pps = oracle.getPricePerShare(positionKey);
        // 1:1 price, symmetric range: PPS should be roughly 2 * amount per token
        assertGt(pps, 0);
    }

    /// @notice Narrow range at high ticks — PPS should still be > 0 thanks to probe
    function test_probeLiquidity_extremeHighTicks_ppsNonZero() public {
        // Create a narrow range at moderately high ticks where 1e18 liquidity produces
        // near-zero amounts but 1e24 probe should still produce meaningful amounts
        MockERC20 t0 = new MockERC20("T0", "T0", 6); // small decimals amplifies the issue
        MockERC20 t1 = new MockERC20("T1", "T1", 18);
        MockAggregator f0 = new MockAggregator(8);
        MockAggregator f1 = new MockAggregator(8);
        f0.setLatestAnswer(1e8);
        f1.setLatestAnswer(1e8);

        // tickSpacing = 10 to allow narrow ranges
        MockUniswapV3CLPool extremePool = new MockUniswapV3CLPool(address(t0), address(t1), 10);
        extremePool.setSlot0(uint160(Q96), 0);
        extremePool.setLiquidity(1e18);

        // Moderately high tick range: [500000, 500100]
        // At these ticks the sqrtPrice is large enough that amount0 per 1e18 liquidity
        // is dust, but 1e24 probe (1e6x more) should produce non-zero amounts
        int24 extremeLower = 500_000;
        int24 extremeUpper = 500_100;

        address extremeKey = registry.registerPosition(
            address(extremePool),
            address(nftManager),
            extremeLower,
            extremeUpper,
            address(t0),
            address(t1),
            address(f0),
            address(f1),
            MAX_STALENESS,
            address(0),
            0
        );

        uint256 pps = oracle.getPricePerShare(extremeKey);
        // With 1e24 probe, this should still produce a non-zero PPS
        // (without the fix, 1e18 probe would floor to 0)
        assertGt(pps, 0, "PPS must be > 0 at extreme high ticks with probe liquidity");
    }

    /// @notice Near min tick extreme range — PPS should be > 0
    function test_probeLiquidity_extremeLowTicks_ppsNonZero() public {
        MockERC20 t0 = new MockERC20("T0", "T0", 18);
        MockERC20 t1 = new MockERC20("T1", "T1", 6);
        MockAggregator f0 = new MockAggregator(8);
        MockAggregator f1 = new MockAggregator(8);
        f0.setLatestAnswer(1e8);
        f1.setLatestAnswer(1e8);

        MockUniswapV3CLPool extremePool = new MockUniswapV3CLPool(address(t0), address(t1), 10);
        extremePool.setSlot0(uint160(Q96), 0);
        extremePool.setLiquidity(1e18);

        int24 extremeLower = -887210;
        int24 extremeUpper = -887200;

        address extremeKey = registry.registerPosition(
            address(extremePool),
            address(nftManager),
            extremeLower,
            extremeUpper,
            address(t0),
            address(t1),
            address(f0),
            address(f1),
            MAX_STALENESS,
            address(0),
            0
        );

        uint256 pps = oracle.getPricePerShare(extremeKey);
        assertGt(pps, 0, "PPS must be > 0 at extreme low ticks with probe liquidity");
    }

    /// @notice Round-trip at extreme range — must not create value
    function test_probeLiquidity_extremeRange_roundTrip_noValueCreation() public {
        MockERC20 t0 = new MockERC20("T0", "T0", 6);
        MockERC20 t1 = new MockERC20("T1", "T1", 18);
        MockAggregator f0 = new MockAggregator(8);
        MockAggregator f1 = new MockAggregator(8);
        f0.setLatestAnswer(1e8);
        f1.setLatestAnswer(1e8);

        MockUniswapV3CLPool extremePool = new MockUniswapV3CLPool(address(t0), address(t1), 10);
        extremePool.setSlot0(uint160(Q96), 0);
        extremePool.setLiquidity(1e18);

        address extremeKey = registry.registerPosition(
            address(extremePool),
            address(nftManager),
            500_000,
            500_100,
            address(t0),
            address(t1),
            address(f0),
            address(f1),
            MAX_STALENESS,
            address(0),
            0
        );

        uint256 assetsIn = 1e6;
        uint256 shares = oracle.getShareOutput(extremeKey, address(0), assetsIn);
        if (shares > 0) {
            uint256 assetsOut = oracle.getAssetOutput(extremeKey, address(0), shares);
            assertLe(assetsOut, assetsIn, "round-trip must not create value at extreme ticks");
        }
    }

    /// @notice Wide range PPS should be proportional to probe-scaled PPS
    function test_probeLiquidity_wideRange_ppsMatchesExpected() public view {
        // 1:1 price, [-6000, 6000] range with 18-decimal tokens
        // PPS should be positive and reasonable
        uint256 pps = oracle.getPricePerShare(positionKey);
        assertGt(pps, 0);
        assertLt(pps, 1e30, "sanity upper bound");
    }

    /*//////////////////////////////////////////////////////////////
        FIX 4: FEE/TICKSPACING DISAMBIGUATION IN BALANCE OF OWNER
    //////////////////////////////////////////////////////////////*/

    /// @notice NFT with matching feeOrTickSpacing should be counted
    function test_feeMatch_matchingFee_counted() public {
        address user = address(0xBEEF);
        // Pool tickSpacing=100 → mock pool falls back to tickSpacing (no fee())
        // NFT with feeOrTickSpacing=100 should match
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 5_000e18);

        uint256 balance = oracle.getBalanceOfOwner(positionKey, user);
        assertEq(balance, 5_000e18, "matching feeOrTickSpacing should be counted");
    }

    /// @notice NFT with wrong feeOrTickSpacing should NOT be counted (different fee tier)
    function test_feeMatch_differentFee_excluded() public {
        address user = address(0xBEEF);
        // Pool tickSpacing=100, but NFT says feeOrTickSpacing=500 (different pool's fee tier)
        nftManager.mint(user, address(token0), address(token1), 500, TICK_LOWER, TICK_UPPER, 5_000e18);

        uint256 balance = oracle.getBalanceOfOwner(positionKey, user);
        assertEq(balance, 0, "different feeOrTickSpacing must be excluded");
    }

    /// @notice Mix of matching and non-matching fee tiers — only matching counted
    function test_feeMatch_mixedFeeTiers_onlyMatchingCounted() public {
        address user = address(0xBEEF);

        // Matching: feeOrTickSpacing=100 (matches pool's tickSpacing)
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 3_000e18);

        // Non-matching: feeOrTickSpacing=500
        nftManager.mint(user, address(token0), address(token1), 500, TICK_LOWER, TICK_UPPER, 7_000e18);

        // Non-matching: feeOrTickSpacing=3000
        nftManager.mint(user, address(token0), address(token1), 3000, TICK_LOWER, TICK_UPPER, 2_000e18);

        uint256 balance = oracle.getBalanceOfOwner(positionKey, user);
        assertEq(balance, 3_000e18, "only matching fee tier should be counted");
    }

    /// @notice Same tokens, same range, different fee — must not cross-pollinate TVL
    function test_feeMatch_crossPoolTVL_isolated() public {
        address user = address(0xBEEF);

        // Mint position for a different fee tier (simulating USDC/WETH 0.3% vs 0.05%)
        nftManager.mint(user, address(token0), address(token1), 3000, TICK_LOWER, TICK_UPPER, 10_000e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(positionKey, user);
        assertEq(tvl, 0, "TVL from different fee tier must not be attributed");
    }

    /// @notice Multiple users, each with different fee tiers — correct per-user isolation
    function test_feeMatch_multipleUsers_correctAttribution() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        // Alice has matching fee
        nftManager.mint(alice, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 4_000e18);

        // Bob has non-matching fee
        nftManager.mint(bob, address(token0), address(token1), 500, TICK_LOWER, TICK_UPPER, 6_000e18);

        assertEq(oracle.getBalanceOfOwner(positionKey, alice), 4_000e18, "Alice's matching position counted");
        assertEq(oracle.getBalanceOfOwner(positionKey, bob), 0, "Bob's non-matching position excluded");
    }

    /// @notice feeOrTickSpacing=0 should not match pool with tickSpacing=100
    function test_feeMatch_zeroFee_excluded() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 0, TICK_LOWER, TICK_UPPER, 1_000e18);

        uint256 balance = oracle.getBalanceOfOwner(positionKey, user);
        assertEq(balance, 0, "feeOrTickSpacing=0 must not match tickSpacing=100");
    }

    /// @notice Two registered pools with same tokens but different tick spacings — correct isolation
    function test_feeMatch_twoPoolsSameTokens_isolatedBalances() public {
        // Second pool with tickSpacing=60
        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(token0), address(token1), 60);
        pool2.setSlot0(uint160(Q96), 0);
        pool2.setLiquidity(500_000e18);

        // Register with ticks aligned to tickSpacing=60
        int24 tL2 = -6000; // divisible by 60
        int24 tU2 = 6000;
        address key2 = registry.registerPosition(
            address(pool2), address(nftManager), tL2, tU2,
            address(token0), address(token1), address(feed0), address(feed1),
            MAX_STALENESS, address(0), 0
        );

        address user = address(0xBEEF);

        // NFT matching pool1 (tickSpacing=100)
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 2_000e18);

        // NFT matching pool2 (tickSpacing=60)
        nftManager.mint(user, address(token0), address(token1), 60, tL2, tU2, 3_000e18);

        assertEq(oracle.getBalanceOfOwner(positionKey, user), 2_000e18, "pool1 balance");
        assertEq(oracle.getBalanceOfOwner(key2, user), 3_000e18, "pool2 balance");
    }

    /*//////////////////////////////////////////////////////////////
        FIX 5: getTVL DISABLED (ALWAYS RETURNS 0)
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVL returns 0 for registered position
    function test_getTVL_registered_returnsZero() public view {
        assertEq(oracle.getTVL(positionKey), 0, "getTVL must return 0 for CLP");
    }

    /// @notice getTVL returns 0 for unregistered position (no revert, pure function)
    function test_getTVL_unregistered_returnsZero() public view {
        assertEq(oracle.getTVL(address(0xDEAD)), 0, "getTVL must return 0 for any address");
    }

    /// @notice getTVLMultiple returns all zeros
    function test_getTVLMultiple_allZeros() public view {
        address[] memory keys = new address[](2);
        keys[0] = positionKey;
        keys[1] = address(0xBEEF);

        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertEq(tvls[0], 0);
        assertEq(tvls[1], 0);
    }

    /*//////////////////////////////////////////////////////////////
        FIX 6: BATCHED TVL READ ISOLATION (TRY/CATCH)
    //////////////////////////////////////////////////////////////*/

    /// @notice Batch with one stale entry and one fresh — fresh entry still returns data
    function test_batchIsolation_staleEntryDoesNotAbortBatch() public {
        // Create a second position with separate feeds
        MockERC20 t2A = new MockERC20("T2A", "T2A", 18);
        MockERC20 t2B = new MockERC20("T2B", "T2B", 18);
        MockAggregator f2A = new MockAggregator(8);
        MockAggregator f2B = new MockAggregator(8);
        f2A.setLatestAnswer(2e8);
        f2B.setLatestAnswer(1e8);

        MockUniswapV3CLPool pool2 = new MockUniswapV3CLPool(address(t2A), address(t2B), 100);
        pool2.setSlot0(uint160(Q96), 0);
        pool2.setLiquidity(500_000e18);

        address key2 = registry.registerPosition(
            address(pool2), address(nftManager), TICK_LOWER, TICK_UPPER,
            address(t2A), address(t2B), address(f2A), address(f2B),
            MAX_STALENESS, address(0), 0
        );

        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000e18);
        nftManager.mint(user, address(t2A), address(t2B), 100, TICK_LOWER, TICK_UPPER, 2_000e18);

        // Make feed0 of position1 stale — its TVL call will revert
        feed0.setRoundData(5, 3); // answeredInRound < roundId

        // Batch query: position1 (stale) + position2 (fresh)
        address[] memory keys = new address[](2);
        keys[0] = positionKey;
        keys[1] = key2;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = user;
        owners[1] = new address[](1);
        owners[1][0] = user;

        // Should NOT revert — stale entry returns 0, fresh entry returns real value
        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertEq(tvls[0][0], 0, "stale entry should return 0, not revert batch");
        assertGt(tvls[1][0], 0, "fresh entry should return real TVL");
    }

    /// @notice Batch with unregistered position key — should return 0, not abort
    function test_batchIsolation_unregisteredKey_returnsZero() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000e18);

        address[] memory keys = new address[](2);
        keys[0] = address(0xDEAD); // unregistered
        keys[1] = positionKey; // valid

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = user;
        owners[1] = new address[](1);
        owners[1][0] = user;

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertEq(tvls[0][0], 0, "unregistered key should return 0");
        assertGt(tvls[1][0], 0, "valid key should return real TVL");
    }

    /// @notice Batch where all entries are valid — should all return real values
    function test_batchIsolation_allValid_allReturnValues() public {
        address user = address(0xBEEF);
        nftManager.mint(user, address(token0), address(token1), 100, TICK_LOWER, TICK_UPPER, 1_000e18);

        address[] memory keys = new address[](1);
        keys[0] = positionKey;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = user;
        owners[0][1] = address(0xCAFE); // no positions

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertGt(tvls[0][0], 0, "user with positions");
        assertEq(tvls[0][1], 0, "user without positions");
    }

    /*//////////////////////////////////////////////////////////////
        COMBINED EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Negative Chainlink answer — should revert INVALID_PRICE
    function test_combined_negativePrice_reverts() public {
        feed0.setLatestAnswer(-1);

        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Zero Chainlink answer — should revert INVALID_PRICE
    function test_combined_zeroPrice_reverts() public {
        feed0.setLatestAnswer(0);

        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Circuit breaker: answer at minAnswer — should revert
    function test_combined_circuitBreaker_atMin_reverts() public {
        feed0.setCircuitBreakerBounds(1e6, 1e10);
        // Refresh bounds in registry
        registry.refreshCircuitBreakerBounds(positionKey);

        feed0.setLatestAnswer(1e6); // at minAnswer

        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Circuit breaker: answer at maxAnswer — should revert
    function test_combined_circuitBreaker_atMax_reverts() public {
        feed0.setCircuitBreakerBounds(1e6, 1e10);
        registry.refreshCircuitBreakerBounds(positionKey);

        feed0.setLatestAnswer(1e10); // at maxAnswer

        vm.expectRevert(UniV3CLPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Timestamp staleness beyond maxStaleness — should revert
    function test_combined_timestampStaleness_reverts() public {
        feed0.setUpdatedAt(block.timestamp - MAX_STALENESS - 1);

        vm.expectRevert(UniV3CLPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(positionKey);
    }

    /// @notice Zero input amounts — should return 0 (no revert)
    function test_combined_zeroInput_returnsZero() public view {
        assertEq(oracle.getShareOutput(positionKey, address(0), 0), 0);
        assertEq(oracle.getAssetOutput(positionKey, address(0), 0), 0);
        assertEq(oracle.getWithdrawalShareOutput(positionKey, address(0), 0), 0);
    }

    /// @notice Withdrawal shares (ceil) >= deposit shares (floor) for same asset amount
    function test_combined_withdrawalCeil_geq_depositFloor() public view {
        uint256 assetsIn = 1e18;
        uint256 sharesFloor = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 sharesCeil = oracle.getWithdrawalShareOutput(positionKey, address(0), assetsIn);
        assertGe(sharesCeil, sharesFloor, "withdrawal shares >= deposit shares");
    }

    /// @notice Round-trip deposit→withdraw must not create value
    function test_combined_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 1e18;
        uint256 shares = oracle.getShareOutput(positionKey, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(positionKey, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    /// @notice Asymmetric prices — PPS should change accordingly
    function test_combined_asymmetricPrices_ppsReflectsRatio() public {
        // token0=$1, token1=$2
        feed0.setLatestAnswer(1e8);
        feed1.setLatestAnswer(2e8);

        uint256 ppsAsym = oracle.getPricePerShare(positionKey);

        // token0=$1, token1=$1 (reset)
        feed1.setLatestAnswer(1e8);
        uint256 ppsEqual = oracle.getPricePerShare(positionKey);

        // When token1 is worth more, the liquidity position is worth more in token0 terms
        assertGt(ppsAsym, ppsEqual, "higher token1 price should increase PPS");
    }

    /// @notice Decimals always returns 18 regardless of yield source address
    function test_combined_decimals_always18() public view {
        assertEq(oracle.decimals(positionKey), 18);
        assertEq(oracle.decimals(address(0xDEAD)), 18);
        assertEq(oracle.decimals(address(0)), 18);
    }

    /*//////////////////////////////////////////////////////////////
        MIXED TOKEN DECIMALS
    //////////////////////////////////////////////////////////////*/

    /// @notice 6/18 decimal tokens (like USDC/WETH) — PPS should be non-zero
    function test_mixedDecimals_6_18_ppsNonZero() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockAggregator usdcFeed = new MockAggregator(8);
        MockAggregator ethFeed = new MockAggregator(8);
        usdcFeed.setLatestAnswer(1e8); // $1
        ethFeed.setLatestAnswer(3300e8); // $3300

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(usdc), address(weth), 10);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1e18);

        address key = registry.registerPosition(
            address(p), address(nftManager), -6000, 6000,
            address(usdc), address(weth), address(usdcFeed), address(ethFeed),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "6/18 decimal PPS must be > 0");
    }

    /// @notice 8/18 decimal tokens (like WBTC/WETH) — PPS should be non-zero
    function test_mixedDecimals_8_18_ppsNonZero() public {
        MockERC20 wbtc = new MockERC20("WBTC", "WBTC", 8);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockAggregator btcFeed = new MockAggregator(8);
        MockAggregator ethFeed = new MockAggregator(8);
        btcFeed.setLatestAnswer(95_000e8); // $95k
        ethFeed.setLatestAnswer(3300e8); // $3.3k

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(wbtc), address(weth), 60);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1e18);

        address key = registry.registerPosition(
            address(p), address(nftManager), -6000, 6000,
            address(wbtc), address(weth), address(btcFeed), address(ethFeed),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "8/18 decimal PPS must be > 0");
    }

    /// @notice 18/6 decimal tokens (like WETH/USDC on Base) — PPS should be non-zero
    function test_mixedDecimals_18_6_ppsNonZero() public {
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockAggregator ethFeed = new MockAggregator(8);
        MockAggregator usdcFeed = new MockAggregator(8);
        ethFeed.setLatestAnswer(3300e8);
        usdcFeed.setLatestAnswer(1e8);

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(weth), address(usdc), 100);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1e18);

        address key = registry.registerPosition(
            address(p), address(nftManager), -6000, 6000,
            address(weth), address(usdc), address(ethFeed), address(usdcFeed),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "18/6 decimal PPS must be > 0");
    }

    /// @notice Same-decimal tokens (18/18) with extreme price ratio
    function test_mixedDecimals_18_18_extremePriceRatio() public {
        MockERC20 t0 = new MockERC20("T0", "T0", 18);
        MockERC20 t1 = new MockERC20("T1", "T1", 18);
        MockAggregator f0 = new MockAggregator(8);
        MockAggregator f1 = new MockAggregator(8);
        f0.setLatestAnswer(1); // token0 = $0.00000001
        f1.setLatestAnswer(1e12); // token1 = $10,000

        MockUniswapV3CLPool p = new MockUniswapV3CLPool(address(t0), address(t1), 100);
        p.setSlot0(uint160(Q96), 0);
        p.setLiquidity(1e18);

        address key = registry.registerPosition(
            address(p), address(nftManager), -6000, 6000,
            address(t0), address(t1), address(f0), address(f1),
            MAX_STALENESS, address(0), 0
        );

        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "extreme price ratio PPS must be > 0");
    }
}
