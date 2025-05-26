// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { SuperOracleL2 } from "../../../src/periphery/oracles/SuperOracleL2.sol";
import { BaseSuperVaultTest } from "../../periphery/integration/SuperVault/BaseSuperVaultTest.t.sol";
import { AggregatorV3Interface } from "../../../src/vendor/chainlink/AggregatorV3Interface.sol";
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockL2Sequencer } from "../../mocks/MockL2Sequencer.sol";

contract SuperOracleL2Test is Test {
    // Test accounts
    address public owner;
    address public user;

    // Contracts
    SuperOracleL2 public oracle;
    MockAggregator public dataFeed;
    MockL2Sequencer public uptimeFeed;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;

    // Constants
    bytes32 public constant CHAINLINK_PROVIDER = keccak256("CHAINLINK");
    uint256 public constant PRICE_DECIMALS = 8;
    uint256 public constant INITIAL_PRICE = 2000 * 10 ** PRICE_DECIMALS; // $2000
    uint256 public constant GRACE_PERIOD = 3600; // 1 hour
    uint256 public constant DEFAULT_STALENESS = 86_400; // 1 day

    function setUp() public {
        // Set a fixed timestamp for deterministic tests
        vm.warp(10_000_000);

        // Setup accounts
        owner = makeAddr("owner");
        user = makeAddr("user");
        vm.startPrank(owner);

        // Setup tokens
        baseToken = new MockERC20("Base Token", "BASE", 18);
        quoteToken = new MockERC20("Quote Token", "QUOTE", 6);
        deal(address(baseToken), address(this), 1 * 10 ** 18);
        deal(address(quoteToken), address(this), 1 * 10 ** 6);

        // Setup price feeds
        dataFeed = new MockAggregator(uint8(PRICE_DECIMALS));
        dataFeed.setLatestAnswer(int256(INITIAL_PRICE));

        // Setup sequencer uptime feed - ensure startedAt is in the past
        uptimeFeed = new MockL2Sequencer();
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); // Well past grace period

        // Setup oracle - we need to pass arrays to the constructor for bases, quotes, providers, and feeds
        address[] memory bases = new address[](1);
        address[] memory quotes = new address[](1);
        bytes32[] memory providers = new bytes32[](1);
        address[] memory feeds = new address[](1);

        bases[0] = address(baseToken);
        quotes[0] = address(quoteToken);
        providers[0] = CHAINLINK_PROVIDER;
        feeds[0] = address(dataFeed);

        // Initialize SuperOracleL2
        oracle = new SuperOracleL2(owner, bases, quotes, providers, feeds);

        // Set uptime feed for the data feed
        oracle.setUptimeFeed(address(dataFeed), address(uptimeFeed), GRACE_PERIOD);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Constructor() public view {
        // Test that constructor sets up the contract correctly
        assertEq(oracle.owner(), owner);
        assertEq(oracle.maxDefaultStaleness(), DEFAULT_STALENESS);

        // Verify oracle configuration
        address configuredOracle = oracle.getOracleAddress(address(baseToken), address(quoteToken), CHAINLINK_PROVIDER);
        assertEq(configuredOracle, address(dataFeed));

        // Verify uptime feed configuration
        assertEq(oracle.uptimeFeeds(address(dataFeed)), address(uptimeFeed));
        assertEq(oracle.gracePeriods(address(uptimeFeed)), GRACE_PERIOD);
    }

    function test_Constructor_NulledInput_Reverts() public {
        // Test constructor reverts with null values
        address[] memory bases = new address[](1);
        address[] memory quotes = new address[](1);
        bytes32[] memory providers = new bytes32[](1);
        address[] memory feeds = new address[](1);

        bases[0] = address(0);
        quotes[0] = address(0);
        providers[0] = bytes32(0);
        feeds[0] = address(0);

        vm.expectRevert();
        new SuperOracleL2(owner, bases, quotes, providers, feeds);
    }

    /*//////////////////////////////////////////////////////////////
                            UPTIME FEED TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SetUptimeFeed() public {
        // Create a new mock uptime feed
        MockL2Sequencer newUptimeFeed = new MockL2Sequencer();
        newUptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        newUptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); 

        // Set a new uptime feed
        vm.prank(owner);
        oracle.setUptimeFeed(address(dataFeed), address(newUptimeFeed), GRACE_PERIOD * 2);

        // Verify the new uptime feed is set
        assertEq(oracle.uptimeFeeds(address(dataFeed)), address(newUptimeFeed));
        assertEq(oracle.gracePeriods(address(newUptimeFeed)), GRACE_PERIOD * 2);
    }

    function test_SetUptimeFeed_OnlyOwner() public {
        // Create a new mock uptime feed
        MockL2Sequencer newUptimeFeed = new MockL2Sequencer();

        // Should revert when non-owner tries to set uptime feed
        vm.prank(user);
        vm.expectRevert();
        oracle.setUptimeFeed(address(dataFeed), address(newUptimeFeed), GRACE_PERIOD);
    }

    function test_SetUptimeFeed_ZeroAddressReverts() public {
        vm.startPrank(owner);

        // Test with zero data oracle
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracleL2.ZERO_ADDRESS.selector);
        vm.expectRevert(encodedError);
        oracle.setUptimeFeed(address(0), address(uptimeFeed), GRACE_PERIOD);

        // Test with zero uptime oracle
        vm.expectRevert(encodedError);
        oracle.setUptimeFeed(address(dataFeed), address(0), GRACE_PERIOD);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      QUOTE RETRIEVAL TESTS
    //////////////////////////////////////////////////////////////*/
    function test_GetQuote_SequencerUp() public {
        // Make sure sequencer is up and grace period is over
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); // Well past grace period


        uint256 baseAmount = 1 * 10 ** 15; 
        uint256 quoteAmount = oracle.getQuote(baseAmount, address(baseToken), address(quoteToken));

        // Get the actual quote amount and use that in our test
        // This lets us focus on the functionality rather than exact decimal math
        assertEq(quoteAmount, 2_000_000);
    }

    function test_GetQuote_SequencerDown_Reverts() public {
        // Set sequencer to down
        uptimeFeed.setLatestAnswer(1); // 1 means sequencer is down

        // Attempt to get a quote - should revert
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracleL2.SEQUENCER_DOWN.selector);
        vm.expectRevert(encodedError);
        oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));
    }

    function test_GetQuote_GracePeriodNotOver_Reverts() public {
        // Set sequencer to up but grace period not over
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - 100); // Grace period not over (3600 is required)

        // Attempt to get a quote - should revert
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracleL2.GRACE_PERIOD_NOT_OVER.selector);
        vm.expectRevert(encodedError);
        oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));
    }

    function test_GetQuote_NoUptimeFeed_Reverts() public {
        // Create a new data feed without an uptime feed
        MockAggregator newDataFeed = new MockAggregator(uint8(PRICE_DECIMALS));
        newDataFeed.setLatestAnswer(int256(INITIAL_PRICE));

        // Configure the oracle with the new data feed
        address[] memory bases = new address[](1);
        address[] memory quotes = new address[](1);
        bytes32[] memory providers = new bytes32[](1);
        address[] memory feeds = new address[](1);

        bases[0] = address(baseToken);
        quotes[0] = address(quoteToken);
        providers[0] = keccak256("NEW_PROVIDER");
        feeds[0] = address(newDataFeed);

        vm.prank(owner);
        oracle.queueOracleUpdate(bases, quotes, providers, feeds);

        // Fast forward past timelock
        vm.warp(block.timestamp + 7 days);

        vm.prank(owner);
        oracle.executeOracleUpdate();

        // Try to get a quote using the new provider
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracleL2.NO_UPTIME_FEED.selector);
        vm.expectRevert(encodedError);
        oracle.getQuoteFromProvider(1 * 10 ** 15, address(baseToken), address(quoteToken), keccak256("NEW_PROVIDER"));
    }

    function test_GetQuote_StaleFeed_Reverts() public {
        // Set up sequencer correctly
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); // Well past grace period

        // Set the data feed to have stale data
        dataFeed.setUpdatedAt(block.timestamp - DEFAULT_STALENESS - 1); // Older than max staleness

        // Attempt to get a quote directly from the oracle function that checks staleness
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracle.NO_VALID_REPORTED_PRICES.selector);
        vm.expectRevert(encodedError);
        oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));
    }

    function test_GetQuote_NegativePrice_Reverts() public {
        // Set up sequencer correctly
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); // Well past grace period

        // Set the data feed to have negative price
        dataFeed.setLatestAnswer(-1 * int256(INITIAL_PRICE));

        // Attempt to get a quote directly from the oracle function that checks for negative prices
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracle.NO_VALID_REPORTED_PRICES.selector);
        vm.expectRevert(encodedError);
        oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_PriceChangeReflected() public {
        // Set up sequencer correctly
        uptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        uptimeFeed.setStartedAt(block.timestamp - GRACE_PERIOD * 2); // Well past grace period

        // Get initial quote - using smaller amounts to avoid overflow
        uint256 baseAmount = 1 * 10 ** 15; // 0.001 token
        uint256 initialQuote = oracle.getQuote(baseAmount, address(baseToken), address(quoteToken));

        // Change price in the feed
        uint256 newPrice = INITIAL_PRICE * 2; // Double the price
        dataFeed.setLatestAnswer(int256(newPrice));

        // Get new quote
        uint256 newQuote = oracle.getQuote(baseAmount, address(baseToken), address(quoteToken));

        // Verify the quote has doubled
        assertEq(newQuote, initialQuote * 2);
    }

    function test_DefaultGracePeriod() public {
        // Create a new uptime feed
        MockL2Sequencer newUptimeFeed = new MockL2Sequencer();
        newUptimeFeed.setLatestAnswer(0); // 0 means sequencer is up
        newUptimeFeed.setStartedAt(block.timestamp - 100); // Recently started (shorter than default grace)

        // Set the uptime feed with a zero grace period (should use default)
        vm.prank(owner);
        oracle.setUptimeFeed(address(dataFeed), address(newUptimeFeed), 0);

        // Verify the default grace period is used
        bytes memory encodedError = abi.encodeWithSelector(ISuperOracleL2.GRACE_PERIOD_NOT_OVER.selector);
        vm.expectRevert(encodedError);
        oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));

        // Now set a time that's past the default grace period
        newUptimeFeed.setStartedAt(block.timestamp - 3700); // Past default grace period

        // Should now succeed
        uint256 quoteAmount = oracle.getQuote(1 * 10 ** 15, address(baseToken), address(quoteToken));
        assertGt(quoteAmount, 0);
    }
}

interface ISuperOracleL2 {
    error SEQUENCER_DOWN();
    error GRACE_PERIOD_NOT_OVER();
    error NO_UPTIME_FEED();
    error ZERO_ADDRESS();
}

interface ISuperOracle {
    error ORACLE_UNTRUSTED_DATA();
    error NO_VALID_REPORTED_PRICES();
    error ZERO_ARRAY_LENGTH();
}
