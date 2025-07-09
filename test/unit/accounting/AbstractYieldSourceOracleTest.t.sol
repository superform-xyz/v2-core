// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { AbstractYieldSourceOracle } from "../../../src/accounting/oracles/AbstractYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

contract MockYieldSourceOracle is AbstractYieldSourceOracle {
    MockERC20 public mockAsset;
    uint8 public constant DECIMALS = 18;
    uint256 public constant PRICE_PER_SHARE = 1e18;
    uint256 public constant TVL = 1000e18;

    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) {
        mockAsset = new MockERC20("Mock Asset", "MA", DECIMALS);
    }

    function decimals(address) external pure override returns (uint8) {
        return DECIMALS;
    }

    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    function getAssetOutput(address, address, uint256 sharesIn) public pure override returns (uint256) {
        return sharesIn;
    }

    function getPricePerShare(address) public pure override returns (uint256) {
        return PRICE_PER_SHARE;
    }

    function getTVLByOwnerOfShares(address, address) public pure override returns (uint256) {
        return TVL;
    }

    function getTVL(address) public pure override returns (uint256) {
        return TVL;
    }

    function getBalanceOfOwner(address, address) external pure override returns (uint256) {
        return TVL;
    }

    function isValidUnderlyingAsset(address, address) public pure override returns (bool) {
        return true;
    }

    function isValidUnderlyingAssets(
        address[] memory,
        address[] memory
    )
        external
        pure
        override
        returns (bool[] memory)
    {
        bool[] memory results = new bool[](2);
        results[0] = true;
        results[1] = true;
        return results;
    }
}

contract AbstractYieldSourceOracleTest is Helpers {
    MockYieldSourceOracle public oracle;
    address public mockYieldSource;
    address public mockAsset;
    address public mockOwner;
    address public mockSuperLedgerConfiguration;

    function setUp() public {
        mockSuperLedgerConfiguration = address(0x789);
        oracle = new MockYieldSourceOracle(mockSuperLedgerConfiguration);
        mockYieldSource = address(0x123);
        mockAsset = address(oracle.mockAsset());
        mockOwner = address(0x456);
    }

    function test_superLedgerConfiguration() public view {
        assertEq(oracle.superLedgerConfiguration(), mockSuperLedgerConfiguration);
    }

    function test_decimals() public view {
        assertEq(oracle.decimals(mockYieldSource), 18);
    }

    function test_getShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 sharesOut = oracle.getShareOutput(mockYieldSource, mockAsset, assetsIn);
        assertEq(sharesOut, assetsIn);
    }

    function test_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 assetsOut = oracle.getAssetOutput(mockYieldSource, mockAsset, sharesIn);
        assertEq(assetsOut, sharesIn);
    }

    function test_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(mockYieldSource);
        assertEq(price, 1e18);
    }

    function test_getTVLByOwnerOfShares() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(mockYieldSource, mockOwner);
        assertEq(tvl, 1000e18);
    }

    function test_getTVL() public view {
        uint256 tvl = oracle.getTVL(mockYieldSource);
        assertEq(tvl, 1000e18);
    }

    function test_getPricePerShareMultiple() public view {
        address[] memory yieldSources = new address[](2);
        yieldSources[0] = mockYieldSource;
        yieldSources[1] = mockYieldSource;

        uint256[] memory prices = oracle.getPricePerShareMultiple(yieldSources);
        assertEq(prices.length, 2);
        assertEq(prices[0], 1e18);
        assertEq(prices[1], 1e18);
    }

    function test_getBalanceOfOwner() public view {
        uint256 balance = oracle.getBalanceOfOwner(mockYieldSource, mockOwner);
        assertEq(balance, 1000e18);
    }

    function test_getTVLByOwnerOfSharesMultiple() public view {
        address[] memory yieldSources = new address[](2);
        address[][] memory owners = new address[][](2);

        yieldSources[0] = mockYieldSource;
        yieldSources[1] = mockYieldSource;

        owners[0] = new address[](1);
        owners[1] = new address[](1);
        owners[0][0] = mockOwner;
        owners[1][0] = mockOwner;

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(yieldSources, owners);
        assertEq(tvls.length, 2);
        assertEq(tvls[0].length, 1);
        assertEq(tvls[1].length, 1);
        assertEq(tvls[0][0], 1000e18);
        assertEq(tvls[1][0], 1000e18);
    }

    function test_getTVLMultiple() public view {
        address[] memory yieldSources = new address[](2);
        yieldSources[0] = mockYieldSource;
        yieldSources[1] = mockYieldSource;

        uint256[] memory tvls = oracle.getTVLMultiple(yieldSources);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 1000e18);
        assertEq(tvls[1], 1000e18);
    }

    function test_isValidUnderlyingAsset() public view {
        bool isValid = oracle.isValidUnderlyingAsset(mockYieldSource, mockAsset);
        assertTrue(isValid);
    }

    function test_isValidUnderlyingAssets() public view {
        address[] memory yieldSources = new address[](2);
        address[] memory expectedUnderlying = new address[](2);

        yieldSources[0] = mockYieldSource;
        yieldSources[1] = mockYieldSource;
        expectedUnderlying[0] = mockAsset;
        expectedUnderlying[1] = mockAsset;

        bool[] memory results = oracle.isValidUnderlyingAssets(yieldSources, expectedUnderlying);
        assertEq(results.length, 2);
        assertTrue(results[0]);
        assertTrue(results[1]);
    }

    function test_getTVLByOwnerOfSharesMultiple_ArrayLengthMismatch() public {
        address[] memory yieldSources = new address[](2);
        address[][] memory owners = new address[][](1); // Mismatched length

        yieldSources[0] = mockYieldSource;
        yieldSources[1] = mockYieldSource;

        owners[0] = new address[](1);
        owners[0][0] = mockOwner;

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(yieldSources, owners);
    }
}
