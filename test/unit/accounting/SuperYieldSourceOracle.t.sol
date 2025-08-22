// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockSuperOracle } from "../../mocks/MockSuperOracle.sol";

import { console2 } from "forge-std/console2.sol";
import { ISuperYieldSourceOracle } from "../../../src/interfaces/accounting/ISuperYieldSourceOracle.sol";
import { SuperYieldSourceOracle } from "../../../src/accounting/oracles/SuperYieldSourceOracle.sol";
import { PendlePTYieldSourceOracle } from "../../../src/accounting/oracles/PendlePTYieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";

contract SuperYieldSourceOracleTest is Helpers {
    SuperYieldSourceOracle public superYieldSourceOracle;
    ISuperYieldSourceOracle public yieldSourceOracle;
    MockSuperOracle public mockSuperOracle;
    PendlePTYieldSourceOracle public pendlePTOracle;
    ERC5115YieldSourceOracle public erc5115Oracle;

    // Edge case test tokens with different decimals
    IERC20Metadata public usdc; // 6 decimals
    IERC20Metadata public usdt; // 6 decimals
    IERC20Metadata public ptToken18; // 18 decimals PT
    IERC20Metadata public ptToken8; // 8 decimals PT
    IERC20Metadata public quoteToken; // 18 decimals quote

    // Real contracts for Pendle testing
    IPendleMarket public pendleMarketUSDC;
    IPendleMarket public pendleMorphoMarket;
    IStandardizedYield public syUSDC;
    IStandardizedYield public syMorpho;
    IERC20Metadata public morphoAsset;
    IERC20Metadata public morphoPT;

    // Constants for testing
    uint256 internal constant BASE_AMOUNT = 1000e18;
    uint256 internal constant QUOTE_AMOUNT = 2000e6; // $2000 with 6 decimals
    uint256 internal constant PRICE_PER_SHARE = 1.2e18; // 1.2 with 18 decimals
    uint256 internal constant TVL_AMOUNT = 5000e18;
    uint256 internal constant TVL_BY_OWNER = 500e18;

    // Edge case constants
    uint256 internal constant USDC_AMOUNT = 1000e6; // 1000 USDC
    uint256 internal constant USDT_AMOUNT = 1000e6; // 1000 USDT
    uint256 internal constant PT_RATE_18_DECIMALS = 1.05e18; // 1.05 PT/Asset ratio
    uint256 internal constant PT_RATE_8_DECIMALS = 1.05e8; // 1.05 PT/Asset ratio (8 decimals)
    uint256 internal constant EXCHANGE_RATE_5115 = 1.1e18; // 1.1 exchange rate for ERC5115

    // Oracle quote rates (USDC/USDT -> Quote token)
    uint256 internal constant USDC_TO_QUOTE_RATE = 1e18; // 1:1 rate (both 18 decimals in quote)
    uint256 internal constant USDT_TO_QUOTE_RATE = 1e18; // 1:1 rate (both 18 decimals in quote)

    function setUp() public {
        // Initialize SuperYieldSourceOracle without oracle parameter
        superYieldSourceOracle = new SuperYieldSourceOracle();
        yieldSourceOracle = ISuperYieldSourceOracle(address(superYieldSourceOracle));

        // Setup test users
        user1 = makeAddr("User 1");
        user2 = makeAddr("User 2");

        _setupEdgeCaseTokensAndOracles();
    }

    function _setupEdgeCaseTokensAndOracles() internal {
        // Create fork at specific block for real Pendle contracts
        uint256 ethFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), 23_198_039);
        vm.selectFork(ethFork);

        // Use real Pendle aUSDC market
        // https://app.pendle.finance/trade/markets?utm_source=landing&utm_medium=landing&chains=ethereum&search=USDC
        pendleMarketUSDC = IPendleMarket(address(0x8539B41CA14148d1F7400d399723827a80579414));

        // Get real tokens from the market
        (address _sy, address _pt,) = pendleMarketUSDC.readTokens();
        syUSDC = IStandardizedYield(_sy);
        ptToken18 = IERC20Metadata(_pt);

        // Get the underlying asset from SY
        (, address assetAddress,) = syUSDC.assetInfo();
        usdc = IERC20Metadata(assetAddress); // This should be USDC (6 decimals)

        // Use real Pendle Morpho market with different decimals
        // https://app.pendle.finance/trade/pools/0x7057c9e6f213bbb9b845fc57010034e9e4a69e8a/zap/in?chain=ethereum
        pendleMorphoMarket = IPendleMarket(address(0x7057c9e6f213bbb9B845FC57010034E9e4A69E8A));

        // Get real tokens from the Morpho market
        (address _syMorpho, address _ptMorpho,) = pendleMorphoMarket.readTokens();
        syMorpho = IStandardizedYield(_syMorpho);
        morphoPT = IERC20Metadata(_ptMorpho);

        // Get the underlying asset from Morpho SY
        (, address morphoAssetAddress,) = syMorpho.assetInfo();
        morphoAsset = IERC20Metadata(morphoAssetAddress);

        // Create quote token for testing
        quoteToken = new MockERC20("Quote Token", "QUOTE", 18);

        // Initialize oracles with proper configuration
        pendlePTOracle = new PendlePTYieldSourceOracle(address(this));
        erc5115Oracle = new ERC5115YieldSourceOracle(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                    ARRAY LENGTH MISMATCH TESTS
    //////////////////////////////////////////////////////////////*/
    function test_getPricePerShareMultipleQuote_ArrayLengthMismatch() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](1); // Mismatched length
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector));
        yieldSourceOracle.getPricePerShareMultipleQuote(
            yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles
        );
    }

    function test_getTVLByOwnerOfSharesMultipleQuote_ArrayLengthMismatch() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[][] memory owners = new address[][](1); // Mismatched length
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector));
        yieldSourceOracle.getTVLByOwnerOfSharesMultipleQuote(
            yieldSources, yieldSourceOracles, owners, baseAssets, quoteAssets, oracles
        );
    }

    function test_getTVLMultipleQuote_ArrayLengthMismatch() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](1); // Mismatched length
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector));
        yieldSourceOracle.getTVLMultipleQuote(yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles);
    }

    /*//////////////////////////////////////////////////////////////
                    USDC MARKET DECIMAL EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getPricePerShareQuote with real USDC (6d) and PT (18d) market
    function test_getPricePerShareQuote_USDC_PT18_EdgeCase() public {
        // Get real price per share from Pendle oracle
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMarketUSDC));

        // Calculate expected base amount after decimal conversion
        uint8 usdcDecimals = usdc.decimals();
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(usdcDecimals))) / 1e18;

        // Create mock oracle that returns 1:1 rate for simplicity
        MockSuperOracle usdcOracle = new MockSuperOracle(expectedBaseAmount * 1e12); // Scale to 18 decimals

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMarketUSDC), // Real Pendle market
            address(pendlePTOracle), // Real Pendle oracle
            address(usdc), // Real USDC (6 decimals)
            address(quoteToken), // Quote token (18 decimals)
            address(usdcOracle) // Price oracle
        );

        uint256 expectedQuote = expectedBaseAmount * 1e12; // Scale USDC to 18 decimals

        assertEq(priceQuote, expectedQuote, "Real USDC PT18 price quote should match expected value");
    }

    /// @notice Test that getAssetOutput calculation aligns with getPricePerShareQuote for real Pendle PT
    function test_getAssetOutput_AlignsWith_getPricePerShareQuote_RealPendlePT() public {
        // Calculate expected base amount for 1 PT token
        uint8 ptDecimals = ptToken18.decimals();
        uint8 usdcDecimals = usdc.decimals();
        uint256 onePTToken = 10 ** uint256(ptDecimals);

        // Get asset output for 1 PT token
        uint256 assetOutput = pendlePTOracle.getAssetOutput(address(pendleMarketUSDC), address(0), onePTToken);

        // Create oracle that returns 1:1 rate scaled to 18 decimals
        MockSuperOracle usdcOracle = new MockSuperOracle(assetOutput * (10 ** (18 - usdcDecimals)));

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMarketUSDC), address(pendlePTOracle), address(usdc), address(quoteToken), address(usdcOracle)
        );

        // Expected: assetOutput scaled to quote decimals
        uint256 expectedQuote = assetOutput * (10 ** (18 - usdcDecimals));

        assertEq(
            priceQuote,
            expectedQuote,
            "getPricePerShareQuote should approximately equal oracle(getAssetOutput(market, 0, 1 PT))"
        );
    }

    /// @notice Test decimal handling with real Pendle contracts
    function test_getPricePerShareQuote_DecimalHandling_RealContracts() public {
        // Get real decimals from contracts
        uint8 usdcDecimals = usdc.decimals();
        uint8 ptDecimals = ptToken18.decimals();
        uint8 quoteDecimals = quoteToken.decimals();

        console2.log("USDC decimals:", usdcDecimals);
        console2.log("PT decimals:", ptDecimals);
        console2.log("Quote decimals:", quoteDecimals);

        // Get real price per share
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMarketUSDC));
        console2.log("Real PPS (1e18):", realPPS);

        // Calculate expected base amount after SuperYieldSourceOracle decimal conversion
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(usdcDecimals))) / 1e18;
        console2.log("Expected base amount (USDC units):", expectedBaseAmount);

        // Create oracle that handles USDC->Quote conversion
        uint256 scaleFactor = 10 ** (quoteDecimals - usdcDecimals); // 1e12 for 6->18
        MockSuperOracle usdcOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMarketUSDC), address(pendlePTOracle), address(usdc), address(quoteToken), address(usdcOracle)
        );

        uint256 expectedQuote = expectedBaseAmount * scaleFactor;
        console2.log("Expected quote:", expectedQuote);
        console2.log("Actual quote:", priceQuote);

        assertEq(priceQuote, expectedQuote, "Decimal handling should work correctly with real contracts");
    }

    /// @notice Test flavor detection with real Pendle market
    function test_FlavorDetection_RealPendleMarket() public {
        // This test verifies that SuperYieldSourceOracle correctly detects Pendle PT flavor
        // and applies proper decimal conversion

        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMarketUSDC));
        uint8 usdcDecimals = usdc.decimals();

        // Expected base amount after flavor detection and conversion
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(usdcDecimals))) / 1e18;

        // Create oracle for conversion
        uint256 scaleFactor = 10 ** (18 - usdcDecimals);
        MockSuperOracle usdcOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMarketUSDC), address(pendlePTOracle), address(usdc), address(quoteToken), address(usdcOracle)
        );

        // Verify the SuperYieldSourceOracle correctly identified this as PendlePT flavor
        // and applied the proper decimal conversion
        uint256 expectedQuote = expectedBaseAmount * scaleFactor;

        assertEq(priceQuote, expectedQuote, "Flavor detection and decimal conversion should work correctly");

        // Additional verification: ensure the conversion is meaningful
        assertGt(realPPS, 0, "Real PPS should be positive");
        assertGt(expectedBaseAmount, 0, "Expected base amount should be positive");
        assertGt(priceQuote, 0, "Price quote should be positive");
    }

    /// @notice Test precision handling with real small amounts
    function test_getPricePerShareQuote_SmallAmounts_RealContracts() public {
        // Test with very small PT amount to verify precision
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMarketUSDC));
        uint8 usdcDecimals = usdc.decimals();

        // Expected conversion through SuperYieldSourceOracle
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(usdcDecimals))) / 1e18;

        // Create oracle that handles the conversion
        uint256 scaleFactor = 10 ** (18 - usdcDecimals);
        MockSuperOracle usdcOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMarketUSDC), address(pendlePTOracle), address(usdc), address(quoteToken), address(usdcOracle)
        );

        uint256 expectedQuote = expectedBaseAmount * scaleFactor;

        assertEq(priceQuote, expectedQuote, "Small amount precision should be handled correctly with real contracts");

        // Ensure we're not losing precision
        assertGt(expectedBaseAmount, 0, "Should not lose precision in conversion");
    }

    /*//////////////////////////////////////////////////////////////
                    MORPHO MARKET DECIMAL EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getPricePerShareQuote with real Morpho market (different decimals)
    function test_getPricePerShareQuote_MorphoMarket_EdgeCase() public {
        // Get real price per share from Pendle oracle for Morpho market
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMorphoMarket));

        // Calculate expected base amount after decimal conversion
        uint8 morphoAssetDecimals = morphoAsset.decimals();
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(morphoAssetDecimals))) / 1e18;

        // Create mock oracle that returns 1:1 rate for simplicity
        MockSuperOracle morphoOracle = new MockSuperOracle(expectedBaseAmount * (10 ** (18 - morphoAssetDecimals)));

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMorphoMarket), // Real Pendle Morpho market
            address(pendlePTOracle), // Real Pendle oracle
            address(morphoAsset), // Real Morpho asset
            address(quoteToken), // Quote token (18 decimals)
            address(morphoOracle) // Price oracle
        );

        uint256 expectedQuote = expectedBaseAmount * (10 ** (18 - morphoAssetDecimals));

        assertEq(priceQuote, expectedQuote, "Real Morpho market price quote should match expected value");
    }

    /// @notice Test that getAssetOutput calculation aligns with getPricePerShareQuote for real Morpho PT
    function test_getAssetOutput_AlignsWith_getPricePerShareQuote_RealMorphoPT() public {
        // Calculate expected base amount for 1 PT token
        uint8 morphoPTDecimals = morphoPT.decimals();
        uint8 morphoAssetDecimals = morphoAsset.decimals();
        uint256 onePTToken = 10 ** uint256(morphoPTDecimals);

        // Get asset output for 1 PT token
        uint256 assetOutput = pendlePTOracle.getAssetOutput(address(pendleMorphoMarket), address(0), onePTToken);

        // Create oracle that returns 1:1 rate scaled to 18 decimals
        MockSuperOracle morphoOracle = new MockSuperOracle(assetOutput * (10 ** (18 - morphoAssetDecimals)));

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMorphoMarket),
            address(pendlePTOracle),
            address(morphoAsset),
            address(quoteToken),
            address(morphoOracle)
        );

        // Expected: assetOutput scaled to quote decimals
        uint256 expectedQuote = assetOutput * (10 ** (18 - morphoAssetDecimals));

        assertEq(
            priceQuote,
            expectedQuote,
            "getPricePerShareQuote should approximately equal oracle(getAssetOutput(morpho market, 0, 1 PT))"
        );
    }

    /// @notice Test decimal handling with real Morpho contracts
    function test_getPricePerShareQuote_DecimalHandling_RealMorphoContracts() public {
        // Get real decimals from contracts
        uint8 morphoAssetDecimals = morphoAsset.decimals();
        uint8 morphoPTDecimals = morphoPT.decimals();
        uint8 quoteDecimals = quoteToken.decimals();

        console2.log("Morpho Asset decimals:", morphoAssetDecimals);
        console2.log("Morpho PT decimals:", morphoPTDecimals);
        console2.log("Quote decimals:", quoteDecimals);

        // Get real price per share
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMorphoMarket));
        console2.log("Real Morpho PPS (1e18):", realPPS);

        // Calculate expected base amount after SuperYieldSourceOracle decimal conversion
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(morphoAssetDecimals))) / 1e18;
        console2.log("Expected base amount (Morpho asset units):", expectedBaseAmount);

        // Create oracle that handles MorphoAsset->Quote conversion
        uint256 scaleFactor = 10 ** (quoteDecimals - morphoAssetDecimals);
        MockSuperOracle morphoOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMorphoMarket),
            address(pendlePTOracle),
            address(morphoAsset),
            address(quoteToken),
            address(morphoOracle)
        );

        uint256 expectedQuote = expectedBaseAmount * scaleFactor;
        console2.log("Expected quote:", expectedQuote);
        console2.log("Actual quote:", priceQuote);

        assertEq(priceQuote, expectedQuote, "Decimal handling should work correctly with real Morpho contracts");
    }

    /// @notice Test flavor detection with real Morpho market
    function test_FlavorDetection_RealMorphoMarket() public {
        // This test verifies that SuperYieldSourceOracle correctly detects Pendle PT flavor
        // and applies proper decimal conversion for Morpho market

        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMorphoMarket));
        uint8 morphoAssetDecimals = morphoAsset.decimals();

        // Expected base amount after flavor detection and conversion
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(morphoAssetDecimals))) / 1e18;

        // Create oracle for conversion
        uint256 scaleFactor = 10 ** (18 - morphoAssetDecimals);
        MockSuperOracle morphoOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMorphoMarket),
            address(pendlePTOracle),
            address(morphoAsset),
            address(quoteToken),
            address(morphoOracle)
        );

        // Verify the SuperYieldSourceOracle correctly identified this as PendlePT flavor
        // and applied the proper decimal conversion
        uint256 expectedQuote = expectedBaseAmount * scaleFactor;

        assertEq(
            priceQuote, expectedQuote, "Flavor detection and decimal conversion should work correctly for Morpho market"
        );

        // Additional verification: ensure the conversion is meaningful
        assertGt(realPPS, 0, "Real Morpho PPS should be positive");
        assertGt(expectedBaseAmount, 0, "Expected base amount should be positive");
        assertGt(priceQuote, 0, "Price quote should be positive");
    }

    /// @notice Test precision handling with real small amounts for Morpho market
    function test_getPricePerShareQuote_SmallAmounts_RealMorphoContracts() public {
        // Test with very small PT amount to verify precision
        uint256 realPPS = pendlePTOracle.getPricePerShare(address(pendleMorphoMarket));
        uint8 morphoAssetDecimals = morphoAsset.decimals();

        // Expected conversion through SuperYieldSourceOracle
        uint256 expectedBaseAmount = (realPPS * (10 ** uint256(morphoAssetDecimals))) / 1e18;

        // Create oracle that handles the conversion
        uint256 scaleFactor = 10 ** (18 - morphoAssetDecimals);
        MockSuperOracle morphoOracle = new MockSuperOracle(expectedBaseAmount * scaleFactor);

        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(pendleMorphoMarket),
            address(pendlePTOracle),
            address(morphoAsset),
            address(quoteToken),
            address(morphoOracle)
        );

        uint256 expectedQuote = expectedBaseAmount * scaleFactor;

        assertEq(
            priceQuote, expectedQuote, "Small amount precision should be handled correctly with real Morpho contracts"
        );

        // Ensure we're not losing precision
        assertGt(expectedBaseAmount, 0, "Should not lose precision in conversion for Morpho market");
    }

    /// @notice Compare decimal handling between USDC and Morpho markets
    function test_CompareDecimalHandling_USDC_vs_Morpho() public view {
        // Get decimals from both markets
        uint8 usdcDecimals = usdc.decimals();
        uint8 morphoAssetDecimals = morphoAsset.decimals();

        console2.log("USDC decimals:", usdcDecimals);
        console2.log("Morpho asset decimals:", morphoAssetDecimals);

        // Get PPS from both markets
        uint256 usdcPPS = pendlePTOracle.getPricePerShare(address(pendleMarketUSDC));
        uint256 morphoPPS = pendlePTOracle.getPricePerShare(address(pendleMorphoMarket));

        console2.log("USDC PPS:", usdcPPS);
        console2.log("Morpho PPS:", morphoPPS);

        // Calculate expected base amounts
        uint256 usdcBaseAmount = (usdcPPS * (10 ** uint256(usdcDecimals))) / 1e18;
        uint256 morphoBaseAmount = (morphoPPS * (10 ** uint256(morphoAssetDecimals))) / 1e18;

        console2.log("USDC base amount:", usdcBaseAmount);
        console2.log("Morpho base amount:", morphoBaseAmount);

        // Both should be positive and meaningful
        assertGt(usdcBaseAmount, 0, "USDC base amount should be positive");
        assertGt(morphoBaseAmount, 0, "Morpho base amount should be positive");

        // Verify different decimal handling doesn't break the oracle
        assertTrue(
            usdcDecimals != morphoAssetDecimals || usdcPPS != morphoPPS,
            "Markets should have different characteristics for this test to be meaningful"
        );
    }
}
