// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { AaveV4SupplyHook } from "../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title IAaveV4SpokeQuery
/// @notice Interface for querying Aave V4 Spoke positions
interface IAaveV4SpokeQuery {
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
}

/// @title AaveV4HooksIntegrationTest
/// @notice E2E integration tests for Aave V4 hooks against real mainnet contracts
/// @dev No mocks — uses SuperExecutor, SuperNativePaymaster, real Aave V4 Spoke, real tokens
contract AaveV4HooksIntegrationTest is MinimalBaseIntegrationTest {
    AaveV4SupplyHook public supplyHook;
    AaveV4WithdrawHook public withdrawHook;
    AaveV4BorrowHook public borrowHook;
    AaveV4RepayHook public repayHook;
    AaveV4SupplyAndBorrowHook public supplyAndBorrowHook;
    AaveV4RepayAndWithdrawHook public repayAndWithdrawHook;
    ISuperNativePaymaster public superNativePaymaster;

    IAaveV4SpokeQuery public spoke;

    // Test with WETH as collateral, USDC as loan token on Main Spoke
    address public constant SPOKE_ADDR = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant WETH_RESERVE_ID = 0;
    uint256 public constant USDC_RESERVE_ID = 7;

    uint256 public constant SUPPLY_AMOUNT = 1 ether; // 1 WETH
    uint256 public constant BORROW_AMOUNT = 500e6; // 500 USDC

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        supplyHook = new AaveV4SupplyHook();
        withdrawHook = new AaveV4WithdrawHook();
        borrowHook = new AaveV4BorrowHook();
        repayHook = new AaveV4RepayHook();
        supplyAndBorrowHook = new AaveV4SupplyAndBorrowHook();
        repayAndWithdrawHook = new AaveV4RepayAndWithdrawHook();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        spoke = IAaveV4SpokeQuery(SPOKE_ADDR);

        // Fund account with WETH for collateral
        _getTokens(CHAIN_1_WETH, accountEth, 10 ether);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes data for supply/withdraw hooks:
    ///      loanToken(20) | collateralToken(20) | spoke(20) | supplyReserveId(32) | borrowReserveId(32) | amount(32) |
    /// usePrevHookAmount(1)
    function _createSupplyData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), // yieldSourceOracleId (52-byte header: bytes 0-31)
            address(0), // yieldSource (52-byte header: bytes 32-51)
            CHAIN_1_USDC, // loanToken
            CHAIN_1_WETH, // collateralToken
            SPOKE_ADDR, // spoke
            WETH_RESERVE_ID, // supplyReserveId (collateral reserve)
            USDC_RESERVE_ID, // borrowReserveId (unused for supply but part of layout)
            amount,
            usePrevHookAmount
        );
    }

    function _createWithdrawData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WETH, SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID, amount,
            usePrevHookAmount
        );
    }

    function _createBorrowData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WETH, SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID, amount,
            usePrevHookAmount
        );
    }

    function _createRepayData(
        uint256 amount,
        bool usePrevHookAmount,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            address(0),
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            SPOKE_ADDR,
            WETH_RESERVE_ID,
            USDC_RESERVE_ID,
            amount,
            usePrevHookAmount,
            isFullRepayment
        );
    }

    function _createSupplyAndBorrowData(
        uint256 supplyAmount,
        bool usePrevHookAmount,
        uint256 borrowAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            address(0),
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            SPOKE_ADDR,
            WETH_RESERVE_ID,
            USDC_RESERVE_ID,
            supplyAmount,
            usePrevHookAmount,
            borrowAmount_
        );
    }

    function _createRepayAndWithdrawData(
        uint256 repayAmount,
        bool usePrevHookAmount,
        bool isFullRepayment,
        uint256 withdrawAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            address(0),
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            SPOKE_ADDR,
            WETH_RESERVE_ID,
            USDC_RESERVE_ID,
            repayAmount,
            usePrevHookAmount,
            isFullRepayment,
            withdrawAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _executeHook(address hook, bytes memory data) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = hook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = data;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _executeHooks(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                         INDIVIDUAL HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply WETH as collateral via AaveV4SupplyHook
    function test_AaveV4_SupplyHook() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 suppliedAfter = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        assertEq(wethBefore - wethAfter, SUPPLY_AMOUNT, "Should spend exact WETH amount");
        assertGt(suppliedAfter, suppliedBefore, "Supply position should increase");
        assertApproxEqAbs(suppliedAfter - suppliedBefore, SUPPLY_AMOUNT, 1, "Supplied amount should match");
    }

    /// @notice Borrow USDC after supplying WETH collateral
    function test_AaveV4_BorrowHook_AfterSupply() external {
        // First supply collateral
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        // Borrow USDC
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        (uint256 drawnDebt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);

        assertEq(usdcAfter - usdcBefore, BORROW_AMOUNT, "Should receive exact USDC borrow amount");
        assertGt(drawnDebt, 0, "Should have debt on Aave V4");
    }

    /// @notice Partial repay after supply + borrow
    function test_AaveV4_RepayHook_PartialRepay() external {
        // Supply + borrow
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        (uint256 debtBefore,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        uint256 repayAmount = BORROW_AMOUNT / 2;

        // Partial repay
        _executeHook(address(repayHook), _createRepayData(repayAmount, false, false));

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertLt(debtAfter, debtBefore, "Debt should decrease after partial repay");
        assertGt(debtAfter, 0, "Should still have remaining debt");
    }

    /// @notice Full repay after supply + borrow + time passes
    function test_AaveV4_RepayHook_FullRepay() external {
        // Supply + borrow
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        // Warp to accrue interest
        vm.warp(block.timestamp + 7 days);

        // Fund extra USDC to cover interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);

        // Full repay
        _executeHook(address(repayHook), _createRepayData(0, false, true));

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debtAfter, 0, "Should have no debt after full repay");
    }

    /// @notice Withdraw WETH after supply (no active borrow)
    function test_AaveV4_WithdrawHook() external {
        // Supply collateral
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 withdrawAmount = SUPPLY_AMOUNT / 2;

        // Withdraw half
        _executeHook(address(withdrawHook), _createWithdrawData(withdrawAmount, false));

        uint256 suppliedAfter = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        assertApproxEqAbs(suppliedBefore - suppliedAfter, withdrawAmount, 1, "Supply position should decrease");
        assertApproxEqAbs(wethAfter - wethBefore, withdrawAmount, 1, "Should receive WETH back");
    }

    /*//////////////////////////////////////////////////////////////
                         COMBINED HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice SupplyAndBorrow in a single UserOp
    function test_AaveV4_SupplyAndBorrowHook() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHook(
            address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT)
        );

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertEq(wethBefore - wethAfter, SUPPLY_AMOUNT, "Should spend exact WETH for supply");
        assertEq(usdcAfter - usdcBefore, BORROW_AMOUNT, "Should receive exact USDC from borrow");

        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        (uint256 debt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);

        assertGt(supplied, 0, "Should have supply position");
        assertGt(debt, 0, "Should have debt position");
    }

    /// @notice RepayAndWithdraw in a single UserOp (partial)
    function test_AaveV4_RepayAndWithdrawHook_Partial() external {
        // Setup: supply + borrow
        _executeHook(
            address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT)
        );

        uint256 repayAmount = BORROW_AMOUNT / 2;
        uint256 withdrawAmount = SUPPLY_AMOUNT / 4;

        (uint256 debtBefore,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        // Partial repay + partial withdraw
        _executeHook(
            address(repayAndWithdrawHook),
            _createRepayAndWithdrawData(repayAmount, false, false, withdrawAmount)
        );

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        uint256 suppliedAfter = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        assertLt(debtAfter, debtBefore, "Debt should decrease");
        assertLt(suppliedAfter, suppliedBefore, "Supply should decrease");
    }

    /// @notice RepayAndWithdraw full repayment + full withdrawal
    function test_AaveV4_RepayAndWithdrawHook_Full() external {
        // Setup: supply + borrow
        _executeHook(
            address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT)
        );

        // Warp to accrue interest
        vm.warp(block.timestamp + 7 days);

        // Fund extra USDC to cover interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        // Full repay + full withdraw (type(uint256).max signals full for both)
        _executeHook(
            address(repayAndWithdrawHook),
            _createRepayAndWithdrawData(0, false, true, type(uint256).max)
        );

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        uint256 suppliedAfter = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        assertEq(debtAfter, 0, "Should have no debt after full repay");
        assertEq(suppliedAfter, 0, "Should have no supply after full withdraw");
        assertGt(wethAfter, wethBefore, "Should receive WETH back");
    }

    /*//////////////////////////////////////////////////////////////
                      CHAINED HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply + Borrow as separate hooks chained in single UserOp
    function test_AaveV4_ChainedSupplyThenBorrow() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);

        bytes[] memory data = new bytes[](2);
        data[0] = _createSupplyData(SUPPLY_AMOUNT, false);
        data[1] = _createBorrowData(BORROW_AMOUNT, false);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHooks(hooks, data);

        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "WETH spent");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "USDC received");

        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        (uint256 debt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertGt(supplied, 0, "Supply position exists");
        assertGt(debt, 0, "Debt position exists");
    }

    /*//////////////////////////////////////////////////////////////
                      FULL LIFECYCLE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: Supply → Borrow → time → Repay → Withdraw
    function test_AaveV4_FullLifecycle() external {
        // 1. Supply WETH
        uint256 wethStart = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        assertEq(wethStart - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "Step 1: WETH supplied");

        // 2. Borrow USDC
        uint256 usdcBeforeBorrow = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBeforeBorrow;
        assertEq(borrowed, BORROW_AMOUNT, "Step 2: USDC borrowed");

        // 3. Wait for interest
        vm.warp(block.timestamp + 30 days);

        // 4. Full repay (deal extra USDC for interest)
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 50e6);
        _executeHook(address(repayHook), _createRepayData(0, false, true));

        (uint256 debtAfterRepay,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debtAfterRepay, 0, "Step 4: No debt after full repay");

        // 5. Withdraw all collateral
        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 wethBeforeWithdraw = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(withdrawHook), _createWithdrawData(supplied, false));

        uint256 suppliedFinal = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        assertEq(suppliedFinal, 0, "Step 5: No supply position remaining");
        assertGt(
            IERC20(CHAIN_1_WETH).balanceOf(accountEth),
            wethBeforeWithdraw,
            "Step 5: WETH returned"
        );
    }

    /// @notice Full lifecycle using combined hooks: SupplyAndBorrow → time → RepayAndWithdraw
    function test_AaveV4_FullLifecycle_CombinedHooks() external {
        uint256 wethStart = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcStart = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        // 1. SupplyAndBorrow
        _executeHook(
            address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT)
        );

        assertEq(wethStart - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "WETH supplied");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcStart, BORROW_AMOUNT, "USDC borrowed");

        // 2. Wait for interest
        vm.warp(block.timestamp + 14 days);

        // 3. Deal extra USDC for interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);
        uint256 wethBeforeRepay = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        // 4. RepayAndWithdraw (full)
        _executeHook(
            address(repayAndWithdrawHook),
            _createRepayAndWithdrawData(0, false, true, type(uint256).max)
        );

        (uint256 finalDebt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        uint256 finalSupply = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        assertEq(finalDebt, 0, "No remaining debt");
        assertEq(finalSupply, 0, "No remaining supply");
        assertGt(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBeforeRepay, "WETH returned");
    }

    /// @notice Multiple supply operations accumulate position
    function test_AaveV4_MultipleSupplies() external {
        uint256 firstAmount = 0.5 ether;
        uint256 secondAmount = 0.3 ether;

        _executeHook(address(supplyHook), _createSupplyData(firstAmount, false));

        uint256 suppliedAfterFirst = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        assertApproxEqAbs(suppliedAfterFirst, firstAmount, 1, "First supply");

        _executeHook(address(supplyHook), _createSupplyData(secondAmount, false));

        uint256 suppliedAfterSecond = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        assertApproxEqAbs(suppliedAfterSecond, firstAmount + secondAmount, 2, "Supplies should accumulate");
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for AaveV4SupplyHook (AMOUNT_POSITION = 124)
    function test_AaveV4_Supply_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 1 ether;
        bytes memory hookData = _createSupplyData(originalAmount, false);

        assertEq(supplyHook.decodeAmounts(hookData)[0], originalAmount, "SupplyHook decodeAmount mismatch");

        uint256 newAmount = 0.5 ether;
        bytes memory replaced = supplyHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(supplyHook.decodeAmounts(replaced)[0], newAmount, "SupplyHook replaced amount mismatch");
        assertFalse(supplyHook.decodeUsePrevHookAmount(replaced), "usePrevHookAmount should be preserved");
    }

    /// @notice decodeAmount roundtrip for AaveV4WithdrawHook
    function test_AaveV4_Withdraw_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 0.5 ether;
        bytes memory hookData = _createWithdrawData(originalAmount, false);

        assertEq(withdrawHook.decodeAmounts(hookData)[0], originalAmount, "WithdrawHook decodeAmount mismatch");

        uint256 newAmount = 0.25 ether;
        bytes memory replaced = withdrawHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(withdrawHook.decodeAmounts(replaced)[0], newAmount, "WithdrawHook replaced amount mismatch");
    }

    /// @notice decodeAmount roundtrip for AaveV4BorrowHook
    function test_AaveV4_Borrow_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 500e6;
        bytes memory hookData = _createBorrowData(originalAmount, false);

        assertEq(borrowHook.decodeAmounts(hookData)[0], originalAmount, "BorrowHook decodeAmount mismatch");

        uint256 newAmount = 250e6;
        bytes memory replaced = borrowHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(borrowHook.decodeAmounts(replaced)[0], newAmount, "BorrowHook replaced amount mismatch");
    }

    /// @notice Supply: build with 1 WETH, replace to 0.5 WETH, execute, verify only 0.5 supplied
    function test_AaveV4_Supply_ReplaceCalldataAmounts_ExecutesCorrectly() external {
        uint256 originalAmount = 1 ether;
        uint256 newAmount = 0.5 ether;

        bytes memory hookData = _createSupplyData(originalAmount, false);
        bytes memory replaced = supplyHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        _executeHook(address(supplyHook), replaced);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);

        assertEq(wethBefore - wethAfter, newAmount, "Should spend exactly replaced amount");
        assertApproxEqAbs(supplied, newAmount, 1, "Supplied amount should match replaced amount");
    }
}
