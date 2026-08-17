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
import {
    EulerDepositCollateralAndBorrowHook
} from "../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title LoanHookExecutor
/// @notice Minimal contract that acts as both executor and account for loan hook lifecycle testing.
///         Flow: setExecutionContext -> build -> execute each Execution -> resetExecutionState -> getOutAmount
contract LoanHookExecutor {
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

/// @title EulerLoanHooksFork
/// @notice Fork tests for all 6 Euler V2 loan hooks against real mainnet contracts.
///         Validates deposit, borrow, repay, withdraw, composite hooks, interest accrual,
///         config validation, and full lifecycle flows.
contract EulerLoanHooksFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Euler V2 EVC (Ethereum mainnet)
    address public constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;

    // Controller vault: Euler Prime USDC (borrow from here)
    address public constant EULER_USDC_VAULT = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Collateral vault: Euler Prime WETH (deposit collateral here)
    // NOTE: MEV Capital WETH vault (0xe2D6...8fa9) has zero LTV for eUSDC Prime.
    //       eWETH Prime is the correct collateral vault (borrowLTV=83%, liquidationLTV=85%).
    address public constant EULER_WETH_VAULT = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant ETH_BLOCK = 21_929_476;

    // Test amounts (conservative to stay well within LTV)
    uint256 public constant COLLATERAL_AMOUNT = 10e18; // 10 WETH
    uint256 public constant BORROW_AMOUNT = 2000e6; // 2000 USDC

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Individual hooks
    EulerDepositCollateralHook public depositHook;
    EulerBorrowHook public borrowHook;
    EulerRepayHook public repayHook;
    EulerWithdrawCollateralHook public withdrawHook;

    // Composite hooks
    EulerDepositCollateralAndBorrowHook public depositAndBorrowHook;
    EulerRepayAndWithdrawHook public repayAndWithdrawHook;

    // Executor (acts as both executor and account)
    LoanHookExecutor public executor;

    // Real vault config (read from controller vault in setUp)
    address public vaultOracle;
    address public vaultUnitOfAccount;
    address public vaultIRM;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), ETH_BLOCK);

        // Deploy all 6 hooks
        depositHook = new EulerDepositCollateralHook();
        borrowHook = new EulerBorrowHook();
        repayHook = new EulerRepayHook();
        withdrawHook = new EulerWithdrawCollateralHook();
        depositAndBorrowHook = new EulerDepositCollateralAndBorrowHook();
        repayAndWithdrawHook = new EulerRepayAndWithdrawHook();

        // Deploy executor
        executor = new LoanHookExecutor();

        // Read real vault config from controller vault (needed for composite hook encoding)
        vaultOracle = IEVault(EULER_USDC_VAULT).oracle();
        vaultUnitOfAccount = IEVault(EULER_USDC_VAULT).unitOfAccount();
        vaultIRM = IEVault(EULER_USDC_VAULT).interestRateModel();

        // Sanity checks: verify vault assets match expected tokens
        assertEq(IEVault(EULER_WETH_VAULT).asset(), WETH, "WETH vault asset should be WETH");
        assertEq(IEVault(EULER_USDC_VAULT).asset(), USDC, "USDC vault asset should be USDC");
        assertGt(IEVault(EULER_USDC_VAULT).cash(), 0, "USDC vault should have cash for borrowing");
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encode the shared 197-byte prefix used by all Euler loan hooks
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
            bytes32(0), // configId at offset 0
            bytes20(uint160(EULER_WETH_VAULT)), // collateralVault at offset 32
            bytes20(uint160(USDC)), // debtAsset at offset 52
            bytes20(uint160(WETH)), // collateralAsset at offset 72
            bytes20(uint160(EVC)), // evc at offset 92
            bytes20(uint160(EULER_USDC_VAULT)), // controllerVault at offset 112
            primaryAmt, // primaryAmount at offset 132
            secondaryAmt, // secondaryAmount at offset 164
            usePrev // usePrevHookAmount at offset 196
        );
    }

    /// @dev Encode deposit collateral data (197 bytes)
    function _encodeDepositData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    /// @dev Encode borrow data (197 bytes)
    function _encodeBorrowData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    /// @dev Encode repay data (198 bytes, includes isFullRepayment flag)
    function _encodeRepayData(uint256 amt, bool isFullRepayment) internal pure returns (bytes memory) {
        return abi.encodePacked(_encodeSharedPrefix(amt, 0, false), isFullRepayment);
    }

    /// @dev Encode withdraw data (197 bytes)
    function _encodeWithdrawData(uint256 amt) internal pure returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, false);
    }

    /// @dev Encode deposit-and-borrow composite data (321 bytes)
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
            maxPostDebt, // offset 197
            maxLiqCapUtilBps, // offset 229
            bytes20(uint160(vaultOracle)), // offset 261
            bytes20(uint160(vaultUnitOfAccount)), // offset 281
            bytes20(uint160(vaultIRM)) // offset 301
        );
    }

    /// @dev Encode repay-and-withdraw composite data (354 bytes)
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
            isFullRepayment, // offset 197
            maxRepayAssets, // offset 198
            maxCollateralRelease, // offset 230
            maxRemainingLiqCapUtilBps, // offset 262
            bytes20(uint160(vaultOracle)), // offset 294
            bytes20(uint160(vaultUnitOfAccount)), // offset 314
            bytes20(uint160(vaultIRM)) // offset 334
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Opens a standard position: deposit WETH as collateral, borrow USDC
    function _openPosition() internal {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
    }

    /// @dev Opens a position using the composite deposit-and-borrow hook
    function _openPositionComposite() internal {
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );
    }

    /// @dev Deal WETH to executor (additive: preserves existing balance)
    function _fundWETH(uint256 amount) internal {
        deal(WETH, address(executor), IERC20(WETH).balanceOf(address(executor)) + amount);
    }

    /// @dev Deal USDC to executor (additive: preserves existing balance)
    function _fundUSDC(uint256 amount) internal {
        deal(USDC, address(executor), IERC20(USDC).balanceOf(address(executor)) + amount);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 1: INDIVIDUAL HOOKS — DEPOSIT COLLATERAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit WETH into collateral vault, verify shares received
    function test_fork_DepositCollateral() public {
        _fundWETH(COLLATERAL_AMOUNT);

        uint256 outAmount = executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // Verify vault shares received
        uint256 shares = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));
        assertGt(shares, 0, "Executor should have received vault shares");

        // outAmount tracks collateral consumed (pre balance - post balance)
        assertEq(outAmount, COLLATERAL_AMOUNT, "outAmount should equal WETH consumed");

        // All WETH deposited
        assertEq(IERC20(WETH).balanceOf(address(executor)), 0, "All WETH should be deposited");

        console2.log("[deposit] WETH deposited:", COLLATERAL_AMOUNT, "Shares:", shares);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 2: INDIVIDUAL HOOKS — DEPOSIT THEN BORROW (CHAINED)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit WETH as collateral, then borrow USDC in a second hook call
    function test_fork_DepositThenBorrow() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // Step 1: Deposit collateral
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // Step 2: Borrow USDC
        uint256 outAmount = executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));

        // Verify USDC received
        assertEq(IERC20(USDC).balanceOf(address(executor)), BORROW_AMOUNT, "Should have received borrowed USDC");
        assertEq(outAmount, BORROW_AMOUNT, "outAmount should equal borrowed USDC");

        // Verify debt exists
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debt, 0, "Executor should have debt");
        assertGe(debt, BORROW_AMOUNT, "Debt should be >= borrow amount");

        // Verify collateral shares exist
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have collateral shares");

        // Verify controller is set
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Should have exactly 1 controller");
        assertEq(controllers[0], EULER_USDC_VAULT, "Controller should be USDC vault");

        console2.log("[borrow] USDC borrowed:", BORROW_AMOUNT, "Debt:", debt);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: INDIVIDUAL HOOKS — REPAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial repay reduces debt but keeps position open
    function test_fork_RepayPartial() public {
        _openPosition();

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 repayAmount = 1000e6; // Repay 1000 USDC (executor has 2000 from borrow)

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmount, false));

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter, debtBefore, "Debt should decrease after partial repay");
        assertGt(debtAfter, 0, "Debt should still exist after partial repay");

        // Controller should still be enabled
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Controller should still be enabled");

        console2.log("[repay partial] Debt before:", debtBefore, "after:", debtAfter);
    }

    /// @notice Full repay clears debt and disables controller
    function test_fork_RepayFull() public {
        _openPosition();

        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        // Fund extra USDC to cover any rounding in debtOf
        _fundUSDC(1e6);

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        // Verify zero debt
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero after full repay");

        // Verify controller disabled
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 0, "Controller should be disabled after full repay");

        console2.log("[repay full] Original debt:", debt);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: INDIVIDUAL HOOKS — WITHDRAW COLLATERAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw collateral after full repay, verify WETH returned
    function test_fork_WithdrawCollateral() public {
        _openPosition();

        // Full repay first
        _fundUSDC(1e6); // Extra buffer for rounding
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        // Withdraw all collateral
        uint256 maxWithdrawable = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        assertGt(maxWithdrawable, 0, "Should be able to withdraw collateral");

        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxWithdrawable));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        // Verify WETH returned (~full collateral minus potential rounding)
        assertGe(wethAfter - wethBefore, COLLATERAL_AMOUNT - 1, "Should get back ~full collateral");

        // Verify no shares remain
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have no collateral shares left");

        console2.log("[withdraw] WETH returned:", wethAfter - wethBefore);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: COMPOSITE HOOKS — DEPOSIT AND BORROW
    //////////////////////////////////////////////////////////////*/

    /// @notice Single composite hook: deposit collateral + borrow in one call
    function test_fork_DepositCollateralAndBorrow() public {
        _fundWETH(COLLATERAL_AMOUNT);

        uint256 outAmount = executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );

        // Verify collateral deposited
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have collateral shares");
        assertEq(IERC20(WETH).balanceOf(address(executor)), 0, "All WETH should be deposited");

        // Verify USDC borrowed (outAmount tracks debtAsset received)
        assertEq(IERC20(USDC).balanceOf(address(executor)), BORROW_AMOUNT, "Should have received borrowed USDC");
        assertEq(outAmount, BORROW_AMOUNT, "outAmount should equal borrowed USDC");

        // Verify debt
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGe(debt, BORROW_AMOUNT, "Debt should be >= borrow amount");

        // Verify controller
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Should have controller");
        assertEq(controllers[0], EULER_USDC_VAULT, "Controller should be USDC vault");

        console2.log("[composite deposit+borrow] Debt:", debt);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: COMPOSITE HOOKS — REPAY AND WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Repay-only path (secondaryAmount = 0), no collateral withdrawal
    function test_fork_RepayAndWithdraw_RepayOnly() public {
        _openPosition();

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 repayAmount = 500e6;
        uint256 sharesBefore = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(
                repayAmount, 0, // secondaryAmount = 0 -> repay-only path
                false, repayAmount, 0, 0
            )
        );

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertLt(debtAfter, debtBefore, "Debt should decrease after repay");
        assertGt(debtAfter, 0, "Should still have debt");

        // Collateral unchanged
        assertEq(
            IEVault(EULER_WETH_VAULT).balanceOf(address(executor)),
            sharesBefore,
            "Collateral shares should be unchanged"
        );
    }

    /// @notice Partial repay + partial withdraw
    function test_fork_RepayAndWithdraw_Partial() public {
        _openPosition();

        uint256 repayAmount = 1000e6;
        uint256 withdrawAmount = 2e18; // 2 WETH

        uint256 debtBefore = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 wethBefore = IERC20(WETH).balanceOf(address(executor));

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(repayAmount, withdrawAmount, false, repayAmount, withdrawAmount, 0)
        );

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(executor));

        assertLt(debtAfter, debtBefore, "Debt should decrease");
        assertEq(wethAfter - wethBefore, withdrawAmount, "Should have withdrawn WETH");

        // Controller still enabled (not full repay)
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 1, "Controller should still be enabled");

        console2.log("[repay+withdraw partial] Debt before:", debtBefore, "after:", debtAfter);
    }

    /// @notice Full repay + partial withdraw + controller cleanup
    /// @dev Uses a conservative withdraw amount (5 WETH) rather than maxWithdraw,
    ///      because maxWithdraw is constrained by the active debt when queried pre-repay.
    ///      After repay (debt=0), the controller is disabled even with remaining shares.
    function test_fork_RepayAndWithdraw_Full() public {
        _openPosition();

        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(1e6); // Extra buffer for rounding

        // Use a fixed withdraw amount that stays within pre-repay health limits
        uint256 withdrawAmount = 5e18; // 5 WETH (well within bounds)

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(
                0, // primaryAmount unused for full repay
                withdrawAmount,
                true, // isFullRepayment
                type(uint256).max,
                withdrawAmount,
                0
            )
        );

        // Verify zero debt
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");

        // Verify controller disabled
        address[] memory controllers = IEVC(EVC).getControllers(address(executor));
        assertEq(controllers.length, 0, "Controller should be disabled");

        // Verify WETH received
        assertEq(IERC20(WETH).balanceOf(address(executor)), withdrawAmount, "Should have withdrawn WETH");

        console2.log("[repay+withdraw full] Original debt:", debt);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: FULL LIFECYCLE — INDIVIDUAL HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Complete lifecycle: deposit -> borrow -> warp -> full repay -> withdraw
    function test_fork_FullCycle_IndividualHooks() public {
        // Step 1: Deposit collateral
        _fundWETH(COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have collateral shares");

        // Step 2: Borrow
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
        assertEq(IERC20(USDC).balanceOf(address(executor)), BORROW_AMOUNT, "Should have borrowed USDC");

        // Step 3: Warp forward 7 days for interest accrual
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        uint256 debtWithInterest = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debtWithInterest, BORROW_AMOUNT, "Debt should exceed borrow amount after interest");

        // Step 4: Full repay (fund extra for interest)
        _fundUSDC(debtWithInterest); // ensures enough even with existing balance
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");

        // Step 5: Withdraw all collateral
        uint256 maxWithdrawable = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxWithdrawable));

        // Verify clean exit
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No collateral shares");
        assertGe(IERC20(WETH).balanceOf(address(executor)), COLLATERAL_AMOUNT - 1, "WETH returned");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "No controllers");

        console2.log("[full cycle] Interest accrued over 7 days:", debtWithInterest - BORROW_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: FULL LIFECYCLE — COMPOSITE HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Complete lifecycle using composite hooks: depositAndBorrow -> warp -> repayAndWithdraw
    function test_fork_FullCycle_CompositeHooks() public {
        // Step 1: Deposit + Borrow (composite)
        _openPositionComposite();

        assertGt(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "Should have collateral shares");
        assertEq(IERC20(USDC).balanceOf(address(executor)), BORROW_AMOUNT, "Should have borrowed USDC");

        // Step 2: Warp forward 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        // Step 3: Full repay + partial withdraw (composite)
        // NOTE: maxWithdraw is constrained by pre-repay health, so use a conservative amount.
        //       After this hook: debt=0, controller disabled, some shares may remain.
        uint256 debt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        _fundUSDC(debt); // extra to cover interest
        uint256 withdrawAmount = 5e18; // Conservative: 5 WETH

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(0, withdrawAmount, true, type(uint256).max, withdrawAmount, 0)
        );

        // Verify debt and controller cleared
        assertEq(IEVault(EULER_USDC_VAULT).debtOf(address(executor)), 0, "Debt should be zero");
        assertEq(IEVC(EVC).getControllers(address(executor)).length, 0, "No controllers");

        // Verify WETH received from composite hook
        assertEq(IERC20(WETH).balanceOf(address(executor)), withdrawAmount, "Should have withdrawn WETH");

        // Step 4: Withdraw remaining collateral via individual withdraw hook (controller is now disabled)
        uint256 remainingMax = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (remainingMax > 0) {
            executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(remainingMax));
        }

        // Verify fully exited
        assertEq(IEVault(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "No collateral shares");
        assertGe(IERC20(WETH).balanceOf(address(executor)), COLLATERAL_AMOUNT - 1, "WETH returned");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: INTEREST ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify debt increases after time warp due to interest accrual
    function test_fork_InterestAccrual() public {
        _openPosition();

        uint256 debtInitial = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        // Warp forward 30 days
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debtAfter = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertGt(debtAfter, debtInitial, "Debt should increase with interest after 30 days");
        assertGt(debtAfter, BORROW_AMOUNT, "Debt should exceed original borrow amount");

        uint256 interestAccrued = debtAfter - debtInitial;
        console2.log("[interest] Initial debt:", debtInitial);
        console2.log("[interest] After 30 days:", debtAfter);
        console2.log("[interest] Interest accrued:", interestAccrued);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: CONFIG VALIDATION (COMPOSITE HOOKS)
    //////////////////////////////////////////////////////////////*/

    /// @notice DepositAndBorrow reverts when oracle doesn't match vault's oracle
    function test_fork_DepositAndBorrow_OracleMismatch() public {
        _fundWETH(COLLATERAL_AMOUNT);

        // Encode with wrong oracle address
        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(COLLATERAL_AMOUNT, BORROW_AMOUNT, false),
            type(uint256).max, // maxPostDebt
            uint256(0), // maxLiqCapUtilBps
            bytes20(uint160(address(1))), // WRONG oracle
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(vaultIRM))
        );

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.ORACLE_MISMATCH.selector);
        executor.executeHook(address(depositAndBorrowHook), address(0), data);
    }

    /// @notice RepayAndWithdraw reverts when IRM doesn't match (validated when secondaryAmount > 0)
    function test_fork_RepayAndWithdraw_ConfigValidation() public {
        _openPosition();

        // Encode with wrong IRM (only validated when secondaryAmount > 0)
        bytes memory data = abi.encodePacked(
            _encodeSharedPrefix(1000e6, 1e18, false), // repay 1000 USDC + withdraw 1 WETH
            false, // not full repay
            uint256(1000e6), // maxRepayAssets
            uint256(1e18), // maxCollateralRelease
            uint256(0), // maxRemainingLiqCapUtilBps
            bytes20(uint160(vaultOracle)),
            bytes20(uint160(vaultUnitOfAccount)),
            bytes20(uint160(address(1))) // WRONG IRM
        );

        vm.expectRevert(EulerRepayAndWithdrawHook.IRM_MISMATCH.selector);
        executor.executeHook(address(repayAndWithdrawHook), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: INSPECT
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns correct packed addresses against real vaults
    function test_fork_Inspect() public view {
        bytes memory expected = abi.encodePacked(
            EULER_WETH_VAULT, // collateralVault
            EVC, // evc
            EULER_USDC_VAULT // controllerVault
        );

        // Individual hooks (197-byte data)
        bytes memory data197 = _encodeDepositData(COLLATERAL_AMOUNT);
        assertEq(depositHook.inspect(data197), expected, "DepositHook inspect mismatch");
        assertEq(borrowHook.inspect(data197), expected, "BorrowHook inspect mismatch");
        assertEq(withdrawHook.inspect(data197), expected, "WithdrawHook inspect mismatch");

        // Repay hook (198-byte data with isFullRepayment)
        bytes memory data198 = _encodeRepayData(BORROW_AMOUNT, false);
        assertEq(repayHook.inspect(data198), expected, "RepayHook inspect mismatch");

        // Composite hooks (longer data)
        bytes memory depositBorrowData =
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0);
        assertEq(depositAndBorrowHook.inspect(depositBorrowData), expected, "DepositAndBorrowHook inspect mismatch");

        bytes memory repayWithdrawData = _encodeRepayAndWithdrawData(1000e6, 1e18, false, 1000e6, 1e18, 0);
        assertEq(repayAndWithdrawHook.inspect(repayWithdrawData), expected, "RepayAndWithdrawHook inspect mismatch");
    }
}
