// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { UniV2LPYieldSourceOracle } from "../../../../src/accounting/oracles/UniV2LPYieldSourceOracle.sol";
import { MockUniswapV2Pair } from "../../../mocks/MockUniswapV2Pair.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";

contract UniV2LPYieldSourceOracleTest is Test {
    UniV2LPYieldSourceOracle public oracle;
    MockUniswapV2Pair public pair;
    MockAggregator public feed0;
    MockAggregator public feed1;
    MockERC20 public token0;
    MockERC20 public token1;
    address public ledgerConfig;

    address public constant OWNER = address(0x123);
    address public constant USER_A = address(0x456);

    uint256 public constant MAX_STALENESS = 1 hours;

    function setUp() public {
        // Create tokens: default 18/18 decimals
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // Create mock pair
        pair = new MockUniswapV2Pair(address(token0), address(token1));

        // Create mock Chainlink feeds (8 decimals, both at $1)
        feed0 = new MockAggregator(8);
        feed1 = new MockAggregator(8);
        feed0.setLatestAnswer(1e8); // $1
        feed1.setLatestAnswer(1e8); // $1

        // Create ledger config and oracle
        ledgerConfig = address(new SuperLedgerConfiguration());
        oracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(feed0), address(feed1), address(token0), address(token1), MAX_STALENESS
        );

        // Default pool state: 1000 token0, 1000 token1, 1000 LP
        pair.setReserves(1000e18, 1000e18);
        pair.setTotalSupply(1000e18);
        pair.setBalance(OWNER, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsImmutables() public view {
        assertEq(address(oracle.FEED0()), address(feed0));
        assertEq(address(oracle.FEED1()), address(feed1));
        assertEq(oracle.FEED0_SCALE(), 1e8);
        assertEq(oracle.FEED1_SCALE(), 1e8);
        assertEq(oracle.TOKEN0_SCALE(), 1e18);
        assertEq(oracle.TOKEN1_DECIMALS(), 18);
        assertEq(oracle.MAX_STALENESS(), MAX_STALENESS);
    }

    function test_constructor_revertsOnZeroFeed0() public {
        vm.expectRevert(UniV2LPYieldSourceOracle.ZERO_ADDRESS.selector);
        new UniV2LPYieldSourceOracle(ledgerConfig, address(0), address(feed1), address(token0), address(token1), MAX_STALENESS);
    }

    function test_constructor_revertsOnZeroFeed1() public {
        vm.expectRevert(UniV2LPYieldSourceOracle.ZERO_ADDRESS.selector);
        new UniV2LPYieldSourceOracle(ledgerConfig, address(feed0), address(0), address(token0), address(token1), MAX_STALENESS);
    }

    function test_constructor_revertsOnZeroToken0() public {
        vm.expectRevert(UniV2LPYieldSourceOracle.ZERO_ADDRESS.selector);
        new UniV2LPYieldSourceOracle(ledgerConfig, address(feed0), address(feed1), address(0), address(token1), MAX_STALENESS);
    }

    function test_constructor_revertsOnZeroToken1() public {
        vm.expectRevert(UniV2LPYieldSourceOracle.ZERO_ADDRESS.selector);
        new UniV2LPYieldSourceOracle(ledgerConfig, address(feed0), address(feed1), address(token0), address(0), MAX_STALENESS);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_returns18() public view {
        assertEq(oracle.decimals(address(pair)), 18);
    }

    function test_decimals_returns18_forAnyAddress() public view {
        assertEq(oracle.decimals(address(0)), 18);
    }

    /*//////////////////////////////////////////////////////////////
                        getPricePerShare - BASIC
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_18_18_equalPrice() public view {
        // Both feeds at $1 -> cross-rate = 1e18 (1:1)
        // Pool: 1000 TK0 (18 dec) + 1000 TK1 (18 dec), supply 1000e18
        // p1InToken0 = 1e8 * 1e8 * 1e18 / (1e8 * 1e8) = 1e18
        // r1ValueInToken0 = 1000e18 * 1e18 / 1e18 = 1000e18
        // sqrt(1000e18 * 1000e18) = 1e21
        // PPS = 2 * 1e21 * 1e18 / 1000e18 = 2e18
        uint256 pps = oracle.getPricePerShare(address(pair));
        assertEq(pps, 2e18, "PPS should be 2 token0 per LP");
    }

    function test_getPricePerShare_18_18_unequalPrice() public {
        // token1 is 4x the price of token0
        // feed0 = $1, feed1 = $4
        feed1.setLatestAnswer(4e8);

        // p1InToken0 = 4e8 * 1e8 * 1e18 / (1e8 * 1e8) = 4e18
        // r1ValueInToken0 = 1000e18 * 4e18 / 1e18 = 4000e18
        // sqrt(1000e18 * 4000e18) = sqrt(4e42) = 2e21
        // PPS = 2 * 2e21 * 1e18 / 1000e18 = 4e18
        uint256 pps = oracle.getPricePerShare(address(pair));
        assertEq(pps, 4e18, "PPS should be 4 token0 per LP");
    }

    function test_getPricePerShare_6_18_decimals() public {
        // USDC (6 dec) / WETH (18 dec) pool
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockUniswapV2Pair usdcWethPair = new MockUniswapV2Pair(address(usdc), address(weth));

        // USDC feed = $1, WETH feed = $4000
        MockAggregator usdcFeed = new MockAggregator(8);
        MockAggregator wethFeed = new MockAggregator(8);
        usdcFeed.setLatestAnswer(1e8);
        wethFeed.setLatestAnswer(4000e8);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(usdcFeed), address(wethFeed), address(usdc), address(weth), MAX_STALENESS
        );

        // 4M USDC and 1000 WETH
        usdcWethPair.setReserves(4_000_000e6, 1000e18);
        usdcWethPair.setTotalSupply(2e18);

        // p1InToken0 = 4000e8 * 1e8 * 1e6 / (1e8 * 1e8) = 4000e6
        // r1ValueInToken0 = 1000e18 * 4000e6 / 1e18 = 4000e6 = 4e9
        // sqrt(4e12 * 4e9) = sqrt(1.6e22) ... let me recalculate
        // r0 = 4_000_000e6 = 4e12, r1ValueInToken0 = 1000e18 * 4000e6 / 1e18 = 4e9
        // Wait: r1ValueInToken0 = mulDiv(1000e18, 4000e6, 1e18) = 4000e6 = 4e9
        // sqrt(4e12 * 4e9) = sqrt(16e21) = 4e10.xxx -- let me just check the final
        // Actually: r1ValueInToken0 = 1000 * 4000e6 / 1 = 4_000_000e6 = 4e12
        // Hmm. Let me redo: mulDiv(1000e18, 4000e6, 1e18) = 1000 * 4000e6 = 4_000_000e6 = 4e12
        // No wait: mulDiv(a,b,c) = a*b/c = 1000e18 * 4000e6 / 1e18 = 4000e6 = 4e9
        // 1000e18 = 1e21. 1e21 * 4e9 / 1e18 = 4e12. Yes that's right.
        // sqrt(4e12 * 4e12) = sqrt(16e24) = 4e12
        // PPS = 2 * 4e12 * 1e18 / 2e18 = 4e12
        uint256 pps = localOracle.getPricePerShare(address(usdcWethPair));
        assertEq(pps, 4e12, "PPS should be 4M USDC (6-dec) per LP token");
    }

    function test_getPricePerShare_18_6_decimals() public {
        // WETH (18 dec) / USDC (6 dec) pool -- token0 is WETH
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockUniswapV2Pair wethUsdcPair = new MockUniswapV2Pair(address(weth), address(usdc));

        // WETH feed = $4000, USDC feed = $1
        MockAggregator wethFeed = new MockAggregator(8);
        MockAggregator usdcFeed = new MockAggregator(8);
        wethFeed.setLatestAnswer(4000e8);
        usdcFeed.setLatestAnswer(1e8);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(wethFeed), address(usdcFeed), address(weth), address(usdc), MAX_STALENESS
        );

        // 1000 WETH and 4M USDC
        wethUsdcPair.setReserves(1000e18, 4_000_000e6);
        wethUsdcPair.setTotalSupply(2e18);

        // p1InToken0 = 1e8 * 4000e8 * 1e18 / (4000e8 * 1e8) = 1e18 / 4000 = 2.5e14
        // r1ValueInToken0 = mulDiv(4_000_000e6, 2.5e14, 1e6) = 4e12 * 2.5e14 / 1e6 = 1e21
        // sqrt(1e21 * 1e21) = 1e21
        // PPS = 2 * 1e21 * 1e18 / 2e18 = 1e21
        uint256 pps = localOracle.getPricePerShare(address(wethUsdcPair));
        assertEq(pps, 1e21, "PPS should be 1000 WETH (18-dec) per LP token");
    }

    function test_getPricePerShare_6_6_decimals() public {
        // USDC (6 dec) / USDT (6 dec) pool
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 usdt = new MockERC20("USDT", "USDT", 6);
        MockUniswapV2Pair stablePair = new MockUniswapV2Pair(address(usdc), address(usdt));

        // Both at $1
        MockAggregator usdcFeed = new MockAggregator(8);
        MockAggregator usdtFeed = new MockAggregator(8);
        usdcFeed.setLatestAnswer(1e8);
        usdtFeed.setLatestAnswer(1e8);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(usdcFeed), address(usdtFeed), address(usdc), address(usdt), MAX_STALENESS
        );

        stablePair.setReserves(1000e6, 1000e6);
        stablePair.setTotalSupply(1000e18);

        // p1InToken0 = 1e8 * 1e8 * 1e6 / (1e8 * 1e8) = 1e6
        // r1ValueInToken0 = mulDiv(1000e6, 1e6, 1e6) = 1000e6 = 1e9
        // sqrt(1e9 * 1e9) = 1e9
        // PPS = 2 * 1e9 * 1e18 / 1000e18 = 2e6
        uint256 pps = localOracle.getPricePerShare(address(stablePair));
        assertEq(pps, 2e6, "PPS should be 2 USDC (6-dec) per LP");
    }

    function test_getPricePerShare_8_18_decimals() public {
        // WBTC (8 dec) / WETH (18 dec) pool
        MockERC20 wbtc = new MockERC20("WBTC", "WBTC", 8);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockUniswapV2Pair btcEthPair = new MockUniswapV2Pair(address(wbtc), address(weth));

        // WBTC = $100000, WETH = $4000 -> 1 WETH = 0.04 WBTC
        MockAggregator wbtcFeed = new MockAggregator(8);
        MockAggregator wethFeed = new MockAggregator(8);
        wbtcFeed.setLatestAnswer(100_000e8);
        wethFeed.setLatestAnswer(4000e8);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(wbtcFeed), address(wethFeed), address(wbtc), address(weth), MAX_STALENESS
        );

        // 100 WBTC + 2500 WETH (1 BTC = 25 ETH)
        btcEthPair.setReserves(100e8, 2500e18);
        btcEthPair.setTotalSupply(1e18);

        // p1InToken0 = 4000e8 * 1e8 * 1e8 / (100000e8 * 1e8) = 4e18 * 1e8 / (1e13 * 1e8) = 4e18 / 1e13 = 4e5
        // Wait: mulDiv(4000e8 * 1e8, 1e8, 100000e8 * 1e8)
        //     = mulDiv(4e11 * 1e8, 1e8, 1e13 * 1e8)
        //     = mulDiv(4e19, 1e8, 1e21) = 4e27 / 1e21 = 4e6
        // r1ValueInToken0 = mulDiv(2500e18, 4e6, 1e18) = 2500 * 4e6 = 1e10
        // sqrt(100e8 * 1e10) = sqrt(1e10 * 1e10) = 1e10
        // PPS = 2 * 1e10 * 1e18 / 1e18 = 2e10
        uint256 pps = localOracle.getPricePerShare(address(btcEthPair));
        assertEq(pps, 2e10, "PPS should be 200 WBTC (8-dec) per LP");
    }

    /*//////////////////////////////////////////////////////////////
                    getPricePerShare - EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_revertsOnZeroTotalSupply() public {
        pair.setTotalSupply(0);
        vm.expectRevert(UniV2LPYieldSourceOracle.ZERO_TOTAL_SUPPLY.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_revertsOnInvalidPrice_zeroAnswer() public {
        feed0.setLatestAnswer(0);
        vm.expectRevert(UniV2LPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_zeroReserves_returnsZero() public {
        pair.setReserves(0, 0);
        pair.setTotalSupply(1e18);
        uint256 pps = oracle.getPricePerShare(address(pair));
        assertEq(pps, 0, "PPS should be 0 when reserves are empty");
    }

    /*//////////////////////////////////////////////////////////////
                    getPricePerShare - STALENESS CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_revertsOnStaleFeed0() public {
        // Warp forward past staleness threshold
        feed0.setUpdatedAt(block.timestamp);
        vm.warp(block.timestamp + MAX_STALENESS + 1);

        vm.expectRevert(UniV2LPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_revertsOnStaleFeed1() public {
        // Feed0 is fresh, feed1 is stale
        feed0.setLatestAnswer(1e8); // refreshes updatedAt
        feed1.setUpdatedAt(block.timestamp);
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        feed0.setLatestAnswer(1e8); // refresh feed0 after warp

        vm.expectRevert(UniV2LPYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_succeedsAtExactStalenessThreshold() public {
        feed0.setUpdatedAt(block.timestamp);
        feed1.setUpdatedAt(block.timestamp);
        vm.warp(block.timestamp + MAX_STALENESS);

        // Should NOT revert -- exactly at threshold
        uint256 pps = oracle.getPricePerShare(address(pair));
        assertEq(pps, 2e18);
    }

    /*//////////////////////////////////////////////////////////////
                    getPricePerShare - INVALID PRICE CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_revertsOnZeroAnswerFeed0() public {
        feed0.setLatestAnswer(0);
        vm.expectRevert(UniV2LPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_revertsOnNegativeAnswerFeed0() public {
        feed0.setLatestAnswer(-1);
        vm.expectRevert(UniV2LPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_revertsOnZeroAnswerFeed1() public {
        feed1.setLatestAnswer(0);
        vm.expectRevert(UniV2LPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    function test_getPricePerShare_revertsOnNegativeAnswerFeed1() public {
        feed1.setLatestAnswer(-1);
        vm.expectRevert(UniV2LPYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(pair));
    }

    /*//////////////////////////////////////////////////////////////
                    getPricePerShare - DIFFERENT FEED DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_differentFeedDecimals() public {
        // feed0 = 8 decimals, feed1 = 18 decimals, both at $1
        MockAggregator feed0_8dec = new MockAggregator(8);
        MockAggregator feed1_18dec = new MockAggregator(18);
        feed0_8dec.setLatestAnswer(1e8);
        feed1_18dec.setLatestAnswer(1e18);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(feed0_8dec), address(feed1_18dec), address(token0), address(token1), MAX_STALENESS
        );

        // p1InToken0 = 1e18 * 1e8 * 1e18 / (1e8 * 1e18) = 1e18 (correct 1:1 cross-rate)
        uint256 pps = localOracle.getPricePerShare(address(pair));
        assertEq(pps, 2e18, "PPS should be 2e18 regardless of feed decimal mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                    getPricePerShare - SWAP INVARIANCE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_invariantUnderSwaps() public {
        uint256 ppsBefore = oracle.getPricePerShare(address(pair));

        // After swap: r0=2000e18, r1=500e18, k still = 1e42
        pair.setReserves(2000e18, 500e18);
        uint256 ppsAfter = oracle.getPricePerShare(address(pair));

        assertEq(ppsBefore, ppsAfter, "PPS must be invariant under constant-k swaps");
    }

    function test_getPricePerShare_invariantUnderSwaps_6_18() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        MockUniswapV2Pair usdcWeth = new MockUniswapV2Pair(address(usdc), address(weth));

        MockAggregator usdcFeed = new MockAggregator(8);
        MockAggregator wethFeed = new MockAggregator(8);
        usdcFeed.setLatestAnswer(1e8);
        wethFeed.setLatestAnswer(4000e8);

        UniV2LPYieldSourceOracle localOracle = new UniV2LPYieldSourceOracle(
            ledgerConfig, address(usdcFeed), address(wethFeed), address(usdc), address(weth), MAX_STALENESS
        );

        // Before: 4M USDC + 1000 WETH
        usdcWeth.setReserves(4_000_000e6, 1000e18);
        usdcWeth.setTotalSupply(2e18);
        uint256 ppsBefore = localOracle.getPricePerShare(address(usdcWeth));

        // After swap: 8M USDC + 500 WETH (k constant)
        usdcWeth.setReserves(8_000_000e6, 500e18);
        uint256 ppsAfter = localOracle.getPricePerShare(address(usdcWeth));

        assertEq(ppsBefore, ppsAfter, "PPS must be invariant under constant-k swaps (6/18)");
    }

    /*//////////////////////////////////////////////////////////////
                        getShareOutput
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_basic() public view {
        uint256 shares = oracle.getShareOutput(address(pair), address(0), 10e18);
        assertEq(shares, 5e18, "Should get 5 LP for 10 token0");
    }

    function test_getShareOutput_returnsZeroForZeroInput() public view {
        uint256 shares = oracle.getShareOutput(address(pair), address(0), 0);
        assertEq(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    getWithdrawalShareOutput
    //////////////////////////////////////////////////////////////*/

    function test_getWithdrawalShareOutput_basic() public view {
        uint256 shares = oracle.getWithdrawalShareOutput(address(pair), address(0), 10e18);
        assertEq(shares, 5e18, "Should burn 5 LP to withdraw 10 token0");
    }

    function test_getWithdrawalShareOutput_roundsUp() public {
        pair.setReserves(1001e18, 1000e18);

        oracle.getPricePerShare(address(pair));
        uint256 assetsIn = 3e18;

        uint256 withdrawShares = oracle.getWithdrawalShareOutput(address(pair), address(0), assetsIn);
        uint256 depositShares = oracle.getShareOutput(address(pair), address(0), assetsIn);

        assertGe(withdrawShares, depositShares, "Withdrawal shares should round up");
    }

    function test_getWithdrawalShareOutput_returnsZeroForZeroInput() public view {
        uint256 shares = oracle.getWithdrawalShareOutput(address(pair), address(0), 0);
        assertEq(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        getAssetOutput
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutput_basic() public view {
        uint256 assets = oracle.getAssetOutput(address(pair), address(0), 5e18);
        assertEq(assets, 10e18, "5 LP should be worth 10 token0");
    }

    function test_getAssetOutput_returnsZeroForZeroInput() public view {
        uint256 assets = oracle.getAssetOutput(address(pair), address(0), 0);
        assertEq(assets, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    PPS CONSISTENCY INVARIANT
    //////////////////////////////////////////////////////////////*/

    function test_ppsConsistency() public view {
        uint256 pps = oracle.getPricePerShare(address(pair));
        uint256 assetForOneLp = oracle.getAssetOutput(address(pair), address(0), 1e18);
        assertEq(pps, assetForOneLp, "PPS must equal asset output for 1e18 LP");
    }

    /*//////////////////////////////////////////////////////////////
                    SHARE-ASSET ROUND TRIP
    //////////////////////////////////////////////////////////////*/

    function test_shareAssetRoundTrip_noValueCreation() public view {
        uint256 assetsIn = 100e18;
        uint256 shares = oracle.getShareOutput(address(pair), address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(address(pair), address(0), shares);

        assertLe(assetsOut, assetsIn, "Round trip must not create value");
    }

    /*//////////////////////////////////////////////////////////////
                        getBalanceOfOwner
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner() public view {
        uint256 balance = oracle.getBalanceOfOwner(address(pair), OWNER);
        assertEq(balance, 100e18, "Should return owner's LP balance");
    }

    function test_getBalanceOfOwner_zeroForUnknownUser() public view {
        uint256 balance = oracle.getBalanceOfOwner(address(pair), USER_A);
        assertEq(balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        getTVLByOwnerOfShares
    //////////////////////////////////////////////////////////////*/

    function test_getTVLByOwnerOfShares() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(pair), OWNER);
        assertEq(tvl, 200e18, "TVL should be 200 token0 for 100 LP at PPS=2");
    }

    function test_getTVLByOwnerOfShares_returnsZeroForNoBalance() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(pair), USER_A);
        assertEq(tvl, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            getTVL
    //////////////////////////////////////////////////////////////*/

    function test_getTVL() public view {
        uint256 tvl = oracle.getTVL(address(pair));
        assertEq(tvl, 2000e18, "TVL should be 2000 token0");
    }

    function test_getTVL_returnsZeroForZeroSupply() public {
        pair.setTotalSupply(0);
        uint256 tvl = oracle.getTVL(address(pair));
        assertEq(tvl, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getPricePerShare_noOverflow(uint112 r0, uint112 r1, uint256 price0Raw, uint256 price1Raw) public {
        // Reserves must be large enough so r1ValueInToken0 doesn't truncate to 0
        // after dividing by 1e18 (token1 decimals). Minimum 1e12 provides headroom.
        r0 = uint112(bound(r0, 1e12, type(uint112).max));
        r1 = uint112(bound(r1, 1e12, type(uint112).max));
        // Realistic Chainlink 8-decimal prices: $0.01 to $100k
        // Max ratio = 1e10 / 1e6 = 1e4, well within safe cross-rate range
        price0Raw = bound(price0Raw, 1e6, 1e13);
        price1Raw = bound(price1Raw, 1e6, 1e13);

        pair.setReserves(r0, r1);
        pair.setTotalSupply(1e18);
        feed0.setLatestAnswer(int256(price0Raw));
        feed1.setLatestAnswer(int256(price1Raw));

        // Should not revert
        uint256 pps = oracle.getPricePerShare(address(pair));
        assertGt(pps, 0, "PPS must be positive for non-empty pool");
    }

    function testFuzz_swapInvariance(uint112 r0, uint112 r1, uint256 swapFraction) public {
        r0 = uint112(bound(r0, 1e10, type(uint112).max / 4));
        r1 = uint112(bound(r1, 1e10, type(uint112).max / 4));
        swapFraction = bound(swapFraction, 1, 99);

        pair.setReserves(r0, r1);
        pair.setTotalSupply(1e18);

        uint256 ppsBefore = oracle.getPricePerShare(address(pair));

        // Simulate swap: keep k constant
        uint256 addAmount = (uint256(r0) * swapFraction) / 100;
        uint256 newR0 = uint256(r0) + addAmount;
        uint256 k = uint256(r0) * uint256(r1);
        uint256 newR1 = k / newR0;

        if (newR0 > type(uint112).max || newR1 == 0) return;

        pair.setReserves(uint112(newR0), uint112(newR1));
        uint256 ppsAfter = oracle.getPricePerShare(address(pair));

        assertApproxEqAbs(ppsBefore, ppsAfter, ppsBefore / 1e9, "PPS should be invariant under swaps");
    }

    function testFuzz_shareAssetRoundTrip(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1e30);

        uint256 shares = oracle.getShareOutput(address(pair), address(0), assetsIn);
        if (shares == 0) return;

        uint256 assetsOut = oracle.getAssetOutput(address(pair), address(0), shares);
        assertLe(assetsOut, assetsIn, "Round trip must not create value");
    }
}
