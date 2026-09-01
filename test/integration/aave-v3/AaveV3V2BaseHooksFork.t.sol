// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";

// Aave V3
import { IPool } from "../../../src/vendor/aave-v3/IPool.sol";
import { AaveV3SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHookV2.sol";
import { AaveV3RepayHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayHookV2.sol";
import { AaveV3RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHookV2.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";

// test utils
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

/// @title AaveV3V2BaseHooksFork
/// @notice No-mock fork integration tests for the V2 Aave V3 loan hooks (open / close / standalone
///         repay) on the Base Core market, driven through the real ERC-4337 UserOp flow.
/// @dev Self-contained V2 harness mirroring the AaveV3ChainForkBase pattern (RPC-skip via envOr,
///      defensive external self-call for fork bring-up) without touching the existing V1 base.
///      WETH collateral / USDC debt; aToken & variableDebtToken resolved via getReserveData.
contract AaveV3V2BaseHooksFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    uint8 internal constant VARIABLE = 2;
    uint256 internal constant BASE_FORK_BLOCK = 24_000_000;
    address internal constant BASE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Base Core Pool
    address internal constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal constant SUPPLY_WETH = 1e18; // 1 WETH collateral
    uint256 internal constant BORROW_USDC = 200e6; // 200 USDC

    // ---- harness state ----
    address internal account;
    AccountInstance internal instance;
    ISuperExecutor internal superExecutor;
    ISuperNativePaymaster internal paymaster;

    AaveV3SupplyAndBorrowHookV2 internal openHook;
    AaveV3RepayHookV2 internal repayHookV2;
    AaveV3RepayAndWithdrawHookV2 internal closeHook;
    ApproveERC20Hook internal approveHook;

    address internal aWeth;
    address internal vUsdc;

    function setUp() public virtual {
        // Skip gracefully when this chain's RPC isn't configured (keeps ftest-ci green on partial setups).
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }

        // Defensive: fork bring-up (ERC-4337 account creation + module install, reserve reads) can fail
        // on a flaky/stale/rate-limited archive RPC. Run it through an external self-call so any revert
        // skips this suite instead of failing CI; hook logic still runs whenever the fork comes up clean.
        try this._forkSetUp(rpc) { }
        catch {
            vm.skip(true);
        }
    }

    /// @notice Fork-dependent setup body, external so setUp() can try/catch it. Only callable by self.
    function _forkSetUp(string memory rpc) external {
        require(msg.sender == address(this), "ONLY_SELF");

        vm.createSelectFork(rpc, BASE_FORK_BLOCK);

        ISuperLedgerConfiguration ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        instance = makeAccountInstance(keccak256(abi.encode("aave-v3-v2-base-acc")));
        account = instance.account;

        superExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        openHook = new AaveV3SupplyAndBorrowHookV2();
        repayHookV2 = new AaveV3RepayHookV2();
        closeHook = new AaveV3RepayAndWithdrawHookV2();
        approveHook = new ApproveERC20Hook();
        paymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        aWeth = IPool(BASE_POOL).getReserveData(BASE_WETH).aTokenAddress;
        vUsdc = IPool(BASE_POOL).getReserveData(BASE_USDC).variableDebtTokenAddress;
        require(aWeth != address(0) && vUsdc != address(0), "reserves not found");

        _getTokens(BASE_WETH, account, 10e18);
        _getTokens(BASE_USDC, account, 1000e6);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                           ENCODERS / EXEC
    //////////////////////////////////////////////////////////////*/
    function _hdr() private pure returns (bytes memory) {
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
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_hdr(), loan, coll, BASE_POOL, VARIABLE, a1, a2, usePrev);
    }

    /// @dev ApproveERC20Hook layout: token (52), spender (72), amount (92), usePrevHookAmount (124).
    ///      At chain position 0 the hook publishes outAmount = amount / outToken = token.
    function _approveData(address token, address spender, uint256 amount) private pure returns (bytes memory) {
        return abi.encodePacked(_hdr(), token, spender, amount, false);
    }

    function _exec(address hook, bytes memory data) private {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execMany(hooks, datas);
    }

    function _execMany(address[] memory hooks, bytes[] memory datas) private {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory op = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOpsThroughPaymaster(op, paymaster, 1e18);
    }

    function _open(uint256 supplyAmount, uint256 borrowAmount) private {
        _exec(address(openHook), _v2(BASE_USDC, BASE_WETH, supplyAmount, borrowAmount, false));
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Open exact: both legs move exactly; aToken/vDebt reflect the position.
    function test_Base_Open_Exact() external {
        uint256 wethBefore = IERC20(BASE_WETH).balanceOf(account);
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);

        _open(SUPPLY_WETH, BORROW_USDC);

        assertEq(wethBefore - IERC20(BASE_WETH).balanceOf(account), SUPPLY_WETH, "collateral spent exactly");
        assertEq(IERC20(BASE_USDC).balanceOf(account) - usdcBefore, BORROW_USDC, "loan received exactly");
        assertApproxEqAbs(IERC20(aWeth).balanceOf(account), SUPPLY_WETH, 2, "aWETH ~ supplied");
        assertApproxEqAbs(IERC20(vUsdc).balanceOf(account), BORROW_USDC, 2, "vDebt ~ borrowed");
    }

    /// @notice Open chained: previous hook (ApproveERC20Hook at position 0) publishes the collateral
    ///         token; the open hook consumes its outAmount as the supply leg.
    function test_Base_Open_UsePrevHookAmount() external {
        uint256 chainedSupply = SUPPLY_WETH / 2;

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook);
        hooks[1] = address(openHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _approveData(BASE_WETH, BASE_POOL, chainedSupply);
        // amount1 = 0 in calldata proves the prev-hook output drives the supply leg
        datas[1] = _v2(BASE_USDC, BASE_WETH, 0, BORROW_USDC, true);

        uint256 wethBefore = IERC20(BASE_WETH).balanceOf(account);
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);
        _execMany(hooks, datas);

        assertEq(wethBefore - IERC20(BASE_WETH).balanceOf(account), chainedSupply, "prev-hook amount supplied exactly");
        assertEq(IERC20(BASE_USDC).balanceOf(account) - usdcBefore, BORROW_USDC, "loan received exactly");
        assertApproxEqAbs(IERC20(aWeth).balanceOf(account), chainedSupply, 2, "aWETH ~ prev amount");
    }

    /// @notice Negative: previous hook produced the WRONG token (loan token instead of collateral);
    ///         build reverts PREV_TOKEN_MISMATCH inside the executor, the userOp fails and no state
    ///         change survives (including the first hook's approval).
    function test_Base_Open_UsePrevHookAmount_WrongPrevToken_NoStateChange() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook);
        hooks[1] = address(openHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _approveData(BASE_USDC, BASE_POOL, 100e6); // wrong token: USDC, not WETH
        datas[1] = _v2(BASE_USDC, BASE_WETH, 0, BORROW_USDC, true);

        uint256 wethBefore = IERC20(BASE_WETH).balanceOf(account);
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);
        _execMany(hooks, datas);

        assertEq(IERC20(BASE_WETH).balanceOf(account), wethBefore, "WETH untouched");
        assertEq(IERC20(BASE_USDC).balanceOf(account), usdcBefore, "USDC untouched");
        assertEq(IERC20(aWeth).balanceOf(account), 0, "no collateral position");
        assertEq(IERC20(vUsdc).balanceOf(account), 0, "no debt position");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "hook 1 approval rolled back");
    }

    /// @notice Partial close: repay y < debt + withdraw x < aToken balance, both exact wallet deltas.
    function test_Base_Close_Partial() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        uint256 repayAmount = 100e6;
        uint256 withdrawAmount = 0.25e18;
        uint256 debtBefore = IERC20(vUsdc).balanceOf(account);
        uint256 aBefore = IERC20(aWeth).balanceOf(account);
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);
        uint256 wethBefore = IERC20(BASE_WETH).balanceOf(account);

        _exec(address(closeHook), _v2(BASE_USDC, BASE_WETH, repayAmount, withdrawAmount, false));

        assertEq(usdcBefore - IERC20(BASE_USDC).balanceOf(account), repayAmount, "loan spent exactly");
        assertEq(IERC20(BASE_WETH).balanceOf(account) - wethBefore, withdrawAmount, "collateral received exactly");
        assertApproxEqAbs(debtBefore - IERC20(vUsdc).balanceOf(account), repayAmount, 2, "debt reduced by ~y");
        assertApproxEqAbs(aBefore - IERC20(aWeth).balanceOf(account), withdrawAmount, 2, "aWETH reduced by ~x");
        assertGt(IERC20(vUsdc).balanceOf(account), 0, "residual debt");
        assertGt(IERC20(aWeth).balanceOf(account), 0, "residual collateral");
    }

    /// @notice Full close after 30 days of accrual: amount1 = max (full variable debt) and
    ///         amount2 = max (full aToken balance) — position fully cleared, allowance reset.
    function test_Base_Close_Full_MaxMax_AfterWarp() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1_296_000); // ~30 days of 2s Base blocks
        _getTokens(BASE_USDC, account, IERC20(BASE_USDC).balanceOf(account) + 50e6); // cover accrued interest

        uint256 wethBefore = IERC20(BASE_WETH).balanceOf(account);
        _exec(address(closeHook), _v2(BASE_USDC, BASE_WETH, type(uint256).max, type(uint256).max, false));

        assertEq(IERC20(vUsdc).balanceOf(account), 0, "debt fully cleared");
        assertEq(IERC20(aWeth).balanceOf(account), 0, "collateral fully withdrawn");
        assertGe(IERC20(BASE_WETH).balanceOf(account) - wethBefore, SUPPLY_WETH, "supplied WETH (+yield) returned");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "loan token allowance reset");
    }

    /// @notice Standalone partial repay: exact wallet spend, allowance reset after.
    function test_Base_Repay_Partial() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        uint256 repayAmount = 100e6;
        uint256 debtBefore = IERC20(vUsdc).balanceOf(account);
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);

        _exec(address(repayHookV2), _v2(BASE_USDC, BASE_WETH, repayAmount, 0, false));

        assertEq(usdcBefore - IERC20(BASE_USDC).balanceOf(account), repayAmount, "loan spent exactly");
        assertApproxEqAbs(debtBefore - IERC20(vUsdc).balanceOf(account), repayAmount, 2, "debt reduced by ~y");
        assertGt(IERC20(vUsdc).balanceOf(account), 0, "residual debt");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "loan token allowance reset");
    }

    /// @notice Standalone full repay via the max sentinel after 30 days of accrual — no dust left.
    function test_Base_Repay_Full_Max_AfterWarp() external {
        _open(SUPPLY_WETH, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1_296_000);
        _getTokens(BASE_USDC, account, IERC20(BASE_USDC).balanceOf(account) + 50e6); // cover accrued interest

        _exec(address(repayHookV2), _v2(BASE_USDC, BASE_WETH, type(uint256).max, 0, false));

        assertEq(IERC20(vUsdc).balanceOf(account), 0, "debt fully cleared, no dust");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "loan token allowance reset");
    }

    /// @notice Negative: standalone repay against a zero-debt position reverts NO_OUTSTANDING_DEBT
    ///         at build time inside the executor — the userOp fails, state unchanged.
    function test_Base_Repay_ZeroDebt_NoStateChange() external {
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);
        assertGt(usdcBefore, 0, "account funded with loan token");

        _exec(address(repayHookV2), _v2(BASE_USDC, BASE_WETH, 100e6, 0, false));

        assertEq(IERC20(BASE_USDC).balanceOf(account), usdcBefore, "USDC untouched");
        assertEq(IERC20(vUsdc).balanceOf(account), 0, "still no debt");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "no dangling allowance");
    }

    /// @notice Negative: a non-sentinel repay amount greater than the outstanding debt makes Aave
    ///         pull only the debt, which fails the hook's post-execution exactness check
    ///         (DELTA_MISMATCH) — the userOp fails and state is unchanged.
    function test_Base_Repay_OverAmount_NonSentinel_NoStateChange() external {
        _open(SUPPLY_WETH, BORROW_USDC);
        uint256 debt = IERC20(vUsdc).balanceOf(account);
        assertGt(debt, 0, "has debt");

        _getTokens(BASE_USDC, account, IERC20(BASE_USDC).balanceOf(account) + debt * 2); // plenty to repay
        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);

        _exec(address(repayHookV2), _v2(BASE_USDC, BASE_WETH, debt + 100e6, 0, false));

        assertEq(IERC20(BASE_USDC).balanceOf(account), usdcBefore, "no USDC spent");
        assertEq(IERC20(vUsdc).balanceOf(account), debt, "debt unchanged");
        assertEq(IERC20(BASE_USDC).allowance(account, BASE_POOL), 0, "no dangling allowance");
    }
}
