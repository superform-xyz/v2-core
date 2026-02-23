// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";
import { PendlePTAmortizedOracleV2 } from "../../src/accounting/oracles/PendlePTAmortizedOracleV2.sol";

interface IPendlePTAmortizedOracle {
    function getBookValue(address strategy, address market) external view returns (uint256);
    function getPricePerShare(address market) external view returns (uint256);
    function getAssetOutput(address market, address owner, uint256 sharesIn) external view returns (uint256);
    function getTVLByOwnerOfShares(address market, address ownerOfShares) external view returns (uint256);
    function bookValues(
        address strategy,
        address market
    )
        external
        view
        returns (uint128 lastUpdateBookValue, uint64 lastUpdateTime);
    function MANAGER_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IPMarket {
    function readTokens() external view returns (address sy, address pt, address yt);
    function expiry() external view returns (uint256);
    function getPtToSyRate(uint32 twapDuration) external view returns (uint256);
    function getPtToAssetRate(uint32 twapDuration) external view returns (uint256);
}

interface IStandardizedYield {
    function assetInfo() external view returns (uint8 assetType, address assetAddress, uint8 assetDecimals);
    function exchangeRate() external view returns (uint256);
}

interface IPPrincipalToken {
    function expiry() external view returns (uint256);
}

/// @title V1vsV2OracleComparison
/// @notice Simulation to compare V1 and V2 Pendle PT Amortized Oracle behavior with real vault data
/// @dev Uses the same market/strategy from CorrectBookValueSim.t.sol
contract V1vsV2OracleComparison is Test {
    // Production addresses (same as CorrectBookValueSim.t.sol)
    address constant V1_ORACLE = 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62;
    address constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address constant MARKET = 0x6D520a943a4Da0784917a2e71defe95248A1DaA1;

    // For V2 oracle deployment
    address constant SUPER_LEDGER_CONFIG = 0x7d46C37B22e3DD0CDc3C6bDB2D71De33B2A48B80;

    PendlePTAmortizedOracleV2 public v2Oracle;

    function setUp() public {
        // Fork mainnet at a recent block
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        // Deploy V2 oracle
        v2Oracle = new PendlePTAmortizedOracleV2(address(this), SUPER_LEDGER_CONFIG);
    }

    /// @notice Test harness to manipulate V2 oracle storage for exact state matching
    function _setV2BookValueState(uint128 bookValue, uint64 timestamp) internal {
        // Storage layout: bookValues is at slot after AccessControl storage
        // mapping(address => mapping(address => BookValueState))
        // BookValueState is packed: uint128 lastUpdateBookValue + uint64 lastUpdateTime

        // Calculate storage slot for bookValues[STRATEGY][MARKET]
        bytes32 outerSlot = keccak256(abi.encode(STRATEGY, uint256(1))); // slot 1 for bookValues
        bytes32 innerSlot = keccak256(abi.encode(MARKET, outerSlot));

        // Pack the BookValueState: bookValue in lower 128 bits, timestamp in next 64 bits
        bytes32 packedValue = bytes32(uint256(bookValue) | (uint256(timestamp) << 128));

        vm.store(address(v2Oracle), innerSlot, packedValue);
    }

    /// @notice Compare V1 and V2 oracle outputs with IDENTICAL starting state and time progression
    function test_V1vsV2_Comparison() public {
        IPendlePTAmortizedOracle v1Oracle = IPendlePTAmortizedOracle(V1_ORACLE);

        // Get V1's current state
        (uint128 v1BookValueRaw, uint64 v1LastUpdateTime) = v1Oracle.bookValues(STRATEGY, MARKET);

        (, address pt,) = IPMarket(MARKET).readTokens();
        uint256 ptBalance = IERC20(pt).balanceOf(STRATEGY);
        uint256 maturity = IPPrincipalToken(pt).expiry();

        console.log("=== SIMULATION: V1 vs V2 with IDENTICAL STATE ===");
        console.log("Strategy:", STRATEGY);
        console.log("Market:", MARKET);
        console.log("PT Balance:", ptBalance / 1e18, "tokens");
        console.log("Maturity:", maturity);
        console.log("V1 lastUpdateBookValue:", v1BookValueRaw);
        console.log("V1 lastUpdateTime:", v1LastUpdateTime);
        console.log("");

        // Warp to V1's lastUpdateTime to start from same point
        vm.warp(v1LastUpdateTime);

        // Seed V2 with EXACT same state as V1 (same book value AND same timestamp)
        _setV2BookValueState(v1BookValueRaw, v1LastUpdateTime);

        // Verify both oracles have identical state
        (uint128 v2BookValueRaw, uint64 v2LastUpdateTime) = v2Oracle.bookValues(STRATEGY, MARKET);
        assertEq(v2BookValueRaw, v1BookValueRaw, "Book values should match");
        assertEq(v2LastUpdateTime, v1LastUpdateTime, "Timestamps should match");

        console.log("=== INITIAL STATE (t = lastUpdateTime) ===");
        uint256 v1BookValue = v1Oracle.getBookValue(STRATEGY, MARKET);
        uint256 v2BookValue = v2Oracle.getBookValue(STRATEGY, MARKET);
        console.log("V1 getBookValue:", v1BookValue);
        console.log("V2 getBookValue:", v2BookValue);
        assertEq(v1BookValue, v2BookValue, "Initial book values should be identical");
        console.log("PASS: Initial book values identical");
        console.log("");

        // Test at multiple time points until maturity
        uint256 timeToMaturity = maturity - v1LastUpdateTime;
        uint256[] memory checkpoints = new uint256[](5);
        checkpoints[0] = timeToMaturity / 4;      // 25%
        checkpoints[1] = timeToMaturity / 2;      // 50%
        checkpoints[2] = timeToMaturity * 3 / 4;  // 75%
        checkpoints[3] = timeToMaturity - 1;      // Just before maturity
        checkpoints[4] = timeToMaturity;          // At maturity

        string[5] memory labels = ["25%", "50%", "75%", "99%", "100% (maturity)"];

        for (uint256 i = 0; i < checkpoints.length; i++) {
            vm.warp(v1LastUpdateTime + checkpoints[i]);

            v1BookValue = v1Oracle.getBookValue(STRATEGY, MARKET);
            v2BookValue = v2Oracle.getBookValue(STRATEGY, MARKET);

            console.log("=== TIME:", labels[i], "===");
            console.log("Timestamp:", block.timestamp);
            console.log("V1 getBookValue:", v1BookValue);
            console.log("V2 getBookValue:", v2BookValue);

            // Assert they're equal (or very close due to rounding)
            assertApproxEqAbs(v1BookValue, v2BookValue, 1, string.concat("Book values should match at ", labels[i]));
            console.log("PASS: Book values match");
            console.log("");
        }

        // At maturity, book value should equal face value (PT balance)
        console.log("=== MATURITY CHECK ===");
        console.log("PT Balance (face value):", ptBalance);
        console.log("V1 Book Value at maturity:", v1BookValue);
        console.log("V2 Book Value at maturity:", v2BookValue);
        assertEq(v1BookValue, ptBalance, "V1 book value should equal face value at maturity");
        assertEq(v2BookValue, ptBalance, "V2 book value should equal face value at maturity");
        console.log("PASS: Both oracles return face value at maturity");
    }

    /// @notice Test getPricePerShare is identical between V1 and V2
    function test_V1vsV2_PricePerShare() public {
        IPendlePTAmortizedOracle v1Oracle = IPendlePTAmortizedOracle(V1_ORACLE);

        uint256 v1Price = v1Oracle.getPricePerShare(MARKET);
        uint256 v2Price = v2Oracle.getPricePerShare(MARKET);

        console.log("=== PRICE PER SHARE COMPARISON ===");
        console.log("V1 getPricePerShare:", v1Price);
        console.log("V2 getPricePerShare:", v2Price);

        assertEq(v1Price, v2Price, "getPricePerShare should be identical");
        console.log("PASS: getPricePerShare identical between V1 and V2");
    }

    /// @notice Test getAssetOutput is identical between V1 and V2
    function test_V1vsV2_GetAssetOutput() public {
        IPendlePTAmortizedOracle v1Oracle = IPendlePTAmortizedOracle(V1_ORACLE);

        (, address pt,) = IPMarket(MARKET).readTokens();
        uint256 ptBalance = IERC20(pt).balanceOf(STRATEGY);

        uint256 v1AssetOutput = v1Oracle.getAssetOutput(MARKET, address(0), ptBalance);
        uint256 v2AssetOutput = v2Oracle.getAssetOutput(MARKET, address(0), ptBalance);

        console.log("=== GET ASSET OUTPUT COMPARISON ===");
        console.log("PT Balance:", ptBalance);
        console.log("V1 getAssetOutput:", v1AssetOutput);
        console.log("V2 getAssetOutput:", v2AssetOutput);

        assertEq(v1AssetOutput, v2AssetOutput, "getAssetOutput should be identical");
        console.log("PASS: getAssetOutput identical between V1 and V2");
    }

    /// @notice Simulate what happens if we record a new purchase in V2
    function test_V2_SimulateNewPurchase() public {
        console.log("=== V2: SIMULATE NEW PURCHASE ===");

        // Get current market state
        (, address pt,) = IPMarket(MARKET).readTokens();
        uint256 currentPtBalance = IERC20(pt).balanceOf(STRATEGY);

        console.log("Current PT Balance:", currentPtBalance);
        console.log("Current PT Balance (tokens):", currentPtBalance / 1e18);

        // Simulate purchasing 10,000 additional PT
        uint256 additionalPt = 10_000e18;

        // Mock the strategy having more PT
        vm.mockCall(
            pt, abi.encodeWithSelector(IERC20.balanceOf.selector, STRATEGY), abi.encode(currentPtBalance + additionalPt)
        );

        // Record purchase via V2 oracle
        vm.prank(STRATEGY);
        v2Oracle.recordPurchase(MARKET, additionalPt, 900); // 15 min TWAP

        // Check the resulting state
        (uint128 bookValueRaw,) = v2Oracle.bookValues(STRATEGY, MARKET);
        uint256 bookValue = v2Oracle.getBookValue(STRATEGY, MARKET);

        console.log("");
        console.log("After recording purchase of", additionalPt / 1e18, "PT:");
        console.log("New lastUpdateBookValue:", bookValueRaw);
        console.log("New getBookValue:", bookValue);

        // Assert: book value should be less than PT amount (discounted)
        assertLt(bookValue, additionalPt, "Book value should be less than PT amount (discounted)");

        // Assert: book value should be approximately PT * rate (~0.9958)
        // Allow 5% tolerance for rate variations
        assertApproxEqRel(bookValue, additionalPt * 9958 / 10000, 0.05e18, "Book value should reflect PT-to-SY rate");

        console.log("PASS: V2 correctly calculates sySpent on-chain using getPtToSyRate");
    }

    /// @notice Test min TWAP duration enforcement
    function test_V2_MinTwapEnforcement() public {
        console.log("=== V2: MIN TWAP DURATION ENFORCEMENT ===");

        (, address pt,) = IPMarket(MARKET).readTokens();
        uint256 currentPtBalance = IERC20(pt).balanceOf(STRATEGY);

        // Mock having some PT
        vm.mockCall(pt, abi.encodeWithSelector(IERC20.balanceOf.selector, STRATEGY), abi.encode(currentPtBalance + 1000e18));

        // Try with spot price (should fail)
        vm.prank(STRATEGY);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        v2Oracle.recordPurchase(MARKET, 1000e18, 0);
        console.log("PASS: Reverted for twapDuration=0 (spot price)");

        // Try with 299s (just below default minimum)
        vm.prank(STRATEGY);
        vm.expectRevert(PendlePTAmortizedOracleV2.TWAP_DURATION_TOO_SHORT.selector);
        v2Oracle.recordPurchase(MARKET, 1000e18, 299);
        console.log("PASS: Reverted for twapDuration=299 (below minimum)");

        // With 300s (exactly at default minimum - should succeed)
        vm.prank(STRATEGY);
        v2Oracle.recordPurchase(MARKET, 1000e18, 300);
        console.log("PASS: Succeeded for twapDuration=300 (at minimum)");

        // Assert default min TWAP
        assertEq(v2Oracle.DEFAULT_MIN_TWAP_DURATION(), 300, "DEFAULT_MIN_TWAP_DURATION should be 300");
        assertEq(v2Oracle.getMinTwapDuration(MARKET), 300, "getMinTwapDuration should return default when not configured");
    }
}
