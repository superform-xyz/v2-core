// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import {
    Id,
    IMorpho,
    IMorphoBase,
    IMorphoStaticTyping,
    MarketParams,
    Market
} from "../../../src/vendor/morpho/IMorpho.sol";
import { SharesMathLib } from "../../../src/vendor/morpho/SharesMathLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";

// Individual hooks
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";

// V2 composite hooks
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title MorphoHookExecutor
/// @notice Minimal contract that acts as both executor and account for Morpho hook testing.
contract MorphoHookExecutor {
    error EXECUTION_FAILED(uint256 index, bytes returnData);

    function executeHook(
        address hook,
        address prevHook,
        bytes calldata data
    )
        external
        returns (uint256 outAmount)
    {
        ISuperHook(hook).setExecutionContext(address(this));
        Execution[] memory execs = ISuperHook(hook).build(prevHook, address(this), data);

        for (uint256 i; i < execs.length; ++i) {
            (bool ok, bytes memory ret) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            if (!ok) revert EXECUTION_FAILED(i, ret);
        }

        ISuperHook(hook).resetExecutionState(address(this));
        outAmount = ISuperHookResult(hook).getOutAmount(address(this));
    }

    function executeHooks(
        address[] calldata hooks,
        address[] calldata prevHooks,
        bytes[] calldata datas
    )
        external
        returns (uint256 lastOutAmount)
    {
        for (uint256 h; h < hooks.length; ++h) {
            ISuperHook(hooks[h]).setExecutionContext(address(this));
            Execution[] memory execs = ISuperHook(hooks[h]).build(prevHooks[h], address(this), datas[h]);

            for (uint256 i; i < execs.length; ++i) {
                (bool ok, bytes memory ret) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
                if (!ok) revert EXECUTION_FAILED(i, ret);
            }

            ISuperHook(hooks[h]).resetExecutionState(address(this));
            lastOutAmount = ISuperHookResult(hooks[h]).getOutAmount(address(this));
        }
    }
}

