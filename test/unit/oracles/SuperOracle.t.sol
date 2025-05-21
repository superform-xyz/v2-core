// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Superform
import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockAggregator } from "../../periphery/mocks/MockAggregator.sol";
import { SuperOracle } from "../../../src/periphery/oracles/SuperOracle.sol";
import { ISuperOracle } from "../../../src/periphery/interfaces/ISuperOracle.sol";

contract SuperOracleTest is Helpers {
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");
    bytes32 public constant PROVIDER_1 = bytes32(keccak256("Provider 1"));
    bytes32 public constant PROVIDER_2 = bytes32(keccak256("Provider 2"));
    bytes32 public constant PROVIDER_3 = bytes32(keccak256("Provider 3"));
    bytes32 public constant NEW_PROVIDER = bytes32(keccak256("New Provider"));

    SuperOracle public superOracle;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    MockAggregator public mockFeed4;
    MockERC20 public mockETH;
    MockERC20 public mockUSD;
    MockERC20 public mockBTC;

    function setUp() public {
        // Create mock tokens
        mockETH = new MockERC20("Mock ETH", "ETH", 18); // ETH has 18 decimals
        mockUSD = new MockERC20("Mock USD", "USD", 6); // USD has 6 decimals
        mockBTC = new MockERC20("Mock BTC", "BTC", 8); // BTC has 8 decimals

        // Create mock price feeds with different price values
        mockFeed1 = new MockAggregator(1.1e8, 8); // ETH/USD = $1100
        mockFeed2 = new MockAggregator(1e8, 8); // ETH/USD = $1000
        mockFeed3 = new MockAggregator(0.9e8, 8); // ETH/USD = $900
        mockFeed4 = new MockAggregator(2e8, 8); // BTC/USD = $20000

        // Configure base oracle with initial providers
        address[] memory bases = new address[](3);
        bases[0] = address(mockETH);
        bases[1] = address(mockETH);
        bases[2] = address(mockETH);

        address[] memory quotes = new address[](3);
        quotes[0] = address(mockUSD);
        quotes[1] = address(mockUSD);
        quotes[2] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](3);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;

        address[] memory feeds = new address[](3);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);

        superOracle = new SuperOracle(address(this), bases, quotes, providers, feeds);

        // Set a longer max staleness period for tests that involve time warping
        superOracle.setMaxStaleness(2 weeks);
    }

    function test_GetQuote() public view {
        uint256 baseAmount = 1e18;
        uint256 expectedQuote = 1e6;

        uint256 quoteAmount = superOracle.getQuote(baseAmount, address(mockETH), address(mockUSD));
        assertEq(quoteAmount, expectedQuote, "Quote amount should match expected value");
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetQuoteFromProvider() public view {
        uint256 baseAmount = 1e18; // 1 ETH

        // Test getting quote from Provider 1 (mockFeed1)
        (uint256 quoteAmount1, uint256 deviation1, uint256 totalProviders1, uint256 availableProviders1) =
            superOracle.getQuoteFromProvider(baseAmount, address(mockETH), address(mockUSD), PROVIDER_1);

        assertEq(quoteAmount1, 1.1e6, "Quote from provider 1 should be $1100");
        assertEq(deviation1, 0, "Deviation should be 0 for single provider");
        assertEq(totalProviders1, 1, "Total providers should be 1");
        assertEq(availableProviders1, 1, "Available providers should be 1");

        // Test getting average quote from all providers
        (uint256 quoteAmountAvg, uint256 deviationAvg, uint256 totalProvidersAvg, uint256 availableProvidersAvg) =
            superOracle.getQuoteFromProvider(baseAmount, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        assertEq(quoteAmountAvg, 1e6, "Average quote should be $1000");
        assertGt(deviationAvg, 0, "Deviation should be greater than 0 for multiple providers");
        assertEq(totalProvidersAvg, 3, "Total providers should be 3");
        assertEq(availableProvidersAvg, 3, "Available providers should be 3");
    }

    /*//////////////////////////////////////////////////////////////
                        PROVIDER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetActiveProviders() public view {
        bytes32[] memory activeProviders = superOracle.getActiveProviders();
        assertEq(activeProviders.length, 3, "Should have 3 active providers");

        // Check all expected providers are active
        bool foundProvider1 = false;
        bool foundProvider2 = false;
        bool foundProvider3 = false;

        for (uint256 i = 0; i < activeProviders.length; i++) {
            if (activeProviders[i] == PROVIDER_1) foundProvider1 = true;
            if (activeProviders[i] == PROVIDER_2) foundProvider2 = true;
            if (activeProviders[i] == PROVIDER_3) foundProvider3 = true;
        }

        assertTrue(foundProvider1, "Provider 1 should be active");
        assertTrue(foundProvider2, "Provider 2 should be active");
        assertTrue(foundProvider3, "Provider 3 should be active");
    }

    function test_AddingNewProvider() public {
        // Add a new provider for BTC/USD
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Queue the oracle update
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);

        // Warp to pass timelock
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update the feed timestamp to avoid staleness after warping
        mockFeed4.setUpdatedAt(block.timestamp);

        // Execute the update
        superOracle.executeOracleUpdate();

        // Verify the new provider is active
        bytes32[] memory activeProviders = superOracle.getActiveProviders();
        assertEq(activeProviders.length, 4, "Should now have 4 active providers");

        // Check new provider added
        bool foundNewProvider = false;
        for (uint256 i = 0; i < activeProviders.length; i++) {
            if (activeProviders[i] == NEW_PROVIDER) {
                foundNewProvider = true;
                break;
            }
        }
        assertTrue(foundNewProvider, "New provider should be active");

        // Test getting quote from new provider
        (uint256 quoteAmount,,,) = superOracle.getQuoteFromProvider(
            1e8, // 1 BTC (8 decimals)
            address(mockBTC),
            address(mockUSD),
            NEW_PROVIDER
        );

        assertEq(quoteAmount, 2e6, "Quote from new provider should be $20000");
    }

    function test_RemovingProvider() public {
        // First verify provider 3 exists
        bytes32[] memory providersToRemove = new bytes32[](1);
        providersToRemove[0] = PROVIDER_3;

        // Queue provider removal
        superOracle.queueProviderRemoval(providersToRemove);

        // Warp to pass timelock
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update timestamps to avoid staleness after warping
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);

        // Execute the removal
        superOracle.executeProviderRemoval();

        // Verify the provider was removed
        bytes32[] memory activeProviders = superOracle.getActiveProviders();
        assertEq(activeProviders.length, 2, "Should now have 2 active providers");

        // Provider 3 should no longer be active
        for (uint256 i = 0; i < activeProviders.length; i++) {
            if (activeProviders[i] == PROVIDER_3) {
                revert("Provider 3 should have been removed");
            }
        }

        // Test getting quote uses average of remaining providers
        (uint256 quoteAmount,,,) = superOracle.getQuoteFromProvider(
            1e18, // 1 ETH
            address(mockETH),
            address(mockUSD),
            AVERAGE_PROVIDER
        );

        // Average of provider 1 ($1100) and provider 2 ($1000)
        assertEq(quoteAmount, 1.05e6, "Average quote should be $1050 after removal");
    }

    /*//////////////////////////////////////////////////////////////
                    STALENESS CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetMaxStaleness() public {
        // Set a new max staleness period
        uint256 newMaxStaleness = 12 hours;
        superOracle.setMaxStaleness(newMaxStaleness);

        // Check it was updated
        assertEq(superOracle.maxDefaultStaleness(), newMaxStaleness, "Max staleness should be updated");
    }

    function test_SetFeedMaxStaleness() public {
        // Set staleness for a specific feed
        uint256 feedStaleness = 6 hours;
        superOracle.setFeedMaxStaleness(address(mockFeed1), feedStaleness);

        // Check it was updated
        assertEq(superOracle.feedMaxStaleness(address(mockFeed1)), feedStaleness, "Feed staleness should be updated");
    }

    function test_StalenessBatchUpdate() public {
        // Set staleness for multiple feeds
        address[] memory feeds = new address[](2);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);

        uint256[] memory stalenessList = new uint256[](2);
        stalenessList[0] = 6 hours;
        stalenessList[1] = 12 hours;

        superOracle.setFeedMaxStalenessBatch(feeds, stalenessList);

        // Check they were updated
        assertEq(superOracle.feedMaxStaleness(address(mockFeed1)), 6 hours, "Feed 1 staleness should be updated");
        assertEq(superOracle.feedMaxStaleness(address(mockFeed2)), 12 hours, "Feed 2 staleness should be updated");
    }

    function test_RevertIfStaleData() public {
        vm.warp(block.timestamp + 2 days);

        // Set the updatedAt for all providers to the current timestamp
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);

        // Make only provider 1 data stale (older than default 1 day)
        mockFeed1.setUpdatedAt(block.timestamp - 2 days);

        // Should revert when trying to get a quote from this provider
        vm.expectRevert(ISuperOracle.ORACLE_UNTRUSTED_DATA.selector);
        superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_1);

        // Average provider should still work but exclude the stale provider
        (uint256 quoteAmount,, uint256 totalProviders, uint256 availableProviders) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // Average of provider 2 ($1000) and provider 3 ($900)
        assertEq(quoteAmount, 0.95e6, "Average quote should be $950 excluding stale provider");
        assertEq(totalProviders, 3, "Total providers should still be 3");
        assertEq(availableProviders, 2, "Available providers should be 2 (1 is stale)");
    }

    /*//////////////////////////////////////////////////////////////
                    ORACLE UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_QueueOracleUpdate() public {
        // Add a new provider
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Queue the update
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);

        // Cannot execute before timelock period
        vm.expectRevert(ISuperOracle.TIMELOCK_NOT_ELAPSED.selector);
        superOracle.executeOracleUpdate();

        // Warp to pass timelock
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update the feed timestamp to avoid staleness after warping
        mockFeed4.setUpdatedAt(block.timestamp);

        // Now it should work
        superOracle.executeOracleUpdate();

        // Verify oracle address is set
        address oracle = superOracle.getOracleAddress(address(mockBTC), address(mockUSD), NEW_PROVIDER);
        assertEq(oracle, address(mockFeed4), "Oracle address should be set for new provider");
    }

    /*//////////////////////////////////////////////////////////////
                    ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertIfZeroAddress() public {
        address[] memory bases = new address[](1);
        bases[0] = address(0); // Zero address

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Should revert due to zero address
        vm.expectRevert(ISuperOracle.ZERO_ADDRESS.selector);
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
    }

    function test_RevertIfZeroProvider() public {
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = bytes32(0); // Zero provider

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Should revert due to zero provider
        vm.expectRevert(ISuperOracle.ZERO_PROVIDER.selector);
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
    }

    function test_RevertIfAverageProvider() public {
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = AVERAGE_PROVIDER; // Cannot use AVERAGE_PROVIDER

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Should revert because AVERAGE_PROVIDER is not allowed
        vm.expectRevert(ISuperOracle.AVERAGE_PROVIDER_NOT_ALLOWED.selector);
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
    }

    function test_RevertIfArrayLengthMismatch() public {
        address[] memory bases = new address[](2);
        bases[0] = address(mockBTC);
        bases[1] = address(mockETH);

        address[] memory quotes = new address[](1); // Mismatch with bases
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Should revert due to array length mismatch
        vm.expectRevert(ISuperOracle.ARRAY_LENGTH_MISMATCH.selector);
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
    }

    function test_RevertIfNoOraclesConfigured() public {
        // Try to get oracle for a pair that doesn't exist
        vm.expectRevert(ISuperOracle.NO_ORACLES_CONFIGURED.selector);
        superOracle.getOracleAddress(address(mockBTC), address(mockUSD), NEW_PROVIDER);
    }

    function test_RevertIfMaxStalenessExceeded() public {
        // Set max staleness to 12 hours
        superOracle.setMaxStaleness(12 hours);

        // Try to set a feed staleness greater than max
        vm.expectRevert(ISuperOracle.MAX_STALENESS_EXCEEDED.selector);
        superOracle.setFeedMaxStaleness(address(mockFeed1), 1 days);
    }

    function test_RevertIfAllProvidersInvalid() public {
        vm.warp(block.timestamp + 3 days);
        // Make all providers return stale data
        mockFeed1.setUpdatedAt(block.timestamp - 2 days);
        mockFeed2.setUpdatedAt(block.timestamp - 2 days);
        mockFeed3.setUpdatedAt(block.timestamp - 2 days);

        // Should revert when trying to get average quote with all stale providers
        vm.expectRevert(ISuperOracle.NO_VALID_REPORTED_PRICES.selector);
        superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);
    }

    function test_DeviationCalculation() public view {
        // Provider 1: $1100, Provider 2: $1000, Provider 3: $900
        // Average: $1000, Standard Deviation: ~$81.65

        (, uint256 deviation,,) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // Verify deviation is not zero (there is some deviation between providers)
        assertGt(deviation, 0, "Deviation should be greater than zero");
    }

    function test_TimelockedProviderRemoval() public {
        // Queue provider removal
        bytes32[] memory providersToRemove = new bytes32[](1);
        providersToRemove[0] = PROVIDER_1;

        superOracle.queueProviderRemoval(providersToRemove);

        // Cannot queue another removal while one is pending
        vm.expectRevert(ISuperOracle.PENDING_UPDATE_EXISTS.selector);
        superOracle.queueProviderRemoval(providersToRemove);

        // Cannot execute before timelock
        vm.expectRevert(ISuperOracle.TIMELOCK_NOT_ELAPSED.selector);
        superOracle.executeProviderRemoval();

        // Warp to pass timelock
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update timestamps to avoid staleness after warping
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);

        // Now execution should succeed
        superOracle.executeProviderRemoval();

        // Verify provider was removed
        bytes32[] memory activeProviders = superOracle.getActiveProviders();
        assertEq(activeProviders.length, 2, "Should have 2 providers after removal");

        for (uint256 i = 0; i < activeProviders.length; i++) {
            if (activeProviders[i] == PROVIDER_1) {
                revert("Provider 1 should have been removed");
            }
        }
    }

    function test_NegativeOracleValues() public {
        // Set a negative price
        mockFeed1.setAnswer(-1e8);

        // Should revert when trying to get a quote from this provider
        vm.expectRevert(ISuperOracle.ORACLE_UNTRUSTED_DATA.selector);
        superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_1);

        // Average provider should still work but exclude the negative provider
        (uint256 quoteAmount,, uint256 totalProviders, uint256 availableProviders) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // Average of provider 2 ($1000) and provider 3 ($900)
        assertEq(quoteAmount, 0.95e6, "Average quote should be $950 excluding negative provider");
        assertEq(totalProviders, 3, "Total providers should still be 3");
        assertEq(availableProviders, 2, "Available providers should be 2 (1 is negative)");
    }

    function test_MultipleProviderRemoval() public {
        // Queue multiple provider removal
        bytes32[] memory providersToRemove = new bytes32[](2);
        providersToRemove[0] = PROVIDER_1;
        providersToRemove[1] = PROVIDER_2;

        superOracle.queueProviderRemoval(providersToRemove);

        // Warp to pass timelock
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update timestamps to avoid staleness after warping
        mockFeed3.setUpdatedAt(block.timestamp);

        // Execute the removal
        superOracle.executeProviderRemoval();

        // Verify providers were removed from the active providers array
        bytes32[] memory activeProviders = superOracle.getActiveProviders();
        assertEq(activeProviders.length, 1, "Should have 1 provider after removal");
        assertEq(activeProviders[0], PROVIDER_3, "Only Provider 3 should remain");

        // Even though the providers were removed from activeProviders,
        // their oracle mappings still exist (the implementation doesn't clear them)
        address oracle1 = superOracle.getOracleAddress(address(mockETH), address(mockUSD), PROVIDER_1);
        address oracle2 = superOracle.getOracleAddress(address(mockETH), address(mockUSD), PROVIDER_2);

        assertEq(oracle1, address(0), "Oracle mapping for Provider 1 should not exist");
        assertEq(oracle2, address(0), "Oracle mapping for Provider 2 should not exist");

        bool isProvider1Set = superOracle.isProviderSet(PROVIDER_1);
        bool isProvider2Set = superOracle.isProviderSet(PROVIDER_2);

        assertEq(isProvider1Set, false, "Provider 1 should not be set");
        assertEq(isProvider2Set, false, "Provider 2 should not be set");

        // Getting quote from remaining provider should work
        (uint256 quoteAmount,,,) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_3);

        assertEq(quoteAmount, 0.9e6, "Quote should be $900 from Provider 3");
    }

    function test_DecimalConversion() public {
        // Create a new feed with different decimals
        MockAggregator mockFeed6Dec = new MockAggregator(1.1e6, 6); // Same price but 6 decimals

        // Add a new oracle with this feed
        address[] memory bases = new address[](1);
        bases[0] = address(mockETH);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = bytes32(keccak256("6DecProvider"));

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed6Dec);

        // Queue and execute update
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        // Update the feed timestamp to avoid staleness after warping
        mockFeed6Dec.setUpdatedAt(block.timestamp);

        superOracle.executeOracleUpdate();

        // Get quote with different decimal configuration
        (uint256 quoteAmount,,,) = superOracle.getQuoteFromProvider(
            1e18, // 1 ETH
            address(mockETH),
            address(mockUSD),
            bytes32(keccak256("6DecProvider"))
        );

        // Should still give correct result with decimal conversion
        assertEq(quoteAmount, 1.1e6, "Quote should be $1100 with correct decimal conversion");
    }

    function test_SkippingProvidersWithoutOracleAddress() public {
        // Create a configuration where:
        // - Provider 1, Provider 2 have ETH/USD oracles
        // - Provider 3 has BTC/USD oracle but not ETH/USD
        // - We add a new provider "BTC_ONLY_PROVIDER" that only has BTC/USD oracle

        // First add a new provider that only has BTC/USD oracle, not ETH/USD
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        bytes32 BTC_ONLY_PROVIDER = bytes32(keccak256("BTC_ONLY_PROVIDER"));
        providers[0] = BTC_ONLY_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Queue and execute the oracle update to add BTC/USD oracle for the new provider
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        mockFeed4.setUpdatedAt(block.timestamp);
        superOracle.executeOracleUpdate();

        // Verify the new provider is active
        bytes32[] memory activeProviders = superOracle.getActiveProviders();

        // Should have 4 active providers (the 3 initial ones + the new BTC-only one)
        assertEq(activeProviders.length, 4, "Should have 4 active providers");

        // Update all feed timestamps to avoid staleness
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);

        // Get average quote for ETH/USD - should only use providers that have ETH/USD oracles
        (uint256 quoteAmount,, uint256 totalProviders, uint256 availableProviders) = superOracle.getQuoteFromProvider(
            1e18, // 1 ETH
            address(mockETH),
            address(mockUSD),
            AVERAGE_PROVIDER
        );

        // Even though we have 4 active providers, only 3 have ETH/USD oracles
        assertEq(totalProviders, 3, "Total providers should be 3");
        assertEq(availableProviders, 3, "Only 3 providers should be available for ETH/USD");
        assertEq(quoteAmount, 1e6, "Average quote should still be $1000 from the 3 ETH/USD providers");

        // Get average quote for BTC/USD - should only use providers that have BTC/USD oracles
        (uint256 btcQuoteAmount,, uint256 btcTotalProviders, uint256 btcAvailableProviders) = superOracle
            .getQuoteFromProvider(
            1e8, // 1 BTC
            address(mockBTC),
            address(mockUSD),
            AVERAGE_PROVIDER
        );

        // Only 1 provider (BTC_ONLY_PROVIDER) has BTC/USD oracle
        assertEq(btcTotalProviders, 1, "Total providers should be 1");
        assertEq(btcAvailableProviders, 1, "Only 1 provider should be available for BTC/USD");
        assertEq(btcQuoteAmount, 2e6, "Quote should be $20000 from the only BTC/USD provider");
    }

    // NEW TESTS BELOW

    function test_RevertIfZeroArrayLength() public {
        // Try to queue provider removal with empty array
        bytes32[] memory emptyArray = new bytes32[](0);
        vm.expectRevert(ISuperOracle.ZERO_ARRAY_LENGTH.selector);
        superOracle.queueProviderRemoval(emptyArray);

        // Try to set batch staleness with empty arrays
        address[] memory emptyAddresses = new address[](0);
        uint256[] memory emptyValues = new uint256[](0);
        vm.expectRevert(ISuperOracle.ZERO_ARRAY_LENGTH.selector);
        superOracle.setFeedMaxStalenessBatch(emptyAddresses, emptyValues);
    }

    function test_RevertOnExecuteWithNoPendingUpdate() public {
        // Attempt to execute oracle update with no pending update
        vm.expectRevert(ISuperOracle.NO_PENDING_UPDATE.selector);
        superOracle.executeOracleUpdate();

        // Attempt to execute provider removal with no pending removal
        vm.expectRevert(ISuperOracle.NO_PENDING_UPDATE.selector);
        superOracle.executeProviderRemoval();
    }

    function test_OnlyOwnerCanPerformAdminActions() public {
        // Create a non-owner address
        address nonOwner = address(0x1234);
        vm.startPrank(nonOwner);

        // Try to set max staleness (should revert)
        vm.expectRevert();
        superOracle.setMaxStaleness(1 days);

        // Try to set feed max staleness (should revert)
        vm.expectRevert();
        superOracle.setFeedMaxStaleness(address(mockFeed1), 12 hours);

        // Try to set feed max staleness batch (should revert)
        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed1);
        uint256[] memory values = new uint256[](1);
        values[0] = 12 hours;
        vm.expectRevert();
        superOracle.setFeedMaxStalenessBatch(feeds, values);

        // Try to queue oracle update (should revert)
        address[] memory bases = new address[](1);
        bases[0] = address(mockETH);
        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);
        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;
        address[] memory oracles = new address[](1);
        oracles[0] = address(mockFeed4);
        vm.expectRevert();
        superOracle.queueOracleUpdate(bases, quotes, providers, oracles);

        // Try to queue provider removal (should revert)
        bytes32[] memory providersToRemove = new bytes32[](1);
        providersToRemove[0] = PROVIDER_1;
        vm.expectRevert();
        superOracle.queueProviderRemoval(providersToRemove);

        vm.stopPrank();
    }

    function test_DefaultFeedStalenessWhenZeroProvided() public {
        // Set maxDefaultStaleness to a specific value
        uint256 defaultStaleness = 3 days;
        superOracle.setMaxStaleness(defaultStaleness);

        // Set feed staleness to 0, which should default to maxDefaultStaleness
        superOracle.setFeedMaxStaleness(address(mockFeed1), 0);

        // Check that the feed staleness was set to the default
        assertEq(
            superOracle.feedMaxStaleness(address(mockFeed1)),
            defaultStaleness,
            "Feed staleness should default to maxDefaultStaleness"
        );
    }

    function test_SingleElementArrayOracles() public {
        // Test the constructor with just a single element
        address[] memory bases = new address[](1);
        bases[0] = address(mockBTC);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = NEW_PROVIDER;

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4);

        // Create a new oracle instance with single element arrays
        SuperOracle newOracle = new SuperOracle(address(this), bases, quotes, providers, feeds);

        // Verify the single provider was set
        bytes32[] memory activeProviders = newOracle.getActiveProviders();
        assertEq(activeProviders.length, 1, "Should have 1 active provider");
        assertEq(activeProviders[0], NEW_PROVIDER, "Active provider should be NEW_PROVIDER");

        // Verify we can get the quote from this provider
        (uint256 quoteAmount,,,) = newOracle.getQuoteFromProvider(
            1e8, // 1 BTC
            address(mockBTC),
            address(mockUSD),
            NEW_PROVIDER
        );

        assertEq(quoteAmount, 2e6, "Quote should be $20000");
    }

    function test_StdDevWithSingleProvider() public {
        // First remove two providers so we only have one
        bytes32[] memory providersToRemove = new bytes32[](2);
        providersToRemove[0] = PROVIDER_1;
        providersToRemove[1] = PROVIDER_2;

        superOracle.queueProviderRemoval(providersToRemove);
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        mockFeed3.setUpdatedAt(block.timestamp);
        superOracle.executeProviderRemoval();

        // Get quote with average provider, which should only use PROVIDER_3
        (, uint256 deviation,,) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // With only one provider, standard deviation should be zero
        assertEq(deviation, 0, "Deviation should be zero with single provider");
    }

    function test_RevertIfQuoteForRemovedProvider() public {
        // Remove PROVIDER_1
        bytes32[] memory providersToRemove = new bytes32[](1);
        providersToRemove[0] = PROVIDER_1;

        superOracle.queueProviderRemoval(providersToRemove);
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        superOracle.executeProviderRemoval();

        // When a provider is removed, its oracle mapping still exists but isProviderSet is false
        // The getOracleAddress function checks isProviderSet and returns address(0) if false
        address oracle = superOracle.getOracleAddress(address(mockETH), address(mockUSD), PROVIDER_1);
        assertEq(oracle, address(0), "Oracle address should be address(0) for removed provider");

        // When getting a quote, the oracle exists but its data is considered untrusted
        vm.expectRevert(ISuperOracle.ORACLE_UNTRUSTED_DATA.selector);
        superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_1);
    }

    function test_ZeroAnswerInOracle() public {
        // Set a zero price in one of the feeds
        mockFeed1.setAnswer(0);

        // Should revert when trying to get a quote directly from this provider
        vm.expectRevert(ISuperOracle.ORACLE_UNTRUSTED_DATA.selector);
        superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_1);

        // Average provider should exclude the provider with zero price
        (uint256 quoteAmount,, uint256 totalProviders, uint256 availableProviders) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // Average of provider 2 ($1000) and provider 3 ($900)
        assertEq(quoteAmount, 0.95e6, "Average quote should be $950 excluding provider with zero price");
        assertEq(totalProviders, 3, "Total providers should still be 3");
        assertEq(availableProviders, 2, "Available providers should be 2 (1 is zero)");
    }

    function test_TransferOwnership() public {
        address newOwner = address(0x1234);

        // Transfer ownership
        superOracle.transferOwnership(newOwner);

        // Try to use a restricted function (should still work because ownership is not transferred yet)
        superOracle.setMaxStaleness(1 days);

        // Accept the ownership as the new owner
        vm.startPrank(newOwner);
        superOracle.acceptOwnership();
        vm.stopPrank();

        // Try to use a restricted function as the old owner (should revert)
        vm.expectRevert();
        superOracle.setMaxStaleness(12 hours);

        // New owner should be able to use restricted functions
        vm.startPrank(newOwner);
        superOracle.setMaxStaleness(12 hours);
        vm.stopPrank();
    }

    function test_HundredPercentDeviationCase() public {
        // Create a scenario with extreme price differences
        mockFeed1.setAnswer(2e8); // $2000
        mockFeed2.setAnswer(1e7); // $100
        mockFeed3.setAnswer(1e8); // $1000

        // Get average quote with these extreme deviations
        (, uint256 deviation,,) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), AVERAGE_PROVIDER);

        // Should have very high deviation
        assertGt(deviation, 0, "Deviation should be > 0 with extreme price differences");
    }

    function test_OracleUpdateWithExistingProvider() public {
        // Update an oracle address for an existing provider
        address[] memory bases = new address[](1);
        bases[0] = address(mockETH);

        address[] memory quotes = new address[](1);
        quotes[0] = address(mockUSD);

        bytes32[] memory providers = new bytes32[](1);
        providers[0] = PROVIDER_1; // Existing provider

        address[] memory feeds = new address[](1);
        feeds[0] = address(mockFeed4); // Different feed

        // Queue and execute the update
        superOracle.queueOracleUpdate(bases, quotes, providers, feeds);
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        mockFeed4.setUpdatedAt(block.timestamp);
        superOracle.executeOracleUpdate();

        // Verify that the oracle address was updated for the existing provider
        (uint256 quoteAmount,,,) =
            superOracle.getQuoteFromProvider(1e18, address(mockETH), address(mockUSD), PROVIDER_1);

        // Should now return the quote from the new feed (mockFeed4)
        assertEq(quoteAmount, 2e6, "Quote should be $2000 from the updated feed");
    }
}
