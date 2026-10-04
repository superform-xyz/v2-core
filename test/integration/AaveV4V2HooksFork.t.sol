// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { ApproveERC20Hook } from "../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { AaveV4SupplyHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { BaseAaveV4LoanHookV2 } from "../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { BaseAaveV4StandaloneLoanHookV2 } from "../../src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol";
import { BaseLoanHookV2 } from "../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { AaveV4ReserveKey } from "../../src/libraries/AaveV4ReserveKey.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../src/interfaces/ISuperHook.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";
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
    AaveV4SupplyHookV2 public pledgeHook;
    AaveV4BorrowHookV2 public borrowHook;
    AaveV4WithdrawHookV2 public releaseHook;
    AaveV4RedeemHook public idleRedeemHook;
    ApproveERC20Hook public approveErc20Hook;
    ISuperNativePaymaster public superNativePaymaster;

    IAaveV4SpokeQuery public spoke;

    // Test with WETH as collateral, USDC as loan token on Main Spoke
    address public constant SPOKE_ADDR = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant WETH_RESERVE_ID = 0;
    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant WBTC_RESERVE_ID = 3;
    uint256 public constant SUPPLY_WBTC = 5_000_000; // 0.05 WBTC (8 dp)
    bytes32 internal constant COLLATERAL_EVENT = keccak256("SetUsingAsCollateral(uint256,address,address,bool)");
    /// @dev Aave V4 Spoke `HealthFactorBelowThreshold()` — the only revert the standalone hooks delegate to the Spoke
    bytes4 internal constant HEALTH_FACTOR_BELOW_THRESHOLD = 0x851aedc1;

    uint256 public constant SUPPLY_AMOUNT = 1 ether; // 1 WETH
    uint256 public constant BORROW_AMOUNT = 500e6; // 500 USDC
    uint256 public constant MAX = type(uint256).max;

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        openHook = new AaveV4SupplyAndBorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();
        pledgeHook = new AaveV4SupplyHookV2();
        borrowHook = new AaveV4BorrowHookV2();
        releaseHook = new AaveV4WithdrawHookV2();
        idleRedeemHook = new AaveV4RedeemHook();
        approveErc20Hook = new ApproveERC20Hook();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        spoke = IAaveV4SpokeQuery(SPOKE_ADDR);

        // Fund account with WETH for collateral
        _getTokens(CHAIN_1_WETH, accountEth, 10 ether);
        _getTokens(CHAIN_1_WBTC, accountEth, 1e8);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 241-byte Aave V4 V2 layout:
    ///      yieldSourceOracleId(32) | reserveKey(20) | loanToken(20) | collateralToken(20) | spoke(20) |
    ///      supplyReserveId(32) | borrowReserveId(32) | amount1(32) | amount2(32) | usePrevHookAmount(1)
    /// @dev Supply-keyed header (OPEN / CLOSE / PLEDGE / RELEASE) on the WETH / USDC pair
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
        return _createDataWithTokens(
            CHAIN_1_USDC, CHAIN_1_WETH, supplyReserveId, borrowReserveId, amount1, usePrevHookAmount, amount2
        );
    }

    /// @dev SUP-21239 header: opaque oracle id + AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId,
    ///      borrowReserveId) at offset 32. No per-op primary reserve: every leg of a market carries one key.
    function _createDataWithTokens(
        address loanToken,
        address collateralToken,
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
            AAVE_V4_YS_ORACLE_ID, // yieldSourceOracleId (52-byte header: bytes 0-31) — identity only
            AaveV4ReserveKey.computeMarketKey(SPOKE_ADDR, supplyReserveId, borrowReserveId), // yieldSource (32-51)
            loanToken, // loanToken
            collateralToken, // collateralToken
            SPOKE_ADDR, // spoke
            supplyReserveId, // supplyReserveId (collateral reserve)
            borrowReserveId, // borrowReserveId (loan reserve)
            amount1, // open: supply; close/repay: repay; standalone: the single leg
            amount2, // open: borrow; close: withdraw; repay/standalone: must be 0
            usePrevHookAmount
        );
    }

    /// @dev Standalone (pledge / borrow / release) data on the WETH(0) / USDC(7) pair; secondary word zero
    function _standaloneData(uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return _createDataWithReserves(WETH_RESERVE_ID, USDC_RESERVE_ID, amount, usePrev, 0);
    }

    /// @dev Standalone BORROW data on the WETH(0) / USDC(7) pair — same market key as every other leg
    function _borrowData(uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return _createDataWithTokens(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, amount, usePrev, 0);
    }

    /// @dev Standalone PLEDGE / RELEASE data on the WBTC(3) / USDC(7) pair
    function _standaloneWbtcData(uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return _createDataWithTokens(CHAIN_1_USDC, CHAIN_1_WBTC, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount, usePrev, 0);
    }

    /// @dev Standalone BORROW data naming WBTC(3) as the (identity-only) collateral reserve
    function _borrowWbtcData(uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return _createDataWithTokens(CHAIN_1_USDC, CHAIN_1_WBTC, WBTC_RESERVE_ID, USDC_RESERVE_ID, amount, usePrev, 0);
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

    /// @dev Standalone repay: amount1 = repay (max = full debt), amount2 word reserved as zero; market-keyed
    function _createRepayData(uint256 repayAmount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return _createDataWithTokens(
            CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, repayAmount, usePrevHookAmount, 0
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

    function _executeHooksExpectFailure(address[] memory hooks, bytes[] memory data, bytes4 expectedSelector) internal {
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
            if (
                blob[i] == selector[0] && blob[i + 1] == selector[1] && blob[i + 2] == selector[2]
                    && blob[i + 3] == selector[3]
            ) {
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

    /// @notice Second open on the same reserve: proves setUsingAsCollateral is idempotent on the
    ///         real Spoke (the "already enabled" no-op path the hook relies on). If enabling an
    ///         already-collateral reserve reverted, this second supply+borrow would revert wholesale.
    function test_AaveV4V2_Open_SecondOnSameReserve_CollateralAlreadyEnabled() external {
        _openDefaultPosition(); // first open enables the WETH reserve as collateral

        uint256 suppliedAfterFirst = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth);
        uint256 debtAfterFirst = _totalDebt();

        // Second open on the same reserve — setUsingAsCollateral(true) is now a no-op
        _executeHook(address(openHook), _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT));

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, accountEth),
            suppliedAfterFirst + SUPPLY_AMOUNT,
            2,
            "second supply added collateral (idempotent enable did not revert)"
        );
        assertApproxEqAbs(_totalDebt(), debtAfterFirst + BORROW_AMOUNT, 2, "second borrow added debt");
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

        assertEq(usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), repayAmount, "Should spend exact USDC amount");
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

    /// @notice Repaying with zero outstanding debt SUCCEEDS as a no-op — the repay leg is
    ///         skipped, so a third-party gift repayment cannot cancel a signed intent
    function test_AaveV4V2_Repay_ZeroDebt_Graceful_NoOp() external {
        _getTokens(CHAIN_1_USDC, accountEth, 1000e6);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertEq(_totalDebt(), 0, "Precondition: no outstanding debt");

        _executeHook(address(repayHook), _createRepayData(100e6, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "USDC balance should be unchanged");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "No allowance should have been set");
        assertEq(_totalDebt(), 0, "Still no debt");
    }

    /// @notice Golden cap>debt: a non-sentinel cap above the total debt resolves to the debt —
    ///         cleared natively via repay(max), spend equals the debt, leftover stays in wallet
    function test_AaveV4V2_Repay_OverAmount_CapsToDebt() external {
        _openDefaultPosition();
        vm.warp(block.timestamp + 30 days);

        uint256 debt = _totalDebt();
        assertGt(debt, 0, "has debt");
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt * 2);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _executeHook(address(repayHook), _createRepayData(debt + 100e6, false));

        assertEq(usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), debt, "spend equals the resolved debt");
        assertEq(_totalDebt(), 0, "debt fully cleared, no dust");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0, "USDC allowance should be reset");
    }

    /*//////////////////////////////////////////////////////////////
                 STANDALONE HELPERS (SUP-21141)
    //////////////////////////////////////////////////////////////*/

    function _supplied(uint256 reserveId) internal view returns (uint256) {
        return spoke.getUserSuppliedAssets(reserveId, accountEth);
    }

    function _isCollateral(uint256 reserveId) internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(SPOKE_ADDR).getUserReserveStatus(reserveId, accountEth);
    }

    /// @dev Executes and returns the EntryPoint return data (for log inspection)
    function _executeHookRet(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = hook;
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = data;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _collateralEvents(ExecutionReturnData memory ret) internal pure returns (uint256 n) {
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == COLLATERAL_EVENT) ++n;
        }
    }

    /*//////////////////////////////////////////////////////////////
                    STANDALONE PLEDGE (AaveV4SupplyHookV2)
    //////////////////////////////////////////////////////////////*/

    function test_AaveV4V2_Pledge_Exact() external {
        assertFalse(_isCollateral(WETH_RESERVE_ID));
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        ExecutionReturnData memory ret = _executeHookRet(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));

        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "exact collateral spend");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1, "position == pledged");
        assertTrue(_isCollateral(WETH_RESERVE_ID), "reserve flagged as collateral");
        assertEq(_collateralEvents(ret), 1, "one SetUsingAsCollateral");
        assertEq(_totalDebt(), 0, "no debt created");
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0, "allowance reset");
    }

    /// @notice A previous hook producing the collateral token feeds the pledge; the amount word is ignored
    function test_AaveV4V2_Pledge_Chained_UsesPrevHookOutput() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(pledgeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_WETH, SPOKE_ADDR, SUPPLY_AMOUNT, false);
        data[1] = _standaloneData(1, true);
        _executeHooks(hooks, data);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "spend == prev output");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1);
        assertTrue(_isCollateral(WETH_RESERVE_ID), "flagged");
        assertEq(_totalDebt(), 0, "no debt");
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0, "allowance reset");
    }

    function test_AaveV4V2_Pledge_Chained_WrongPrevToken_StateUnchanged() external {
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(pledgeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_USDC, SPOKE_ADDR, BORROW_AMOUNT, false);
        data[1] = _standaloneData(1, true);
        _executeHooksExpectFailure(hooks, data, BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        assertEq(_supplied(WETH_RESERVE_ID), 0, "nothing pledged");
        assertFalse(_isCollateral(WETH_RESERVE_ID));
    }

    /// @notice Second pledge on the same reserve: the enable call is an idempotent no-op on the real Spoke
    function test_AaveV4V2_Pledge_SecondOnSameReserve_CollateralAlreadyEnabled() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 first = _supplied(WETH_RESERVE_ID);
        ExecutionReturnData memory ret = _executeHookRet(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), first + SUPPLY_AMOUNT, 2, "second pledge added collateral");
        assertTrue(_isCollateral(WETH_RESERVE_ID));
        assertEq(_collateralEvents(ret), 0, "already enabled: no event on the no-op");
    }

    /// @notice Pledging flips the per-(account, reserve) collateral flag; the idle MONEY_MARKET hooks then
    ///         refuse that reserve for this account by design (one mode per (account, reserve)).
    function test_AaveV4V2_Pledge_FlipsFlag_IdleRedeemRefuses() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        address key = address(uint160(uint256(keccak256(abi.encode(SPOKE_ADDR, WETH_RESERVE_ID)))));
        bytes memory idleData = abi.encodePacked(
            bytes32(uint256(1)), key, CHAIN_1_WETH, SPOKE_ADDR, WETH_RESERVE_ID, type(uint256).max, false
        );
        _executeHookExpectFailure(
            address(idleRedeemHook), idleData, BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1, "position untouched");
    }

    /*//////////////////////////////////////////////////////////////
                    STANDALONE BORROW (AaveV4BorrowHookV2)
    //////////////////////////////////////////////////////////////*/

    function test_AaveV4V2_Borrow_AfterPledge_Exact() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "exact loan receipt");
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1, "debt == borrowed");
    }

    /// @notice Pledge then borrow in one userOp reaches the same end state as the composite open
    function test_AaveV4V2_PledgeThenBorrow_OneUserOp() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _borrowData(BORROW_AMOUNT, false);
        _executeHooks(hooks, data);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT);
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1);
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);
    }

    function test_AaveV4V2_Borrow_ZeroAmount_Reverts() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHookExpectFailure(address(borrowHook), _borrowData(0, false), BaseHook.AMOUNT_NOT_VALID.selector);
        assertEq(_totalDebt(), 0, "no debt");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1, "collateral untouched");
    }

    /// @notice With no collateral the Spoke's own health check rejects the borrow: the hook adds no LTV logic
    function test_AaveV4V2_Borrow_NoCollateral_SpokeReverts() external {
        _executeHookExpectFailure(address(borrowHook), _borrowData(BORROW_AMOUNT, false), HEALTH_FACTOR_BELOW_THRESHOLD);
        assertEq(_totalDebt(), 0, "no debt");
    }

    /*//////////////////////////////////////////////////////////////
                   STANDALONE RELEASE (AaveV4WithdrawHookV2)
    //////////////////////////////////////////////////////////////*/

    function test_AaveV4V2_Release_ExactPartial() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(0.3 ether, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.3 ether, "exact receipt");
        // receipt is exact; the position consumed may differ by supply round-down + withdraw share rounding (<= 2 wei)
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT - 0.3 ether, 2, "position reduced within rounding");
    }

    function test_AaveV4V2_Release_MaxSentinel_FullCollateral() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "full position paid exactly");
        assertEq(_supplied(WETH_RESERVE_ID), 0, "position fully released");
        // The hook never toggles the flag: it stays TRUE after a full withdrawal on the live Spoke
        assertTrue(_isCollateral(WETH_RESERVE_ID), "collateral flag stays true after a full release");
    }

    function test_AaveV4V2_Release_MaxSentinel_AfterWarp_PaysAccrued() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        vm.warp(block.timestamp + 30 days);
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        assertGe(supplied, SUPPLY_AMOUNT - 1, "accrued (or flat) position");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "pre-read position paid exactly");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    function test_AaveV4V2_Release_EmptyPosition_Reverts() external {
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(type(uint256).max, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(1 ether, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
    }

    /// @notice Aave would silently turn an over-withdrawal into a full one; the hook refuses it first. This includes
    ///         the exact pledged word: the supply credit rounds down (1 wei for this amount; exchange-rate dependent,
    ///         see the CreditRoundDown regression), so "release exactly what I pledged" is above the position in the
    ///         same block — size from getUserSuppliedAssets or use the max sentinel.
    function test_AaveV4V2_Release_ExactAboveSupplied_Reverts() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        assertEq(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT - 1, "observed 1-wei shortfall for 1 WETH at this block");
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(SUPPLY_AMOUNT, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(2 ether, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT - 1, "state unchanged");
    }

    /// @notice Releasing most of the collateral with debt open passes the hook (amount <= supplied) and fails the
    ///         Spoke's health check — no LTV logic in the hook. (The full position is 1 wei below SUPPLY_AMOUNT after
    ///         the supply round-down, so an exact SUPPLY_AMOUNT word would be refused by the hook first.)
    function test_AaveV4V2_Release_Undercollateralized_SpokeHealthCheckReverts() external {
        _openDefaultPosition();
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(0.9 ether, false), HEALTH_FACTOR_BELOW_THRESHOLD
        );
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1, "collateral untouched");
    }

    /// @notice An exact word equal to the whole position pays it all, same as the sentinel (same virtual index,
    ///         same block)
    function test_AaveV4V2_Release_ExactEqualsSupplied_PaysAll() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(supplied, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "exact == supplied pays all");
        assertEq(_supplied(WETH_RESERVE_ID), 0, "position fully released");
    }

    /// @notice One mode per (account, reserve), enforced on-chain both ways: a position supplied WITHOUT the
    ///         collateral flag (the idle MONEY_MARKET side) is refused by PLEDGE and by RELEASE before any Spoke call
    function test_AaveV4V2_Standalone_UnflaggedPosition_RefusedByPledgeAndRelease() external {
        // idle-style supply straight from the account: supplied > 0, flag false
        vm.startPrank(accountEth);
        IERC20(CHAIN_1_WETH).approve(SPOKE_ADDR, SUPPLY_AMOUNT);
        IAaveV4Spoke(SPOKE_ADDR).supply(WETH_RESERVE_ID, SUPPLY_AMOUNT, accountEth);
        vm.stopPrank();
        assertFalse(_isCollateral(WETH_RESERVE_ID));
        uint256 before = _supplied(WETH_RESERVE_ID);
        assertGt(before, 0);

        _executeHookExpectFailure(
            address(pledgeHook),
            _standaloneData(SUPPLY_AMOUNT, false),
            BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector
        );
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(type(uint256).max, false),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(0.3 ether, false),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), before, "idle position untouched");
        assertFalse(_isCollateral(WETH_RESERVE_ID), "flag untouched");
    }

    function test_AaveV4V2_Standalone_ReserveMismatch_StateUnchanged() external {
        // header keyed consistently with the swapped body (supply id for PLEDGE / RELEASE, borrow id for BORROW), so
        // the live Spoke binding is what refuses the payload
        bytes memory swapped = _createDataWithReserves(USDC_RESERVE_ID, WETH_RESERVE_ID, SUPPLY_AMOUNT, false, 0);
        bytes memory swappedB = _createDataWithTokens(
            CHAIN_1_USDC, CHAIN_1_WETH, USDC_RESERVE_ID, WETH_RESERVE_ID, SUPPLY_AMOUNT, false, 0
        );
        _executeHookExpectFailure(address(pledgeHook), swapped, BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        _executeHookExpectFailure(address(borrowHook), swappedB, BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        _executeHookExpectFailure(address(releaseHook), swapped, BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_totalDebt(), 0);
    }

    /// @notice pledge -> borrow -> repay(max) -> release(max) ends exactly where open -> close does
    function test_AaveV4V2_StandaloneTrio_FullLifecycleParity() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _borrowData(BORROW_AMOUNT, false);
        _executeHooks(hooks, data);

        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(repayHook), _createRepayData(type(uint256).max, false));
        assertEq(_totalDebt(), 0, "debt cleared");

        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0, "collateral fully released");
        // supply round-down (1 wei observed here; exchange-rate dependent) + partial-withdraw share rounding
        assertApproxEqAbs(
            IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, 2, "WETH back within 2 wei of rounding"
        );
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0);
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0);
    }

    /// @notice Two collateral reserves (WETH 0, WBTC 3) sharing one borrow reserve (USDC 7), released
    ///         independently around the debt
    function test_AaveV4V2_TwoCollaterals_OneBorrow_Lifecycle() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);

        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(pledgeHook), _standaloneWbtcData(SUPPLY_WBTC, false));
        assertTrue(_isCollateral(WETH_RESERVE_ID) && _isCollateral(WBTC_RESERVE_ID));
        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), SUPPLY_WBTC, "exact WBTC spend");

        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);

        // Release the WBTC leg entirely: 1 WETH alone keeps 500 USDC healthy
        _executeHook(address(releaseHook), _standaloneWbtcData(type(uint256).max, false));
        assertEq(_supplied(WBTC_RESERVE_ID), 0, "WBTC leg released");
        assertApproxEqAbs(IERC20(CHAIN_1_WBTC).balanceOf(accountEth), wbtcBefore, 1, "WBTC back");

        // Partial WETH release with debt still open (stays healthy)
        _executeHook(address(releaseHook), _standaloneData(0.3 ether, false));
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT - 0.3 ether, 2);

        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(repayHook), _createRepayData(type(uint256).max, false));
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_totalDebt(), 0);
        // supply round-down (1 wei observed here; exchange-rate dependent) + partial-withdraw share rounding
        assertApproxEqAbs(
            IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, 2, "WETH back within 2 wei of rounding"
        );
    }

    /// @notice With both collaterals pledged and debt open, releasing the LAST collateral leg fails the
    ///         Spoke's health check while the first release (WETH) succeeds
    function test_AaveV4V2_TwoCollaterals_ReleaseLast_WithDebt_Reverts() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(pledgeHook), _standaloneWbtcData(SUPPLY_WBTC, false));
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));

        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false)); // WBTC alone backs 500 USDC
        assertEq(_supplied(WETH_RESERVE_ID), 0);

        _executeHookExpectFailure(
            address(releaseHook), _standaloneWbtcData(type(uint256).max, false), HEALTH_FACTOR_BELOW_THRESHOLD
        );
        assertApproxEqAbs(_supplied(WBTC_RESERVE_ID), SUPPLY_WBTC, 1, "WBTC untouched: health check blocked it");
    }

    /*//////////////////////////////////////////////////////////////
                   STANDALONE CHAINING THROUGH THE REAL PIPE
    //////////////////////////////////////////////////////////////*/

    /// @notice A previous hook producing the LOAN token sizes the borrow; the calldata word is ignored and the
    ///         exact prev amount is received
    function test_AaveV4V2_Borrow_Chained_UsesPrevHookOutput() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_USDC, SPOKE_ADDR, 300e6, false);
        data[1] = _borrowData(1, true);
        _executeHooks(hooks, data);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, 300e6, "receipt == prev output");
        assertApproxEqAbs(_totalDebt(), 300e6, 1, "debt == prev output");
    }

    /// @notice A previous hook producing the COLLATERAL token sizes the release; the max word is ignored
    function test_AaveV4V2_Release_Chained_UsesPrevHookOutput_IgnoresMaxWord() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(releaseHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_WETH, SPOKE_ADDR, 0.3 ether, false);
        data[1] = _standaloneData(type(uint256).max, true);
        _executeHooks(hooks, data);
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.3 ether, "partial, not full");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT - 0.3 ether, 2, "position kept");
    }

    /// @notice Wrong-token feeders are refused before any Spoke call on BORROW and RELEASE (mirror of the pledge
    ///         case): WETH into BORROW, USDC into RELEASE — state unchanged
    function test_AaveV4V2_BorrowRelease_Chained_WrongPrevToken_StateUnchanged() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        bytes[] memory data = new bytes[](2);

        hooks[1] = address(borrowHook);
        data[0] = _createApproveHookData(CHAIN_1_WETH, SPOKE_ADDR, 1 ether, false);
        data[1] = _borrowData(1, true);
        _executeHooksExpectFailure(hooks, data, BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        assertEq(_totalDebt(), 0, "no debt");

        hooks[1] = address(releaseHook);
        data[0] = _createApproveHookData(CHAIN_1_USDC, SPOKE_ADDR, 1e6, false);
        data[1] = _standaloneData(1, true);
        _executeHooksExpectFailure(hooks, data, BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "collateral untouched");
    }

    /// @notice release(max) -> pledge(usePrev) in one userOp: the released collateral is re-pledged exactly through
    ///         the real pipe (RELEASE publishes its measured wallet delta as the product)
    function test_AaveV4V2_ReleaseThenRepledge_OneUserOp_RoundTrips() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(releaseHook);
        hooks[1] = address(pledgeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _standaloneData(type(uint256).max, false);
        data[1] = _standaloneData(1, true);
        _executeHooks(hooks, data);
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "wallet net zero: released == re-pledged");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), supplied, 2, "position restored within rounding");
        assertTrue(_isCollateral(WETH_RESERVE_ID));
    }

    /// @notice PLEDGE is terminal on the live Spoke too: a same-token usePrev consumer (RELEASE) chained off it fails
    ///         closed on the zero output, a different-token one (BORROW) on the token check, and in both cases the
    ///         whole userOp reverts — nothing pledged
    function test_AaveV4V2_Pledge_AsPrevHook_FailsClosed_StateUnchanged() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(pledgeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _standaloneData(1, true);

        hooks[1] = address(releaseHook);
        _executeHooksExpectFailure(hooks, data, BaseHook.AMOUNT_NOT_VALID.selector);
        assertEq(_supplied(WETH_RESERVE_ID), 0, "pledge rolled back with the userOp");
        assertFalse(_isCollateral(WETH_RESERVE_ID));

        hooks[1] = address(borrowHook);
        data[1] = _borrowData(1, true);
        _executeHooksExpectFailure(hooks, data, BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_totalDebt(), 0);
    }

    /// @notice A pledge above the wallet balance is refused by the token inside the userOp; the hook's pre-flight
    ///         does not read the wallet, so the failure is the transfer's, and state is unchanged
    function test_AaveV4V2_Pledge_InsufficientWallet_StateUnchanged() external {
        uint256 bal = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(pledgeHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _standaloneData(bal + 1, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
        // WETH9 reverts with empty data, so the EntryPoint emits no UserOperationRevertReason; read the
        // success flag of UserOperationEvent instead
        bytes32 opTopic = keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)");
        bool seen;
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == opTopic) {
                (, bool success,,) = abi.decode(ret.logs[i].data, (uint256, bool, uint256, uint256));
                assertFalse(success, "userOp execution must have reverted");
                seen = true;
            }
        }
        assertTrue(seen, "UserOperationEvent emitted");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), bal, "wallet untouched");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertFalse(_isCollateral(WETH_RESERVE_ID));
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0, "no dangling allowance");
    }

    /// @notice Two borrows accumulate debt exactly; a borrow above what the collateral supports fails the Spoke's
    ///         health check and leaves the first borrow's debt as it was
    function test_AaveV4V2_Borrow_Twice_ThenOverBorrow_SpokeReverts() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        uint256 debt = _totalDebt();
        assertApproxEqAbs(debt, 2 * BORROW_AMOUNT, 2, "debt accumulates");
        // 1 WETH cannot back 1000 + 50_000 USDC
        _executeHookExpectFailure(address(borrowHook), _borrowData(50_000e6, false), HEALTH_FACTOR_BELOW_THRESHOLD);
        assertEq(_totalDebt(), debt, "debt unchanged after the refused borrow");
    }

    /// @notice Sizing rewrite on the live Spoke: a payload rewritten by replaceCalldataAmounts executes with the
    ///         rewritten amount (the sizer-facing view and execution agree on the same byte)
    function test_AaveV4V2_Standalone_ReplacedPayload_ExecutesRewrittenAmount() external {
        uint256[] memory one = new uint256[](1);
        one[0] = 0.4 ether;
        bytes memory rewritten = pledgeHook.replaceCalldataAmounts(_standaloneData(SUPPLY_AMOUNT, false), one);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(pledgeHook), rewritten);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), 0.4 ether, "rewritten amount pledged");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), 0.4 ether, 1);
    }

    /*//////////////////////////////////////////////////////////////
                STANDALONE: CATALOG GAPS (post-review additions)
    //////////////////////////////////////////////////////////////*/

    /// @notice BORROW's published output is the exact USDC delta with outToken = USDC: a REPAY(usePrev) consumer in the
    ///         same userOp clears exactly what was borrowed, so the wallet nets to zero and the debt to zero
    function test_AaveV4V2_PledgeBorrowRepay_OneUserOp_BorrowOutputFeedsRepay() external {
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](3);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(borrowHook);
        hooks[2] = address(repayHook);
        bytes[] memory data = new bytes[](3);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _borrowData(BORROW_AMOUNT, false);
        data[2] = _createRepayData(1, true); // cap word ignored: the cap IS the borrowed delta
        _executeHooks(hooks, data);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "borrowed == repaid");
        // the cap is the exact wallet receipt; the debt carries <= 2 wei of index rounding above it, which the
        // capped repay leaves behind (min(cap, debt) semantics — never over-pulls the wallet)
        assertApproxEqAbs(_totalDebt(), 0, 2, "debt reduced to rounding dust in the same block");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), SUPPLY_AMOUNT, 1, "collateral stays pledged");
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0);
    }

    /// @notice A previous-hook output above the position is refused by RELEASE before any Spoke call (prev path of the
    ///         over-withdrawal guard on the live Spoke)
    function test_AaveV4V2_Release_Chained_PrevAboveSupplied_Reverts_StateUnchanged() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(releaseHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_WETH, SPOKE_ADDR, 2 ether, false);
        data[1] = _standaloneData(0, true);
        _executeHooksExpectFailure(hooks, data, BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector);
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched");
    }

    /// @notice Fourth cell of the (flag, supplied) table on the live Spoke: after a full RELEASE the flag stays true
    ///         and the position is empty — a new PLEDGE is accepted (not mistaken for an idle position) and the
    ///         enable call is a silent no-op
    function test_AaveV4V2_Pledge_AfterFullRelease_RepledgeAllowed() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertTrue(_isCollateral(WETH_RESERVE_ID));
        ExecutionReturnData memory ret = _executeHookRet(address(pledgeHook), _standaloneData(0.5 ether, false));
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), 0.5 ether, 1, "re-pledged");
        assertEq(_collateralEvents(ret), 0, "flag already true: no event");
    }

    /// @notice Documented trade-off: an account that manually disables the collateral flag on a PLEDGED reserve turns
    ///         it into an idle-looking position — RELEASE and further PLEDGE are refused (the hooks never repair the
    ///         flag) until the account re-enables it, after which RELEASE works again
    function test_AaveV4V2_ManualFlagOff_BlocksReleaseAndPledge_UntilReenabled() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, false, accountEth);
        assertFalse(_isCollateral(WETH_RESERVE_ID));

        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(type(uint256).max, false),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        _executeHookExpectFailure(
            address(pledgeHook),
            _standaloneData(0.1 ether, false),
            BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched");
        assertFalse(_isCollateral(WETH_RESERVE_ID), "hooks never toggled the flag");

        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, true, accountEth);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "released after re-enable");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /// @notice Zero / sentinel words on PLEDGE and RELEASE are refused before any Spoke call on the live Spoke, state
    ///         unchanged (BORROW zero is covered above)
    function test_AaveV4V2_PledgeRelease_ZeroAndMaxWords_Reverts_StateUnchanged() external {
        _executeHookExpectFailure(address(pledgeHook), _standaloneData(0, false), BaseHook.AMOUNT_NOT_VALID.selector);
        _executeHookExpectFailure(
            address(pledgeHook), _standaloneData(type(uint256).max, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        _executeHookExpectFailure(
            address(borrowHook), _borrowData(type(uint256).max, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertFalse(_isCollateral(WETH_RESERVE_ID));
        assertEq(_totalDebt(), 0);

        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        _executeHookExpectFailure(address(releaseHook), _standaloneData(0, false), BaseHook.AMOUNT_NOT_VALID.selector);
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched");
    }

    /// @notice Documented residual (final security pass P3-A): the flag can still be set over an un-flagged idle
    ///         position by a direct self-call (and by the PRE-SUP-21143 deployed OPEN V2 / V1 supply hooks, which
    ///         carry no idle guard; the recompiled ones do). RELEASE keys LOAN mode on the flag alone, so it then
    ///         pays the merged position out — this pins WHY the OMS routing rule exists for the manual path
    function test_AaveV4V2_Release_ManualFlagOverIdlePosition_PaysOut_Residual() external {
        vm.startPrank(accountEth);
        IERC20(CHAIN_1_WETH).approve(SPOKE_ADDR, SUPPLY_AMOUNT);
        IAaveV4Spoke(SPOKE_ADDR).supply(WETH_RESERVE_ID, SUPPLY_AMOUNT, accountEth); // idle-style, un-flagged
        vm.stopPrank();
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(type(uint256).max, false),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, true, accountEth); // flag flipped outside PLEDGE
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "idle position paid out by RELEASE");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /*//////////////////////////////////////////////////////////////
                STANDALONE: THIRD PASS (executor-level edges)
    //////////////////////////////////////////////////////////////*/

    /// @notice The same PLEDGE contract twice in one userOp (WETH then WBTC) plus a BORROW: plain transient slots are
    ///         re-snapshotted per hook run, both legs settle exactly and both flags flip
    function test_AaveV4V2_SameHookTwice_OneUserOp_TwoCollaterals_ThenBorrow() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](3);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(pledgeHook);
        hooks[2] = address(borrowHook);
        bytes[] memory data = new bytes[](3);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _standaloneWbtcData(SUPPLY_WBTC, false);
        data[2] = _borrowData(BORROW_AMOUNT, false);
        ExecutionReturnData memory ret = _executeHooksRet(hooks, data);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT, "WETH leg exact");
        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), SUPPLY_WBTC, "WBTC leg exact");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT, "borrow exact");
        assertTrue(_isCollateral(WETH_RESERVE_ID) && _isCollateral(WBTC_RESERVE_ID));
        assertEq(_collateralEvents(ret), 2, "one enable event per reserve");
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0);
        assertEq(IERC20(CHAIN_1_WBTC).allowance(accountEth, SPOKE_ADDR), 0);
    }

    /// @notice Self-chaining a producing hook into itself (BORROW -> BORROW(usePrev)) fails closed under the real
    ///         executor: the executor opens a fresh execution context for the second run before build, so the pipe
    ///         reads an empty output slot (outToken == address(0)) and rejects it with PREV_TOKEN_MISMATCH; the whole
    ///         userOp reverts — no debt at all
    function test_AaveV4V2_SelfChain_UsePrev_FailsClosed_StateUnchanged() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        address[] memory hooks = new address[](2);
        hooks[0] = address(borrowHook);
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _borrowData(BORROW_AMOUNT, false);
        data[1] = _borrowData(1, true);
        _executeHooksExpectFailure(hooks, data, BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        assertEq(_totalDebt(), 0, "first borrow rolled back with the userOp");
    }

    /// @notice A second RELEASE(max) after a full release is refused on the empty position (any dust shares round to a
    ///         zero position and are unreachable by the hook)
    function test_AaveV4V2_Release_Twice_SecondRefused() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(type(uint256).max, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        _executeHookExpectFailure(address(releaseHook), _standaloneData(1, false), BaseHook.AMOUNT_NOT_VALID.selector);
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "nothing paid twice");
    }

    /// @notice After 30 days of accrual (drawn + premium debt) a second exact BORROW still receives exactly its word
    ///         and RELEASE(exact = accrued position) still pays exactly; no hook arithmetic depends on the index
    function test_AaveV4V2_AfterAccrual_ExactWordsStayExact() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        vm.warp(block.timestamp + 30 days);
        uint256 debtBefore = _totalDebt();
        assertGe(debtBefore, BORROW_AMOUNT, "debt accrued or flat");
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), _borrowData(100e6, false));
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, 100e6, "exact second borrow");
        assertApproxEqAbs(_totalDebt(), debtBefore + 100e6, 2, "debt grew by the borrow (+ index dust)");
        // release a partial exact slice sized from the live position
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 slice = supplied / 10;
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(slice, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, slice, "exact partial after accrual");
    }

    /// @notice 8-decimal collateral (WBTC): at this block and amount the supply credit round-down is 1 unit (share
    ///         round-trip rounding; NOT a universal bound — see the regression test below) and RELEASE(max) returns
    ///         exactly the credited position — decimals do not change the hook's exactness
    function test_AaveV4V2_Wbtc_RoundDownAtMostOne_ReleaseMaxExact() external {
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        _executeHook(address(pledgeHook), _standaloneWbtcData(SUPPLY_WBTC, false));
        uint256 supplied = _supplied(WBTC_RESERVE_ID);
        assertLe(SUPPLY_WBTC - supplied, 1, "observed credit shortfall at this block / amount");
        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), SUPPLY_WBTC, "spend exact");
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneWbtcData(SUPPLY_WBTC, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        _executeHook(address(releaseHook), _standaloneWbtcData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WBTC).balanceOf(accountEth), wbtcBefore - (SUPPLY_WBTC - supplied), "back minus dust");
        assertEq(_supplied(WBTC_RESERVE_ID), 0);
    }

    /// @notice BORROW's supplyReserveId is identity only: naming an un-flagged, empty reserve (WBTC) as the collateral
    ///         identity while WETH backs the position still borrows — the health check spans every flagged reserve
    function test_AaveV4V2_Borrow_SupplyIdIsIdentityOnly() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        assertEq(_supplied(WBTC_RESERVE_ID), 0);
        assertFalse(_isCollateral(WBTC_RESERVE_ID));
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), _borrowWbtcData(BORROW_AMOUNT, false));
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW_AMOUNT);
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);
        assertFalse(_isCollateral(WBTC_RESERVE_ID), "identity reserve untouched");
    }

    /// @notice Sizing rewrites execute with the rewritten amount on BORROW and RELEASE too (PLEDGE covered above)
    function test_AaveV4V2_BorrowRelease_ReplacedPayloads_ExecuteRewrittenAmounts() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256[] memory one = new uint256[](1);
        one[0] = 250e6;
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(borrowHook), borrowHook.replaceCalldataAmounts(_borrowData(1, false), one));
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, 250e6, "rewritten borrow");
        one[0] = 0.25 ether;
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), releaseHook.replaceCalldataAmounts(_standaloneData(1, false), one));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.25 ether, "rewritten release");
    }

    /// @dev Multi-hook variant of _executeHookRet
    function _executeHooksRet(
        address[] memory hooks,
        bytes[] memory data
    )
        internal
        returns (ExecutionReturnData memory)
    {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
        LIQUIDATION PATH (mocked WETH price feed, real liquidationCall)
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant LIQ_PLEDGE = 5 ether;
    uint256 internal constant LIQ_BORROW = 4000e6;

    /// @dev Swaps the WETH reserve's price feed through the Spoke's `restricted` admin path (AccessManager `canCall`
    ///      mocked) to an 8-decimal mock returning `price`; returns the original feed so it can be restored
    function _setWethPrice(int256 price) internal returns (address original) {
        address oracle = IAaveV4SpokeAdmin(SPOKE_ADDR).ORACLE();
        original = IAaveOracleLike(oracle).getReserveSource(WETH_RESERVE_ID);
        MockPriceFeed feed = new MockPriceFeed(price);
        address authority = IAaveV4SpokeAdmin(SPOKE_ADDR).authority();
        vm.mockCall(authority, abi.encodeWithSelector(0xb7009613), abi.encode(true, uint32(0)));
        IAaveV4SpokeAdmin(SPOKE_ADDR).updateReservePriceSource(WETH_RESERVE_ID, address(feed));
        vm.clearMockedCalls();
    }

    function _restoreWethPrice(address original) internal {
        address authority = IAaveV4SpokeAdmin(SPOKE_ADDR).authority();
        vm.mockCall(authority, abi.encodeWithSelector(0xb7009613), abi.encode(true, uint32(0)));
        IAaveV4SpokeAdmin(SPOKE_ADDR).updateReservePriceSource(WETH_RESERVE_ID, original);
        vm.clearMockedCalls();
    }

    /// @notice Liquidation between signing and execution: a WETH price drop makes the pledged position liquidatable,
    ///         a third party liquidates part of it (position shrinks, flag stays), and the SIGNED exact release word
    ///         sized before the liquidation is refused with the typed error naming the live position — no silent full
    ///         withdrawal. After the price recovers and the debt is repaid, RELEASE(max) pays the remainder exactly.
    function test_AaveV4V2_Liquidation_StaleReleaseTyped_MaxPaysRemainder() external {
        _executeHook(address(pledgeHook), _standaloneData(LIQ_PLEDGE, false));
        _executeHook(address(borrowHook), _borrowData(LIQ_BORROW, false));
        uint256 suppliedBefore = _supplied(WETH_RESERVE_ID);
        uint256 debtBefore = _totalDebt();

        address originalFeed = _setWethPrice(900e8); // ~2329 -> 900 USD: HF < 1
        // BORROW / RELEASE are arbitrated by the Spoke while under water (hook adds no LTV logic)
        _executeHookExpectFailure(address(borrowHook), _borrowData(1e6, false), HEALTH_FACTOR_BELOW_THRESHOLD);
        _executeHookExpectFailure(address(releaseHook), _standaloneData(1, false), HEALTH_FACTOR_BELOW_THRESHOLD);

        address liquidator = makeAddr("liquidator");
        _getTokens(CHAIN_1_USDC, liquidator, LIQ_BORROW);
        vm.startPrank(liquidator);
        IERC20(CHAIN_1_USDC).approve(SPOKE_ADDR, type(uint256).max);
        IAaveV4SpokeLiquidation(SPOKE_ADDR)
            .liquidationCall(WETH_RESERVE_ID, USDC_RESERVE_ID, accountEth, LIQ_BORROW / 2, false);
        vm.stopPrank();
        uint256 suppliedAfter = _supplied(WETH_RESERVE_ID);
        assertLt(suppliedAfter, suppliedBefore, "collateral seized");
        assertLt(_totalDebt(), debtBefore, "debt covered in part");
        assertTrue(_isCollateral(WETH_RESERVE_ID), "liquidation never clears the flag");

        _restoreWethPrice(originalFeed);
        // the pre-liquidation exact word is above the live position: typed, before any Spoke call
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(suppliedBefore, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), suppliedAfter, "position untouched by the refused release");

        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(repayHook), _createRepayData(type(uint256).max, false));
        assertEq(_totalDebt(), 0);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, suppliedAfter, "remainder paid exactly");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /// @notice CLOSE's withdraw leg after a liquidation: the stale exact withdraw word is refused with the same typed
    ///         error; CLOSE(max repay, max withdraw) then closes the shrunken position exactly
    function test_AaveV4V2_Liquidation_StaleCloseTyped_ThenMaxClose() external {
        _executeHook(address(openHook), _createOpenData(LIQ_PLEDGE, false, LIQ_BORROW));
        uint256 suppliedBefore = _supplied(WETH_RESERVE_ID);
        address originalFeed = _setWethPrice(900e8);
        address liquidator = makeAddr("liquidator");
        _getTokens(CHAIN_1_USDC, liquidator, LIQ_BORROW);
        vm.startPrank(liquidator);
        IERC20(CHAIN_1_USDC).approve(SPOKE_ADDR, type(uint256).max);
        IAaveV4SpokeLiquidation(SPOKE_ADDR)
            .liquidationCall(WETH_RESERVE_ID, USDC_RESERVE_ID, accountEth, LIQ_BORROW / 2, false);
        vm.stopPrank();
        _restoreWethPrice(originalFeed);
        uint256 suppliedAfter = _supplied(WETH_RESERVE_ID);
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHookExpectFailure(
            address(closeHook),
            _createCloseData(type(uint256).max, false, suppliedBefore),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        assertEq(_totalDebt(), debt, "refused close repaid nothing");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(closeHook), _createCloseData(type(uint256).max, false, type(uint256).max));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, suppliedAfter, "shrunken position paid");
        assertEq(_totalDebt(), 0);
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /*//////////////////////////////////////////////////////////////
            HUB-SIDE CAPS (mocked AccessManager on the Hub)
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets the Main Spoke's add / draw caps (whole assets) for the asset behind `reserveId` through the Hub's
    ///      `restricted` `updateSpokeConfig`, keeping riskPremiumThreshold 0 / active / not halted as live
    function _setSpokeCaps(uint256 reserveId, uint40 addCap, uint40 drawCap) internal {
        IAaveV4Spoke.Reserve memory r = IAaveV4Spoke(SPOKE_ADDR).getReserve(reserveId);
        address authority = IAaveV4HubAdmin(r.hub).authority();
        vm.mockCall(authority, abi.encodeWithSelector(0xb7009613), abi.encode(true, uint32(0)));
        IAaveV4HubAdmin(r.hub)
            .updateSpokeConfig(r.assetId, SPOKE_ADDR, IAaveV4HubAdmin.SpokeConfig(addCap, drawCap, 0, true, false));
        vm.clearMockedCalls();
    }

    /// @notice Hub add cap on WETH below what the Spoke already holds: PLEDGE and OPEN are refused by the Hub
    ///         (`AddCapExceeded`), RELEASE still exits; raising the cap restores PLEDGE
    function test_AaveV4V2_HubAddCap_PledgeRefused_ReleaseAllowed() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        _setSpokeCaps(WETH_RESERVE_ID, 1, 1_099_511_627_775); // 1 WETH add cap (already exceeded), draw cap = no cap
        _executeHookExpectFailure(address(pledgeHook), _standaloneData(0.1 ether, false), bytes4(0xde3fc6ae));
        _executeHookExpectFailure(address(openHook), _createOpenData(0.1 ether, false, 10e6), bytes4(0xde3fc6ae));
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "nothing added");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(0.3 ether, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.3 ether, "capped reserve still exits");
        _setSpokeCaps(WETH_RESERVE_ID, 1_099_511_627_775, 1_099_511_627_775);
        _executeHook(address(pledgeHook), _standaloneData(0.1 ether, false));
    }

    /// @notice Hub draw cap on USDC below the requested borrow: BORROW is refused by the Hub (`DrawCapExceeded`), no
    ///         debt; REPAY / RELEASE are unaffected
    function test_AaveV4V2_HubDrawCap_BorrowRefused() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _setSpokeCaps(USDC_RESERVE_ID, 1_099_511_627_775, 1); // 1 USDC draw cap (already exceeded by the spoke)
        _executeHookExpectFailure(address(borrowHook), _borrowData(BORROW_AMOUNT, false), bytes4(0x3ad30dd0));
        assertEq(_totalDebt(), 0, "no debt");
        _setSpokeCaps(USDC_RESERVE_ID, 1_099_511_627_775, 1_099_511_627_775);
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);
    }

    /*//////////////////////////////////////////////////////////////
                PER-ACCOUNT ISOLATION ON THE LIVE SPOKE
    //////////////////////////////////////////////////////////////*/

    /// @notice Another account's un-flagged idle position on the same reserve never trips this account's guards, and
    ///         this account's RELEASE(max) pays out its own position only
    function test_AaveV4V2_OtherAccountIdlePosition_DoesNotAffectThisAccount() external {
        address bob = makeAddr("bob");
        _getTokens(CHAIN_1_WETH, bob, 2 ether);
        vm.startPrank(bob);
        IERC20(CHAIN_1_WETH).approve(SPOKE_ADDR, 2 ether);
        IAaveV4Spoke(SPOKE_ADDR).supply(WETH_RESERVE_ID, 2 ether, bob); // bob: idle, un-flagged
        vm.stopPrank();
        uint256 bobBefore = IAaveV4Spoke(SPOKE_ADDR).getUserSuppliedAssets(WETH_RESERVE_ID, bob);
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _executeHook(address(openHook), _createOpenData(0.5 ether, false, 100e6));
        uint256 mine = _supplied(WETH_RESERVE_ID);
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(repayHook), _createRepayData(type(uint256).max, false));
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, mine, "only my position paid");
        assertEq(IAaveV4Spoke(SPOKE_ADDR).getUserSuppliedAssets(WETH_RESERVE_ID, bob), bobBefore, "bob untouched");
        (bool bobFlag,) = IAaveV4Spoke(SPOKE_ADDR).getUserReserveStatus(WETH_RESERVE_ID, bob);
        assertFalse(bobFlag, "bob still idle");
    }

    /*//////////////////////////////////////////////////////////////
            GOVERNANCE STATES: FROZEN / PAUSED (mocked AccessManager)
    //////////////////////////////////////////////////////////////*/

    /// @dev Aave V4 Spoke `ReserveFrozen()` / `ReservePaused()` selectors (bubble through the hooks unchanged)
    bytes4 internal constant RESERVE_FROZEN = 0x6d305815;
    bytes4 internal constant RESERVE_PAUSED = 0xd37f5f1c;

    /// @dev Flips the paused / frozen flags of a reserve through the Spoke's `restricted` admin path by mocking the
    ///      AccessManager `canCall(address,address,bytes4)` → (immediate = true, delay = 0). Other config bits kept
    ///      at the live values (collateralRisk 0, borrowable, receiveSharesEnabled) read at AAVE_V4_BLOCK.
    function _setReserveFlags(uint256 reserveId, bool paused, bool frozen) internal {
        address authority = IAaveV4SpokeAdmin(SPOKE_ADDR).authority();
        vm.mockCall(authority, abi.encodeWithSelector(0xb7009613), abi.encode(true, uint32(0)));
        IAaveV4SpokeAdmin.ReserveConfig memory cfg = IAaveV4SpokeAdmin.ReserveConfig(0, paused, frozen, true, true);
        IAaveV4SpokeAdmin(SPOKE_ADDR).updateReserveConfig(reserveId, cfg);
        vm.clearMockedCalls();
        IAaveV4SpokeAdmin.ReserveConfig memory c = IAaveV4SpokeAdmin(SPOKE_ADDR).getReserveConfig(reserveId);
        assertEq(c.paused, paused);
        assertEq(c.frozen, frozen);
    }

    /// @notice Frozen collateral reserve: PLEDGE is refused by the Spoke (`ReserveFrozen`), RELEASE still exits (exact
    ///         and max); state is untouched by the refused pledge; unfreezing restores PLEDGE
    function test_AaveV4V2_FrozenReserve_PledgeRefused_ReleaseAllowed() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        _setReserveFlags(WETH_RESERVE_ID, false, true);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHookExpectFailure(address(pledgeHook), _standaloneData(0.1 ether, false), RESERVE_FROZEN);
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "refused pledge left the position untouched");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "wallet untouched");
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0, "no allowance residue");

        _executeHook(address(releaseHook), _standaloneData(0.3 ether, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.3 ether, "frozen reserve still exits");
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0, "full exit while frozen");

        _setReserveFlags(WETH_RESERVE_ID, false, false);
        _executeHook(address(pledgeHook), _standaloneData(0.1 ether, false));
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), 0.1 ether, 1, "pledge works again after unfreeze");
    }

    /// @notice Frozen borrow reserve: BORROW is refused by the Spoke (`ReserveFrozen`) with no debt created; the
    ///         collateral side is unaffected and the borrow succeeds once unfrozen
    function test_AaveV4V2_FrozenBorrowReserve_BorrowRefused() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        _setReserveFlags(USDC_RESERVE_ID, false, true);
        _executeHookExpectFailure(address(borrowHook), _borrowData(BORROW_AMOUNT, false), RESERVE_FROZEN);
        assertEq(_totalDebt(), 0, "no debt");
        _setReserveFlags(USDC_RESERVE_ID, false, false);
        _executeHook(address(borrowHook), _borrowData(BORROW_AMOUNT, false));
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);
    }

    /// @notice Paused collateral reserve: every action is refused (`ReservePaused`) — PLEDGE, RELEASE exact and max
    ///         — and the position survives untouched until unpause, when RELEASE exits exactly
    function test_AaveV4V2_PausedReserve_AllRefused_UntilUnpause() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        _setReserveFlags(WETH_RESERVE_ID, true, false);

        _executeHookExpectFailure(address(pledgeHook), _standaloneData(0.1 ether, false), RESERVE_PAUSED);
        _executeHookExpectFailure(address(releaseHook), _standaloneData(0.3 ether, false), RESERVE_PAUSED);
        _executeHookExpectFailure(address(releaseHook), _standaloneData(type(uint256).max, false), RESERVE_PAUSED);
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched while paused");
        assertTrue(_isCollateral(WETH_RESERVE_ID));

        _setReserveFlags(WETH_RESERVE_ID, false, false);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "exact exit after unpause");
    }

    /// @notice Atomicity across legs: a healthy WETH pledge followed by a WBTC pledge on a frozen reserve in one userOp
    ///         rolls both back — no partial collateral, no flags, no allowances
    function test_AaveV4V2_FrozenSecondLeg_WholeUserOpRollsBack() external {
        _setReserveFlags(WBTC_RESERVE_ID, false, true);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(pledgeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _standaloneWbtcData(SUPPLY_WBTC, false);
        _executeHooksExpectFailure(hooks, data, RESERVE_FROZEN);
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "WETH leg rolled back");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_supplied(WBTC_RESERVE_ID), 0);
        assertFalse(_isCollateral(WETH_RESERVE_ID) || _isCollateral(WBTC_RESERVE_ID));
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0);
    }

    /// @notice Non-borrowable borrow reserve: BORROW is refused by the Spoke, no debt; the hook adds no eligibility
    ///         logic
    function test_AaveV4V2_NonBorrowableReserve_BorrowRefused() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        address authority = IAaveV4SpokeAdmin(SPOKE_ADDR).authority();
        vm.mockCall(authority, abi.encodeWithSelector(0xb7009613), abi.encode(true, uint32(0)));
        IAaveV4SpokeAdmin.ReserveConfig memory cfg = IAaveV4SpokeAdmin.ReserveConfig(0, false, false, false, true);
        IAaveV4SpokeAdmin(SPOKE_ADDR).updateReserveConfig(USDC_RESERVE_ID, cfg);
        vm.clearMockedCalls();
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(borrowHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _standaloneData(BORROW_AMOUNT, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
        bytes32 opTopic = keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)");
        bool seen;
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == opTopic) {
                (, bool success,,) = abi.decode(ret.logs[i].data, (uint256, bool, uint256, uint256));
                assertFalse(success, "borrow on a non-borrowable reserve must revert");
                seen = true;
            }
        }
        assertTrue(seen);
        assertEq(_totalDebt(), 0, "no debt");
    }

    /*//////////////////////////////////////////////////////////////
            REAL-LIFE E2E: MIXED-KEY USEROPS AND OMS SIZING FLOWS
    //////////////////////////////////////////////////////////////*/

    /// @notice One userOp, four hooks, three distinct header keys and a usePrev chain — PLEDGE(WETH key) →
    /// BORROW(USDC
    ///         key) → REPAY(USDC key, cap = BORROW's published delta) → RELEASE(WETH key, max): ends with no debt,
    /// no
    ///         position, WETH back within rounding, allowances reset
    function test_E2E_PledgeBorrowRepayRelease_OneUserOp_MixedKeys() external {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](4);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(borrowHook);
        hooks[2] = address(repayHook);
        hooks[3] = address(releaseHook);
        bytes[] memory data = new bytes[](4);
        data[0] = _standaloneData(SUPPLY_AMOUNT, false);
        data[1] = _borrowData(BORROW_AMOUNT, false);
        data[2] = _createRepayData(1, true);
        data[3] = _standaloneData(type(uint256).max, false);
        // the four headers carry two different keys (WETH for PLEDGE / RELEASE, USDC for BORROW / REPAY)
        assertEq(BytesLib.toAddress(data[0], 32), BytesLib.toAddress(data[3], 32));
        assertEq(BytesLib.toAddress(data[1], 32), BytesLib.toAddress(data[2], 32));
        assertTrue(BytesLib.toAddress(data[0], 32) != BytesLib.toAddress(data[1], 32));
        _executeHooks(hooks, data);
        assertApproxEqAbs(_totalDebt(), 0, 2, "debt cleared to index dust");
        assertEq(_supplied(WETH_RESERVE_ID), 0, "collateral fully released");
        assertApproxEqAbs(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, 2, "WETH back within rounding");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "borrowed == repaid");
        assertEq(IERC20(CHAIN_1_WETH).allowance(accountEth, SPOKE_ADDR), 0);
        assertEq(IERC20(CHAIN_1_USDC).allowance(accountEth, SPOKE_ADDR), 0);
    }

    /// @notice OMS sizing flow on the composites: a keyed OPEN payload with placeholder amounts is sized through the
    ///         strict views (decodeAmounts → replaceCalldataAmounts), then executed; the same for CLOSE. A mis-keyed
    ///         payload is refused at the sizing step, before anything is signed
    function test_E2E_CompositeSizingFlow_RewriteThenExecute_WrongKeyRefusedAtSizing() external {
        bytes memory openTemplate = _createOpenData(1, false, 1);
        uint256[] memory sized = openHook.decodeAmounts(openTemplate);
        assertEq(sized.length, 2);
        sized[0] = 0.7 ether;
        sized[1] = 300e6;
        bytes memory openSized = openHook.replaceCalldataAmounts(openTemplate, sized);
        assertEq(openHook.inspect(openSized), openHook.inspect(openTemplate), "identity survives sizing");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeHook(address(openHook), openSized);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), 0.7 ether, "sized supply executed");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, 300e6, "sized borrow executed");

        // mis-keyed template (the loan reserve's OLD reserve key on an OPEN): the strict views refuse it —
        // the OMS never gets a payload to sign
        bytes memory badTemplate = abi.encodePacked(
            AAVE_V4_YS_ORACLE_ID,
            AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, USDC_RESERVE_ID),
            BytesLib.slice(openTemplate, 52, 189)
        );
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        openHook.decodeAmounts(badTemplate);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        openHook.replaceCalldataAmounts(badTemplate, sized);

        // CLOSE: size repay cap to the live debt and the withdraw to the live position, then execute
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        uint256[] memory closeSized = new uint256[](2);
        closeSized[0] = debt;
        closeSized[1] = _supplied(WETH_RESERVE_ID);
        bytes memory closeSizedData = closeHook.replaceCalldataAmounts(_createCloseData(1, false, 1), closeSized);
        _executeHook(address(closeHook), closeSizedData);
        assertEq(_totalDebt(), 0, "debt cleared");
        assertEq(_supplied(WETH_RESERVE_ID), 0, "position closed");
    }

    /// @notice Real-life operator mistake: after a partial CLOSE the OMS re-sizes a RELEASE from a stale (pre-close)
    ///         position read — the typed error names both numbers so the sizer can re-read and retry with the live
    /// one
    function test_E2E_StaleSizing_TypedError_ThenLiveResize() external {
        _openDefaultPosition();
        uint256 stale = _supplied(WETH_RESERVE_ID);
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(closeHook), _createCloseData(type(uint256).max, false, 0.4 ether)); // partial close
        uint256 live = _supplied(WETH_RESERVE_ID);
        assertLt(live, stale);
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(stale, false), BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(live, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, live, "live-sized release pays exactly");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /*//////////////////////////////////////////////////////////////
        CLOSE WITHDRAW LEG ON THE LIVE SPOKE (typed over-position, mode gate)
    //////////////////////////////////////////////////////////////*/

    /// @notice CLOSE with an exact withdraw word above the live position is refused with the typed error before any
    ///         Spoke call (state unchanged); sized from the live position it closes exactly
    function test_AaveV4V2_Close_WithdrawAboveSupplied_Typed_StateUnchanged() external {
        _openDefaultPosition();
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHookExpectFailure(
            address(closeHook),
            _createCloseData(type(uint256).max, false, supplied + 1),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "collateral untouched");
        assertEq(_totalDebt(), debt, "debt untouched");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(closeHook), _createCloseData(type(uint256).max, false, supplied));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "exact == live position pays all");
        assertEq(_totalDebt(), 0);
    }

    /// @notice CLOSE never pays out an un-flagged (idle) position: refused with RESERVE_NOT_COLLATERAL before any call
    function test_AaveV4V2_Close_OverIdlePosition_Refused() external {
        vm.startPrank(accountEth);
        IERC20(CHAIN_1_WETH).approve(SPOKE_ADDR, SUPPLY_AMOUNT);
        IAaveV4Spoke(SPOKE_ADDR).supply(WETH_RESERVE_ID, SUPPLY_AMOUNT, accountEth);
        vm.stopPrank();
        uint256 before = _supplied(WETH_RESERVE_ID);
        _executeHookExpectFailure(
            address(closeHook),
            _createCloseData(type(uint256).max, false, type(uint256).max),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), before, "idle position untouched");
    }

    /// @notice A zero header oracle id is refused through the real userOp path on every V2 hook
    function test_AaveV4V2_ZeroOracleId_Refused_StateUnchanged() external {
        bytes memory pledge = _standaloneData(SUPPLY_AMOUNT, false);
        _executeHookExpectFailure(
            address(pledgeHook),
            abi.encodePacked(bytes32(0), BytesLib.slice(pledge, 32, 209)),
            BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector
        );
        bytes memory open = _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT);
        _executeHookExpectFailure(
            address(openHook),
            abi.encodePacked(bytes32(0), BytesLib.slice(open, 32, 209)),
            BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_totalDebt(), 0);
    }

    /// @notice The documented manual-flag-off trade-off applies to CLOSE too: after the debt is repaid and the account
    ///         clears the flag itself, CLOSE(max, max) is refused (RESERVE_NOT_COLLATERAL) until the flag is re-enabled
    function test_AaveV4V2_Close_ManualFlagOff_Refused_UntilReenabled() external {
        _openDefaultPosition();
        uint256 debt = _totalDebt();
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _executeHook(address(repayHook), _createRepayData(type(uint256).max, false));
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, false, accountEth);
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        _executeHookExpectFailure(
            address(closeHook),
            _createCloseData(type(uint256).max, false, type(uint256).max),
            BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched");
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, true, accountEth);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(closeHook), _createCloseData(type(uint256).max, false, type(uint256).max));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, supplied, "closed after re-enable");
    }

    /// @notice A fresh account with no position on the reserve: RELEASE(max), RELEASE(exact) and CLOSE(max, max) are
    /// all refused before any Spoke call with the empty-position error (AMOUNT_NOT_VALID) via userOp, and the
    /// standalone
    ///         BORROW with no collateral is refused by the Spoke itself (whole userOp reverts, nothing borrowed)
    function test_AaveV4V2_EmptyAccount_ReleaseCloseBorrow_AllRefused() external {
        assertEq(_supplied(WETH_RESERVE_ID), 0, "fresh");
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(type(uint256).max, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        _executeHookExpectFailure(
            address(releaseHook), _standaloneData(1 ether, false), BaseHook.AMOUNT_NOT_VALID.selector
        );
        _executeHookExpectFailure(
            address(closeHook),
            _createCloseData(type(uint256).max, false, type(uint256).max),
            BaseHook.AMOUNT_NOT_VALID.selector
        );
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](1);
        hooks[0] = address(borrowHook);
        bytes[] memory data = new bytes[](1);
        data[0] = _borrowData(100e6, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
        bytes32 evTopic = keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)");
        bool sawFailure;
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == evTopic) {
                (, bool success,,) = abi.decode(ret.logs[i].data, (uint256, bool, uint256, uint256));
                sawFailure = !success;
            }
        }
        assertTrue(sawFailure, "uncollateralised borrow reverts at the Spoke");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "nothing borrowed");
        (uint256 debt,) = IAaveV4Spoke(SPOKE_ADDR).getUserDebt(USDC_RESERVE_ID, accountEth);
        assertEq(debt, 0, "no debt");
    }

    /*//////////////////////////////////////////////////////////////
                OPEN IDLE-MODE GUARD ON THE LIVE SPOKE
    //////////////////////////////////////////////////////////////*/

    /// @notice One mode per (account, reserve), now closed on the composite side too: an idle-style un-flagged
    ///         supply is refused by OPEN (`RESERVE_HAS_IDLE_POSITION`) before any Spoke call, so OPEN can no longer
    ///         flip an idle, ledger-tracked position into LOAN mode; a flagged position (from a PLEDGE) opens fine
    function test_AaveV4V2_Open_OverIdlePosition_Refused_FlaggedPasses() external {
        vm.startPrank(accountEth);
        IERC20(CHAIN_1_WETH).approve(SPOKE_ADDR, SUPPLY_AMOUNT);
        IAaveV4Spoke(SPOKE_ADDR).supply(WETH_RESERVE_ID, SUPPLY_AMOUNT, accountEth); // idle-style, un-flagged
        vm.stopPrank();
        uint256 before = _supplied(WETH_RESERVE_ID);
        _executeHookExpectFailure(
            address(openHook),
            _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT),
            BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), before, "idle position untouched");
        assertFalse(_isCollateral(WETH_RESERVE_ID), "flag untouched");
        assertEq(_totalDebt(), 0);
        // flag it through the account (the OMS-documented path) and OPEN proceeds
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE_ADDR).setUsingAsCollateral(WETH_RESERVE_ID, true, accountEth);
        _executeHook(address(openHook), _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT));
        assertApproxEqAbs(_totalDebt(), BORROW_AMOUNT, 1);
    }

    /*//////////////////////////////////////////////////////////////
            PLEDGE CREDIT ROUNDING (PR #1019 review P3-1 regression)
    //////////////////////////////////////////////////////////////*/

    /// @notice The supplied-assets credit is NOT bounded by "1 wei below the pledge": assets → shares rounds down
    ///         and shares → assets rounds down again, so the shortfall depends on the exchange rate. Reviewer-
    ///         reproduced on the live Main Spoke at AAVE_V4_BLOCK: pledging 1_000_000_000_000_001_857 wei credits
    ///         2 wei less. The hook is unaffected (it asserts the wallet spend, not the credit); RELEASE must be
    ///         sized from the live position or use the sentinel — an exact word equal to the pledge is refused.
    function test_AaveV4V2_Pledge_CreditRoundDown_CanExceedOneWei_Regression() external {
        uint256 pledge = 1_000_000_000_000_001_857;
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(pledgeHook), _standaloneData(pledge, false));
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), pledge, "spend is exact");
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        assertEq(pledge - supplied, 2, "observed 2-wei credit shortfall at this block (share round-trip rounding)");
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(pledge, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        _executeHookExpectFailure(
            address(releaseHook),
            _standaloneData(pledge - 1, false),
            BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector
        );
        uint256 mid = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(releaseHook), _standaloneData(type(uint256).max, false));
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - mid, supplied, "sentinel pays the live position exactly");
        assertEq(_supplied(WETH_RESERVE_ID), 0);
    }

    /*//////////////////////////////////////////////////////////////
                HEADER BIND (SUP-21143) ON THE LIVE SPOKE
    //////////////////////////////////////////////////////////////*/

    /// @notice SUP-21239: inspect() of all six V2 ops starts with the registry-derived MARKET key of the pair —
    ///         the SAME 20 bytes for every op, where the per-reserve rule gave OPEN / CLOSE / PLEDGE / RELEASE
    ///         one key and REPAY / BORROW another — then spoke, tokens and both ids, still 144 bytes. The key
    ///         equals the deployed registry's `computeMarketKey`, which is what off-chain consumers query.
    function test_AaveV4V2_Header_KeyEqualsRegistry_AllSixOps() external {
        AaveV4ReserveRegistryV2 registry = new AaveV4ReserveRegistryV2(address(this));
        address marketKey = registry.computeMarketKey(SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID);
        assertEq(
            marketKey,
            AaveV4ReserveKey.computeMarketKey(SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID),
            "library == registry"
        );
        // the two NAV keys are deliberately NOT the header any more, and must stay distinct from it
        assertTrue(marketKey != registry.computeReserveKey(SPOKE_ADDR, WETH_RESERVE_ID), "not the collateral key");
        assertTrue(marketKey != registry.computeDebtKey(SPOKE_ADDR, USDC_RESERVE_ID), "not the loan debt key");
        bytes memory tail = abi.encodePacked(SPOKE_ADDR, CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID);
        bytes memory expS = abi.encodePacked(marketKey, tail);
        bytes memory expB = expS;
        assertEq(expS.length, 144);
        assertEq(openHook.inspect(_createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT)), expS, "OPEN");
        assertEq(repayHook.inspect(_createRepayData(BORROW_AMOUNT, false)), expB, "REPAY");
        assertEq(closeHook.inspect(_createCloseData(BORROW_AMOUNT, false, SUPPLY_AMOUNT)), expS, "CLOSE");
        assertEq(pledgeHook.inspect(_standaloneData(SUPPLY_AMOUNT, false)), expS, "PLEDGE");
        assertEq(borrowHook.inspect(_borrowData(BORROW_AMOUNT, false)), expB, "BORROW");
        assertEq(releaseHook.inspect(_standaloneData(SUPPLY_AMOUNT, false)), expS, "RELEASE");
    }

    /// @notice The header key is identity only: on all six ops every non-ERC20 execution targets the calldata Spoke
    ///         and every approve names the Spoke as spender (built against the live Spoke with a live position)
    function test_AaveV4V2_SpokeIsCallTarget_AllSixOps() external {
        _openDefaultPosition();
        address keyWeth = AaveV4ReserveKey.computeMarketKey(SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID);
        address keyUsdc = AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, WETH_RESERVE_ID);
        address[6] memory hooks = [
            address(openHook),
            address(repayHook),
            address(closeHook),
            address(pledgeHook),
            address(borrowHook),
            address(releaseHook)
        ];
        bytes[6] memory datas = [
            _createOpenData(SUPPLY_AMOUNT, false, BORROW_AMOUNT),
            _createRepayData(100e6, false),
            _createCloseData(100e6, false, 0.1 ether),
            _standaloneData(SUPPLY_AMOUNT, false),
            _borrowData(100e6, false),
            _standaloneData(0.1 ether, false)
        ];
        for (uint256 i; i < hooks.length; ++i) {
            Execution[] memory ex = ISuperHook(hooks[i]).build(address(0), accountEth, datas[i]);
            for (uint256 j = 1; j + 1 < ex.length; ++j) {
                assertTrue(ex[j].target != keyWeth && ex[j].target != keyUsdc, "key is never a target");
                if (ex[j].target == CHAIN_1_USDC || ex[j].target == CHAIN_1_WETH) {
                    (address spender,) = abi.decode(BytesLib.slice(ex[j].callData, 4, 64), (address, uint256));
                    assertEq(spender, SPOKE_ADDR, "approve spender is the Spoke");
                } else {
                    assertEq(ex[j].target, SPOKE_ADDR, "provider target is the Spoke");
                }
            }
        }
    }

    /// @notice Through the real userOp path: a header carrying either leg's OLD reserve key, the reversed
    ///         market, another spoke's market, the spoke itself or zero is refused before any Spoke call —
    ///         nothing pledged, borrowed or released. The reserve-key cases are the migration property: a new
    ///         hook address against an old reserve-keyed root fails closed.
    function test_AaveV4V2_WrongHeaderKey_Reverts_StateUnchanged() external {
        _executeHook(address(pledgeHook), _standaloneData(SUPPLY_AMOUNT, false));
        uint256 supplied = _supplied(WETH_RESERVE_ID);
        bytes memory releaseBody = BytesLib.slice(_standaloneData(0.3 ether, false), 52, 189);
        bytes memory borrowBody = BytesLib.slice(_borrowData(BORROW_AMOUNT, false), 52, 189);
        address[5] memory wrongForRelease = [
            AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, WETH_RESERVE_ID),
            AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, USDC_RESERVE_ID),
            AaveV4ReserveKey.computeMarketKey(SPOKE_ADDR, USDC_RESERVE_ID, WETH_RESERVE_ID),
            AaveV4ReserveKey.computeMarketKey(address(0xBEEF), WETH_RESERVE_ID, USDC_RESERVE_ID),
            SPOKE_ADDR
        ];
        for (uint256 w; w < wrongForRelease.length; ++w) {
            _executeHookExpectFailure(
                address(releaseHook),
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, wrongForRelease[w], releaseBody),
                AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector
            );
        }
        // BORROW keyed to a reserve leg — under SUP-21143 the collateral key was the "wrong primary" mistake
        // and the borrow key was correct; now BOTH are refused because the header must be the market key
        _executeHookExpectFailure(
            address(borrowHook),
            abi.encodePacked(
                AAVE_V4_YS_ORACLE_ID, AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, WETH_RESERVE_ID), borrowBody
            ),
            AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector
        );
        _executeHookExpectFailure(
            address(borrowHook),
            abi.encodePacked(
                AAVE_V4_YS_ORACLE_ID, AaveV4ReserveKey.computeReserveKey(SPOKE_ADDR, USDC_RESERVE_ID), borrowBody
            ),
            AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector
        );
        _executeHookExpectFailure(
            address(pledgeHook),
            abi.encodePacked(AAVE_V4_YS_ORACLE_ID, address(0), releaseBody),
            BaseHook.ADDRESS_NOT_VALID.selector
        );
        assertEq(_supplied(WETH_RESERVE_ID), supplied, "position untouched");
        assertEq(_totalDebt(), 0, "no debt");
    }

    /// @notice The oracle id (offset 0) is identity only on the live path: any value executes identically
    function test_AaveV4V2_Header_AnyNonzeroOracleIdAccepted() external {
        bytes memory data = _standaloneData(SUPPLY_AMOUNT, false);
        bytes memory tagged = abi.encodePacked(keccak256("any-oracle-id"), BytesLib.slice(data, 32, 209));
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _executeHook(address(pledgeHook), tagged);
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), SUPPLY_AMOUNT);
        assertTrue(_isCollateral(WETH_RESERVE_ID));
    }
}

