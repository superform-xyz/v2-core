// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { UniV2LPYieldSourceOracle } from "../../../src/accounting/oracles/UniV2LPYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IUniswapV2Pair } from "../../../src/vendor/uniswap/IUniswapV2Pair.sol";

import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";

/// @dev Extended interface for mint/burn/swap (not in IUniswapV2Pair)
interface IUniswapV2PairFull {
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

/// @title UniV2LPYieldSourceOracleFork
/// @notice Fork tests for UniV2LPYieldSourceOracle against real Ethereum mainnet state.
///         Validates the oracle against three Uniswap V2 pairs with different decimal combinations:
///         - USDC/WETH (6/18) — high TVL, uncorrelated
///         - DAI/USDC  (18/6) — stablecoin pair, primary use case
///         - WBTC/WETH (8/18) — blue chip, tests decimal handling
///
/// @dev Run with: forge test --match-contract UniV2LPYieldSourceOracleFork -vv
contract UniV2LPYieldSourceOracleFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant FORK_BLOCK = 21_929_476;
    uint256 constant MAX_STALENESS = 86_400; // 24h — generous for historical block

    // --- USDC/WETH pair (token0=USDC 6 dec, token1=WETH 18 dec) ---
    address constant USDC_WETH_PAIR = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // --- DAI/USDC pair (token0=DAI 18 dec, token1=USDC 6 dec) ---
    address constant DAI_USDC_PAIR = 0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant DAI_USD_FEED = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

    // --- WBTC/WETH pair (token0=WBTC 8 dec, token1=WETH 18 dec) ---
    address constant WBTC_WETH_PAIR = 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    UniV2LPYieldSourceOracle public oracleUsdcWeth;
    UniV2LPYieldSourceOracle public oracleDaiUsdc;
    UniV2LPYieldSourceOracle public oracleWbtcWeth;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        address cfg = address(ledgerConfig);

        // USDC/WETH: token0=USDC, token1=WETH
        oracleUsdcWeth = new UniV2LPYieldSourceOracle(cfg, USDC_USD_FEED, ETH_USD_FEED, USDC, WETH, MAX_STALENESS);

        // DAI/USDC: token0=DAI, token1=USDC
        oracleDaiUsdc = new UniV2LPYieldSourceOracle(cfg, DAI_USD_FEED, USDC_USD_FEED, DAI, USDC, MAX_STALENESS);

        // WBTC/WETH: token0=WBTC, token1=WETH
        oracleWbtcWeth = new UniV2LPYieldSourceOracle(cfg, BTC_USD_FEED, ETH_USD_FEED, WBTC, WETH, MAX_STALENESS);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 1: USDC/WETH (6/18 decimals)
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must be positive for the USDC/WETH pair
    function test_fork_usdcWeth_pps_nonZero() public view {
        uint256 pps = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertGt(pps, 0, "USDC/WETH PPS must be > 0");
    }

    /// @notice PPS sanity range: each LP token should be worth between $100 and $10B in USDC terms
    /// @dev At fork block, pool has ~$30M TVL and ~3e15 totalSupply, so PPS ≈ 1e7 USDC (6-dec)
    function test_fork_usdcWeth_pps_sanityRange() public view {
        uint256 pps = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        // PPS in 6-decimal USDC terms; each LP token worth $100–$10B
        assertGt(pps, 100e6, "USDC/WETH PPS too low (< $100)");
        assertLt(pps, 10_000_000_000e6, "USDC/WETH PPS too high (> $10B)");
    }

    /// @notice TVL must be positive
    function test_fork_usdcWeth_tvl_nonZero() public view {
        uint256 tvl = oracleUsdcWeth.getTVL(USDC_WETH_PAIR);
        assertGt(tvl, 0, "USDC/WETH TVL must be > 0");
    }

