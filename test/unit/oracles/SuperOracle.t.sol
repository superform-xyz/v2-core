// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;


// Superform
import { BaseTest } from "../../BaseTest.t.sol";

import { SuperOracle } from "../../../src/core/accounting/oracles/SuperOracle.sol";
import { AggregatorV3Interface } from "../../../src/vendor/chainlink/AggregatorV3Interface.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";



contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _updatedAt;
    uint8 private immutable _decimals;

    constructor(int256 answer_, uint8 decimals_) {
        _answer = answer_;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Aggregator";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, _updatedAt, 1);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, _updatedAt, 1);
    }
}

contract SuperOracleTest is BaseTest {
    SuperOracle public superOracle;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    MockERC20 public mockETH;
    MockERC20 public mockUSD;

    function setUp() public override {
        super.setUp();
        
        // Create mock tokens
        mockETH = new MockERC20("Mock ETH", "ETH", 18); // ETH has 18 decimals
        mockUSD = new MockERC20("Mock USD", "USD", 6);  // USD has 6 decimals
        mockFeed1 = new MockAggregator(1.1e8, 8);
        mockFeed2 = new MockAggregator(1e8, 8);
        mockFeed3 = new MockAggregator(0.9e8, 8);

        // Configure both provider 0 (average) and provider 1
        address[] memory bases = new address[](4);
        bases[0] = address(mockETH);
        bases[1] = address(mockETH);
        bases[2] = address(mockETH);
        bases[3] = address(mockETH);

        address[] memory quotes = new address[](4);
        quotes[0] = address(mockUSD);
        quotes[1] = address(mockUSD);
        quotes[2] = address(mockUSD);
        quotes[3] = address(mockUSD);

        uint256[] memory providers = new uint256[](4);
        providers[0] = 0; // Provider 0 (average)
        providers[1] = 1; // Provider 1 (e.g. Chainlink)
        providers[2] = 2; // Provider 1 (e.g. Some oracle)
        providers[3] = 3; // Provider 1 (e.g. Some oracle)

        address[] memory feeds = new address[](4);
        feeds[0] = address(0);
        feeds[1] = address(mockFeed1);
        feeds[2] = address(mockFeed2);
        feeds[3] = address(mockFeed3);

        superOracle = new SuperOracle(address(this), bases, quotes, providers, feeds);
    }

    function test_GetQuote() public view {
        uint256 baseAmount = 1e18;
        uint256 expectedQuote = 1e6; 
        
        uint256 quoteAmount = superOracle.getQuote(baseAmount, address(mockETH), address(mockUSD));
        assertEq(quoteAmount, expectedQuote, "Quote amount should match expected value");
    }
}
