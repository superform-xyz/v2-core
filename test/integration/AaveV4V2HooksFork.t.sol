// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { ApproveERC20Hook } from "../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title IAaveV4SpokeQuery
/// @notice Interface for querying Aave V4 Spoke positions
interface IAaveV4SpokeQuery {
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
}

/// @title AaveV4V2HooksFork
/// @notice E2E fork tests for the V2 Aave V4 loan hooks against real mainnet contracts
/// @dev No mocks — uses SuperExecutor, SuperNativePaymaster, real Aave V4 Spoke, real tokens
contract AaveV4V2HooksFork is MinimalBaseIntegrationTest {
    AaveV4SupplyAndBorrowHookV2 public openHook;
    AaveV4RepayHookV2 public repayHook;
    AaveV4RepayAndWithdrawHookV2 public closeHook;
    ApproveERC20Hook public approveErc20Hook;
    ISuperNativePaymaster public superNativePaymaster;

    IAaveV4SpokeQuery public spoke;

    // Test with WETH as collateral, USDC as loan token on Main Spoke
    address public constant SPOKE_ADDR = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant WETH_RESERVE_ID = 0;
    uint256 public constant USDC_RESERVE_ID = 7;

    uint256 public constant SUPPLY_AMOUNT = 1 ether; // 1 WETH
    uint256 public constant BORROW_AMOUNT = 500e6; // 500 USDC
    uint256 public constant MAX = type(uint256).max;

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        openHook = new AaveV4SupplyAndBorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();
        approveErc20Hook = new ApproveERC20Hook();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        spoke = IAaveV4SpokeQuery(SPOKE_ADDR);

        // Fund account with WETH for collateral
        _getTokens(CHAIN_1_WETH, accountEth, 10 ether);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 241-byte Aave V4 V2 layout:
    ///      bytes32(0) | address(0) | loanToken(20) | collateralToken(20) | spoke(20) |
    ///      supplyReserveId(32) | borrowReserveId(32) | amount1(32) | amount2(32) | usePrevHookAmount(1)
    function _createDataWithReserves(
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 amount1,
        bool usePrevHookAmount,
        uint256 amount2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0), // yieldSourceOracleId (52-byte header: bytes 0-31)
            address(0), // yieldSource (52-byte header: bytes 32-51)
            CHAIN_1_USDC, // loanToken
            CHAIN_1_WETH, // collateralToken
            SPOKE_ADDR, // spoke
            supplyReserveId, // supplyReserveId (collateral reserve)
            borrowReserveId, // borrowReserveId (loan reserve)
            amount1, // open: supply; close/repay: repay
            amount2, // open: borrow; close: withdraw; repay: must be 0
            usePrevHookAmount
        );
    }

    /// @dev Open: amount1 = collateral supplied, amount2 = loan borrowed
    function _createOpenData(
        uint256 supplyAmount,
        bool usePrevHookAmount,
        uint256 borrowAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _createDataWithReserves(WETH_RESERVE_ID, USDC_RESERVE_ID, supplyAmount, usePrevHookAmount, borrowAmount_);
    }

    /// @dev Close: amount1 = repay (max = full debt), amount2 = withdraw (max = full supplied)
    function _createCloseData(
        uint256 repayAmount,
        bool usePrevHookAmount,
        uint256 withdrawAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return _createDataWithReserves(WETH_RESERVE_ID, USDC_RESERVE_ID, repayAmount, usePrevHookAmount, withdrawAmount);
    }

    /// @dev Standalone repay: amount1 = repay (max = full debt), amount2 word reserved as zero
    function _createRepayData(uint256 repayAmount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return _createDataWithReserves(WETH_RESERVE_ID, USDC_RESERVE_ID, repayAmount, usePrevHookAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _executeHook(address hook, bytes memory data) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = hook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = data;

        _executeHooks(hooksAddresses, hooksData);
    }

    function _executeHooks(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @dev Executes and asserts the userOp execution phase reverted with the expected custom
    ///      error, surfaced by the EntryPoint via the UserOperationRevertReason event
    function _executeHookExpectFailure(address hook, bytes memory data, bytes4 expectedSelector) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = hook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = data;

        _executeHooksExpectFailure(hooksAddresses, hooksData, expectedSelector);
    }

    function _executeHooksExpectFailure(
        address[] memory hooks,
        bytes[] memory data,
        bytes4 expectedSelector
    )
        internal
    {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory log = ret.logs[i];
            if (log.topics.length > 0 && log.topics[0] == revertTopic && _containsSelector(log.data, expectedSelector))
            {
                found = true;
                break;
            }
        }
        assertTrue(found, "Expected UserOperationRevertReason with the given error selector");
    }

    /// @dev True when the 4-byte selector appears anywhere in the revert-reason blob
    function _containsSelector(bytes memory blob, bytes4 selector) internal pure returns (bool) {
        if (blob.length < 4) return false;
        for (uint256 i; i <= blob.length - 4; ++i) {
            if (blob[i] == selector[0] && blob[i + 1] == selector[1] && blob[i + 2] == selector[2]
                && blob[i + 3] == selector[3]) {
                return true;
            }
        }
        return false;
    }

    /// @dev Opens the canonical position (1 WETH collateral, 500 USDC debt) used as setup by
    ///      close/repay tests
    function _openDefaultPosition() internal {
        _executeHook(address(openHook), _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT));
    }

    function _totalDebt() internal view returns (uint256) {
        (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        return drawnDebt + premiumDebt;
    }

    /*//////////////////////////////////////////////////////////////
                          OPEN (SUPPLY + BORROW)
    //////////////////////////////////////////////////////////////*/

    /// @notice Open exact: supply 1 WETH + borrow 500 USDC with exact wallet deltas
    function test_AaveV4V2_Open_Exact() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _openDefaultPosition();

        assertEq(
            wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "Should spend exact WETH amount"
        );
        assertEq(
            IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "Should receive exact USDC amount"
        );

        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        assertApproxEqAbs(supplied, SUPPLY_AMOUNT, 1, "Supplied should match supply amount");
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1, "Total debt (drawn + premium) should match borrow amount");
    }

    /// @notice Open chained with usePrevHookAmount: previous hook publishes WETH, open supplies it
    function test_AaveV4V2_Open_ChainedWithPrevHookAmount() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(openHook);

        bytes[] memory data = new bytes[](2);
        // ApproveERC20Hook publishes outToken = WETH, outAmount = SUPPLY_AMOUNT
        data[0] = _createApproveHookData(CHAIN_1_WETH, SPOKE_ADDR, SUPPLY_AMOUNT, false);
        // amount1 = 0 in calldata proves the previous hook's output is what gets supplied
        data[1] = _createOpenData(0, true, BORROW_AMOUNT);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHooks(hooks, data);

        assertEq(
            wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth),
            SUPPLY_AMOUNT,
            "Should supply exactly the previous hook's output amount"
        );
        assertEq(
            IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "Should receive exact USDC amount"
        );

        uint256 supplied = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        assertApproxEqAbs(supplied, SUPPLY_AMOUNT, 1, "Supplied should match previous hook amount");
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1, "Total debt should match borrow amount");
    }

    /// @notice Negative: previous hook publishes the wrong token (USDC != collateral WETH) —
    ///         PREV_TOKEN_MISMATCH reverts the whole userOp execution, state unchanged
    function test_AaveV4V2_Open_WrongPrevToken_StateUnchanged() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(openHook);

        bytes[] memory data = new bytes[](2);
        // Previous hook publishes outToken = USDC — not the collateral token the open expects
        data[0] = _createApproveHookData(CHAIN_1_USDC, SPOKE_ADDR, BORROW_AMOUNT, false);
        data[1] = _createOpenData(0, true, BORROW_AMOUNT);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHooksExpectFailure(hooks, data, bytes4(keccak256("PREV_TOKEN_MISMATCH()")));

        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "WETH balance should be unchanged");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "USDC balance should be unchanged");
        assertEq(spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth), 0, "No supply position should exist");
        assertEq(_totalDebt(), 0, "No debt position should exist");
    }

    /// @notice Negative: reserve ids that do not resolve to the declared tokens —
    ///         TOKEN_RESERVE_MISMATCH reverts the whole userOp execution, state unchanged
    function test_AaveV4V2_Open_ReserveMismatch_StateUnchanged() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        bytes4 mismatchSelector = bytes4(keccak256("TOKEN_RESERVE_MISMATCH()"));

        // borrowReserveId points at the WETH reserve while loanToken is declared as USDC
        _executeHookExpectFailure(
            address(openHook),
            _createDataWithReserves(WETH_RESERVE_ID, WETH_RESERVE_ID, SUPPLY_AMOUNT, false, BORROW_AMOUNT),
            mismatchSelector
        );

        // both ids swapped: the supply-side binding fails first
        _executeHookExpectFailure(
            address(openHook),
            _createDataWithReserves(USDC_RESERVE_ID, WETH_RESERVE_ID, SUPPLY_AMOUNT, false, BORROW_AMOUNT),
            mismatchSelector
        );

        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "WETH balance should be unchanged");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "USDC balance should be unchanged");
        assertEq(spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth), 0, "No supply position should exist");
        assertEq(_totalDebt(), 0, "No debt position should exist");
    }

    /*//////////////////////////////////////////////////////////////
                          CLOSE (REPAY + WITHDRAW)
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial close: repay 200 USDC + withdraw 0.3 WETH with exact wallet deltas
    function test_AaveV4V2_Close_Partial() external {
        _openDefaultPosition();

        uint256 repayAmount = 200e6;
        uint256 withdrawAmount = 0.3 ether;

        uint256 debtBefore = _totalDebt();
        uint256 suppliedBefore = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHook(address(closeHook), _createCloseData(repayAmount, false, withdrawAmount));

        assertEq(usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), repayAmount, "Should spend exact USDC");
        assertEq(
            IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, withdrawAmount, "Should receive exact WETH back"
        );

        assertApproxEqAbs(debtBefore - _totalDebt(), repayAmount, 1, "Debt should decrease by repay amount");
        assertApproxEqAbs(
            suppliedBefore - spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth),
            withdrawAmount,
            1,
            "Supplied should decrease by withdraw amount"
        );
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "USDC allowance should be reset");
    }

    /// @notice Full close after 30 days of interest accrual: amount1 = max, amount2 = max
    function test_AaveV4V2_Close_Full_AfterWarp() external {
        _openDefaultPosition();

        // Warp to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Fund extra USDC to cover accrued interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 50e6);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        _executeHook(address(closeHook), _createCloseData(MAX, false, MAX));

        (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(drawnDebt, 0, "Drawn debt should be zero after full repay");
        assertEq(premiumDebt, 0, "Premium debt should be zero after full repay");
        assertEq(spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth), 0, "Supplied should be zero");
        assertGt(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "Should receive collateral back");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "USDC allowance should be reset");
    }

    /*//////////////////////////////////////////////////////////////
                            STANDALONE REPAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone partial repay: exact wallet spend, allowance reset after
    function test_AaveV4V2_Repay_Partial() external {
        _openDefaultPosition();

        uint256 repayAmount = 150e6;
        uint256 debtBefore = _totalDebt();
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHook(address(repayHook), _createRepayData(repayAmount, false));

        assertEq(
            usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), repayAmount, "Should spend exact USDC amount"
        );
        assertApproxEqAbs(debtBefore - _totalDebt(), repayAmount, 1, "Debt should decrease by repay amount");
        assertGt(_totalDebt(), 0, "Should still have remaining debt");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "USDC allowance should be reset");
    }

    /// @notice Standalone full repay via max sentinel after interest accrual
    function test_AaveV4V2_Repay_FullViaMax() external {
        _openDefaultPosition();

        // Warp to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Fund extra USDC to cover accrued interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 50e6);

        assertGt(_totalDebt(), 0, "Debt should exist before repay");

        _executeHook(address(repayHook), _createRepayData(MAX, false));

        (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(drawnDebt, 0, "Drawn debt should be zero after full repay");
        assertEq(premiumDebt, 0, "Premium debt should be zero after full repay");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "USDC allowance should be reset");

        // Collateral remains untouched by the standalone repay
        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth),
            SUPPLY_AMOUNT,
            0.01 ether,
            "Supplied collateral should remain (plus supply interest)"
        );
    }

    /// @notice Negative: repaying with zero outstanding debt reverts at build-time inside the
    ///         executor call, so the userOp execution fails and state is unchanged
    function test_AaveV4V2_Repay_ZeroDebt_StateUnchanged() external {
        _getTokens(CHAIN_1_USDC, accountEth, 1000e6);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertEq(_totalDebt(), 0, "Precondition: no outstanding debt");

        _executeHookExpectFailure(
            address(repayHook), _createRepayData(100e6, false), bytes4(keccak256("NO_OUTSTANDING_DEBT()"))
        );

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "USDC balance should be unchanged");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "No allowance should have been set");
        assertEq(_totalDebt(), 0, "Still no debt");
    }
}
