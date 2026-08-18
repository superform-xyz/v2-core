// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IEVault } from "../../../src/vendor/euler/IEVault.sol";
import { IEVC } from "../../../src/vendor/euler/IEVC.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";

// Oracle
import { EulerDebtOracle } from "../../../src/accounting/oracles/EulerDebtOracle.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

// Hooks
import { EulerDepositCollateralHook } from "../../../src/hooks/loan/euler/EulerDepositCollateralHook.sol";
import { EulerBorrowHook } from "../../../src/hooks/loan/euler/EulerBorrowHook.sol";
import { EulerRepayHook } from "../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerWithdrawCollateralHook } from "../../../src/hooks/loan/euler/EulerWithdrawCollateralHook.sol";
import { EulerDepositCollateralAndBorrowHook } from
    "../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title DebtOracleHookExecutor
/// @notice Minimal contract that acts as both executor and account for hook + oracle testing.
contract DebtOracleHookExecutor {
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

/// @title EulerDebtOracleFork
/// @notice E2E fork tests for EulerDebtOracle against real Euler V2 mainnet contracts,
///         combined with loan hook execution. Tests the oracle's ability to track debt
///         positions before, during, and after leveraged lifecycle operations.
contract EulerDebtOracleFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Euler V2 EVC (Ethereum mainnet)
    address public constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;

    // Controller vault: Euler Prime USDC (borrow from here — debt oracle target)
    address public constant EULER_USDC_VAULT = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Collateral vault: Euler Prime WETH (deposit collateral — supply oracle target)
    address public constant EULER_WETH_VAULT = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant ETH_BLOCK = 21_929_476;

    // Test amounts
    uint256 public constant COLLATERAL_AMOUNT = 10e18; // 10 WETH
    uint256 public constant BORROW_AMOUNT = 2000e6; // 2000 USDC

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Oracles
    EulerDebtOracle public debtOracle;
    ERC4626YieldSourceOracle public supplyOracle;

    // Hooks
    EulerDepositCollateralHook public depositHook;
    EulerBorrowHook public borrowHook;
    EulerRepayHook public repayHook;
    EulerWithdrawCollateralHook public withdrawHook;
    EulerDepositCollateralAndBorrowHook public depositAndBorrowHook;
    EulerRepayAndWithdrawHook public repayAndWithdrawHook;

    // Executor (acts as both executor and account)
    DebtOracleHookExecutor public executor;
    DebtOracleHookExecutor public executor2; // second executor for multi-account tests

    // Real vault config
    address public vaultOracle;
    address public vaultUnitOfAccount;
    address public vaultIRM;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), ETH_BLOCK);

        // Deploy oracles
        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        debtOracle = new EulerDebtOracle(address(ledgerConfig));
        supplyOracle = new ERC4626YieldSourceOracle(address(ledgerConfig));

        // Deploy hooks
        depositHook = new EulerDepositCollateralHook();
        borrowHook = new EulerBorrowHook();
        repayHook = new EulerRepayHook();
        withdrawHook = new EulerWithdrawCollateralHook();
        depositAndBorrowHook = new EulerDepositCollateralAndBorrowHook();
        repayAndWithdrawHook = new EulerRepayAndWithdrawHook();

        // Deploy executors
        executor = new DebtOracleHookExecutor();
        executor2 = new DebtOracleHookExecutor();

        // Read real vault config
        vaultOracle = IEVault(EULER_USDC_VAULT).oracle();
        vaultUnitOfAccount = IEVault(EULER_USDC_VAULT).unitOfAccount();
        vaultIRM = IEVault(EULER_USDC_VAULT).interestRateModel();

        // Sanity
        assertEq(IEVault(EULER_WETH_VAULT).asset(), WETH);
        assertEq(IEVault(EULER_USDC_VAULT).asset(), USDC);
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _encodeSharedPrefix(
        address collateralVault,
        address debtAsset,
        address collateralAsset,
        address evc,
        address controllerVault,
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
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            primaryAmt,
            secondaryAmt,
            usePrev
        );
    }

    function _defaultPrefix(uint256 primaryAmt, uint256 secondaryAmt, bool usePrev)
        internal
        pure
        returns (bytes memory)
    {
        return _encodeSharedPrefix(EULER_WETH_VAULT, USDC, WETH, EVC, EULER_USDC_VAULT, primaryAmt, secondaryAmt, usePrev);
    }

    function _encodeDepositData(uint256 amt) internal pure returns (bytes memory) {
        return _defaultPrefix(amt, 0, false);
    }

    function _encodeBorrowData(uint256 amt) internal pure returns (bytes memory) {
        return _defaultPrefix(amt, 0, false);
    }

    function _encodeRepayData(uint256 amt, bool isFullRepayment) internal pure returns (bytes memory) {
        return abi.encodePacked(_defaultPrefix(amt, 0, false), isFullRepayment);
    }

    function _encodeWithdrawData(uint256 amt) internal pure returns (bytes memory) {
        return _defaultPrefix(amt, 0, false);
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
            _defaultPrefix(collateralAmt, borrowAmt, false),
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
            _defaultPrefix(repayAmt, withdrawAmt, false),
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

    function _fundWETH(address target, uint256 amount) internal {
        deal(WETH, target, IERC20(WETH).balanceOf(target) + amount);
    }

    function _fundUSDC(address target, uint256 amount) internal {
        deal(USDC, target, IERC20(USDC).balanceOf(target) + amount);
    }

    function _openPosition() internal {
        _openPositionFor(executor);
    }

    function _openPositionFor(DebtOracleHookExecutor exec) internal {
        _fundWETH(address(exec), COLLATERAL_AMOUNT);
        exec.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        exec.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));
    }

    function _openPositionComposite() internal {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(
            address(depositAndBorrowHook),
            address(0),
            _encodeDepositAndBorrowData(COLLATERAL_AMOUNT, BORROW_AMOUNT, type(uint256).max, 0)
        );
    }

    function _fullRepayAndWithdraw(DebtOracleHookExecutor exec) internal {
        uint256 debtOwed = IEVault(EULER_USDC_VAULT).debtOf(address(exec));
        _fundUSDC(address(exec), debtOwed + 1e6); // buffer for rounding
        exec.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));
        uint256 maxWithdrawable = IEVault(EULER_WETH_VAULT).maxWithdraw(address(exec));
        if (maxWithdrawable > 0) {
            exec.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(maxWithdrawable));
        }
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 1: DEBT ORACLE — BASIC READS AGAINST REAL VAULTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify debt oracle decimals match the controller vault decimals (USDC = 6)
    function test_fork_debtOracle_decimals_USDC() public view {
        uint8 oracleDecimals = debtOracle.decimals(EULER_USDC_VAULT);
        uint8 vaultDecimals = IEVault(EULER_USDC_VAULT).decimals();
        assertEq(oracleDecimals, vaultDecimals, "Decimals must match vault");
        assertEq(oracleDecimals, 6, "USDC vault should have 6 decimals");
    }

    /// @notice Verify debt oracle decimals for WETH vault (18 decimals)
    function test_fork_debtOracle_decimals_WETH() public view {
        uint8 oracleDecimals = debtOracle.decimals(EULER_WETH_VAULT);
        uint8 vaultDecimals = IEVault(EULER_WETH_VAULT).decimals();
        assertEq(oracleDecimals, vaultDecimals, "Decimals must match vault");
        assertEq(oracleDecimals, 18, "WETH vault should have 18 decimals");
    }

    /// @notice Decimals matches underlying asset for USDC vault
    function test_fork_debtOracle_decimals_matchesUnderlyingAsset_USDC() public view {
        uint8 oracleDecimals = debtOracle.decimals(EULER_USDC_VAULT);
        // Euler EVaults use same decimals as underlying asset
        assertEq(oracleDecimals, IERC20Metadata(USDC).decimals());
    }

    /// @notice PPS for debt oracle is always 1:1 (10^decimals) — USDC vault
    function test_fork_debtOracle_pps_USDC() public view {
        uint256 pps = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        assertEq(pps, 1e6, "PPS for 6-decimal debt oracle should be 1e6");
    }

    /// @notice PPS for debt oracle is always 1:1 (10^decimals) — WETH vault
    function test_fork_debtOracle_pps_WETH() public view {
        uint256 pps = debtOracle.getPricePerShare(EULER_WETH_VAULT);
        assertEq(pps, 1e18, "PPS for 18-decimal debt oracle should be 1e18");
    }

    /// @notice PPS remains constant regardless of vault state changes (borrow, accrue, etc.)
    function test_fork_debtOracle_pps_constantAfterBorrowAndAccrual() public {
        uint256 ppsBefore = debtOracle.getPricePerShare(EULER_USDC_VAULT);

        _openPosition();

        uint256 ppsAfterBorrow = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        assertEq(ppsAfterBorrow, ppsBefore, "PPS unchanged after borrow");

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 2_628_000);

        uint256 ppsAfterYear = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        assertEq(ppsAfterYear, ppsBefore, "PPS unchanged after 1 year of accrual");
    }

    /// @notice TVL (totalBorrows) should be non-zero on an active lending vault
    function test_fork_debtOracle_tvl_nonZero() public view {
        uint256 tvl = debtOracle.getTVL(EULER_USDC_VAULT);
        uint256 totalBorrows = IEVault(EULER_USDC_VAULT).totalBorrows();
        assertGt(tvl, 0, "Active vault should have nonzero totalBorrows");
        assertEq(tvl, totalBorrows, "Oracle TVL must match vault totalBorrows");
        console2.log("[debtOracle] USDC vault totalBorrows:", tvl);
    }

    /// @notice WETH vault also has totalBorrows
    function test_fork_debtOracle_tvl_WETH_nonZero() public view {
        uint256 tvl = debtOracle.getTVL(EULER_WETH_VAULT);
        uint256 totalBorrows = IEVault(EULER_WETH_VAULT).totalBorrows();
        assertEq(tvl, totalBorrows, "Oracle TVL must match vault totalBorrows for WETH");
    }

    /// @notice Identity conversion: getShareOutput returns input unchanged
    function test_fork_debtOracle_identity_conversions() public view {
        uint256 amount = 1000e6;
        assertEq(debtOracle.getShareOutput(EULER_USDC_VAULT, USDC, amount), amount);
        assertEq(debtOracle.getWithdrawalShareOutput(EULER_USDC_VAULT, USDC, amount), amount);
        assertEq(debtOracle.getAssetOutput(EULER_USDC_VAULT, USDC, amount), amount);
    }

    /// @notice Identity conversions with zero
    function test_fork_debtOracle_identity_zero() public view {
        assertEq(debtOracle.getShareOutput(EULER_USDC_VAULT, USDC, 0), 0);
        assertEq(debtOracle.getAssetOutput(EULER_USDC_VAULT, USDC, 0), 0);
        assertEq(debtOracle.getWithdrawalShareOutput(EULER_USDC_VAULT, USDC, 0), 0);
    }

    /// @notice Identity conversions with 1 wei
    function test_fork_debtOracle_identity_1wei() public view {
        assertEq(debtOracle.getShareOutput(EULER_USDC_VAULT, USDC, 1), 1);
        assertEq(debtOracle.getAssetOutput(EULER_USDC_VAULT, USDC, 1), 1);
        assertEq(debtOracle.getWithdrawalShareOutput(EULER_USDC_VAULT, USDC, 1), 1);
    }

    /// @notice Identity conversions with max uint256
    function test_fork_debtOracle_identity_maxUint() public view {
        assertEq(debtOracle.getShareOutput(EULER_USDC_VAULT, USDC, type(uint256).max), type(uint256).max);
        assertEq(debtOracle.getAssetOutput(EULER_USDC_VAULT, USDC, type(uint256).max), type(uint256).max);
    }

    /// @notice No-debt account returns 0 from getBalanceOfOwner
    function test_fork_debtOracle_zeroDebt_unknownAccount() public view {
        address nobody = address(0xdead);
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, nobody), 0);
        assertEq(debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, nobody), 0);
    }

    /// @notice Zero address as owner returns 0 (no debt)
    function test_fork_debtOracle_zeroDebt_zeroAddress() public view {
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(0)), 0);
        assertEq(debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(0)), 0);
    }

    /// @notice getAssetOutputWithFees returns identity when no config is set
    function test_fork_debtOracle_getAssetOutputWithFees_noConfig() public view {
        bytes32 fakeId = keccak256("nonexistent");
        uint256 amount = 1000e6;
        uint256 result = debtOracle.getAssetOutputWithFees(fakeId, EULER_USDC_VAULT, USDC, address(executor), amount);
        assertEq(result, amount, "getAssetOutputWithFees should return identity without config");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 2: DEBT ORACLE — TRACKS DEBT AFTER BORROW (HOOKS)
    //////////////////////////////////////////////////////////////*/

    /// @notice After deposit + borrow via hooks, debt oracle reports the correct debt
    function test_fork_debtOracle_tracksDebtAfterBorrow() public {
        // Before borrowing: no debt
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "No debt before borrow");
        assertEq(debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor)), 0, "No TVL before borrow");

        // Open position: deposit 10 WETH, borrow 2000 USDC
        _openPosition();

        // After borrowing: debt oracle should report the debt
        uint256 oracleDebt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 oracleTVL = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));
        uint256 directDebt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        assertGe(oracleDebt, BORROW_AMOUNT, "Oracle debt should be >= borrow amount");
        assertEq(oracleDebt, directDebt, "Oracle debt must match debtOf()");
        assertEq(oracleDebt, oracleTVL, "getBalanceOfOwner == getTVLByOwnerOfShares for debt oracle");

        console2.log("[e2e borrow] Oracle debt:", oracleDebt, "Direct debtOf:", directDebt);
    }

    /// @notice After composite deposit+borrow, debt oracle reports the correct debt
    function test_fork_debtOracle_tracksDebtAfterCompositeBorrow() public {
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "No debt before");

        _openPositionComposite();

        uint256 oracleDebt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 directDebt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        assertGe(oracleDebt, BORROW_AMOUNT, "Oracle debt should be >= borrow amount");
        assertEq(oracleDebt, directDebt, "Oracle must match debtOf()");
    }

    /// @notice Oracle reads in the same transaction as borrow — no lag
    function test_fork_debtOracle_sameBlockConsistency() public {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // Check debt is zero before borrow
        uint256 debtPre = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertEq(debtPre, 0);

        // Borrow in same block
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));

        // Oracle should reflect immediately
        uint256 debtPost = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debtPost, BORROW_AMOUNT, "Debt reflected in same block");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: DEBT ORACLE — INTEREST ACCRUAL TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle correctly reflects interest accrual over time
    function test_fork_debtOracle_interestAccrual_7days() public {
        _openPosition();

        uint256 debtDay0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        // Warp 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        uint256 debtDay7 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 directDebt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));

        assertGt(debtDay7, debtDay0, "Debt should increase after 7 days");
        assertEq(debtDay7, directDebt, "Oracle must match debtOf() after accrual");

        uint256 interest = debtDay7 - debtDay0;
        console2.log("[interest 7d] Day 0:", debtDay0, "Day 7:", debtDay7);
        console2.log("[interest 7d] Interest:", interest);
    }

    /// @notice 1 day of interest accrual
    function test_fork_debtOracle_interestAccrual_1day() public {
        _openPosition();

        uint256 debtDay0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 7200);

        uint256 debtDay1 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtDay1, debtDay0, "Debt should increase after 1 day");
        assertEq(debtDay1, IEVault(EULER_USDC_VAULT).debtOf(address(executor)));
    }

    /// @notice Debt oracle correctly reflects interest accrual over 30 days
    function test_fork_debtOracle_interestAccrual_30days() public {
        _openPosition();

        uint256 debtDay0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        // Warp 30 days
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debtDay30 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 tvlDay30 = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));

        assertGt(debtDay30, debtDay0, "Debt should increase after 30 days");
        assertEq(debtDay30, tvlDay30, "getBalanceOfOwner == getTVLByOwnerOfShares");

        uint256 interest = debtDay30 - debtDay0;
        console2.log("[interest 30d] Day 0:", debtDay0, "Day 30:", debtDay30);
        console2.log("[interest 30d] Interest:", interest);
    }

    /// @notice 365-day long-term accrual — no overflow, interest is reasonable
    function test_fork_debtOracle_interestAccrual_365days() public {
        _openPosition();

        uint256 debtDay0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 2_628_000);

        uint256 debtDay365 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtDay365, debtDay0, "Debt should increase after 365 days");
        assertEq(debtDay365, IEVault(EULER_USDC_VAULT).debtOf(address(executor)));

        // Sanity: interest should be reasonable (< 100% APR)
        uint256 interest = debtDay365 - debtDay0;
        assertLt(interest, debtDay0, "Interest after 1 year should be < 100%");

        console2.log("[interest 365d] Day 0:", debtDay0, "Day 365:", debtDay365);
        console2.log("[interest 365d] APR%:", (interest * 100) / debtDay0);
    }

    /// @notice Interest is monotonically increasing: day7 < day30 < day365
    function test_fork_debtOracle_interestAccrual_monotonic() public {
        _openPosition();

        uint256 debtDay0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);
        uint256 debtDay7 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        vm.warp(block.timestamp + 23 days); // total 30 days
        vm.roll(block.number + 165_600);
        uint256 debtDay30 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        vm.warp(block.timestamp + 335 days); // total 365 days
        vm.roll(block.number + 2_412_000);
        uint256 debtDay365 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        assertGt(debtDay7, debtDay0, "day7 > day0");
        assertGt(debtDay30, debtDay7, "day30 > day7");
        assertGt(debtDay365, debtDay30, "day365 > day30");
    }

    /// @notice totalBorrows (getTVL) also increases with interest accrual
    function test_fork_debtOracle_tvl_increasesWithInterest() public {
        uint256 tvlBefore = debtOracle.getTVL(EULER_USDC_VAULT);

        _openPosition();

        uint256 tvlAfterBorrow = debtOracle.getTVL(EULER_USDC_VAULT);
        assertGt(tvlAfterBorrow, tvlBefore, "TVL should increase after new borrow");

        // Warp 30 days — interest accrues across all borrowers
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 tvlAfterAccrual = debtOracle.getTVL(EULER_USDC_VAULT);
        assertGt(tvlAfterAccrual, tvlAfterBorrow, "TVL should increase with interest accrual");

        console2.log("[TVL] Before:", tvlBefore, "After borrow:", tvlAfterBorrow);
        console2.log("[TVL] After 30d:", tvlAfterAccrual);
    }

    /// @notice TVL increase from borrow == borrow amount (within rounding)
    function test_fork_debtOracle_tvl_increaseMatchesBorrow() public {
        uint256 tvlBefore = debtOracle.getTVL(EULER_USDC_VAULT);

        _openPosition();

        uint256 tvlAfter = debtOracle.getTVL(EULER_USDC_VAULT);
        uint256 delta = tvlAfter - tvlBefore;
        // delta should be approximately BORROW_AMOUNT (may differ by 1 due to rounding)
        assertGe(delta, BORROW_AMOUNT, "TVL increase should be >= borrow amount");
        assertLe(delta, BORROW_AMOUNT + 1, "TVL increase should be within 1 of borrow amount");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: DEBT ORACLE — PARTIAL REPAY TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle reflects reduced debt after partial repay
    function test_fork_debtOracle_partialRepay_debtDecreases() public {
        _openPosition();

        uint256 debtBefore = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 repayAmount = 1000e6; // Repay half

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmount, false));

        uint256 debtAfter = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertLt(debtAfter, debtBefore, "Debt should decrease after partial repay");
        assertGt(debtAfter, 0, "Debt should not be zero after partial repay");

        // Verify oracle matches direct call
        assertEq(debtAfter, IEVault(EULER_USDC_VAULT).debtOf(address(executor)));

        console2.log("[partial repay] Before:", debtBefore, "After:", debtAfter);
    }

    /// @notice Partial repay after interest accrual — delta matches repay amount
    function test_fork_debtOracle_partialRepay_afterAccrual() public {
        _openPosition();

        // Warp 7 days to accrue interest
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        uint256 debtWithInterest = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtWithInterest, BORROW_AMOUNT, "Should have accrued interest");

        // Partial repay 500 USDC
        uint256 repayAmount = 500e6;
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(repayAmount, false));

        uint256 debtAfterRepay = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        // Debt reduction should be approximately repayAmount
        uint256 reduction = debtWithInterest - debtAfterRepay;
        assertGe(reduction, repayAmount - 1, "Reduction >= repay amount (minus rounding)");
        assertLe(reduction, repayAmount + 1, "Reduction <= repay amount (plus rounding)");
    }

    /// @notice Very small partial repay (1 USDC)
    function test_fork_debtOracle_partialRepay_tiny() public {
        _openPosition();

        uint256 debtBefore = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(1e6, false));
        uint256 debtAfter = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        assertLt(debtAfter, debtBefore, "Even tiny repay should decrease debt");
        assertEq(debtAfter, IEVault(EULER_USDC_VAULT).debtOf(address(executor)));
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: DEBT ORACLE — FULL REPAY CLEARS DEBT
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle returns 0 after full repayment
    function test_fork_debtOracle_fullRepay_debtCleared() public {
        _openPosition();

        uint256 debtBefore = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtBefore, 0, "Should have debt before repay");

        // Fund extra for interest rounding
        _fundUSDC(address(executor), 1e6);

        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        uint256 debtAfter = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 tvlAfter = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));

        assertEq(debtAfter, 0, "Debt should be zero after full repay");
        assertEq(tvlAfter, 0, "TVL should be zero after full repay");
    }

    /// @notice Full repay after significant interest accrual (30 days)
    function test_fork_debtOracle_fullRepay_afterAccrual() public {
        _openPosition();

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debtWithInterest = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtWithInterest, BORROW_AMOUNT, "Should have accrued interest");

        _fundUSDC(address(executor), debtWithInterest);
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Debt cleared after accrual");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: DUAL ORACLE — COLLATERAL + DEBT TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Track both collateral (supply oracle) and debt (debt oracle) for a leveraged position
    function test_fork_dualOracle_collateralAndDebt() public {
        // Before: no position
        uint256 collateralTVL0 = supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor));
        uint256 debtTVL0 = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));
        assertEq(collateralTVL0, 0, "No collateral before");
        assertEq(debtTVL0, 0, "No debt before");

        // Open leveraged position
        _openPosition();

        // After: both legs tracked
        uint256 collateralTVL = supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor));
        uint256 debtTVL = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));

        assertGt(collateralTVL, 0, "Should have collateral TVL");
        assertGt(debtTVL, 0, "Should have debt TVL");

        // Collateral shares correspond to deposited WETH
        uint256 shares = supplyOracle.getBalanceOfOwner(EULER_WETH_VAULT, address(executor));
        uint256 convertedAssets = supplyOracle.getAssetOutput(EULER_WETH_VAULT, WETH, shares);
        assertGe(convertedAssets, COLLATERAL_AMOUNT - 1, "Collateral value should be ~= deposited WETH");

        // Debt matches borrowed USDC
        assertGe(debtTVL, BORROW_AMOUNT, "Debt should be >= borrow amount");

        console2.log("[dual] Collateral TVL (WETH assets):", collateralTVL);
        console2.log("[dual] Debt TVL (USDC):", debtTVL);
    }

    /// @notice After interest accrual, debt increases while collateral value also increases (supply side earns)
    function test_fork_dualOracle_interestAccrual_bothLegs() public {
        _openPosition();

        uint256 collateralTVL0 = supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor));
        uint256 debtTVL0 = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));

        // Warp 30 days
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 collateralTVL30 = supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor));
        uint256 debtTVL30 = debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));

        // Debt should definitely increase (borrower pays interest)
        assertGt(debtTVL30, debtTVL0, "Debt should increase after 30 days");

        // Collateral value may increase if WETH vault earns yield (supply side)
        // At minimum, it should not decrease materially
        assertGe(collateralTVL30, collateralTVL0 - 1, "Collateral should not lose value");

        console2.log("[dual 30d] Collateral day0:", collateralTVL0, "day30:", collateralTVL30);
        console2.log("[dual 30d] Debt day0:", debtTVL0, "day30:", debtTVL30);
    }

    /// @notice Full lifecycle: open -> accrue -> full repay -> withdraw — both oracles reset to 0
    function test_fork_dualOracle_fullLifecycle() public {
        // Step 1: Open position
        _openPosition();

        assertGt(supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor)), 0, "Collateral TVL > 0");
        assertGt(debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor)), 0, "Debt TVL > 0");

        // Step 2: Warp 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        uint256 debtWithInterest = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtWithInterest, BORROW_AMOUNT, "Debt should have accrued interest");

        // Step 3: Full repay and withdraw
        _fullRepayAndWithdraw(executor);

        // Both oracles should return 0
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Debt oracle = 0 after close");
        assertEq(
            supplyOracle.getBalanceOfOwner(EULER_WETH_VAULT, address(executor)),
            0,
            "Supply oracle = 0 after close"
        );
        assertEq(
            debtOracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor)),
            0,
            "Debt TVL = 0 after close"
        );
        assertEq(
            supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor)),
            0,
            "Supply TVL = 0 after close"
        );
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: DEBT ORACLE — COMPOSITE HOOK E2E
    //////////////////////////////////////////////////////////////*/

    /// @notice Composite deposit+borrow -> oracle reads -> composite repay+withdraw -> oracle reads
    function test_fork_debtOracle_compositeHookLifecycle() public {
        // Step 1: Open via composite hook
        _openPositionComposite();

        uint256 debt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 collateral = supplyOracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(executor));
        assertGe(debt, BORROW_AMOUNT, "Debt after composite open");
        assertGt(collateral, 0, "Collateral after composite open");

        // Step 2: Warp 7 days
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_400);

        uint256 debtDay7 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtDay7, debt, "Debt should grow with interest");

        // Step 3: Close via composite repay+withdraw
        _fundUSDC(address(executor), debtDay7);
        uint256 withdrawAmount = 5e18;

        executor.executeHook(
            address(repayAndWithdrawHook),
            address(0),
            _encodeRepayAndWithdrawData(0, withdrawAmount, true, type(uint256).max, withdrawAmount, 0)
        );

        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Debt cleared after composite");

        // Withdraw remaining collateral
        uint256 remainingMax = IEVault(EULER_WETH_VAULT).maxWithdraw(address(executor));
        if (remainingMax > 0) {
            executor.executeHook(address(withdrawHook), address(0), _encodeWithdrawData(remainingMax));
        }

        assertEq(supplyOracle.getBalanceOfOwner(EULER_WETH_VAULT, address(executor)), 0, "All collateral withdrawn");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: DEBT ORACLE — BATCH METHODS ON REAL VAULTS
    //////////////////////////////////////////////////////////////*/

    /// @notice getPricePerShareMultiple returns correct PPS for both vaults
    function test_fork_debtOracle_batchPPS() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        uint256[] memory prices = debtOracle.getPricePerShareMultiple(vaults);
        assertEq(prices[0], 1e6, "USDC vault PPS");
        assertEq(prices[1], 1e18, "WETH vault PPS");
    }

    /// @notice getTVLMultiple returns totalBorrows for both vaults
    function test_fork_debtOracle_batchTVL() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        uint256[] memory tvls = debtOracle.getTVLMultiple(vaults);
        assertEq(tvls[0], IEVault(EULER_USDC_VAULT).totalBorrows(), "USDC TVL");
        assertEq(tvls[1], IEVault(EULER_WETH_VAULT).totalBorrows(), "WETH TVL");
    }

    /// @notice getTVLByOwnerOfSharesMultiple tracks debt across multiple accounts
    function test_fork_debtOracle_batchTVLByOwner() public {
        // Open position for executor
        _openPosition();

        address[] memory vaults = new address[](1);
        vaults[0] = EULER_USDC_VAULT;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = address(executor);
        owners[0][1] = address(0xdead); // no debt

        (uint256[][] memory tvls, bool[][] memory succeeded) =
            debtOracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        assertGe(tvls[0][0], BORROW_AMOUNT, "Executor should have debt");
        assertTrue(succeeded[0][0], "Executor query should succeed");
        assertEq(tvls[0][1], 0, "Dead address should have zero debt");
        assertTrue(succeeded[0][1], "Dead address query should succeed");
    }

    /// @notice Batch across both vaults with multiple owners
    function test_fork_debtOracle_batchTVLByOwner_multiVaultMultiOwner() public {
        _openPosition();

        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](2);
        owners[0][0] = address(executor);
        owners[0][1] = address(0xdead);
        owners[1] = new address[](1);
        owners[1][0] = address(executor);

        (uint256[][] memory tvls, bool[][] memory succeeded) =
            debtOracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        // executor has USDC debt
        assertGe(tvls[0][0], BORROW_AMOUNT);
        assertTrue(succeeded[0][0]);

        // 0xdead has no USDC debt
        assertEq(tvls[0][1], 0);
        assertTrue(succeeded[0][1]);

        // executor has no WETH debt (it's collateral vault, not borrowing WETH)
        assertEq(tvls[1][0], 0);
        assertTrue(succeeded[1][0]);
    }

    /// @notice Empty batch arrays return empty results
    function test_fork_debtOracle_batchPPS_empty() public view {
        address[] memory vaults = new address[](0);
        uint256[] memory prices = debtOracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 0);
    }

    function test_fork_debtOracle_batchTVL_empty() public view {
        address[] memory vaults = new address[](0);
        uint256[] memory tvls = debtOracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: DEBT ORACLE vs SUPPLY ORACLE — DISTINCT SEMANTICS
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt oracle PPS is constant (1:1), supply oracle PPS varies with vault state
    function test_fork_oracle_pps_semanticDifference() public view {
        // Debt oracle: always 1:1
        uint256 debtPPS_USDC = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        assertEq(debtPPS_USDC, 1e6, "Debt PPS always 1:1");

        // Supply oracle: reflects vault share-to-asset conversion (may be > 1.0 if yield accrued)
        uint256 supplyPPS_WETH = supplyOracle.getPricePerShare(EULER_WETH_VAULT);
        // eWETH Prime PPS should be >= 1e18 (yield accrues to depositors)
        assertGe(supplyPPS_WETH, 1e18, "Supply PPS should be >= 1.0");
        console2.log("[semantic] Debt PPS USDC:", debtPPS_USDC, "Supply PPS WETH:", supplyPPS_WETH);
    }

    /// @notice Debt oracle getBalanceOfOwner returns debtOf, supply oracle returns vault shares
    function test_fork_oracle_balanceOfOwner_semanticDifference() public {
        _openPosition();

        // Supply oracle returns vault share balance
        uint256 supplyBalance = supplyOracle.getBalanceOfOwner(EULER_WETH_VAULT, address(executor));
        uint256 vaultShares = IEVault(EULER_WETH_VAULT).balanceOf(address(executor));
        assertEq(supplyBalance, vaultShares, "Supply oracle returns share balance");

        // Debt oracle returns debt amount in asset units
        uint256 debtBalance = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 directDebt = IEVault(EULER_USDC_VAULT).debtOf(address(executor));
        assertEq(debtBalance, directDebt, "Debt oracle returns debtOf");

        // These are different units/semantics
        assertGt(supplyBalance, 0);
        assertGt(debtBalance, 0);
    }

    /// @notice Debt oracle TVL returns totalBorrows, supply oracle TVL returns totalAssets
    function test_fork_oracle_tvl_semanticDifference() public view {
        uint256 debtTVL = debtOracle.getTVL(EULER_USDC_VAULT);
        uint256 supplyTVL = supplyOracle.getTVL(EULER_USDC_VAULT);

        uint256 totalBorrows = IEVault(EULER_USDC_VAULT).totalBorrows();
        uint256 totalAssets = IERC4626(EULER_USDC_VAULT).totalAssets();

        assertEq(debtTVL, totalBorrows, "Debt oracle TVL = totalBorrows");
        assertEq(supplyTVL, totalAssets, "Supply oracle TVL = totalAssets");

        // totalAssets should be > totalBorrows (vault has cash + borrows = totalAssets)
        assertGt(supplyTVL, debtTVL, "Supply TVL > Debt TVL (vault has unborrowed cash)");

        console2.log("[TVL semantics] Debt (totalBorrows):", debtTVL, "Supply (totalAssets):", supplyTVL);
    }

    /// @notice Supply oracle PPS changes over time; debt oracle PPS does not
    function test_fork_oracle_pps_divergenceOverTime() public {
        uint256 debtPPS0 = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 supplyPPS0 = supplyOracle.getPricePerShare(EULER_USDC_VAULT);

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 2_628_000);

        uint256 debtPPS365 = debtOracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 supplyPPS365 = supplyOracle.getPricePerShare(EULER_USDC_VAULT);

        assertEq(debtPPS0, debtPPS365, "Debt PPS unchanged after 1 year");
        assertGt(supplyPPS365, supplyPPS0, "Supply PPS should increase after 1 year");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: DEBT ORACLE — SEQUENTIAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential borrows increase debt tracked by oracle
    function test_fork_debtOracle_sequentialBorrows() public {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // First borrow: 500 USDC
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        uint256 debtAfterFirst = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debtAfterFirst, 500e6, "Debt after first borrow");

        // Second borrow: 500 USDC
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        uint256 debtAfterSecond = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debtAfterSecond, 1000e6, "Debt after second borrow");
        assertGt(debtAfterSecond, debtAfterFirst, "Debt should increase after second borrow");

        // Third borrow: 500 USDC
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        uint256 debtAfterThird = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debtAfterThird, 1500e6, "Debt after third borrow");
        assertGt(debtAfterThird, debtAfterSecond, "Debt should increase after third borrow");

        console2.log("[seq borrows] 1st:", debtAfterFirst, "2nd:", debtAfterSecond);
        console2.log("[seq borrows] 3rd:", debtAfterThird);
    }

    /// @notice Sequential partial repays progressively reduce debt tracked by oracle
    function test_fork_debtOracle_sequentialPartialRepays() public {
        _openPosition();

        uint256 debtInitial = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));

        // First partial repay: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfterFirst = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertLt(debtAfterFirst, debtInitial, "Debt should decrease after first repay");

        // Second partial repay: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfterSecond = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertLt(debtAfterSecond, debtAfterFirst, "Debt should decrease after second repay");

        // Third partial repay: 500 USDC
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfterThird = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertLt(debtAfterThird, debtAfterSecond, "Debt should decrease after third repay");

        console2.log("[seq repays] Initial:", debtInitial, "After 1st:", debtAfterFirst);
        console2.log("[seq repays] After 2nd:", debtAfterSecond, "After 3rd:", debtAfterThird);
    }

    /// @notice Borrow, repay partial, borrow again — oracle tracks correctly
    function test_fork_debtOracle_borrowRepayBorrow() public {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        // Borrow 1000
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(1000e6));
        uint256 debtAfterBorrow1 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debtAfterBorrow1, 1000e6);

        // Repay 500
        executor.executeHook(address(repayHook), address(0), _encodeRepayData(500e6, false));
        uint256 debtAfterRepay = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertLt(debtAfterRepay, debtAfterBorrow1);

        // Borrow 500 more
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));
        uint256 debtAfterBorrow2 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGt(debtAfterBorrow2, debtAfterRepay);
        assertGe(debtAfterBorrow2, 1000e6, "Net debt should be ~1000");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: DEBT ORACLE — RE-OPEN AFTER CLOSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Close position fully, re-open, verify oracle tracks new debt correctly
    function test_fork_debtOracle_reopenAfterClose() public {
        // Open and close position
        _openPosition();
        _fullRepayAndWithdraw(executor);

        // Verify clean slate
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Debt should be 0 after close");

        // Re-open with different amount
        uint256 newCollateral = 5e18; // 5 WETH
        uint256 newBorrow = 1000e6; // 1000 USDC
        _fundWETH(address(executor), newCollateral);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(newCollateral));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(newBorrow));

        uint256 newDebt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(newDebt, newBorrow, "New debt should reflect re-opened position");
        assertLt(newDebt, BORROW_AMOUNT + 1e6, "New debt should be for the smaller borrow amount");

        console2.log("[reopen] New debt:", newDebt);
    }

    /// @notice Multiple close-reopen cycles
    function test_fork_debtOracle_multipleCycles() public {
        // Cycle 1
        _openPosition();
        assertGt(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Cycle 1: has debt");
        _fullRepayAndWithdraw(executor);
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Cycle 1: cleared");

        // Cycle 2
        _openPosition();
        assertGt(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Cycle 2: has debt");
        _fullRepayAndWithdraw(executor);
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Cycle 2: cleared");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 12: MULTI-ACCOUNT TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Two independent accounts with separate debt positions
    function test_fork_debtOracle_multipleAccounts_independentDebt() public {
        // Open position for executor1
        _openPositionFor(executor);

        // Open position for executor2 with different amounts
        _fundWETH(address(executor2), 5e18);
        executor2.executeHook(address(depositHook), address(0), _encodeDepositData(5e18));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(1000e6));

        // Each should have independent debt
        uint256 debt1 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 debt2 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor2));

        assertGe(debt1, BORROW_AMOUNT, "Executor 1 debt >= 2000 USDC");
        assertGe(debt2, 1000e6, "Executor 2 debt >= 1000 USDC");
        assertGt(debt1, debt2, "Executor 1 should have more debt");

        // Repay executor2's debt — should not affect executor1
        _fundUSDC(address(executor2), debt2 + 1e6);
        executor2.executeHook(address(repayHook), address(0), _encodeRepayData(0, true));

        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor2)), 0, "Executor 2 debt cleared");
        assertGe(
            debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)),
            BORROW_AMOUNT,
            "Executor 1 debt unaffected"
        );
    }

    /// @notice Batch query returns correct per-account debt
    function test_fork_debtOracle_multipleAccounts_batchQuery() public {
        _openPositionFor(executor);

        _fundWETH(address(executor2), 5e18);
        executor2.executeHook(address(depositHook), address(0), _encodeDepositData(5e18));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(500e6));

        address[] memory vaults = new address[](1);
        vaults[0] = EULER_USDC_VAULT;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](3);
        owners[0][0] = address(executor);
        owners[0][1] = address(executor2);
        owners[0][2] = address(0xdead);

        (uint256[][] memory tvls, bool[][] memory succeeded) =
            debtOracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        assertGe(tvls[0][0], BORROW_AMOUNT, "Executor 1 debt");
        assertTrue(succeeded[0][0]);
        assertGe(tvls[0][1], 500e6, "Executor 2 debt");
        assertTrue(succeeded[0][1]);
        assertEq(tvls[0][2], 0, "Dead address no debt");
        assertTrue(succeeded[0][2]);
    }

    /// @notice Interest accrual affects both accounts independently
    function test_fork_debtOracle_multipleAccounts_interestAccrual() public {
        _openPositionFor(executor);

        _fundWETH(address(executor2), 5e18);
        executor2.executeHook(address(depositHook), address(0), _encodeDepositData(5e18));
        executor2.executeHook(address(borrowHook), address(0), _encodeBorrowData(1000e6));

        uint256 debt1_day0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 debt2_day0 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor2));

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);

        uint256 debt1_day30 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 debt2_day30 = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor2));

        assertGt(debt1_day30, debt1_day0, "Account 1 debt accrues");
        assertGt(debt2_day30, debt2_day0, "Account 2 debt accrues");

        // Account with more debt should accrue more interest
        uint256 interest1 = debt1_day30 - debt1_day0;
        uint256 interest2 = debt2_day30 - debt2_day0;
        assertGt(interest1, interest2, "More debt = more interest");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 13: EDGE CASES — SMALL BORROW AMOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow minimum viable amount (100 USDC to stay healthy)
    function test_fork_debtOracle_smallBorrow() public {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));

        uint256 smallBorrow = 100e6; // 100 USDC
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(smallBorrow));

        uint256 debt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertGe(debt, smallBorrow, "Small borrow tracked correctly");
        assertEq(debt, IEVault(EULER_USDC_VAULT).debtOf(address(executor)));
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 14: EXISTING BORROWERS ON MAINNET
    //////////////////////////////////////////////////////////////*/

    /// @notice Query an address that already has debt on mainnet (real state)
    function test_fork_debtOracle_existingMainnetBorrower() public view {
        // The vault should have existing borrowers at this block
        uint256 totalBorrows = debtOracle.getTVL(EULER_USDC_VAULT);
        assertGt(totalBorrows, 0, "Vault should have existing borrows at fork block");

        // Verify cash < totalAssets (some assets are lent out)
        uint256 cash = IEVault(EULER_USDC_VAULT).cash();
        uint256 totalAssets = IERC4626(EULER_USDC_VAULT).totalAssets();
        assertLt(cash, totalAssets, "Cash should be less than totalAssets (borrows exist)");

        // totalBorrows should be significant relative to totalAssets
        assertGt(totalBorrows, totalAssets / 10, "Borrows should be > 10% of total assets (active vault)");
    }

    /// @notice debtOf for a non-borrower contract address returns 0
    function test_fork_debtOracle_contractNonBorrower() public view {
        // The oracle contract itself is not a borrower
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(debtOracle)), 0);
        assertEq(debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(supplyOracle)), 0);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 15: SAME VAULT — SUPPLY vs DEBT ORACLE READS
    //////////////////////////////////////////////////////////////*/

    /// @notice Same vault through both oracles — different methods, different results
    function test_fork_sameVault_supplyVsDebt_methodsDiffer() public view {
        // Supply oracle calls convertToAssets for PPS — varies with vault yield
        uint256 supplyPPS = supplyOracle.getPricePerShare(EULER_USDC_VAULT);
        // Debt oracle returns fixed 10^decimals
        uint256 debtPPS = debtOracle.getPricePerShare(EULER_USDC_VAULT);

        // Supply PPS should be >= debt PPS (vault has earned yield)
        assertGe(supplyPPS, debtPPS, "Supply PPS >= Debt PPS");

        // Supply TVL = totalAssets, Debt TVL = totalBorrows — always different
        uint256 supplyTVL = supplyOracle.getTVL(EULER_USDC_VAULT);
        uint256 debtTVL = debtOracle.getTVL(EULER_USDC_VAULT);
        assertGt(supplyTVL, debtTVL, "Supply TVL always > Debt TVL for active vault");
    }

    /// @notice Supply oracle getShareOutput != debt oracle getShareOutput (for USDC vault)
    function test_fork_sameVault_shareOutputDiffers() public view {
        uint256 amount = 1000e6;
        uint256 supplyShares = supplyOracle.getShareOutput(EULER_USDC_VAULT, USDC, amount);
        uint256 debtShares = debtOracle.getShareOutput(EULER_USDC_VAULT, USDC, amount);

        // Debt is identity
        assertEq(debtShares, amount);
        // Supply goes through previewDeposit — should return fewer shares (PPS > 1)
        assertLe(supplyShares, amount, "Supply shares <= input (PPS >= 1)");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 16: debtOf ROUNDS UP — CONSERVATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that debtOf rounds UP by checking debt >= borrow in same block
    function test_fork_debtOracle_debtOf_roundsUp() public {
        _fundWETH(address(executor), COLLATERAL_AMOUNT);
        executor.executeHook(address(depositHook), address(0), _encodeDepositData(COLLATERAL_AMOUNT));
        executor.executeHook(address(borrowHook), address(0), _encodeBorrowData(BORROW_AMOUNT));

        uint256 debt = debtOracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        // debtOf rounds UP, so debt >= borrow amount always
        assertGe(debt, BORROW_AMOUNT, "debtOf should round UP (conservative)");
    }
}

/*//////////////////////////////////////////////////////////////
                    INTERFACE HELPER
//////////////////////////////////////////////////////////////*/

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
