// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockYoVault } from "../../mocks/MockYoVault.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { YoYieldSourceOracle } from "../../../src/accounting/oracles/YoYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";

/// @title YoYieldSourceOracleTest
/// @notice Comprehensive test suite for YoYieldSourceOracle
/// @dev Tests the key behavior: TVL includes both held shares AND pending async redemptions
contract YoYieldSourceOracleTest is Helpers {
    YoYieldSourceOracle public oracle;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    MockERC20 public weth; // 18 decimals (WETH-like)
    MockERC20 public usdc; // 6 decimals (USDC-like)

    MockYoVault public yoETH; // yoETH vault
    MockYoVault public yoUSDC; // yoUSDC vault

    address public superVault;
    address public feeRecipient;

    function setUp() public {
        // Deploy configuration and oracle
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        oracle = new YoYieldSourceOracle(address(ledgerConfig));

        // Create underlying assets with different decimals
        weth = new MockERC20("Wrapped ETH", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Create Yo Vaults
        yoETH = new MockYoVault(address(weth), "Yo ETH", "yoETH", 18);
        yoUSDC = new MockYoVault(address(usdc), "Yo USDC", "yoUSDC", 6);

        superVault = makeAddr("superVault");
        feeRecipient = makeAddr("feeRecipient");

        // Mint some assets to yoETH and yoUSDC for testing
        weth.mint(address(yoETH), 1000 ether);
        usdc.mint(address(yoUSDC), 1_000_000e6);

        // Register oracle in configuration
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 100, // 1%
            feeRecipient: feeRecipient,
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = keccak256("YO_YIELD_SOURCE_ORACLE");
        ledgerConfig.setYieldSourceOracles(salts, configs);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test decimals() returns correct value for 18 decimal vault (yoETH)
    function test_decimals_18decimals() public view {
        uint8 decimals = oracle.decimals(address(yoETH));
        assertEq(decimals, 18);
        assertEq(decimals, yoETH.decimals());
    }

    /// @notice Test decimals() returns correct value for 6 decimal vault (yoUSDC)
    function test_decimals_6decimals() public view {
        uint8 decimals = oracle.decimals(address(yoUSDC));
        assertEq(decimals, 6);
        assertEq(decimals, yoUSDC.decimals());
    }

    /*//////////////////////////////////////////////////////////////
                        GET SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getShareOutput() uses previewDeposit()
    function test_getShareOutput_usesPreviewDeposit() public view {
        uint256 assetsIn = 1000e18; // 1000 WETH

        uint256 oracleShares = oracle.getShareOutput(address(yoETH), address(weth), assetsIn);
        uint256 expectedShares = yoETH.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);
    }

    /// @notice Test getShareOutput() with 6 decimal asset
    function test_getShareOutput_6decimals() public view {
        uint256 assetsIn = 1000e6; // 1000 USDC

        uint256 oracleShares = oracle.getShareOutput(address(yoUSDC), address(usdc), assetsIn);
        uint256 expectedShares = yoUSDC.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);
    }

    /// @notice Fuzz test getShareOutput() across various amounts
    function testFuzz_getShareOutput(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1_000_000e18);

        uint256 oracleShares = oracle.getShareOutput(address(yoETH), address(weth), assetsIn);
        uint256 expectedShares = yoETH.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);
    }

    /*//////////////////////////////////////////////////////////////
                WITHDRAWAL SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getWithdrawalShareOutput() uses correct decimals
    function test_getWithdrawalShareOutput_correctDecimals_18decimals() public view {
        uint256 assetsIn = 1000e18;

        uint256 oneShare = 10 ** yoETH.decimals();
        uint256 assetsPerShare = yoETH.convertToAssets(oneShare);
        uint256 expectedShares = Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);

        uint256 actualShares = oracle.getWithdrawalShareOutput(address(yoETH), address(weth), assetsIn);

        assertEq(actualShares, expectedShares);
    }

    /// @notice Test getWithdrawalShareOutput() handles zero PPS gracefully
    function test_getWithdrawalShareOutput_zeroPPS() public {
        yoETH.setPricePerShare(0);

        uint256 shares = oracle.getWithdrawalShareOutput(address(yoETH), address(weth), 1000e18);
        assertEq(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    GET ASSET OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getAssetOutput() uses convertToAssets()
    function test_getAssetOutput_usesConvertToAssets() public view {
        uint256 sharesIn = 1000e18;

        uint256 oracleAssets = oracle.getAssetOutput(address(yoETH), address(weth), sharesIn);
        uint256 expectedAssets = yoETH.convertToAssets(sharesIn);

        assertEq(oracleAssets, expectedAssets);
    }

    /*//////////////////////////////////////////////////////////////
                    PRICE PER SHARE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getPricePerShare() returns correct value for 18 decimal vault
    function test_getPricePerShare_18decimals() public view {
        uint256 pps = oracle.getPricePerShare(address(yoETH));
        uint256 expectedPPS = yoETH.convertToAssets(10 ** yoETH.decimals());

        assertEq(pps, expectedPPS);
    }

    /// @notice Test getPricePerShare() returns correct value for 6 decimal vault
    function test_getPricePerShare_6decimals() public view {
        uint256 pps = oracle.getPricePerShare(address(yoUSDC));
        uint256 expectedPPS = yoUSDC.convertToAssets(10 ** yoUSDC.decimals());

        assertEq(pps, expectedPPS);
    }

    /// @notice Test getPricePerShare() reflects PPS changes
    function test_getPricePerShare_reflectsChanges() public {
        // Set PPS to 1.5x
        uint256 newPPS = 15e17; // 1.5 * 1e18
        yoETH.setPricePerShare(newPPS);

        uint256 pps = oracle.getPricePerShare(address(yoETH));
        assertEq(pps, newPPS);
    }

    /*//////////////////////////////////////////////////////////////
                        BALANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getBalanceOfOwner() returns only held shares (NOT pending)
    function test_getBalanceOfOwner_excludesPending() public {
        uint256 heldShares = 100e18;
        uint256 pendingAssets = 50e18;
        uint256 pendingShares = 50e18;

        // Mint shares to superVault
        yoETH.mint(superVault, heldShares);

        // Set pending redemption
        yoETH.setPendingRedeemRequest(superVault, pendingAssets, pendingShares);

        // getBalanceOfOwner should only return held shares
        uint256 balance = oracle.getBalanceOfOwner(address(yoETH), superVault);
        assertEq(balance, heldShares);
        assertEq(balance, yoETH.balanceOf(superVault));
    }

    /*//////////////////////////////////////////////////////////////
                    TVL BY OWNER TESTS (KEY FUNCTIONALITY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getTVLByOwnerOfShares() with no pending redeems (steady state)
    function test_getTVLByOwnerOfShares_noPending() public {
        uint256 shares = 100e18;
        yoETH.mint(superVault, shares);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        uint256 expectedTVL = yoETH.convertToAssets(shares);

        assertEq(tvl, expectedTVL);
    }

    /// @notice Test getTVLByOwnerOfShares() includes pending async redemption value
    /// @dev THIS IS THE KEY TEST - proves the oracle accounts for pending redemptions
    function test_getTVLByOwnerOfShares_includesPending() public {
        uint256 heldShares = 100e18;
        uint256 pendingAssets = 50e18;
        uint256 pendingShares = 50e18;

        // Mint shares to superVault
        yoETH.mint(superVault, heldShares);

        // Set pending redemption (simulates shares burned but not yet fulfilled)
        yoETH.setPendingRedeemRequest(superVault, pendingAssets, pendingShares);

        // TVL should include BOTH held value AND pending assets
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        uint256 heldValue = yoETH.convertToAssets(heldShares);
        uint256 expectedTVL = heldValue + pendingAssets;

        assertEq(tvl, expectedTVL);
    }

    /// @notice Test getTVLByOwnerOfShares() returns zero for empty position
    function test_getTVLByOwnerOfShares_zeroPosition() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        assertEq(tvl, 0);
    }

    /// @notice Test getTVLByOwnerOfShares() with only pending (all shares burned)
    function test_getTVLByOwnerOfShares_onlyPending() public {
        // No held shares, only pending
        uint256 pendingAssets = 100e18;
        uint256 pendingShares = 100e18;

        yoETH.setPendingRedeemRequest(superVault, pendingAssets, pendingShares);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        assertEq(tvl, pendingAssets);
    }

    /// @notice Test PPS stability during async redeem request
    /// @dev Key scenario: After requestRedeem(), TVL should remain stable
    function test_getTVLByOwnerOfShares_ppsStabilityOnRequest() public {
        uint256 initialShares = 100e18;
        yoETH.mint(superVault, initialShares);

        // Record TVL before requestRedeem
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);

        // Simulate requestRedeem: burn 50 shares, add to pending
        uint256 redeemShares = 50e18;
        uint256 redeemAssets = yoETH.convertToAssets(redeemShares);

        // Burn shares and add to pending (simulating requestRedeem)
        yoETH.burn(superVault, redeemShares);
        yoETH.setPendingRedeemRequest(superVault, redeemAssets, redeemShares);

        // Record TVL after requestRedeem
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);

        // TVL should be unchanged (held_value decreased, pending_value increased by same amount)
        assertEq(tvlBefore, tvlAfter, "PPS should remain stable during requestRedeem");
    }

    /// @notice Test PPS stability during async redeem fulfillment
    /// @dev Key scenario: After fulfillRedeem(), TVL should remain stable
    function test_getTVLByOwnerOfShares_ppsStabilityOnFulfillment() public {
        uint256 heldShares = 50e18;
        uint256 pendingAssets = 50e18;
        uint256 pendingShares = 50e18;

        // Setup: 50 held shares + 50 pending
        yoETH.mint(superVault, heldShares);
        yoETH.setPendingRedeemRequest(superVault, pendingAssets, pendingShares);

        // Record TVL before fulfillment
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);

        // Simulate fulfillment: pending cleared (assets transferred to SV)
        yoETH.setPendingRedeemRequest(superVault, 0, 0);
        // Note: In reality, liquid_assets would increase by pendingAssets
        // but that's tracked elsewhere (e.g., SV's balance of underlying asset)

        // Record TVL after fulfillment
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);

        // TVL from Yo oracle perspective decreases by pendingAssets
        // (but total SV TVL remains same when counting liquid assets)
        uint256 expectedTvlAfter = yoETH.convertToAssets(heldShares); // Only held shares now
        assertEq(tvlAfter, expectedTvlAfter);
        assertEq(tvlAfter, tvlBefore - pendingAssets);
    }

    /// @notice Test cumulative pending across multiple requests
    function test_getTVLByOwnerOfShares_cumulativePending() public {
        uint256 heldShares = 100e18;
        yoETH.mint(superVault, heldShares);

        // First request
        uint256 pending1 = 25e18;
        yoETH.setPendingRedeemRequest(superVault, pending1, 25e18);

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        assertEq(tvl1, yoETH.convertToAssets(heldShares) + pending1);

        // Second request (cumulative)
        uint256 pending2 = 75e18; // Total pending now
        yoETH.setPendingRedeemRequest(superVault, pending2, 75e18);

        uint256 tvl2 = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        assertEq(tvl2, yoETH.convertToAssets(heldShares) + pending2);
    }

    /*//////////////////////////////////////////////////////////////
                            TVL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getTVL() returns total assets
    function test_getTVL() public {
        // Set total assets in vault directly
        yoETH.setTotalAssets(500e18);

        uint256 tvl = oracle.getTVL(address(yoETH));
        uint256 expectedTVL = yoETH.totalAssets();

        assertEq(tvl, expectedTVL);
        assertEq(tvl, 500e18);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test oracle with very small amounts
    function test_edgeCase_smallAmounts() public view {
        uint256 smallAmount = 1; // 1 wei

        oracle.getShareOutput(address(yoETH), address(weth), smallAmount);
        oracle.getWithdrawalShareOutput(address(yoETH), address(weth), smallAmount);
        oracle.getAssetOutput(address(yoETH), address(weth), smallAmount);
    }

    /// @notice Test oracle with very large amounts
    function test_edgeCase_largeAmounts() public view {
        uint256 largeAmount = type(uint128).max;

        oracle.getShareOutput(address(yoETH), address(weth), largeAmount);
        oracle.getWithdrawalShareOutput(address(yoETH), address(weth), largeAmount);
        oracle.getAssetOutput(address(yoETH), address(weth), largeAmount);
    }

    /// @notice Test oracle with non-1:1 price per share
    function test_edgeCase_nonOneToOnePPS() public {
        // Set PPS to 2x (vault has appreciated)
        yoETH.setPricePerShare(2e18);

        uint256 shares = 100e18;
        yoETH.mint(superVault, shares);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        uint256 expectedTVL = 200e18; // 100 shares * 2x PPS

        assertEq(tvl, expectedTVL);
    }

    /// @notice Test 6 decimal vault TVL calculation
    function test_getTVLByOwnerOfShares_6decimals() public {
        uint256 shares = 1000e6; // 1000 yoUSDC shares
        yoUSDC.mint(superVault, shares);

        uint256 pendingAssets = 500e6;
        yoUSDC.setPendingRedeemRequest(superVault, pendingAssets, 500e6);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoUSDC), superVault);
        uint256 heldValue = yoUSDC.convertToAssets(shares);
        uint256 expectedTVL = heldValue + pendingAssets;

        assertEq(tvl, expectedTVL);
    }

    /// @notice Fuzz test getTVLByOwnerOfShares with various held and pending amounts
    function testFuzz_getTVLByOwnerOfShares(uint256 heldShares, uint256 pendingAssets) public {
        heldShares = bound(heldShares, 0, 1_000_000e18);
        pendingAssets = bound(pendingAssets, 0, 1_000_000e18);

        if (heldShares > 0) {
            yoETH.mint(superVault, heldShares);
        }

        if (pendingAssets > 0) {
            yoETH.setPendingRedeemRequest(superVault, pendingAssets, pendingAssets);
        }

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(yoETH), superVault);
        uint256 heldValue = heldShares > 0 ? yoETH.convertToAssets(heldShares) : 0;
        uint256 expectedTVL = heldValue + pendingAssets;

        assertEq(tvl, expectedTVL);
    }
}
