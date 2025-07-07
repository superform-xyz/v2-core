// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { MockSuperOracle } from "../../mocks/MockSuperOracle.sol";
import { MockYieldSourceOracle } from "../../mocks/MockYieldSourceOracle.sol";
import { ISuperYieldSourceOracle } from "../../../src/core/interfaces/accounting/ISuperYieldSourceOracle.sol";
import { SuperYieldSourceOracle } from "../../../src/core/accounting/oracles/SuperYieldSourceOracle.sol";

contract SuperYieldSourceOracleTest is Helpers {
    SuperYieldSourceOracle public superYieldSourceOracle;
    ISuperYieldSourceOracle public yieldSourceOracle;
    MockSuperOracle public mockSuperOracle;
    MockYieldSourceOracle public mockYieldSourceOracle;

    Mock4626Vault public yieldSource;
    MockERC20 public invalidAsset;
    MockERC20 public validAsset;

    // Constants for testing
    uint256 constant BASE_AMOUNT = 1000e18;
    uint256 constant QUOTE_AMOUNT = 2000e6; // $2000 with 6 decimals
    uint256 constant PRICE_PER_SHARE = 1.2e18; // 1.2 with 18 decimals
    uint256 constant TVL_AMOUNT = 5000e18;
    uint256 constant TVL_BY_OWNER = 500e18;

    function setUp() public {
        // Create mock oracles with predefined values
        mockSuperOracle = new MockSuperOracle(QUOTE_AMOUNT);
        mockYieldSourceOracle = new MockYieldSourceOracle(
            PRICE_PER_SHARE,
            TVL_AMOUNT,
            TVL_BY_OWNER,
            false // Default validity set to false
        );

        // Initialize SuperYieldSourceOracle without oracle parameter
        superYieldSourceOracle = new SuperYieldSourceOracle();
        yieldSourceOracle = ISuperYieldSourceOracle(address(superYieldSourceOracle));

        // Setup mock tokens and yield source
        invalidAsset = new MockERC20("Invalid Asset", "IA", 18);
        validAsset = new MockERC20("Valid Asset", "VA", 18);
        yieldSource = new Mock4626Vault(address(validAsset), "YieldSource", "YS");

        // Mark validAsset as valid and invalidAsset as invalid in the mock yield source oracle
        mockYieldSourceOracle.setValidAsset(address(validAsset), true);
        mockYieldSourceOracle.setValidAsset(address(invalidAsset), false);

        // Setup test users
        user1 = makeAddr("User 1");
        user2 = makeAddr("User 2");
    }

    /*//////////////////////////////////////////////////////////////
                    INDIVIDUAL QUOTING FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareQuote() public view {
        uint256 priceQuote = yieldSourceOracle.getPricePerShareQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            address(validAsset),
            address(invalidAsset), // Quote asset can be any address
            address(mockSuperOracle)
        );

        assertEq(priceQuote, QUOTE_AMOUNT, "Price quote should match the expected value");
    }

    function test_getPricePerShareQuote_InvalidBase() public {
        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getPricePerShareQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            address(invalidAsset), // Invalid base asset
            address(validAsset),
            address(mockSuperOracle)
        );
    }

    function test_getTVLByOwnerOfSharesQuote() public view {
        uint256 tvlQuote = yieldSourceOracle.getTVLByOwnerOfSharesQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            user1,
            address(validAsset),
            address(invalidAsset), // Quote asset can be any address
            address(mockSuperOracle)
        );

        assertEq(tvlQuote, QUOTE_AMOUNT, "TVL quote should match the expected value");
    }

    function test_getTVLByOwnerOfSharesQuote_InvalidBase() public {
        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLByOwnerOfSharesQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            user1,
            address(invalidAsset), // Invalid base asset
            address(validAsset),
            address(mockSuperOracle)
        );
    }

    function test_getTVLQuote() public view {
        uint256 tvlQuote = yieldSourceOracle.getTVLQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            address(validAsset),
            address(invalidAsset), // Quote asset can be any address
            address(mockSuperOracle)
        );

        assertEq(tvlQuote, QUOTE_AMOUNT, "TVL quote should match the expected value");
    }

    function test_getTVLQuote_InvalidBase() public {
        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLQuote(
            address(yieldSource),
            address(mockYieldSourceOracle),
            address(invalidAsset), // Invalid base asset
            address(validAsset),
            address(mockSuperOracle)
        );
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH QUOTING FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_getPricePerShareMultipleQuote() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(validAsset);

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        uint256[] memory quotes = yieldSourceOracle.getPricePerShareMultipleQuote(
            yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles
        );

        assertEq(quotes.length, 2, "Should return 2 quotes");
        assertEq(quotes[0], QUOTE_AMOUNT, "First quote should match expected value");
        assertEq(quotes[1], QUOTE_AMOUNT, "Second quote should match expected value");
    }

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

    function test_getPricePerShareMultipleQuote_InvalidBase() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(invalidAsset); // Invalid base asset

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getPricePerShareMultipleQuote(
            yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles
        );
    }

    function test_getTVLByOwnerOfSharesMultipleQuote() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[][] memory owners = new address[][](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        owners[0] = new address[](2);
        owners[0][0] = user1;
        owners[0][1] = user2;

        owners[1] = new address[](1);
        owners[1][0] = user1;

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(validAsset);

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        (uint256[][] memory userTvls, uint256[] memory totalTvls) = yieldSourceOracle.getTVLByOwnerOfSharesMultipleQuote(
            yieldSources, yieldSourceOracles, owners, baseAssets, quoteAssets, oracles
        );

        assertEq(userTvls.length, 2, "Should return 2 user TVL arrays");
        assertEq(userTvls[0].length, 2, "First user TVL array should have 2 elements");
        assertEq(userTvls[1].length, 1, "Second user TVL array should have 1 element");

        assertEq(userTvls[0][0], QUOTE_AMOUNT, "First user's TVL should match expected value");
        assertEq(userTvls[0][1], QUOTE_AMOUNT, "Second user's TVL should match expected value");
        assertEq(userTvls[1][0], QUOTE_AMOUNT, "Third user's TVL should match expected value");

        assertEq(totalTvls.length, 2, "Should return 2 total TVLs");
        assertEq(totalTvls[0], QUOTE_AMOUNT * 2, "First total TVL should be sum of user TVLs");
        assertEq(totalTvls[1], QUOTE_AMOUNT, "Second total TVL should be sum of user TVLs");
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

    function test_getTVLByOwnerOfSharesMultipleQuote_InvalidBase() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[][] memory owners = new address[][](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        owners[0] = new address[](1);
        owners[0][0] = user1;

        owners[1] = new address[](1);
        owners[1][0] = user1;

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(invalidAsset); // Invalid base asset

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLByOwnerOfSharesMultipleQuote(
            yieldSources, yieldSourceOracles, owners, baseAssets, quoteAssets, oracles
        );
    }

    function test_getTVLMultipleQuote() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(validAsset);

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        uint256[] memory tvls =
            yieldSourceOracle.getTVLMultipleQuote(yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles);

        assertEq(tvls.length, 2, "Should return 2 TVLs");
        assertEq(tvls[0], QUOTE_AMOUNT, "First TVL should match expected value");
        assertEq(tvls[1], QUOTE_AMOUNT, "Second TVL should match expected value");
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

    function test_getTVLMultipleQuote_InvalidBase() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory baseAssets = new address[](2);
        address[] memory quoteAssets = new address[](2);
        address[] memory oracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        baseAssets[0] = address(validAsset);
        baseAssets[1] = address(invalidAsset); // Invalid base asset

        quoteAssets[0] = address(invalidAsset);
        quoteAssets[1] = address(invalidAsset);

        oracles[0] = address(mockSuperOracle);
        oracles[1] = address(mockSuperOracle);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLMultipleQuote(yieldSources, yieldSourceOracles, baseAssets, quoteAssets, oracles);
    }

    /*//////////////////////////////////////////////////////////////
                    YIELD SOURCE ORACLE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_getPricePerShareMultiple() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        uint256[] memory prices =
            yieldSourceOracle.getPricePerShareMultiple(yieldSources, yieldSourceOracles, address(validAsset));

        assertEq(prices.length, 2, "Should return 2 prices");
        assertEq(prices[0], PRICE_PER_SHARE, "First price should match expected value");
        assertEq(prices[1], PRICE_PER_SHARE, "Second price should match expected value");
    }

    function test_getPricePerShareMultiple_InvalidBaseAsset() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getPricePerShareMultiple(yieldSources, yieldSourceOracles, address(invalidAsset));
    }

    function test_getTVLByOwnerOfSharesMultiple() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory owners = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        owners[0] = user1;
        owners[1] = user2;

        uint256[] memory tvls = yieldSourceOracle.getTVLByOwnerOfSharesMultiple(
            yieldSources, yieldSourceOracles, owners, address(validAsset)
        );

        assertEq(tvls.length, 2, "Should return 2 TVLs");
        assertEq(tvls[0], TVL_BY_OWNER, "First TVL should match expected value");
        assertEq(tvls[1], TVL_BY_OWNER, "Second TVL should match expected value");
    }

    function test_getTVLByOwnerOfSharesMultiple_InvalidBaseAsset() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);
        address[] memory owners = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        owners[0] = user1;
        owners[1] = user2;

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLByOwnerOfSharesMultiple(yieldSources, yieldSourceOracles, owners, address(invalidAsset));
    }

    function test_getTVLMultiple() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        uint256[] memory tvls = yieldSourceOracle.getTVLMultiple(yieldSources, yieldSourceOracles, address(validAsset));

        assertEq(tvls.length, 2, "Should return 2 TVLs");
        assertEq(tvls[0], TVL_AMOUNT, "First TVL should match expected value");
        assertEq(tvls[1], TVL_AMOUNT, "Second TVL should match expected value");
    }

    function test_getTVLMultiple_InvalidBaseAsset() public {
        address[] memory yieldSources = new address[](2);
        address[] memory yieldSourceOracles = new address[](2);

        yieldSources[0] = address(yieldSource);
        yieldSources[1] = address(yieldSource);

        yieldSourceOracles[0] = address(mockYieldSourceOracle);
        yieldSourceOracles[1] = address(mockYieldSourceOracle);

        vm.expectRevert(abi.encodeWithSelector(ISuperYieldSourceOracle.INVALID_BASE_ASSET.selector));
        yieldSourceOracle.getTVLMultiple(yieldSources, yieldSourceOracles, address(invalidAsset));
    }
}
