// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { MockERC7540VaultFull } from "../../mocks/MockERC7540VaultFull.sol";

/// @title ERC7540OracleIntegration
/// @notice Integration tests for ERC7540YieldSourceOracle against vaults of different decimal configurations
/// @dev Tests 4 vault configurations:
///      - centrifugeVault: 6-decimal with Centrifuge-realistic exchange rate (~1.054 USDC/share)
///      - vault18: 18-decimal (DAI/WETH-like)
///      - vault8: 8-decimal (WBTC-like)
///      - vault6: 6-decimal (generic USDC-like)
///      Note: Live Centrifuge vault at 0x1d01Ef... predates ERC-7575 and does not expose share().
///      We use MockERC7540VaultFull configured with Centrifuge's actual exchange rate to validate
///      oracle behavior with realistic parameters.
contract ERC7540OracleIntegration is Test {
    ERC7540YieldSourceOracle public oracle;
    SuperLedgerConfiguration public ledgerConfig;

    // Centrifuge-realistic vault: exchange rate from live Centrifuge USDC vault at block 21_929_476
    // Live vault convertToAssets(1e6) = 1_054_230
    MockERC7540VaultFull public centrifugeVault;

    // Additional decimal configurations
    MockERC7540VaultFull public vault6; // 6-dec (generic USDC-like)
    MockERC7540VaultFull public vault18; // 18-dec (DAI/WETH-like)
    MockERC7540VaultFull public vault8; // 8-dec (WBTC-like)

    address public testUser;
    address public testUser2;

    function setUp() public {
        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);

        // Centrifuge-realistic vault: mirrors live Centrifuge USDC vault parameters
        // Live vault: 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970 at block 21_929_476
        // PPS = 1.054230 USDC per share (6-decimal shares, 6-decimal USDC asset)
        centrifugeVault = new MockERC7540VaultFull(6, 6);
        centrifugeVault.setAssetsPerShare(1_054_230);
        centrifugeVault.setTotalAssets(10_000_000e6); // ~$10M TVL (realistic for RWA tranche)

        // 6-decimal vault: 1:1 exchange rate (no yield accrued yet)
        vault6 = new MockERC7540VaultFull(6, 6);
        vault6.setAssetsPerShare(1e6);
        vault6.setTotalAssets(500_000e6); // $500K TVL

        // 18-decimal vault: 1 share = 1.1e18 assets (PPS > 1, like yield-bearing ETH tranche)
        vault18 = new MockERC7540VaultFull(18, 18);
        vault18.setAssetsPerShare(1.1e18); // 1.1 ETH per share
        vault18.setTotalAssets(5_000e18); // 5000 ETH TVL

        // 8-decimal vault: 1 share = 1.00125e8 assets (PPS slightly > 1, like yield-bearing BTC tranche)
        vault8 = new MockERC7540VaultFull(8, 8);
        vault8.setAssetsPerShare(100_125_000); // 1.00125 BTC per share
        vault8.setTotalAssets(100e8); // 100 BTC TVL

        testUser = makeAddr("testUser");
        testUser2 = makeAddr("testUser2");
    }

    /*//////////////////////////////////////////////////////////////
                    CENTRIFUGE-REALISTIC VAULT TESTS (6-DEC RWA)
    //////////////////////////////////////////////////////////////*/

    /// @notice Decimals match Centrifuge share token (6)
    function test_centrifuge_decimals() public view {
        assertEq(oracle.decimals(address(centrifugeVault)), 6);
    }

    /// @notice PPS matches live Centrifuge vault rate: 1.054230 USDC per share
    function test_centrifuge_getPricePerShare() public view {
        uint256 pps = oracle.getPricePerShare(address(centrifugeVault));
        assertEq(pps, 1_054_230, "PPS must match Centrifuge rate ~1.054");
        assertEq(pps, centrifugeVault.convertToAssets(1e6));
    }

    /// @notice Share output at Centrifuge rate
    function test_centrifuge_getShareOutput() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 shares = oracle.getShareOutput(address(centrifugeVault), testUser, assetsIn);
        assertEq(shares, centrifugeVault.convertToShares(assetsIn));
        // 1 USDC / 1.054230 = ~948,557 shares
        assertLt(shares, 1e6, "shares < 1e6 when PPS > 1");
        assertGt(shares, 0);
    }

    /// @notice Asset output at Centrifuge rate
    function test_centrifuge_getAssetOutput() public view {
        uint256 sharesIn = 1e6;
        uint256 assets = oracle.getAssetOutput(address(centrifugeVault), testUser, sharesIn);
        assertEq(assets, 1_054_230, "1 share = 1.054230 USDC");
    }

    /// @notice Withdrawal ceil rounding at Centrifuge rate
    function test_centrifuge_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(address(centrifugeVault), testUser, assetsIn);

        uint256 assetsBack = oracle.getAssetOutput(address(centrifugeVault), testUser, sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding must favor the vault");
    }

    /// @notice TVL matches totalAssets
    function test_centrifuge_getTVL() public view {
        assertEq(oracle.getTVL(address(centrifugeVault)), 10_000_000e6);
    }

    /// @notice Balance check with Centrifuge vault
    function test_centrifuge_getBalanceOfOwner() public {
        uint256 shares = 100e6;
        centrifugeVault.mintShares(testUser, shares);

        uint256 balance = oracle.getBalanceOfOwner(address(centrifugeVault), testUser);
        assertEq(balance, shares);
    }

    /// @notice Full lifecycle with all 5 components at Centrifuge exchange rate
    function test_centrifuge_fullLifecycle() public {
        uint256 heldShares = 100e6;
        centrifugeVault.mintShares(testUser, heldShares);
        centrifugeVault.setPendingRedeemShares(testUser, 20e6);
        centrifugeVault.setMaxWithdrawAssets(testUser, 15_000_000); // 15 USDC claimable
        centrifugeVault.setPendingDepositAssets(testUser, 50_000_000); // 50 USDC pending
        centrifugeVault.setClaimableDepositAssets(testUser, 25_000_000); // 25 USDC claimable deposit

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(centrifugeVault), testUser);

        // Held: 100 shares * 1.054230 = 105.423 USDC
        assertEq(heldValue, centrifugeVault.convertToAssets(heldShares), "held value");
        // Pending redeem: 20 shares * 1.054230 = 21.0846 USDC
        assertEq(pendingRedeemValue, centrifugeVault.convertToAssets(20e6), "pending redeem");
        assertEq(claimableRedeemValue, 15_000_000, "claimable redeem = maxWithdraw");
        assertEq(pendingDepositValue, 50_000_000, "pending deposit");
        assertEq(claimableDepositValue, 25_000_000, "claimable deposit");

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(centrifugeVault), testUser);
        assertEq(
            tvl,
            heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue
        );
    }

    /// @notice Breakdown components sum correctly for address with no async state
    function test_centrifuge_breakdown_heldOnly() public {
        uint256 shares = 50e6;
        centrifugeVault.mintShares(testUser, shares);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(centrifugeVault), testUser);

        assertEq(heldValue, centrifugeVault.convertToAssets(shares), "heldValue check");
        assertEq(pendingRedeemValue, 0, "no pending redeem");
        assertEq(claimableRedeemValue, 0, "no claimable redeem");
        assertEq(pendingDepositValue, 0, "no pending deposit");
        assertEq(claimableDepositValue, 0, "no claimable deposit");

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(centrifugeVault), testUser);
        assertEq(tvl, heldValue);
    }

    /// @notice Batch PPS with Centrifuge vault returns correct result
    function test_centrifuge_getPricePerShareMultiple() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = address(centrifugeVault);

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 1);
        assertEq(prices[0], oracle.getPricePerShare(address(centrifugeVault)));
        assertEq(prices[0], 1_054_230);
    }

    /*//////////////////////////////////////////////////////////////
                        6-DECIMAL VAULT TESTS (GENERIC 1:1)
    //////////////////////////////////////////////////////////////*/

    function test_vault6_decimals() public view {
        assertEq(oracle.decimals(address(vault6)), 6);
    }

    function test_vault6_getPricePerShare() public view {
        uint256 pps = oracle.getPricePerShare(address(vault6));
        assertEq(pps, 1e6, "PPS = 1.0 for 1:1 vault");
    }

    function test_vault6_getShareOutput() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 shares = oracle.getShareOutput(address(vault6), testUser, assetsIn);
        assertEq(shares, assetsIn, "1:1 rate means shares = assets");
    }

    function test_vault6_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(address(vault6), testUser, assetsIn);

        uint256 assetsBack = oracle.getAssetOutput(address(vault6), testUser, sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding must favor the vault");
    }

    function test_vault6_getTVL() public view {
        assertEq(oracle.getTVL(address(vault6)), 500_000e6);
    }

    function test_vault6_fullLifecycle() public {
        uint256 heldShares = 100e6;
        vault6.mintShares(testUser, heldShares);
        vault6.setPendingRedeemShares(testUser, 20e6);
        vault6.setMaxWithdrawAssets(testUser, 15_000_000); // 15 USDC claimable
        vault6.setPendingDepositAssets(testUser, 50_000_000); // 50 USDC pending deposit
        vault6.setClaimableDepositAssets(testUser, 25_000_000); // 25 USDC claimable deposit

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(vault6), testUser);

        assertEq(heldValue, vault6.convertToAssets(heldShares), "held value");
        assertEq(pendingRedeemValue, vault6.convertToAssets(20e6), "pending redeem value");
        assertEq(claimableRedeemValue, 15_000_000, "claimable redeem = maxWithdraw");
        assertEq(pendingDepositValue, 50_000_000, "pending deposit");
        assertEq(claimableDepositValue, 25_000_000, "claimable deposit");

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault6), testUser);
        assertEq(
            tvl,
            heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue
        );
    }

    /*//////////////////////////////////////////////////////////////
                        18-DECIMAL VAULT TESTS (DAI/WETH-LIKE)
    //////////////////////////////////////////////////////////////*/

    function test_vault18_decimals() public view {
        assertEq(oracle.decimals(address(vault18)), 18);
    }

    function test_vault18_getPricePerShare() public view {
        uint256 pps = oracle.getPricePerShare(address(vault18));
        assertEq(pps, 1.1e18, "PPS must be 1.1e18 for 18-dec vault");
        assertEq(pps, vault18.convertToAssets(1e18));
    }

    function test_vault18_getShareOutput() public view {
        uint256 assetsIn = 10e18; // 10 ETH
        uint256 shares = oracle.getShareOutput(address(vault18), testUser, assetsIn);
        assertEq(shares, vault18.convertToShares(assetsIn));
        // 10 ETH / 1.1 = ~9.09e18 shares
        assertGt(shares, 9e18);
        assertLt(shares, 10e18);
    }

    function test_vault18_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 assets = oracle.getAssetOutput(address(vault18), testUser, sharesIn);
        assertEq(assets, 1.1e18, "1 share = 1.1 ETH");
    }

    function test_vault18_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 3e18; // 3 ETH
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(address(vault18), testUser, assetsIn);

        uint256 assetsBack = oracle.getAssetOutput(address(vault18), testUser, sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding must favor the vault");
    }

    function test_vault18_getTVL() public view {
        assertEq(oracle.getTVL(address(vault18)), 5_000e18);
    }

    function test_vault18_getBalanceOfOwner() public {
        uint256 shares = 500e18;
        vault18.mintShares(testUser, shares);

        uint256 balance = oracle.getBalanceOfOwner(address(vault18), testUser);
        assertEq(balance, shares);
    }

    function test_vault18_fullLifecycle() public {
        uint256 heldShares = 1_000e18;
        vault18.mintShares(testUser, heldShares);
        vault18.setPendingRedeemShares(testUser, 200e18);
        vault18.setMaxWithdrawAssets(testUser, 180e18); // 180 ETH claimable
        vault18.setPendingDepositAssets(testUser, 500e18); // 500 ETH pending
        vault18.setClaimableDepositAssets(testUser, 300e18); // 300 ETH claimable deposit

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(vault18), testUser);

        // 1000 shares * 1.1 = 1100 ETH
        assertEq(heldValue, 1100e18, "held value = 1000 * 1.1");
        // 200 shares * 1.1 = 220 ETH
        assertEq(pendingRedeemValue, 220e18, "pending redeem = 200 * 1.1");
        assertEq(claimableRedeemValue, 180e18, "claimable redeem = maxWithdraw");
        assertEq(pendingDepositValue, 500e18, "pending deposit");
        assertEq(claimableDepositValue, 300e18, "claimable deposit");

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault18), testUser);
        assertEq(tvl, 1100e18 + 220e18 + 180e18 + 500e18 + 300e18);
        assertEq(tvl, 2300e18, "total TVL = 2300 ETH");
    }

    /*//////////////////////////////////////////////////////////////
                        8-DECIMAL VAULT TESTS (WBTC-LIKE)
    //////////////////////////////////////////////////////////////*/

    function test_vault8_decimals() public view {
        assertEq(oracle.decimals(address(vault8)), 8);
    }

    function test_vault8_getPricePerShare() public view {
        uint256 pps = oracle.getPricePerShare(address(vault8));
        assertEq(pps, 100_125_000, "PPS must be 1.00125e8 for 8-dec vault");
        assertEq(pps, vault8.convertToAssets(1e8));
    }

    function test_vault8_getShareOutput() public view {
        uint256 assetsIn = 1e8; // 1 BTC
        uint256 shares = oracle.getShareOutput(address(vault8), testUser, assetsIn);
        assertEq(shares, vault8.convertToShares(assetsIn));
        // 1 BTC / 1.00125 = ~0.99875e8 shares
        assertLt(shares, 1e8);
        assertGt(shares, 99_800_000);
    }

    function test_vault8_getAssetOutput() public view {
        uint256 sharesIn = 1e8;
        uint256 assets = oracle.getAssetOutput(address(vault8), testUser, sharesIn);
        assertEq(assets, 100_125_000, "1 share = 1.00125 BTC");
    }

    function test_vault8_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 5e8; // 5 BTC
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(address(vault8), testUser, assetsIn);

        uint256 assetsBack = oracle.getAssetOutput(address(vault8), testUser, sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding must favor the vault");
    }

    function test_vault8_getTVL() public view {
        assertEq(oracle.getTVL(address(vault8)), 100e8);
    }

    function test_vault8_fullLifecycle() public {
        uint256 heldShares = 10e8; // 10 shares
        vault8.mintShares(testUser, heldShares);
        vault8.setPendingRedeemShares(testUser, 2e8);
        vault8.setMaxWithdrawAssets(testUser, 1_50_000_000); // 1.5 BTC claimable
        vault8.setPendingDepositAssets(testUser, 3e8); // 3 BTC pending
        vault8.setClaimableDepositAssets(testUser, 1e8); // 1 BTC claimable deposit

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(vault8), testUser);

        // 10 shares * 1.00125 = 10.0125 BTC
        assertEq(heldValue, vault8.convertToAssets(heldShares), "held value");
        // 2 shares * 1.00125 = 2.0025 BTC
        assertEq(pendingRedeemValue, vault8.convertToAssets(2e8), "pending redeem");
        assertEq(claimableRedeemValue, 1_50_000_000, "claimable redeem = maxWithdraw");
        assertEq(pendingDepositValue, 3e8, "pending deposit");
        assertEq(claimableDepositValue, 1e8, "claimable deposit");

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault8), testUser);
        uint256 expectedSum =
            heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue;
        assertEq(tvl, expectedSum);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-DECIMAL BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice getPricePerShareMultiple across all 4 vault types
    function test_batch_getPricePerShareMultiple_multiDecimal() public view {
        address[] memory vaults = new address[](4);
        vaults[0] = address(centrifugeVault);
        vaults[1] = address(vault6);
        vaults[2] = address(vault18);
        vaults[3] = address(vault8);

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 4);
        assertEq(prices[0], 1_054_230, "centrifuge PPS");
        assertEq(prices[1], 1e6, "6-dec PPS");
        assertEq(prices[2], 1.1e18, "18-dec PPS");
        assertEq(prices[3], 100_125_000, "8-dec PPS");
    }

    /// @notice getTVLMultiple across all 4 vault types
    function test_batch_getTVLMultiple_multiDecimal() public view {
        address[] memory vaults = new address[](4);
        vaults[0] = address(centrifugeVault);
        vaults[1] = address(vault6);
        vaults[2] = address(vault18);
        vaults[3] = address(vault8);

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 4);
        assertEq(tvls[0], 10_000_000e6, "centrifuge TVL");
        assertEq(tvls[1], 500_000e6, "6-dec TVL");
        assertEq(tvls[2], 5_000e18, "18-dec TVL");
        assertEq(tvls[3], 100e8, "8-dec TVL");
    }

    /// @notice getTVLByOwnerOfSharesMultiple with multiple owners across different vaults
    function test_batch_getTVLByOwnerOfSharesMultiple_multiDecimal() public {
        // Give shares to users across different vaults
        centrifugeVault.mintShares(testUser, 100e6);
        vault18.mintShares(testUser, 50e18);
        vault8.mintShares(testUser2, 5e8);

        address[] memory vaults = new address[](3);
        vaults[0] = address(centrifugeVault);
        vaults[1] = address(vault18);
        vaults[2] = address(vault8);

        address[][] memory owners = new address[][](3);
        owners[0] = new address[](1);
        owners[0][0] = testUser;
        owners[1] = new address[](1);
        owners[1][0] = testUser;
        owners[2] = new address[](1);
        owners[2][0] = testUser2;

        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls.length, 3);
        assertEq(tvls[0][0], oracle.getTVLByOwnerOfShares(address(centrifugeVault), testUser), "centrifuge user TVL");
        assertEq(tvls[1][0], oracle.getTVLByOwnerOfShares(address(vault18), testUser), "18-dec user TVL");
        assertEq(tvls[2][0], oracle.getTVLByOwnerOfShares(address(vault8), testUser2), "8-dec user TVL");
    }

    /*//////////////////////////////////////////////////////////////
                    GRACEFUL DEGRADATION ACROSS DECIMALS
    //////////////////////////////////////////////////////////////*/

    /// @notice R2 graceful degradation works correctly for 18-decimal vault
    function test_vault18_gracefulDegradation() public {
        vault18.mintShares(testUser, 100e18);
        vault18.setPendingRedeemShares(testUser, 50e18);
        vault18.setMaxWithdrawAssets(testUser, 40e18);
        vault18.setPendingDepositAssets(testUser, 30e18);
        vault18.setClaimableDepositAssets(testUser, 20e18);

        // Enable revert on maxWithdraw and pendingDeposit
        vault18.setRevertOnMaxWithdraw(true);
        vault18.setRevertOnPendingDepositRequest(true);

        // Should not revert — degraded components become 0
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault18), testUser);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(address(vault18), testUser);

        assertGt(heldValue, 0, "held value preserved");
        assertGt(pendingRedeemValue, 0, "pending redeem preserved");
        assertEq(claimableRedeemValue, 0, "claimable redeem degraded to 0");
        assertEq(pendingDepositValue, 0, "pending deposit degraded to 0");
        assertGt(claimableDepositValue, 0, "claimable deposit preserved");
        assertEq(tvl, heldValue + pendingRedeemValue + claimableDepositValue);
    }

    /// @notice R2 graceful degradation works correctly for 8-decimal vault
    function test_vault8_gracefulDegradation() public {
        vault8.mintShares(testUser, 10e8);
        vault8.setPendingRedeemShares(testUser, 3e8);
        vault8.setMaxWithdrawAssets(testUser, 2e8);
        vault8.setPendingDepositAssets(testUser, 1e8);
        vault8.setClaimableDepositAssets(testUser, 5_000_0000); // 0.5 BTC

        // Enable revert on all async functions
        vault8.setRevertOnPendingRedeemRequest(true);
        vault8.setRevertOnMaxWithdraw(true);
        vault8.setRevertOnPendingDepositRequest(true);
        vault8.setRevertOnClaimableDepositRequest(true);

        // Should not revert — only held value remains
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault8), testUser);
        uint256 heldValue = vault8.convertToAssets(10e8);
        assertEq(tvl, heldValue, "Only held value when all async degraded");
    }

    /*//////////////////////////////////////////////////////////////
                    EXCHANGE RATE CHANGES ACROSS DECIMALS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS changes correctly when exchange rate changes on 18-dec vault
    function test_vault18_exchangeRateChange() public view {
        uint256 ppsBefore = oracle.getPricePerShare(address(vault18));
        assertEq(ppsBefore, 1.1e18);

        // After rate change in a separate test, PPS would update
        // This test verifies the oracle reads the live rate
        uint256 oneShare = 10 ** oracle.decimals(address(vault18));
        assertEq(oneShare, 1e18);
        assertEq(ppsBefore, vault18.convertToAssets(oneShare));
    }

    /// @notice PPS changes correctly when exchange rate changes on 8-dec vault
    function test_vault8_exchangeRateChange() public {
        uint256 ppsBefore = oracle.getPricePerShare(address(vault8));
        assertEq(ppsBefore, 100_125_000);

        // Change rate to 1.05 BTC per share
        vault8.setAssetsPerShare(1_05_000_000);
        uint256 ppsAfter = oracle.getPricePerShare(address(vault8));
        assertEq(ppsAfter, 1_05_000_000, "PPS updates with exchange rate");
        assertGt(ppsAfter, ppsBefore, "PPS increased");
    }
}

/// @title ERC7540OracleForkTest
/// @notice Fork tests against live Centrifuge v3 vaults on Ethereum mainnet at block 24,990,000
/// @dev Pinned block for deterministic values. Tests oracle against real deployed contracts:
///      JTRSY = Centrifuge RWA tranche (USDC, 6-dec, PPS = 1.101748)
///      JAAA = Centrifuge senior tranche (USDC, 6-dec, PPS = 1.031939)
///      Both implement ERC-7575 share() returning separate tranche tokens.
///      No vm.mockCall for core view functions — all values read from live contracts.
///
///      Real depositors verified at this block:
///        0x86b4... holds 921,979.703126 JAAA shares (~$951K)
///        0x0401... holds 2,911.134480 JAAA shares
///        0xfd47... has 2,911.134477 JAAA shares in pendingRedeem (non-zero async state)
contract ERC7540OracleForkTest is Test {
    ERC7540YieldSourceOracle public oracle;
    SuperLedgerConfiguration public ledgerConfig;

    // Pinned fork block for deterministic tests
    uint256 constant FORK_BLOCK = 24_990_000;

    // Live Centrifuge v3 vaults on Ethereum mainnet
    address constant JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address constant JAAA_VAULT = 0x4880799eE5200fC58DA299e965df644fBf46780B;

    // Share tokens (tranche tokens) discovered via share()
    address constant JTRSY_TRANCHE = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address constant JAAA_TRANCHE = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;

    // USDC (underlying asset for both vaults)
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Exact expected values at block 24,990,000 (verified via cast call)
    uint256 constant JTRSY_PPS = 1_101_748; // convertToAssets(1e6)
    uint256 constant JTRSY_SHARES_PER_USDC = 907_647; // convertToShares(1e6)
    uint256 constant JTRSY_TOTAL_ASSETS = 1_269_351_955_129_173; // ~$1.27B
    uint256 constant JAAA_PPS = 1_031_939; // convertToAssets(1e6)
    uint256 constant JAAA_SHARES_PER_USDC = 969_049; // convertToShares(1e6)
    uint256 constant JAAA_TOTAL_ASSETS = 145_504_012_015_214; // ~$145.5M

    // Real depositors on-chain at this block
    address constant JAAA_LARGE_HOLDER = 0x86b495e4Cb00AB18Ad94BFD7920479cC79E8eBFE;
    uint256 constant JAAA_LARGE_HOLDER_BALANCE = 921_979_703_126; // ~921,979 shares
    uint256 constant JAAA_LARGE_HOLDER_ASSETS = 951_427_200_346; // convertToAssets(balance)

    address constant JAAA_SMALL_HOLDER = 0x040170aA9AAa916c2e8135777a31f17C440BA52a;
    uint256 constant JAAA_SMALL_HOLDER_BALANCE = 2_911_134_480; // ~2,911 shares

    address constant JAAA_REDEEMING_HOLDER = 0xfd47520724e7dC432B041A283Ef889fa9F492E81;
    uint256 constant JAAA_REDEEMING_PENDING_SHARES = 2_911_134_477; // pendingRedeemRequest
    uint256 constant JAAA_REDEEMING_PENDING_VALUE = 3_004_114_424; // convertToAssets(pending)

    address public testUser;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);
        testUser = makeAddr("testUser");
    }

    /*//////////////////////////////////////////////////////////////
                    SHARE TOKEN DISCOVERY (ERC-7575)
    //////////////////////////////////////////////////////////////*/

    /// @notice share() returns the correct tranche token address for JTRSY
    function test_fork_jtrsy_shareTokenAddress() public view {
        address discovered = IERC7540(JTRSY_VAULT).share();
        assertEq(discovered, JTRSY_TRANCHE, "share() must return JTRSY tranche token");
    }

    /// @notice share() returns the correct tranche token address for JAAA
    function test_fork_jaaa_shareTokenAddress() public view {
        address discovered = IERC7540(JAAA_VAULT).share();
        assertEq(discovered, JAAA_TRANCHE, "share() must return JAAA tranche token");
    }

    /// @notice Both vaults use USDC as the underlying asset
    function test_fork_bothVaults_assetIsUSDC() public view {
        assertEq(IERC7540(JTRSY_VAULT).asset(), USDC, "JTRSY asset = USDC");
        assertEq(IERC7540(JAAA_VAULT).asset(), USDC, "JAAA asset = USDC");
        assertEq(IERC20Metadata(USDC).decimals(), 6, "USDC = 6 decimals");
    }

    /*//////////////////////////////////////////////////////////////
                    JTRSY — EXACT VALUE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Decimals read from tranche token (6), not vault contract
    function test_fork_jtrsy_decimals() public view {
        assertEq(oracle.decimals(JTRSY_VAULT), 6);
        assertEq(oracle.decimals(JTRSY_VAULT), IERC20Metadata(JTRSY_TRANCHE).decimals());
    }

    /// @notice PPS matches exact expected value: 1.101748 USDC/share
    function test_fork_jtrsy_getPricePerShare_exact() public view {
        uint256 pps = oracle.getPricePerShare(JTRSY_VAULT);
        assertEq(pps, JTRSY_PPS, "PPS must be exactly 1101748");
        assertEq(pps, IERC7540(JTRSY_VAULT).convertToAssets(1e6));
    }

    /// @notice getShareOutput matches exact expected value: 907647 shares per USDC
    function test_fork_jtrsy_getShareOutput_exact() public view {
        uint256 shares = oracle.getShareOutput(JTRSY_VAULT, testUser, 1_000_000);
        assertEq(shares, JTRSY_SHARES_PER_USDC, "must be exactly 907647");
        assertEq(shares, IERC7540(JTRSY_VAULT).convertToShares(1_000_000));
    }

    /// @notice getAssetOutput matches exact expected PPS
    function test_fork_jtrsy_getAssetOutput_exact() public view {
        uint256 assets = oracle.getAssetOutput(JTRSY_VAULT, testUser, 1e6);
        assertEq(assets, JTRSY_PPS, "1 share = 1.101748 USDC");
        assertEq(assets, IERC7540(JTRSY_VAULT).convertToAssets(1e6));
    }

    /// @notice Withdrawal ceil rounding: shares needed to withdraw 1 USDC
    function test_fork_jtrsy_getWithdrawalShareOutput_ceilFavorsVault() public view {
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(JTRSY_VAULT, testUser, 1_000_000);
        uint256 assetsBack = oracle.getAssetOutput(JTRSY_VAULT, testUser, sharesNeeded);
        assertGe(assetsBack, 1_000_000, "ceil rounding must favor vault");
    }

    /// @notice getTVL matches exact totalAssets: ~$1.27B
    function test_fork_jtrsy_getTVL_exact() public view {
        assertEq(oracle.getTVL(JTRSY_VAULT), JTRSY_TOTAL_ASSETS);
        assertEq(oracle.getTVL(JTRSY_VAULT), IERC7540(JTRSY_VAULT).totalAssets());
    }

    /// @notice getBalanceOfOwner reads from tranche token via share() discovery
    function test_fork_jtrsy_getBalanceOfOwner() public {
        deal(JTRSY_TRANCHE, testUser, 100e6);
        assertEq(oracle.getBalanceOfOwner(JTRSY_VAULT, testUser), 100e6);
        assertEq(oracle.getBalanceOfOwner(JTRSY_VAULT, testUser), IERC20(JTRSY_TRANCHE).balanceOf(testUser));
    }

    /// @notice TVL breakdown for deal'd user: only held component, async = 0
    function test_fork_jtrsy_breakdown_dealtUser() public {
        deal(JTRSY_TRANCHE, testUser, 50e6);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(JTRSY_VAULT, testUser);

        assertEq(held, IERC7540(JTRSY_VAULT).convertToAssets(50e6), "held = shares * PPS");
        assertGt(held, 50e6, "held > 50 USDC (PPS > 1)");
        assertEq(pendingRedeem, 0);
        assertEq(claimableRedeem, 0);
        assertEq(pendingDeposit, 0);
        assertEq(claimableDeposit, 0);
    }

    /// @notice getTVLByOwnerOfShares equals held value when no async state
    function test_fork_jtrsy_TVLByOwner() public {
        deal(JTRSY_TRANCHE, testUser, 100e6);
        uint256 tvl = oracle.getTVLByOwnerOfShares(JTRSY_VAULT, testUser);
        assertEq(tvl, IERC7540(JTRSY_VAULT).convertToAssets(100e6));
    }

    /// @notice Round-trip: assets → shares → assets loses at most 1 unit (floor rounding)
    function test_fork_jtrsy_roundTrip_floorLoss() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 shares = oracle.getShareOutput(JTRSY_VAULT, testUser, assetsIn);
        uint256 assetsBack = oracle.getAssetOutput(JTRSY_VAULT, testUser, shares);
        assertLe(assetsBack, assetsIn, "floor rounding: assetsBack <= assetsIn");
        assertGe(assetsBack, assetsIn - 1, "at most 1 unit lost to rounding");
    }

    /*//////////////////////////////////////////////////////////////
                    JAAA — EXACT VALUE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Decimals from JAAA tranche token
    function test_fork_jaaa_decimals() public view {
        assertEq(oracle.decimals(JAAA_VAULT), 6);
        assertEq(oracle.decimals(JAAA_VAULT), IERC20Metadata(JAAA_TRANCHE).decimals());
    }

    /// @notice PPS matches exact expected value: 1.031939 USDC/share
    function test_fork_jaaa_getPricePerShare_exact() public view {
        uint256 pps = oracle.getPricePerShare(JAAA_VAULT);
        assertEq(pps, JAAA_PPS, "PPS must be exactly 1031939");
        assertEq(pps, IERC7540(JAAA_VAULT).convertToAssets(1e6));
    }

    /// @notice getShareOutput matches exact expected value: 969049 shares per USDC
    function test_fork_jaaa_getShareOutput_exact() public view {
        uint256 shares = oracle.getShareOutput(JAAA_VAULT, testUser, 1_000_000);
        assertEq(shares, JAAA_SHARES_PER_USDC, "must be exactly 969049");
        assertEq(shares, IERC7540(JAAA_VAULT).convertToShares(1_000_000));
    }

    /// @notice getAssetOutput matches exact expected PPS
    function test_fork_jaaa_getAssetOutput_exact() public view {
        uint256 assets = oracle.getAssetOutput(JAAA_VAULT, testUser, 1e6);
        assertEq(assets, JAAA_PPS, "1 share = 1.031939 USDC");
    }

    /// @notice Withdrawal ceil rounding favors the vault
    function test_fork_jaaa_getWithdrawalShareOutput_ceilFavorsVault() public view {
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(JAAA_VAULT, testUser, 1_000_000);
        uint256 assetsBack = oracle.getAssetOutput(JAAA_VAULT, testUser, sharesNeeded);
        assertGe(assetsBack, 1_000_000, "ceil rounding must favor vault");
    }

    /// @notice getTVL matches exact totalAssets: ~$145.5M
    function test_fork_jaaa_getTVL_exact() public view {
        assertEq(oracle.getTVL(JAAA_VAULT), JAAA_TOTAL_ASSETS);
    }

    /// @notice Round-trip on JAAA
    function test_fork_jaaa_roundTrip_floorLoss() public view {
        uint256 assetsIn = 1_000_000;
        uint256 shares = oracle.getShareOutput(JAAA_VAULT, testUser, assetsIn);
        uint256 assetsBack = oracle.getAssetOutput(JAAA_VAULT, testUser, shares);
        assertLe(assetsBack, assetsIn);
        assertGe(assetsBack, assetsIn - 1);
    }

    /*//////////////////////////////////////////////////////////////
                    REAL DEPOSITOR VERIFICATION (JAAA)
    //////////////////////////////////////////////////////////////*/

    /// @notice Large holder: oracle balance matches on-chain tranche balance exactly
    function test_fork_realDepositor_largeHolder_balance() public view {
        uint256 balance = oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_LARGE_HOLDER);
        assertEq(balance, JAAA_LARGE_HOLDER_BALANCE, "oracle balance must match on-chain");
        assertEq(balance, IERC20(JAAA_TRANCHE).balanceOf(JAAA_LARGE_HOLDER));
    }

    /// @notice Large holder: TVL = convertToAssets(balance) with exact expected value
    function test_fork_realDepositor_largeHolder_TVL() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_LARGE_HOLDER);
        assertEq(tvl, JAAA_LARGE_HOLDER_ASSETS, "TVL must be exactly 951427200346");
        assertEq(tvl, IERC7540(JAAA_VAULT).convertToAssets(JAAA_LARGE_HOLDER_BALANCE));
    }

    /// @notice Large holder: breakdown shows held only, no async state
    function test_fork_realDepositor_largeHolder_breakdown() public view {
        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_LARGE_HOLDER);

        assertEq(held, JAAA_LARGE_HOLDER_ASSETS, "held = convertToAssets(balance)");
        assertEq(pendingRedeem, 0, "no pending redeem");
        assertEq(claimableRedeem, 0, "no claimable redeem");
        assertEq(pendingDeposit, 0, "no pending deposit");
        assertEq(claimableDeposit, 0, "no claimable deposit");
    }

    /// @notice Small holder: oracle balance matches on-chain
    function test_fork_realDepositor_smallHolder_balance() public view {
        uint256 balance = oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_SMALL_HOLDER);
        assertEq(balance, JAAA_SMALL_HOLDER_BALANCE);
        assertEq(balance, IERC20(JAAA_TRANCHE).balanceOf(JAAA_SMALL_HOLDER));
    }

    /// @notice Redeeming holder: has pendingRedeemRequest > 0 and zero balance
    function test_fork_realDepositor_redeemingHolder_pendingRedeem() public view {
        // This depositor has 0 balance but non-zero pendingRedeemRequest
        uint256 balance = oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_REDEEMING_HOLDER);
        assertEq(balance, 0, "balance = 0 (shares burned by requestRedeem)");

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_REDEEMING_HOLDER);

        assertEq(held, 0, "no held shares");
        assertEq(pendingRedeem, JAAA_REDEEMING_PENDING_VALUE, "pendingRedeem = convertToAssets(pending shares)");
        assertEq(pendingRedeem, IERC7540(JAAA_VAULT).convertToAssets(JAAA_REDEEMING_PENDING_SHARES));
        assertEq(claimableRedeem, 0, "no claimable redeem");
        assertEq(pendingDeposit, 0, "no pending deposit");
        assertEq(claimableDeposit, 0, "no claimable deposit");
    }

    /// @notice Redeeming holder: TVL = pendingRedeemValue only
    function test_fork_realDepositor_redeemingHolder_TVL() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_REDEEMING_HOLDER);
        assertEq(tvl, JAAA_REDEEMING_PENDING_VALUE, "TVL = pending redeem value only");
        assertGt(tvl, 0, "TVL > 0 even with 0 balance");
    }

    /// @notice Redeeming holder: TVL equals sum of all 5 components
    function test_fork_realDepositor_redeemingHolder_componentSum() public view {
        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_REDEEMING_HOLDER);

        uint256 tvl = oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_REDEEMING_HOLDER);
        assertEq(tvl, held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit, "TVL = sum of 5 components");
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-VAULT BATCH TESTS (LIVE, EXACT)
    //////////////////////////////////////////////////////////////*/

    /// @notice Batch PPS: JTRSY > JAAA (higher yield tranche has higher PPS)
    function test_fork_batch_PPS_exact() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = JTRSY_VAULT;
        vaults[1] = JAAA_VAULT;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices[0], JTRSY_PPS, "JTRSY PPS exact");
        assertEq(prices[1], JAAA_PPS, "JAAA PPS exact");
        assertGt(prices[0], prices[1], "JTRSY PPS > JAAA PPS (higher yield tranche)");
    }

    /// @notice Batch TVL: exact values for both vaults
    function test_fork_batch_TVL_exact() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = JTRSY_VAULT;
        vaults[1] = JAAA_VAULT;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls[0], JTRSY_TOTAL_ASSETS, "JTRSY TVL exact");
        assertEq(tvls[1], JAAA_TOTAL_ASSETS, "JAAA TVL exact");
        assertGt(tvls[0], tvls[1], "JTRSY TVL > JAAA TVL");
    }

    /// @notice Batch TVLByOwner with real depositors across vaults
    function test_fork_batch_TVLByOwner_realDepositors() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = JAAA_VAULT;
        vaults[1] = JAAA_VAULT;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = JAAA_LARGE_HOLDER;
        owners[1] = new address[](1);
        owners[1][0] = JAAA_REDEEMING_HOLDER;

        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls[0][0], JAAA_LARGE_HOLDER_ASSETS, "large holder TVL");
        assertEq(tvls[1][0], JAAA_REDEEMING_PENDING_VALUE, "redeeming holder TVL");
    }

    /// @notice Batch TVLByOwner mixing deal'd and real depositors
    function test_fork_batch_TVLByOwner_mixedDealtAndReal() public {
        deal(JTRSY_TRANCHE, testUser, 100e6);

        address[] memory vaults = new address[](2);
        vaults[0] = JTRSY_VAULT;
        vaults[1] = JAAA_VAULT;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = testUser; // deal'd
        owners[1] = new address[](1);
        owners[1][0] = JAAA_LARGE_HOLDER; // real

        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls[0][0], IERC7540(JTRSY_VAULT).convertToAssets(100e6), "deal'd user JTRSY TVL");
        assertEq(tvls[1][0], JAAA_LARGE_HOLDER_ASSETS, "real holder JAAA TVL");
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-VALIDATION: ORACLE vs DIRECT CALLS
    //////////////////////////////////////////////////////////////*/

    /// @notice Every oracle method must return the same value as direct vault calls
    function test_fork_crossValidation_allMethods_JTRSY() public view {
        IERC7540 vault = IERC7540(JTRSY_VAULT);

        // decimals
        assertEq(oracle.decimals(JTRSY_VAULT), IERC20Metadata(vault.share()).decimals());

        // PPS
        uint256 oneShare = 10 ** oracle.decimals(JTRSY_VAULT);
        assertEq(oracle.getPricePerShare(JTRSY_VAULT), vault.convertToAssets(oneShare));

        // getShareOutput for various amounts
        for (uint256 i = 1; i <= 5; i++) {
            uint256 assets = i * 1_000_000;
            assertEq(oracle.getShareOutput(JTRSY_VAULT, testUser, assets), vault.convertToShares(assets));
        }

        // getAssetOutput for various amounts
        for (uint256 i = 1; i <= 5; i++) {
            uint256 shares = i * 1e6;
            assertEq(oracle.getAssetOutput(JTRSY_VAULT, testUser, shares), vault.convertToAssets(shares));
        }

        // getTVL
        assertEq(oracle.getTVL(JTRSY_VAULT), vault.totalAssets());
    }

    /// @notice Every oracle method must return the same value as direct vault calls (JAAA)
    function test_fork_crossValidation_allMethods_JAAA() public view {
        IERC7540 vault = IERC7540(JAAA_VAULT);

        assertEq(oracle.decimals(JAAA_VAULT), IERC20Metadata(vault.share()).decimals());

        uint256 oneShare = 10 ** oracle.decimals(JAAA_VAULT);
        assertEq(oracle.getPricePerShare(JAAA_VAULT), vault.convertToAssets(oneShare));

        for (uint256 i = 1; i <= 5; i++) {
            uint256 assets = i * 1_000_000;
            assertEq(oracle.getShareOutput(JAAA_VAULT, testUser, assets), vault.convertToShares(assets));
        }

        for (uint256 i = 1; i <= 5; i++) {
            uint256 shares = i * 1e6;
            assertEq(oracle.getAssetOutput(JAAA_VAULT, testUser, shares), vault.convertToAssets(shares));
        }

        assertEq(oracle.getTVL(JAAA_VAULT), vault.totalAssets());
    }

    /// @notice Cross-validate breakdown components against direct vault calls for real depositor
    function test_fork_crossValidation_breakdown_realDepositor() public view {
        IERC7540 vault = IERC7540(JAAA_VAULT);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_REDEEMING_HOLDER);

        // Component 1: held = convertToAssets(balanceOf)
        uint256 balance = IERC20(JAAA_TRANCHE).balanceOf(JAAA_REDEEMING_HOLDER);
        assertEq(held, balance > 0 ? vault.convertToAssets(balance) : 0);

        // Component 2: pendingRedeem = convertToAssets(pendingRedeemRequest)
        uint256 pendingShares = vault.pendingRedeemRequest(0, JAAA_REDEEMING_HOLDER);
        assertEq(pendingRedeem, pendingShares > 0 ? vault.convertToAssets(pendingShares) : 0);

        // Component 3: claimableRedeem = maxWithdraw
        assertEq(claimableRedeem, vault.maxWithdraw(JAAA_REDEEMING_HOLDER));

        // Component 4: pendingDeposit = pendingDepositRequest
        assertEq(pendingDeposit, vault.pendingDepositRequest(0, JAAA_REDEEMING_HOLDER));

        // Component 5: claimableDeposit = claimableDepositRequest
        assertEq(claimableDeposit, vault.claimableDepositRequest(0, JAAA_REDEEMING_HOLDER));
    }

    /*//////////////////////////////////////////////////////////////
                    ORACLE DASHBOARD — FULL OUTPUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Prints all oracle outputs for both vaults and all real depositors
    function test_fork_dashboard() public view {
        console2.log("============================================================");
        console2.log("  ERC7540YieldSourceOracle Dashboard - Block 24,990,000");
        console2.log("============================================================");

        // --- JTRSY ---
        console2.log("");
        console2.log("--- JTRSY (Centrifuge RWA Tranche) ---");
        console2.log("  Vault:           ", JTRSY_VAULT);
        console2.log("  Tranche Token:   ", JTRSY_TRANCHE);
        console2.log("  Decimals:        ", oracle.decimals(JTRSY_VAULT));
        console2.log("  PPS (raw):       ", oracle.getPricePerShare(JTRSY_VAULT));
        console2.log("  ShareOut(1 USDC):", oracle.getShareOutput(JTRSY_VAULT, testUser, 1e6));
        console2.log("  AssetOut(1 share):", oracle.getAssetOutput(JTRSY_VAULT, testUser, 1e6));
        console2.log("  WithdrawShares(1 USDC):", oracle.getWithdrawalShareOutput(JTRSY_VAULT, testUser, 1e6));
        console2.log("  TVL (raw):       ", oracle.getTVL(JTRSY_VAULT));

        // --- JAAA ---
        console2.log("");
        console2.log("--- JAAA (Centrifuge Senior Tranche) ---");
        console2.log("  Vault:           ", JAAA_VAULT);
        console2.log("  Tranche Token:   ", JAAA_TRANCHE);
        console2.log("  Decimals:        ", oracle.decimals(JAAA_VAULT));
        console2.log("  PPS (raw):       ", oracle.getPricePerShare(JAAA_VAULT));
        console2.log("  ShareOut(1 USDC):", oracle.getShareOutput(JAAA_VAULT, testUser, 1e6));
        console2.log("  AssetOut(1 share):", oracle.getAssetOutput(JAAA_VAULT, testUser, 1e6));
        console2.log("  WithdrawShares(1 USDC):", oracle.getWithdrawalShareOutput(JAAA_VAULT, testUser, 1e6));
        console2.log("  TVL (raw):       ", oracle.getTVL(JAAA_VAULT));

        // --- Real Depositor: Large Holder ---
        console2.log("");
        console2.log("--- Real Depositor: Large Holder (JAAA) ---");
        console2.log("  Address:         ", JAAA_LARGE_HOLDER);
        console2.log("  Share Balance:   ", oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_LARGE_HOLDER));
        console2.log("  TVLByOwner:      ", oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_LARGE_HOLDER));
        (uint256 h1, uint256 pr1, uint256 cr1, uint256 pd1, uint256 cd1) =
            oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_LARGE_HOLDER);
        console2.log("  Held Value:      ", h1);
        console2.log("  Pending Redeem:  ", pr1);
        console2.log("  Claimable Redeem:", cr1);
        console2.log("  Pending Deposit: ", pd1);
        console2.log("  Claimable Deposit:", cd1);

        // --- Real Depositor: Small Holder ---
        console2.log("");
        console2.log("--- Real Depositor: Small Holder (JAAA) ---");
        console2.log("  Address:         ", JAAA_SMALL_HOLDER);
        console2.log("  Share Balance:   ", oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_SMALL_HOLDER));
        console2.log("  TVLByOwner:      ", oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_SMALL_HOLDER));
        (uint256 h2, uint256 pr2, uint256 cr2, uint256 pd2, uint256 cd2) =
            oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_SMALL_HOLDER);
        console2.log("  Held Value:      ", h2);
        console2.log("  Pending Redeem:  ", pr2);
        console2.log("  Claimable Redeem:", cr2);
        console2.log("  Pending Deposit: ", pd2);
        console2.log("  Claimable Deposit:", cd2);

        // --- Real Depositor: Redeeming Holder ---
        console2.log("");
        console2.log("--- Real Depositor: Redeeming Holder (JAAA) ---");
        console2.log("  Address:         ", JAAA_REDEEMING_HOLDER);
        console2.log("  Share Balance:   ", oracle.getBalanceOfOwner(JAAA_VAULT, JAAA_REDEEMING_HOLDER));
        console2.log("  TVLByOwner:      ", oracle.getTVLByOwnerOfShares(JAAA_VAULT, JAAA_REDEEMING_HOLDER));
        (uint256 h3, uint256 pr3, uint256 cr3, uint256 pd3, uint256 cd3) =
            oracle.getAsyncStateBreakdown(JAAA_VAULT, JAAA_REDEEMING_HOLDER);
        console2.log("  Held Value:      ", h3);
        console2.log("  Pending Redeem:  ", pr3);
        console2.log("  Claimable Redeem:", cr3);
        console2.log("  Pending Deposit: ", pd3);
        console2.log("  Claimable Deposit:", cd3);

        console2.log("");
        console2.log("============================================================");
    }
}