    /// @notice PPS must equal getAssetOutput for 1 full LP token (1e18)
    function test_fork_usdcWeth_ppsConsistency() public view {
        uint256 pps = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        uint256 assetForOneLp = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), 1e18);
        assertEq(pps, assetForOneLp, "USDC/WETH: PPS must equal getAssetOutput(1e18)");
    }

    /// @notice Round-trip: getAssetOutput(getShareOutput(assets)) <= assets (no value creation)
    function test_fork_usdcWeth_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 1_000_000e6; // 1M USDC
        uint256 shares = oracleUsdcWeth.getShareOutput(USDC_WETH_PAIR, address(0), assetsIn);
        uint256 assetsOut = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "USDC/WETH: round trip must not create value");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 2: DAI/USDC (18/6 decimals)
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must be positive for the DAI/USDC pair
    function test_fork_daiUsdc_pps_nonZero() public view {
        uint256 pps = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        assertGt(pps, 0, "DAI/USDC PPS must be > 0");
    }

    /// @notice PPS sanity range: stablecoin pair, PPS denominated in DAI (18-dec)
    /// @dev For a stablecoin pair, PPS ≈ 2 * sqrt(r0 * r1) / totalSupply in token0 terms
    function test_fork_daiUsdc_pps_sanityRange() public view {
        uint256 pps = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        // Each LP token in 18-decimal DAI terms; worth between $0.01 and $1T
        assertGt(pps, 1e16, "DAI/USDC PPS too low (< 0.01 DAI)");
        assertLt(pps, 1e30, "DAI/USDC PPS too high (> 1T DAI)");
    }

    /// @notice TVL must be positive
    function test_fork_daiUsdc_tvl_nonZero() public view {
        uint256 tvl = oracleDaiUsdc.getTVL(DAI_USDC_PAIR);
        assertGt(tvl, 0, "DAI/USDC TVL must be > 0");
    }

    /// @notice PPS must equal getAssetOutput for 1 full LP token (1e18)
    function test_fork_daiUsdc_ppsConsistency() public view {
        uint256 pps = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        uint256 assetForOneLp = oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), 1e18);
        assertEq(pps, assetForOneLp, "DAI/USDC: PPS must equal getAssetOutput(1e18)");
    }

    /// @notice Round-trip: getAssetOutput(getShareOutput(assets)) <= assets (no value creation)
    function test_fork_daiUsdc_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 1_000_000e18; // 1M DAI
        uint256 shares = oracleDaiUsdc.getShareOutput(DAI_USDC_PAIR, address(0), assetsIn);
        uint256 assetsOut = oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "DAI/USDC: round trip must not create value");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 3: WBTC/WETH (8/18 decimals)
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must be positive for the WBTC/WETH pair
    function test_fork_wbtcWeth_pps_nonZero() public view {
        uint256 pps = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        assertGt(pps, 0, "WBTC/WETH PPS must be > 0");
    }

    /// @notice PPS sanity range: denominated in WBTC (8-dec)
    function test_fork_wbtcWeth_pps_sanityRange() public view {
        uint256 pps = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        // Each LP token in 8-decimal WBTC terms; worth between 0.001 BTC and 1B BTC
        assertGt(pps, 1e5, "WBTC/WETH PPS too low (< 0.001 BTC)");
        assertLt(pps, 1e17, "WBTC/WETH PPS too high (> 1B BTC)");
    }

    /// @notice TVL must be positive
    function test_fork_wbtcWeth_tvl_nonZero() public view {
        uint256 tvl = oracleWbtcWeth.getTVL(WBTC_WETH_PAIR);
        assertGt(tvl, 0, "WBTC/WETH TVL must be > 0");
    }

    /// @notice PPS must equal getAssetOutput for 1 full LP token (1e18)
    function test_fork_wbtcWeth_ppsConsistency() public view {
        uint256 pps = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        uint256 assetForOneLp = oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), 1e18);
        assertEq(pps, assetForOneLp, "WBTC/WETH: PPS must equal getAssetOutput(1e18)");
    }

    /// @notice Round-trip: getAssetOutput(getShareOutput(assets)) <= assets (no value creation)
    function test_fork_wbtcWeth_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 100e8; // 100 WBTC
        uint256 shares = oracleWbtcWeth.getShareOutput(WBTC_WETH_PAIR, address(0), assetsIn);
        uint256 assetsOut = oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "WBTC/WETH: round trip must not create value");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 4: CROSS-PAIR TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice All LP pairs must return 18 decimals (UniV2 standard)
    function test_fork_decimals_always18() public view {
        assertEq(oracleUsdcWeth.decimals(USDC_WETH_PAIR), 18, "USDC/WETH decimals must be 18");
        assertEq(oracleDaiUsdc.decimals(DAI_USDC_PAIR), 18, "DAI/USDC decimals must be 18");
        assertEq(oracleWbtcWeth.decimals(WBTC_WETH_PAIR), 18, "WBTC/WETH decimals must be 18");
    }

    /// @notice getWithdrawalShareOutput (ceil) >= getShareOutput (floor) for same input
    function test_fork_ceilRounding() public view {
        // Test on DAI/USDC (stablecoin pair — most likely to surface rounding diffs)
        uint256 assetsIn = 1_000_000e18; // 1M DAI
        uint256 depositShares = oracleDaiUsdc.getShareOutput(DAI_USDC_PAIR, address(0), assetsIn);
        uint256 withdrawShares = oracleDaiUsdc.getWithdrawalShareOutput(DAI_USDC_PAIR, address(0), assetsIn);
        assertGe(withdrawShares, depositShares, "Ceil rounding: withdrawal shares >= deposit shares");
    }

    /// @notice getBalanceOfOwner returns 0 for a random address with no LP tokens
    function test_fork_balanceOfOwner_zeroForRandomAddress() public view {
        address nobody = address(0xdeAD0000DEAd0000DEAd0000DEad0000DeAd0000);
        assertEq(oracleUsdcWeth.getBalanceOfOwner(USDC_WETH_PAIR, nobody), 0, "USDC/WETH balance 0 for nobody");
        assertEq(oracleDaiUsdc.getBalanceOfOwner(DAI_USDC_PAIR, nobody), 0, "DAI/USDC balance 0 for nobody");
        assertEq(oracleWbtcWeth.getBalanceOfOwner(WBTC_WETH_PAIR, nobody), 0, "WBTC/WETH balance 0 for nobody");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 5: getPricePerShareMultiple
    //////////////////////////////////////////////////////////////*/

    /// @notice Batch PPS must match individual PPS calls for each pair
    function test_fork_getPricePerShareMultiple_consistency() public view {
        // Test each oracle's batch vs single call
        address[] memory vaults = new address[](1);

        vaults[0] = USDC_WETH_PAIR;
        uint256[] memory prices = oracleUsdcWeth.getPricePerShareMultiple(vaults);
        assertEq(prices[0], oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR), "USDC/WETH batch must match single");

        vaults[0] = DAI_USDC_PAIR;
        prices = oracleDaiUsdc.getPricePerShareMultiple(vaults);
        assertEq(prices[0], oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR), "DAI/USDC batch must match single");

        vaults[0] = WBTC_WETH_PAIR;
        prices = oracleWbtcWeth.getPricePerShareMultiple(vaults);
        assertEq(prices[0], oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR), "WBTC/WETH batch must match single");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 6: TVL BY OWNER
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVLByOwnerOfShares returns 0 for address with no LP tokens
    function test_fork_tvlByOwner_zeroForRandomAddress() public view {
        address nobody = address(0xdeAD0000DEAd0000DEAd0000DEad0000DeAd0000);
        assertEq(oracleUsdcWeth.getTVLByOwnerOfShares(USDC_WETH_PAIR, nobody), 0);
        assertEq(oracleDaiUsdc.getTVLByOwnerOfShares(DAI_USDC_PAIR, nobody), 0);
        assertEq(oracleWbtcWeth.getTVLByOwnerOfShares(WBTC_WETH_PAIR, nobody), 0);
    }

    /*//////////////////////////////////////////////////////////////
                SECTION 7: ADD / REMOVE LIQUIDITY — PPS INVARIANCE
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must remain approximately unchanged after proportional add liquidity (USDC/WETH)
    /// @dev Tiny drift (~1e-11 relative) is expected from UniV2 mint integer rounding
    function test_fork_usdcWeth_pps_unchangedAfterAddLiquidity() public {
        uint256 ppsBefore = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        _addLiquidity(USDC_WETH_PAIR, USDC, WETH);

        uint256 ppsAfter = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "USDC/WETH: PPS drift > 0.0001% after add liquidity");
    }

    /// @notice PPS must remain approximately unchanged after remove liquidity (USDC/WETH)
    function test_fork_usdcWeth_pps_unchangedAfterRemoveLiquidity() public {
        uint256 ppsBefore = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        _removeLiquidity(USDC_WETH_PAIR);

        uint256 ppsAfter = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "USDC/WETH: PPS drift > 0.0001% after remove liquidity");
    }

    /// @notice PPS must remain approximately unchanged after proportional add liquidity (DAI/USDC)
    function test_fork_daiUsdc_pps_unchangedAfterAddLiquidity() public {
        uint256 ppsBefore = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);

        _addLiquidity(DAI_USDC_PAIR, DAI, USDC);

        uint256 ppsAfter = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "DAI/USDC: PPS drift > 0.0001% after add liquidity");
    }

    /// @notice PPS must remain approximately unchanged after remove liquidity (DAI/USDC)
    function test_fork_daiUsdc_pps_unchangedAfterRemoveLiquidity() public {
        uint256 ppsBefore = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);

        _removeLiquidity(DAI_USDC_PAIR);

        uint256 ppsAfter = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "DAI/USDC: PPS drift > 0.0001% after remove liquidity");
    }

    /// @notice PPS must remain approximately unchanged after proportional add liquidity (WBTC/WETH)
    function test_fork_wbtcWeth_pps_unchangedAfterAddLiquidity() public {
        uint256 ppsBefore = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);

        _addLiquidity(WBTC_WETH_PAIR, WBTC, WETH);

        uint256 ppsAfter = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "WBTC/WETH: PPS drift > 0.0001% after add liquidity");
    }

    /// @notice PPS must remain approximately unchanged after remove liquidity (WBTC/WETH)
    function test_fork_wbtcWeth_pps_unchangedAfterRemoveLiquidity() public {
        uint256 ppsBefore = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);

        _removeLiquidity(WBTC_WETH_PAIR);

        uint256 ppsAfter = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "WBTC/WETH: PPS drift > 0.0001% after remove liquidity");
    }

    /// @notice TVL must increase after add liquidity and decrease after remove liquidity
    function test_fork_usdcWeth_tvl_changesWithLiquidity() public {
        uint256 tvlBefore = oracleUsdcWeth.getTVL(USDC_WETH_PAIR);

        _addLiquidity(USDC_WETH_PAIR, USDC, WETH);

        uint256 tvlAfterAdd = oracleUsdcWeth.getTVL(USDC_WETH_PAIR);
        assertGt(tvlAfterAdd, tvlBefore, "TVL must increase after add liquidity");

        _removeLiquidity(USDC_WETH_PAIR);

        uint256 tvlAfterRemove = oracleUsdcWeth.getTVL(USDC_WETH_PAIR);
        assertLt(tvlAfterRemove, tvlAfterAdd, "TVL must decrease after remove liquidity");
    }

    /// @notice User TVL via getBalanceOfOwner + getAssetOutput must reflect LP received from add
    function test_fork_usdcWeth_userTvl_afterAddLiquidity() public {
        address lp = address(0xBEEF);

        // Add liquidity and receive LP tokens
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(USDC_WETH_PAIR).getReserves();
        uint256 totalSupply = IUniswapV2Pair(USDC_WETH_PAIR).totalSupply();

        // Add 1% of reserves
        uint256 amount0 = uint256(r0) / 100;
        uint256 amount1 = uint256(r1) / 100;

        deal(USDC, USDC_WETH_PAIR, IERC20(USDC).balanceOf(USDC_WETH_PAIR) + amount0);
        deal(WETH, USDC_WETH_PAIR, IERC20(WETH).balanceOf(USDC_WETH_PAIR) + amount1);
        uint256 lpReceived = IUniswapV2PairFull(USDC_WETH_PAIR).mint(lp);

        assertGt(lpReceived, 0, "must receive LP tokens");
        assertEq(
            oracleUsdcWeth.getBalanceOfOwner(USDC_WETH_PAIR, lp), lpReceived, "oracle balance must match LP received"
        );

        // User TVL should approximate the value deposited
        uint256 userTvl = oracleUsdcWeth.getTVLByOwnerOfShares(USDC_WETH_PAIR, lp);
        assertGt(userTvl, 0, "user TVL must be positive after add");

        // LP received should be ~1% of total supply
        uint256 expectedLp = totalSupply / 100;
        assertApproxEqRel(lpReceived, expectedLp, 1e15, "LP received ~1% of supply (0.1% tolerance)");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 8: SWAP INVARIANCE ON REAL PAIRS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must not decrease after a real swap (USDC/WETH)
    /// @dev The 0.3% swap fee increases k, so PPS can only go up (or stay same due to rounding).
    ///      The Alpha Homora formula uses sqrt(r0*r1_in_token0) which increases with k.
    function test_fork_usdcWeth_pps_nonDecreasingAfterSwap() public {
        uint256 ppsBefore = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        _simulateSwap(USDC_WETH_PAIR, USDC, WETH);

        uint256 ppsAfter = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertGe(ppsAfter, ppsBefore, "USDC/WETH: PPS must not decrease after swap (fees accrue)");
        // Should be very close — 1% swap with 0.3% fee = ~0.003% PPS increase
        assertApproxEqRel(ppsAfter, ppsBefore, 1e14, "USDC/WETH: PPS drift > 0.01% after swap");
    }

    /// @notice PPS must not decrease after a real swap (DAI/USDC)
    function test_fork_daiUsdc_pps_nonDecreasingAfterSwap() public {
        uint256 ppsBefore = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);

        _simulateSwap(DAI_USDC_PAIR, DAI, USDC);

        uint256 ppsAfter = oracleDaiUsdc.getPricePerShare(DAI_USDC_PAIR);
        assertGe(ppsAfter, ppsBefore, "DAI/USDC: PPS must not decrease after swap (fees accrue)");
        assertApproxEqRel(ppsAfter, ppsBefore, 1e14, "DAI/USDC: PPS drift > 0.01% after swap");
    }

    /// @notice PPS must not decrease after a real swap (WBTC/WETH)
    function test_fork_wbtcWeth_pps_nonDecreasingAfterSwap() public {
        uint256 ppsBefore = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);

        _simulateSwap(WBTC_WETH_PAIR, WBTC, WETH);

        uint256 ppsAfter = oracleWbtcWeth.getPricePerShare(WBTC_WETH_PAIR);
        assertGe(ppsAfter, ppsBefore, "WBTC/WETH: PPS must not decrease after swap (fees accrue)");
        assertApproxEqRel(ppsAfter, ppsBefore, 1e14, "WBTC/WETH: PPS drift > 0.01% after swap");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 9: TVL = PPS × TOTAL_SUPPLY / 1e18
    //////////////////////////////////////////////////////////////*/

    /// @notice TVL must equal getAssetOutput(totalSupply) for each pair
    function test_fork_tvl_equalsPpsTimesSupply() public view {
        // USDC/WETH
        uint256 supply = IUniswapV2Pair(USDC_WETH_PAIR).totalSupply();
        uint256 tvl = oracleUsdcWeth.getTVL(USDC_WETH_PAIR);
        uint256 tvlViaAssetOutput = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), supply);
        assertEq(tvl, tvlViaAssetOutput, "USDC/WETH: TVL must equal getAssetOutput(totalSupply)");

        // DAI/USDC
        supply = IUniswapV2Pair(DAI_USDC_PAIR).totalSupply();
        tvl = oracleDaiUsdc.getTVL(DAI_USDC_PAIR);
        tvlViaAssetOutput = oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), supply);
        assertEq(tvl, tvlViaAssetOutput, "DAI/USDC: TVL must equal getAssetOutput(totalSupply)");

        // WBTC/WETH
        supply = IUniswapV2Pair(WBTC_WETH_PAIR).totalSupply();
        tvl = oracleWbtcWeth.getTVL(WBTC_WETH_PAIR);
        tvlViaAssetOutput = oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), supply);
        assertEq(tvl, tvlViaAssetOutput, "WBTC/WETH: TVL must equal getAssetOutput(totalSupply)");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 10: BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVLMultiple must match individual getTVL calls
    function test_fork_getTVLMultiple_consistency() public view {
        address[] memory vaults = new address[](1);

        vaults[0] = USDC_WETH_PAIR;
        uint256[] memory tvls = oracleUsdcWeth.getTVLMultiple(vaults);
        assertEq(tvls[0], oracleUsdcWeth.getTVL(USDC_WETH_PAIR), "USDC/WETH batch TVL must match single");

        vaults[0] = DAI_USDC_PAIR;
        tvls = oracleDaiUsdc.getTVLMultiple(vaults);
        assertEq(tvls[0], oracleDaiUsdc.getTVL(DAI_USDC_PAIR), "DAI/USDC batch TVL must match single");

        vaults[0] = WBTC_WETH_PAIR;
        tvls = oracleWbtcWeth.getTVLMultiple(vaults);
        assertEq(tvls[0], oracleWbtcWeth.getTVL(WBTC_WETH_PAIR), "WBTC/WETH batch TVL must match single");
    }

    /// @notice getTVLByOwnerOfSharesMultiple must match individual calls
    function test_fork_getTVLByOwnerOfSharesMultiple_consistency() public {
        address lp = address(0xBEEF);
        _addLiquidity(USDC_WETH_PAIR, USDC, WETH);

        address[] memory vaults = new address[](1);
        vaults[0] = USDC_WETH_PAIR;
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = lp;

        uint256[][] memory tvls = oracleUsdcWeth.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(
            tvls[0][0],
            oracleUsdcWeth.getTVLByOwnerOfShares(USDC_WETH_PAIR, lp),
            "batch owner TVL must match single"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 11: CONSTRUCTOR IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor immutables must match the real on-chain feed/token values
    function test_fork_immutables_usdcWeth() public view {
        assertEq(address(oracleUsdcWeth.FEED0()), USDC_USD_FEED, "FEED0 must be USDC/USD");
        assertEq(address(oracleUsdcWeth.FEED1()), ETH_USD_FEED, "FEED1 must be ETH/USD");
        assertEq(oracleUsdcWeth.FEED0_SCALE(), 10 ** IAggregatorV3(USDC_USD_FEED).decimals(), "FEED0_SCALE");
        assertEq(oracleUsdcWeth.FEED1_SCALE(), 10 ** IAggregatorV3(ETH_USD_FEED).decimals(), "FEED1_SCALE");
        assertEq(oracleUsdcWeth.TOKEN0_SCALE(), 1e6, "TOKEN0_SCALE = 10^6 for USDC");
        assertEq(oracleUsdcWeth.TOKEN1_DECIMALS(), 18, "TOKEN1_DECIMALS = 18 for WETH");
        assertEq(oracleUsdcWeth.MAX_STALENESS(), MAX_STALENESS);
    }

    /// @notice Constructor immutables must match for WBTC/WETH
    function test_fork_immutables_wbtcWeth() public view {
        assertEq(address(oracleWbtcWeth.FEED0()), BTC_USD_FEED, "FEED0 must be BTC/USD");
        assertEq(address(oracleWbtcWeth.FEED1()), ETH_USD_FEED, "FEED1 must be ETH/USD");
        assertEq(oracleWbtcWeth.TOKEN0_SCALE(), 1e8, "TOKEN0_SCALE = 10^8 for WBTC");
        assertEq(oracleWbtcWeth.TOKEN1_DECIMALS(), 18, "TOKEN1_DECIMALS = 18 for WETH");
    }

    /// @notice Constructor immutables must match for DAI/USDC
    function test_fork_immutables_daiUsdc() public view {
        assertEq(address(oracleDaiUsdc.FEED0()), DAI_USD_FEED, "FEED0 must be DAI/USD");
        assertEq(address(oracleDaiUsdc.FEED1()), USDC_USD_FEED, "FEED1 must be USDC/USD");
        assertEq(oracleDaiUsdc.TOKEN0_SCALE(), 1e18, "TOKEN0_SCALE = 10^18 for DAI");
        assertEq(oracleDaiUsdc.TOKEN1_DECIMALS(), 6, "TOKEN1_DECIMALS = 6 for USDC");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 12: ZERO INPUT INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice All conversion functions must return 0 for zero input
    function test_fork_zeroInputs_returnZero() public view {
        // getShareOutput(0) = 0
        assertEq(oracleUsdcWeth.getShareOutput(USDC_WETH_PAIR, address(0), 0), 0, "getShareOutput(0) must be 0");
        assertEq(oracleDaiUsdc.getShareOutput(DAI_USDC_PAIR, address(0), 0), 0);
        assertEq(oracleWbtcWeth.getShareOutput(WBTC_WETH_PAIR, address(0), 0), 0);

        // getAssetOutput(0) = 0
        assertEq(oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), 0), 0, "getAssetOutput(0) must be 0");
        assertEq(oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), 0), 0);
        assertEq(oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), 0), 0);

        // getWithdrawalShareOutput(0) = 0
        assertEq(
            oracleUsdcWeth.getWithdrawalShareOutput(USDC_WETH_PAIR, address(0), 0),
            0,
            "getWithdrawalShareOutput(0) must be 0"
        );
        assertEq(oracleDaiUsdc.getWithdrawalShareOutput(DAI_USDC_PAIR, address(0), 0), 0);
        assertEq(oracleWbtcWeth.getWithdrawalShareOutput(WBTC_WETH_PAIR, address(0), 0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 13: getAssetOutputWithFees (NO FEE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Without fees configured, getAssetOutputWithFees must equal getAssetOutput
    function test_fork_assetOutputWithFees_equalsBaseWhenNoFeesConfigured() public view {
        uint256 sharesIn = 1e18;
        bytes32 oracleId = bytes32(0);

        uint256 base = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), sharesIn);
        uint256 withFees = oracleUsdcWeth.getAssetOutputWithFees(oracleId, USDC_WETH_PAIR, address(0), address(0), sharesIn);
        assertEq(withFees, base, "no fees configured: getAssetOutputWithFees must equal getAssetOutput");

        base = oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), sharesIn);
        withFees = oracleDaiUsdc.getAssetOutputWithFees(oracleId, DAI_USDC_PAIR, address(0), address(0), sharesIn);
        assertEq(withFees, base, "DAI/USDC: no fees");

        base = oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), sharesIn);
        withFees = oracleWbtcWeth.getAssetOutputWithFees(oracleId, WBTC_WETH_PAIR, address(0), address(0), sharesIn);
        assertEq(withFees, base, "WBTC/WETH: no fees");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 14: LARGE LIQUIDITY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS stable after 50% add liquidity (stress test large amounts)
    function test_fork_usdcWeth_pps_stableAfterLargeAdd() public {
        uint256 ppsBefore = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        _addLiquidityPct(USDC_WETH_PAIR, USDC, WETH, 50);

        uint256 ppsAfter = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "PPS drift > 0.0001% after 50% add");
    }

    /// @notice PPS stable after 50% remove liquidity
    function test_fork_usdcWeth_pps_stableAfterLargeRemove() public {
        uint256 ppsBefore = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        _removeLiquidityPct(USDC_WETH_PAIR, 50);

        uint256 ppsAfter = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "PPS drift > 0.0001% after 50% remove");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 15: SEQUENTIAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS remains stable through add -> swap -> remove sequence
    function test_fork_usdcWeth_pps_stableThroughSequence() public {
        uint256 ppsStart = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);

        // Step 1: Add 5% liquidity
        _addLiquidityPct(USDC_WETH_PAIR, USDC, WETH, 5);
        uint256 ppsAfterAdd = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertApproxEqRel(ppsAfterAdd, ppsStart, 1e12, "PPS drift after add");

        // Step 2: Swap (0.3% fee increases k slightly, so PPS can only go up)
        _simulateSwap(USDC_WETH_PAIR, USDC, WETH);
        uint256 ppsAfterSwap = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        assertGe(ppsAfterSwap, ppsAfterAdd, "PPS must not decrease after swap");
        assertApproxEqRel(ppsAfterSwap, ppsAfterAdd, 1e14, "PPS drift > 0.01% after swap");

        // Step 3: Remove 5% liquidity
        _removeLiquidityPct(USDC_WETH_PAIR, 5);
        uint256 ppsAfterRemove = oracleUsdcWeth.getPricePerShare(USDC_WETH_PAIR);
        // PPS should be >= ppsStart (swap fees accrued) and within tight tolerance
        assertGe(ppsAfterRemove, ppsStart, "PPS must not decrease over full sequence (fees accrued)");
        assertApproxEqRel(ppsAfterRemove, ppsStart, 1e14, "PPS drift after full add-swap-remove sequence");
    }

    /*//////////////////////////////////////////////////////////////
                SECTION 16: WITHDRAWAL CEIL COVERS ASSETS POST-LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice getWithdrawalShareOutput still covers requested assets after liquidity change
    function test_fork_ceilRounding_holdsAfterAddLiquidity() public {
        _addLiquidity(USDC_WETH_PAIR, USDC, WETH);

        uint256 assetsIn = 500_000e6; // 500k USDC
        uint256 sharesNeeded = oracleUsdcWeth.getWithdrawalShareOutput(USDC_WETH_PAIR, address(0), assetsIn);
        uint256 assetsBack = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding must cover requested assets after add liquidity");
    }

    /// @notice Round-trip no-value-creation holds after liquidity change for all pairs
    function test_fork_roundTrip_holdsAfterLiquidityChange() public {
        // Add liquidity to each pair then test round-trip
        _addLiquidity(USDC_WETH_PAIR, USDC, WETH);
        _addLiquidity(DAI_USDC_PAIR, DAI, USDC);
        _addLiquidity(WBTC_WETH_PAIR, WBTC, WETH);

        // USDC/WETH
        uint256 assetsIn = 1_000_000e6;
        uint256 shares = oracleUsdcWeth.getShareOutput(USDC_WETH_PAIR, address(0), assetsIn);
        uint256 assetsOut = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "USDC/WETH: round trip must not create value after add");

        // DAI/USDC
        assetsIn = 1_000_000e18;
        shares = oracleDaiUsdc.getShareOutput(DAI_USDC_PAIR, address(0), assetsIn);
        assetsOut = oracleDaiUsdc.getAssetOutput(DAI_USDC_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "DAI/USDC: round trip must not create value after add");

        // WBTC/WETH
        assetsIn = 100e8;
        shares = oracleWbtcWeth.getShareOutput(WBTC_WETH_PAIR, address(0), assetsIn);
        assetsOut = oracleWbtcWeth.getAssetOutput(WBTC_WETH_PAIR, address(0), shares);
        assertLe(assetsOut, assetsIn, "WBTC/WETH: round trip must not create value after add");
    }

    /*//////////////////////////////////////////////////////////////
                SECTION 17: REAL LP HOLDER (MINIMUM LIQUIDITY LOCK)
    //////////////////////////////////////////////////////////////*/

    /// @notice The minimum liquidity lock at address(0) must have a sensible TVL
    function test_fork_minimumLiquidityLock_hasTvl() public view {
        // UniV2 burns MINIMUM_LIQUIDITY (1000) to address(0) on first mint
        address lockAddr = address(0);

        uint256 lockBalance = oracleUsdcWeth.getBalanceOfOwner(USDC_WETH_PAIR, lockAddr);
        assertGt(lockBalance, 0, "USDC/WETH: minimum liquidity lock must exist");

        uint256 lockTvl = oracleUsdcWeth.getTVLByOwnerOfShares(USDC_WETH_PAIR, lockAddr);
        assertGt(lockTvl, 0, "minimum liquidity lock TVL must be > 0");

        // TVL must equal getAssetOutput(balance)
        uint256 expectedTvl = oracleUsdcWeth.getAssetOutput(USDC_WETH_PAIR, address(0), lockBalance);
        assertEq(lockTvl, expectedTvl, "lock TVL must equal getAssetOutput(lockBalance)");
    }

    /*//////////////////////////////////////////////////////////////
                SECTION 18: TVL APPROXIMATELY 2 × RESERVE0 VALUE
    //////////////////////////////////////////////////////////////*/

    /// @notice TVL should approximately equal 2 × reserve0 (in token0 terms) when feeds are near-peg
    /// @dev For DAI/USDC stablecoin pair, both near $1, so TVL ≈ 2 × r0 in DAI
    function test_fork_daiUsdc_tvl_approximately2xReserve0() public view {
        (uint112 r0,,) = IUniswapV2Pair(DAI_USDC_PAIR).getReserves();
        uint256 tvl = oracleDaiUsdc.getTVL(DAI_USDC_PAIR);

        // For stablecoin pair near peg: TVL ≈ 2 * r0 (within 5% for Chainlink price deviations)
        uint256 twoR0 = uint256(r0) * 2;
        assertApproxEqRel(tvl, twoR0, 5e16, "DAI/USDC: TVL should be ~2x reserve0 (within 5%)");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Add proportional liquidity: deal `pct`% of current reserves to pair, call mint
    function _addLiquidityPct(address pair, address token0, address token1, uint256 pct) internal {
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();

        uint256 amount0 = uint256(r0) * pct / 100;
        uint256 amount1 = uint256(r1) * pct / 100;

        deal(token0, pair, IERC20(token0).balanceOf(pair) + amount0);
        deal(token1, pair, IERC20(token1).balanceOf(pair) + amount1);

        IUniswapV2PairFull(pair).mint(address(0xBEEF));
    }

    /// @dev Shorthand for 1% add
    function _addLiquidity(address pair, address token0, address token1) internal {
        _addLiquidityPct(pair, token0, token1, 1);
    }

    /// @dev Remove `pct`% of total supply via burn
    function _removeLiquidityPct(address pair, uint256 pct) internal {
        uint256 totalSupply = IUniswapV2Pair(pair).totalSupply();
        uint256 burnAmount = totalSupply * pct / 100;

        address burner = address(0xCAFE);
        deal(pair, burner, burnAmount);
        vm.prank(burner);
        IERC20(pair).transfer(pair, burnAmount);
        IUniswapV2PairFull(pair).burn(burner);
    }

    /// @dev Shorthand for 1% remove
    function _removeLiquidity(address pair) internal {
        _removeLiquidityPct(pair, 1);
    }

    /// @dev Simulate a swap by dealing token0 into the pair and taking token1 out.
    ///      Uses UniV2 fee-inclusive formula: amountOut = r1 * amountIn * 997 / (r0 * 1000 + amountIn * 997)
    ///      After swap, k increases slightly due to 0.3% fee retained in pool.
    function _simulateSwap(address pair, address token0, address) internal {
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();

        // Swap 1% of r0 in (token0 -> token1)
        uint256 amountIn = uint256(r0) / 100;
        // UniV2 fee-inclusive output: amountOut = r1 * amountIn * 997 / (r0 * 1000 + amountIn * 997)
        uint256 numerator = uint256(r1) * amountIn * 997;
        uint256 denominator = uint256(r0) * 1000 + amountIn * 997;
        uint256 amountOut = numerator / denominator;

        // Deal token0 into pair (increases r0)
        deal(token0, pair, IERC20(token0).balanceOf(pair) + amountIn);

        // Execute swap: take amountOut of token1
        address recipient = address(0xF00D);
        IUniswapV2PairFull(pair).swap(0, amountOut, recipient, "");

        // Verify: reserves changed in expected direction
        (uint112 postR0, uint112 postR1,) = IUniswapV2Pair(pair).getReserves();
        assertGt(postR0, r0, "r0 must increase after swap");
        assertLt(postR1, r1, "r1 must decrease after swap");
    }
}
