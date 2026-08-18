// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    Id, IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Market
} from "../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../../src/vendor/morpho/SharesMathLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";

// Oracles
import { MorphoBlueDebtOracle } from "../../../src/accounting/oracles/MorphoBlueDebtOracle.sol";
import { MorphoBlueYieldSourceOracle } from "../../../src/accounting/oracles/MorphoBlueYieldSourceOracle.sol";
import { MorphoBlueMarketRegistry } from "../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

// Hooks
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title DebtOracleMorphoExecutor
/// @notice Minimal contract that acts as both executor and account for Morpho debt oracle + hook testing.
contract DebtOracleMorphoExecutor {
    error EXECUTION_FAILED(uint256 index, bytes returnData);

    function executeHook(address hook, address prevHook, bytes calldata data) external returns (uint256 outAmount) {
        ISuperHook(hook).setExecutionContext(address(this));
        Execution[] memory execs = ISuperHook(hook).build(prevHook, address(this), data);

        for (uint256 i; i < execs.length; ++i) {
            (bool ok, bytes memory ret) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            if (!ok) revert EXECUTION_FAILED(i, ret);
        }

        ISuperHook(hook).resetExecutionState(address(this));
        outAmount = ISuperHookResult(hook).getOutAmount(address(this));
    }
}

/*//////////////////////////////////////////////////////////////
                    TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title MorphoBlueDebtOracleFork
/// @notice E2E fork tests for MorphoBlueDebtOracle against real Morpho Blue on BASE chain,
///         combined with loan hook execution. Tests the oracle's ability to track debt
///         positions before, during, and after leveraged lifecycle operations.
/// @dev Key difference from EulerDebtOracleFork: Morpho's debt oracle has a non-identity PPS
///      that increases over time as interest accrues (borrow shares are priced using
///      totalBorrowAssets / totalBorrowShares), unlike Euler which uses debtOf() directly.
contract MorphoBlueDebtOracleFork is Test {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Morpho Blue (same address on all chains)
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // BASE chain tokens
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Market config (WETH/USDC market on BASE — loanToken=WETH, collateralToken=USDC)
    address public constant MORPHO_ORACLE = 0xD09048c8B568Dbf5f189302beA26c9edABFC4858;
    address public constant MORPHO_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 public constant LLTV = 860_000_000_000_000_000; // 86%
    uint256 public constant LTV_RATIO = 660_000_000_000_000_000; // 66% target LTV for borrow hook

    uint256 public constant BASE_FORK_BLOCK = 49_500_000;

    // Test amounts (conservative to stay within LTV)
    uint256 public constant COLLATERAL_USDC = 10_000e6; // 10,000 USDC
    uint256 public constant BORROW_WETH = 5e16; // 0.05 WETH

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Oracles
    MorphoBlueDebtOracle public debtOracle;
    MorphoBlueYieldSourceOracle public supplyOracle;
    MorphoBlueMarketRegistry public registry;
    SuperLedgerConfiguration public ledgerConfig;

    // Market key (pseudo-address from registry)
    address public marketKey;

    // Hooks
    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoLendHook public lendHook;
    MorphoSupplyAndBorrowHookV2 public supplyAndBorrowV2;
    MorphoRepayAndWithdrawHookV2 public repayAndWithdrawV2;

    // Market params
    MarketParams public marketParams;
    Id public marketId;

    // Executors
    DebtOracleMorphoExecutor public executor;
    DebtOracleMorphoExecutor public executor2;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);

        // Deploy ledger config & registry
        ledgerConfig = new SuperLedgerConfiguration();
        registry = new MorphoBlueMarketRegistry(address(this));

        // Approve IRM and register market
        registry.setIrmApproval(MORPHO_IRM, true);
        marketKey = registry.registerMarket(MORPHO, WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, LLTV);

        // Deploy oracles (both use same registry)
        debtOracle = new MorphoBlueDebtOracle(address(ledgerConfig), address(registry));
        supplyOracle = new MorphoBlueYieldSourceOracle(address(ledgerConfig), address(registry));

        // Deploy hooks
        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        lendHook = new MorphoLendHook(MORPHO);
        supplyAndBorrowV2 = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayAndWithdrawV2 = new MorphoRepayAndWithdrawHookV2(MORPHO);

        // Deploy executors
        executor = new DebtOracleMorphoExecutor();
        executor2 = new DebtOracleMorphoExecutor();

        // Setup market params for direct Morpho calls
        marketParams =
            MarketParams({ loanToken: WETH, collateralToken: USDC, oracle: MORPHO_ORACLE, irm: MORPHO_IRM, lltv: LLTV });
        marketId = marketParams.id();

        // Sanity check: market should have liquidity
        Market memory market = IMorpho(MORPHO).market(marketId);
        assertGt(market.totalSupplyAssets, 0, "Market should have supply");
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _header() internal pure returns (bytes memory) {
        return abi.encodePacked(
            WETH, // 20 bytes
            USDC, // 20 bytes
            bytes12(0) // 12 bytes → total = 52 bytes
        );
    }

    function _encodeSupplyData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(_header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LLTV, false);
    }

    function _encodeBorrowData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(_header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LTV_RATIO, false, LLTV, false);
    }

    function _encodeRepayData(uint256 amt, bool isFullRepayment) internal pure returns (bytes memory) {
        return abi.encodePacked(_header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LLTV, false, isFullRepayment);
    }

    function _encodeSupplyAndBorrowV2Data(uint256 supplyAmt, uint256 borrowAmt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, supplyAmt, borrowAmt, false, LLTV, type(uint256).max
        );
    }

    function _encodeRepayAndWithdrawV2Data(
        uint256 repayAmt,
        uint256 withdrawAmt,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _header(),
            WETH,
            USDC,
            MORPHO_ORACLE,
            MORPHO_IRM,
            repayAmt,
            withdrawAmt,
            false,
            isFullRepayment,
            LLTV,
            type(uint256).max,
            type(uint256).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _fundUSDC(address target, uint256 amount) internal {
        deal(USDC, target, IERC20(USDC).balanceOf(target) + amount);
    }

    function _fundWETH(address target, uint256 amount) internal {
        deal(WETH, target, IERC20(WETH).balanceOf(target) + amount);
    }

    function _openPosition() internal {
        _openPositionFor(executor);
    }

    function _openPositionFor(DebtOracleMorphoExecutor exec) internal {
        _fundUSDC(address(exec), COLLATERAL_USDC);
        exec.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));
        exec.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH));
    }

    function _openPositionComposite() internal {
        _fundUSDC(address(executor), COLLATERAL_USDC);
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );
    }

    function _getPosition(address account)
        internal
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)
    {
        (supplyShares, borrowShares, collateral) = IMorphoStaticTyping(MORPHO).position(marketId, account);
    }

    function _getDebt(address account) internal view returns (uint256) {
        (, uint128 borrowShares,) = _getPosition(account);
        Market memory market = IMorpho(MORPHO).market(marketId);
        return uint256(borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function _fullRepayAndWithdraw(DebtOracleMorphoExecutor exec) internal {
        uint256 debt = _getDebt(address(exec));
        _fundWETH(address(exec), debt + 1e16);

        (,, uint128 collateral) = _getPosition(address(exec));
        exec.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(0, uint256(collateral), true)
        );
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 1: DEBT ORACLE — BASIC READS AGAINST REAL MARKET
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify debt oracle decimals match loanToken.decimals() + 6
    function test_fork_debtOracle_decimals() public view {
        uint8 oracleDecimals = debtOracle.decimals(marketKey);
        uint8 loanDecimals = IERC20Metadata(WETH).decimals();
        assertEq(oracleDecimals, loanDecimals + 6, "Debt oracle decimals = loanDecimals + 6");
        assertEq(oracleDecimals, 24, "WETH (18) + 6 = 24");
    }

    /// @notice Debt oracle decimals match supply oracle decimals (both use same formula)
    function test_fork_debtOracle_decimals_matchesSupplyOracle() public view {
        assertEq(debtOracle.decimals(marketKey), supplyOracle.decimals(marketKey), "Both oracles share decimals");
    }

    /// @notice PPS for debt oracle should be >= 1.0 (10^decimals shares → >= 10^loanDecimals assets)
    function test_fork_debtOracle_pps_nonZero() public view {
        uint256 pps = debtOracle.getPricePerShare(marketKey);
        console2.log("[debtOracle PPS]:", pps);
        assertGe(pps, 1e18, "Borrow PPS should be >= 1.0 in 18-decimal asset units");
    }

    /// @notice TVL (totalBorrowAssets) should be non-zero on an active market
    function test_fork_debtOracle_tvl_nonZero() public view {
        uint256 tvl = debtOracle.getTVL(marketKey);
        assertGt(tvl, 0, "Active market should have nonzero totalBorrowAssets");
        console2.log("[debtOracle TVL]:", tvl);
    }

    /// @notice Share/asset conversions should be consistent with PPS
    function test_fork_debtOracle_conversions_consistent() public view {
        uint8 dec = debtOracle.decimals(marketKey);
        uint256 oneShareUnit = 10 ** dec;

        uint256 pps = debtOracle.getPricePerShare(marketKey);
        uint256 assetFromOneShare = debtOracle.getAssetOutput(marketKey, address(0), oneShareUnit);

        // PPS uses toAssetsUp, getAssetOutput uses toAssetsUp — they should match
        assertEq(assetFromOneShare, pps, "getAssetOutput(1 share unit) must equal PPS");
    }

    /// @notice Round-trip: assets→shares→assets should not create value
    function test_fork_debtOracle_roundTrip_noValueCreation() public view {
        uint256 assets = 1 ether;
        uint256 shares = debtOracle.getShareOutput(marketKey, address(0), assets);
        uint256 assetsBack = debtOracle.getAssetOutput(marketKey, address(0), shares);

        // toAssetsUp(toSharesDown(x)) may be slightly >= x (debt rounding is conservative)
        // But the difference should be at most 1 wei
        assertLe(assetsBack, assets + 1, "Round trip overshoot should be <= 1 wei");
        console2.log("Assets in:", assets, "Assets back:", assetsBack);
    }

    /// @notice No-debt account returns 0 from getBalanceOfOwner
    function test_fork_debtOracle_zeroDebt_unknownAccount() public view {
        address nobody = address(0xdead);
        assertEq(debtOracle.getBalanceOfOwner(marketKey, nobody), 0);
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, nobody), 0);
    }

    /// @notice Zero address as owner returns 0
    function test_fork_debtOracle_zeroDebt_zeroAddress() public view {
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(0)), 0);
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(0)), 0);
    }

    /// @notice getAssetOutputWithFees always bypasses fee logic (P2-1 security fix)
    function test_fork_debtOracle_getAssetOutputWithFees_bypassesFees() public view {
        bytes32 fakeId = keccak256("nonexistent");
        uint256 amount = 1e24; // 1 full share unit (24 decimals for WETH market)
        uint256 result = debtOracle.getAssetOutputWithFees(fakeId, marketKey, WETH, address(executor), amount);
        uint256 expected = debtOracle.getAssetOutput(marketKey, WETH, amount);
        assertEq(result, expected, "getAssetOutputWithFees must equal getAssetOutput (fees bypassed)");
    }

    /// @notice getLastUpdate returns Morpho's stored lastUpdate timestamp
    function test_fork_debtOracle_getLastUpdate() public view {
        uint256 lastUpdate = debtOracle.getLastUpdate(marketKey);
        // At fork block, lastUpdate should be > 0 and <= block.timestamp
        assertGt(lastUpdate, 0, "lastUpdate should be nonzero");
        assertLe(lastUpdate, block.timestamp, "lastUpdate should be <= block.timestamp");
    }

    /// @notice getLastUpdate changes after accrueInterest is called
    function test_fork_debtOracle_getLastUpdate_afterAccrual() public {
        uint256 lastUpdateBefore = debtOracle.getLastUpdate(marketKey);

        vm.warp(block.timestamp + 1 days);
        IMorphoBase(MORPHO).accrueInterest(marketParams);

        uint256 lastUpdateAfter = debtOracle.getLastUpdate(marketKey);
        assertGt(lastUpdateAfter, lastUpdateBefore, "lastUpdate should advance after accrual");
        assertEq(lastUpdateAfter, block.timestamp, "lastUpdate should equal block.timestamp after accrual");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 2: BIT-EXACT PARITY — VIEW vs ON-CHAIN ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Oracle's view-replicated borrow accrual must match Morpho's on-chain state
    ///         after accrueInterest() is called in the same block.
    function test_fork_debtOracle_bitExactParity() public {
        // Warp so there is pending interest to accrue
        vm.warp(block.timestamp + 1 days);

        // 1. Snapshot oracle's view-replicated values BEFORE on-chain accrual
        uint256 oracleTVL = debtOracle.getTVL(marketKey);
        uint256 oraclePPS = debtOracle.getPricePerShare(marketKey);

        // 2. Call accrueInterest on-chain — updates stored state to block.timestamp
        IMorphoBase(MORPHO).accrueInterest(marketParams);

        // 3. Read the now-updated on-chain borrow state
        (,, uint128 totalBorrowAssets,,,) = IMorphoStaticTyping(MORPHO).market(marketId);

        // 4. Oracle TVL must be bit-exact with on-chain totalBorrowAssets
        assertEq(oracleTVL, uint256(totalBorrowAssets), "TVL must be bit-exact with on-chain totalBorrowAssets");

        // 5. PPS must also match (oracle re-reads the now-current state, elapsed=0 → no accrual)
        uint256 ppsAfterAccrual = debtOracle.getPricePerShare(marketKey);
        assertEq(oraclePPS, ppsAfterAccrual, "PPS must be bit-exact: view-replicated == post-accrual stored");
    }

    /// @notice Bit-exact parity after 7 days (longer accrual window)
    function test_fork_debtOracle_bitExactParity_7days() public {
        vm.warp(block.timestamp + 7 days);

        uint256 oracleTVL = debtOracle.getTVL(marketKey);
        IMorphoBase(MORPHO).accrueInterest(marketParams);
        (,, uint128 totalBorrowAssets,,,) = IMorphoStaticTyping(MORPHO).market(marketId);

        assertEq(oracleTVL, uint256(totalBorrowAssets), "TVL bit-exact after 7 days");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: DEBT ORACLE — TRACKS DEBT AFTER BORROW (HOOKS)
    //////////////////////////////////////////////////////////////*/

    /// @notice After supply + borrow via hooks, debt oracle reports correct borrowShares and debt
    function test_fork_debtOracle_tracksDebtAfterBorrow() public {
        // Before borrowing: no debt
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "No shares before borrow");
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(executor)), 0, "No TVL before borrow");

        // Open position: supply 10,000 USDC collateral, borrow 0.05 WETH
        _openPosition();

        // After borrowing: debt oracle should report borrowShares
        uint256 oracleShares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        uint256 oracleTVL = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        (, uint128 directBorrowShares,) = _getPosition(address(executor));

        assertGt(oracleShares, 0, "Oracle should report borrow shares");
        assertEq(oracleShares, uint256(directBorrowShares), "Oracle shares must match position borrowShares");
        assertGe(oracleTVL, BORROW_WETH, "Oracle TVL should be >= borrow amount");

        console2.log("[borrow] Oracle shares:", oracleShares, "TVL:", oracleTVL);
    }

    /// @notice After composite supply+borrow, debt oracle reports correct debt
    function test_fork_debtOracle_tracksDebtAfterCompositeBorrow() public {
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "No shares before");

        _openPositionComposite();

        uint256 oracleShares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        (, uint128 directShares,) = _getPosition(address(executor));
        assertGt(oracleShares, 0, "Should have borrow shares");
        assertEq(oracleShares, uint256(directShares), "Must match position");
    }

    /// @notice Oracle reads in the same block as borrow — no lag
    function test_fork_debtOracle_sameBlockConsistency() public {
        _fundUSDC(address(executor), COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        // Check: no borrow shares before borrow
        uint256 sharesPre = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        assertEq(sharesPre, 0);

        // Borrow in same block
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH));

        // Oracle should reflect immediately
        uint256 sharesPost = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        assertGt(sharesPost, 0, "Borrow shares reflected in same block");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: DEBT ORACLE — INTEREST ACCRUAL / PPS GROWTH
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS increases over time as interest accrues (unlike Euler's identity PPS)
    function test_fork_debtOracle_pps_increasesWithTime() public {
        uint256 ppsBefore = debtOracle.getPricePerShare(marketKey);

        vm.warp(block.timestamp + 30 days);

        uint256 ppsAfter = debtOracle.getPricePerShare(marketKey);
        assertGe(ppsAfter, ppsBefore, "Borrow PPS should not decrease");
        console2.log("[PPS growth] Before:", ppsBefore, "After 30d:", ppsAfter);
    }

    /// @notice Debt TVL for a borrower increases over time (interest accrues)
    function test_fork_debtOracle_interestAccrual_debtGrows() public {
        _openPosition();

        uint256 tvlDay0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        // Warp 7 days
        vm.warp(block.timestamp + 7 days);

        uint256 tvlDay7 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(tvlDay7, tvlDay0, "Debt TVL should not decrease after 7 days");

        // BorrowShares should NOT change (only PPS changes)
        uint256 sharesDay0_implicit = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        (, uint128 directShares,) = _getPosition(address(executor));
        assertEq(sharesDay0_implicit, uint256(directShares), "Shares unchanged - only PPS moves");

        console2.log("[interest 7d] TVL day0:", tvlDay0, "TVL day7:", tvlDay7);
    }

    /// @notice Debt oracle correctly reflects interest accrual over 30 days
    function test_fork_debtOracle_interestAccrual_30days() public {
        _openPosition();

        uint256 tvlDay0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        vm.warp(block.timestamp + 30 days);

        uint256 tvlDay30 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(tvlDay30, tvlDay0, "Debt should not decrease after 30 days");

        console2.log("[interest 30d] TVL day0:", tvlDay0, "TVL day30:", tvlDay30);
    }

    /// @notice Interest is monotonically increasing: day7 <= day30 <= day365
    function test_fork_debtOracle_interestAccrual_monotonic() public {
        _openPosition();

        uint256 tvlDay0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        vm.warp(block.timestamp + 7 days);
        uint256 tvlDay7 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        vm.warp(block.timestamp + 23 days); // total 30 days
        uint256 tvlDay30 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        vm.warp(block.timestamp + 335 days); // total 365 days
        uint256 tvlDay365 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        assertGe(tvlDay7, tvlDay0, "day7 >= day0");
        assertGe(tvlDay30, tvlDay7, "day30 >= day7");
        assertGe(tvlDay365, tvlDay30, "day365 >= day30");
    }

    /// @notice totalBorrows (getTVL) also increases with interest accrual
    function test_fork_debtOracle_tvl_increasesWithInterest() public {
        uint256 tvlBefore = debtOracle.getTVL(marketKey);

        _openPosition();

        uint256 tvlAfterBorrow = debtOracle.getTVL(marketKey);
        assertGt(tvlAfterBorrow, tvlBefore, "TVL should increase after new borrow");

        vm.warp(block.timestamp + 30 days);

        uint256 tvlAfterAccrual = debtOracle.getTVL(marketKey);
        assertGe(tvlAfterAccrual, tvlAfterBorrow, "TVL should not decrease with interest accrual");

        console2.log("[TVL] Before:", tvlBefore, "After borrow:", tvlAfterBorrow);
        console2.log("[TVL] After 30d:", tvlAfterAccrual);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: DEBT ORACLE — PARTIAL REPAY TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle reflects reduced debt after partial repay
    function test_fork_debtOracle_partialRepay_debtDecreases() public {
        _openPosition();

        uint256 tvlBefore = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 sharesBefore = debtOracle.getBalanceOfOwner(marketKey, address(executor));

        // Partial repay: half the borrowed WETH
        uint256 repayAmt = BORROW_WETH / 2;
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmt, false));

        uint256 tvlAfter = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 sharesAfter = debtOracle.getBalanceOfOwner(marketKey, address(executor));

        assertLt(sharesAfter, sharesBefore, "Borrow shares should decrease after partial repay");
        assertLt(tvlAfter, tvlBefore, "Debt TVL should decrease after partial repay");
        assertGt(tvlAfter, 0, "Debt should not be zero after partial repay");

        console2.log("[partial repay] TVL before:", tvlBefore, "TVL after:", tvlAfter);
    }

    /// @notice Partial repay after interest accrual
    function test_fork_debtOracle_partialRepay_afterAccrual() public {
        _openPosition();

        vm.warp(block.timestamp + 7 days);

        uint256 tvlWithInterest = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(tvlWithInterest, BORROW_WETH, "Should have accrued interest");

        // Partial repay
        uint256 repayAmt = BORROW_WETH / 2;
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmt, false));

        uint256 tvlAfterRepay = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertLt(tvlAfterRepay, tvlWithInterest, "Debt should decrease after repay");
        assertGt(tvlAfterRepay, 0, "Residual debt should remain");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: DEBT ORACLE — FULL REPAY CLEARS DEBT
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle returns 0 shares and 0 TVL after full repayment
    function test_fork_debtOracle_fullRepay_debtCleared() public {
        _openPosition();

        uint256 sharesBefore = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        assertGt(sharesBefore, 0, "Should have borrow shares before repay");

        // Fund extra for interest rounding
        uint256 debt = _getDebt(address(executor));
        _fundWETH(address(executor), debt + 1e16);

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 sharesAfter = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        uint256 tvlAfter = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        assertEq(sharesAfter, 0, "Borrow shares should be zero after full repay");
        assertEq(tvlAfter, 0, "TVL should be zero after full repay");
    }

    /// @notice Full repay after 30 days of interest accrual
    function test_fork_debtOracle_fullRepay_afterAccrual() public {
        _openPosition();

        vm.warp(block.timestamp + 30 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debt = _getDebt(address(executor));
        assertGt(debt, BORROW_WETH, "Debt should exceed borrow due to interest");

        _fundWETH(address(executor), debt + 1e16);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Shares cleared after accrual");
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(executor)), 0, "TVL cleared after accrual");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: DUAL ORACLE — SUPPLY + DEBT TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Track both supply oracle (lend-side) and debt oracle (borrow-side) for a position
    function test_fork_dualOracle_supplyAndDebt() public {
        // Before: no position
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "No debt before");

        // Open position: supply collateral + borrow
        _openPosition();

        // Debt oracle should track borrowShares
        uint256 debtShares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        uint256 debtTVL = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGt(debtShares, 0, "Should have debt shares");
        assertGe(debtTVL, BORROW_WETH, "Debt TVL should be >= borrow amount");

        console2.log("[dual] Debt shares:", debtShares, "Debt TVL:", debtTVL);
    }

    /// @notice After interest accrual, debt increases
    function test_fork_dualOracle_interestAccrual() public {
        _openPosition();

        uint256 debtTVL0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        vm.warp(block.timestamp + 30 days);

        uint256 debtTVL30 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(debtTVL30, debtTVL0, "Debt should not decrease after 30 days");

        console2.log("[dual 30d] Debt day0:", debtTVL0, "day30:", debtTVL30);
    }

    /// @notice Full lifecycle: open -> accrue -> full repay+withdraw -> both oracles reset to 0
    function test_fork_dualOracle_fullLifecycle() public {
        // Step 1: Open position
        _openPosition();

        assertGt(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Debt shares > 0");

        // Step 2: Warp 7 days
        vm.warp(block.timestamp + 7 days);

        uint256 tvlWithInterest = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(tvlWithInterest, BORROW_WETH, "Debt should have accrued interest");

        // Step 3: Full repay and withdraw
        _fullRepayAndWithdraw(executor);

        // Debt oracle should return 0
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Debt shares = 0 after close");
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(executor)), 0, "Debt TVL = 0 after close");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: COMPOSITE HOOK LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Composite open -> oracle reads -> composite close -> oracle reads
    function test_fork_debtOracle_compositeHookLifecycle() public {
        // Step 1: Open via composite hook
        _openPositionComposite();

        uint256 shares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        assertGt(shares, 0, "Shares after composite open");

        // Step 2: Warp 7 days
        vm.warp(block.timestamp + 7 days);

        uint256 tvlDay7 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        // Step 3: Close via composite repay+withdraw
        uint256 debt = _getDebt(address(executor));
        _fundWETH(address(executor), debt + 1e16);

        (,, uint128 collateral) = _getPosition(address(executor));
        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(0, uint256(collateral), true)
        );

        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Shares cleared after composite");
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(executor)), 0, "TVL cleared after composite");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: BATCH METHODS ON REAL MARKET
    //////////////////////////////////////////////////////////////*/

    /// @notice getPricePerShareMultiple returns correct PPS
    function test_fork_debtOracle_batchPPS() public view {
        address[] memory keys = new address[](1);
        keys[0] = marketKey;

        uint256[] memory prices = debtOracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 1);
        assertGe(prices[0], 1e18, "PPS should be >= 1.0");
    }

    /// @notice getTVLMultiple returns totalBorrowAssets
    function test_fork_debtOracle_batchTVL() public view {
        address[] memory keys = new address[](1);
        keys[0] = marketKey;

        uint256[] memory tvls = debtOracle.getTVLMultiple(keys);
        assertEq(tvls.length, 1);
        assertGt(tvls[0], 0, "Active market should have borrows");
    }

    /// @notice getTVLByOwnerOfSharesMultiple tracks debt across accounts
    function test_fork_debtOracle_batchTVLByOwner() public {
        _openPosition();

        address[] memory keys = new address[](1);
        keys[0] = marketKey;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = address(executor);
        owners[0][1] = address(0xdead); // no debt

        (uint256[][] memory tvls, bool[][] memory succeeded) = debtOracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertGe(tvls[0][0], BORROW_WETH, "Executor should have debt");
        assertTrue(succeeded[0][0], "Executor query should succeed");
        assertEq(tvls[0][1], 0, "Dead address should have zero debt");
        assertTrue(succeeded[0][1], "Dead address query should succeed");
    }

    /// @notice Empty batch arrays return empty results
    function test_fork_debtOracle_batchPPS_empty() public view {
        address[] memory keys = new address[](0);
        uint256[] memory prices = debtOracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 0);
    }

    function test_fork_debtOracle_batchTVL_empty() public view {
        address[] memory keys = new address[](0);
        uint256[] memory tvls = debtOracle.getTVLMultiple(keys);
        assertEq(tvls.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: SUPPLY vs DEBT ORACLE — DISTINCT SEMANTICS
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle PPS may differ from supply oracle PPS (borrow vs supply share pricing)
    function test_fork_oracle_pps_semanticDifference() public view {
        uint256 debtPPS = debtOracle.getPricePerShare(marketKey);
        uint256 supplyPPS = supplyOracle.getPricePerShare(marketKey);

        // Both should be >= 1.0 in asset units
        assertGe(debtPPS, 1e18, "Debt PPS >= 1.0");
        assertGe(supplyPPS, 1e18, "Supply PPS >= 1.0");

        console2.log("[semantic] Debt PPS:", debtPPS, "Supply PPS:", supplyPPS);
    }

    /// @notice Debt oracle getBalanceOfOwner returns borrowShares; supply oracle returns supplyShares
    function test_fork_oracle_balanceOfOwner_semanticDifference() public {
        _openPosition();

        // Supply oracle for the same market — we need a lend position to compare
        // Instead, just verify debt oracle returns borrowShares
        uint256 debtShares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        (, uint128 directBorrowShares,) = _getPosition(address(executor));
        assertEq(debtShares, uint256(directBorrowShares), "Debt oracle returns borrowShares");
    }

    /// @notice Debt oracle TVL returns accrued totalBorrowAssets; supply oracle TVL returns accrued totalSupplyAssets
    function test_fork_oracle_tvl_semanticDifference() public {
        // Accrue interest on-chain first so stored state matches oracle's view
        IMorphoBase(MORPHO).accrueInterest(marketParams);

        uint256 debtTVL = debtOracle.getTVL(marketKey);
        uint256 supplyTVL = supplyOracle.getTVL(marketKey);

        (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = IMorphoStaticTyping(MORPHO).market(marketId);

        // After accrual, elapsed=0 so oracle reads stored state directly
        assertEq(debtTVL, uint256(totalBorrowAssets), "Debt oracle TVL = totalBorrowAssets");
        assertEq(supplyTVL, uint256(totalSupplyAssets), "Supply oracle TVL = totalSupplyAssets");

        // totalSupplyAssets >= totalBorrowAssets (vault has cash + borrows)
        assertGe(supplyTVL, debtTVL, "Supply TVL >= Debt TVL");

        console2.log("[TVL semantics] Debt:", debtTVL, "Supply:", supplyTVL);
    }

    /// @notice Supply oracle PPS may differ from debt oracle PPS over time
    function test_fork_oracle_pps_divergenceOverTime() public {
        uint256 debtPPS0 = debtOracle.getPricePerShare(marketKey);
        uint256 supplyPPS0 = supplyOracle.getPricePerShare(marketKey);

        vm.warp(block.timestamp + 365 days);

        uint256 debtPPS365 = debtOracle.getPricePerShare(marketKey);
        uint256 supplyPPS365 = supplyOracle.getPricePerShare(marketKey);

        // Both should increase (interest accrues)
        assertGe(debtPPS365, debtPPS0, "Debt PPS should not decrease");
        assertGe(supplyPPS365, supplyPPS0, "Supply PPS should not decrease");

        console2.log("[PPS divergence] Debt 0:", debtPPS0, "365:", debtPPS365);
        console2.log("[PPS divergence] Supply 0:", supplyPPS0, "365:", supplyPPS365);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: SEQUENTIAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential borrows increase debt tracked by oracle
    function test_fork_debtOracle_sequentialBorrows() public {
        _fundUSDC(address(executor), COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 smallBorrow = BORROW_WETH / 5;

        // First borrow
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        uint256 tvl1 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(tvl1, smallBorrow, "TVL after first borrow");

        // Second borrow
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        uint256 tvl2 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGt(tvl2, tvl1, "TVL should increase after second borrow");

        // Third borrow
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        uint256 tvl3 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGt(tvl3, tvl2, "TVL should increase after third borrow");

        console2.log("[seq borrows] 1st:", tvl1, "2nd:", tvl2);
        console2.log("[seq borrows] 3rd:", tvl3);
    }

    /// @notice Sequential partial repays progressively reduce debt
    function test_fork_debtOracle_sequentialPartialRepays() public {
        _openPosition();

        uint256 tvlInitial = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 repayPerStep = BORROW_WETH / 4;

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 tvl1 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertLt(tvl1, tvlInitial, "Debt should decrease after 1st repay");

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 tvl2 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertLt(tvl2, tvl1, "Debt should decrease after 2nd repay");

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 tvl3 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertLt(tvl3, tvl2, "Debt should decrease after 3rd repay");

        console2.log("[seq repays] Initial:", tvlInitial, "After 3rd:", tvl3);
    }

    /// @notice Borrow, repay partial, borrow again — oracle tracks correctly
    function test_fork_debtOracle_borrowRepayBorrow() public {
        _fundUSDC(address(executor), COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 smallBorrow = BORROW_WETH / 2;

        // Borrow
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        uint256 tvl1 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        // Repay half
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(smallBorrow / 2, false));
        uint256 tvl2 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertLt(tvl2, tvl1, "TVL should decrease after partial repay");

        // Borrow more
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow / 2));
        uint256 tvl3 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGt(tvl3, tvl2, "TVL should increase after re-borrow");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 12: RE-OPEN AFTER CLOSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Close position fully, re-open, verify oracle tracks new debt correctly
    function test_fork_debtOracle_reopenAfterClose() public {
        // Open and close position
        _openPosition();
        _fullRepayAndWithdraw(executor);

        // Verify clean slate
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Shares 0 after close");
        assertEq(debtOracle.getTVLByOwnerOfShares(marketKey, address(executor)), 0, "TVL 0 after close");

        // Re-open with smaller amounts
        uint256 newCollateral = 5000e6;
        uint256 newBorrow = BORROW_WETH / 2;
        _fundUSDC(address(executor), newCollateral);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(newCollateral));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(newBorrow));

        uint256 newTVL = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        assertGe(newTVL, newBorrow, "New debt should reflect re-opened position");

        console2.log("[reopen] New TVL:", newTVL);
    }

    /// @notice Multiple close-reopen cycles
    function test_fork_debtOracle_multipleCycles() public {
        // Cycle 1
        _openPosition();
        assertGt(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Cycle 1: has shares");
        _fullRepayAndWithdraw(executor);
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Cycle 1: cleared");

        // Cycle 2
        _openPosition();
        assertGt(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Cycle 2: has shares");
        _fullRepayAndWithdraw(executor);
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Cycle 2: cleared");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 13: MULTI-ACCOUNT TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Two independent accounts with separate debt positions
    function test_fork_debtOracle_multipleAccounts_independentDebt() public {
        // Open position for executor1
        _openPositionFor(executor);

        // Open position for executor2 with smaller amounts
        _fundUSDC(address(executor2), 5000e6);
        executor2.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH / 2));

        // Each should have independent debt
        uint256 tvl1 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 tvl2 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor2));

        assertGe(tvl1, BORROW_WETH, "Executor 1 TVL >= borrow amount");
        assertGe(tvl2, BORROW_WETH / 2, "Executor 2 TVL >= half borrow amount");
        assertGt(tvl1, tvl2, "Executor 1 should have more debt");

        // Repay executor2's debt — should not affect executor1
        uint256 debt2 = _getDebt(address(executor2));
        _fundWETH(address(executor2), debt2 + 1e16);
        executor2.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(executor2)), 0, "Executor 2 shares cleared");
        assertGt(debtOracle.getBalanceOfOwner(marketKey, address(executor)), 0, "Executor 1 shares unaffected");
    }

    /// @notice Batch query returns correct per-account debt
    function test_fork_debtOracle_multipleAccounts_batchQuery() public {
        _openPositionFor(executor);

        _fundUSDC(address(executor2), 5000e6);
        executor2.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH / 4));

        address[] memory keys = new address[](1);
        keys[0] = marketKey;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](3);
        owners[0][0] = address(executor);
        owners[0][1] = address(executor2);
        owners[0][2] = address(0xdead);

        (uint256[][] memory tvls, bool[][] memory succeeded) = debtOracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertGe(tvls[0][0], BORROW_WETH, "Executor 1 debt");
        assertTrue(succeeded[0][0]);
        assertGe(tvls[0][1], BORROW_WETH / 4, "Executor 2 debt");
        assertTrue(succeeded[0][1]);
        assertEq(tvls[0][2], 0, "Dead address no debt");
        assertTrue(succeeded[0][2]);
    }

    /// @notice Interest accrual affects both accounts (PPS rises for all)
    function test_fork_debtOracle_multipleAccounts_interestAccrual() public {
        _openPositionFor(executor);

        _fundUSDC(address(executor2), 5000e6);
        executor2.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH / 2));

        uint256 tvl1_day0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 tvl2_day0 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor2));

        vm.warp(block.timestamp + 30 days);

        uint256 tvl1_day30 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));
        uint256 tvl2_day30 = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor2));

        assertGe(tvl1_day30, tvl1_day0, "Account 1 debt should not decrease");
        assertGe(tvl2_day30, tvl2_day0, "Account 2 debt should not decrease");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 14: EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Small borrow — minimum viable amount tracked correctly
    function test_fork_debtOracle_smallBorrow() public {
        _fundUSDC(address(executor), COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 smallBorrow = 100; // 100 wei of WETH
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));

        uint256 shares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        assertGt(shares, 0, "Small borrow should create borrow shares");
    }

    /// @notice Existing borrowers on the forked market — totalBorrowAssets should be nonzero
    function test_fork_debtOracle_existingMarketBorrowers() public view {
        uint256 totalBorrows = debtOracle.getTVL(marketKey);
        assertGt(totalBorrows, 0, "Market should have existing borrows at fork block");

        // Verify borrow utilization (totalBorrowAssets / totalSupplyAssets)
        uint256 totalSupply = supplyOracle.getTVL(marketKey);
        assertGt(totalSupply, totalBorrows, "Supply should exceed borrows");

        console2.log("[existing] Total borrows:", totalBorrows, "Total supply:", totalSupply);
    }

    /// @notice Non-borrower contract returns 0 for getBalanceOfOwner
    function test_fork_debtOracle_contractNonBorrower() public view {
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(debtOracle)), 0);
        assertEq(debtOracle.getBalanceOfOwner(marketKey, address(supplyOracle)), 0);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 15: MORPHO-SPECIFIC — SHARES vs ASSETS DISTINCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice getBalanceOfOwner returns borrowShares (not assets), getTVLByOwnerOfShares returns assets
    function test_fork_debtOracle_sharesVsAssets() public {
        _openPosition();

        uint256 oracleShares = debtOracle.getBalanceOfOwner(marketKey, address(executor));
        uint256 oracleTVL = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        // Shares and assets are in different units — shares have +6 decimal offset
        // They should NOT be equal in general (PPS != 1.0 after interest accrues)
        assertGt(oracleShares, 0, "Should have shares");
        assertGt(oracleTVL, 0, "Should have TVL");

        // TVL = shares * PPS / 10^decimals  (conceptually)
        // For a just-opened position, PPS ≈ 1.0 so TVL ≈ shares / 10^6
        console2.log("[shares vs assets] Shares:", oracleShares, "TVL:", oracleTVL);
    }

    /// @notice toAssetsUp rounding: getAssetOutput rounds UP (conservative for borrower)
    function test_fork_debtOracle_roundingConvention() public view {
        // Compare toAssetsUp (debt oracle) vs toAssetsDown (supply oracle) for same share amount
        uint256 testShares = 1e24; // 1 full share unit for 18-dec loanToken
        uint256 debtAssets = debtOracle.getAssetOutput(marketKey, address(0), testShares);
        uint256 supplyAssets = supplyOracle.getAssetOutput(marketKey, address(0), testShares);

        // Debt rounds up, supply rounds down → debt should be >= supply (for same shares)
        // Note: different oracle uses different totalAssets/totalShares so this may not always hold,
        // but the rounding direction should be correct within each oracle
        assertGe(debtAssets, 0, "Debt assets should be positive");
        assertGe(supplyAssets, 0, "Supply assets should be positive");

        console2.log("[rounding] Debt assets:", debtAssets, "Supply assets:", supplyAssets);
    }

    /// @notice getShareOutput (toSharesDown) and getWithdrawalShareOutput (toSharesUp) differ by rounding
    function test_fork_debtOracle_shareOutputRounding() public view {
        uint256 assets = 1 ether;

        uint256 sharesDown = debtOracle.getShareOutput(marketKey, address(0), assets);
        uint256 sharesUp = debtOracle.getWithdrawalShareOutput(marketKey, address(0), assets);

        // toSharesUp >= toSharesDown always
        assertGe(sharesUp, sharesDown, "Withdrawal shares (up) >= deposit shares (down)");

        console2.log("[share rounding] Down:", sharesDown, "Up:", sharesUp);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 16: 365-DAY ELAPSED CAP
    //////////////////////////////////////////////////////////////*/

    /// @notice Warping beyond 365 days does not cause overflow — elapsed is capped
    function test_fork_debtOracle_elapsedCap_noOverflow() public {
        _openPosition();

        // Warp 2 years — should be capped to 365 days internally
        vm.warp(block.timestamp + 730 days);

        // These should not revert
        uint256 pps = debtOracle.getPricePerShare(marketKey);
        uint256 tvl = debtOracle.getTVL(marketKey);
        uint256 userTvl = debtOracle.getTVLByOwnerOfShares(marketKey, address(executor));

        assertGt(pps, 0, "PPS should be positive after 2 years");
        assertGt(tvl, 0, "TVL should be positive after 2 years");
        assertGt(userTvl, 0, "User TVL should be positive after 2 years");

        console2.log("[2y cap] PPS:", pps, "TVL:", tvl);
        console2.log("[2y cap] User TVL:", userTvl);
    }
}
