// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";

// Aave V4 hooks
import { AaveV4SupplyHook } from "../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";

/// @notice Interface for querying Aave V4 Spoke positions
interface IAaveV4SpokeQuery {
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
}

/// @title AaveV4MultiReserveHooksIntegrationTest
/// @author Superform Labs
/// @notice Real-address integration tests for the Aave V4 loan-hook suite on a SECOND reserve pair.
/// @dev No mocks — SuperExecutor + SuperNativePaymaster through the real ERC-4337 UserOp flow, against
///      the real Aave V4 Main Spoke on Ethereum. The existing AaveV4HooksIntegrationTest only covers the
///      WETH-collateral/USDC-borrow pair; this suite exercises WBTC-collateral (reserve 3) /
///      USDC-borrow (reserve 7) to catch reserve-specific and decimal-specific (8-decimal collateral) issues.
contract AaveV4MultiReserveHooksIntegrationTest is MinimalBaseIntegrationTest {
    AaveV4SupplyHook public supplyHook;
    AaveV4WithdrawHook public withdrawHook;
    AaveV4BorrowHook public borrowHook;
    AaveV4RepayHook public repayHook;
    AaveV4SupplyAndBorrowHook public supplyAndBorrowHook;
    AaveV4RepayAndWithdrawHook public repayAndWithdrawHook;
    ISuperNativePaymaster public superNativePaymaster;

    IAaveV4SpokeQuery public spoke;

    // WBTC collateral / USDC borrow on the Main Spoke.
    address public constant SPOKE_ADDR = AAVE_V4_MAIN_SPOKE;
    uint256 public constant WBTC_RESERVE_ID = AAVE_V4_WBTC_RESERVE_ID; // 3
    uint256 public constant USDC_RESERVE_ID = AAVE_V4_USDC_RESERVE_ID; // 7

    uint256 public constant SUPPLY_AMOUNT = 1e8; // 1 WBTC (8 decimals)
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

        // Fund account with WBTC for collateral
        _getTokens(CHAIN_1_WBTC, accountEth, 10e8); // 10 WBTC
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Layout: yieldSourceOracleId(32) | yieldSource(20) | loanToken(20) | collateralToken(20) |
    ///      spoke(20) | supplyReserveId(32) | borrowReserveId(32) | amount(32) | usePrevHookAmount(1) [| extra]
    function _createSupplyData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount,
            usePrevHookAmount
        );
    }

    function _createWithdrawData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount,
            usePrevHookAmount
        );
    }

    function _createBorrowData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount,
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
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount,
            usePrevHookAmount, isFullRepayment
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
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID,
            supplyAmount, usePrevHookAmount, borrowAmount_
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
            bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WBTC, SPOKE_ADDR, WBTC_RESERVE_ID, USDC_RESERVE_ID,
            repayAmount, usePrevHookAmount, isFullRepayment, withdrawAmount
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
                              TEST CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply WBTC (8-decimal collateral) via AaveV4SupplyHook.
    function test_AaveV4_WBTC_Supply() external {
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth);

        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), SUPPLY_AMOUNT, "spent exact WBTC");
        uint256 suppliedAfter = spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth);
        assertApproxEqAbs(suppliedAfter - suppliedBefore, SUPPLY_AMOUNT, 1, "supplied WBTC recorded");
    }

    /// @notice Borrow USDC against WBTC collateral.
    function test_AaveV4_WBTC_Borrow_AfterSupply() external {
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "received USDC");
        (uint256 drawnDebt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertGt(drawnDebt, 0, "debt recorded");
    }

    /// @notice Partial repay reduces but does not clear the USDC debt.
    function test_AaveV4_WBTC_Repay_Partial() external {
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        (uint256 debtBefore,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        _executeHook(address(repayHook), _createRepayData(BORROW_AMOUNT / 2, false, false));

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertLt(debtAfter, debtBefore, "debt decreased");
        assertGt(debtAfter, 0, "residual debt remains");
    }

    /// @notice Full repay clears the USDC debt after interest accrual.
    function test_AaveV4_WBTC_Repay_Full() external {
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        vm.warp(block.timestamp + 7 days);
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);

        _executeHook(address(repayHook), _createRepayData(0, false, true));

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debtAfter, 0, "no debt after full repay");
    }

    /// @notice Withdraw WBTC collateral (no active borrow).
    function test_AaveV4_WBTC_Withdraw() external {
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));

        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        uint256 withdrawAmount = SUPPLY_AMOUNT / 2;

        _executeHook(address(withdrawHook), _createWithdrawData(withdrawAmount, false));

        assertApproxEqAbs(
            suppliedBefore - spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth), withdrawAmount, 1, "supply down"
        );
        assertApproxEqAbs(
            IERC20(CHAIN_1_WBTC).balanceOf(accountEth) - wbtcBefore, withdrawAmount, 1, "WBTC returned"
        );
    }

    /// @notice Supply + borrow via the combined hook in a single UserOp.
    function test_AaveV4_WBTC_SupplyAndBorrow() external {
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHook(address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT));

        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), SUPPLY_AMOUNT, "WBTC supplied");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "USDC borrowed");
        assertGt(spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth), 0, "supply position");
        (uint256 debt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertGt(debt, 0, "debt position");
    }

    /// @notice Full repay + full withdraw via the combined hook.
    function test_AaveV4_WBTC_RepayAndWithdraw_Full() external {
        _executeHook(address(supplyAndBorrowHook), _createSupplyAndBorrowData(SUPPLY_AMOUNT, false, BORROW_AMOUNT));

        vm.warp(block.timestamp + 7 days);
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);

        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        _executeHook(address(repayAndWithdrawHook), _createRepayAndWithdrawData(0, false, true, type(uint256).max));

        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debtAfter, 0, "no debt after full repay");
        assertEq(spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth), 0, "no supply after full withdraw");
        assertGt(IERC20(CHAIN_1_WBTC).balanceOf(accountEth), wbtcBefore, "WBTC returned");
    }

    /// @notice Supply + borrow as two chained hooks in one UserOp.
    function test_AaveV4_WBTC_ChainedSupplyBorrow() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createSupplyData(SUPPLY_AMOUNT, false);
        data[1] = _createBorrowData(BORROW_AMOUNT, false);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHooks(hooks, data);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "USDC received");
        assertGt(spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth), 0, "supplied");
        (uint256 debt,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertGt(debt, 0, "borrowed");
    }

    /// @notice Full lifecycle: supply -> borrow -> accrue -> full repay -> full withdraw.
    function test_AaveV4_WBTC_FullLifecycle() external {
        _executeHook(address(supplyHook), _createSupplyData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _createBorrowData(BORROW_AMOUNT, false));

        vm.warp(block.timestamp + 30 days);
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 20e6);

        _executeHook(address(repayHook), _createRepayData(0, false, true));
        (uint256 debtAfter,) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debtAfter, 0, "debt cleared");

        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        _executeHook(address(withdrawHook), _createWithdrawData(type(uint256).max, false));

        assertEq(spoke.getUserSuppliedAssets(WBTC_RESERVE_ID, accountEth), 0, "collateral fully withdrawn");
        assertGt(IERC20(CHAIN_1_WBTC).balanceOf(accountEth), wbtcBefore, "WBTC returned");
    }
}
