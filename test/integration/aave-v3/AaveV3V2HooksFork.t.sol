// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";

// Aave V3
import { IPool } from "../../../src/vendor/aave-v3/IPool.sol";
import { AaveV3SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHookV2.sol";
import { AaveV3RepayHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayHookV2.sol";
import { AaveV3RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHookV2.sol";

/// @title AaveV3V2HooksFork
/// @notice No-mock fork integration tests for the V2 Aave V3 loan hooks (open / close / standalone
///         repay) against the real Aave V3 Core market on Ethereum, driven through the real
///         ERC-4337 UserOp flow.
/// @dev Market: WETH collateral / USDC debt. aToken & variableDebtToken are resolved in setUp via
///      getReserveData — never hardcoded. V2 hooks enforce exact wallet deltas, so positive tests
///      assert wallet balances with strict equality and Aave positions with accrual tolerance.
contract AaveV3V2HooksFork is MinimalBaseIntegrationTest {
    IPool public constant POOL = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2); // Ethereum Core Pool
    uint256 internal constant AAVE_V3_ETH_BLOCK = 21_929_476; // postdates V3.2 stable-rate removal
    uint8 internal constant VARIABLE = 2;

    uint256 internal constant SUPPLY_WETH = 1e18; // 1 WETH collateral
    uint256 internal constant BORROW_USDC = 500e6; // 500 USDC

    address internal weth; // collateral
    address internal usdc; // debt
    address internal aWeth; // aToken of collateral
    address internal vUsdc; // variableDebtToken of debt

    AaveV3SupplyAndBorrowHookV2 internal openHook;
    AaveV3RepayHookV2 internal repayHookV2;
    AaveV3RepayAndWithdrawHookV2 internal closeHook;
    ISuperNativePaymaster internal paymaster;

    function setUp() public override {
        blockNumber = AAVE_V3_ETH_BLOCK;
        super.setUp();

        weth = CHAIN_1_WETH;
        usdc = CHAIN_1_USDC;
        aWeth = POOL.getReserveData(weth).aTokenAddress;
        vUsdc = POOL.getReserveData(usdc).variableDebtTokenAddress;
        require(aWeth != address(0) && vUsdc != address(0), "reserves not found");

        openHook = new AaveV3SupplyAndBorrowHookV2();
        repayHookV2 = new AaveV3RepayHookV2();
        closeHook = new AaveV3RepayAndWithdrawHookV2();
        paymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(weth, accountEth, 10e18);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/
    function _hdr() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0));
    }

    /// @dev Canonical 178-byte Aave V3 V2 layout: loanToken (52), collateralToken (72), pool (92),
    ///      rateMode (112, must be 2), amount1 (113), amount2 (145), usePrevHookAmount (177)
    function _v2(
        address loan,
        address coll,
        uint256 a1,
        uint256 a2,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(_hdr(), loan, coll, address(POOL), VARIABLE, a1, a2, usePrev);
    }

    /// @dev ApproveERC20Hook layout: token (52), spender (72), amount (92), usePrevHookAmount (124).
    ///      At chain position 0 the hook publishes outAmount = amount / outToken = token, making it
    ///      a producer for downstream usePrevHookAmount consumers.
    function _approveData(address token, address spender, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(_hdr(), token, spender, amount, false);
    }

    function _exec(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execMany(hooks, datas);
    }

    function _execMany(address[] memory hooks, bytes[] memory datas) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory op = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(op, paymaster, 1e18);
    }

    function _open(uint256 supplyAmount, uint256 borrowAmount) internal {
        _exec(address(openHook), _v2(usdc, weth, supplyAmount, borrowAmount, false));
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Open exact: both legs move exactly; aToken/vDebt reflect the position.
    function test_Open_Exact() external {
        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);

        _open(SUPPLY_WETH, BORROW_USDC);

        assertEq(wethBefore - IERC20(weth).balanceOf(accountEth), SUPPLY_WETH, "collateral spent exactly");
        assertEq(IERC20(usdc).balanceOf(accountEth) - usdcBefore, BORROW_USDC, "loan received exactly");
        assertGe(IERC20(aWeth).balanceOf(accountEth) + 2, SUPPLY_WETH, "aWETH minted (>= supplied - rounding)");
        assertApproxEqAbs(IERC20(aWeth).balanceOf(accountEth), SUPPLY_WETH, 2, "aWETH ~ supplied");
        assertGe(IERC20(vUsdc).balanceOf(accountEth) + 2, BORROW_USDC, "vDebt >= borrowed - rounding");
        assertApproxEqAbs(IERC20(vUsdc).balanceOf(accountEth), BORROW_USDC, 2, "vDebt ~ borrowed");
    }

    /// @notice Open chained: previous hook (ApproveERC20Hook at position 0) publishes the collateral
    ///         token; the open hook consumes its outAmount as the supply leg.
    function test_Open_UsePrevHookAmount() external {
        uint256 chainedSupply = SUPPLY_WETH / 2;

        address[] memory hooks = new address[](2);
        hooks[0] = approveHook; // deployed by MinimalBaseIntegrationTest
        hooks[1] = address(openHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _approveData(weth, address(POOL), chainedSupply);
        // amount1 = 0 in calldata proves the prev-hook output drives the supply leg
        datas[1] = _v2(usdc, weth, 0, BORROW_USDC, true);

        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        _execMany(hooks, datas);

        assertEq(wethBefore - IERC20(weth).balanceOf(accountEth), chainedSupply, "prev-hook amount supplied exactly");
        assertEq(IERC20(usdc).balanceOf(accountEth) - usdcBefore, BORROW_USDC, "loan received exactly");
        assertApproxEqAbs(IERC20(aWeth).balanceOf(accountEth), chainedSupply, 2, "aWETH ~ prev amount");
    }

    /// @notice Negative: previous hook produced the WRONG token (loan token instead of collateral);
    ///         build reverts PREV_TOKEN_MISMATCH inside the executor, the userOp fails and no state
    ///         change survives (including the first hook's approval).
    function test_Open_UsePrevHookAmount_WrongPrevToken_NoStateChange() external {
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = address(openHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _approveData(usdc, address(POOL), 100e6); // wrong token: USDC, not WETH
        datas[1] = _v2(usdc, weth, 0, BORROW_USDC, true);

        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        _execMany(hooks, datas);

        assertEq(IERC20(weth).balanceOf(accountEth), wethBefore, "WETH untouched");
        assertEq(IERC20(usdc).balanceOf(accountEth), usdcBefore, "USDC untouched");
        assertEq(IERC20(aWeth).balanceOf(accountEth), 0, "no collateral position");
        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "no debt position");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "hook 1 approval rolled back");
    }

    /// @notice Partial close: repay y < debt + withdraw x < aToken balance, both exact wallet deltas.
    function test_Close_Partial() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        uint256 repayAmount = 200e6;
        uint256 withdrawAmount = 0.25e18;
        uint256 debtBefore = IERC20(vUsdc).balanceOf(accountEth);
        uint256 aBefore = IERC20(aWeth).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);

        _exec(address(closeHook), _v2(usdc, weth, repayAmount, withdrawAmount, false));

        assertEq(usdcBefore - IERC20(usdc).balanceOf(accountEth), repayAmount, "loan spent exactly");
        assertEq(IERC20(weth).balanceOf(accountEth) - wethBefore, withdrawAmount, "collateral received exactly");
        assertApproxEqAbs(debtBefore - IERC20(vUsdc).balanceOf(accountEth), repayAmount, 2, "debt reduced by ~y");
        assertApproxEqAbs(aBefore - IERC20(aWeth).balanceOf(accountEth), withdrawAmount, 2, "aWETH reduced by ~x");
        assertGt(IERC20(vUsdc).balanceOf(accountEth), 0, "residual debt");
        assertGt(IERC20(aWeth).balanceOf(accountEth), 0, "residual collateral");
    }

    /// @notice Full close after 30 days of accrual: amount1 = max (full variable debt) and
    ///         amount2 = max (full aToken balance) — position fully cleared, allowance reset.
    function test_Close_Full_MaxMax_AfterWarp() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);
        _getTokens(usdc, accountEth, IERC20(usdc).balanceOf(accountEth) + 100e6); // cover accrued interest

        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);
        _exec(address(closeHook), _v2(usdc, weth, type(uint256).max, type(uint256).max, false));

        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "debt fully cleared");
        assertEq(IERC20(aWeth).balanceOf(accountEth), 0, "collateral fully withdrawn");
        assertGe(IERC20(weth).balanceOf(accountEth) - wethBefore, SUPPLY_WETH, "supplied WETH (+yield) returned");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "loan token allowance reset");
    }

    /// @notice Standalone partial repay: exact wallet spend, allowance reset after.
    function test_Repay_Partial() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        uint256 repayAmount = 200e6;
        uint256 debtBefore = IERC20(vUsdc).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);

        _exec(address(repayHookV2), _v2(usdc, weth, repayAmount, 0, false));

        assertEq(usdcBefore - IERC20(usdc).balanceOf(accountEth), repayAmount, "loan spent exactly");
        assertApproxEqAbs(debtBefore - IERC20(vUsdc).balanceOf(accountEth), repayAmount, 2, "debt reduced by ~y");
        assertGt(IERC20(vUsdc).balanceOf(accountEth), 0, "residual debt");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "loan token allowance reset");
    }

    /// @notice Standalone full repay via the max sentinel after 30 days of accrual — no dust left.
    function test_Repay_Full_Max_AfterWarp() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216_000);
        _getTokens(usdc, accountEth, IERC20(usdc).balanceOf(accountEth) + 100e6); // cover accrued interest

        _exec(address(repayHookV2), _v2(usdc, weth, type(uint256).max, 0, false));

        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "debt fully cleared, no dust");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "loan token allowance reset");
    }

    /// @notice Standalone repay against a zero-debt position SUCCEEDS as a no-op — the repay leg
    ///         is skipped, so a third-party gift repayment cannot cancel a signed intent.
    function test_Repay_ZeroDebt_Graceful_NoOp() external {
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        assertGt(usdcBefore, 0, "account funded with loan token");

        _exec(address(repayHookV2), _v2(usdc, weth, 100e6, 0, false));

        assertEq(IERC20(usdc).balanceOf(accountEth), usdcBefore, "USDC untouched");
        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "still no debt");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "no dangling allowance");
    }

    /// @notice Golden cap>debt: a non-sentinel cap above the outstanding debt resolves to the
    ///         debt — cleared natively via repay(max) with no dust, spend equals the debt, and
    ///         the leftover stays in the wallet.
    function test_Repay_OverAmount_CapsToDebt() external {
        _open(SUPPLY_WETH, BORROW_USDC);
        uint256 debt = IERC20(vUsdc).balanceOf(accountEth);
        assertGt(debt, 0, "has debt");

        _getTokens(usdc, accountEth, IERC20(usdc).balanceOf(accountEth) + debt * 2); // plenty to repay
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);

        _exec(address(repayHookV2), _v2(usdc, weth, debt + 100e6, 0, false));

        assertEq(usdcBefore - IERC20(usdc).balanceOf(accountEth), debt, "spend equals the resolved debt");
        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "debt fully cleared, no dust");
        assertEq(IERC20(usdc).allowance(accountEth, address(POOL)), 0, "no dangling allowance");
    }
}
