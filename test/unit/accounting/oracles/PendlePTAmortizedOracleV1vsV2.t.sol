// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { PendlePTAmortizedOracle } from "../../../../src/accounting/oracles/PendlePTAmortizedOracle.sol";
import { PendlePTAmortizedOracleV2 } from "../../../../src/accounting/oracles/PendlePTAmortizedOracleV2.sol";
import { MockPendleMarket, MockPrincipalToken } from "./mocks/MockPendleContracts.sol";

/// @title PendlePTAmortizedOracleV1vsV2Test
/// @notice Comparison tests between V1 and V2 oracles demonstrating key differences
/// @dev V1: Requires sySpent as parameter (off-chain price calculation)
/// @dev V2: Calculates sySpent from on-chain PT rate (no off-chain dependency)
contract PendlePTAmortizedOracleV1vsV2Test is Test {
    PendlePTAmortizedOracle public oracleV1;
    PendlePTAmortizedOracleV2 public oracleV2;
    MockPendleMarket public market;
    MockPrincipalToken public pt;

    address public admin;
    address public strategyV1;
    address public strategyV2;
    address public superLedgerConfiguration;

    uint256 constant MATURITY = 100 days;
    uint256 constant INITIAL_TIME = 1000;
    uint32 constant DEFAULT_TWAP_DURATION = 900;

    function setUp() public {
        admin = address(this);
        strategyV1 = makeAddr("strategyV1");
        strategyV2 = makeAddr("strategyV2");
        superLedgerConfiguration = makeAddr("superLedgerConfiguration");

        vm.warp(INITIAL_TIME);

        // Deploy mock PT with maturity 100 days from now
        pt = new MockPrincipalToken(block.timestamp + MATURITY);

        // Deploy mock market
        market = new MockPendleMarket(address(pt));

        // Deploy both oracles
        oracleV1 = new PendlePTAmortizedOracle(admin, superLedgerConfiguration);
        oracleV2 = new PendlePTAmortizedOracleV2(admin, superLedgerConfiguration);
    }

    /// @notice Demonstrate the key API difference: V1 requires sySpent, V2 doesn't
    function test_ApiDifference_RecordPurchase() public {
        uint256 ptAmount = 100e18;

        // Mint PT to both strategies
        pt.mint(strategyV1, ptAmount);
        pt.mint(strategyV2, ptAmount);

        // V1: Must provide sySpent externally (off-chain calculation)
        // Simulating off-chain: user bought 100 PT for ~90 SY
        uint256 sySpent = 90e18;
        vm.prank(strategyV1);
        oracleV1.recordPurchase(address(market), sySpent, ptAmount);

        // V2: Only provide ptBought and twapDuration - oracle calculates sySpent
        // No off-chain price dependency!
        vm.prank(strategyV2);
        oracleV2.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Both should have positions
        assertTrue(oracleV1.hasPosition(strategyV1, address(market)));
        assertTrue(oracleV2.hasPosition(strategyV2, address(market)));

        // Book values should be similar (both ~90e18 for ~0.9 PT rate)
        uint256 bookValueV1 = oracleV1.getBookValue(strategyV1, address(market));
        uint256 bookValueV2 = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("V1 Book Value:", bookValueV1);
        console2.log("V2 Book Value:", bookValueV2);

        // Both should be approximately 90e18 (PT rate ~0.9)
        assertApproxEqRel(bookValueV1, 90e18, 0.02e18);
        assertApproxEqRel(bookValueV2, 90e18, 0.02e18);
    }

    /// @notice V1 risk: Off-chain manipulation could pass wrong sySpent
    /// @dev In V1, a malicious off-chain system could inflate/deflate sySpent
    function test_V1Risk_IncorrectSySpent() public {
        uint256 ptAmount = 100e18;
        pt.mint(strategyV1, ptAmount);

        // V1 Risk: Off-chain could pass wrong sySpent
        // Correct: ~90e18 (PT rate ~0.9)
        // Attacker passes: 50e18 (understates cost - inflates apparent profit)
        uint256 manipulatedSySpent = 50e18;

        vm.prank(strategyV1);
        oracleV1.recordPurchase(address(market), manipulatedSySpent, ptAmount);

        // Book value reflects the manipulated (incorrect) sySpent
        uint256 bookValue = oracleV1.getBookValue(strategyV1, address(market));
        assertEq(bookValue, manipulatedSySpent);

        console2.log("V1 with manipulated sySpent:", bookValue);
        console2.log("This is INCORRECT - should be ~90e18");
    }

    /// @notice V2 protection: sySpent calculated from on-chain PT rate
    /// @dev No matter what, V2 calculates sySpent from actual market data
    function test_V2Protection_OnChainCalculation() public {
        uint256 ptAmount = 100e18;
        pt.mint(strategyV2, ptAmount);

        // V2: Only pass ptBought and twapDuration
        // sySpent is calculated from on-chain PT rate - cannot be manipulated
        vm.prank(strategyV2);
        oracleV2.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Book value reflects actual market rate, not user-supplied value
        uint256 bookValue = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("V2 with on-chain calculation:", bookValue);
        console2.log("Always reflects market reality");

        // Should be ~90e18 based on market PT rate
        assertApproxEqRel(bookValue, 90e18, 0.02e18);
    }

    /// @notice Both oracles produce same results when used correctly
    function test_EquivalentResults_WhenUsedCorrectly() public {
        uint256 ptAmount = 100e18;
        pt.mint(strategyV1, ptAmount);
        pt.mint(strategyV2, ptAmount);

        // V1: User correctly calculates sySpent from PT rate
        uint256 ptRate = market.getPtToAssetRate(DEFAULT_TWAP_DURATION);
        uint256 correctSySpent = (ptAmount * ptRate) / 1e18;

        vm.prank(strategyV1);
        oracleV1.recordPurchase(address(market), correctSySpent, ptAmount);

        // V2: Oracle calculates sySpent internally
        vm.prank(strategyV2);
        oracleV2.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        uint256 bookValueV1 = oracleV1.getBookValue(strategyV1, address(market));
        uint256 bookValueV2 = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("V1 (correct sySpent):", bookValueV1);
        console2.log("V2 (on-chain calc):", bookValueV2);

        // When V1 is used correctly, results should be equivalent
        assertApproxEqRel(bookValueV1, bookValueV2, 0.02e18);
    }

    /// @notice V2 allows different TWAP durations per call
    /// @dev Flexibility for different markets without storage overhead
    function test_V2Flexibility_DifferentTwapDurations() public {
        // Strategy 1 uses 15-min TWAP
        pt.mint(strategyV1, 100e18);
        vm.prank(strategyV1);
        oracleV2.recordPurchase(address(market), 100e18, 900); // 15 min

        // Strategy 2 (same address, different market scenario) uses 10-min TWAP
        MockPrincipalToken pt2 = new MockPrincipalToken(block.timestamp + MATURITY);
        MockPendleMarket market2 = new MockPendleMarket(address(pt2));
        pt2.mint(strategyV1, 100e18);

        vm.prank(strategyV1);
        oracleV2.recordPurchase(address(market2), 100e18, 600); // 10 min

        // Both positions recorded with different TWAP settings
        assertTrue(oracleV2.hasPosition(strategyV1, address(market)));
        assertTrue(oracleV2.hasPosition(strategyV1, address(market2)));
    }

    /// @notice Amortization works the same in both versions
    function test_AmortizationBehavior_Equivalent() public {
        uint256 ptAmount = 100e18;
        pt.mint(strategyV1, ptAmount);
        pt.mint(strategyV2, ptAmount);

        // Record purchases
        uint256 sySpent = 90e18;
        vm.prank(strategyV1);
        oracleV1.recordPurchase(address(market), sySpent, ptAmount);

        vm.prank(strategyV2);
        oracleV2.recordPurchase(address(market), ptAmount, DEFAULT_TWAP_DURATION);

        // Get initial book values
        uint256 initialV1 = oracleV1.getBookValue(strategyV1, address(market));
        uint256 initialV2 = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("Initial V1:", initialV1);
        console2.log("Initial V2:", initialV2);

        // Advance to 50% maturity
        vm.warp(block.timestamp + MATURITY / 2);

        uint256 midV1 = oracleV1.getBookValue(strategyV1, address(market));
        uint256 midV2 = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("At 50% maturity V1:", midV1);
        console2.log("At 50% maturity V2:", midV2);

        // Both should have amortized (book value increased toward face value)
        assertGt(midV1, initialV1);
        assertGt(midV2, initialV2);

        // At maturity, both should equal face value
        vm.warp(block.timestamp + MATURITY / 2);

        uint256 finalV1 = oracleV1.getBookValue(strategyV1, address(market));
        uint256 finalV2 = oracleV2.getBookValue(strategyV2, address(market));

        console2.log("At maturity V1:", finalV1);
        console2.log("At maturity V2:", finalV2);

        assertEq(finalV1, ptAmount);
        assertEq(finalV2, ptAmount);
    }
}
