// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FirelightYieldSourceOracle } from "../../../src/accounting/oracles/FirelightYieldSourceOracle.sol";
import { IFirelightVault } from "../../../src/vendor/vaults/firelight/IFirelightVault.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

/// @title FirelightOracleFork
/// @notice Integration tests for FirelightYieldSourceOracle against real Firelight stXRP vault on Flare.
///         Compares oracle-reported values vs vault-computed values across all lifecycle scenarios:
///         deposit, redeem (partial/full/multiple), and cross-validates PPS at every stage.
contract FirelightOracleFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public constant VAULT = 0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3;
    address public constant FXRP = 0xAd552A648C74D49E10027AB8a618A3ad4901c5bE;
    address public constant TOP_HOLDER = 0x80743e896Df841900803a46F6d8451e0F9EF6F4A;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    FirelightYieldSourceOracle public oracle;
    IFirelightVault public vault;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("FLARE_RPC_URL"));
        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        oracle = new FirelightYieldSourceOracle(address(ledgerConfig));
        vault = IFirelightVault(VAULT);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 1: ORACLE PPS vs VAULT PPS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS must always match: oracle delegates to convertToAssets(10^decimals)
    function test_ppsMatch_initialState() public view {
        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch in initial state");
        assertGt(oraclePPS, 1e6, "PPS should be > 1.0 (yield accruing)");
        console2.log("[initial] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /// @notice PPS should NOT change after a redeem (redeem doesn't change exchange rate)
    function test_ppsMatch_afterRedeem() public {
        uint256 ppsBefore = oracle.getPricePerShare(VAULT);

        vm.prank(TOP_HOLDER);
        vault.redeem(1e6, TOP_HOLDER, TOP_HOLDER);

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch after redeem");
        // PPS may change by 1 wei due to totalSupply change rounding, but should be approximately equal
        assertApproxEqAbs(oraclePPS, ppsBefore, 1, "PPS should not change after small redeem");
        console2.log("[post-redeem] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /// @notice PPS still matches after a large redeem (50% of holder)
    function test_ppsMatch_afterLargeRedeem() public {
        uint256 holderBalance = vault.balanceOf(TOP_HOLDER);
        uint256 shares = holderBalance / 2;

        vm.prank(TOP_HOLDER);
        vault.redeem(shares, TOP_HOLDER, TOP_HOLDER);

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch after large redeem");
        console2.log("[post-large-redeem] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /// @notice PPS matches after full redeem (all shares burned)
    function test_ppsMatch_afterFullRedeem() public {
        uint256 holderBalance = vault.balanceOf(TOP_HOLDER);

        vm.prank(TOP_HOLDER);
        vault.redeem(holderBalance, TOP_HOLDER, TOP_HOLDER);

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch after full redeem");
        console2.log("[post-full-redeem] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /// @notice PPS matches after deposit
    function test_ppsMatch_afterDeposit() public {
        uint256 ppsBefore = oracle.getPricePerShare(VAULT);

        // Fund a fresh user and deposit
        address depositor = address(0xBEEF);
        uint256 depositAmount = vault.convertToShares(1e6) > 0 ? 1e6 : 0; // 1 FXRP
        vm.assume(depositAmount > 0);

        deal(FXRP, depositor, depositAmount);
        vm.startPrank(depositor);
        IERC20(FXRP).approve(VAULT, depositAmount);

        // Vault may have a deposit cap — try depositing within maxDeposit
        uint256 maxDep = _maxDeposit(depositor);
        uint256 toDeposit = depositAmount > maxDep ? maxDep : depositAmount;
        if (toDeposit == 0) {
            vm.stopPrank();
            console2.log("[deposit] Skipped: maxDeposit is 0");
            return;
        }

        (bool ok,) = VAULT.call(abi.encodeWithSignature("deposit(uint256,address)", toDeposit, depositor));
        vm.stopPrank();

        if (!ok) {
            console2.log("[deposit] Skipped: deposit reverted (cap reached)");
            return;
        }

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch after deposit");
        // PPS should not change from a proportional deposit
        assertApproxEqAbs(oraclePPS, ppsBefore, 1, "PPS should not change after deposit");
        console2.log("[post-deposit] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /// @notice PPS matches after multiple redeems
    function test_ppsMatch_afterMultipleRedeems() public {
        vm.startPrank(TOP_HOLDER);
        vault.redeem(1e6, TOP_HOLDER, TOP_HOLDER);
        vault.redeem(2e6, TOP_HOLDER, TOP_HOLDER);
        vault.redeem(5e6, TOP_HOLDER, TOP_HOLDER);
        vm.stopPrank();

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertEq(oraclePPS, vaultPPS, "PPS mismatch after multiple redeems");
        console2.log("[post-multi-redeem] Oracle PPS:", oraclePPS, "Vault PPS:", vaultPPS);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 2: CONVERSION CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice oracle.getShareOutput must match vault.convertToShares at all amounts
    function test_shareConversion_matchesVault() public view {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 0;
        amounts[1] = 1; // 1 wei
        amounts[2] = 1e6; // 1 FXRP
        amounts[3] = 1_000_000e6; // 1M FXRP
        amounts[4] = type(uint128).max;

        for (uint256 i; i < amounts.length; i++) {
            uint256 oracleShares = oracle.getShareOutput(VAULT, address(0), amounts[i]);
            uint256 vaultShares = vault.convertToShares(amounts[i]);
            assertEq(oracleShares, vaultShares, string.concat("getShareOutput mismatch at index ", vm.toString(i)));
        }
    }

    /// @notice oracle.getAssetOutput must match vault.convertToAssets at all amounts
    function test_assetConversion_matchesVault() public view {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 0;
        amounts[1] = 1; // 1 wei share
        amounts[2] = 1e6; // 1 stXRP
        amounts[3] = 1_000_000e6; // 1M stXRP
        amounts[4] = type(uint128).max;

        for (uint256 i; i < amounts.length; i++) {
            uint256 oracleAssets = oracle.getAssetOutput(VAULT, address(0), amounts[i]);
            uint256 vaultAssets = vault.convertToAssets(amounts[i]);
            assertEq(oracleAssets, vaultAssets, string.concat("getAssetOutput mismatch at index ", vm.toString(i)));
        }
    }

    /// @notice getWithdrawalShareOutput (ceil) >= getShareOutput (floor) and covers the input
    function test_withdrawalShareOutput_ceilProperty() public view {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1;
        amounts[1] = 1e6;
        amounts[2] = 1_000_000e6;
        amounts[3] = 777_777e6;

        for (uint256 i; i < amounts.length; i++) {
            uint256 ceil = oracle.getWithdrawalShareOutput(VAULT, address(0), amounts[i]);
            uint256 floor = oracle.getShareOutput(VAULT, address(0), amounts[i]);
            assertGe(ceil, floor, "ceil < floor");

            // Ceil shares should be enough to cover the requested assets
            uint256 assetsFromCeil = oracle.getAssetOutput(VAULT, address(0), ceil);
            assertGe(assetsFromCeil, amounts[i], "ceil shares don't cover assets");
        }
    }

    /// @notice Round-trip: assets → shares → assets should lose at most 1 wei (floor rounding)
    function test_roundTrip_assetShareAsset() public view {
        uint256 assetsIn = 1e6;
        uint256 shares = oracle.getShareOutput(VAULT, address(0), assetsIn);
        uint256 assetsOut = oracle.getAssetOutput(VAULT, address(0), shares);

        assertLe(assetsOut, assetsIn, "Round-trip should not gain assets");
        assertGe(assetsOut, assetsIn - 1, "Round-trip should lose at most 1 wei");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: TVL — ORACLE vs VAULT at EVERY LIFECYCLE STAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Initial: oracle TVL matches vault.totalAssets
    function test_tvl_initialState_matchesVault() public view {
        assertEq(oracle.getTVL(VAULT), vault.totalAssets(), "Global TVL mismatch");
    }

    /// @notice Initial: owner TVL matches convertToAssets(balanceOf) when no pending
    function test_tvlByOwner_initialState_matchesHeldValue() public view {
        uint256 oracleTVL = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 balance = vault.balanceOf(TOP_HOLDER);
        uint256 heldValue = vault.convertToAssets(balance);

        // TOP_HOLDER has no pending withdrawals → TVL == held value
        assertEq(oracleTVL, heldValue, "Initial TVL should equal held share value");
        console2.log("[initial] Owner TVL:", oracleTVL, "Held value:", heldValue);
    }

    /// @notice After deposit: owner TVL increases by deposited amount
    function test_tvlByOwner_afterDeposit() public {
        address depositor = address(0xBEEF);
        uint256 maxDep = _maxDeposit(depositor);
        if (maxDep == 0) {
            console2.log("[deposit] Skipped: maxDeposit is 0");
            return;
        }
        uint256 depositAmount = maxDep;

        deal(FXRP, depositor, depositAmount);
        vm.startPrank(depositor);
        IERC20(FXRP).approve(VAULT, depositAmount);
        (bool ok,) = VAULT.call(abi.encodeWithSignature("deposit(uint256,address)", depositAmount, depositor));
        vm.stopPrank();

        if (!ok) {
            console2.log("[deposit] Skipped: deposit reverted");
            return;
        }

        uint256 oracleTVL = oracle.getTVLByOwnerOfShares(VAULT, depositor);
        uint256 balance = vault.balanceOf(depositor);
        uint256 heldValue = vault.convertToAssets(balance);

        assertEq(oracleTVL, heldValue, "Post-deposit TVL should match held value");
        assertGt(oracleTVL, 0, "Depositor should have non-zero TVL");

        // PPS cross-check
        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());
        assertEq(oraclePPS, vaultPPS, "PPS mismatch post-deposit");

        console2.log("[post-deposit] TVL:", oracleTVL, "Shares:", balance);
        console2.log("[post-deposit] PPS:", oraclePPS);
    }

    /// @notice After partial redeem: oracle TVL preserved (held + pending), vault PPS unchanged
    function test_tvlByOwner_afterPartialRedeem() public {
        uint256 holderBalance = vault.balanceOf(TOP_HOLDER);
        uint256 shares = holderBalance / 4; // 25%

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 ppsBefore = oracle.getPricePerShare(VAULT);

        vm.prank(TOP_HOLDER);
        vault.redeem(shares, TOP_HOLDER, TOP_HOLDER);

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 ppsAfter = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        // TVL preserved (shares moved to pending)
        assertApproxEqRel(tvlAfter, tvlBefore, 0.001e18, "TVL not preserved after partial redeem");

        // PPS unchanged and matches vault
        assertEq(ppsAfter, vaultPPS, "Oracle PPS != vault PPS after partial redeem");
        assertApproxEqAbs(ppsAfter, ppsBefore, 1, "PPS changed after partial redeem");

        // Decompose: held + pending = TVL
        uint256 remainingShares = vault.balanceOf(TOP_HOLDER);
        uint256 heldValue = vault.convertToAssets(remainingShares);
        uint256 period = vault.currentPeriod();
        uint256 pendingValue = vault.withdrawalsOf(period + 1, TOP_HOLDER);

        assertEq(remainingShares, holderBalance - shares, "Wrong remaining shares");
        assertGt(pendingValue, 0, "Pending should be non-zero");
        assertApproxEqRel(tvlAfter, heldValue + pendingValue, 0.001e18, "TVL != held + pending");

        console2.log("[partial-redeem] TVL before:", tvlBefore, "TVL after:", tvlAfter);
        console2.log("[partial-redeem] Held:", heldValue, "Pending:", pendingValue);
        console2.log("[partial-redeem] PPS:", ppsAfter);
    }

    /// @notice After full redeem: balanceOf=0, TVL preserved entirely through pending
    function test_tvlByOwner_afterFullRedeem() public {
        uint256 holderBalance = vault.balanceOf(TOP_HOLDER);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);

        vm.prank(TOP_HOLDER);
        vault.redeem(holderBalance, TOP_HOLDER, TOP_HOLDER);

        // Balance is 0
        assertEq(vault.balanceOf(TOP_HOLDER), 0, "Balance should be 0");

        // TVL preserved through pending
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        assertApproxEqRel(tvlAfter, tvlBefore, 0.001e18, "TVL not preserved after full redeem");

        // PPS still matches vault
        _assertPPSMatch("full-redeem");

        // Without oracle's pending tracking, TVL would be 0 (the bug we're preventing)
        assertEq(
            vault.convertToAssets(vault.balanceOf(TOP_HOLDER)),
            0,
            "Naive TVL (balance only) is 0 - oracle pending tracking prevents this"
        );

        console2.log("[full-redeem] TVL before:", tvlBefore, "TVL after:", tvlAfter);
    }

    /// @notice Multiple redeems accumulate pending in same period, TVL preserved
    function test_tvlByOwner_multipleRedeems_sameUser() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        vault.redeem(1e6, TOP_HOLDER, TOP_HOLDER);
        vault.redeem(2e6, TOP_HOLDER, TOP_HOLDER);
        vault.redeem(5e6, TOP_HOLDER, TOP_HOLDER);
        vm.stopPrank();

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());

        assertApproxEqRel(tvlAfter, tvlBefore, 0.001e18, "TVL not preserved after 3 redeems");
        assertEq(oraclePPS, vaultPPS, "PPS mismatch after multiple redeems");

        // Verify pending accumulation
        uint256 period = vault.currentPeriod();
        uint256 pendingValue = vault.withdrawalsOf(period + 1, TOP_HOLDER);
        assertGt(pendingValue, 0, "Pending should accumulate from 3 redeems");

        console2.log("[multi-redeem] TVL before:", tvlBefore, "TVL after:", tvlAfter);
        console2.log("[multi-redeem] Pending:", pendingValue, "PPS:", oraclePPS);
    }

    /// @notice Two users redeem — each tracked independently
    function test_tvlByOwner_twoUsersRedeem() public {
        // Give a second user some shares by depositing
        address user2 = address(0xCAFE);
        uint256 maxDep = _maxDeposit(user2);
        if (maxDep == 0) {
            // Can't create second user via deposit — test with TOP_HOLDER only
            console2.log("[two-user] Skipped: can't deposit for user2");
            return;
        }

        deal(FXRP, user2, maxDep);
        vm.startPrank(user2);
        IERC20(FXRP).approve(VAULT, maxDep);
        (bool ok,) = VAULT.call(abi.encodeWithSignature("deposit(uint256,address)", maxDep, user2));
        vm.stopPrank();
        if (!ok) {
            console2.log("[two-user] Skipped: deposit failed");
            return;
        }

        uint256 tvl1Before = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 tvl2Before = oracle.getTVLByOwnerOfShares(VAULT, user2);

        // TOP_HOLDER redeems 10 stXRP
        vm.prank(TOP_HOLDER);
        vault.redeem(10e6, TOP_HOLDER, TOP_HOLDER);

        uint256 tvl1After = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 tvl2After = oracle.getTVLByOwnerOfShares(VAULT, user2);

        // TOP_HOLDER TVL preserved, user2 unaffected
        assertApproxEqRel(tvl1After, tvl1Before, 0.001e18, "TOP_HOLDER TVL not preserved");
        assertEq(tvl2After, tvl2Before, "User2 TVL changed unexpectedly");

        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());
        assertEq(oraclePPS, vaultPPS, "PPS mismatch after two-user scenario");

        console2.log("[two-user] Holder TVL:", tvl1After, "User2 TVL:", tvl2After);
        console2.log("[two-user] PPS:", oraclePPS);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: GLOBAL TVL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice Global TVL always matches vault.totalAssets, regardless of redeems
    function test_globalTVL_afterRedeem() public {
        uint256 globalTVLBefore = oracle.getTVL(VAULT);
        uint256 vaultTotalBefore = vault.totalAssets();
        assertEq(globalTVLBefore, vaultTotalBefore, "Global TVL mismatch before redeem");

        vm.prank(TOP_HOLDER);
        vault.redeem(100e6, TOP_HOLDER, TOP_HOLDER);

        uint256 globalTVLAfter = oracle.getTVL(VAULT);
        uint256 vaultTotalAfter = vault.totalAssets();
        assertEq(globalTVLAfter, vaultTotalAfter, "Global TVL mismatch after redeem");

        // Note: totalAssets may or may not decrease after redeem (depends on vault implementation)
        // The point is oracle always matches vault
        console2.log("[global-tvl] Before:", globalTVLBefore, "After:", globalTVLAfter);
    }

    /// @notice PPS relationship: totalAssets ≈ totalSupply * PPS / 10^decimals
    function test_pps_totalAssets_relationship() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = IERC20(VAULT).totalSupply();
        uint256 pps = oracle.getPricePerShare(VAULT);
        uint8 dec = vault.decimals();

        // totalAssets ≈ totalSupply * pps / 10^dec
        uint256 computedTotalAssets = (totalSupply * pps) / (10 ** dec);

        // Allow small rounding difference (up to totalSupply rounding errors)
        assertApproxEqRel(
            computedTotalAssets, totalAssets, 0.0001e18, "totalSupply * PPS should approximate totalAssets"
        );

        console2.log("[relationship] totalAssets:", totalAssets);
        console2.log("[relationship] totalSupply * PPS / 10^dec:", computedTotalAssets);
        console2.log("[relationship] PPS:", pps, "totalSupply:", totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: FULL LIFECYCLE — DEPOSIT → REDEEM → VERIFY
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: deposit -> verify -> partial redeem -> verify -> full redeem -> verify
    function test_fullLifecycle_depositRedeemWithPPSChecks() public {
        address user = address(0xD00D);
        uint256 maxDep = _maxDeposit(user);
        if (maxDep == 0) {
            console2.log("[lifecycle] Skipped: maxDeposit is 0");
            return;
        }

        // Step 1: Deposit
        uint256 tvlPostDeposit = _lifecycle_deposit(user, maxDep);
        if (tvlPostDeposit == 0) return;

        // Step 2: Partial redeem (50%)
        uint256 shares = vault.balanceOf(user);
        uint256 redeemShares = shares / 2;
        if (redeemShares == 0) {
            console2.log("[lifecycle] Skipped: too few shares for partial redeem");
            return;
        }
        _lifecycle_partialRedeem(user, redeemShares, tvlPostDeposit);

        // Step 3: Full redeem (remaining)
        _lifecycle_fullRedeem(user, tvlPostDeposit);
    }

    function _lifecycle_deposit(address user, uint256 amount) internal returns (uint256 tvl) {
        deal(FXRP, user, amount);
        vm.startPrank(user);
        IERC20(FXRP).approve(VAULT, amount);
        (bool ok,) = VAULT.call(abi.encodeWithSignature("deposit(uint256,address)", amount, user));
        vm.stopPrank();
        if (!ok) {
            console2.log("[lifecycle] Skipped: deposit failed");
            return 0;
        }

        uint256 shares = vault.balanceOf(user);
        assertGt(shares, 0, "Should have shares after deposit");
        _assertPPSMatch("post-deposit");

        tvl = oracle.getTVLByOwnerOfShares(VAULT, user);
        assertEq(tvl, vault.convertToAssets(shares), "Post-deposit TVL should match held value");
        console2.log("[lifecycle-deposit] Shares:", shares, "TVL:", tvl);
    }

    function _lifecycle_partialRedeem(address user, uint256 redeemShares, uint256 tvlBefore) internal {
        vm.prank(user);
        vault.redeem(redeemShares, user, user);

        _assertPPSMatch("post-partial-redeem");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(VAULT, user);
        assertApproxEqRel(tvlAfter, tvlBefore, 0.01e18, "TVL preserved after partial redeem");

        uint256 held = vault.convertToAssets(vault.balanceOf(user));
        uint256 pending = vault.withdrawalsOf(vault.currentPeriod() + 1, user);
        console2.log("[lifecycle-partial] Held:", held, "Pending:", pending);
    }

    function _lifecycle_fullRedeem(address user, uint256 tvlBefore) internal {
        uint256 remaining = vault.balanceOf(user);
        vm.prank(user);
        vault.redeem(remaining, user, user);

        _assertPPSMatch("post-full-redeem");
        assertEq(vault.balanceOf(user), 0, "No shares remaining");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(VAULT, user);
        assertApproxEqRel(tvlAfter, tvlBefore, 0.01e18, "TVL preserved after full redeem");

        uint256 pending = vault.withdrawalsOf(vault.currentPeriod() + 1, user);
        assertGt(pending, 0, "All value should be in pending");
        console2.log("[lifecycle-full] Pending:", pending, "TVL:", tvlAfter);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: PENDING WITHDRAWAL TRACKING DEEP DIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Redeem puts value into currentPeriod + 1, oracle picks it up
    function test_pending_goesToNextPeriod() public {
        uint256 period = vault.currentPeriod();
        uint256 pendingBefore = vault.withdrawalsOf(period + 1, TOP_HOLDER);

        vm.prank(TOP_HOLDER);
        uint256 assetsNominal = vault.redeem(100e6, TOP_HOLDER, TOP_HOLDER);

        uint256 pendingAfter = vault.withdrawalsOf(period + 1, TOP_HOLDER);

        assertGt(pendingAfter, pendingBefore, "Pending should increase after redeem");
        assertEq(pendingAfter - pendingBefore, assetsNominal, "Pending delta should match redeem return value");

        console2.log("[pending] Period:", period, "Before:", pendingBefore);
        console2.log("[pending] After:", pendingAfter);
        console2.log("[pending] Nominal assets from redeem:", assetsNominal);
    }

    /// @notice Oracle TVL includes pending from correct period
    function test_pending_oracleIncludesPeriodPlusOne() public {
        uint256 period = vault.currentPeriod();

        vm.prank(TOP_HOLDER);
        vault.redeem(100e6, TOP_HOLDER, TOP_HOLDER);

        uint256 oracleTVL = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 heldValue = vault.convertToAssets(vault.balanceOf(TOP_HOLDER));
        uint256 pendingValue = vault.withdrawalsOf(period + 1, TOP_HOLDER);

        // Oracle TVL = held + pending (from period scan)
        assertEq(oracleTVL, heldValue + pendingValue, "Oracle TVL should equal held + pending");

        console2.log("[pending-oracle] TVL:", oracleTVL, "Held:", heldValue);
        console2.log("[pending-oracle] Pending:", pendingValue);
    }

    /// @notice Consecutive redeems accumulate in same period
    function test_pending_accumulatesInSamePeriod() public {
        uint256 period = vault.currentPeriod();

        vm.startPrank(TOP_HOLDER);
        uint256 nominal1 = vault.redeem(10e6, TOP_HOLDER, TOP_HOLDER);
        uint256 nominal2 = vault.redeem(20e6, TOP_HOLDER, TOP_HOLDER);
        uint256 nominal3 = vault.redeem(30e6, TOP_HOLDER, TOP_HOLDER);
        vm.stopPrank();

        uint256 pendingTotal = vault.withdrawalsOf(period + 1, TOP_HOLDER);
        assertEq(pendingTotal, nominal1 + nominal2 + nominal3, "Pending should accumulate all redeems");

        uint256 oracleTVL = oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER);
        uint256 heldValue = vault.convertToAssets(vault.balanceOf(TOP_HOLDER));
        assertEq(oracleTVL, heldValue + pendingTotal, "Oracle TVL = held + accumulated pending");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: CROSS-VALIDATION TABLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Comprehensive cross-validation: all oracle functions vs direct vault calls
    function test_crossValidation_allFunctions() public view {
        assertEq(oracle.decimals(VAULT), vault.decimals(), "decimals");
        assertEq(oracle.getPricePerShare(VAULT), vault.convertToAssets(1e6), "PPS");
        assertEq(oracle.getShareOutput(VAULT, address(0), 1e6), vault.convertToShares(1e6), "getShareOutput");
        assertEq(oracle.getAssetOutput(VAULT, address(0), 1e6), vault.convertToAssets(1e6), "getAssetOutput");
        assertEq(oracle.getBalanceOfOwner(VAULT, TOP_HOLDER), vault.balanceOf(TOP_HOLDER), "getBalanceOfOwner");
        assertEq(oracle.getTVL(VAULT), vault.totalAssets(), "getTVL");
    }

    /// @notice Cross-validate conversions at multiple scale points
    function test_crossValidation_multipleScales() public view {
        uint256[6] memory scales = [uint256(1), 1e3, 1e6, 1e9, 1e12, type(uint64).max];

        for (uint256 i; i < scales.length; i++) {
            assertEq(
                oracle.getShareOutput(VAULT, address(0), scales[i]),
                vault.convertToShares(scales[i]),
                string.concat("shares@", vm.toString(scales[i]))
            );
            assertEq(
                oracle.getAssetOutput(VAULT, address(0), scales[i]),
                vault.convertToAssets(scales[i]),
                string.concat("assets@", vm.toString(scales[i]))
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    function test_batchPPS() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = VAULT;
        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices[0], oracle.getPricePerShare(VAULT));
    }

    function test_batchTVL() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = VAULT;
        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls[0], oracle.getTVL(VAULT));
    }

    function test_batchTVLByOwner() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = VAULT;
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = TOP_HOLDER;
        owners[0][1] = address(0xdead);

        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls[0][0], oracle.getTVLByOwnerOfShares(VAULT, TOP_HOLDER));
        assertEq(tvls[0][1], 0);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_edge_zeroInputs() public view {
        assertEq(oracle.getShareOutput(VAULT, address(0), 0), 0);
        assertEq(oracle.getAssetOutput(VAULT, address(0), 0), 0);
        assertEq(oracle.getWithdrawalShareOutput(VAULT, address(0), 0), 0);
    }

    function test_edge_unknownAddress() public view {
        assertEq(oracle.getBalanceOfOwner(VAULT, address(0xdead)), 0);
        assertEq(oracle.getTVLByOwnerOfShares(VAULT, address(0xdead)), 0);
    }

    function test_edge_largeConversion() public view {
        uint256 assets = 1_000_000e6;
        uint256 shares = oracle.getShareOutput(VAULT, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(VAULT, address(0), shares);
        assertLe(assetsBack, assets, "Floor rounding");
        assertGt(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Asserts oracle PPS matches vault PPS and logs both
    function _assertPPSMatch(string memory label) internal view {
        uint256 oraclePPS = oracle.getPricePerShare(VAULT);
        uint256 vaultPPS = vault.convertToAssets(10 ** vault.decimals());
        assertEq(oraclePPS, vaultPPS, string.concat("PPS mismatch at: ", label));
        console2.log(string.concat("[", label, "] PPS:"), oraclePPS);
    }

    /// @dev Safe maxDeposit call - returns 0 if function doesn't exist
    function _maxDeposit(address depositor) internal view returns (uint256) {
        (bool ok, bytes memory data) =
            VAULT.staticcall(abi.encodeWithSignature("maxDeposit(address)", depositor));
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }
}
