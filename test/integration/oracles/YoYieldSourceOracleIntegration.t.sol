// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { YoYieldSourceOracle } from "../../../src/accounting/oracles/YoYieldSourceOracle.sol";
import { IYoVault } from "../../../src/vendor/yo/IYoVault.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title YoYieldSourceOracleIntegration
/// @notice Integration tests for YoYieldSourceOracle against real Yo Vaults on Base
/// @dev Forks Base mainnet to test against deployed yoETH, yoBTC, yoUSD vaults
contract YoYieldSourceOracleIntegration is Test, Constants {
    YoYieldSourceOracle public oracle;
    SuperLedgerConfiguration public ledgerConfig;

    address public yoEthVault;
    address public yoBtcVault;
    address public yoUsdVault;

    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY));

        // Deploy oracle infrastructure
        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new YoYieldSourceOracle(address(ledgerConfig));

        // Set vault addresses
        yoEthVault = CHAIN_8453_YO_ETH_VAULT;
        yoBtcVault = CHAIN_8453_YO_BTC_VAULT;
        yoUsdVault = CHAIN_8453_YO_USD_VAULT;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify yoETH vault interface matches IYoVault
    function test_yoEthVault_interfaceCompatibility() public view {
        IYoVault vault = IYoVault(yoEthVault);

        // Test all interface methods don't revert
        uint8 decimals = vault.decimals();
        console2.log("yoETH decimals:", decimals);
        assertGt(decimals, 0, "Decimals should be > 0");

        uint256 totalAssets = vault.totalAssets();
        console2.log("yoETH totalAssets:", totalAssets);

        // Test convertToAssets with 1 share
        uint256 oneShare = 10 ** decimals;
        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        console2.log("yoETH assets per share:", assetsPerShare);
        assertGt(assetsPerShare, 0, "Assets per share should be > 0");

        // Test convertToShares
        uint256 sharesForOneAsset = vault.convertToShares(oneShare);
        console2.log("yoETH shares for 1 asset unit:", sharesForOneAsset);

        // Test previewDeposit
        uint256 previewShares = vault.previewDeposit(oneShare);
        console2.log("yoETH preview deposit shares:", previewShares);

        // Test pendingRedeemRequest (critical for async redemption)
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(address(this));
        console2.log("yoETH pending assets (test addr):", pendingAssets);
        console2.log("yoETH pending shares (test addr):", pendingShares);
        // Should be 0 for test address with no pending requests
        assertEq(pendingAssets, 0, "No pending assets expected for test address");
        assertEq(pendingShares, 0, "No pending shares expected for test address");
    }

    /// @notice Verify yoBTC vault interface matches IYoVault
    function test_yoBtcVault_interfaceCompatibility() public view {
        IYoVault vault = IYoVault(yoBtcVault);

        uint8 decimals = vault.decimals();
        console2.log("yoBTC decimals:", decimals);
        assertGt(decimals, 0, "Decimals should be > 0");

        uint256 totalAssets = vault.totalAssets();
        console2.log("yoBTC totalAssets:", totalAssets);

        uint256 oneShare = 10 ** decimals;
        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        console2.log("yoBTC assets per share:", assetsPerShare);

        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(address(this));
        assertEq(pendingAssets, 0, "No pending assets expected");
        assertEq(pendingShares, 0, "No pending shares expected");
    }

    /// @notice Verify yoUSD vault interface matches IYoVault
    function test_yoUsdVault_interfaceCompatibility() public view {
        IYoVault vault = IYoVault(yoUsdVault);

        uint8 decimals = vault.decimals();
        console2.log("yoUSD decimals:", decimals);
        assertGt(decimals, 0, "Decimals should be > 0");

        uint256 totalAssets = vault.totalAssets();
        console2.log("yoUSD totalAssets:", totalAssets);

        uint256 oneShare = 10 ** decimals;
        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        console2.log("yoUSD assets per share:", assetsPerShare);

        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(address(this));
        assertEq(pendingAssets, 0, "No pending assets expected");
        assertEq(pendingShares, 0, "No pending shares expected");
    }

    /*//////////////////////////////////////////////////////////////
                        ORACLE METHOD TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test oracle decimals() against yoETH
    function test_oracle_decimals_yoEth() public view {
        uint8 oracleDecimals = oracle.decimals(yoEthVault);
        uint8 vaultDecimals = IYoVault(yoEthVault).decimals();

        assertEq(oracleDecimals, vaultDecimals, "Oracle decimals should match vault");
        console2.log("yoETH decimals verified:", oracleDecimals);
    }

    /// @notice Test oracle getPricePerShare() against yoETH
    function test_oracle_getPricePerShare_yoEth() public view {
        uint256 pps = oracle.getPricePerShare(yoEthVault);
        console2.log("yoETH PPS via oracle:", pps);

        // Verify against direct vault call
        IYoVault vault = IYoVault(yoEthVault);
        uint256 oneShare = 10 ** vault.decimals();
        uint256 directPps = vault.convertToAssets(oneShare);

        assertEq(pps, directPps, "Oracle PPS should match direct vault call");
    }

    /// @notice Test oracle getShareOutput() against yoETH
    function test_oracle_getShareOutput_yoEth() public view {
        uint256 assetsIn = 1 ether;
        uint256 sharesOut = oracle.getShareOutput(yoEthVault, address(this), assetsIn);
        console2.log("yoETH shares for 1 ETH deposit:", sharesOut);

        // Verify against direct vault call
        uint256 directShares = IYoVault(yoEthVault).previewDeposit(assetsIn);
        assertEq(sharesOut, directShares, "Oracle share output should match vault previewDeposit");
    }

    /// @notice Test oracle getAssetOutput() against yoETH
    function test_oracle_getAssetOutput_yoEth() public view {
        IYoVault vault = IYoVault(yoEthVault);
        uint256 oneShare = 10 ** vault.decimals();

        uint256 assetsOut = oracle.getAssetOutput(yoEthVault, address(this), oneShare);
        console2.log("yoETH assets for 1 share redeem:", assetsOut);

        // Verify against direct vault call
        uint256 directAssets = vault.convertToAssets(oneShare);
        assertEq(assetsOut, directAssets, "Oracle asset output should match vault convertToAssets");
    }

    /// @notice Test oracle getTVL() against yoETH
    function test_oracle_getTVL_yoEth() public view {
        uint256 tvl = oracle.getTVL(yoEthVault);
        console2.log("yoETH TVL via oracle:", tvl);

        // Verify against direct vault call
        uint256 directTvl = IYoVault(yoEthVault).totalAssets();
        assertEq(tvl, directTvl, "Oracle TVL should match vault totalAssets");
    }

    /// @notice Test oracle getBalanceOfOwner() for address with shares
    function test_oracle_getBalanceOfOwner_withShares() public view {
        // Find an address that has yoETH shares by checking the vault itself
        // The vault contract should have delegated shares or we can check totalSupply > 0
        IYoVault vault = IYoVault(yoEthVault);

        // Test with vault address itself (may have some balance for operational purposes)
        uint256 vaultSelfBalance = oracle.getBalanceOfOwner(yoEthVault, yoEthVault);
        console2.log("yoETH vault self-balance:", vaultSelfBalance);

        // Verify matches direct call
        uint256 directBalance = vault.balanceOf(yoEthVault);
        assertEq(vaultSelfBalance, directBalance, "Oracle balance should match vault balanceOf");
    }

    /// @notice Test oracle getTVLByOwnerOfShares() combines held + pending
    function test_oracle_getTVLByOwnerOfShares_yoEth() public view {
        // For test address with no shares and no pending, TVL should be 0
        uint256 tvlByOwner = oracle.getTVLByOwnerOfShares(yoEthVault, address(this));
        console2.log("yoETH TVL for test address:", tvlByOwner);

        // Should be 0 for test address
        assertEq(tvlByOwner, 0, "TVL should be 0 for address with no position");
    }

    /*//////////////////////////////////////////////////////////////
                    REAL HOLDER TESTS (EXPLORATORY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Find and test with a real yoETH holder
    /// @dev This test explores the vault to find real holders
    function test_oracle_withRealHolder_yoEth() public view {
        IYoVault vault = IYoVault(yoEthVault);

        // Check if vault has any total supply
        // We'll test with the YO multisig which likely has shares
        address yoMultisig = 0x93e5260Ac975B475aF8BF818c14DEEE7fEfd5927;

        uint256 multisigShares = vault.balanceOf(yoMultisig);
        console2.log("YO Multisig yoETH shares:", multisigShares);

        if (multisigShares > 0) {
            // Test oracle methods with real holder
            uint256 balance = oracle.getBalanceOfOwner(yoEthVault, yoMultisig);
            assertEq(balance, multisigShares, "Oracle balance should match");

            uint256 tvlByOwner = oracle.getTVLByOwnerOfShares(yoEthVault, yoMultisig);
            console2.log("YO Multisig TVL in yoETH:", tvlByOwner);

            // TVL should be >= held value (held + pending)
            uint256 heldValue = vault.convertToAssets(multisigShares);
            (uint256 pendingAssets,) = vault.pendingRedeemRequest(yoMultisig);

            assertEq(tvlByOwner, heldValue + pendingAssets, "TVL should equal held + pending");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    PENDING REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that oracle correctly includes pending redemptions in TVL
    /// @dev This is the KEY test for async redemption support
    function test_oracle_pendingRedemptionIncludedInTVL() public view {
        IYoVault vault = IYoVault(yoEthVault);

        // Check multiple known addresses for pending redemptions
        address[] memory addressesToCheck = new address[](3);
        addressesToCheck[0] = 0x93e5260Ac975B475aF8BF818c14DEEE7fEfd5927; // YO Multisig
        addressesToCheck[1] = yoEthVault; // Vault itself
        addressesToCheck[2] = address(0x1234567890123456789012345678901234567890); // Random

        for (uint256 i = 0; i < addressesToCheck.length; i++) {
            address holder = addressesToCheck[i];

            uint256 heldShares = vault.balanceOf(holder);
            uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;
            (uint256 pendingAssets,) = vault.pendingRedeemRequest(holder);

            uint256 expectedTvl = heldValue + pendingAssets;
            uint256 oracleTvl = oracle.getTVLByOwnerOfShares(yoEthVault, holder);

            assertEq(oracleTvl, expectedTvl, "Oracle TVL should equal held + pending");

            if (pendingAssets > 0) {
                console2.log("Found holder with pending redemption:");
                console2.log("  Address:", holder);
                console2.log("  Held value:", heldValue);
                console2.log("  Pending assets:", pendingAssets);
                console2.log("  Total TVL:", oracleTvl);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL SHARE CALCULATION TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getWithdrawalShareOutput uses ceil rounding
    function test_oracle_getWithdrawalShareOutput_ceilRounding() public view {
        IYoVault vault = IYoVault(yoEthVault);
        uint256 decimals = vault.decimals();
        uint256 oneShare = 10 ** decimals;

        // Get assets per share
        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        console2.log("Assets per share:", assetsPerShare);

        // Request withdrawal of exactly 1 asset unit
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(yoEthVault, address(this), 1);
        console2.log("Shares needed for 1 wei withdrawal:", sharesNeeded);

        // Verify ceil rounding - redeeming sharesNeeded should give >= 1 wei
        if (sharesNeeded > 0) {
            uint256 assetsReceived = vault.convertToAssets(sharesNeeded);
            assertGe(assetsReceived, 1, "Ceil rounding should ensure we get at least requested amount");
        }

        // Test with larger amount
        uint256 withdrawAmount = 1 ether;
        uint256 sharesForEther = oracle.getWithdrawalShareOutput(yoEthVault, address(this), withdrawAmount);
        console2.log("Shares needed for 1 ETH withdrawal:", sharesForEther);

        uint256 assetsFromShares = vault.convertToAssets(sharesForEther);
        assertGe(assetsFromShares, withdrawAmount, "Should receive at least requested withdrawal amount");
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-VAULT CONSISTENCY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify oracle works consistently across all Yo vaults
    function test_oracle_multiVaultConsistency() public view {
        address[] memory vaults = new address[](3);
        vaults[0] = yoEthVault;
        vaults[1] = yoBtcVault;
        vaults[2] = yoUsdVault;

        string[] memory names = new string[](3);
        names[0] = "yoETH";
        names[1] = "yoBTC";
        names[2] = "yoUSD";

        for (uint256 i = 0; i < vaults.length; i++) {
            console2.log("--- Testing", names[i], "---");

            // All oracle methods should work without reverting
            uint8 decimals = oracle.decimals(vaults[i]);
            console2.log("  Decimals:", decimals);

            uint256 pps = oracle.getPricePerShare(vaults[i]);
            console2.log("  PPS:", pps);

            uint256 tvl = oracle.getTVL(vaults[i]);
            console2.log("  TVL:", tvl);

            // Verify decimals are reasonable (6-18)
            assertGe(decimals, 6, "Decimals should be >= 6");
            assertLe(decimals, 18, "Decimals should be <= 18");

            // PPS should be > 0 for active vaults
            assertGt(pps, 0, "PPS should be > 0");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT AND TVL VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test TVL tracking after depositing into yoETH from a fresh address
    /// @dev This is the KEY integration test - deposit real assets and verify oracle TVL
    function test_depositAndVerifyTVL_yoEth() public {
        // Create a fresh user address
        address user = makeAddr("freshDepositor");

        // Get the underlying asset (WETH for yoETH)
        IERC4626 vault4626 = IERC4626(yoEthVault);
        address underlyingAsset = vault4626.asset();
        console2.log("yoETH underlying asset:", underlyingAsset);

        // Verify it's WETH on Base
        assertEq(underlyingAsset, CHAIN_8453_WETH, "Underlying should be WETH");

        // Amount to deposit
        uint256 depositAmount = 1 ether;

        // Deal WETH to user
        deal(underlyingAsset, user, depositAmount);
        assertEq(IERC20(underlyingAsset).balanceOf(user), depositAmount, "User should have WETH");

        // Check TVL before deposit - should be 0 for fresh address
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(yoEthVault, user);
        console2.log("User TVL before deposit:", tvlBefore);
        assertEq(tvlBefore, 0, "TVL should be 0 before deposit");

        // Preview expected shares
        uint256 expectedShares = vault4626.previewDeposit(depositAmount);
        console2.log("Expected shares from deposit:", expectedShares);

        // Deposit as user
        vm.startPrank(user);
        IERC20(underlyingAsset).approve(yoEthVault, depositAmount);
        uint256 sharesReceived = vault4626.deposit(depositAmount, user);
        vm.stopPrank();

        console2.log("Shares received:", sharesReceived);
        assertEq(sharesReceived, expectedShares, "Shares received should match preview");

        // Verify share balance via oracle
        uint256 shareBalance = oracle.getBalanceOfOwner(yoEthVault, user);
        console2.log("Share balance via oracle:", shareBalance);
        assertEq(shareBalance, sharesReceived, "Oracle should report correct share balance");

        // Verify TVL after deposit
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(yoEthVault, user);
        console2.log("User TVL after deposit:", tvlAfter);

        // TVL should be approximately equal to deposit amount (may differ slightly due to PPS)
        // Using 1% tolerance for any conversion rounding
        uint256 tolerance = depositAmount / 100;
        assertApproxEqAbs(tvlAfter, depositAmount, tolerance, "TVL should be ~deposit amount");

        // Verify TVL matches: convertToAssets(shares) + pendingAssets
        IYoVault vault = IYoVault(yoEthVault);
        uint256 heldValue = vault.convertToAssets(shareBalance);
        (uint256 pendingAssets,) = vault.pendingRedeemRequest(user);
        uint256 expectedTvl = heldValue + pendingAssets;

        assertEq(tvlAfter, expectedTvl, "TVL should equal held + pending");
        console2.log("Held value:", heldValue);
        console2.log("Pending assets:", pendingAssets);
    }

    /// @notice Test TVL tracking after depositing into yoUSD from a fresh address
    function test_depositAndVerifyTVL_yoUsd() public {
        address user = makeAddr("usdDepositor");

        IERC4626 vault4626 = IERC4626(yoUsdVault);
        address underlyingAsset = vault4626.asset();
        console2.log("yoUSD underlying asset:", underlyingAsset);

        // yoUSD should use USDC
        assertEq(underlyingAsset, CHAIN_8453_USDC, "Underlying should be USDC");

        // Deposit 1000 USDC (6 decimals)
        uint256 depositAmount = 1000 * 1e6;

        // Deal USDC to user
        deal(underlyingAsset, user, depositAmount);

        // Check TVL before
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(yoUsdVault, user);
        assertEq(tvlBefore, 0, "TVL should be 0 before deposit");

        // Deposit
        vm.startPrank(user);
        IERC20(underlyingAsset).approve(yoUsdVault, depositAmount);
        uint256 sharesReceived = vault4626.deposit(depositAmount, user);
        vm.stopPrank();

        console2.log("yoUSD shares received:", sharesReceived);

        // Verify TVL
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(yoUsdVault, user);
        console2.log("yoUSD TVL after deposit:", tvlAfter);

        // Should be ~1000 USDC worth
        uint256 tolerance = depositAmount / 100; // 1% tolerance
        assertApproxEqAbs(tvlAfter, depositAmount, tolerance, "TVL should be ~deposit amount");
    }

    /// @notice Test TVL tracking with immediate redeem (vault has liquidity)
    function test_depositAndImmediateRedeem_yoUsd() public {
        address user = makeAddr("redeemUser");

        // Deposit 10,000 USDC
        uint256 shares = _depositToYoUsd(user, 10_000 * 1e6);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(yoUsdVault, user);
        console2.log("Shares received:", shares);
        console2.log("TVL after deposit:", tvlBefore);

        // Request redeem half
        vm.prank(user);
        IYoVault(yoUsdVault).requestRedeem(shares / 2, user, user);

        // Check state
        IYoVault vault = IYoVault(yoUsdVault);
        uint256 remaining = vault.balanceOf(user);
        (uint256 pending,) = vault.pendingRedeemRequest(user);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(yoUsdVault, user);

        console2.log("Remaining shares:", remaining);
        console2.log("Pending assets:", pending);
        console2.log("TVL after redeem:", tvlAfter);

        // Verify TVL formula: held + pending
        uint256 heldValue = vault.convertToAssets(remaining);
        assertEq(tvlAfter, heldValue + pending, "TVL = held + pending");

        // When immediate: pending=0, TVL=half
        // When pending: TVL stays same
        if (pending == 0) {
            console2.log("IMMEDIATE redemption - vault had liquidity");
        } else {
            console2.log("PENDING redemption - TVL should be stable");
            assertApproxEqAbs(tvlAfter, tvlBefore, tvlBefore / 100, "TVL stable");
        }
    }

    /// @notice Test TVL with pending redemption by draining vault liquidity
    /// @dev Drains USDC from vault to force pending state
    function test_depositAndPendingRedeem_drainedVault() public {
        address user = makeAddr("pendingUser");
        IYoVault vault = IYoVault(yoUsdVault);
        IERC4626 vault4626 = IERC4626(yoUsdVault);
        address usdc = vault4626.asset();

        // Deposit
        uint256 shares = _depositToYoUsd(user, 10_000 * 1e6);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(yoUsdVault, user);
        console2.log("TVL after deposit:", tvlBefore);

        // Drain vault's USDC to force pending redemption
        uint256 vaultUsdc = IERC20(usdc).balanceOf(yoUsdVault);
        console2.log("Vault USDC before drain:", vaultUsdc);

        // Set vault's USDC balance to 0 (simulating no liquidity)
        deal(usdc, yoUsdVault, 0);
        console2.log("Vault USDC after drain:", IERC20(usdc).balanceOf(yoUsdVault));

        // Now request redeem - should be pending since no liquidity
        vm.prank(user);
        uint256 assetsRequested = vault.requestRedeem(shares / 2, user, user);
        console2.log("Assets requested:", assetsRequested);

        // Check pending state
        (uint256 pending,) = vault.pendingRedeemRequest(user);
        uint256 remaining = vault.balanceOf(user);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(yoUsdVault, user);

        console2.log("=== After Redeem Request (Drained Vault) ===");
        console2.log("Remaining shares:", remaining);
        console2.log("Pending assets:", pending);
        console2.log("TVL after redeem:", tvlAfter);

        // KEY: TVL = held + pending
        uint256 heldValue = vault.convertToAssets(remaining);
        assertEq(tvlAfter, heldValue + pending, "TVL = held + pending");

        // If pending > 0, TVL should be stable (PPS stability)
        if (pending > 0) {
            console2.log("SUCCESS: Forced pending redemption");
            assertApproxEqAbs(tvlAfter, tvlBefore, tvlBefore / 100, "TVL stable with pending");
        }
    }

    /// @notice Helper to deposit USDC to yoUSD vault
    function _depositToYoUsd(address user, uint256 amount) internal returns (uint256 shares) {
        IERC4626 vault4626 = IERC4626(yoUsdVault);
        address usdc = vault4626.asset();

        deal(usdc, user, amount);

        vm.startPrank(user);
        IERC20(usdc).approve(yoUsdVault, amount);
        shares = vault4626.deposit(amount, user);
        vm.stopPrank();
    }

    /// @notice Test multiple deposits accumulate TVL correctly
    function test_multipleDeposits_accumulateTVL() public {
        address user = makeAddr("multiDepositor");

        IERC4626 vault4626 = IERC4626(yoEthVault);
        address weth = vault4626.asset();

        // First deposit: 1 ETH
        uint256 deposit1 = 1 ether;
        deal(weth, user, deposit1);

        vm.startPrank(user);
        IERC20(weth).approve(yoEthVault, deposit1);
        vault4626.deposit(deposit1, user);
        vm.stopPrank();

        uint256 tvlAfterFirst = oracle.getTVLByOwnerOfShares(yoEthVault, user);
        console2.log("TVL after first deposit:", tvlAfterFirst);

        // Second deposit: 2 ETH
        uint256 deposit2 = 2 ether;
        deal(weth, user, deposit2);

        vm.startPrank(user);
        IERC20(weth).approve(yoEthVault, deposit2);
        vault4626.deposit(deposit2, user);
        vm.stopPrank();

        uint256 tvlAfterSecond = oracle.getTVLByOwnerOfShares(yoEthVault, user);
        console2.log("TVL after second deposit:", tvlAfterSecond);

        // TVL should be approximately 3 ETH total
        uint256 totalDeposited = deposit1 + deposit2;
        uint256 tolerance = totalDeposited / 100;
        assertApproxEqAbs(tvlAfterSecond, totalDeposited, tolerance, "TVL should be ~total deposited");

        // Second TVL should be greater than first
        assertGt(tvlAfterSecond, tvlAfterFirst, "TVL should increase after second deposit");
    }

    /// @notice Test TVL for multiple users are independent
    function test_multipleUsers_independentTVL() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        IERC4626 vault4626 = IERC4626(yoEthVault);
        address weth = vault4626.asset();

        // User1 deposits 1 ETH
        deal(weth, user1, 1 ether);
        vm.startPrank(user1);
        IERC20(weth).approve(yoEthVault, 1 ether);
        vault4626.deposit(1 ether, user1);
        vm.stopPrank();

        // User2 deposits 5 ETH
        deal(weth, user2, 5 ether);
        vm.startPrank(user2);
        IERC20(weth).approve(yoEthVault, 5 ether);
        vault4626.deposit(5 ether, user2);
        vm.stopPrank();

        // Check TVLs are independent
        uint256 tvl1 = oracle.getTVLByOwnerOfShares(yoEthVault, user1);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(yoEthVault, user2);

        console2.log("User1 TVL:", tvl1);
        console2.log("User2 TVL:", tvl2);

        // User2 should have ~5x the TVL of User1
        assertApproxEqAbs(tvl1, 1 ether, 1 ether / 100, "User1 TVL should be ~1 ETH");
        assertApproxEqAbs(tvl2, 5 ether, 5 ether / 100, "User2 TVL should be ~5 ETH");
        assertGt(tvl2, tvl1, "User2 should have higher TVL");
    }

    /// @notice Test share balance and TVL relationship
    function test_shareBalanceAndTVL_relationship() public {
        address user = makeAddr("relationshipTester");

        IERC4626 vault4626 = IERC4626(yoEthVault);
        IYoVault vault = IYoVault(yoEthVault);
        address weth = vault4626.asset();

        uint256 depositAmount = 10 ether;
        deal(weth, user, depositAmount);

        vm.startPrank(user);
        IERC20(weth).approve(yoEthVault, depositAmount);
        vault4626.deposit(depositAmount, user);
        vm.stopPrank();

        // Get values from oracle
        uint256 shareBalance = oracle.getBalanceOfOwner(yoEthVault, user);
        uint256 tvlByOwner = oracle.getTVLByOwnerOfShares(yoEthVault, user);
        uint256 pps = oracle.getPricePerShare(yoEthVault);

        console2.log("Share balance:", shareBalance);
        console2.log("TVL by owner:", tvlByOwner);
        console2.log("PPS:", pps);

        // Verify relationship: TVL = convertToAssets(shares) + pending
        uint256 heldValue = vault.convertToAssets(shareBalance);
        (uint256 pendingAssets,) = vault.pendingRedeemRequest(user);

        assertEq(tvlByOwner, heldValue + pendingAssets, "TVL = held + pending");

        // For new deposits, pending should be 0
        assertEq(pendingAssets, 0, "No pending for fresh deposit");
        assertEq(tvlByOwner, heldValue, "TVL equals held value when no pending");
    }
}