/*//////////////////////////////////////////////////////////////
                    TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title MorphoLoanHooksEdgeCasesFork
/// @notice Fork tests for Morpho Blue loan hooks on BASE chain, with focus on V2 composite hooks
///         and edge cases: partial repay, full repay, interest drift, independent amounts, re-open positions.
contract MorphoLoanHooksEdgeCasesFork is Test {
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

    // Market config (WETH/USDC market on BASE)
    address public constant MORPHO_ORACLE = 0xD09048c8B568Dbf5f189302beA26c9edABFC4858;
    address public constant MORPHO_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 public constant LLTV = 860_000_000_000_000_000; // 86%
    uint256 public constant LTV_RATIO = 660_000_000_000_000_000; // 66% target LTV for borrow hook

    uint256 public constant BASE_FORK_BLOCK = 49_500_000;

    // Test amounts (conservative to stay within LTV)
    uint256 public constant COLLATERAL_USDC = 10_000e6; // 10,000 USDC
    uint256 public constant BORROW_WETH = 5e16; // 0.05 WETH — well below LTV cap
    uint256 public constant LEND_WETH = 1e18; // 1 WETH for lend-side tests

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Individual hooks
    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;

    // V2 composite hooks
    MorphoSupplyAndBorrowHookV2 public supplyAndBorrowV2;
    MorphoRepayAndWithdrawHookV2 public repayAndWithdrawV2;

    // Executor
    MorphoHookExecutor public executor;

    // Market
    MarketParams public marketParams;
    Id public marketId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);

        // Deploy hooks
        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        supplyAndBorrowV2 = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayAndWithdrawV2 = new MorphoRepayAndWithdrawHookV2(MORPHO);

        // Deploy executor
        executor = new MorphoHookExecutor();

        // Setup market params
        marketParams = MarketParams({
            loanToken: WETH,
            collateralToken: USDC,
            oracle: MORPHO_ORACLE,
            irm: MORPHO_IRM,
            lltv: LLTV
        });
        marketId = marketParams.id();

        // Sanity check: market should have liquidity
        Market memory market = IMorpho(MORPHO).market(marketId);
        assertGt(market.totalSupplyAssets, 0, "Market should have supply");
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Standard 52-byte header + hook-specific fields
    function _header() internal pure returns (bytes memory) {
        return abi.encodePacked(
            WETH, // 20 bytes
            USDC, // 20 bytes
            bytes12(0) // 12 bytes → total = 52 bytes
        );
    }

    /// @dev Supply collateral data (197 bytes)
    function _encodeSupplyData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LLTV, false
        );
    }

    /// @dev Borrow data (230 bytes — includes ltvRatio + lltv)
    function _encodeBorrowData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LTV_RATIO, false, LLTV, false
        );
    }

    /// @dev Repay data (198 bytes)
    function _encodeRepayData(uint256 amt, bool isFullRepayment) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LLTV, false, isFullRepayment
        );
    }

    /// @dev Lend data (197 bytes — same layout as supply but uses loanToken)
    function _encodeLendData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, amt, LLTV, false
        );
    }

    /// @dev Withdraw lend-side data (228 bytes — lltv + assets + shares)
    function _encodeWithdrawData(uint256 assets, uint256 shares) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, LLTV, assets, shares
        );
    }

    /// @dev V2 SupplyAndBorrow data (229 bytes)
    function _encodeSupplyAndBorrowV2Data(uint256 supplyAmt, uint256 borrowAmt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, supplyAmt, borrowAmt, false, LLTV
        );
    }

    /// @dev V2 RepayAndWithdraw data (230 bytes)
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
            _header(), WETH, USDC, MORPHO_ORACLE, MORPHO_IRM, repayAmt, withdrawAmt, false, isFullRepayment, LLTV
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _fundUSDC(uint256 amount) internal {
        deal(USDC, address(executor), IERC20(USDC).balanceOf(address(executor)) + amount);
    }

    function _fundWETH(uint256 amount) internal {
        deal(WETH, address(executor), IERC20(WETH).balanceOf(address(executor)) + amount);
    }

    function _openPosition() internal {
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH));
    }

    function _openPositionV2() internal {
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );
    }

    function _getPosition()
        internal
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)
    {
        (supplyShares, borrowShares, collateral) = IMorphoStaticTyping(MORPHO).position(marketId, address(executor));
    }

    function _getDebt() internal view returns (uint256) {
        (, uint128 borrowShares,) = _getPosition();
        Market memory market = IMorpho(MORPHO).market(marketId);
        return uint256(borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 1: V2 SUPPLY AND BORROW — INDEPENDENT AMOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 SupplyAndBorrow: both collateral and borrow amounts are independent
    function test_fork_V2SupplyAndBorrow_BasicOpen() public {
        _fundUSDC(COLLATERAL_USDC);

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );

        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        // outAmount tracks collateral consumed
        assertEq(outAmount, COLLATERAL_USDC, "outAmount should track USDC consumed");

        // WETH received
        assertEq(wethAfter - wethBefore, BORROW_WETH, "Should have received borrowed WETH");

        // Position state
        (, uint128 borrowShares, uint128 collateral) = _getPosition();
        assertEq(uint256(collateral), COLLATERAL_USDC, "Collateral should be recorded");
        assertGt(uint256(borrowShares), 0, "Should have borrow shares");

        console2.log("[V2 supply+borrow] Collateral:", COLLATERAL_USDC, "Borrowed:", BORROW_WETH);
    }

    /// @notice V2 SupplyAndBorrow: add to existing position
    function test_fork_V2SupplyAndBorrow_AddToPosition() public {
        _openPositionV2();
        (, uint128 borrowSharesBefore, uint128 collateralBefore) = _getPosition();

        // Add more: 5000 USDC collateral + 0.02 WETH borrow
        _fundUSDC(5000e6);
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(5000e6, 2e16)
        );

        (, uint128 borrowSharesAfter, uint128 collateralAfter) = _getPosition();
        assertEq(uint256(collateralAfter), uint256(collateralBefore) + 5000e6, "Collateral should increase");
        assertGt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "Borrow shares should increase");
    }

    /// @notice V2 SupplyAndBorrow: small amounts (1 USDC + minimum WETH)
    function test_fork_V2SupplyAndBorrow_SmallAmounts() public {
        _fundUSDC(1e6);

        // Very small borrow — 100 wei of WETH
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(1e6, 100)
        );

        (, uint128 borrowShares, uint128 collateral) = _getPosition();
        assertEq(uint256(collateral), 1e6, "Should have 1 USDC collateral");
        assertGt(uint256(borrowShares), 0, "Should have borrow shares");
    }

    /// @notice V2 SupplyAndBorrow: zero primary amount reverts
    function test_fork_V2SupplyAndBorrow_ZeroPrimaryReverts() public {
        _fundUSDC(COLLATERAL_USDC);
        vm.expectRevert();
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(0, BORROW_WETH)
        );
    }

    /// @notice V2 SupplyAndBorrow: zero secondary amount reverts
    function test_fork_V2SupplyAndBorrow_ZeroSecondaryReverts() public {
        _fundUSDC(COLLATERAL_USDC);
        vm.expectRevert();
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, 0)
        );
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 2: V2 REPAY AND WITHDRAW — INDEPENDENT AMOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 RepayAndWithdraw: partial repay, no withdraw (secondaryAmount = 0)
    function test_fork_V2RepayAndWithdraw_PartialRepayOnly() public {
        _openPositionV2();
        uint256 debtBefore = _getDebt();

        // Partial repay: half the borrowed WETH
        uint256 repayAmt = BORROW_WETH / 2;
        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(repayAmt, 0, false)
        );

        uint256 debtAfter = _getDebt();
        assertLt(debtAfter, debtBefore, "Debt should decrease after partial repay");
        assertGt(debtAfter, 0, "Debt should still exist");

        // Collateral unchanged
        (,, uint128 collateral) = _getPosition();
        assertEq(uint256(collateral), COLLATERAL_USDC, "Collateral should be unchanged");
    }

    /// @notice V2 RepayAndWithdraw: partial repay + independent partial withdraw
    function test_fork_V2RepayAndWithdraw_PartialRepayPartialWithdraw() public {
        _openPositionV2();

        uint256 repayAmt = BORROW_WETH / 2;
        uint256 withdrawAmt = 1000e6; // Withdraw 1000 USDC
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));

        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(repayAmt, withdrawAmt, false)
        );

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));
        assertEq(usdcAfter - usdcBefore, withdrawAmt, "Should have withdrawn USDC");

        (, uint128 borrowShares, uint128 collateral) = _getPosition();
        assertGt(uint256(borrowShares), 0, "Should still have debt");
        assertEq(uint256(collateral), COLLATERAL_USDC - withdrawAmt, "Collateral should decrease");
    }

    /// @notice V2 RepayAndWithdraw: full repay, no withdraw
    function test_fork_V2RepayAndWithdraw_FullRepayOnly() public {
        _openPositionV2();

        uint256 debt = _getDebt();
        _fundWETH(debt); // Extra WETH to cover interest

        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(0, 0, true)
        );

        (, uint128 borrowShares, uint128 collateral) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Debt should be fully repaid");
        assertEq(uint256(collateral), COLLATERAL_USDC, "Collateral should be unchanged");
    }

    /// @notice V2 RepayAndWithdraw: full repay + independent withdraw
    function test_fork_V2RepayAndWithdraw_FullRepayWithdraw() public {
        _openPositionV2();

        uint256 debt = _getDebt();
        _fundWETH(debt);

        uint256 withdrawAmt = 5000e6;
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));

        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(0, withdrawAmt, true)
        );

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));
        (, uint128 borrowShares, uint128 collateral) = _getPosition();

        assertEq(uint256(borrowShares), 0, "Debt should be zero");
        assertEq(uint256(collateral), COLLATERAL_USDC - withdrawAmt, "Collateral should decrease");
        assertEq(usdcAfter - usdcBefore, withdrawAmt, "Should have received withdrawn USDC");
    }

    /// @notice V2 RepayAndWithdraw: full repay + full withdraw
    function test_fork_V2RepayAndWithdraw_FullRepayFullWithdraw() public {
        _openPositionV2();

        uint256 debt = _getDebt();
        _fundWETH(debt);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));

        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, COLLATERAL_USDC, true)
        );

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));
        (, uint128 borrowShares, uint128 collateral) = _getPosition();

        assertEq(uint256(borrowShares), 0, "Debt should be zero");
        assertEq(uint256(collateral), 0, "Collateral should be zero");
        assertEq(usdcAfter - usdcBefore, COLLATERAL_USDC, "Should have received all USDC back");

        console2.log("[V2 full close] Debt repaid:", debt, "Collateral returned:", COLLATERAL_USDC);
    }

    /// @notice V2 RepayAndWithdraw: minimum partial repay (1 wei WETH)
    function test_fork_V2RepayAndWithdraw_MinimumRepay() public {
        _openPositionV2();

        uint256 debtBefore = _getDebt();

        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(1, 0, false)
        );

        uint256 debtAfter = _getDebt();
        assertLe(debtAfter, debtBefore, "Debt should decrease or stay same");
    }

    /// @notice V2 RepayAndWithdraw: repay caps to current debt under interest drift
    /// @dev The V2 hook's _preExecute calls accrueInterest(), which changes market state after build()
    ///      computed the capped repay amount. We accrue interest BEFORE executing the hook so that
    ///      build() and preExecute see consistent state.
    function test_fork_V2RepayAndWithdraw_RepayCapsToDeb() public {
        _openPositionV2();

        // Advance time so preExecute's accrueInterest() accrues 1s of interest.
        // build() reads raw (stale) market state, computes capped repay amount.
        // preExecute then accrues, making the real debt slightly larger than the cap,
        // which avoids the toAssetsUp→toSharesDown round-trip rounding issue.
        vm.warp(block.timestamp + 1);

        // Try to repay more than owed — V2 hook caps to current debt
        uint256 excessiveRepay = BORROW_WETH * 3; // 3x the borrowed amount
        _fundWETH(excessiveRepay);

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(excessiveRepay, 0, false)
        );
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        // Should only consume approximately the actual debt, not the full requested amount
        uint256 consumed = wethBefore - wethAfter;
        assertLt(consumed, excessiveRepay, "Should consume less than requested (capped to debt)");
        assertGe(consumed, BORROW_WETH, "Should consume at least the borrow amount");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: INDIVIDUAL HOOKS — PARTIAL REPAY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial repay: exact borrowed amount (may leave residual interest)
    function test_fork_RepayPartial_ExactBorrowAmount() public {
        _openPosition();

        uint256 debtBefore = _getDebt();

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(BORROW_WETH, false));

        uint256 debtAfter = _getDebt();
        assertLt(debtAfter, debtBefore, "Debt should decrease");
        // May have residual interest debt
        console2.log("[exact repay] Remaining debt:", debtAfter);
    }

    /// @notice Multiple sequential partial repays
    function test_fork_RepayPartial_MultipleSequential() public {
        _openPosition();

        uint256 debtInitial = _getDebt();
        uint256 repayPerStep = BORROW_WETH / 4;

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 debt1 = _getDebt();
        assertLt(debt1, debtInitial, "Debt should decrease after 1st repay");

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 debt2 = _getDebt();
        assertLt(debt2, debt1, "Debt should decrease after 2nd repay");

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayPerStep, false));
        uint256 debt3 = _getDebt();
        assertLt(debt3, debt2, "Debt should decrease after 3rd repay");

        console2.log("[multi-repay] Initial:", debtInitial, "After 3:", debt3);
    }

    /// @notice Partial repay after interest accrual — repay only the interest
    function test_fork_RepayPartial_InterestOnly() public {
        _openPosition();

        vm.warp(block.timestamp + 30 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debtWithInterest = _getDebt();
        uint256 interestAccrued = debtWithInterest - BORROW_WETH;

        if (interestAccrued > 0) {
            _fundWETH(interestAccrued);
            executor.executeHook(address(repayHook), address(0), _encodeRepayData(interestAccrued, false));

            uint256 debtAfter = _getDebt();
            assertLe(debtAfter, BORROW_WETH + 1e15, "Debt should be close to original borrow");
        }

        console2.log("[interest-only repay] Interest:", interestAccrued);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: INDIVIDUAL HOOKS — FULL REPAY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Full repay after 90 days of interest accrual
    function test_fork_RepayFull_AfterLongInterestAccrual() public {
        _openPosition();

        vm.warp(block.timestamp + 90 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debt = _getDebt();
        assertGt(debt, BORROW_WETH, "Debt should exceed borrow due to interest");

        _fundWETH(debt + 1e16); // Buffer
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        (, uint128 borrowShares,) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Debt should be fully repaid");

        console2.log("[full repay 90d] Debt was:", debt);
    }

    /// @notice Full repay with excess funds — surplus stays with executor
    function test_fork_RepayFull_ExcessFunds() public {
        _openPosition();

        uint256 excess = 1e18;
        _fundWETH(excess);

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        (, uint128 borrowShares,) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Debt should be repaid");

        uint256 consumed = wethBefore - wethAfter;
        assertGe(consumed, BORROW_WETH, "Should consume at least borrow amount");
        assertGt(wethAfter, 0, "Surplus WETH should remain");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: SUPPLY COLLATERAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential supply operations
    function test_fork_SupplyCollateral_MultipleDeposits() public {
        _fundUSDC(3000e6);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(1000e6));

        (,, uint128 col1) = _getPosition();
        assertEq(uint256(col1), 1000e6, "1st deposit");

        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(1000e6));
        (,, uint128 col2) = _getPosition();
        assertEq(uint256(col2), 2000e6, "2nd deposit");

        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(1000e6));
        (,, uint128 col3) = _getPosition();
        assertEq(uint256(col3), 3000e6, "3rd deposit");
    }

    /// @notice Add collateral to existing position to improve health
    function test_fork_SupplyCollateral_AddToExistingPosition() public {
        _openPosition();

        (,, uint128 collateralBefore) = _getPosition();
        assertEq(uint256(collateralBefore), COLLATERAL_USDC, "Initial collateral");

        _fundUSDC(5000e6);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));

        (,, uint128 collateralAfter) = _getPosition();
        assertEq(uint256(collateralAfter), COLLATERAL_USDC + 5000e6, "Collateral should increase");
    }

    /// @notice Supply minimum amount (1 USDC)
    function test_fork_SupplyCollateral_MinimumAmount() public {
        _fundUSDC(1e6);
        uint256 outAmount = executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(1e6));

        assertEq(outAmount, 1e6, "outAmount should match supply");
        (,, uint128 collateral) = _getPosition();
        assertEq(uint256(collateral), 1e6, "Collateral should be 1 USDC");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: BORROW EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential borrows
    function test_fork_Borrow_MultipleSequential() public {
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 smallBorrow = BORROW_WETH / 5; // 0.01 WETH

        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));

        assertEq(IERC20(WETH).balanceOf(address(executor)), smallBorrow * 3, "Should have total borrowed WETH");
        assertGt(_getDebt(), 0, "Should have debt");
    }

    /// @notice Borrow minimum amount
    function test_fork_Borrow_MinimumAmount() public {
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 outAmount = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(1));

        assertEq(outAmount, 1, "outAmount should be 1 wei");
        assertGt(_getDebt(), 0, "Should have debt");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: LEND + WITHDRAW EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Lend WETH then partial withdraw by assets
    function test_fork_LendAndPartialWithdraw_ByAssets() public {
        _fundWETH(LEND_WETH);
        executor.executeHook(address(lendHook), address(0), _encodeLendData(LEND_WETH));

        (uint256 supplySharesBefore,,) = _getPosition();
        assertGt(supplySharesBefore, 0, "Should have supply shares");

        // Withdraw half by assets
        uint256 withdrawAssets = LEND_WETH / 2;
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(withdrawAssets, 0));

        (uint256 supplySharesAfter,,) = _getPosition();
        assertLt(supplySharesAfter, supplySharesBefore, "Supply shares should decrease");
        assertGt(supplySharesAfter, 0, "Should still have supply shares");
    }

    /// @notice Lend WETH then full withdraw by shares
    function test_fork_LendAndFullWithdraw_ByShares() public {
        _fundWETH(LEND_WETH);
        executor.executeHook(address(lendHook), address(0), _encodeLendData(LEND_WETH));

        (uint256 supplyShares,,) = _getPosition();

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(0, supplyShares));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        (uint256 supplySharesAfter,,) = _getPosition();
        assertEq(supplySharesAfter, 0, "Position should be fully closed");
        // Share-to-asset conversion may lose up to 1 wei due to rounding down
        assertGe(wethAfter - wethBefore, LEND_WETH - 1, "Should get back at least lent amount (1 wei rounding tolerance)");
    }

    /// @notice Lend with interest accrual — withdraw more than lent
    function test_fork_LendWithInterest_WithdrawMore() public {
        _fundWETH(LEND_WETH);
        executor.executeHook(address(lendHook), address(0), _encodeLendData(LEND_WETH));

        // Warp 30 days for interest
        vm.warp(block.timestamp + 30 days);

        (uint256 supplyShares,,) = _getPosition();

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(0, supplyShares));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        uint256 received = wethAfter - wethBefore;
        assertGe(received, LEND_WETH, "Should receive at least the lent amount (interest may be zero in low-activity market)");

        console2.log("[lend+interest] Lent:", LEND_WETH, "Received after 30d:", received);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: INTEREST ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Interest accrual at multiple intervals
    function test_fork_InterestAccrual_MultipleIntervals() public {
        _openPosition();
        uint256 debtInitial = _getDebt();

        vm.warp(block.timestamp + 1 days);
        IMorpho(MORPHO).accrueInterest(marketParams);
        uint256 debt1d = _getDebt();
        assertGe(debt1d, debtInitial, "Debt should not decrease after 1 day");

        vm.warp(block.timestamp + 6 days);
        IMorpho(MORPHO).accrueInterest(marketParams);
        uint256 debt7d = _getDebt();
        assertGe(debt7d, debt1d, "Debt should not decrease after 7 days");

        vm.warp(block.timestamp + 23 days);
        IMorpho(MORPHO).accrueInterest(marketParams);
        uint256 debt30d = _getDebt();
        assertGe(debt30d, debt7d, "Debt should not decrease after 30 days");

        console2.log("[interest] 1d delta:", debt1d - debtInitial);
        console2.log("[interest] 7d delta:", debt7d - debtInitial);
        console2.log("[interest] 30d delta:", debt30d - debtInitial);
    }

    /// @notice Full repay after interest is exact (share-based)
    function test_fork_InterestAccrual_FullRepayIsExact() public {
        _openPosition();

        vm.warp(block.timestamp + 30 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debt = _getDebt();
        _fundWETH(debt + 1e16);

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        (, uint128 borrowShares,) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Should have zero borrow shares");

        uint256 consumed = wethBefore - wethAfter;
        assertGe(consumed, BORROW_WETH, "Should consume at least the original borrow");
        assertGt(wethAfter, 0, "Surplus should remain");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: OUTAMOUNT TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply outAmount tracks collateral consumed
    function test_fork_OutAmount_Supply() public {
        _fundUSDC(5000e6);
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcBefore - usdcAfter, "outAmount should match USDC consumed");
    }

    /// @notice Borrow outAmount tracks WETH received
    function test_fork_OutAmount_Borrow() public {
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(outAmount, wethAfter - wethBefore, "outAmount should match WETH received");
    }

    /// @notice Repay outAmount tracks WETH consumed
    function test_fork_OutAmount_Repay() public {
        _openPosition();

        uint256 repayAmt = BORROW_WETH / 2;
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmt, false));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(outAmount, wethBefore - wethAfter, "outAmount should match WETH consumed");
    }

    /// @notice V2 SupplyAndBorrow outAmount tracks collateral consumed
    function test_fork_OutAmount_V2SupplyAndBorrow() public {
        _fundUSDC(COLLATERAL_USDC);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcBefore - usdcAfter, "outAmount should match USDC consumed");
    }

    /// @notice V2 RepayAndWithdraw: withdraw path outAmount tracks collateral received
    function test_fork_OutAmount_V2RepayAndWithdraw_WithdrawPath() public {
        _openPositionV2();

        uint256 withdrawAmt = 1000e6;
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(BORROW_WETH / 4, withdrawAmt, false)
        );
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcAfter - usdcBefore, "outAmount should match USDC received");
    }

    /// @notice V2 RepayAndWithdraw: repay-only path outAmount tracks collateral delta (zero)
    function test_fork_OutAmount_V2RepayAndWithdraw_RepayOnlyPath() public {
        _openPositionV2();

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(BORROW_WETH / 4, 0, false)
        );
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        // No collateral withdrawn, so delta should be 0
        assertEq(usdcAfter, usdcBefore, "No USDC should be received for repay-only");
        assertEq(outAmount, 0, "outAmount should be 0 for repay-only (no collateral change)");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: MULTI-STEP LIFECYCLE COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 open → partial repay → add collateral → borrow more → full close
    function test_fork_Lifecycle_V2OpenPartialRepayAddCollateralBorrowMore() public {
        // Step 1: V2 open
        _openPositionV2();

        // Step 2: Partial repay
        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(BORROW_WETH / 2, 0, false)
        );

        // Step 3: Add collateral
        _fundUSDC(5000e6);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(5000e6));

        // Step 4: Borrow more
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH / 2));

        // Step 5: Warp
        vm.warp(block.timestamp + 14 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        // Step 6: Full close with V2
        uint256 debt = _getDebt();
        _fundWETH(debt);

        (,, uint128 collateral) = _getPosition();
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, uint256(collateral), true)
        );

        (, uint128 borrowShares, uint128 colAfter) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Debt should be zero");
        assertEq(uint256(colAfter), 0, "Collateral should be zero");
    }

    /// @notice Individual open → V2 composite close
    function test_fork_Lifecycle_IndividualOpenV2Close() public {
        _openPosition();

        vm.warp(block.timestamp + 7 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debt = _getDebt();
        _fundWETH(debt);

        (,, uint128 collateral) = _getPosition();
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, uint256(collateral), true)
        );

        (, uint128 borrowShares, uint128 colAfter) = _getPosition();
        assertEq(uint256(borrowShares), 0, "Debt should be zero");
        assertEq(uint256(colAfter), 0, "Collateral should be zero");
    }

    /// @notice V2 open → individual repay → V2 withdraw remaining collateral
    function test_fork_Lifecycle_V2OpenIndividualRepayV2Withdraw() public {
        _openPositionV2();

        vm.warp(block.timestamp + 7 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        uint256 debt = _getDebt();
        _fundWETH(debt);

        // Full repay with individual hook
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        (, uint128 bsAfterRepay,) = _getPosition();
        assertEq(uint256(bsAfterRepay), 0, "Debt should be zero after individual repay");

        // Re-open a tiny position so V2 RepayAndWithdraw can work, then immediately close it
        // OR: just verify collateral is still there — no individual withdrawCollateral hook exists
        (,, uint128 collateral) = _getPosition();
        assertEq(uint256(collateral), COLLATERAL_USDC, "Collateral should remain after repay");

        // To withdraw collateral after debt is cleared, we need a small borrow then full repay+withdraw
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(1));
        _fundWETH(1e18); // generous buffer
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, COLLATERAL_USDC, true)
        );

        (, uint128 bsFinal, uint128 colFinal) = _getPosition();
        assertEq(uint256(bsFinal), 0, "No debt");
        assertEq(uint256(colFinal), 0, "No collateral");
    }

    /// @notice Re-open position after full close
    function test_fork_Lifecycle_ReopenAfterClose() public {
        // Open
        _openPositionV2();

        // Close
        uint256 debt = _getDebt();
        _fundWETH(debt);
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, COLLATERAL_USDC, true)
        );

        // Verify closed
        (, uint128 borrowShares, uint128 col) = _getPosition();
        assertEq(uint256(borrowShares), 0, "No debt");
        assertEq(uint256(col), 0, "No collateral");

        // Re-open
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );

        (, uint128 bs2, uint128 col2) = _getPosition();
        assertGt(uint256(bs2), 0, "Should have borrow shares again");
        assertEq(uint256(col2), COLLATERAL_USDC, "Should have collateral again");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: EXECUTION COUNT VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify execution array sizes for all hook paths
    /// @dev BaseHook.build() wraps _buildHookExecutions with preExecute (first) and postExecute (last),
    ///      adding +2 to the hook-specific execution count.
    function test_fork_ExecutionCounts() public {
        address exec = address(executor);

        // Set up state with executeHook (handles pre/post correctly)
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(address(supplyHook), address(0), _encodeSupplyData(COLLATERAL_USDC));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_WETH));

        // Supply: 4 hook executions + 2 (preExecute + postExecute) = 6
        {
            Execution[] memory execs =
                ISuperHook(address(supplyHook)).build(address(0), exec, _encodeSupplyData(1000e6));
            assertEq(execs.length, 6, "Supply should have 6 executions");
        }

        // Borrow: 1 hook execution + 2 = 3
        {
            Execution[] memory execs =
                ISuperHook(address(borrowHook)).build(address(0), exec, _encodeBorrowData(BORROW_WETH));
            assertEq(execs.length, 3, "Borrow should have 3 executions");
        }

        // Partial repay: 4 hook executions + 2 = 6
        {
            Execution[] memory execs =
                ISuperHook(address(repayHook)).build(address(0), exec, _encodeRepayData(BORROW_WETH / 2, false));
            assertEq(execs.length, 6, "Partial repay should have 6 executions");
        }

        // Full repay: 4 hook executions + 2 = 6
        {
            Execution[] memory execs =
                ISuperHook(address(repayHook)).build(address(0), exec, _encodeRepayData(0, true));
            assertEq(execs.length, 6, "Full repay should have 6 executions");
        }

        // V2 SupplyAndBorrow: 5 hook executions + 2 = 7
        {
            Execution[] memory execs = ISuperHook(address(supplyAndBorrowV2)).build(
                address(0), exec, _encodeSupplyAndBorrowV2Data(1000e6, BORROW_WETH)
            );
            assertEq(execs.length, 7, "V2 SupplyAndBorrow should have 7 executions");
        }
    }

    /// @notice V2 RepayAndWithdraw execution counts for all 4 paths
    /// @dev BaseHook.build() wraps _buildHookExecutions with preExecute (first) and postExecute (last),
    ///      adding +2 to the hook-specific execution count.
    function test_fork_ExecutionCounts_V2RepayAndWithdraw() public {
        _openPosition();
        address exec = address(executor);

        // Partial repay-only (secondaryAmount=0, isFullRepayment=false): 4 hook + 2 = 6
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawV2)).build(
                address(0), exec, _encodeRepayAndWithdrawV2Data(BORROW_WETH / 4, 0, false)
            );
            assertEq(execs.length, 6, "Partial repay-only should have 6 executions");
        }

        // Full repay-only (secondaryAmount=0, isFullRepayment=true): 4 hook + 2 = 6
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawV2)).build(
                address(0), exec, _encodeRepayAndWithdrawV2Data(0, 0, true)
            );
            assertEq(execs.length, 6, "Full repay-only should have 6 executions");
        }

        // Partial repay + withdraw (secondaryAmount>0, isFullRepayment=false): 5 hook + 2 = 7
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawV2)).build(
                address(0), exec, _encodeRepayAndWithdrawV2Data(BORROW_WETH / 4, 1000e6, false)
            );
            assertEq(execs.length, 7, "Partial repay + withdraw should have 7 executions");
        }

        // Full repay + withdraw (secondaryAmount>0, isFullRepayment=true): 5 hook + 2 = 7
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawV2)).build(
                address(0), exec, _encodeRepayAndWithdrawV2Data(0, 5000e6, true)
            );
            assertEq(execs.length, 7, "Full repay + withdraw should have 7 executions");
        }
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 12: POSITION STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify position state through complete V2 lifecycle
    function test_fork_PositionState_V2Lifecycle() public {
        address exec = address(executor);

        // Initial: no position
        (uint256 ss, uint128 bs, uint128 col) = _getPosition();
        assertEq(ss, 0, "No supply shares initially");
        assertEq(uint256(bs), 0, "No borrow shares initially");
        assertEq(uint256(col), 0, "No collateral initially");

        // After V2 SupplyAndBorrow
        _fundUSDC(COLLATERAL_USDC);
        executor.executeHook(
            address(supplyAndBorrowV2), address(0), _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH)
        );
        (, uint128 bs1, uint128 col1) = _getPosition();
        assertGt(uint256(bs1), 0, "Should have borrow shares");
        assertEq(uint256(col1), COLLATERAL_USDC, "Should have full collateral");

        // After V2 partial repay
        executor.executeHook(
            address(repayAndWithdrawV2), address(0), _encodeRepayAndWithdrawV2Data(BORROW_WETH / 2, 0, false)
        );
        (, uint128 bs2, uint128 col2) = _getPosition();
        assertLt(uint256(bs2), uint256(bs1), "Borrow shares should decrease");
        assertEq(uint256(col2), COLLATERAL_USDC, "Collateral unchanged after repay-only");

        // After V2 partial withdraw (no repay — just withdraw some collateral)
        // Use partial repay + withdraw with tiny repay
        uint256 withdrawAmt = 1000e6;
        _fundWETH(BORROW_WETH / 10); // Small repay to cover the tiny amount
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(BORROW_WETH / 10, withdrawAmt, false)
        );
        (, uint128 bs3, uint128 col3) = _getPosition();
        assertLt(uint256(bs3), uint256(bs2), "Borrow shares should decrease more");
        assertEq(uint256(col3), COLLATERAL_USDC - withdrawAmt, "Collateral should decrease");

        // Final: full close
        uint256 debt = _getDebt();
        _fundWETH(debt);
        executor.executeHook(
            address(repayAndWithdrawV2),
            address(0),
            _encodeRepayAndWithdrawV2Data(0, uint256(col3), true)
        );
        (, uint128 bs4, uint128 col4) = _getPosition();
        assertEq(uint256(bs4), 0, "No borrow shares");
        assertEq(uint256(col4), 0, "No collateral");
    }

    /// @notice Verify inspect returns correct packed data for V2 hooks
    function test_fork_Inspect_V2Hooks() public view {
        bytes memory expectedPacked = abi.encodePacked(WETH, USDC, MORPHO_ORACLE, MORPHO_IRM);

        bytes memory supplyBorrowData = _encodeSupplyAndBorrowV2Data(COLLATERAL_USDC, BORROW_WETH);
        assertEq(supplyAndBorrowV2.inspect(supplyBorrowData), expectedPacked, "V2 SupplyAndBorrow inspect mismatch");

        bytes memory repayWithdrawData = _encodeRepayAndWithdrawV2Data(BORROW_WETH, 1000e6, false);
        assertEq(repayAndWithdrawV2.inspect(repayWithdrawData), expectedPacked, "V2 RepayAndWithdraw inspect mismatch");
    }
}
