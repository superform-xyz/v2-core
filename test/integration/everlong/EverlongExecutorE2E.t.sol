// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { SwapEverlongHook } from "../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISwapRouter02 } from "../../../src/vendor/everlong/ISwapRouter02.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockWETH9, MockSwapRouter02 } from "./EverlongHookE2E.t.sol";
import { EverlongKatanaFixtures } from "./EverlongKatanaFixtures.sol";

/// @title EverlongExecutorE2E
/// @author Superform Labs
/// @notice CI-runnable (no RPC) end-to-end through a REAL Nexus account + `SuperExecutor` UserOps, with the
///         SwapRouter02 semantics reproduced by mocks. Covers what the direct `build()` suites cannot: the
///         executor's hook lifecycle (setExecutionContext → pre → executions → post → reset), predecessor
///         outAmount/outToken propagation through transient storage, multi-hook chains where a Sushi swap feeds a
///         second Everlong swap, and UserOp-level atomicity when the hook floor fails.
contract EverlongExecutorE2E is Helpers, RhinestoneModuleKit, InternalHelpers, EverlongKatanaFixtures {
    using ModuleKitHelpers for *;

    MockWETH9 internal weth;
    MockSwapRouter02 internal rp; // the venue
    address internal rs; // approval spender == the router
    uint256 internal constant DEADLINE = 1_800_000_000;
    address internal constant THIS = address(2);
    SwapEverlongHook internal swapHook;
    ApproveAndSwapEverlongHook internal approveHook;
    ApproveERC20Hook internal approveErc20Hook;

    AccountInstance internal instance;
    address internal account;
    ISuperExecutor internal superExecutor;

    MockERC20 internal usdc;
    MockERC20 internal kat;
    MockERC20 internal third;

    uint256 internal constant IN = 1000e18;
    uint256 internal constant QUOTE = 1000e18;
    uint256 internal constant OUTER_MIN = 990e18;
    uint256 internal constant HEADER_MIN = 994e18; // post-fee floor (tail 990 pre-fee, 4 bps)

    function _net(uint256 gross) internal pure returns (uint256) {
        return gross - gross * 4 / 10_000;
    }

    receive() external payable { }

    function setUp() public {
        vm.warp(DEADLINE - 1000);
        weth = new MockWETH9();
        rp = new MockSwapRouter02(weth);
        rs = address(rp);
        vm.deal(address(weth), 100_000 ether);
        usdc = new MockERC20("USDC", "USDC", 18);
        kat = new MockERC20("KAT", "KAT", 18);
        third = new MockERC20("THIRD", "THR", 18);

        swapHook = new SwapEverlongHook(address(rp), address(weth), NATIVE);
        approveHook = new ApproveAndSwapEverlongHook(address(rp), address(weth), NATIVE);
        approveErc20Hook = new ApproveERC20Hook();

        instance = makeAccountInstance(keccak256("everlong-executor-e2e"));
        account = instance.account;
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        usdc.mint(account, 100 * IN);
        vm.deal(account, 10 * IN); // native-in quotes are 1000 ether
    }

    /*//////////////////////////////////////////////////////////////
                               USEROP FLOWS
    //////////////////////////////////////////////////////////////*/

    function test_UserOp_ApproveAndSwap_FlagOff() public {
        bytes memory data =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        uint256 before = usdc.balanceOf(account);

        executeOp(_op1(address(approveHook), data));

        assertEq(before - usdc.balanceOf(account), IN, "input spent");
        assertEq(kat.balanceOf(account), _net(QUOTE), "output received (post 4 bps fee)");
        assertEq(usdc.allowance(account, address(rs)), 0, "allowance reset");
        assertEq(rp.legsExecuted(), 2);
    }

    function test_UserOp_ApproveHook_PlusPlainSwap_Chained80_And120() public {
        _chained(IN * 80 / 100);
        _chained(IN * 120 / 100);
    }

    function _chained(uint256 actual) internal {
        uint256 usdcBefore = usdc.balanceOf(account);
        uint256 katBefore = kat.balanceOf(account);
        uint256 legsBefore = rp.legsExecuted();
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(address(usdc), address(rs), actual, false),
                address(swapHook),
                _data(address(usdc), address(kat), IN, HEADER_MIN, true, _tx(address(usdc), address(kat), IN))
            )
        );
        assertEq(usdcBefore - usdc.balanceOf(account), actual, "spent the predecessor amount");
        assertEq(kat.balanceOf(account) - katBefore, _net(actual), "1:1 at the scaled size, post-fee");
        assertEq(rp.legsExecuted() - legsBefore, 2, "both rescaled legs ran");
        assertEq(usdc.allowance(account, address(rs)), 0, "predecessor allowance consumed");
    }

    /// @notice Everlong feeds Everlong: swap USDC→KAT, then KAT→THIRD sized from the FIRST swap's
    /// outAmount/outToken. The second header is quoted for 2x the amount the first swap actually produced, so the
    /// second hook must
    ///         read the predecessor (outToken == KAT) and rescale both heads down to 50%.
    function test_UserOp_EverlongFeedsEverlong_OutTokenAndAmountPropagate() public {
        uint256 secondQuoteIn = 2 * QUOTE; // deliberately mis-sized: real input will be QUOTE
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        bytes memory second = _data(
            address(kat),
            address(third),
            secondQuoteIn,
            2 * HEADER_MIN,
            true,
            _tx(address(kat), address(third), secondQuoteIn)
        );

        executeOp(_op2(address(approveHook), first, address(approveHook), second));

        assertEq(kat.balanceOf(account), 0, "all KAT from the first swap went into the second");
        assertEq(third.balanceOf(account), _net(_net(QUOTE)), "second swap sized from the first's post-fee output");
        assertEq(kat.allowance(account, address(rs)), 0);
    }

    /// @notice REGRESSION (review finding): same hook instance chained to itself. The executor advances BaseHook's
    ///         context between build and pre/post, so a naive `prevHook.getOutAmount` in `_postExecute` read this
    ///         hook's OWN balance snapshot: a pre-seeded 2x-quote output balance produced a bogus floor (false
    ///         revert) and a zero balance produced a ZERO floor (vacuous guarantee). Both must be impossible.
    function test_UserOp_EverlongFeedsEverlong_PreSeededOutputBalance_DoesNotFalselyRevert() public {
        third.mint(account, 2 * QUOTE); // pre-existing output of the SECOND swap, 2x its quote
        kat.mint(account, 3 * QUOTE); // pre-existing output of the FIRST swap too
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        bytes memory second = _data(
            address(kat), address(third), 2 * QUOTE, 2 * HEADER_MIN, true, _tx(address(kat), address(third), 2 * QUOTE)
        );

        executeOp(_op2(address(approveHook), first, address(approveHook), second));

        assertEq(kat.balanceOf(account), 3 * QUOTE, "second swap consumed exactly the first swap's output");
        assertEq(third.balanceOf(account), 2 * QUOTE + _net(_net(QUOTE)), "pre-seeded + swapped (post-fee twice)");
    }

    /// @notice REGRESSION: the scaled floor on an adjacent same-instance second swap is REAL and SCALED. Rate 0.9960:
    ///         leg 1 receives 1000 x 0.996 x 0.9996 = 995.6016 (>= 994 header, tail 990 pre-fee ok); leg 2 input
    ///         995.6016, receives x 0.996 x 0.9996 = 991.23; its scaled floor with a 2 x 996 header min is
    ///         ceil(1992 x 995.6016 / 2000) = 991.62 > 991.23 -> revert.
    function test_UserOp_EverlongFeedsEverlong_ScaledFloorStillEnforced() public {
        rp.setRate(0.996e18);
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        // second header min 2 * 996e18 scaled by the actual (995.5e18 / 2000e18) = 991.518e18 > 991.02e18 received
        bytes memory second = _data(
            address(kat), address(third), 2 * QUOTE, 2 * 996e18, true, _tx(address(kat), address(third), 2 * QUOTE)
        );
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op2(address(approveHook), first, address(approveHook), second);
        instance.expect4337Revert(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(op);

        assertEq(usdc.balanceOf(account), usdcBefore, "whole op rolled back");
        assertEq(third.balanceOf(account), 0);
    }

    /// @notice The SCALED hook floor fires through a real executor with the flag on: at 50% the floor is
    ///         ceil(994e18 / 2) = 497e18; rate 0.994 -> 500 x 0.994 x 0.9996 = 496.80e18 received -> revert;
    ///         rate 0.996 -> 497.80e18 -> ok (the UNSCALED 994e18 would have rejected it: the threshold is scaled).
    function test_UserOp_Chained_ScaledHookFloor_ThroughExecutor() public {
        uint256 actual = IN / 2;
        bytes memory approve = _createApproveHookData(address(usdc), address(rs), actual, false);
        bytes memory swap =
            _data(address(usdc), address(kat), IN, HEADER_MIN, true, _tx(address(usdc), address(kat), IN));

        rp.setRate(0.994e18);
        uint256 usdcBefore = usdc.balanceOf(account);
        instance.expect4337Revert(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(_op2(address(approveErc20Hook), approve, address(approveHook), swap));
        assertEq(usdc.balanceOf(account), usdcBefore, "revert path: nothing spent");
        assertEq(kat.balanceOf(account), 0);

        rp.setRate(0.996e18);
        executeOp(_op2(address(approveErc20Hook), approve, address(approveHook), swap));
        assertEq(usdcBefore - usdc.balanceOf(account), actual, "pass path: spent the actual amount");
        assertEq(kat.balanceOf(account), _net(498e18), "post-fee 497.8 >= scaled floor 497 (unscaled 994 would reject)");
    }

    /// @notice The predecessor publishes the WRONG token for the second swap's header: the second hook refuses the
    ///         context and the whole UserOp reverts, leaving the first swap undone too (atomic batch).
    function test_UserOp_EverlongFeedsEverlong_PrevTokenMismatch_RevertsWholeOp() public {
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        // second header claims its input is USDC, but the predecessor's outToken is KAT
        bytes memory second =
            _data(address(usdc), address(third), IN, HEADER_MIN, true, _tx(address(usdc), address(third), IN));
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op2(address(approveHook), first, address(approveHook), second);
        instance.expect4337Revert(ApproveAndSwapEverlongHook.PREV_TOKEN_MISMATCH.selector);
        executeOp(op);

        assertEq(usdc.balanceOf(account), usdcBefore, "first swap rolled back with the op");
        assertEq(kat.balanceOf(account), 0);
        assertEq(third.balanceOf(account), 0);
    }

    /// @notice Everlong's tail floor passes, the standardized header floor does not: the hook's `_postExecute` reverts
    /// and the UserOp is atomic, so no input leaves the account and no approval survives.
    function test_UserOp_HookFloor_RevertsAtomically() public {
        rp.setRate(0.994e18); // tail 994 >= 990 passes; account receives 993.60 < header 994 -> hook floor reverts
        bytes memory data =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op1(address(approveHook), data);
        instance.expect4337Revert(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(op);

        assertEq(usdc.balanceOf(account), usdcBefore, "nothing spent");
        assertEq(kat.balanceOf(account), 0, "nothing received");
        assertEq(usdc.allowance(account, address(rs)), 0, "no dangling approval");
    }

    function test_UserOp_NativeIn_And_NativeOut() public {
        uint256 ethBefore = account.balance;
        executeOp(
            _op1(
                address(approveHook), _data(NATIVE, address(kat), IN, HEADER_MIN, false, _tx(NATIVE, address(kat), IN))
            )
        );
        assertEq(kat.balanceOf(account), _net(QUOTE), "native-in output (post-fee)");
        assertGe(ethBefore - account.balance, IN, "value forwarded");
        assertEq(rp.lastValue(), IN, "value forwarded == sum of legs");

        uint256 ethMid = account.balance;
        executeOp(
            _op1(
                address(approveHook),
                _data(address(usdc), NATIVE, IN, HEADER_MIN, false, _tx(address(usdc), NATIVE, IN))
            )
        );
        // the account pays its own UserOp prefund in this local setup, hence the small tolerance
        assertApproxEqAbs(account.balance - ethMid, _net(QUOTE), 0.01 ether, "native-out delivered post-fee");
    }

    /// @notice OMS sizing path: `replaceCalldataAmounts` resizes header + payload, then the resized data executes
    ///         with the flag off and the hook floor tracks the new size.
    function test_UserOp_ReplaceCalldataAmounts_ThenExecute() public {
        bytes memory quoted =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = IN * 3 / 10;
        bytes memory resized = approveHook.replaceCalldataAmounts(quoted, amounts);
        assertEq(approveHook.decodeInputAmount(resized), amounts[0]);
        assertEq(approveHook.decodeOutputMin(resized), Math.mulDiv(HEADER_MIN, 3, 10, Math.Rounding.Ceil));

        uint256 before = usdc.balanceOf(account);
        executeOp(_op1(address(approveHook), resized));
        assertEq(before - usdc.balanceOf(account), amounts[0]);
        assertEq(kat.balanceOf(account), _net(amounts[0]));
    }

    /// @notice The executor's transient context is per (hook, account): a second account running the same hook
    ///         in a later op does not see the first account's snapshot.
    function test_UserOp_TwoAccounts_IndependentContext() public {
        AccountInstance memory other = makeAccountInstance(keccak256("everlong-executor-e2e-other"));
        other.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        usdc.mint(other.account, IN);
        kat.mint(other.account, 777e18); // pre-existing output must not be counted as swap output

        executeOp(
            _op1(
                address(approveHook),
                _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN))
            )
        );
        UserOpData memory op = _getExecOps(
            other,
            superExecutor,
            abi.encode(
                ISuperExecutor.ExecutorEntry({
                    hooksAddresses: _hooks1(address(approveHook)),
                    hooksData: _datas1(
                        _dataFor(
                            other.account,
                            address(usdc),
                            address(kat),
                            IN,
                            HEADER_MIN,
                            false,
                            _txFor(other.account, address(usdc), address(kat), IN)
                        )
                    )
                })
            )
        );
        executeOp(op);
        assertEq(kat.balanceOf(other.account), 777e18 + _net(QUOTE));
        assertEq(kat.balanceOf(account), _net(QUOTE));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function executeOpExternal(UserOpData memory op) external {
        executeOp(op);
    }

    function _eis(address tIn, address tOut, uint256 amountIn) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(tIn, tOut, 500, THIS, amountIn, 0, 0)
        );
    }

    /// @dev Two legs (60/40) + tail; tail min = 99% of the 1:1 quote (pre-fee); unwrap tail when tokenOut is native.
    function _txFor(
        address recipient,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (bytes memory)
    {
        bool nIn = tokenIn == NATIVE;
        bool nOut = tokenOut == NATIVE;
        address tIn = nIn ? address(weth) : tokenIn;
        address tOut = nOut ? address(weth) : tokenOut;
        uint256 n = (nIn || nOut) ? 4 : 3;
        bytes[] memory c = new bytes[](n);
        c[0] = _eis(tIn, tOut, amountIn * 6 / 10);
        c[1] = _eis(tIn, tOut, amountIn - amountIn * 6 / 10);
        c[2] = nOut
            ? abi.encodeWithSelector(
                ISwapRouter02.unwrapWETH9WithFee.selector,
                amountIn * OUTER_MIN / QUOTE,
                recipient,
                uint256(4),
                FEE_RECIPIENT
            )
            : abi.encodeWithSelector(
                ISwapRouter02.sweepTokenWithFee.selector,
                tOut,
                amountIn * OUTER_MIN / QUOTE,
                recipient,
                uint256(4),
                FEE_RECIPIENT
            );
        if (n == 4) c[3] = abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
        return abi.encodeWithSelector(ISwapRouter02.multicall.selector, DEADLINE, c);
    }

    function _tx(address tokenIn, address tokenOut, uint256 amountIn) private view returns (bytes memory) {
        return _txFor(account, tokenIn, tokenOut, amountIn);
    }

    function _dataFor(
        address,
        address in_,
        address out_,
        uint256 amount,
        uint256 outputMin,
        bool flag,
        bytes memory txData
    )
        private
        pure
        returns (bytes memory)
    {
        return _hookData(in_, out_, amount, amount, outputMin, flag, txData);
    }

    function _data(
        address in_,
        address out_,
        uint256 amount,
        uint256 outputMin,
        bool flag,
        bytes memory txData
    )
        private
        pure
        returns (bytes memory)
    {
        return _hookData(in_, out_, amount, amount, outputMin, flag, txData);
    }

    function _hooks1(address h) private pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = h;
    }

    function _datas1(bytes memory d) private pure returns (bytes[] memory a) {
        a = new bytes[](1);
        a[0] = d;
    }

    function _op1(address hook, bytes memory data) internal returns (UserOpData memory) {
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: _hooks1(hook), hooksData: _datas1(data) }))
        );
    }

    function _op2(
        address hookA,
        bytes memory dataA,
        address hookB,
        bytes memory dataB
    )
        internal
        returns (UserOpData memory)
    {
        address[] memory hooks = new address[](2);
        hooks[0] = hookA;
        hooks[1] = hookB;
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataA;
        datas[1] = dataB;
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas }))
        );
    }
}
