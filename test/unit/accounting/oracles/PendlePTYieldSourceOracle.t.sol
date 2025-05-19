// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { InternalHelpers } from "../../../utils/InternalHelpers.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { PendlePTYieldSourceOracle } from "../../../../src/core/accounting/oracles/PendlePTYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { MockStandardizedYield } from "../../../mocks/MockStandardizedYield.sol";
import { MockPendleMarket } from "../../../mocks/MockPendleMarket.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

contract PendlePtYieldSourceOracleTest is InternalHelpers, Helpers {
    PendlePTYieldSourceOracle public oracle;
    MockPendleMarket public mockPendleMarket;

    MockERC20 public assetSy;
    MockERC20 public assetPt;
    MockERC20 public assetYt;
    MockStandardizedYield public sy;
    MockStandardizedYield public pt;
    MockStandardizedYield public yt;
    
    address public constant OWNER = address(0x123);
    uint256 public constant INITIAL_UNDERLYING_AMOUNT = 1000e18;
    uint256 public constant INITIAL_PT_AMOUNT = 800e18; // Assuming some discount due to time value

    function setUp() public {
        assetSy = new MockERC20("Mock SY", "MSY", 18);
        assetPt = new MockERC20("Mock PT", "MPT", 18);
        assetYt = new MockERC20("Mock YT", "MYT", 18);

        oracle = new PendlePTYieldSourceOracle();
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        pt = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        yt = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));
    }

    function test_decimals() public view {
        assertEq(oracle.decimals(address(mockPendleMarket)), 18, "Incorrect decimals");
    }

    function test_getPricePerShare() public {
        uint256 rate = 1e18;
        mockPendleMarket.setPtToAssetRate(rate);
        assertEq(oracle.getPricePerShare(address(mockPendleMarket)), rate, "Incorrect price per share");
    }

    function test_getShareOutput() public {
        uint256 rate = 1e18;
        uint256 assetIn = 1e18;

        mockPendleMarket.setPtToAssetRate(rate);
        assertEq(oracle.getShareOutput(address(mockPendleMarket), address(0), assetIn), assetIn * rate/1e18, "Incorrect share output");
    }

    function test_getAssetOutput() public {
        uint256 rate = 1e18;
        uint256 assetIn = 1e18;

        mockPendleMarket.setPtToAssetRate(rate);
        assertEq(oracle.getAssetOutput(address(mockPendleMarket), address(0), assetIn), assetIn * rate/1e18, "Incorrect asset output");
    }

    function test_getTVLByOwnerOfShares() public {
        pt.setBalanceForAccount(address(this), 0);
        assertEq(oracle.getTVLByOwnerOfShares(address(mockPendleMarket), address(this)), 0, "Incorrect TVL for 0 shares");

        pt.setBalanceForAccount(address(this), 1e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(mockPendleMarket), address(this)), 1e18, "Incorrect TVL for 1e18 shares");
    }

    function test_getTVL() public {
        pt.setBalanceForAccount(address(this), 0);
        assertEq(oracle.getTVL(address(mockPendleMarket)), 0, "Incorrect TVL for 0 assets");

        pt.setBalanceForAccount(address(this), 1e18);
        assertEq(oracle.getTVL(address(mockPendleMarket)), 1e18, "Incorrect TVL");
    }

    function test_balanceOfOwner() public {
        pt.setBalanceForAccount(address(this), 0);
        assertEq(oracle.getBalanceOfOwner(address(mockPendleMarket), address(this)), 0, "Incorrect balance for 0 shares");

        pt.setBalanceForAccount(address(this), 1e18);
        assertEq(
            oracle.getBalanceOfOwner(address(mockPendleMarket), address(this)),
            1e18,
            "Incorrect balance for 1e18 shares"
        );
    }

    function testIsValidUnderlyingAsset() public {
        assertTrue(oracle.isValidUnderlyingAsset(address(mockPendleMarket), address(assetSy)));

        sy.setAssetType(1);
        vm.expectRevert();
        oracle.isValidUnderlyingAsset(address(mockPendleMarket), address(assetSy));

        sy.setAssetType(0);
        address[] memory yieldSourceAddresses = new address[](1);
        yieldSourceAddresses[0] = address(mockPendleMarket);
        address[] memory expectedUnderlyings = new address[](1);
        expectedUnderlyings[0] = address(assetSy);
        bool[] memory results = oracle.isValidUnderlyingAssets(yieldSourceAddresses, expectedUnderlyings);
        assertTrue(results[0], "First yield source should have valid underlying");
    }

    function testGetShareOutputWithDifferentDecimals() public {
        // Test with 6 decimals asset (like USDC)
        assetSy = new MockERC20("Mock SY 6", "MSY6", 6);
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));

        uint256 rate = 1e6; // 1:1 rate
        mockPendleMarket.setPtToAssetRate(rate);
        uint256 assetsIn = 1e6; // 1 USDC
        uint256 expectedShares = 1e6; // Should get 1 full share
        assertEq(
            oracle.getShareOutput(address(mockPendleMarket), address(0), assetsIn),
            expectedShares,
            "Incorrect share output for 6 decimals"
        );

        // Test with 24 decimals asset
        assetSy = new MockERC20("Mock SY 24", "MSY24", 24);
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));

        assetsIn = 1e24; // 1 full token
        expectedShares = 1e24; // Should get 1 full share
        assertEq(
            oracle.getShareOutput(address(mockPendleMarket), address(0), assetsIn),
            expectedShares,
            "Incorrect share output for 24 decimals"
        );
    }

    function testGetAssetOutputWithDifferentDecimals() public {
        // Test with 6 decimals asset
        assetSy = new MockERC20("Mock SY 6", "MSY6", 6);
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));

        uint256 rate = 1e6; // 1:1 rate
        mockPendleMarket.setPtToAssetRate(rate);
        uint256 sharesIn = 1e6; // 1 full share
        uint256 expectedAssets = 1000000; // Should get 1 USDC
        assertEq(
            oracle.getAssetOutput(address(mockPendleMarket), address(0), sharesIn),
            expectedAssets,
            "Incorrect asset output for 6 decimals"
        );

        // Test with 24 decimals asset
        assetSy = new MockERC20("Mock SY 24", "MSY24", 24);
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));

        sharesIn = 1e24; // 1 full share
        expectedAssets = 1e24; // Should get 1 full token
        assertEq(
            oracle.getAssetOutput(address(mockPendleMarket), address(0), sharesIn),
            expectedAssets,
            "Incorrect asset output for 24 decimals"
        );
    }

    function testGetTVLWithDifferentDecimals() public {
        // Test with 6 decimals asset
        assetSy = new MockERC20("Mock SY 6", "MSY6", 6);
        sy = new MockStandardizedYield(address(assetSy), address(assetPt), address(assetYt));
        mockPendleMarket = new MockPendleMarket(address(sy), address(pt), address(yt));

        uint256 rate = 1e6; // 1:1 rate
        mockPendleMarket.setPtToAssetRate(rate);
        pt.setTotalAsset(1e6); // 1 full PT
        uint256 expectedTVL = 1000000; // Should be 1 USDC
        assertEq(oracle.getTVL(address(mockPendleMarket)), expectedTVL, "Incorrect TVL for 6 decimals");
    }

    function testGetPricePerShareExtremeValues() public {
        // Test with very small rate
        uint256 smallRate = 1; // Smallest non-zero rate
        mockPendleMarket.setPtToAssetRate(smallRate);
        assertEq(oracle.getPricePerShare(address(mockPendleMarket)), 1e18, "Incorrect price for small rate");

        // Test with very large rate
        uint256 largeRate = type(uint256).max;
        mockPendleMarket.setPtToAssetRate(largeRate);
        assertEq(oracle.getPricePerShare(address(mockPendleMarket)), 1e18, "Incorrect price for large rate");
    }
}