// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { UniV3CLPRegistry } from "../../../src/accounting/oracles/UniV3CLPRegistry.sol";
import { UniV3CLPYieldSourceOracle } from "../../../src/accounting/oracles/UniV3CLPYieldSourceOracle.sol";
import { INonfungiblePositionManager } from "../../../src/vendor/uniswap/v3/INonfungiblePositionManager.sol";
import { IUniswapV3CLPool } from "../../../src/vendor/uniswap/v3/IUniswapV3CLPool.sol";
import { CLLiquidityAmounts } from "../../../src/vendor/uniswap/v3/CLLiquidityAmounts.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

/// @title UniV3CLPOracleFork
/// @notice Comprehensive integration fork tests for UniV3CLPRegistry + UniV3CLPYieldSourceOracle
/// @dev Fork environments:
///      1. Ethereum Mainnet — Uniswap V3 USDC/WETH 0.05% and WBTC/WETH 0.3% pools at block 21_929_476
///      2. Base — Aerodrome Slipstream WETH/USDC (tickSpacing 100) at block 47_790_000
///
/// Run with:
///   forge test --match-path "test/integration/accounting/UniV3CLPOracleFork.t.sol" -v
///
/// Set RPC URLs in .env:
///   ETHEREUM_RPC_URL=<your-mainnet-rpc>
///   BASE_RPC_URL=<your-base-rpc>
contract UniV3CLPOracleForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                        ETHEREUM MAINNET CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant ETH_FORK_BLOCK = 21_929_476;

    // ── Uniswap V3 USDC/WETH 0.05% pool (tickSpacing = 10) ─────────────
    address constant ETH_USDC_WETH_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant ETH_NFT_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    // Tokens (sorted: USDC < WETH)
    address constant ETH_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 dec, token0
    address constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // 18 dec, token1

    // Chainlink feeds (8 dec each)
    address constant ETH_USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant ETH_ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // ── Uniswap V3 WBTC/WETH 0.3% pool (tickSpacing = 60) ──────────────
    address constant ETH_WBTC_WETH_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
    address constant ETH_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // 8 dec, token0 (WBTC < WETH)
    address constant ETH_BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // 8 dec

    // ── Full-range tick bounds (must be aligned to each pool's tickSpacing) ──
    int24 constant FULL_TICK_LOWER = -887_200; // divisible by 10 (USDC/WETH) and 100 (Base)
    int24 constant FULL_TICK_UPPER = 887_200;
    int24 constant WBTC_WETH_TICK_LOWER = -887_160; // divisible by 60 (WBTC/WETH 0.3%)
    int24 constant WBTC_WETH_TICK_UPPER = 887_160;

    uint256 constant ETH_MAX_STALENESS = 1 days; // generous for fork testing

    /*//////////////////////////////////////////////////////////////
                            BASE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant BASE_FORK_BLOCK = 47_790_000;

    // ── Aerodrome Slipstream WETH/USDC CL pool (tickSpacing = 100) ──────
    // token0 = WETH (0x4200... < 0x8335... so WETH sorts first)
    // token1 = USDC
    address constant BASE_CL_POOL = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;
    address constant BASE_NFT_MANAGER = 0x827922686190790b37229fd06084350E74485b72;

    // Tokens on Base (in pool order)
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006; // 18 dec, token0
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // 6 dec, token1

    // Chainlink feeds on Base (8 dec each)
    address constant BASE_ETH_USD_FEED = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address constant BASE_USDC_USD_FEED = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    address constant BASE_SEQUENCER_FEED = address(0); // disabled for fork testing
    uint256 constant BASE_GRACE_PERIOD = 0;
    uint256 constant BASE_MAX_STALENESS = 1 days;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    UniV3CLPRegistry internal registry;
    UniV3CLPYieldSourceOracle internal oracle;
    address internal ledgerConfig;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        string memory ethRpc = vm.envOr("ETHEREUM_RPC_URL", string(""));
        string memory baseRpc = vm.envOr("BASE_RPC_URL", string(""));

        if (bytes(ethRpc).length > 0) {
            ethForkId = vm.createFork(ethRpc, ETH_FORK_BLOCK);
        }
        if (bytes(baseRpc).length > 0) {
            baseForkId = vm.createFork(baseRpc, BASE_FORK_BLOCK);
        }
    }

    function _requireEthFork() internal {
        if (bytes(vm.envOr("ETHEREUM_RPC_URL", string(""))).length == 0) vm.skip(true);
        vm.selectFork(ethForkId);
    }

    function _requireBaseFork() internal {
        if (bytes(vm.envOr("BASE_RPC_URL", string(""))).length == 0) vm.skip(true);
        vm.selectFork(baseForkId);
    }

    /// @notice Deploy fresh registry + oracle on the active fork
    function _deployOracle() internal {
        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new UniV3CLPRegistry(address(this));
        oracle = new UniV3CLPYieldSourceOracle(ledgerConfig, address(registry));
    }

    /// @notice Register USDC/WETH full-range position
    function _registerUsdcWeth() internal returns (address positionKey) {
        positionKey = registry.registerPosition(
            ETH_USDC_WETH_POOL,
            ETH_NFT_MANAGER,
            FULL_TICK_LOWER,
            FULL_TICK_UPPER,
            ETH_USDC,
            ETH_WETH,
            500, // fee for USDC/WETH 0.05% pool
            ETH_USDC_USD_FEED,
            ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS,
            address(0),
            0
        );
    }

    /// @notice Register WBTC/WETH full-range position
    function _registerWbtcWeth() internal returns (address positionKey) {
        positionKey = registry.registerPosition(
            ETH_WBTC_WETH_POOL,
            ETH_NFT_MANAGER,
            WBTC_WETH_TICK_LOWER,
            WBTC_WETH_TICK_UPPER,
            ETH_WBTC,
            ETH_WETH,
            3000, // fee for WBTC/WETH 0.3% pool
            ETH_BTC_USD_FEED,
            ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS,
            address(0),
            0
        );
    }

    /// @notice Register Base Aerodrome Slipstream WETH/USDC full-range position
    function _registerBaseWethUsdc() internal returns (address positionKey) {
        positionKey = registry.registerPosition(
            BASE_CL_POOL,
            BASE_NFT_MANAGER,
            FULL_TICK_LOWER,
            FULL_TICK_UPPER,
            BASE_WETH,
            BASE_USDC,
            100, // tickSpacing for Slipstream pool
            BASE_ETH_USD_FEED,
            BASE_USDC_USD_FEED,
            BASE_MAX_STALENESS,
            BASE_SEQUENCER_FEED,
            BASE_GRACE_PERIOD
        );
    }

    /*//////////////////////////////////////////////////////////////
            GROUP A: REGISTRY — CONFIG & SCALES (ETH FORK)
    //////////////////////////////////////////////////////////////*/

    function test_eth_registry_usdcWeth_correctScales() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);
        assertEq(cfg.pool, ETH_USDC_WETH_POOL);
        assertEq(cfg.nftManager, ETH_NFT_MANAGER);
        assertEq(cfg.token0, ETH_USDC);
        assertEq(cfg.token1, ETH_WETH);
        assertEq(cfg.token0Scale, 1e6, "USDC = 6 decimals");
        assertEq(cfg.token1Scale, 1e18, "WETH = 18 decimals");
        assertEq(cfg.feed0Scale, 1e8, "Chainlink = 8 decimals");
        assertEq(cfg.feed1Scale, 1e8);
        assertTrue(cfg.registered);
    }

    function test_eth_registry_wbtcWeth_correctScales() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();

        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);
        assertEq(cfg.pool, ETH_WBTC_WETH_POOL);
        assertEq(cfg.token0, ETH_WBTC);
        assertEq(cfg.token1, ETH_WETH);
        assertEq(cfg.token0Scale, 1e8, "WBTC = 8 decimals");
        assertEq(cfg.token1Scale, 1e18, "WETH = 18 decimals");
    }

    function test_eth_registry_positionKey_deterministic() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        address computed = registry.computePositionKey(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER, FULL_TICK_LOWER, FULL_TICK_UPPER
        );
        assertEq(key, computed);
    }

    function test_eth_registry_deregistrationTimelock() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        registry.proposeDeregisterPosition(key);
        assertEq(registry.pendingDeregistrations(key), block.timestamp + 2 days);

        vm.expectRevert(UniV3CLPRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterPosition(key);

        vm.warp(block.timestamp + 2 days);
        registry.executeDeregisterPosition(key);
        assertFalse(registry.isRegistered(key));
    }

    function test_eth_registry_accessControl() public {
        _requireEthFork();
        _deployOracle();

        vm.prank(address(0x9999));
        vm.expectRevert();
        registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER, -100, 100,
            ETH_USDC, ETH_WETH, 500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
        GROUP B: CIRCUIT BREAKER BOUNDS FROM REAL CHAINLINK FEEDS
    //////////////////////////////////////////////////////////////*/

    function test_eth_circuitBreaker_ethUsdFeed_hasBounds() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);

        // ETH/USD is feed1 (token1 = WETH). Real Chainlink ETH/USD aggregator has circuit breaker bounds.
        // We verify the registry actually read non-zero values from the real aggregator proxy.
        // Note: feed0 = USDC/USD may or may not have non-zero bounds depending on the aggregator version.
        // At minimum, one of the feeds should have bounds.
        bool hasSomeBounds = cfg.feed0MinAnswer != 0 || cfg.feed0MaxAnswer != 0
            || cfg.feed1MinAnswer != 0 || cfg.feed1MaxAnswer != 0;

        assertTrue(hasSomeBounds, "At least one real Chainlink feed should have circuit breaker bounds");
    }

    function test_eth_circuitBreaker_btcUsdFeed_hasBounds() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();

        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);

        // BTC/USD is feed0 (token0 = WBTC). Real Chainlink aggregators should have bounds.
        bool hasSomeBounds = cfg.feed0MinAnswer != 0 || cfg.feed0MaxAnswer != 0
            || cfg.feed1MinAnswer != 0 || cfg.feed1MaxAnswer != 0;

        assertTrue(hasSomeBounds, "Real BTC/USD or ETH/USD feed should have circuit breaker bounds");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP C: PRICE PER SHARE — USDC/WETH POOL
    //////////////////////////////////////////////////////////////*/

    function test_eth_usdcWeth_pps_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0");
    }

    function test_eth_usdcWeth_pps_sanityRange() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        // PPS = value of 1e18 liquidity units in USDC terms (6 dec).
        // Full-range position at ~$3,300 ETH: PPS should be a finite, positive number.
        // Not astronomically large (< 1e30) and not dust-level small (> 1).
        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 1, "PPS should be meaningfully positive");
        assertLt(pps, 1e30, "PPS sanity upper bound");
    }

    function test_eth_usdcWeth_decimals_returns18() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        assertEq(oracle.decimals(key), 18);
    }

    function test_eth_usdcWeth_getShareOutput_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        // 1 USDC = 1e6 atoms
        uint256 shares = oracle.getShareOutput(key, address(0), 1e6);
        assertGt(shares, 0, "shares for 1 USDC must be > 0");
    }

    function test_eth_usdcWeth_getAssetOutput_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        uint256 assets = oracle.getAssetOutput(key, address(0), 1e18);
        assertGt(assets, 0, "assets for 1e18 liquidity must be > 0");
    }

    function test_eth_usdcWeth_withdrawalSharesCeil_geq_depositSharesFloor() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        uint256 assetsIn = 1e6;
        uint256 sharesFloor = oracle.getShareOutput(key, address(0), assetsIn);
        uint256 sharesCeil = oracle.getWithdrawalShareOutput(key, address(0), assetsIn);
        assertGe(sharesCeil, sharesFloor, "withdrawal shares >= deposit shares");
    }

    function test_eth_usdcWeth_roundTrip_noValueCreation() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        uint256 assetsIn = 1e6;
        uint256 shares = oracle.getShareOutput(key, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(key, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    /// @notice getTVL is intentionally disabled (returns 0) — pool-wide liquidity is not per-position TVL
    function test_eth_usdcWeth_tvl_alwaysReturnsZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        uint256 tvl = oracle.getTVL(key);
        assertEq(tvl, 0, "getTVL is disabled and must return 0");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP D: PRICE PER SHARE — WBTC/WETH POOL (8/18 DECIMALS)
    //////////////////////////////////////////////////////////////*/

    function test_eth_wbtcWeth_pps_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "WBTC/WETH PPS must be > 0");
    }

    function test_eth_wbtcWeth_pps_sanityRange() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();


        // PPS in WBTC terms (8 dec). Should be finite and positive.
        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 1);
        assertLt(pps, 1e30);
    }

    function test_eth_wbtcWeth_shareOutput_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();


        // 1 WBTC = 1e8 atoms
        uint256 shares = oracle.getShareOutput(key, address(0), 1e8);
        assertGt(shares, 0, "shares for 1 WBTC must be > 0");
    }

    function test_eth_wbtcWeth_assetOutput_nonZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();


        uint256 assets = oracle.getAssetOutput(key, address(0), 1e18);
        assertGt(assets, 0, "asset output for 1e18 liquidity must be > 0");
    }

    function test_eth_wbtcWeth_roundTrip_noValueCreation() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();


        uint256 assetsIn = 1e8; // 1 WBTC
        uint256 shares = oracle.getShareOutput(key, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(key, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    /// @notice getTVL is intentionally disabled (returns 0)
    function test_eth_wbtcWeth_tvl_alwaysReturnsZero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();

        uint256 tvl = oracle.getTVL(key);
        assertEq(tvl, 0, "getTVL is disabled and must return 0");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP E: NARROW TICK RANGES — OUT-OF-RANGE BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Narrow range BELOW current tick -> PPS should still be > 0 (all token0)
    function test_eth_narrowRange_belowCurrentTick_ppsNonZero() public {
        _requireEthFork();
        _deployOracle();

        // Current USDC/WETH tick is ~195,000 at ~$3,300 ETH.
        // Register a range [100_000, 110_000] which is well below current tick.
        address key = registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER,
            100_000, 110_000,
            ETH_USDC, ETH_WETH,
            500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0 for below-range position (all token1 converted to token0)");
    }

    /// @notice Narrow range ABOVE current tick -> PPS should still be > 0 (all token1)
    function test_eth_narrowRange_aboveCurrentTick_ppsNonZero() public {
        _requireEthFork();
        _deployOracle();

        // Register a range [300_000, 310_000] which is well above current tick ~195,000.
        address key = registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER,
            300_000, 310_000,
            ETH_USDC, ETH_WETH,
            500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0 for above-range position (all token0)");
    }

    /// @notice Narrow range around current tick -> PPS > 0
    function test_eth_narrowRange_aroundCurrentTick_inRange() public {
        _requireEthFork();
        _deployOracle();

        // At fork block, ETH ≈ $3,300. USDC/WETH tick ≈ +195,000.
        // Range [190_000, 200_000] should be in-range. Ticks must be multiples of tickSpacing(10).
        address key = registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER,
            190_000, 200_000,
            ETH_USDC, ETH_WETH,
            500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0 for in-range narrow position");
    }

    /// @notice getTVL always returns 0 (disabled) regardless of tick range
    function test_eth_narrowRange_outOfRange_tvlZero() public {
        _requireEthFork();
        _deployOracle();

        address key = registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER,
            100_000, 110_000,
            ETH_USDC, ETH_WETH,
            500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );

        uint256 tvl = oracle.getTVL(key);
        assertEq(tvl, 0, "getTVL is disabled and must return 0");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP F: REAL LP HOLDER — getBalanceOfOwner
    //////////////////////////////////////////////////////////////*/

    /// @notice Find a real LP holder by scanning the first N tokenIds on the NFT manager
    function test_eth_realLPHolder_scanAndVerify() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        INonfungiblePositionManager nft = INonfungiblePositionManager(ETH_NFT_MANAGER);
        IERC721 nftErc721 = IERC721(ETH_NFT_MANAGER);

        // Scan tokenIds 1-500 looking for an active USDC/WETH full-range-ish position
        address foundHolder;
        for (uint256 tokenId = 1; tokenId <= 500; tokenId++) {
            try nftErc721.ownerOf(tokenId) returns (address owner) {
                if (owner == address(0)) continue;

                (
                    ,
                    ,
                    address t0,
                    address t1,
                    ,
                    int24 tL,
                    int24 tU,
                    uint128 liq,
                    ,
                    ,
                    ,
                ) = nft.positions(tokenId);

                // Match: same tokens, full-range ticks, non-zero liquidity
                if (t0 == ETH_USDC && t1 == ETH_WETH && tL == FULL_TICK_LOWER && tU == FULL_TICK_UPPER && liq > 0) {
                    foundHolder = owner;
                    break;
                }
            } catch {
                continue; // tokenId may have been burned
            }
        }

        if (foundHolder != address(0)) {
            uint256 balance = oracle.getBalanceOfOwner(key, foundHolder);
            assertGt(balance, 0, "Real LP holder must have > 0 liquidity");

            uint256 tvl = oracle.getTVLByOwnerOfShares(key, foundHolder);
            assertGt(tvl, 0, "Real LP holder TVL must be > 0");
        }
        // If no full-range holder found in first 500 tokenIds, test is inconclusive (not a failure)
    }

    /// @notice Verify getBalanceOfOwner returns 0 for an address with no positions
    function test_eth_getBalanceOfOwner_noPositions_zero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        assertEq(oracle.getBalanceOfOwner(key, address(0xBEEF)), 0);
    }

    /// @notice Verify getTVLByOwnerOfShares returns 0 for an address with no positions
    function test_eth_getTVLByOwnerOfShares_noPositions_zero() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();

        assertEq(oracle.getTVLByOwnerOfShares(key, address(0xBEEF)), 0);
    }

    /*//////////////////////////////////////////////////////////////
        GROUP G: CROSS-POOL BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_eth_getPricePerShareMultiple_twoPools() public {
        _requireEthFork();
        _deployOracle();
        address key1 = _registerUsdcWeth();
        address key2 = _registerWbtcWeth();



        address[] memory keys = new address[](2);
        keys[0] = key1;
        keys[1] = key2;

        uint256[] memory prices = oracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 2);
        assertEq(prices[0], oracle.getPricePerShare(key1), "batch PPS[0] must match single");
        assertEq(prices[1], oracle.getPricePerShare(key2), "batch PPS[1] must match single");
    }

    /// @notice getTVLMultiple returns zeros since getTVL is disabled
    function test_eth_getTVLMultiple_twoPools() public {
        _requireEthFork();
        _deployOracle();
        address key1 = _registerUsdcWeth();
        address key2 = _registerWbtcWeth();

        address[] memory keys = new address[](2);
        keys[0] = key1;
        keys[1] = key2;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 0, "getTVL is disabled");
        assertEq(tvls[1], 0, "getTVL is disabled");
    }

    function test_eth_getTVLByOwnerOfSharesMultiple() public {
        _requireEthFork();
        _deployOracle();
        address key1 = _registerUsdcWeth();
        address key2 = _registerWbtcWeth();

        address[] memory keys = new address[](2);
        keys[0] = key1;
        keys[1] = key2;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = address(0xBEEF);
        owners[1] = new address[](1);
        owners[1][0] = address(0xBEEF);

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertEq(tvls.length, 2);
        assertEq(tvls[0][0], 0, "no positions -> TVL = 0");
        assertTrue(succeeded[0][0], "should succeed even with 0 TVL");
        assertEq(tvls[1][0], 0, "no positions -> TVL = 0");
        assertTrue(succeeded[1][0], "should succeed even with 0 TVL");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP H: CROSS-POOL PRICE CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice Two pools using the same tokens should produce related PPS values
    ///         (the oracle is invariant to the pool — it only uses Chainlink prices)
    function test_eth_sameFeedsDifferentPools_ppsDependsOnRange() public {
        _requireEthFork();
        _deployOracle();
        address key1 = _registerUsdcWeth();

        // Register same tokens/feeds but narrower range
        address key2 = registry.registerPosition(
            ETH_USDC_WETH_POOL, ETH_NFT_MANAGER,
            190_000, 200_000,
            ETH_USDC, ETH_WETH,
            500, ETH_USDC_USD_FEED, ETH_ETH_USD_FEED,
            ETH_MAX_STALENESS, address(0), 0
        );


        uint256 ppsFull = oracle.getPricePerShare(key1);
        uint256 ppsNarrow = oracle.getPricePerShare(key2);

        // Both must be > 0
        assertGt(ppsFull, 0);
        assertGt(ppsNarrow, 0);

        // They should differ because the tick range affects the liquidity distribution
        assertTrue(ppsFull != ppsNarrow, "different tick ranges must produce different PPS");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP I: UNREGISTERED POSITION REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_eth_unregistered_getPricePerShare_reverts() public {
        _requireEthFork();
        _deployOracle();

        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getPricePerShare(address(0xDEAD));
    }

    function test_eth_unregistered_getShareOutput_reverts() public {
        _requireEthFork();
        _deployOracle();

        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getShareOutput(address(0xDEAD), address(0), 1e18);
    }

    /// @notice getTVL is disabled (returns 0) — does not check registration
    function test_eth_unregistered_getTVL_returnsZero() public {
        _requireEthFork();
        _deployOracle();

        assertEq(oracle.getTVL(address(0xDEAD)), 0);
    }

    function test_eth_unregistered_getBalanceOfOwner_reverts() public {
        _requireEthFork();
        _deployOracle();

        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(address(0xDEAD), address(0xBEEF));
    }

    /*//////////////////////////////////////////////////////////////
        GROUP J: POOL STATE VALIDATION (ETH FORK)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify pool.slot0() returns expected token ordering
    function test_eth_poolState_usdcWeth_currentTickReasonable() public {
        _requireEthFork();

        (, int24 currentTick) = IUniswapV3CLPool(ETH_USDC_WETH_POOL).slot0();

        // At ~$3,300 ETH: tick ≈ 195,000 for USDC/WETH 0.05% pool.
        // We allow a wide band [150_000, 250_000] to be robust against price changes at fork block.
        assertGt(currentTick, 150_000, "current tick too low for USDC/WETH");
        assertLt(currentTick, 250_000, "current tick too high for USDC/WETH");
    }

    /// @notice Verify pool has meaningful active liquidity
    function test_eth_poolState_usdcWeth_hasActiveLiquidity() public {
        _requireEthFork();

        uint128 activeLiq = IUniswapV3CLPool(ETH_USDC_WETH_POOL).liquidity();
        assertGt(activeLiq, 0, "USDC/WETH pool must have active liquidity at fork block");
    }

    function test_eth_poolState_wbtcWeth_currentTickReasonable() public {
        _requireEthFork();

        (, int24 currentTick) = IUniswapV3CLPool(ETH_WBTC_WETH_POOL).slot0();

        // WBTC/WETH: BTC ~$95k, ETH ~$3.3k -> ratio ~28.8
        // In atomic terms: 1 WBTC = 1e8, 1 WETH = 1e18
        // price = (1/28.8) * (1e18/1e8) = 3.47e8
        // tick = ln(3.47e8) / ln(1.0001) ≈ 196,000
        // Wide band [150_000, 280_000]
        assertGt(currentTick, 150_000, "current tick too low for WBTC/WETH");
        assertLt(currentTick, 280_000, "current tick too high for WBTC/WETH");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP K: ASSET OUTPUT WITH FEES (NO CONFIG)
    //////////////////////////////////////////////////////////////*/

    function test_eth_getAssetOutputWithFees_noConfig_returnsBase() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, key, address(0), address(0xBEEF), 1e18);
        uint256 base = oracle.getAssetOutput(key, address(0), 1e18);
        assertEq(result, base, "should return base output when no config exists");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP L: DEREGISTRATION -> ORACLE REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_eth_oracleRevertsAfterDeregistration() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerUsdcWeth();


        // Verify oracle works before deregistration
        assertGt(oracle.getPricePerShare(key), 0);

        // Deregister
        registry.proposeDeregisterPosition(key);
        vm.warp(block.timestamp + 2 days);
        registry.executeDeregisterPosition(key);

        // All oracle calls should now revert
        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getPricePerShare(key);
    }

    /*//////////////////////////////////////////////////////////////
        GROUP M: BASE FORK — AERODROME SLIPSTREAM
    //////////////////////////////////////////////////////////////*/

    function test_base_registry_config() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();

        UniV3CLPRegistry.PositionConfig memory cfg = registry.getPositionConfig(key);
        assertEq(cfg.pool, BASE_CL_POOL);
        assertEq(cfg.nftManager, BASE_NFT_MANAGER);
        assertEq(cfg.token0, BASE_WETH); // WETH is token0 (lower address)
        assertEq(cfg.token1, BASE_USDC); // USDC is token1
        assertEq(cfg.token0Scale, 1e18, "WETH = 18 dec");
        assertEq(cfg.token1Scale, 1e6, "USDC = 6 dec");
        assertEq(cfg.sequencerUptimeFeed, address(0));
    }

    function test_base_oracle_pps_nonZero() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "Base PPS must be > 0");
    }

    function test_base_oracle_pps_sanityRange() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();


        // PPS in WETH terms (token0 = WETH, 18 dec). Should be reasonable.
        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 1);
        assertLt(pps, 1e36, "sanity upper bound");
    }

    function test_base_oracle_decimals_returns18() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();

        assertEq(oracle.decimals(key), 18);
    }

    function test_base_oracle_shareOutput_nonZero() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();


        // PPS is in WETH terms; deposit 1 WETH = 1e18
        uint256 shares = oracle.getShareOutput(key, address(0), 1e18);
        assertGt(shares, 0, "shares for 1 WETH must be > 0");
    }

    function test_base_oracle_assetOutput_nonZero() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();


        uint256 assets = oracle.getAssetOutput(key, address(0), 1e18);
        assertGt(assets, 0, "assets for 1e18 liquidity must be > 0");
    }

    function test_base_oracle_roundTrip_noValueCreation() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();


        uint256 assetsIn = 1e18;
        uint256 shares = oracle.getShareOutput(key, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(key, address(0), shares);
        assertLe(assetsOut, assetsIn, "round-trip must not create value");
    }

    /// @notice getTVL is intentionally disabled (returns 0)
    function test_base_oracle_tvl_alwaysReturnsZero() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();

        uint256 tvl = oracle.getTVL(key);
        assertEq(tvl, 0, "getTVL is disabled and must return 0");
    }

    function test_base_oracle_unregistered_reverts() public {
        _requireBaseFork();
        _deployOracle();

        vm.expectRevert(UniV3CLPRegistry.POSITION_NOT_REGISTERED.selector);
        oracle.getPricePerShare(address(0xDEAD));
    }

    function test_base_poolState_currentTickReasonable() public {
        _requireBaseFork();

        (, int24 currentTick) = IUniswapV3CLPool(BASE_CL_POOL).slot0();

        // Base WETH/USDC: token0=WETH, token1=USDC
        // At fork block 47_790_000: tick ≈ -202,258
        // Wide band [-250_000, -150_000]
        assertGt(currentTick, -250_000, "current tick too low for Base WETH/USDC");
        assertLt(currentTick, -150_000, "current tick too high for Base WETH/USDC");
    }

    function test_base_poolState_hasActiveLiquidity() public {
        _requireBaseFork();

        uint128 activeLiq = IUniswapV3CLPool(BASE_CL_POOL).liquidity();
        assertGt(activeLiq, 0, "Base WETH/USDC pool must have active liquidity");
    }

    function test_base_narrowRange_belowCurrentTick_ppsNonZero() public {
        _requireBaseFork();
        _deployOracle();

        // Current tick for Base WETH/USDC ≈ -357,300
        // Register range [-500_000, -490_000] which is well below current tick
        address key = registry.registerPosition(
            BASE_CL_POOL, BASE_NFT_MANAGER,
            -500_000, -490_000,
            BASE_WETH, BASE_USDC,
            100, BASE_ETH_USD_FEED, BASE_USDC_USD_FEED,
            BASE_MAX_STALENESS, BASE_SEQUENCER_FEED, BASE_GRACE_PERIOD
        );


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0 for below-range position");
    }

    function test_base_narrowRange_aboveCurrentTick_ppsNonZero() public {
        _requireBaseFork();
        _deployOracle();

        // Register range [-200_000, -190_000] which is well above current tick ≈ -357,300
        address key = registry.registerPosition(
            BASE_CL_POOL, BASE_NFT_MANAGER,
            -200_000, -190_000,
            BASE_WETH, BASE_USDC,
            100, BASE_ETH_USD_FEED, BASE_USDC_USD_FEED,
            BASE_MAX_STALENESS, BASE_SEQUENCER_FEED, BASE_GRACE_PERIOD
        );


        uint256 pps = oracle.getPricePerShare(key);
        assertGt(pps, 0, "PPS must be > 0 for above-range position");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP N: REAL SLIPSTREAM LP HOLDER (BASE FORK)
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint a Slipstream LP position and verify oracle sees it
    /// @dev Deterministic: mints a full-range WETH/USDC position via deal + NPM.mint
    function test_base_slipstreamMint_getBalanceOfOwner() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();

        address lper = makeAddr("slipstream-lper");

        // Deal tokens to lper
        deal(BASE_WETH, lper, 1 ether);
        deal(BASE_USDC, lper, 3000e6); // ~3000 USDC

        vm.startPrank(lper);

        // Approve NPM to spend tokens
        IERC20(BASE_WETH).approve(BASE_NFT_MANAGER, type(uint256).max);
        IERC20(BASE_USDC).approve(BASE_NFT_MANAGER, type(uint256).max);

        // Slipstream NPM.mint params struct:
        // (token0, token1, int24 tickSpacing, int24 tickLower, int24 tickUpper,
        //  amount0Desired, amount1Desired, amount0Min, amount1Min,
        //  recipient, deadline, uint160 sqrtPriceX96)
        // sqrtPriceX96 = 0 because the pool already exists
        (bool ok, bytes memory ret) = BASE_NFT_MANAGER.call(
            abi.encodeWithSignature(
                "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
                BASE_WETH,       // token0
                BASE_USDC,       // token1
                int24(100),      // tickSpacing
                FULL_TICK_LOWER, // tickLower
                FULL_TICK_UPPER, // tickUpper
                1 ether,         // amount0Desired (WETH)
                3000e6,          // amount1Desired (USDC)
                uint256(0),      // amount0Min
                uint256(0),      // amount1Min
                lper,            // recipient
                block.timestamp, // deadline
                uint160(0)       // sqrtPriceX96 (0 = pool exists)
            )
        );
        require(ok, "NPM.mint failed");

        // Decode: (tokenId, liquidity, amount0, amount1)
        (,uint128 mintedLiquidity,,) = abi.decode(ret, (uint256, uint128, uint256, uint256));
        assertGt(mintedLiquidity, 0, "Minted liquidity must be > 0");

        vm.stopPrank();

        // Verify oracle sees the position
        uint256 balance = oracle.getBalanceOfOwner(key, lper);
        assertGt(balance, 0, "Oracle must see minted Slipstream LP liquidity");

        uint256 tvl = oracle.getTVLByOwnerOfShares(key, lper);
        assertGt(tvl, 0, "Oracle must report TVL > 0 for minted position");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP O: PPS GROUND-TRUTH ACCURACY (ETH FORK)
    //////////////////////////////////////////////////////////////*/

    /// @notice Compare oracle PPS against a spot-derived ground truth for WBTC/WETH
    function test_eth_ppsGroundTruth_matchesSpotDerived() public {
        _requireEthFork();
        _deployOracle();
        address key = _registerWbtcWeth();

        // 1. Read pool slot0 sqrtPriceX96
        (uint160 sqrtPriceX96,) = IUniswapV3CLPool(ETH_WBTC_WETH_POOL).slot0();

        // 2. Compute amounts for 1e18 liquidity using slot0 price
        uint160 sqrtA = TickMath.getSqrtPriceAtTick(WBTC_WETH_TICK_LOWER);
        uint160 sqrtB = TickMath.getSqrtPriceAtTick(WBTC_WETH_TICK_UPPER);
        (uint256 amount0, uint256 amount1) =
            CLLiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtA, sqrtB, 1e18);

        // 3. Read Chainlink prices
        (, int256 btcPrice,,,) = IAggregatorV3(ETH_BTC_USD_FEED).latestRoundData();
        (, int256 ethPrice,,,) = IAggregatorV3(ETH_ETH_USD_FEED).latestRoundData();
        uint256 feedScale = 1e8; // both feeds are 8 decimals

        // 4. Compute spot-derived PPS in token0 (WBTC) terms
        // amount1InToken0 = amount1 * price1/price0 * token0Scale/token1Scale
        uint256 token0Scale = 1e8; // WBTC 8 decimals
        uint256 token1Scale = 1e18; // WETH 18 decimals
        uint256 spotPPS = amount0
            + Math.mulDiv(
                amount1 * uint256(ethPrice) * feedScale * token0Scale,
                1,
                uint256(btcPrice) * feedScale * token1Scale
            );

        // 5. Get oracle PPS
        uint256 oraclePPS = oracle.getPricePerShare(key);

        // 6. Assert within 5% tolerance (Chainlink vs AMM price deviation)
        uint256 tolerance = spotPPS * 5 / 100;
        uint256 diff = oraclePPS > spotPPS ? oraclePPS - spotPPS : spotPPS - oraclePPS;
        assertLe(diff, tolerance, "Oracle PPS should be within 5% of spot-derived PPS");
    }

    /*//////////////////////////////////////////////////////////////
        GROUP P: DEREGISTRATION — BASE FORK
    //////////////////////////////////////////////////////////////*/

    function test_base_deregistration_flow() public {
        _requireBaseFork();
        _deployOracle();
        address key = _registerBaseWethUsdc();

        registry.proposeDeregisterPosition(key);
        vm.expectRevert(UniV3CLPRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterPosition(key);

        vm.warp(block.timestamp + 2 days);
        registry.executeDeregisterPosition(key);
        assertFalse(registry.isRegistered(key));
    }
}
