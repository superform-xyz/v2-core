// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { UniV2LPYieldSourceOracle } from "../../../src/accounting/oracles/UniV2LPYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IUniswapV2Pair } from "../../../src/vendor/uniswap/IUniswapV2Pair.sol";

/// @notice Minimal interface for Aerodrome Pool operations (mint/burn/swap)
/// @dev Aerodrome pools have the same mint/burn/swap signatures as UniV2
interface IAerodromePool {
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function stable() external view returns (bool);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
}

/// @title AerodromeOracleForkTest
/// @notice Fork tests verifying UniV2LPYieldSourceOracle works with Aerodrome volatile pools on Base
/// @dev Aerodrome is a Solidly fork. Key differences from UniV2:
///      - getReserves() returns (uint256, uint256, uint256) vs UniV2's (uint112, uint112, uint32)
///      - Has both volatile (x*y=k) and stable (x^3*y + x*y^3 = k) pool types
///      - The UniV2 oracle formula is ONLY valid for volatile pools (x*y=k invariant)
///      ABI compatibility: Solidity 0.8.x decodes uint256->uint112 successfully when value fits
contract AerodromeOracleForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS - BASE CHAIN
    //////////////////////////////////////////////////////////////*/

    uint256 constant FORK_BLOCK = 47_790_000;
    uint256 constant MAX_STALENESS = 86_400; // 24h - generous for fork block

    // Aerodrome volatile pools on Base
    address constant AERO_WETH_USDC = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    address constant AERO_WETH_CBBTC = 0x2578365B3dfA7FfE60108e181EFb79FeDdec2319;

    // Aerodrome stable pool (for negative test)
    address constant AERO_USDC_USDBC_STABLE = 0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD;

    // Base tokens
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

    // Chainlink feeds on Base (8 decimals)
    address constant ETH_USD_FEED = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address constant USDC_USD_FEED = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address constant BTC_USD_FEED = 0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D;

    // Address guaranteed to hold no LP tokens
    address constant NO_LP_HOLDER = address(0xdeAD0000DEAd0000DEAd0000DEad0000DeAd0000);

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    UniV2LPYieldSourceOracle public oracleWethUsdc;
    UniV2LPYieldSourceOracle public oracleWethCbbtc;
    UniV2LPYieldSourceOracle public oracleStable;
    address public ledgerConfig;

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());

        // WETH/USDC volatile: token0=WETH(18), token1=USDC(6)
        // On Base L2 but sequencer check disabled for historical fork block
        oracleWethUsdc = new UniV2LPYieldSourceOracle(
            ledgerConfig, ETH_USD_FEED, USDC_USD_FEED, WETH, USDC, MAX_STALENESS, address(0), 0
        );

        // WETH/cbBTC volatile: token0=WETH(18), token1=cbBTC(8)
        oracleWethCbbtc = new UniV2LPYieldSourceOracle(
            ledgerConfig, ETH_USD_FEED, BTC_USD_FEED, WETH, CBBTC, MAX_STALENESS, address(0), 0
        );

        // USDC/USDbC stable: token0=USDC(6), token1=USDbC(6)
        // Deployed to show oracle WORKS but gives inaccurate PPS for stable pools
        oracleStable = new UniV2LPYieldSourceOracle(
            ledgerConfig, USDC_USD_FEED, USDC_USD_FEED, USDC, USDBC, MAX_STALENESS, address(0), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                    ABI COMPATIBILITY - CRITICAL CHECK
    //////////////////////////////////////////////////////////////*/

    /// @notice Aerodrome returns (uint256,uint256,uint256) from getReserves,
    ///         but our IUniswapV2Pair decodes as (uint112,uint112,uint32).
    ///         This works as long as values fit in the smaller types.
    function test_aero_abiCompat_getReservesDecodesCorrectly() public view {
        // Decode through our IUniswapV2Pair interface (uint112, uint112, uint32)
        (uint112 r0_narrow, uint112 r1_narrow, uint32 ts_narrow) =
            IUniswapV2Pair(AERO_WETH_USDC).getReserves();

        // Decode through Aerodrome native interface (uint256, uint256, uint256)
        (uint256 r0_wide, uint256 r1_wide, uint256 ts_wide) =
            IAerodromePool(AERO_WETH_USDC).getReserves();

        // Values must match
        assertEq(uint256(r0_narrow), r0_wide, "reserve0 must match across ABI decodings");
        assertEq(uint256(r1_narrow), r1_wide, "reserve1 must match across ABI decodings");
        assertEq(uint256(ts_narrow), ts_wide, "timestamp must match across ABI decodings");

        // Sanity: reserves are non-zero
        assertGt(r0_wide, 0, "reserve0 must be non-zero");
        assertGt(r1_wide, 0, "reserve1 must be non-zero");
    }

    /// @notice Verify pool is actually volatile (x*y=k) - our formula requires this
    function test_aero_wethUsdc_isVolatile() public view {
        bool isStable = IAerodromePool(AERO_WETH_USDC).stable();
        assertFalse(isStable, "WETH/USDC must be a volatile pool");
    }

    function test_aero_wethCbbtc_isVolatile() public view {
        bool isStable = IAerodromePool(AERO_WETH_CBBTC).stable();
        assertFalse(isStable, "WETH/cbBTC must be a volatile pool");
    }

    /*//////////////////////////////////////////////////////////////
                WETH/USDC VOLATILE POOL - CORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_aero_wethUsdc_pps_nonZero() public view {
        uint256 pps = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);
        assertGt(pps, 0, "PPS must be positive");
    }

    function test_aero_wethUsdc_pps_sanityRange() public view {
        uint256 pps = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        // PPS is in WETH terms (token0=WETH, 18 dec)
        // This pool has ~2290 WETH + ~$3.78M USDC
        // Total value in WETH ~ 2290 + 3780000/1652 ~ 2290 + 2288 ~ 4578 WETH
        // totalSupply ~ 9.1e16 = 0.091 LP tokens
        // PPS ~ 4578e18 / 0.091e18 ~ 50,307e18
        // Allow wide range: 10,000 to 200,000 WETH per LP token
        assertGt(pps, 10_000e18, "PPS too low");
        assertLt(pps, 200_000e18, "PPS too high");
    }

    function test_aero_wethUsdc_tvl_nonZero() public view {
        uint256 tvl = oracleWethUsdc.getTVL(AERO_WETH_USDC);
        assertGt(tvl, 0, "TVL must be positive");
    }

    function test_aero_wethUsdc_tvl_sanity() public view {
        uint256 tvl = oracleWethUsdc.getTVL(AERO_WETH_USDC);

        // TVL in WETH terms. Pool has ~4578 WETH total value
        // Allow 1000 to 20,000 WETH range
        assertGt(tvl, 1000e18, "TVL too low");
        assertLt(tvl, 20_000e18, "TVL too high");
    }

    function test_aero_wethUsdc_ppsConsistency() public view {
        uint256 pps = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);
        uint256 assetForOneLp = oracleWethUsdc.getAssetOutput(AERO_WETH_USDC, address(0), 1e18);
        assertEq(pps, assetForOneLp, "PPS must equal getAssetOutput(1e18)");
    }

    function test_aero_wethUsdc_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 100e18; // 100 WETH
        uint256 shares = oracleWethUsdc.getShareOutput(AERO_WETH_USDC, address(0), assetsIn);
        uint256 assetsOut = oracleWethUsdc.getAssetOutput(AERO_WETH_USDC, address(0), shares);
        assertLe(assetsOut, assetsIn, "Round trip must not create value");
    }

    function test_aero_wethUsdc_decimals() public view {
        assertEq(oracleWethUsdc.decimals(AERO_WETH_USDC), 18);
    }

    function test_aero_wethUsdc_ceilRounding() public view {
        uint256 assetsIn = 7e18;
        uint256 depositShares = oracleWethUsdc.getShareOutput(AERO_WETH_USDC, address(0), assetsIn);
        uint256 withdrawShares = oracleWethUsdc.getWithdrawalShareOutput(AERO_WETH_USDC, address(0), assetsIn);
        assertGe(withdrawShares, depositShares, "Withdrawal shares must >= deposit shares (ceil rounding)");
    }

    function test_aero_wethUsdc_balanceOfZero() public view {
        uint256 bal = oracleWethUsdc.getBalanceOfOwner(AERO_WETH_USDC, NO_LP_HOLDER);
        assertEq(bal, 0);
    }

    function test_aero_wethUsdc_tvlByOwnerZero() public view {
        uint256 tvl = oracleWethUsdc.getTVLByOwnerOfShares(AERO_WETH_USDC, NO_LP_HOLDER);
        assertEq(tvl, 0);
    }

    /*//////////////////////////////////////////////////////////////
                WETH/USDC - LIQUIDITY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_aero_wethUsdc_addLiquidity_ppsStable() public {
        uint256 ppsBefore = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        _addLiquidityPct(AERO_WETH_USDC, WETH, USDC, 1); // Add 1% of reserves

        uint256 ppsAfter = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        // PPS should stay approximately the same after proportional add
        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "PPS should be stable after add liquidity");
    }

    function test_aero_wethUsdc_removeLiquidity_ppsStable() public {
        uint256 ppsBefore = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        _removeLiquidityPct(AERO_WETH_USDC, 1); // Remove 1% of LP

        uint256 ppsAfter = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        assertApproxEqRel(ppsAfter, ppsBefore, 1e12, "PPS should be stable after remove liquidity");
    }

    function test_aero_wethUsdc_swap_ppsNonDecreasing() public {
        uint256 ppsBefore = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        _simulateSwap(AERO_WETH_USDC, WETH, USDC);

        uint256 ppsAfter = oracleWethUsdc.getPricePerShare(AERO_WETH_USDC);

        // Swap fees increase k, so PPS should not decrease
        assertGe(ppsAfter, ppsBefore, "PPS must not decrease after swap (fees increase k)");
        // Should be within ~0.01% (fee is 0.3% but only on small portion of reserves)
        assertApproxEqRel(ppsAfter, ppsBefore, 1e14, "PPS should be approximately same after small swap");
    }

    /*//////////////////////////////////////////////////////////////
                WETH/cbBTC VOLATILE POOL - CORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_aero_wethCbbtc_pps_nonZero() public view {
        uint256 pps = oracleWethCbbtc.getPricePerShare(AERO_WETH_CBBTC);
        assertGt(pps, 0, "PPS must be positive");
    }

    function test_aero_wethCbbtc_tvl_nonZero() public view {
        uint256 tvl = oracleWethCbbtc.getTVL(AERO_WETH_CBBTC);
        assertGt(tvl, 0, "TVL must be positive");
    }

    function test_aero_wethCbbtc_ppsConsistency() public view {
        uint256 pps = oracleWethCbbtc.getPricePerShare(AERO_WETH_CBBTC);
        uint256 assetForOneLp = oracleWethCbbtc.getAssetOutput(AERO_WETH_CBBTC, address(0), 1e18);
        assertEq(pps, assetForOneLp, "PPS must equal getAssetOutput(1e18)");
    }

    function test_aero_wethCbbtc_roundTrip_noValueCreation() public view {
        uint256 assetsIn = 10e18;
        uint256 shares = oracleWethCbbtc.getShareOutput(AERO_WETH_CBBTC, address(0), assetsIn);
        uint256 assetsOut = oracleWethCbbtc.getAssetOutput(AERO_WETH_CBBTC, address(0), shares);
        assertLe(assetsOut, assetsIn, "Round trip must not create value");
    }

    function test_aero_wethCbbtc_swap_ppsNonDecreasing() public {
        uint256 ppsBefore = oracleWethCbbtc.getPricePerShare(AERO_WETH_CBBTC);

        _simulateSwap(AERO_WETH_CBBTC, WETH, CBBTC);

        uint256 ppsAfter = oracleWethCbbtc.getPricePerShare(AERO_WETH_CBBTC);

        assertGe(ppsAfter, ppsBefore, "PPS must not decrease after swap");
    }

    /*//////////////////////////////////////////////////////////////
                STABLE POOL - FORMULA APPLICABILITY CHECK
    //////////////////////////////////////////////////////////////*/

    /// @notice The Alpha Homora formula is derived from x*y=k invariant.
    ///         For stable pools (x^3*y + x*y^3 = k), it's technically inaccurate.
    ///         However, for stablecoin pairs near 1:1, the error is small.
    ///         This test documents that the oracle CAN be called on stable pools
    ///         but the PPS may diverge from reality during large depegs.
    function test_aero_stable_pps_returnsValue() public view {
        assertTrue(IAerodromePool(AERO_USDC_USDBC_STABLE).stable(), "Must be stable pool");

        // Oracle still returns a value - it doesn't know the invariant type
        uint256 pps = oracleStable.getPricePerShare(AERO_USDC_USDBC_STABLE);
        assertGt(pps, 0, "PPS must be positive even on stable pool");

        // PPS = 2 * sqrt(r0 * r1ValueInToken0) * 1e18 / totalSupply
        // For USDC/USDbC at ~1:1 with ~equal reserves and totalSupply:
        //   PPS ~ 2 * sqrt(r0 * r1) * 1e18 / totalSupply ~ 2e18
        // (totalSupply is in 18-dec LP terms, reserves in 6-dec USDC terms)
        // The result is valid for volatile formula; for stablecoin pairs near peg
        // the Alpha Homora formula gives approximately correct results.
        // The formula diverges from reality for large depegs on stable pools.
        assertApproxEqRel(pps, 2e18, 5e16, "PPS should be ~2e18 for 1:1 stablecoin pair (within 5%)");
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-POOL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_aero_tvlEqualsAssetOutputOfTotalSupply() public view {
        uint256 totalSupply = IUniswapV2Pair(AERO_WETH_USDC).totalSupply();
        uint256 tvl = oracleWethUsdc.getTVL(AERO_WETH_USDC);
        uint256 assetOutputTotal = oracleWethUsdc.getAssetOutput(AERO_WETH_USDC, address(0), totalSupply);
        assertEq(tvl, assetOutputTotal, "TVL must equal getAssetOutput(totalSupply)");
    }

    function test_aero_batchPpsConsistency() public view {
        address[] memory pairs = new address[](2);
        pairs[0] = AERO_WETH_USDC;
        pairs[1] = AERO_WETH_CBBTC;

        uint256[] memory ppsBatch = oracleWethUsdc.getPricePerShareMultiple(pairs);

        // First oracle handles both - but only WETH/USDC PPS is meaningful from oracleWethUsdc
        // For proper batch test, just verify it returns same as individual calls
        assertEq(ppsBatch[0], oracleWethUsdc.getPricePerShare(AERO_WETH_USDC));
    }

    function test_aero_constructorImmutables() public view {
        assertEq(address(oracleWethUsdc.FEED0()), ETH_USD_FEED);
        assertEq(address(oracleWethUsdc.FEED1()), USDC_USD_FEED);
        assertEq(oracleWethUsdc.TOKEN0_SCALE(), 1e18);
        assertEq(oracleWethUsdc.TOKEN1_DECIMALS(), 6);
        assertEq(oracleWethUsdc.MAX_STALENESS(), MAX_STALENESS);

        assertEq(address(oracleWethCbbtc.FEED0()), ETH_USD_FEED);
        assertEq(address(oracleWethCbbtc.FEED1()), BTC_USD_FEED);
        assertEq(oracleWethCbbtc.TOKEN0_SCALE(), 1e18);
        assertEq(oracleWethCbbtc.TOKEN1_DECIMALS(), 8);
    }

    function test_aero_zeroInputs() public view {
        assertEq(oracleWethUsdc.getShareOutput(AERO_WETH_USDC, address(0), 0), 0);
        assertEq(oracleWethUsdc.getAssetOutput(AERO_WETH_USDC, address(0), 0), 0);
        assertEq(oracleWethUsdc.getWithdrawalShareOutput(AERO_WETH_USDC, address(0), 0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add liquidity proportional to current reserves
    function _addLiquidityPct(address pool, address token0, address token1, uint256 pct) internal {
        (uint256 r0, uint256 r1,) = IAerodromePool(pool).getReserves();
        uint256 amount0 = r0 * pct / 100;
        uint256 amount1 = r1 * pct / 100;

        deal(token0, address(this), amount0);
        deal(token1, address(this), amount1);

        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);

        IAerodromePool(pool).mint(address(this));
    }

    /// @notice Remove liquidity by burning a percentage of total LP supply
    function _removeLiquidityPct(address pool, uint256 pct) internal {
        uint256 totalSupply = IUniswapV2Pair(pool).totalSupply();
        uint256 burnAmount = totalSupply * pct / 100;

        // Give this contract LP tokens then send to pool for burn
        deal(pool, address(this), burnAmount);
        IERC20(pool).transfer(pool, burnAmount);

        IAerodromePool(pool).burn(address(this));
    }

    /// @notice Simulate a small swap (1% of reserve0) using fee-inclusive output
    function _simulateSwap(address pool, address token0, address) internal {
        (uint256 r0, uint256 r1,) = IAerodromePool(pool).getReserves();
        uint256 amountIn = r0 / 100; // 1% of reserve0

        // Aerodrome volatile fee is 0.3% (same as UniV2)
        // amountOut = r1 * amountIn * 997 / (r0 * 1000 + amountIn * 997)
        uint256 numerator = r1 * amountIn * 997;
        uint256 denominator = r0 * 1000 + amountIn * 997;
        uint256 amountOut = numerator / denominator;

        deal(token0, address(this), amountIn);
        IERC20(token0).transfer(pool, amountIn);

        IAerodromePool(pool).swap(0, amountOut, address(this), "");
    }
}
