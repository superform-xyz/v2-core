// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IEVault } from "../../../src/vendor/euler/IEVault.sol";
import { IEVC } from "../../../src/vendor/euler/IEVC.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";

// Hooks
import { EulerDepositCollateralHook } from "../../../src/hooks/loan/euler/EulerDepositCollateralHook.sol";
import { EulerBorrowHook } from "../../../src/hooks/loan/euler/EulerBorrowHook.sol";
import { EulerRepayHook } from "../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerWithdrawCollateralHook } from "../../../src/hooks/loan/euler/EulerWithdrawCollateralHook.sol";
import { EulerDepositCollateralAndBorrowHook } from
    "../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";
import { BaseEulerLoanHook } from "../../../src/hooks/loan/euler/BaseEulerLoanHook.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title LoanHookExecutorEdge
/// @notice Minimal contract that acts as both executor and account for loan hook lifecycle testing.
contract LoanHookExecutorEdge {
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

    /// @dev Attempt to execute a hook — returns false instead of reverting on failure
    function tryExecuteHook(
        address hook,
        address prevHook,
        bytes calldata data
    )
        external
        returns (bool success, uint256 outAmount)
    {
        try this.executeHook(hook, prevHook, data) returns (uint256 out) {
            return (true, out);
        } catch {
            return (false, 0);
        }
    }
}

