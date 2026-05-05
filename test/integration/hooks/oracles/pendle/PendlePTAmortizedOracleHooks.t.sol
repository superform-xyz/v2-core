// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTAmortizedOracleHook } from
    "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol";
import { RecordRedemptionPendlePTAmortizedOracleHook } from
    "../../../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol";
import { RecordPurchasePendlePTAmortizedOracleHookV2 } from
    "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol";
import { IPendleMarket } from "../../../../../src/vendor/pendle/IPendleMarket.sol";
import { MockPendlePTAmortizedOracle } from "../../../../mocks/MockPendlePTAmortizedOracle.sol";
import { MockPendlePTAmortizedOracleV2 } from "../../../../mocks/MockPendlePTAmortizedOracleV2.sol";
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

    // V1 hooks and oracle
    RecordPurchasePendlePTAmortizedOracleHook public purchaseHook;
    RecordRedemptionPendlePTAmortizedOracleHook public redemptionHook;
    MockPendlePTAmortizedOracle public oracle;

    // V2 hooks and oracle
    RecordPurchasePendlePTAmortizedOracleHookV2 public purchaseHookV2;
    MockPendlePTAmortizedOracleV2 public oracleV2;

    MockPendleRouterSwapHook public mockSwapHook;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        // Deploy V1 mock oracle and hooks
        oracle = new MockPendlePTAmortizedOracle();
        purchaseHook = new RecordPurchasePendlePTAmortizedOracleHook(address(oracle));
        redemptionHook = new RecordRedemptionPendlePTAmortizedOracleHook(address(oracle));

        // Deploy V2 mock oracle and hooks
        oracleV2 = new MockPendlePTAmortizedOracleV2();
        purchaseHookV2 = new RecordPurchasePendlePTAmortizedOracleHookV2(address(oracleV2));

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

    /// @notice Encode V2 purchase data: market + ptAmount + twapDuration + usePrevHookAmount
    /// @dev V2 key difference: no sySpent, adds twapDuration instead
    function _encodePurchaseDataV2(
        address market,
        uint256 ptAmount,
        uint32 twapDuration,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(market, ptAmount, twapDuration, usePrevHookAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    V2 PURCHASE HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2: recordPurchase takes ptBought and twapDuration (no sySpent)
    /// @dev Oracle calculates sySpent from on-chain PT rate
    function test_Fork_V2_PurchaseHook_SimulateStrategyPurchase() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptAmount = 1050e6; // PT to record
        uint32 twapDuration = 900; // 15 min TWAP

        bytes memory data = _encodePurchaseDataV2(market, ptAmount, twapDuration, false);

        // Get the execution to be performed
        Execution[] memory executions = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, data);

        // Verify execution structure
        assertEq(executions.length, 3); // preExecute + oracle call + postExecute
        assertEq(executions[1].target, address(oracleV2));

        // Execute the oracle call as the strategy would
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "V2 Oracle call failed");

        // Verify oracle recorded the purchase
        assertEq(oracleV2.getPurchaseCount(), 1);
        MockPendlePTAmortizedOracleV2.PurchaseRecord memory record = oracleV2.getLastPurchase();
        assertEq(record.caller, SUPERUSDC_STRATEGY);
        assertEq(record.market, market);
        assertEq(record.ptBought, ptAmount);
        assertEq(record.twapDuration, twapDuration);
    }

    /// @notice V2: Test with different TWAP durations (spot price, 10 min, 15 min)
    function test_Fork_V2_PurchaseHook_DifferentTwapDurations() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptAmount = 1000e6;

        // Test spot price (twapDuration = 0)
        bytes memory dataSpot = _encodePurchaseDataV2(market, ptAmount, 0, false);
        Execution[] memory execSpot = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, dataSpot);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = execSpot[1].target.call(execSpot[1].callData);
        assertTrue(success1);

        MockPendlePTAmortizedOracleV2.PurchaseRecord memory recordSpot = oracleV2.getLastPurchase();
        assertEq(recordSpot.twapDuration, 0);

        // Test 10 min TWAP
        bytes memory data10min = _encodePurchaseDataV2(market, ptAmount, 600, false);
        Execution[] memory exec10min = purchaseHookV2.build(address(0), SUPERWETH_STRATEGY, data10min);
        vm.prank(SUPERWETH_STRATEGY);
        (bool success2,) = exec10min[1].target.call(exec10min[1].callData);
        assertTrue(success2);

        MockPendlePTAmortizedOracleV2.PurchaseRecord memory record10min = oracleV2.getLastPurchase();
        assertEq(record10min.twapDuration, 600);

        // Test 15 min TWAP (default)
        bytes memory data15min = _encodePurchaseDataV2(market, ptAmount, 900, false);
        Execution[] memory exec15min = purchaseHookV2.build(address(0), SUPERWBTC_STRATEGY, data15min);
        vm.prank(SUPERWBTC_STRATEGY);
        (bool success3,) = exec15min[1].target.call(exec15min[1].callData);
        assertTrue(success3);

        MockPendlePTAmortizedOracleV2.PurchaseRecord memory record15min = oracleV2.getLastPurchase();
        assertEq(record15min.twapDuration, 900);
    }

    /// @notice V2: Tests realistic purchase flow with prev hook amount
    /// @dev Flow: PendleRouterSwapHook (swapExactTokenForPt) → RecordPurchaseHookV2
    function test_Fork_V2_PurchaseHook_WithPrevHookAmount_RealisticFlow() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptFromSwap = 1100e6; // PT received from swap (from prev hook's outAmount)
        uint32 twapDuration = 900;

        // Mock the swap hook's output (PT received)
        mockSwapHook.setOutAmount(SUPERUSDC_STRATEGY, ptFromSwap);

        // usePrevHookAmount = true means ptAmount comes from swap hook's outAmount
        bytes memory data = _encodePurchaseDataV2(market, 0, twapDuration, true);

        Execution[] memory executions = purchaseHookV2.build(address(mockSwapHook), SUPERUSDC_STRATEGY, data);

        // Execute as strategy
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success);

        // Verify ptAmount came from swap hook's outAmount
        MockPendlePTAmortizedOracleV2.PurchaseRecord memory record = oracleV2.getLastPurchase();
        assertEq(record.ptBought, ptFromSwap);
        assertEq(record.twapDuration, twapDuration);
    }

    /// @notice V2: Multiple purchases accumulate book value
    function test_Fork_V2_PurchaseHook_MultiplePurchases() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint32 twapDuration = 900;

        // First purchase
        bytes memory data1 = _encodePurchaseDataV2(market, 1000e6, twapDuration, false);
        Execution[] memory exec1 = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, data1);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = exec1[1].target.call(exec1[1].callData);
        assertTrue(success1);

        // Second purchase
        bytes memory data2 = _encodePurchaseDataV2(market, 500e6, twapDuration, false);
        Execution[] memory exec2 = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, data2);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success2,) = exec2[1].target.call(exec2[1].callData);
        assertTrue(success2);

        assertEq(oracleV2.getPurchaseCount(), 2);
        assertTrue(oracleV2.hasPosition(SUPERUSDC_STRATEGY, market));
        // Mock calculates ~90% as book value: (1000 + 500) * 0.9 = 1350
        assertEq(oracleV2.getBookValue(SUPERUSDC_STRATEGY, market), 1350e6);
    }

    /*//////////////////////////////////////////////////////////////
                    V2 FULL LIFECYCLE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2: Full purchase → redemption lifecycle
    /// @dev Key V2 difference: purchase hook doesn't need sySpent, oracle calculates it
    function test_Fork_V2_FullLifecycle_PurchaseThenRedemption() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint32 twapDuration = 900;

        // === PURCHASE PHASE ===
        // Strategy receives 1050 PT from swap
        uint256 ptReceived = 1050e6;

        // Simulate PendleRouterSwapHook output (PT received)
        mockSwapHook.setOutAmount(SUPERUSDC_STRATEGY, ptReceived);

        // V2: Record purchase with ptAmount from swap hook, twapDuration passed
        // Oracle will calculate sySpent from on-chain PT rate
        bytes memory purchaseData = _encodePurchaseDataV2(market, 0, twapDuration, true);
        Execution[] memory purchaseExec = purchaseHookV2.build(address(mockSwapHook), SUPERUSDC_STRATEGY, purchaseData);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = purchaseExec[1].target.call(purchaseExec[1].callData);
        assertTrue(success1, "V2 Purchase recording failed");

        // Verify purchase recorded
        assertTrue(oracleV2.hasPosition(SUPERUSDC_STRATEGY, market));
        MockPendlePTAmortizedOracleV2.PurchaseRecord memory purchase = oracleV2.getLastPurchase();
        assertEq(purchase.ptBought, ptReceived);
        assertEq(purchase.twapDuration, twapDuration);

        // === REDEMPTION PHASE ===
        // Strategy sells 500 PT (partial redemption)
        // Note: V2 uses same redemption hook as V1 (no change needed)
        uint256 ptToSell = 500e6;

        bytes memory redemptionData = _encodeRedemptionData(market, ptToSell, false);
        Execution[] memory redemptionExec = redemptionHook.build(address(0), SUPERUSDC_STRATEGY, redemptionData);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success2,) = redemptionExec[1].target.call(redemptionExec[1].callData);
        assertTrue(success2, "Redemption recording failed");

        // Verify both operations recorded
        assertEq(oracleV2.getPurchaseCount(), 1);
        // Note: redemption goes to V1 oracle in this test (since redemption hook uses V1 oracle)
        assertEq(oracle.getRedemptionCount(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    V2 MULTI-STRATEGY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_V2_MultipleStrategies_IndependentRecords() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint32 twapDuration = 900;

        // USDC strategy purchase
        bytes memory data1 = _encodePurchaseDataV2(market, 1000e6, twapDuration, false);
        Execution[] memory exec1 = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, data1);
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = exec1[1].target.call(exec1[1].callData);
        assertTrue(success1);

        // WETH strategy purchase (different amount, different twap)
        bytes memory data2 = _encodePurchaseDataV2(market, 2000e18, 600, false);
        Execution[] memory exec2 = purchaseHookV2.build(address(0), SUPERWETH_STRATEGY, data2);
        vm.prank(SUPERWETH_STRATEGY);
        (bool success2,) = exec2[1].target.call(exec2[1].callData);
        assertTrue(success2);

        // Verify independent positions
        assertTrue(oracleV2.hasPosition(SUPERUSDC_STRATEGY, market));
        assertTrue(oracleV2.hasPosition(SUPERWETH_STRATEGY, market));
        // Mock calculates ~90% as book value
        assertEq(oracleV2.getBookValue(SUPERUSDC_STRATEGY, market), 900e6);
        assertEq(oracleV2.getBookValue(SUPERWETH_STRATEGY, market), 1800e18);
    }

    /*//////////////////////////////////////////////////////////////
                    V2 GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_V2_GasBenchmarks() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;

        // Benchmark V2 purchase hook build
        bytes memory purchaseData = _encodePurchaseDataV2(market, 1050e6, 900, false);
        uint256 gasBefore = gasleft();
        purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, purchaseData);
        uint256 gasUsedBuildV2 = gasBefore - gasleft();
        console2.log("Gas used - V2 purchaseHook.build():", gasUsedBuildV2);

        // Benchmark V2 oracle recordPurchase
        Execution[] memory executions = purchaseHookV2.build(address(0), SUPERUSDC_STRATEGY, purchaseData);
        gasBefore = gasleft();
        vm.prank(SUPERUSDC_STRATEGY);
        (bool success,) = executions[1].target.call(executions[1].callData);
        uint256 gasUsedRecordV2 = gasBefore - gasleft();
        assertTrue(success);
        console2.log("Gas used - V2 oracle.recordPurchase():", gasUsedRecordV2);

        // Compare with V1 (note: V1 requires sySpent which is extra computation off-chain)
        bytes memory purchaseDataV1 = _encodePurchaseData(market, 945e6, 1050e6, false);
        gasBefore = gasleft();
        purchaseHook.build(address(0), SUPERWETH_STRATEGY, purchaseDataV1);
        uint256 gasUsedBuildV1 = gasBefore - gasleft();
        console2.log("Gas used - V1 purchaseHook.build():", gasUsedBuildV1);

        console2.log("V2 vs V1 build gas difference:", int256(gasUsedBuildV2) - int256(gasUsedBuildV1));
    }

    /*//////////////////////////////////////////////////////////////
                    V1 vs V2 COMPARISON TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Compare V1 and V2 API differences
    /// @dev V1: needs sySpent passed (off-chain calculation required)
    /// @dev V2: only ptBought + twapDuration (on-chain calculation)
    function test_Fork_V1vsV2_ApiComparison() public {
        address market = PENDLE_MARKET_SUSDE_FEB2026;
        uint256 ptAmount = 1000e6;
        uint256 sySpentV1 = 900e6; // V1: must be calculated/passed off-chain
        uint32 twapDuration = 900;

        // V1: Requires sySpent to be calculated off-chain and passed
        bytes memory dataV1 = _encodePurchaseData(market, sySpentV1, ptAmount, false);
        Execution[] memory execV1 = purchaseHook.build(address(0), SUPERUSDC_STRATEGY, dataV1);

        vm.prank(SUPERUSDC_STRATEGY);
        (bool success1,) = execV1[1].target.call(execV1[1].callData);
        assertTrue(success1);

        // V2: Only needs ptBought + twapDuration, oracle calculates sySpent
        bytes memory dataV2 = _encodePurchaseDataV2(market, ptAmount, twapDuration, false);
        Execution[] memory execV2 = purchaseHookV2.build(address(0), SUPERWETH_STRATEGY, dataV2);

        vm.prank(SUPERWETH_STRATEGY);
        (bool success2,) = execV2[1].target.call(execV2[1].callData);
        assertTrue(success2);

        // V1 oracle records sySpent as passed
        MockPendlePTAmortizedOracle.PurchaseRecord memory recordV1 = oracle.getLastPurchase();
        assertEq(recordV1.sySpent, sySpentV1);
        assertEq(recordV1.ptAmount, ptAmount);

        // V2 oracle records ptBought and twapDuration
        MockPendlePTAmortizedOracleV2.PurchaseRecord memory recordV2 = oracleV2.getLastPurchase();
        assertEq(recordV2.ptBought, ptAmount);
        assertEq(recordV2.twapDuration, twapDuration);

        console2.log("=== V1 vs V2 API Comparison ===");
        console2.log("V1: sySpent passed off-chain:", sySpentV1);
        console2.log("V2: twapDuration for on-chain calc:", twapDuration);
        console2.log("V2 advantage: No off-chain price dependency, more secure");
    }
}
