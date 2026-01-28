// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTAmortizedOracleHook } from
    "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol";
import { RecordRedemptionPendlePTAmortizedOracleHook } from
    "../../../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol";
import { IPendleMarket } from "../../../../../src/vendor/pendle/IPendleMarket.sol";
import { MockPendlePTAmortizedOracle } from "../../../../mocks/MockPendlePTAmortizedOracle.sol";
import { MockPendleRouterSwapHook } from "../../../../mocks/MockPendleRouterSwapHook.sol";

/// @title PendlePTAmortizedOracleHooksForkTest
/// @notice Integration tests for oracle hooks using mainnet fork
contract PendlePTAmortizedOracleHooksForkTest is Test {
    // Mainnet addresses
    address constant SUPERUSDC_STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address constant SUPERWETH_STRATEGY = 0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2;
    address constant SUPERWBTC_STRATEGY = 0xa96060B0B6907406EdBDf3cCc9438abf0F78Cf83;

    // Pendle markets on mainnet (from Pendle docs)
    address constant PENDLE_MARKET_SUSDE_FEB2026 = 0xCdD26EB5eB2cE0f203a84553853667FB73f9dB13; // sUSDE 5 Feb 2026
    address constant PENDLE_MARKET_CUSD_JAN2026 = 0x73Dde2A75c06a108912BF7EF1942C88B98Efee17; // cUSD 29 Jan 2026

    RecordPurchasePendlePTAmortizedOracleHook public purchaseHook;
    RecordRedemptionPendlePTAmortizedOracleHook public redemptionHook;
    MockPendlePTAmortizedOracle public oracle;
    MockPendleRouterSwapHook public mockSwapHook;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        // Deploy mock oracle and hooks
        oracle = new MockPendlePTAmortizedOracle();
        purchaseHook = new RecordPurchasePendlePTAmortizedOracleHook(address(oracle));
        redemptionHook = new RecordRedemptionPendlePTAmortizedOracleHook(address(oracle));
        mockSwapHook = new MockPendleRouterSwapHook();
    }

    /*//////////////////////////////////////////////////////////////
                        MAINNET MARKET VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_Fork_ValidatePendleMarkets() public view {
        console2.log("=== Validating Pendle Markets ===");

        // Validate sUSDE market
        if (PENDLE_MARKET_SUSDE_FEB2026.code.length > 0) {
            (address sy, address pt, address yt) = IPendleMarket(PENDLE_MARKET_SUSDE_FEB2026).readTokens();
            console2.log("sUSDE Market:", PENDLE_MARKET_SUSDE_FEB2026);
            console2.log("  SY:", sy);
            console2.log("  PT:", pt);
            console2.log("  YT:", yt);
        } else {
            console2.log("sUSDE Market not deployed");
        }

        // Validate cUSD market
        if (PENDLE_MARKET_CUSD_JAN2026.code.length > 0) {
            (address sy, address pt, address yt) = IPendleMarket(PENDLE_MARKET_CUSD_JAN2026).readTokens();
            console2.log("cUSD Market:", PENDLE_MARKET_CUSD_JAN2026);
            console2.log("  SY:", sy);
            console2.log("  PT:", pt);
            console2.log("  YT:", yt);
        } else {
            console2.log("cUSD Market not deployed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    PURCHASE HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_PurchaseHook_SimulateStrategyPurchase() public {
        // Simulate a strategy recording a purchase
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 sySpent = 1000e6; // 1000 USDC worth of SY
        uint256 ptAmount = 1050e6; // 1050 PT received (5% discount)

        bytes memory data = _encodePurchaseData(market, sySpent, ptAmount, false);

        // Get the execution to be performed
        Execution[] memory executions = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, data);

        // Verify execution structure
        assertEq(executions.length, 3); // preExecute + oracle call + postExecute
        assertEq(executions[1].target, address(oracle));

        // Execute the oracle call as the strategy would
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "Oracle call failed");

        // Verify oracle recorded the purchase
        assertEq(oracle.getPurchaseCount(), 1);
        MockPendlePTAmortizedOracle.PurchaseRecord memory record = oracle.getLastPurchase();
        assertEq(record.caller, SUPERUSDC_STRATEGY);
        assertEq(record.market, market);
        assertEq(record.sySpent, sySpent);
        assertEq(record.ptAmount, ptAmount);
    }

    /// @notice Tests realistic purchase flow: PendleRouterSwapHook (swapExactTokenForPt) → RecordPurchaseHook
    /// @dev In this flow:
    ///      1. PendleRouterSwapHook swaps token → PT, sets outAmount = PT received
    ///      2. RecordPurchaseHook reads ptAmount from prev hook's outAmount (usePrevHookAmount=true)
    function test_Fork_PurchaseHook_WithPrevHookAmount_RealisticFlow() public {
        // Simulate PendleRouterSwapHook output after swapExactTokenForPt
        // The swap hook's outAmount is the PT received
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 sySpent = 1000e6; // SY input to swap (known ahead of time)
        uint256 ptFromSwap = 1100e6; // PT received from swap (from prev hook's outAmount)

        // Mock the swap hook's output (PT received)
        mockSwapHook.setOutAmount(SUPERUSDC_STRATEGY, ptFromSwap);

        // usePrevHookAmount = true means ptAmount comes from swap hook's outAmount
        bytes memory data = _encodePurchaseData(market, sySpent, 0, true);

        Execution[] memory executions = purchaseHook.build(address(mockSwapHook), SUPERUSDC_STRATEGY, data);

        // Execute as strategy
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success);

        // Verify ptAmount came from swap hook's outAmount (PT received)
        MockPendlePTAmortizedOracle.PurchaseRecord memory record = oracle.getLastPurchase();
        assertEq(record.ptAmount, ptFromSwap);
        assertEq(record.sySpent, sySpent);
    }

    function test_Fork_PurchaseHook_MultiplePurchases() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;

        // First purchase
        bytes memory data1 = _encodePurchaseData(market, 1000e6, 1050e6, false);
        Execution[] memory exec1 = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, data1);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = exec1[1].target.call(exec1[1].callData);
        assertTrue(success1);

        // Second purchase
        bytes memory data2 = _encodePurchaseData(market, 500e6, 520e6, false);
        Execution[] memory exec2 = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, data2);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success2,) = exec2[1].target.call(exec2[1].callData);
        assertTrue(success2);

        assertEq(oracle.getPurchaseCount(), 2);
        assertEq(oracle.getBookValue(SUPERUSDC_STRATEGY, market), 1500e6); // 1000 + 500
    }

    /*//////////////////////////////////////////////////////////////
                   REDEMPTION HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests realistic redemption flow: RecordRedemptionHook → PendleRouterSwapHook (swapExactPtForToken)
    /// @dev In this flow:
    ///      1. RecordRedemptionHook records ptSold (passed directly, known ahead of time)
    ///      2. PendleRouterSwapHook swaps PT → token, sets outAmount = token received
    /// @dev ptSold is the INPUT to the swap, so it's passed directly (usePrevHookAmount=false)
    function test_Fork_RedemptionHook_RealisticFlow_PtSoldPassedDirectly() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptSold = 500e6; // Known ahead of time - this is the input to swapExactPtForToken

        // ptSold is passed directly since it's the swap input (not output from prev hook)
        bytes memory data = _encodeRedemptionData(market, ptSold, false);

        Execution[] memory executions = redemptionHook.build(address(0), SUPERUSDC_STRATEGY, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(oracle));

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success);

        assertEq(oracle.getRedemptionCount(), 1);
        MockPendlePTAmortizedOracle.RedemptionRecord memory record = oracle.getLastRedemption();
        assertEq(record.caller, SUPERUSDC_STRATEGY);
        assertEq(record.market, market);
        assertEq(record.ptSold, ptSold);
    }

    /// @notice Tests redemption with usePrevHookAmount when PT comes from another source
    /// @dev This flow is useful when PT amount comes from a previous hook (e.g., transfer hook, unstake hook)
    ///      NOT from PendleRouterSwapHook's swapExactPtForToken (which outputs underlying token, not PT)
    function test_Fork_RedemptionHook_WithPrevHookAmount_PtFromAnotherSource() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptFromPrevHook = 750e6; // PT amount from another hook (e.g., transfer, unstake)

        // Simulate PT coming from a previous hook (NOT from swapExactPtForToken)
        mockSwapHook.setOutAmount(SUPERUSDC_STRATEGY, ptFromPrevHook);

        bytes memory data = _encodeRedemptionData(market, 0, true);

        Execution[] memory executions = redemptionHook.build(address(mockSwapHook), SUPERUSDC_STRATEGY, data);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success);

        MockPendlePTAmortizedOracle.RedemptionRecord memory record = oracle.getLastRedemption();
        assertEq(record.ptSold, ptFromPrevHook);
    }

    /*//////////////////////////////////////////////////////////////
                    FULL LIFECYCLE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests the complete purchase → redemption lifecycle
    /// @dev Purchase flow: PendleRouterSwapHook (token→PT) → RecordPurchaseHook (usePrevHookAmount=true)
    /// @dev Redemption flow: RecordRedemptionHook (ptSold direct) → PendleRouterSwapHook (PT→token)
    function test_Fork_FullLifecycle_PurchaseThenRedemption() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;

        // === PURCHASE PHASE ===
        // Strategy swaps 1000 SY → 1050 PT (5% discount typical for PT)
        uint256 sySpent = 1000e6;
        uint256 ptReceived = 1050e6;

        // Simulate PendleRouterSwapHook output (PT received)
        mockSwapHook.setOutAmount(SUPERUSDC_STRATEGY, ptReceived);

        // Record purchase with ptAmount from swap hook
        bytes memory purchaseData = _encodePurchaseData(market, sySpent, 0, true);
        Execution[] memory purchaseExec = purchaseHook.build(address(mockSwapHook), SUPERUSDC_STRATEGY, purchaseData);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = purchaseExec[1].target.call(purchaseExec[1].callData);
        assertTrue(success1, "Purchase recording failed");

        // Verify purchase recorded
        assertEq(oracle.getBookValue(SUPERUSDC_STRATEGY, market), sySpent);
        assertTrue(oracle.hasPosition(SUPERUSDC_STRATEGY, market));

        // === REDEMPTION PHASE ===
        // Strategy sells 500 PT (partial redemption)
        uint256 ptToSell = 500e6;

        // Record redemption with ptSold passed directly (it's the swap input)
        bytes memory redemptionData = _encodeRedemptionData(market, ptToSell, false);
        Execution[] memory redemptionExec = redemptionHook.build(address(0), SUPERUSDC_STRATEGY, redemptionData);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success2,) = redemptionExec[1].target.call(redemptionExec[1].callData);
        assertTrue(success2, "Redemption recording failed");

        // Verify both operations recorded
        assertEq(oracle.getPurchaseCount(), 1);
        assertEq(oracle.getRedemptionCount(), 1);

        MockPendlePTAmortizedOracle.PurchaseRecord memory purchase = oracle.getLastPurchase();
        assertEq(purchase.sySpent, sySpent);
        assertEq(purchase.ptAmount, ptReceived);

        MockPendlePTAmortizedOracle.RedemptionRecord memory redemption = oracle.getLastRedemption();
        assertEq(redemption.ptSold, ptToSell);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-STRATEGY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_MultipleStrategies_IndependentRecords() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;

        // USDC strategy purchase
        bytes memory data1 = _encodePurchaseData(market, 1000e6, 1050e6, false);
        Execution[] memory exec1 = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, data1);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = exec1[1].target.call(exec1[1].callData);
        assertTrue(success1);

        // WETH strategy purchase (different amount)
        bytes memory data2 = _encodePurchaseData(market, 2000e18, 2100e18, false);
        Execution[] memory exec2 = purchaseHook.build(address(0), SUPERWETH_STRATEGY, data2);
        vm.prank(SUPERWETH_STRATEGY);
        (bool success2,) = exec2[1].target.call(exec2[1].callData);
        assertTrue(success2);

        // Verify independent book values
        assertEq(oracle.getBookValue(SUPERUSDC_STRATEGY, market), 1000e6);
        assertEq(oracle.getBookValue(SUPERWETH_STRATEGY, market), 2000e18);
        assertTrue(oracle.hasPosition(SUPERUSDC_STRATEGY, market));
        assertTrue(oracle.hasPosition(SUPERWETH_STRATEGY, market));
    }

    /*//////////////////////////////////////////////////////////////
                        GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_GasBenchmarks() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;

        // Benchmark purchase hook build
        bytes memory purchaseData = _encodePurchaseData(market, 1000e6, 1050e6, false);
        uint256 gasBefore = gasleft();
        purchaseHook.build(address(0), SUPERUSDC_STRATEGY, purchaseData);
        uint256 gasUsedBuild = gasBefore - gasleft();
        console2.log("Gas used - purchaseHook.build():", gasUsedBuild);

        // Benchmark oracle recordPurchase
        Execution[] memory executions = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, purchaseData);
        gasBefore = gasleft();
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        uint256 gasUsedRecord = gasBefore - gasleft();
        assertTrue(success);
        console2.log("Gas used - oracle.recordPurchase():", gasUsedRecord);

        // Benchmark redemption hook build
        bytes memory redemptionData = _encodeRedemptionData(market, 500e6, false);
        gasBefore = gasleft();
        redemptionHook.build(address(0), SUPERUSDC_STRATEGY, redemptionData);
        uint256 gasUsedRedemptionBuild = gasBefore - gasleft();
        console2.log("Gas used - redemptionHook.build():", gasUsedRedemptionBuild);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodePurchaseData(
        address market,
        uint256 sySpent,
        uint256 ptAmount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(market, sySpent, ptAmount, usePrevHookAmount);
    }

    function _encodeRedemptionData(
        address market,
        uint256 ptSold,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(market, ptSold, usePrevHookAmount);
    }
}
