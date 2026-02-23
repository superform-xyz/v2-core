// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { PendlePTAmortizedOracle } from "../../../src/accounting/oracles/PendlePTAmortizedOracle.sol";
import { IPMarket } from "@pendle/interfaces/IPMarket.sol";
import { IPPrincipalToken } from "@pendle/interfaces/IPPrincipalToken.sol";
import { IStandardizedYield } from "@pendle/interfaces/IStandardizedYield.sol";
import { IPYieldToken } from "@pendle/interfaces/IPYieldToken.sol";

/// @title PendlePTAmortizedOracleForkTest
/// @notice Integration fork tests for PendlePTAmortizedOracle using real Pendle markets
/// @dev Uses real SuperVault strategies and Pendle markets from mainnet
/// @dev Strategies call recordPurchase/recordRedemption directly (msg.sender is the strategy)
contract PendlePTAmortizedOracleForkTest is Test {
    // RPC URL key from environment
    string constant ETHEREUM_RPC_URL_KEY = "ETHEREUM_RPC_URL";

    PendlePTAmortizedOracle public oracle;
    address public admin;
    address public superLedgerConfiguration;

    // Production SuperVault Strategies from supervaults.json
    address constant USDC_STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address constant WBTC_STRATEGY = 0xa96060B0B6907406EdBDf3cCc9438abf0F78Cf83;
    address constant WETH_STRATEGY = 0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2;

    // Known Pendle Markets on Ethereum mainnet (from test exploration)
    // These may need updating based on actual deployed markets
    address constant PENDLE_AUSDC_MARKET = 0x8539B41CA14148d1F7400d399723827a80579414;
    address constant PENDLE_ETHENA_MARKET = 0x3Ee118EFC826d30A29645eAf3b2EaaC9E8320185;
    address constant PENDLE_PUFETH_MARKET = 0x58612beB0e8a126735b19BB222cbC7fC2C162D2a;

    // Pendle Router for swaps
    address constant PENDLE_ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    // Fork block - use a recent block
    uint256 constant FORK_BLOCK = 21_500_000;

    // Events
    event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp);

    function setUp() public {
        // Create mainnet fork
        uint256 forkId = vm.createFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        vm.selectFork(forkId);

        admin = makeAddr("admin");
        superLedgerConfiguration = makeAddr("superLedgerConfiguration");

        // Deploy oracle
        vm.prank(admin);
        oracle = new PendlePTAmortizedOracle(admin, superLedgerConfiguration);
    }

    /*//////////////////////////////////////////////////////////////
                        MARKET INSPECTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test reading market tokens from real Pendle market
    function test_Fork_ReadMarketTokens_aUSDCMarket() public view {
        IPMarket market = IPMarket(PENDLE_AUSDC_MARKET);

        (IStandardizedYield sy, IPPrincipalToken pt, IPYieldToken yt) = market.readTokens();

        console2.log("=== aUSDC Market ===");
        console2.log("Market:", PENDLE_AUSDC_MARKET);
        console2.log("SY:", address(sy));
        console2.log("PT:", address(pt));
        console2.log("YT:", address(yt));
        console2.log("PT Expiry:", pt.expiry());
        console2.log("PT Decimals:", IERC20Metadata(address(pt)).decimals());

        // Verify tokens are valid
        assertTrue(address(sy) != address(0), "SY should not be zero");
        assertTrue(address(pt) != address(0), "PT should not be zero");
        assertTrue(address(yt) != address(0), "YT should not be zero");
        assertTrue(pt.expiry() > 0, "Expiry should be set");
    }

    /// @notice Test reading market tokens from pufETH market
    function test_Fork_ReadMarketTokens_PufETHMarket() public view {
        IPMarket market = IPMarket(PENDLE_PUFETH_MARKET);

        (IStandardizedYield sy, IPPrincipalToken pt, IPYieldToken yt) = market.readTokens();

        console2.log("=== pufETH Market ===");
        console2.log("Market:", PENDLE_PUFETH_MARKET);
        console2.log("SY:", address(sy));
        console2.log("PT:", address(pt));
        console2.log("YT:", address(yt));
        console2.log("PT Expiry:", pt.expiry());
        console2.log("Current time:", block.timestamp);
        console2.log("Time to maturity:", pt.expiry() > block.timestamp ? pt.expiry() - block.timestamp : 0);

        assertTrue(address(pt) != address(0), "PT should not be zero");
    }

    /*//////////////////////////////////////////////////////////////
                    ORACLE LIFECYCLE TESTS WITH REAL MARKETS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test full purchase lifecycle with a real Pendle market
    function test_Fork_RecordPurchase_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_AUSDC_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        // Skip if market is expired
        if (block.timestamp >= pt.expiry()) {
            console2.log("Market expired, skipping test");
            return;
        }

        // Create a test strategy address
        address testStrategy = makeAddr("testStrategy");

        // Mint some PT to the test strategy using deal
        uint256 ptAmount = 1000e6; // 1000 PT (6 decimals for USDC-based)
        deal(address(pt), testStrategy, ptAmount);

        // Verify the PT was minted
        uint256 strategyPtBalance = IERC20(address(pt)).balanceOf(testStrategy);
        assertEq(strategyPtBalance, ptAmount, "Strategy should have PT");

        // Record purchase (10% discount from face value)
        // Strategy calls recordPurchase directly (msg.sender is strategy)
        uint256 sySpent = ptAmount * 90 / 100; // 900 units spent for 1000 PT

        vm.prank(testStrategy);
        vm.expectEmit(true, true, false, true);
        emit BookValueUpdated(testStrategy, address(market), sySpent, block.timestamp);
        oracle.recordPurchase(address(market), sySpent, ptAmount);

        // Verify book value
        uint256 bookValue = oracle.getBookValue(testStrategy, address(market));
        assertEq(bookValue, sySpent, "Book value should equal sySpent");

        console2.log("=== Purchase Recorded ===");
        console2.log("Strategy:", testStrategy);
        console2.log("PT Amount:", ptAmount);
        console2.log("SY Spent:", sySpent);
        console2.log("Book Value:", bookValue);
        console2.log("Maturity:", pt.expiry());
    }

    /// @notice Test amortization over time with a real market
    function test_Fork_Amortization_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_PUFETH_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        // Skip if market is expired
        if (block.timestamp >= pt.expiry()) {
            console2.log("pufETH market expired, skipping test");
            return;
        }

        address testStrategy = makeAddr("testStrategy");
        uint256 ptAmount = 1000e18; // 1000 PT (18 decimals)
        uint256 sySpent = ptAmount * 90 / 100; // 10% discount

        // Mint PT to strategy
        deal(address(pt), testStrategy, ptAmount);

        // Record purchase (strategy calls directly)
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent, ptAmount);

        uint256 initialBookValue = oracle.getBookValue(testStrategy, address(market));
        console2.log("Initial book value:", initialBookValue);

        // Calculate time to maturity
        uint256 timeToMaturity = pt.expiry() - block.timestamp;
        console2.log("Time to maturity (seconds):", timeToMaturity);

        // Warp forward 25% of time to maturity
        uint256 warpTime = timeToMaturity / 4;
        vm.warp(block.timestamp + warpTime);

        uint256 bookValueAt25Percent = oracle.getBookValue(testStrategy, address(market));
        console2.log("Book value at 25%:", bookValueAt25Percent);

        // Book value should have increased (amortized)
        assertGt(bookValueAt25Percent, initialBookValue, "Book value should increase over time");

        // Warp to 50%
        vm.warp(block.timestamp + warpTime);
        uint256 bookValueAt50Percent = oracle.getBookValue(testStrategy, address(market));
        console2.log("Book value at 50%:", bookValueAt50Percent);

        assertGt(bookValueAt50Percent, bookValueAt25Percent, "Book value should continue increasing");

        // Warp to maturity
        vm.warp(pt.expiry());
        uint256 bookValueAtMaturity = oracle.getBookValue(testStrategy, address(market));
        console2.log("Book value at maturity:", bookValueAtMaturity);

        // At maturity, book value should equal face value (ptAmount)
        assertEq(bookValueAtMaturity, ptAmount, "Book value at maturity should equal face value");
    }

    /// @notice Test redemption with cost basis accounting on real market
    function test_Fork_Redemption_CostBasis_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_AUSDC_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        if (block.timestamp >= pt.expiry()) {
            console2.log("Market expired, skipping test");
            return;
        }

        address testStrategy = makeAddr("testStrategy");
        uint256 ptAmount = 1000e6;
        uint256 sySpent = ptAmount * 90 / 100;

        // Mint PT and record purchase
        deal(address(pt), testStrategy, ptAmount);
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent, ptAmount);

        // Warp forward some time
        uint256 timeToMaturity = pt.expiry() - block.timestamp;
        vm.warp(block.timestamp + timeToMaturity / 4);

        uint256 bookValueBeforeRedemption = oracle.getBookValue(testStrategy, address(market));
        console2.log("Book value before redemption:", bookValueBeforeRedemption);

        // Redeem 50% of position
        uint256 ptToRedeem = ptAmount / 2;

        // Simulate the actual redemption by burning PT BEFORE recording
        // Note: In real scenario, strategy would transfer PT away. We simulate by dealing less.
        // recordRedemption is called AFTER the PT has been burned (per hook design)
        deal(address(pt), testStrategy, ptAmount - ptToRedeem);

        // Record redemption (strategy calls directly)
        vm.prank(testStrategy);
        oracle.recordRedemption(address(market), ptToRedeem);

        uint256 bookValueAfterRedemption = oracle.getBookValue(testStrategy, address(market));
        console2.log("Book value after redemption:", bookValueAfterRedemption);

        // Book value should be approximately half (proportional reduction)
        // Allow 1% tolerance for rounding
        assertApproxEqRel(
            bookValueAfterRedemption, bookValueBeforeRedemption / 2, 0.01e18, "Book value should be halved"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE PURCHASES TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test multiple purchases at different times with real market
    function test_Fork_MultiplePurchases_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_PUFETH_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        if (block.timestamp >= pt.expiry()) {
            console2.log("Market expired, skipping test");
            return;
        }

        address testStrategy = makeAddr("testStrategy");

        // First purchase: 1000 PT at 90% of face value
        uint256 ptAmount1 = 1000e18;
        uint256 sySpent1 = ptAmount1 * 90 / 100;

        deal(address(pt), testStrategy, ptAmount1);
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent1, ptAmount1);

        uint256 bookValue1 = oracle.getBookValue(testStrategy, address(market));
        console2.log("After 1st purchase - Book value:", bookValue1);

        // Warp forward
        uint256 timeToMaturity = pt.expiry() - block.timestamp;
        vm.warp(block.timestamp + timeToMaturity / 4);

        uint256 bookValueAmortized = oracle.getBookValue(testStrategy, address(market));
        console2.log("After amortization - Book value:", bookValueAmortized);

        // Second purchase: 500 PT at 95% of face value (less discount as closer to maturity)
        uint256 ptAmount2 = 500e18;
        uint256 sySpent2 = ptAmount2 * 95 / 100;

        deal(address(pt), testStrategy, ptAmount1 + ptAmount2);
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent2, ptAmount2);

        uint256 bookValueAfterSecondPurchase = oracle.getBookValue(testStrategy, address(market));
        console2.log("After 2nd purchase - Book value:", bookValueAfterSecondPurchase);

        // New book value should be amortized value + sySpent2
        assertEq(
            bookValueAfterSecondPurchase,
            bookValueAmortized + sySpent2,
            "Book value should equal amortized + new purchase"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test behavior after market maturity
    function test_Fork_AfterMaturity_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_AUSDC_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        address testStrategy = makeAddr("testStrategy");
        uint256 ptAmount = 1000e6;
        uint256 sySpent = ptAmount * 90 / 100;

        // Mint PT and record purchase only if market not yet expired
        if (block.timestamp < pt.expiry()) {
            deal(address(pt), testStrategy, ptAmount);
            vm.prank(testStrategy);
            oracle.recordPurchase(address(market), sySpent, ptAmount);

            // Warp well past maturity
            vm.warp(pt.expiry() + 365 days);

            // Book value should cap at face value, not extrapolate
            uint256 bookValue = oracle.getBookValue(testStrategy, address(market));
            assertEq(bookValue, ptAmount, "Book value should equal face value after maturity");

            console2.log("Book value after maturity:", bookValue);
            console2.log("PT Amount (face value):", ptAmount);
        } else {
            // Market already expired at fork block - test that recording purchase fails
            deal(address(pt), testStrategy, ptAmount);

            vm.prank(testStrategy);
            vm.expectRevert(PendlePTAmortizedOracle.MARKET_EXPIRED.selector);
            oracle.recordPurchase(address(market), sySpent, ptAmount);
        }
    }

    /// @notice Test with zero PT balance edge case
    function test_Fork_ZeroPTBalance_RealMarket() public {
        IPMarket market = IPMarket(PENDLE_AUSDC_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        if (block.timestamp >= pt.expiry()) {
            console2.log("Market expired, skipping test");
            return;
        }

        address testStrategy = makeAddr("testStrategy");
        uint256 ptAmount = 1000e6;
        uint256 sySpent = ptAmount * 90 / 100;

        // Record purchase with PT
        deal(address(pt), testStrategy, ptAmount);
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent, ptAmount);

        // Remove all PT (simulate transfer out)
        deal(address(pt), testStrategy, 0);

        // Book value should return 0 when no PT held
        uint256 bookValue = oracle.getBookValue(testStrategy, address(market));
        assertEq(bookValue, 0, "Book value should be 0 when no PT held");
    }

    /*//////////////////////////////////////////////////////////////
                    PRODUCTION STRATEGY INSPECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Inspect real production strategies for PT holdings
    function test_Fork_InspectProductionStrategies() public view {
        console2.log("=== Inspecting Production Strategies ===");

        // Check USDC strategy
        console2.log("\nUSDC Strategy:", USDC_STRATEGY);
        _inspectStrategyPTHoldings(USDC_STRATEGY, PENDLE_AUSDC_MARKET);

        // Check WETH strategy
        console2.log("\nWETH Strategy:", WETH_STRATEGY);
        _inspectStrategyPTHoldings(WETH_STRATEGY, PENDLE_ETHENA_MARKET);

        // Check WBTC strategy
        console2.log("\nWBTC Strategy:", WBTC_STRATEGY);
        _inspectStrategyPTHoldings(WBTC_STRATEGY, PENDLE_PUFETH_MARKET);
    }

    function _inspectStrategyPTHoldings(address strategy, address marketAddress) internal view {
        IPMarket market = IPMarket(marketAddress);

        try market.readTokens() returns (IStandardizedYield, IPPrincipalToken pt, IPYieldToken) {
            uint256 ptBalance = IERC20(address(pt)).balanceOf(strategy);
            console2.log("  Market:", marketAddress);
            console2.log("  PT Address:", address(pt));
            console2.log("  PT Balance:", ptBalance);
            console2.log("  PT Expiry:", pt.expiry());
        } catch {
            console2.log("  Market read failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Benchmark gas usage for key operations
    function test_Fork_GasBenchmarks() public {
        IPMarket market = IPMarket(PENDLE_PUFETH_MARKET);
        (, IPPrincipalToken pt,) = market.readTokens();

        if (block.timestamp >= pt.expiry()) {
            console2.log("Market expired, skipping benchmark");
            return;
        }

        address testStrategy = makeAddr("testStrategy");
        uint256 ptAmount = 1000e18;
        uint256 sySpent = ptAmount * 90 / 100;

        deal(address(pt), testStrategy, ptAmount);

        // Benchmark recordPurchase (strategy calls directly)
        uint256 gasBefore = gasleft();
        vm.prank(testStrategy);
        oracle.recordPurchase(address(market), sySpent, ptAmount);
        uint256 gasUsedPurchase = gasBefore - gasleft();
        console2.log("Gas used - recordPurchase:", gasUsedPurchase);

        // Benchmark getBookValue
        gasBefore = gasleft();
        oracle.getBookValue(testStrategy, address(market));
        uint256 gasUsedGetBookValue = gasBefore - gasleft();
        console2.log("Gas used - getBookValue:", gasUsedGetBookValue);

        // Benchmark recordRedemption (strategy calls directly)
        gasBefore = gasleft();
        vm.prank(testStrategy);
        oracle.recordRedemption(address(market), ptAmount / 2);
        uint256 gasUsedRedemption = gasBefore - gasleft();
        console2.log("Gas used - recordRedemption:", gasUsedRedemption);

        // Verify view function is under 20k gas (per spec requirement)
        assertLt(gasUsedGetBookValue, 20_000, "getBookValue should be under 20k gas");
    }
}