/// @dev Admin / config surface of the Aave V4 Spoke used only by the governance-state tests
interface IAaveV4SpokeAdmin {
    struct ReserveConfig {
        uint24 collateralRisk;
        bool paused;
        bool frozen;
        bool borrowable;
        bool receiveSharesEnabled;
    }

    function authority() external view returns (address);
    function updateReserveConfig(uint256 reserveId, ReserveConfig calldata config) external;
    function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory);
    function updateReservePriceSource(uint256 reserveId, address priceSource) external;
    function ORACLE() external view returns (address);
}

/// @dev Hub admin surface used only by the cap tests
interface IAaveV4HubAdmin {
    struct SpokeConfig {
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
    }

    function authority() external view returns (address);
    function updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig calldata config) external;
}

interface IAaveV4SpokeLiquidation {
    function liquidationCall(
        uint256 collateralReserveId,
        uint256 debtReserveId,
        address user,
        uint256 debtToCover,
        bool receiveShares
    )
        external;
}

interface IAaveOracleLike {
    function getReserveSource(uint256 reserveId) external view returns (address);
}

/// @dev 8-decimal Chainlink-shaped feed with a settable answer (what `AaveOracle.setReserveSource` accepts)
contract MockPriceFeed {
    int256 public answer;

    constructor(int256 answer_) {
        answer = answer_;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestAnswer() external view returns (int256) {
        return answer;
    }
}
