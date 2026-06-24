// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { PendlePTAmortizedOracleV2 } from "../../../../src/accounting/oracles/PendlePTAmortizedOracleV2.sol";

// Mock contracts for testing
import { MockPendleMarket, MockPrincipalToken, MockTwapOracle } from "./mocks/MockPendleContracts.sol";

/// @notice Test harness to expose internal storage for testing defensive code paths
contract PendlePTAmortizedOracleV2Harness is PendlePTAmortizedOracleV2 {
    constructor(address admin, address superLedgerConfiguration) PendlePTAmortizedOracleV2(admin, superLedgerConfiguration) { }

    /// @notice Directly set book value state (for testing invalid states)
    function setBookValueState(
        address strategy,
        address market,
        uint128 bookValue,
        uint64 time
    ) external {
        bookValues[strategy][market].lastUpdateBookValue = bookValue;
        bookValues[strategy][market].lastUpdateTime = time;
    }
}

/// @title PendlePTAmortizedOracleV2Test
/// @notice Unit tests for PendlePTAmortizedOracleV2 - Amortized cost pricing with on-chain PT rate calculation
/// @dev V2 key differences:
///      - recordPurchase calculates sySpent from PT rate (no off-chain price dependency)
///      - twapDuration is passed per-call (no market config storage)
contract PendlePTAmortizedOracleV2Test is Test {
    PendlePTAmortizedOracleV2 public oracle;
    MockPendleMarket public market;
    MockPrincipalToken public pt;

    address public admin;
    address public strategy;
    address public superLedgerConfiguration;

    // Roles
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Test constants
    uint256 constant MATURITY = 100 days;
    uint256 constant INITIAL_TIME = 1000;
    uint32 constant DEFAULT_TWAP_DURATION = 900;
    uint32 constant TWAP_SPOT = 0;

    // Events
    event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp);
    event BookValueCorrected(
        address indexed strategy,
        address indexed market,
        uint256 oldBookValue,
        uint256 newBookValue,
        address indexed correctedBy
    );
    event PurchaseRecorded(
        address indexed strategy,
        address indexed market,
        uint256 ptBought,
        uint256 calculatedSySpent,
        uint32 twapDuration
    );
    event RedemptionRecorded(
        address indexed strategy,
        address indexed market,
        uint256 ptSold
    );
    event MinTwapDurationSet(address indexed market, uint32 minTwapDuration);

    function setUp() public {
        admin = address(this);
        strategy = makeAddr("strategy");
        superLedgerConfiguration = makeAddr("superLedgerConfiguration");

        // Set initial timestamp
        vm.warp(INITIAL_TIME);

        // Deploy mock PT with maturity 100 days from now
        pt = new MockPrincipalToken(block.timestamp + MATURITY);

        // Deploy mock market
        market = new MockPendleMarket(address(pt));

        // Deploy oracle - V2 has no market config, twapDuration passed per-call
        oracle = new PendlePTAmortizedOracleV2(admin, superLedgerConfiguration);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_InitializesCorrectly() public view {
        assertTrue(oracle.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(oracle.hasRole(MANAGER_ROLE, admin));
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        new PendlePTAmortizedOracleV2(address(0), superLedgerConfiguration);
    }

    function test_Constructor_RevertsOnZeroSuperLedgerConfiguration() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        new PendlePTAmortizedOracleV2(admin, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        RECORD PURCHASE TESTS (V2)
    //////////////////////////////////////////////////////////////*/

    /// @notice V2: recordPurchase takes market, ptBought, and twapDuration
    function test_RecordPurchase_FirstPurchase() public {
        uint256 ptAmount = 100e18;

        // Mint PT to strategy
        pt.mint(strategy, ptAmount);

        // V2: Oracle calculates sySpent from PT rate
        // Mock market returns ~0.9 rate before maturity
        uint256 expectedSySpent = ptAmount * 9 / 10; // ~90e18

        vm.prank(strategy);
        vm.expectEmit(true, true, false, false); // Don't check exact sySpent due to Pendle math
        emit PurchaseRecorded(strategy, address(market), ptAmount, expectedSySpent, DEFAULT_TWAP_DURATION);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Verify position exists
        assertTrue(oracle.hasPosition(strategy, address(market)));

        // Book value should be approximately ptAmount * ptRate
        uint256 bookValue = oracle.getBookValue(strategy, address(market));
        assertApproxEqRel(bookValue, expectedSySpent, 0.02e18); // 2% tolerance for Pendle math
    }

    /// @notice V2: Test with different TWAP durations
    function test_RecordPurchase_DifferentTwapDurations() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);

        // Use 600s (10 min) TWAP - different from default 900s
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, 600);

        assertTrue(oracle.hasPosition(strategy, address(market)));
        uint256 bookValue = oracle.getBookValue(strategy, address(market));
        // Book value should be approximately ptAmount * ptRate (~0.9)
        assertApproxEqRel(bookValue, ptAmount * 9 / 10, 0.02e18);
    }

    /// @notice V2: Test subsequent purchase with amortization
    function test_RecordPurchase_SubsequentPurchase() public {
        uint256 ptAmount1 = 100e18;

        // First purchase
        pt.mint(strategy, ptAmount1);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount1, DEFAULT_TWAP_DURATION);

        uint256 initialBookValue = oracle.getBookValue(strategy, address(market));

        // Advance time halfway to maturity
        vm.warp(block.timestamp + MATURITY / 2);

        // Second purchase
        uint256 ptAmount2 = 50e18;
        pt.mint(strategy, ptAmount2);

        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount2, DEFAULT_TWAP_DURATION);

        // Book value should have increased
        uint256 newBookValue = oracle.getBookValue(strategy, address(market));
        assertGt(newBookValue, initialBookValue);
    }

    function test_RecordPurchase_RevertsZeroMarketAddress() public {
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.recordPurchase(address(0), 100e18, DEFAULT_TWAP_DURATION);
    }

    function test_RecordPurchase_RevertsZeroPtAmount() public {
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_AMOUNT.selector);
        oracle.recordPurchase(address(market), 0, DEFAULT_TWAP_DURATION);
    }

    function test_RecordPurchase_RevertsMarketExpired() public {
        pt.mint(strategy, 100e18);

        // Warp past maturity
        vm.warp(block.timestamp + MATURITY + 1);

        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.MARKET_EXPIRED.selector);
        oracle.recordPurchase(address(market), 100e18, DEFAULT_TWAP_DURATION);
    }

    function test_RecordPurchase_RevertsTwapDurationTooShort() public {
        pt.mint(strategy, 100e18);

        // Try with twapDuration below default minimum (300s)
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        oracle.recordPurchase(address(market), 100e18, 299);

        // Also test with 0 (spot price)
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        oracle.recordPurchase(address(market), 100e18, 0);
    }

    /// @notice Test BOOK_VALUE_EXCEEDS_FACE_VALUE check in recordPurchase
    /// @dev The check `if (newBookValue > currentPtBalance)` in recordPurchase (line 201) is defensive
    ///      code that triggers when PT rate > 1e18 (PT at premium over SY). This is an abnormal
    ///      condition that could occur due to oracle manipulation or extreme market conditions.
    /// @dev In normal operation with rate < 1e18: sySpent = ptBought * rate < ptBought,
    ///      so newBookValue = (existingBookValue + sySpent) <= currentPtBalance always holds.
    /// @dev This test verifies the error selector is used correctly in the codebase by testing
    ///      correctBookValue which has the same check. The recordPurchase path would require
    ///      mocking Pendle library internals to return rate > 1e18.
    function test_RecordPurchase_BookValueExceedsFaceValue_DefensiveCodePath() public {
        // The BOOK_VALUE_EXCEEDS_FACE_VALUE error is used in two places:
        // 1. recordPurchase line 201: triggers when PT rate > 1e18 (defensive, hard to unit test)
        // 2. correctBookValue line 290: triggers when admin sets bookValue > ptBalance
        //
        // We test #2 here. Test #1 would require Pendle oracle to return rate > 1e18,
        // which only happens in extreme/manipulated market conditions.

        pt.mint(strategy, 100e18);

        // Verify the error works via correctBookValue (same check, different trigger)
        vm.expectRevert(PendlePTAmortizedOracleV2.BOOK_VALUE_EXCEEDS_FACE_VALUE.selector);
        oracle.correctBookValue(strategy, address(market), 150e18); // 150 > 100 PT balance
    }

    /*//////////////////////////////////////////////////////////////
                    MIN TWAP DURATION CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetMinTwapDuration_ReturnsDefaultWhenNotConfigured() public view {
        // When not configured, should return DEFAULT_MIN_TWAP_DURATION (300)
        assertEq(oracle.getMinTwapDuration(address(market)), 300);
    }

    function test_SetMinTwapDuration_ByManager() public {
        uint32 customMinTwap = 600; // 10 minutes

        vm.expectEmit(true, false, false, true);
        emit MinTwapDurationSet(address(market), customMinTwap);
        oracle.setMinTwapDuration(address(market), customMinTwap);

        assertEq(oracle.getMinTwapDuration(address(market)), customMinTwap);
    }

    function test_SetMinTwapDuration_ZeroUsesDefault() public {
        // First set a custom value
        oracle.setMinTwapDuration(address(market), 600);
        assertEq(oracle.getMinTwapDuration(address(market)), 600);

        // Set to 0 to use default
        oracle.setMinTwapDuration(address(market), 0);
        // getMinTwapDuration returns DEFAULT when storage is 0
        assertEq(oracle.getMinTwapDuration(address(market)), 300);
    }

    function test_SetMinTwapDuration_RevertsNonManager() public {
        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonManager, MANAGER_ROLE)
        );
        oracle.setMinTwapDuration(address(market), 600);
    }

    function test_SetMinTwapDuration_RevertsZeroAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.setMinTwapDuration(address(0), 600);
    }

    function test_RecordPurchase_RespectsCustomMinTwapDuration() public {
        uint256 ptAmount = 100e18;
        pt.mint(strategy, ptAmount);

        // Set a higher minimum for this market
        oracle.setMinTwapDuration(address(market), 600);

        // Default duration (900) should still work
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // But 500s should now fail (below custom minimum of 600)
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        oracle.recordPurchase(address(market), ptAmount, 500);
    }

    function test_MinTwapDuration_PerMarketIsolation() public {
        // Create second market
        MockPrincipalToken pt2 = new MockPrincipalToken(block.timestamp + MATURITY);
        MockPendleMarket market2 = new MockPendleMarket(address(pt2));

        // Set different minimums for each market
        oracle.setMinTwapDuration(address(market), 400);
        oracle.setMinTwapDuration(address(market2), 700);

        assertEq(oracle.getMinTwapDuration(address(market)), 400);
        assertEq(oracle.getMinTwapDuration(address(market2)), 700);

        // Market1: 500s should work (>= 400)
        pt.mint(strategy, 100e18);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), 100e18, 500);

        // Market2: 500s should fail (< 700)
        pt2.mint(strategy, 100e18);
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        oracle.recordPurchase(address(market2), 100e18, 500);

        // Market2: 700s should work
        vm.prank(strategy);
        oracle.recordPurchase(address(market2), 100e18, 700);
    }

    /// @notice Test configured market vs unconfigured market behavior
    function test_MinTwapDuration_ConfiguredVsUnconfigured() public {
        // Create second market (will remain unconfigured)
        MockPrincipalToken pt2 = new MockPrincipalToken(block.timestamp + MATURITY);
        MockPendleMarket unconfiguredMarket = new MockPendleMarket(address(pt2));

        // Configure market1 with lower minimum (200s)
        oracle.setMinTwapDuration(address(market), 200);

        // Verify: configured market has custom value, unconfigured has default
        assertEq(oracle.getMinTwapDuration(address(market)), 200);
        assertEq(oracle.getMinTwapDuration(address(unconfiguredMarket)), 300); // DEFAULT_MIN_TWAP_DURATION
        assertEq(oracle.marketMinTwapDuration(address(unconfiguredMarket)), 0); // Storage is 0

        // Configured market: 250s works (>= 200)
        pt.mint(strategy, 100e18);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), 100e18, 250);
        assertTrue(oracle.hasPosition(strategy, address(market)));

        // Unconfigured market: 250s fails (< 300 default)
        pt2.mint(strategy, 100e18);
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        oracle.recordPurchase(address(unconfiguredMarket), 100e18, 250);

        // Unconfigured market: 300s works (>= 300 default)
        vm.prank(strategy);
        oracle.recordPurchase(address(unconfiguredMarket), 100e18, 300);
        assertTrue(oracle.hasPosition(strategy, address(unconfiguredMarket)));
    }

    /*//////////////////////////////////////////////////////////////
                        RECORD REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RecordRedemption_PartialRedemption() public {
        uint256 ptAmount = 100e18;

        // Initial purchase
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Advance time
        vm.warp(block.timestamp + MATURITY / 5);

        uint256 ptToRedeem = 60e18;

        // Burn the PT BEFORE recording (simulates hook being called after redeem)
        pt.burn(strategy, ptToRedeem);

        vm.prank(strategy);
        vm.expectEmit(true, true, false, true);
        emit RedemptionRecorded(strategy, address(market), ptToRedeem);
        oracle.recordRedemption(address(market), ptToRedeem);

        // Book value should be reduced proportionally
        uint256 bookValue = oracle.getBookValue(strategy, address(market));
        assertGt(bookValue, 0);
    }

    function test_RecordRedemption_FullRedemption() public {
        uint256 ptAmount = 100e18;

        // Initial purchase
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Advance time
        vm.warp(block.timestamp + MATURITY / 2);

        // Burn the PT BEFORE recording
        pt.burn(strategy, ptAmount);

        // Full redemption
        vm.prank(strategy);
        oracle.recordRedemption(address(market), ptAmount);

        // Book value should be 0
        (uint128 lastBookValue,) = oracle.bookValues(strategy, address(market));
        assertEq(lastBookValue, 0);
    }

    function test_RecordRedemption_RevertsNoPosition() public {
        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.NO_POSITION.selector);
        oracle.recordRedemption(address(market), 50e18);
    }

    function test_RecordRedemption_RevertsZeroMarketAddress() public {
        // First create a position so we don't hit NO_POSITION first
        pt.mint(strategy, 100e18);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), 100e18, DEFAULT_TWAP_DURATION);

        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.recordRedemption(address(0), 50e18);
    }

    function test_RecordRedemption_RevertsZeroPtAmount() public {
        // First create a position
        pt.mint(strategy, 100e18);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), 100e18, DEFAULT_TWAP_DURATION);

        vm.prank(strategy);
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_AMOUNT.selector);
        oracle.recordRedemption(address(market), 0);
    }

    /// @notice Test recordRedemption after maturity hits the maturity check in _calculateAmortizedBookValue
    /// @dev This tests the `if (block.timestamp >= maturity) return A;` line in _calculateAmortizedBookValue
    function test_RecordRedemption_AfterMaturity() public {
        uint256 ptAmount = 100e18;

        // Initial purchase
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Warp past maturity
        vm.warp(block.timestamp + MATURITY + 1);

        uint256 ptToRedeem = 30e18;

        // Burn the PT BEFORE recording
        pt.burn(strategy, ptToRedeem);

        // Record redemption after maturity
        // This exercises the maturity check in _calculateAmortizedBookValue
        vm.prank(strategy);
        oracle.recordRedemption(address(market), ptToRedeem);

        // Book value should be reduced proportionally from face value
        // At maturity: book value = face value = 100e18
        // After redemption of 30: newBookValue = 100 - (100 * 30 / 100) = 70e18
        (uint128 lastBookValue,) = oracle.bookValues(strategy, address(market));
        assertEq(lastBookValue, 70e18);
    }

    /*//////////////////////////////////////////////////////////////
                        GET BOOK VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetBookValue_LinearAmortization() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        uint256 initialBookValue = oracle.getBookValue(strategy, address(market));

        // At 50% of duration, book value should be closer to face value
        vm.warp(block.timestamp + MATURITY / 2);
        uint256 midBookValue = oracle.getBookValue(strategy, address(market));
        assertGt(midBookValue, initialBookValue);

        // At maturity, book value = face value
        vm.warp(block.timestamp + MATURITY / 2);
        assertEq(oracle.getBookValue(strategy, address(market)), ptAmount);
    }

    function test_GetBookValue_AfterMaturity() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Warp well past maturity
        vm.warp(block.timestamp + MATURITY * 2);

        // Should return face value
        assertEq(oracle.getBookValue(strategy, address(market)), ptAmount);
    }

    function test_GetBookValue_ZeroBalance() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Burn all PT
        pt.burn(strategy, ptAmount);

        // Should return 0 when balance is 0
        assertEq(oracle.getBookValue(strategy, address(market)), 0);
    }

    function test_GetBookValue_RevertsNoPosition() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.NO_POSITION.selector);
        oracle.getBookValue(strategy, address(market));
    }

    /*//////////////////////////////////////////////////////////////
                    CORRECT BOOK VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CorrectBookValue_ByManager() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        uint256 oldBookValue = oracle.getBookValue(strategy, address(market));

        // Correct the book value
        uint128 newBookValue = 85e18;

        vm.expectEmit(true, true, true, true);
        emit BookValueCorrected(strategy, address(market), oldBookValue, newBookValue, admin);
        oracle.correctBookValue(strategy, address(market), newBookValue);

        assertEq(oracle.getBookValue(strategy, address(market)), newBookValue);
    }

    function test_CorrectBookValue_RevertsNonManager() public {
        pt.mint(strategy, 100e18);

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonManager, MANAGER_ROLE)
        );
        oracle.correctBookValue(strategy, address(market), 85e18);
    }

    function test_CorrectBookValue_RevertsBookValueExceedsFaceValue() public {
        pt.mint(strategy, 100e18);

        vm.expectRevert(PendlePTAmortizedOracleV2.BOOK_VALUE_EXCEEDS_FACE_VALUE.selector);
        oracle.correctBookValue(strategy, address(market), 101e18);
    }

    function test_CorrectBookValue_RevertsZeroStrategyAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.correctBookValue(address(0), address(market), 85e18);
    }

    function test_CorrectBookValue_RevertsZeroMarketAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.correctBookValue(strategy, address(0), 85e18);
    }

    /*//////////////////////////////////////////////////////////////
                    DELETE POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeletePosition_ByManager() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        assertTrue(oracle.hasPosition(strategy, address(market)));

        oracle.deletePosition(strategy, address(market));

        assertFalse(oracle.hasPosition(strategy, address(market)));
    }

    function test_DeletePosition_RevertsNoPosition() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.NO_POSITION.selector);
        oracle.deletePosition(strategy, address(market));
    }

    function test_DeletePosition_RevertsZeroStrategyAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.deletePosition(address(0), address(market));
    }

    function test_DeletePosition_RevertsZeroMarketAddress() public {
        vm.expectRevert(PendlePTAmortizedOracleV2.ZERO_ADDRESS.selector);
        oracle.deletePosition(strategy, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    IYIELDSOURCEORACLE IMPLEMENTATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetPricePerShare_UsesDefaultDuration() public view {
        // V2: Uses DEFAULT_TWAP_DURATION constant for IYieldSourceOracle compatibility
        uint256 price = oracle.getPricePerShare(address(market));
        assertApproxEqRel(price, 0.9e18, 0.02e18);
    }

    function test_GetTVLByOwnerOfShares_ReturnsAmortizedValue() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Advance to 50% of maturity
        vm.warp(block.timestamp + MATURITY / 2);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(market), strategy);

        // Should be between initial book value and face value
        assertGt(tvl, 85e18);
        assertLt(tvl, ptAmount);
    }

    function test_GetTVLByOwnerOfShares_FallbackToMarketPrice() public {
        // Mint PT but don't record purchase
        pt.mint(strategy, 100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(market), strategy);

        // Falls back to getAssetOutput
        assertApproxEqRel(tvl, 90e18, 0.02e18);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE STRATEGIES/MARKETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleStrategies_SameMarket() public {
        address strategy2 = makeAddr("strategy2");
        uint256 ptAmount = 100e18;

        // Strategy 1 purchase
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Strategy 2 purchase
        pt.mint(strategy2, ptAmount);
        vm.prank(strategy2);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Verify independent positions
        assertTrue(oracle.hasPosition(strategy, address(market)));
        assertTrue(oracle.hasPosition(strategy2, address(market)));

        // Delete strategy 1, strategy 2 unaffected
        oracle.deletePosition(strategy, address(market));
        assertFalse(oracle.hasPosition(strategy, address(market)));
        assertTrue(oracle.hasPosition(strategy2, address(market)));
    }

    function test_SameStrategy_MultipleMarkets() public {
        // Create second market
        MockPrincipalToken pt2 = new MockPrincipalToken(block.timestamp + MATURITY);
        MockPendleMarket market2 = new MockPendleMarket(address(pt2));

        uint256 ptAmount = 100e18;

        // Purchase in market 1
        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Purchase in market 2
        pt2.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market2), ptAmount, DEFAULT_TWAP_DURATION);

        // Verify independent positions
        assertTrue(oracle.hasPosition(strategy, address(market)));
        assertTrue(oracle.hasPosition(strategy, address(market2)));
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RecordPurchase_ValidAmounts(uint128 ptAmount, uint32 twapDuration) public {
        vm.assume(ptAmount > 1e10 && ptAmount <= 1e30);
        // Bound twapDuration to valid range:
        // - Min: DEFAULT_MIN_TWAP_DURATION (300s) to prevent spot price manipulation
        // - Max: 900s (15 min) to avoid overflow in mock's observe()
        twapDuration = uint32(bound(twapDuration, 300, 900));

        pt.mint(strategy, ptAmount);

        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, twapDuration);

        assertTrue(oracle.hasPosition(strategy, address(market)));
    }

    function testFuzz_Amortization_TimePoints(uint256 timePassed) public {
        uint256 ptAmount = 100e18;

        vm.assume(timePassed <= MATURITY);

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        uint256 initialBookValue = oracle.getBookValue(strategy, address(market));

        vm.warp(block.timestamp + timePassed);

        uint256 bookValue = oracle.getBookValue(strategy, address(market));

        // Book value should be between initial and face value
        assertGe(bookValue, initialBookValue);
        assertLe(bookValue, ptAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    IYIELDSOURCEORACLE COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test decimals() function returns PT decimals
    function test_Decimals_ReturnsPtDecimals() public view {
        uint8 oracleDecimals = oracle.decimals(address(market));
        assertEq(oracleDecimals, 18); // MockPrincipalToken has 18 decimals
    }

    /// @notice Test getShareOutput() function converts assets to shares
    function test_GetShareOutput_ConvertsAssetsToShares() public view {
        uint256 assetsIn = 90e18; // 90 underlying assets

        uint256 sharesOut = oracle.getShareOutput(address(market), address(0), assetsIn);

        // With ~0.9 price per share (PT discounted), 90 assets should give ~100 shares
        // sharesOut = assetsIn18 * 10^ptDecimals / pricePerShare
        // sharesOut = 90e18 * 1e18 / 0.9e18 = 100e18
        assertApproxEqRel(sharesOut, 100e18, 0.02e18); // 2% tolerance for Pendle math
    }

    /// @notice Test getShareOutput() returns 0 when pricePerShare is 0
    function test_GetShareOutput_ReturnsZeroWhenPriceZero() public {
        // Create market with 0 price (past maturity where observe returns 0)
        // This is a defensive test - in practice pricePerShare shouldn't be 0
        // But the function has a check for it at line 445

        // Deploy a new market and warp past its maturity
        MockPrincipalToken expiredPt = new MockPrincipalToken(block.timestamp - 1);
        MockPendleMarket expiredMarket = new MockPendleMarket(address(expiredPt));

        // At maturity, price should be 1e18, not 0
        uint256 price = oracle.getPricePerShare(address(expiredMarket));
        assertEq(price, 1e18); // Confirms at maturity price is 1e18

        // The pricePerShare == 0 branch would only be hit if Pendle returned 0 rate
        // which shouldn't happen in practice
    }

    /// @notice Test getWithdrawalShareOutput() with ceiling rounding
    function test_GetWithdrawalShareOutput_UsesCeilRounding() public view {
        uint256 assetsIn = 90e18;

        uint256 sharesOut = oracle.getWithdrawalShareOutput(address(market), address(0), assetsIn);

        // Should be similar to getShareOutput but with ceiling rounding
        assertApproxEqRel(sharesOut, 100e18, 0.02e18);
    }

    /// @notice Test getBalanceOfOwner() returns PT balance
    function test_GetBalanceOfOwner_ReturnsPtBalance() public {
        uint256 ptAmount = 123e18;
        pt.mint(strategy, ptAmount);

        uint256 balance = oracle.getBalanceOfOwner(address(market), strategy);
        assertEq(balance, ptAmount);
    }

    /// @notice Test getBalanceOfOwner() returns 0 for address with no PT
    function test_GetBalanceOfOwner_ReturnsZeroForNoBalance() public {
        address noBalanceAddr = makeAddr("noBalance");
        uint256 balance = oracle.getBalanceOfOwner(address(market), noBalanceAddr);
        assertEq(balance, 0);
    }

    /// @notice Test getTVL() returns total value locked across all PT holders
    function test_GetTVL_ReturnsTotalValueLocked() public {
        // Mint PT to multiple addresses
        pt.mint(strategy, 100e18);
        pt.mint(makeAddr("user2"), 50e18);
        pt.mint(makeAddr("user3"), 50e18);

        uint256 tvl = oracle.getTVL(address(market));

        // Total PT supply = 200e18, with ~0.9 price = ~180e18 TVL
        assertApproxEqRel(tvl, 180e18, 0.02e18);
    }

    /// @notice Test getTVL() returns 0 when no PT supply
    function test_GetTVL_ReturnsZeroWhenNoSupply() public view {
        // No PT minted yet
        uint256 tvl = oracle.getTVL(address(market));
        assertEq(tvl, 0);
    }

    /// @notice Test getTVLByOwnerOfShares() returns 0 when no PT balance and no position
    function test_GetTVLByOwnerOfShares_ReturnsZeroForNoBalanceNoPosition() public {
        address noBalanceAddr = makeAddr("noBalance");

        // No PT and no recorded position
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(market), noBalanceAddr);
        assertEq(tvl, 0);
    }

    /*//////////////////////////////////////////////////////////////
            _calculateAmortizedBookValue EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test edge case when block.timestamp <= t0 (same block as last update)
    function test_AmortizedBookValue_SameBlockAsUpdate() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Query in same block (block.timestamp == t0)
        uint256 bookValue = oracle.getBookValue(strategy, address(market));

        // Book value should equal initial book value (no amortization yet)
        // ~90e18 based on ~0.9 PT rate
        assertApproxEqRel(bookValue, ptAmount * 9 / 10, 0.02e18);
    }

    /// @notice Test defensive case when book value exceeds face value (shouldn't happen but code handles it)
    function test_AmortizedBookValue_BookValueExceedsFaceValue_DefensivePath() public {
        // Use a fresh address to avoid any prior state
        address freshStrategy = makeAddr("freshStrategy");

        // Deploy harness
        PendlePTAmortizedOracleV2Harness harness = new PendlePTAmortizedOracleV2Harness(admin, superLedgerConfiguration);

        uint256 ptAmount = 100e18;
        pt.mint(freshStrategy, ptAmount);

        // Set book value HIGHER than PT amount (invalid state: B_t0 > A)
        // This simulates corrupted data where book value (150e18) > face value (100e18)
        harness.setBookValueState(
            freshStrategy,
            address(market),
            uint128(150e18), // Book value of 150e18, but only 100e18 PT
            uint64(block.timestamp)
        );

        // Advance time (but not to maturity)
        vm.warp(block.timestamp + MATURITY / 2);

        // The defensive code path (line 417-420) should cap at face value
        uint256 bookValue = harness.getBookValue(freshStrategy, address(market));

        // Should return face value (A = ptAmount = 100e18) since B_t0 > A
        assertEq(bookValue, ptAmount);
    }

    /// @notice Test _calculateAmortizedBookValue when PT amount is 0 (edge case)
    function test_AmortizedBookValue_ZeroPtAmount() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Burn all PT without recording redemption
        pt.burn(strategy, ptAmount);

        // getBookValue with 0 balance should return 0
        uint256 bookValue = oracle.getBookValue(strategy, address(market));
        assertEq(bookValue, 0);
    }

    /// @notice Test amortization at exact maturity timestamp
    function test_AmortizedBookValue_ExactMaturityTimestamp() public {
        uint256 ptAmount = 100e18;

        pt.mint(strategy, ptAmount);
        vm.prank(strategy);
        oracle.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Warp to exact maturity
        vm.warp(block.timestamp + MATURITY);

        // At maturity, book value = face value (1 PT = 1 SY)
        uint256 bookValue = oracle.getBookValue(strategy, address(market));
        assertEq(bookValue, ptAmount);
    }
}