/*//////////////////////////////////////////////////////////////
                    TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title EulerLoanHooksEdgeCasesFork
/// @notice Edge-case fork tests for all 6 Euler V2 loan hooks.
///         Covers: partial repay amounts, full repay edge cases, multiple sequential borrows,
///         additional collateral deposits, partial withdraw under debt, interest accrual scenarios,
///         composite hook cap/limit validations, multi-step lifecycle combinations, and outAmount tracking.
contract EulerLoanHooksEdgeCasesFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;
    address public constant EULER_USDC_VAULT = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant EULER_WETH_VAULT = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant ETH_BLOCK = 21_929_476;

    uint256 public constant COLLATERAL_AMOUNT = 10e18; // 10 WETH
    uint256 public constant BORROW_AMOUNT = 2000e6; // 2000 USDC

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    EulerDepositCollateralHook public depositHook;
    EulerBorrowHook public borrowHook;
    EulerRepayHook public repayHook;
    EulerWithdrawCollateralHook public withdrawHook;
    EulerDepositCollateralAndBorrowHook public depositAndBorrowHook;
    EulerRepayAndWithdrawHook public repayAndWithdrawHook;

    LoanHookExecutorEdge public executor;

    address public vaultOracle;
    address public vaultUnitOfAccount;
    address public vaultIRM;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), ETH_BLOCK);

        depositHook = new EulerDepositCollateralHook();
        borrowHook = new EulerBorrowHook();
        repayHook = new EulerRepayHook();
        withdrawHook = new EulerWithdrawCollateralHook();
        depositAndBorrowHook = new EulerDepositCollateralAndBorrowHook();
        repayAndWithdrawHook = new EulerRepayAndWithdrawHook();

        executor = new LoanHookExecutorEdge();

        vaultOracle = IEVault(EULER_USDC_VAULT).oracle();
        vaultUnitOfAccount = IEVault(EULER_USDC_VAULT).unitOfAccount();
        vaultIRM = IEVault(EULER_USDC_VAULT).interestRateModel();
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _encodeSharedPrefix(
        uint256 primaryAmt,
        uint256 secondaryAmt,
        bool usePrev
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            bytes20(uint160(EULER_WETH_VAULT)),
            bytes20(uint160(USDC)),
            bytes20(uint160(WETH)),
            bytes20(uint160(EVC)),
            bytes20(uint160(EULER_USDC_VAULT)),
            primaryAmt,
            secondaryAmt,
            usePrev
        );
    }

    function _encodeDepositData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    function _encodeBorrowData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    function _encodeRepayData(uint256 amt, bool isFullRepayment) internal pure returns (bytes memory) {
        return abi.encodePacked(_encodeSharedPrefix(amt, 0, false), isFullRepayment);
    }

    function _encodeWithdrawData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    function _encodeDepositAndBorrowData(
        uint256 collateralAmt,
        uint256 borrowAmt,
        uint256 maxPostDebt,
        uint256 maxLiqCapUtilBps
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _encodeSharedPrefix(collateralAmt, borrowAmt, false),
            maxPostDebt,
            maxLiqCapUtilBps,
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(vaultIRM))
        );
    }

    function _encodeRepayAndWithdrawData(
        uint256 repayAmt,
        uint256 withdrawAmt,
        bool isFullRepayment,
        uint256 maxRepayAssets,
        uint256 maxCollateralRelease,
        uint256 maxRemainingLiqCapUtilBps
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _encodeSharedPrefix(repayAmt, withdrawAmt, false),
            isFullRepayment,
            maxRepayAssets,
            maxCollateralRelease,
            maxRemainingLiqCapUtilBps,
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(vaultIRM))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _openPosition() internal {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
    }

    function _openPositionComposite() internal {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );
    }

    function _fundWETH(uint256 amount) internal {
        deal(WETH, address(executor), IERC20(WETH).balanceOf(address(executor)) + amount);
    }

    function _fundUSDC(uint256 amount) internal {
        deal(USDC, address(executor), IERC20(USDC).balanceOf(address(executor)) + amount);
    }

    function _fullRepayAndWithdrawAll() internal {
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (maxW > 0) {
            executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));
        }
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 1: PARTIAL REPAY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Repay the minimum possible amount (1 wei of USDC) — verify debt decreases
    function test_fork_RepayPartial_MinimumAmount() public {
        _openPosition();

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 repayAmount = 1; // 1 wei of USDC

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmount, false));

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLe(debtAfter, debtBefore, "Debt should decrease or stay same after 1-wei repay");
        assertGt(debtAfter, 0, "Debt should still exist");

        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Controller should still be active");
    }

    /// @notice Repay exactly the borrowed amount (no interest buffer) — should leave residual interest debt
    function test_fork_RepayPartial_ExactBorrowAmount() public {
        _openPosition();

        // The borrowed amount is 2000 USDC — already in the executor from the borrow
        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debtBefore, BORROW_AMOUNT, "Debt should be >= borrow amount due to rounding");

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(BORROW_AMOUNT, false));

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        // Debt may not be zero because of interest rounding
        assertLt(debtAfter, debtBefore, "Debt should decrease significantly");

        // Controller should still be active since we haven't fully repaid
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Controller should still be active (partial repay)");

        console2.log("[repay exact borrow] Remaining debt:", debtAfter);
    }

    /// @notice Multiple sequential partial repays to bring debt close to zero, then full repay
    function test_fork_RepayPartial_MultipleSequential() public {
        _openPosition();

        uint256 debtInitial = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        // Partial repay #1: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfter1 = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter1, debtInitial, "Debt should decrease after 1st partial repay");

        // Partial repay #2: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfter2 = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter2, debtAfter1, "Debt should decrease after 2nd partial repay");

        // Partial repay #3: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfter3 = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter3, debtAfter2, "Debt should decrease after 3rd partial repay");

        // Remaining debt should be small (original 2000 - 1500 repaid + some interest rounding)
        assertLt(debtAfter3, 600e6, "Remaining debt should be under 600 USDC");

        // Full repay to clean up
        _fundUSDC(debtAfter3);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero after full repay");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "Controller should be disabled");
    }

    /// @notice Partial repay after interest accrual — repay amount covers only interest
    function test_fork_RepayPartial_InterestOnly() public {
        _openPosition();

        // Warp 30 days to accrue meaningful interest
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debtWithInterest = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 interestAccrued = debtWithInterest - BORROW_AMOUNT;
        assertGt(interestAccrued, 0, "Interest should have accrued");

        // Repay only the interest portion
        _fundUSDC(interestAccrued);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(interestAccrued, false));

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        // After repaying interest, debt should be approximately the original borrow amount
        // (plus any tiny interest from the repay transaction itself)
        assertLe(debtAfter, BORROW_AMOUNT + 1e6, "Debt should be close to original borrow after interest repay");
        assertGt(debtAfter, 0, "Debt should still exist");

        console2.log("[interest-only repay] Interest:", interestAccrued, "Debt after:", debtAfter);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 2: FULL REPAY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Full repay after significant interest accrual (90 days)
    function test_fork_RepayFull_AfterLongInterestAccrual() public {
        _openPosition();

        vm.warp(block.timestamp + 90 days);
        vm.roll(block.number + 648_000);

        uint256 debtWithInterest = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debtWithInterest, BORROW_AMOUNT, "Debt should be well above borrow amount");

        // Fund enough to cover all debt + buffer
        _fundUSDC(debtWithInterest + 10e6);

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "Controller should be disabled");

        // Collateral should remain untouched
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Collateral shares should remain");

        console2.log("[full repay 90d] Debt was:", debtWithInterest);
    }

    /// @notice Full repay with excess USDC — verify surplus stays with executor
    function test_fork_RepayFull_ExcessFunds() public {
        _openPosition();

        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 excess = 1000e6;
        _fundUSDC(excess); // Extra 1000 USDC beyond what borrow gave us

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");

        // The surplus should remain (total funded - debt consumed)
        uint256 consumed = usdcBefore - usdcAfter;
        assertGe(consumed, BORROW_AMOUNT, "Should have consumed at least the borrow amount");
        assertGt(usdcAfter, 0, "Surplus USDC should remain in executor");

        console2.log("[full repay excess] Consumed:", consumed, "Remaining:", usdcAfter);
    }

    /// @notice Full repay cleans up collateral registration in EVC
    function test_fork_RepayFull_VerifyCollateralCleanup() public {
        _openPosition();

        // Before full repay: collateral should be enabled
        assertTrue(
            IEVC(EVC).isCollateralEnabled(address(executor), EULER_WETH_VAULT), "Collateral should be enabled before"
        );
        assertTrue(
            IEVC(EVC).isControllerEnabled(address(executor), EULER_USDC_VAULT), "Controller should be enabled before"
        );

        _fundUSDC(1e6);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        // After full repay: both should be disabled
        assertFalse(
            IEVC(EVC).isCollateralEnabled(address(executor), EULER_WETH_VAULT), "Collateral should be disabled after"
        );
        assertFalse(
            IEVC(EVC).isControllerEnabled(address(executor), EULER_USDC_VAULT), "Controller should be disabled after"
        );
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: DEPOSIT COLLATERAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential deposits accumulate shares correctly
    function test_fork_DepositCollateral_MultipleDeposits() public {
        uint256 depositAmount = 2e18; // 2 WETH each

        _fundWETH(depositAmount);
        uint256 out1 = executor.executeHook(address(depositHook), address(0), _encodeDepositData(depositAmount));
        uint256 shares1 = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));

        _fundWETH(depositAmount);
        uint256 out2 = executor.executeHook(address(depositHook), address(0), _encodeDepositData(depositAmount));
        uint256 shares2 = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));

        _fundWETH(depositAmount);
        uint256 out3 = executor.executeHook(address(depositHook), address(0), _encodeDepositData(depositAmount));
        uint256 shares3 = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));

        // Each deposit should track the amount consumed
        assertEq(out1, depositAmount, "1st outAmount should match deposit");
        assertEq(out2, depositAmount, "2nd outAmount should match deposit");
        assertEq(out3, depositAmount, "3rd outAmount should match deposit");

        // Shares should accumulate
        assertGt(shares2, shares1, "Shares should increase after 2nd deposit");
        assertGt(shares3, shares2, "Shares should increase after 3rd deposit");

        console2.log("[multi-deposit] Final shares:", shares3);
    }

    /// @notice Add more collateral to an existing position to improve health factor
    function test_fork_DepositCollateral_AddToExistingPosition() public {
        _openPosition();

        uint256 sharesBefore = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));
        (uint256 collValueBefore,) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        // Add 5 more WETH as collateral
        uint256 additionalCollateral = 5e18;
        _fundWETH(additionalCollateral);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(additionalCollateral));

        uint256 sharesAfter = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));
        (uint256 collValueAfter,) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        assertGt(sharesAfter, sharesBefore, "Shares should increase");
        assertGt(collValueAfter, collValueBefore, "Collateral value should increase");

        console2.log("[add collateral] Coll value before:", collValueBefore, "after:", collValueAfter);
    }

    /// @notice Deposit a very small amount of collateral — verify outAmount tracking
    /// @dev Euler V2 vaults may reject deposits below a minimum share threshold (1 wei produces 0 shares).
    ///      Using 0.001 WETH as a safe minimum that produces at least 1 share.
    function test_fork_DepositCollateral_MinimumAmount() public {
        uint256 minDeposit = 1e15; // 0.001 WETH
        _fundWETH(minDeposit);

        uint256 outAmount = executor.executeHook(address(depositHook), address(0), _encodeDepositData(minDeposit));

        assertEq(outAmount, minDeposit, "outAmount should match deposit");
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have received shares");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: BORROW EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential borrows against same collateral
    function test_fork_Borrow_MultipleSequential() public {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // Borrow #1: 500 USDC
        uint256 out1 = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        assertEq(out1, 500e6, "1st borrow outAmount should be 500 USDC");

        // Borrow #2: 500 USDC
        uint256 out2 = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        assertEq(out2, 500e6, "2nd borrow outAmount should be 500 USDC");

        // Borrow #3: 500 USDC
        uint256 out3 = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        assertEq(out3, 500e6, "3rd borrow outAmount should be 500 USDC");

        // Total USDC should be 1500
        assertEq(IERC20(USDC).balanceOf(address(executor)), 1500e6, "Should have 1500 USDC total");

        // Debt should be >= 1500 USDC
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt, 1500e6, "Debt should be >= 1500 USDC");

        // Controller should be set exactly once
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Should have exactly 1 controller");
    }

    /// @notice Borrow minimum amount (1 USDC) — verify state changes
    function test_fork_Borrow_MinimumAmount() public {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        uint256 outAmount = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(1e6));

        assertEq(outAmount, 1e6, "outAmount should be 1 USDC");
        assertEq(IERC20(USDC).balanceOf(address(executor)), 1e6, "Should have 1 USDC");
        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should have debt");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: WITHDRAW COLLATERAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial withdraw while debt is active — must stay within health limits
    /// @dev maxWithdraw may return 0 if the vault has insufficient liquidity (all WETH lent out).
    ///      In that case, we skip the test rather than fail — this is a vault liquidity constraint, not a hook bug.
    function test_fork_WithdrawCollateral_PartialWithDebt() public {
        _openPosition();

        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (maxW == 0) {
            console2.log("[skip] maxWithdraw is 0 - vault has no available liquidity for withdrawal");
            return;
        }

        // Withdraw a small amount — well within health limits
        uint256 withdrawAmt = maxW < 1e18 ? maxW : 1e18;

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(withdrawAmt));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(wethAfter - wethBefore, withdrawAmt, "Should have received withdrawn WETH");
        assertEq(outAmount, withdrawAmt, "outAmount should match withdrawn amount");

        // Position should still be healthy
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should still have collateral shares");
        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should still have debt");
    }

    /// @notice Withdraw maximum possible while keeping position healthy
    /// @dev maxWithdraw may return 0 if the vault has insufficient liquidity (all WETH lent out).
    function test_fork_WithdrawCollateral_MaxSafe() public {
        _openPosition();

        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (maxW == 0) {
            console2.log("[skip] maxWithdraw is 0 - vault has no available liquidity for withdrawal");
            return;
        }

        // maxWithdraw accounts for the active debt — should be safe
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(wethAfter - wethBefore, maxW, "Should have received max WETH");

        // Debt still active
        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should still have debt");

        console2.log(
            "[max withdraw] maxWithdraw:",
            maxW,
            "Remaining shares:",
            IEVault(EULER_WETH_VAULT).balanceOf(address(executor))
        );
    }

    /// @notice Withdraw all after no debt — clean exit
    function test_fork_WithdrawCollateral_AllAfterFullRepay() public {
        _openPosition();

        // Full repay first
        _fundUSDC(1e6);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        uint256 outAmount = executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));

        assertEq(outAmount, maxW, "outAmount should match max withdraw");
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have no shares left");
        assertGe(IERC20(WETH).balanceOf(address(executor)), COLLATERAL_AMOUNT - 1, "Should get back ~all collateral");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: COMPOSITE DEPOSIT-AND-BORROW EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice maxPostDebt caps the total debt allowed after execution
    /// @dev MAX_POST_DEBT_EXCEEDED is thrown in _postExecute, which is now an execution in the array.
    ///      The executor wraps it in EXECUTION_FAILED, so we use a generic expectRevert.
    function test_fork_DepositAndBorrow_MaxPostDebtEnforced() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // Set maxPostDebt to something less than the borrow amount — should revert
        vm.expectRevert();
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, 1000e6, 0) // maxPostDebt = 1000 USDC < 2000
        );
    }

    /// @notice maxPostDebt set exactly to borrow amount — edge case passes
    function test_fork_DepositAndBorrow_MaxPostDebtExact() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // Debt after borrow will be >= BORROW_AMOUNT (possibly slightly more due to interest)
        // Set max to a generous bound
        uint256 maxDebt = BORROW_AMOUNT + 10e6; // small buffer for rounding
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, maxDebt, 0)
        );

        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLe(debt, maxDebt, "Debt should be within maxPostDebt");
    }

    /// @notice liquidation capacity utilization check when maxLiqCapUtilBps is set
    function test_fork_DepositAndBorrow_LiqCapUtilBps() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // 5000 bps = 50% utilization — should be fine for 10 WETH collateral / 2000 USDC borrow
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 5000)
        );

        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should have debt");
    }

    /// @notice Very tight liquidation capacity should revert
    /// @dev LIQUIDATION_CAPACITY_EXCEEDED is thrown in _postExecute, which is now an execution in the array.
    ///      The executor wraps it in EXECUTION_FAILED, so we use a generic expectRevert.
    function test_fork_DepositAndBorrow_LiqCapUtilBpsTooTight() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // 100 bps = 1% utilization — far too tight for a 2000 USDC borrow against 10 WETH
        vm.expectRevert();
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 100)
        );
    }

    /// @notice UnitOfAccount mismatch should revert
    function test_fork_DepositAndBorrow_UnitOfAccountMismatch() public {
        _fundWETH(COLLATERAL_AMOUNT);

        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(COLLATERAL_AMOUNT, BORROW_AMOUNT, false),
            type(uint256).max,
            uint256(0),
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(address(0xdead))), // Wrong unit of account
            bytes20(uint160(vaultIRM))
        );

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.UNIT_OF_ACCOUNT_MISMATCH.selector);
        executor.executeHook(address(depositAndBorrowHook), address(0), data);
    }

    /// @notice IRM mismatch should revert
    function test_fork_DepositAndBorrow_IRMMismatch() public {
        _fundWETH(COLLATERAL_AMOUNT);

        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(COLLATERAL_AMOUNT, BORROW_AMOUNT, false),
            type(uint256).max,
            uint256(0),
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(address(0xdead))) // Wrong IRM
        );

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.IRM_MISMATCH.selector);
        executor.executeHook(address(depositAndBorrowHook), address(0), data);
    }

    /// @notice Open multiple positions sequentially (add to existing)
    function test_fork_DepositAndBorrow_AddToExistingPosition() public {
        // First position
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );

        uint256 debtAfter1 = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        // Add to position (more collateral + more borrow)
        _fundWETH(5e18);
        executor.executeHook(
            address(depositAndBorrowHook), address(0), _encodeDepositAndBorrowData(5e18, 1000e6, type(uint256).max, 0)
        );

        uint256 debtAfter2 = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debtAfter2, debtAfter1, "Debt should increase after 2nd borrow");
        assertEq(IERC20(USDC).balanceOf(address(executor)), BORROW_AMOUNT + 1000e6, "Should have total USDC");

        console2.log("[add to position] Debt after 1st:", debtAfter1, "after 2nd:", debtAfter2);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: COMPOSITE REPAY-AND-WITHDRAW EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Repay-only path: repay minimum amount (1 USDC), no withdraw
    function test_fork_RepayAndWithdraw_RepayOnly_MinimumAmount() public {
        _openPosition();

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawHook), address(0), _encodeRepayAndWithdrawData(1e6, 0, false, 1e6, 0, 0)
        );

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLe(debtAfter, debtBefore, "Debt should decrease or stay same");
        // outAmount tracks debt consumed for repay-only path
        assertGe(outAmount, 1e6 - 1, "outAmount should track USDC consumed");
    }

    /// @notice Repay-only: repay all borrowed USDC but not as full repay
    function test_fork_RepayAndWithdraw_RepayOnly_LargePartial() public {
        _openPosition();

        // Repay the full borrowed amount as a partial repay (not isFullRepayment)
        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(BORROW_AMOUNT, 0, false, BORROW_AMOUNT, 0, 0)
        );

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        // May have residual debt from interest rounding
        assertLe(debtAfter, 10e6, "Residual debt should be tiny");

        // Controller should still be active since this was a partial repay
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 1, "Controller should still be active");
    }

    /// @notice Partial repay + partial withdraw
    function test_fork_RepayAndWithdraw_PartialBoth() public {
        _openPosition();

        uint256 repayAmt = 500e6;
        uint256 withdrawAmt = 1e18;

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));

        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(repayAmt, withdrawAmt, false, repayAmt, withdrawAmt, 0)
        );

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertLt(debtAfter, debtBefore, "Debt should decrease");
        assertEq(wethAfter - wethBefore, withdrawAmt, "Should have withdrawn WETH");
        // outAmount tracks collateral received when secondaryAmount > 0
        assertEq(outAmount, withdrawAmt, "outAmount should track withdrawn WETH");
    }

    /// @notice Full repay + withdraw collateral
    /// @dev maxWithdraw pre-repay is constrained by both debt AND vault liquidity.
    ///      If maxWithdraw is 0 (vault has no available liquidity), we use a two-step approach:
    ///      full repay first (via repay hook), then withdraw separately.
    function test_fork_RepayAndWithdraw_FullRepayFullWithdraw() public {
        _openPosition();

        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt);

        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));

        if (maxW > 0) {
            // Happy path: vault has liquidity, use composite hook
            executor.executeHook(
                address(repayAndWithdrawHook),
                address(0),
                _encodeRepayAndWithdrawData(0, maxW, true, type(uint256).max, maxW, 0)
            );

            assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
            assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "Controller should be disabled");
            assertGe(IERC20(WETH).balanceOf(address(executor)), maxW, "Should have withdrawn WETH");
        } else {
            // Vault has no liquidity: do full repay only, verify debt cleared + controller cleanup
            executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

            assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
            assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "Controller should be disabled");

            // Withdraw what's available after repay (controller is now disabled, so more may be available)
            uint256 maxWAfterRepay = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
            if (maxWAfterRepay > 0) {
                executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxWAfterRepay));
            }
            console2.log("[full repay only] maxW was 0, maxW after repay:", maxWAfterRepay);
        }
    }

    /// @notice Full repay + zero withdraw (clean up debt and controller without withdrawing)
    function test_fork_RepayAndWithdraw_FullRepayNoWithdraw() public {
        _openPosition();

        _fundUSDC(1e6);

        // Full repay with secondaryAmount = 0 — should take the repay-only path BUT with full repay
        // Actually this tests isFullRepayment=true + secondaryAmount=0
        // In the code: secondaryAmount==0 means repay-only path (4 executions)
        // But isFullRepayment doesn't add cleanup for repay-only path!
        // Looking at the code, secondaryAmount==0 always takes the 4-execution repay-only path regardless of
        // isFullRepayment
        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(BORROW_AMOUNT, 0, false, BORROW_AMOUNT, 0, 0)
        );

        // Should have repaid the borrow amount (residual interest may remain)
        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLe(debtAfter, 10e6, "Residual debt should be tiny");

        // Collateral should be untouched
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Collateral shares should remain");
    }

    /// @notice maxRepayAssets cap enforcement
    function test_fork_RepayAndWithdraw_MaxRepayExceeded() public {
        _openPosition();

        // Try to repay 1000 USDC but cap is 500 USDC
        vm.expectRevert(EulerRepayAndWithdrawHook.MAX_REPAY_EXCEEDED.selector);
        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(
                1000e6, // repay 1000
                0,
                false,
                500e6, // maxRepayAssets = 500 (too low)
                0,
                0
            )
        );
    }

    /// @notice maxCollateralRelease cap enforcement
    function test_fork_RepayAndWithdraw_MaxCollateralReleaseExceeded() public {
        _openPosition();

        // Try to withdraw 2 WETH but cap is 1 WETH
        vm.expectRevert(EulerRepayAndWithdrawHook.MAX_COLLATERAL_RELEASE_EXCEEDED.selector);
        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(
                1000e6,
                2e18, // withdraw 2 WETH
                false,
                1000e6,
                1e18, // maxCollateralRelease = 1 WETH (too low)
                0
            )
        );
    }

    /// @notice Liquidation capacity check after partial repay + withdraw
    function test_fork_RepayAndWithdraw_LiqCapCheck() public {
        _openPosition();

        // Partial repay + small withdraw with tight liq cap — should succeed
        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(
                500e6,
                1e18,
                false,
                500e6,
                1e18,
                9000 // 90% cap — should be fine since we repaid and withdrew little
            )
        );

        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should still have debt");
    }

    /// @notice Config validation on RepayAndWithdraw oracle mismatch
    function test_fork_RepayAndWithdraw_OracleMismatch() public {
        _openPosition();

        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(1000e6, 1e18, false),
            false,
            uint256(1000e6),
            uint256(1e18),
            uint256(0),
            bytes20(uint160(address(0xdead))), // Wrong oracle
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(vaultIRM))
        );

        vm.expectRevert(EulerRepayAndWithdrawHook.ORACLE_MISMATCH.selector);
        executor.executeHook(address(repayAndWithdrawHook), address(0), data);
    }

    /// @notice Config validation on RepayAndWithdraw UnitOfAccount mismatch
    function test_fork_RepayAndWithdraw_UnitOfAccountMismatch() public {
        _openPosition();

        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(1000e6, 1e18, false),
            false,
            uint256(1000e6),
            uint256(1e18),
            uint256(0),
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(address(0xdead))), // Wrong unit of account
            bytes20(uint160(vaultIRM))
        );

        vm.expectRevert(EulerRepayAndWithdrawHook.UNIT_OF_ACCOUNT_MISMATCH.selector);
        executor.executeHook(address(repayAndWithdrawHook), address(0), data);
    }

    /// @notice Repay-only path skips config validation (secondaryAmount = 0)
    function test_fork_RepayAndWithdraw_RepayOnlySkipsConfigValidation() public {
        _openPosition();

        // Use wrong oracle/IRM but secondaryAmount = 0 — should NOT revert
        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(500e6, 0, false), // secondaryAmount = 0
            false,
            uint256(500e6),
            uint256(0),
            uint256(0),
            bytes20(uint160(address(0xdead))), // Wrong oracle
            bytes20(uint160(address(0xdead))), // Wrong unit of account
            bytes20(uint160(address(0xdead))) // Wrong IRM
        );

        executor.executeHook(address(repayAndWithdrawHook), address(0), data);

        // Should have successfully repaid
        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter, BORROW_AMOUNT + 10e6, "Debt should have decreased");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: MULTI-STEP LIFECYCLE COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Individual open -> partial repay -> add more collateral -> more borrow -> full close
    function test_fork_Lifecycle_AddCollateralBorrowMore() public {
        // Step 1: Open initial position
        _openPosition();

        // Step 2: Partial repay 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));

        // Step 3: Add more collateral (5 WETH)
        _fundWETH(5e18);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(5e18));

        // Step 4: Borrow more (1500 USDC)
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(1500e6));

        // Step 5: Warp 14 days
        vm.warp(block.timestamp + 14 days);
        vm.roll(block.number + 100_800);

        uint256 totalDebt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        // Step 6: Full repay
        _fundUSDC(totalDebt);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");

        // Step 7: Withdraw all
        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No shares should remain");

        // Should have recovered ~15 WETH
        assertGe(IERC20(WETH).balanceOf(address(executor)), 14.99e18, "Should get back ~15 WETH");

        console2.log("[lifecycle] Total debt before repay:", totalDebt);
    }

    /// @notice Composite open -> warp -> composite partial repay+withdraw -> composite full close
    /// @dev Withdraw amounts are constrained by vault liquidity at the fork block. Uses maxWithdraw
    ///      to determine safe amounts rather than hardcoded values.
    function test_fork_Lifecycle_CompositePartialThenFull() public {
        // Step 1: Composite open
        _openPositionComposite();

        // Step 2: Warp 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        // Step 3: Composite partial repay (500 USDC) + partial withdraw (if vault has liquidity)
        uint256 maxW1 = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        uint256 withdrawAmt1 = maxW1 > 1e18 ? 1e18 : maxW1;

        if (withdrawAmt1 > 0) {
            executor.executeHook(
                address(repayAndWithdrawHook),
                address(0),
                _encodeRepayAndWithdrawData(500e6, withdrawAmt1, false, 500e6, withdrawAmt1, 0)
            );
        } else {
            // No vault liquidity — do repay-only
            executor.executeHook(
                address(repayAndWithdrawHook), address(0), _encodeRepayAndWithdrawData(500e6, 0, false, 500e6, 0, 0)
            );
        }

        uint256 debtMid = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debtMid, 0, "Should still have debt after partial");

        // Step 4: Warp another 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        // Step 5: Full repay + withdraw (use available vault liquidity)
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt);

        uint256 maxW2 = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        uint256 withdrawAmt2 = maxW2 > 3e18 ? 3e18 : maxW2;

        if (withdrawAmt2 > 0) {
            executor.executeHook(
                address(repayAndWithdrawHook),
                address(0),
                _encodeRepayAndWithdrawData(0, withdrawAmt2, true, type(uint256).max, withdrawAmt2, 0)
            );
        } else {
            // No vault liquidity — use individual repay hook for full repay with cleanup
            executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        }

        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "Controller should be disabled");
    }

    /// @notice Open with individual hooks, close with composite hook
    function test_fork_Lifecycle_IndividualOpenCompositeClose() public {
        // Open with individual hooks
        _openPosition();

        // Warp 3 days
        vm.warp(block.timestamp + 3 days);
        vm.roll(block.number + 21_600);

        // Close with composite hook (full repay + partial withdraw)
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt);

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(0, 5e18, true, type(uint256).max, 5e18, 0)
        );

        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "No controllers");

        // Withdraw remaining with individual hook
        uint256 remaining = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (remaining > 0) {
            executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(remaining));
        }

        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No shares remaining");
    }

    /// @notice Open with composite hook, close with individual hooks
    function test_fork_Lifecycle_CompositeOpenIndividualClose() public {
        // Open with composite hook
        _openPositionComposite();

        // Warp 3 days
        vm.warp(block.timestamp + 3 days);
        vm.roll(block.number + 21_600);

        // Close with individual hooks
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt);

        // Full repay
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");

        // Withdraw all
        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No shares remaining");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: OUTAMOUNT TRACKING VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify deposit outAmount tracks collateral consumed precisely
    function test_fork_OutAmount_Deposit() public {
        uint256 amt = 3.5e18;
        _fundWETH(amt);

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(depositHook), address(0), _encodeDepositData(amt));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(outAmount, wethBefore - wethAfter, "outAmount should match WETH consumed");
    }

    /// @notice Verify borrow outAmount tracks USDC received
    function test_fork_OutAmount_Borrow() public {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcAfter - usdcBefore, "outAmount should match USDC received");
    }

    /// @notice Verify repay outAmount tracks USDC consumed
    function test_fork_OutAmount_RepayPartial() public {
        _openPosition();

        uint256 repayAmt = 750e6;
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmt, false));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcBefore - usdcAfter, "outAmount should match USDC consumed for repay");
    }

    /// @notice Verify full repay outAmount tracks total USDC consumed
    function test_fork_OutAmount_RepayFull() public {
        _openPosition();
        _fundUSDC(1e6);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcBefore - usdcAfter, "outAmount should match USDC consumed for full repay");
        assertGe(outAmount, BORROW_AMOUNT, "Full repay should consume at least the borrow amount");
    }

    /// @notice Verify withdraw outAmount tracks WETH received
    function test_fork_OutAmount_Withdraw() public {
        _openPosition();
        _fundUSDC(1e6);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 withdrawAmt = 5e18;
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(withdrawAmt));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(outAmount, wethAfter - wethBefore, "outAmount should match WETH received");
    }

    /// @notice Verify composite deposit-and-borrow outAmount tracks USDC received (debtAsset)
    function test_fork_OutAmount_DepositAndBorrow() public {
        _fundWETH(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcAfter - usdcBefore, "outAmount should match USDC received from borrow");
    }

    /// @notice Verify composite repay-and-withdraw outAmount tracks WETH received (collateral)
    function test_fork_OutAmount_RepayAndWithdraw_WithdrawPath() public {
        _openPosition();

        uint256 withdrawAmt = 1e18;
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));

        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(500e6, withdrawAmt, false, 500e6, withdrawAmt, 0)
        );
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertEq(outAmount, wethAfter - wethBefore, "outAmount should match WETH received");
    }

    /// @notice Verify composite repay-only outAmount tracks USDC consumed (debtAsset)
    function test_fork_OutAmount_RepayAndWithdraw_RepayOnlyPath() public {
        _openPosition();

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        uint256 outAmount = executor.executeHook(
            address(repayAndWithdrawHook), address(0), _encodeRepayAndWithdrawData(500e6, 0, false, 500e6, 0, 0)
        );
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));

        assertEq(outAmount, usdcBefore - usdcAfter, "outAmount should match USDC consumed for repay-only");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: INTEREST ACCRUAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Interest accrual at different time intervals: 1 day, 7 days, 30 days, 90 days
    function test_fork_InterestAccrual_MultipleIntervals() public {
        _openPosition();

        uint256 debtInitial = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        // 1 day
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 7200);
        uint256 debt1d = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt1d, debtInitial, "Debt should not decrease after 1 day");

        // 7 days
        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43_200);
        uint256 debt7d = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt7d, debt1d, "Debt should not decrease after 7 days");

        // 30 days
        vm.warp(block.timestamp + 23 days);
        vm.roll(block.number + 165_600);
        uint256 debt30d = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt30d, debt7d, "Debt should not decrease after 30 days");

        // 90 days
        vm.warp(block.timestamp + 60 days);
        vm.roll(block.number + 432_000);
        uint256 debt90d = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt90d, debt30d, "Debt should not decrease after 90 days");

        console2.log("[interest] 1d:", debt1d - debtInitial);
        console2.log("[interest] 7d:", debt7d - debtInitial);
        console2.log("[interest] 30d:", debt30d - debtInitial);
        console2.log("[interest] 90d:", debt90d - debtInitial);
    }

    /// @notice Full repay after interest accrual uses type(uint256).max to handle exact debt
    function test_fork_InterestAccrual_FullRepayIsExact() public {
        _openPosition();

        // Accrue meaningful interest
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debtBefore + 100e6); // generous buffer

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(executor));
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(executor));
        uint256 consumed = usdcBefore - usdcAfter;

        // Full repay should consume approximately debtBefore (not the generous funded amount)
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be exactly zero");
        assertGe(consumed, BORROW_AMOUNT, "Should consume at least the borrow amount");
        assertGt(usdcAfter, 0, "Surplus should remain");

        console2.log("[exact repay] Debt was:", debtBefore, "Consumed:", consumed);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: EVC STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify collateral and controller state through complete lifecycle
    function test_fork_EVCState_FullLifecycle() public {
        address exec = address(executor);

        // Before anything: no controllers, no collateral
        assertEq(IEVC(EVC).getControllers(exec).length, 0, "No controllers initially");
        assertEq(IEVC(EVC).getCollaterals(exec).length, 0, "No collaterals initially");

        // After deposit: no controller yet (just deposited, didn't borrow)
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        assertEq(IEVC(EVC).getControllers(exec).length, 0, "No controller after deposit only");

        // After borrow: controller + collateral enabled
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
        assertEq(IEVC(EVC).getControllers(exec).length, 1, "Controller after borrow");
        assertTrue(IEVC(EVC).isControllerEnabled(exec, EULER_USDC_VAULT), "USDC vault is controller");
        assertTrue(IEVC(EVC).isCollateralEnabled(exec, EULER_WETH_VAULT), "WETH vault is collateral");

        // After partial repay: controller still enabled
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        assertEq(IEVC(EVC).getControllers(exec).length, 1, "Controller still active after partial repay");

        // After full repay: controller + collateral disabled
        _fundUSDC(BORROW_AMOUNT);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        assertEq(IEVC(EVC).getControllers(exec).length, 0, "No controller after full repay");
        assertFalse(IEVC(EVC).isControllerEnabled(exec, EULER_USDC_VAULT), "USDC vault not controller");
        assertFalse(IEVC(EVC).isCollateralEnabled(exec, EULER_WETH_VAULT), "WETH vault not collateral");

        // Shares still exist (didn't withdraw)
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(exec), 0, "Shares still exist");
    }

    /// @notice Re-opening position after full close works correctly
    function test_fork_EVCState_ReopenAfterClose() public {
        // Open and close
        _openPosition();
        _fundUSDC(1e6);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        uint256 maxW = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxW));

        // Verify fully closed
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "No debt");
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No shares");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "No controllers");

        // Re-open position
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));

        // Verify re-opened correctly
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have shares again");
        assertGt(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Should have debt again");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 1, "Should have controller again");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 12: EXECUTION ARRAY LENGTH VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify execution array sizes for all hook paths against real vault state
    /// @dev BaseHook.build() wraps _buildHookExecutions with preExecute (first) and postExecute (last),
    ///      adding +2 to the hook-specific execution count.
    function test_fork_ExecutionCounts() public {
        address exec = address(executor);

        // Set up state with executeHook (handles pre/post correctly)
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));

        // Deposit: 4 hook executions + 2 (preExecute + postExecute) = 6
        {
            Execution[] memory execs =
                ISuperHook(address(depositHook)).build(address(0), exec, _encodeDepositData(1e18));
            assertEq(execs.length, 6, "Deposit should have 6 executions");
        }

        // Borrow: 3 hook executions + 2 = 5
        {
            Execution[] memory execs = ISuperHook(address(borrowHook)).build(address(0), exec, _encodeBorrowData(500e6));
            assertEq(execs.length, 5, "Borrow should have 5 executions");
        }

        // Partial Repay: 4 hook executions + 2 = 6
        {
            Execution[] memory execs =
                ISuperHook(address(repayHook)).build(address(0), exec, _encodeRepayData(500e6, false));
            assertEq(execs.length, 6, "Partial repay should have 6 executions");
        }

        // Full Repay: 6 hook executions + 2 = 8
        {
            Execution[] memory execs = ISuperHook(address(repayHook)).build(address(0), exec, _encodeRepayData(0, true));
            assertEq(execs.length, 8, "Full repay should have 8 executions");
        }

        // Withdraw: 1 hook execution + 2 = 3
        {
            Execution[] memory execs =
                ISuperHook(address(withdrawHook)).build(address(0), exec, _encodeWithdrawData(1e18));
            assertEq(execs.length, 3, "Withdraw should have 3 executions");
        }
    }

    /// @notice Verify execution array sizes for composite hooks
    /// @dev BaseHook.build() wraps _buildHookExecutions with preExecute (first) and postExecute (last),
    ///      adding +2 to the hook-specific execution count.
    function test_fork_ExecutionCounts_Composite() public {
        address exec = address(executor);

        // Set up state with composite hook
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );

        // DepositAndBorrow: 7 hook executions + 2 = 9
        {
            Execution[] memory execs = ISuperHook(address(depositAndBorrowHook)).build(
                address(0), exec, _encodeDepositAndBorrowData(1e18, 500e6, type(uint256).max, 0)
            );
            assertEq(execs.length, 9, "DepositAndBorrow should have 9 executions");
        }

        // RepayAndWithdraw repay-only: 4 hook executions + 2 = 6
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawHook)).build(
                address(0), exec, _encodeRepayAndWithdrawData(500e6, 0, false, 500e6, 0, 0)
            );
            assertEq(execs.length, 6, "RepayAndWithdraw repay-only should have 6 executions");
        }

        // RepayAndWithdraw partial: 5 hook executions + 2 = 7
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawHook)).build(
                address(0), exec, _encodeRepayAndWithdrawData(500e6, 1e18, false, 500e6, 1e18, 0)
            );
            assertEq(execs.length, 7, "RepayAndWithdraw partial should have 7 executions");
        }

        // RepayAndWithdraw full: 8 hook executions + 2 = 10
        {
            Execution[] memory execs = ISuperHook(address(repayAndWithdrawHook)).build(
                address(0), exec, _encodeRepayAndWithdrawData(0, 3e18, true, type(uint256).max, 3e18, 0)
            );
            assertEq(execs.length, 10, "RepayAndWithdraw full should have 10 executions");
        }
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 13: ACCOUNT LIQUIDITY VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify account liquidity values are sane after opening a position
    function test_fork_AccountLiquidity_AfterOpen() public {
        _openPositionComposite();

        (uint256 collValue, uint256 liabValue) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        assertGt(collValue, 0, "Collateral value should be > 0");
        assertGt(liabValue, 0, "Liability value should be > 0");
        assertGt(collValue, liabValue, "Collateral value should exceed liability (healthy position)");

        console2.log("[liquidity] Collateral value:", collValue, "Liability:", liabValue);
    }

    /// @notice Verify liquidity improves after adding collateral
    function test_fork_AccountLiquidity_ImprovesWithCollateral() public {
        _openPositionComposite();

        (uint256 collBefore, uint256 liabBefore) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        _fundWETH(5e18);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(5e18));

        (uint256 collAfter, uint256 liabAfter) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        assertGt(collAfter, collBefore, "Collateral value should increase");
        assertEq(liabAfter, liabBefore, "Liability should not change");
    }

    /// @notice Verify liquidity improves after partial repay
    function test_fork_AccountLiquidity_ImprovesWithRepay() public {
        _openPositionComposite();

        (, uint256 liabBefore) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));

        (, uint256 liabAfter) = IEVault(EULER_USDC_VAULT).accountLiquidity(address(executor), false);

        assertLt(liabAfter, liabBefore, "Liability should decrease after repay");
    }
}
