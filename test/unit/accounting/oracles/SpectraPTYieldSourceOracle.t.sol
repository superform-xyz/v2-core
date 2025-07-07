// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { InternalHelpers } from "../../../utils/InternalHelpers.sol";
import { Helpers } from "../../../utils/Helpers.sol";

import { SpectraPTYieldSourceOracle } from "../../../../src/accounting/oracles/SpectraPTYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { MockSpectraPrincipalToken } from "../../../mocks/MockSpectraPrincipalToken.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../../src/accounting/SuperLedger.sol";

contract SpectraPTYieldSourceOracleTest is InternalHelpers, Helpers {
    SpectraPTYieldSourceOracle public oracle;
    MockSpectraPrincipalToken public mockPT;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    MockERC20 public mockUnderlying;
    MockERC20 public ibt;
    MockERC20 public yt;
    address public constant OWNER = address(0x123);
    uint256 public constant INITIAL_UNDERLYING_AMOUNT = 1000e18;
    uint256 public constant INITIAL_PT_AMOUNT = 800e18; // Assuming some discount due to time value

    function setUp() public {
        mockUnderlying = new MockERC20("Mock Underlying", "MO", 18);
        ibt = new MockERC20("Mock IBT", "MOIBT", 18);
        yt = new MockERC20("Mock YT", "MOYT", 18);

        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        oracle = new SpectraPTYieldSourceOracle(address(ledgerConfig));
        mockPT = new MockSpectraPrincipalToken(address(yt), address(ibt), address(mockUnderlying));
        mockPT.setUnderlyingAmount(INITIAL_UNDERLYING_AMOUNT);
        mockPT.mint(OWNER, INITIAL_PT_AMOUNT);
    }

    function test_decimals() public view {
        assertEq(oracle.decimals(address(mockPT)), 18, "Incorrect decimals");
    }

    function test_getShareOutput() public view {
        uint256 assetsIn = 100e18;
        uint256 expectedShares = mockPT.convertToPrincipal(assetsIn);
        uint256 actualShares = oracle.getShareOutput(address(mockPT), address(0), assetsIn);
        assertEq(actualShares, expectedShares, "Incorrect share output");
    }

    function test_getAssetOutput() public view {
        uint256 sharesIn = 100e18;
        uint256 expectedAssets = mockPT.convertToUnderlying(sharesIn);
        uint256 actualAssets = oracle.getAssetOutput(address(mockPT), address(0), sharesIn);
        assertEq(actualAssets, expectedAssets, "Incorrect asset output");
    }

    function test_getPricePerShare() public view {
        uint256 oneUnit = 10 ** oracle.decimals(address(mockPT));
        uint256 expectedPrice = mockPT.convertToUnderlying(oneUnit);
        uint256 actualPrice = oracle.getPricePerShare(address(mockPT));
        assertEq(actualPrice, expectedPrice, "Incorrect price per share");
    }

    function test_getBalanceOfOwner() public view {
        uint256 expectedBalance = mockPT.balanceOf(OWNER);
        uint256 actualBalance = oracle.getBalanceOfOwner(address(mockPT), OWNER);
        assertEq(actualBalance, expectedBalance, "Incorrect balance");
    }

    function test_getTVLByOwnerOfShares() public view {
        uint256 shares = mockPT.balanceOf(OWNER);
        uint256 expectedTVL = mockPT.convertToUnderlying(shares);
        uint256 actualTVL = oracle.getTVLByOwnerOfShares(address(mockPT), OWNER);
        assertEq(actualTVL, expectedTVL, "Incorrect TVL by owner");
    }

    function test_getTVLByOwnerOfShares_ZeroBalance() public view {
        uint256 actualTVL = oracle.getTVLByOwnerOfShares(address(mockPT), address(0x456));
        assertEq(actualTVL, 0, "TVL should be zero for address with no balance");
    }

    function test_getTVL() public view {
        uint256 expectedTVL = mockPT.totalAssets();
        uint256 actualTVL = oracle.getTVL(address(mockPT));
        assertEq(actualTVL, expectedTVL, "Incorrect total TVL");
    }

    function test_isValidUnderlyingAsset() public {
        address _mockUnderlying = address(0x789);
        mockPT.setUnderlying(_mockUnderlying);

        assertTrue(
            oracle.isValidUnderlyingAsset(address(mockPT), _mockUnderlying), "Should return true for correct underlying"
        );
        assertFalse(
            oracle.isValidUnderlyingAsset(address(mockPT), address(0x999)),
            "Should return false for incorrect underlying"
        );
    }

    function test_isValidUnderlyingAssets() public {
        address mockUnderlying1 = address(0x789);
        address mockUnderlying2 = address(0x987);

        MockSpectraPrincipalToken mockPT2 =
            new MockSpectraPrincipalToken(address(yt), address(ibt), address(mockUnderlying2));

        mockPT.setUnderlying(mockUnderlying1);
        mockPT2.setUnderlying(mockUnderlying2);

        address[] memory ptAddresses = new address[](2);
        ptAddresses[0] = address(mockPT);
        ptAddresses[1] = address(mockPT2);

        address[] memory expectedUnderlyings = new address[](2);
        expectedUnderlyings[0] = mockUnderlying1;
        expectedUnderlyings[1] = mockUnderlying2;

        bool[] memory results = oracle.isValidUnderlyingAssets(ptAddresses, expectedUnderlyings);

        assertTrue(results[0], "First PT should have valid underlying");
        assertTrue(results[1], "Second PT should have valid underlying");
    }

    function test_isValidUnderlyingAssets_ArrayLengthMismatch() public {
        address[] memory ptAddresses = new address[](2);
        address[] memory expectedUnderlyings = new address[](1);

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.isValidUnderlyingAssets(ptAddresses, expectedUnderlyings);
    }
}
