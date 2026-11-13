// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { SwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import { ApproveAndSwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IRedSnwapper } from "../../../src/vendor/sushiswap/IRedSnwapper.sol";
import { IRouteProcessor7 } from "../../../src/vendor/sushiswap/IRouteProcessor7.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockRedSnwapper, MockRouteProcessor } from "./SushiSwapHookE2E.t.sol";
import { SushiKatanaFixtures } from "./SushiKatanaFixtures.sol";

/// @title SushiSwapExecutorE2E
/// @author Superform Labs
/// @notice CI-runnable (no RPC) end-to-end through a REAL Nexus account + `SuperExecutor` UserOps, with the
///         RedSnwapper / executor semantics reproduced by mocks. Covers what the direct `build()` suites cannot: the
///         executor's hook lifecycle (setExecutionContext → pre → executions → post → reset), predecessor
///         outAmount/outToken propagation through transient storage, multi-hook chains where a Sushi swap feeds a
///         second Sushi swap, and UserOp-level atomicity when the hook floor fails.
contract SushiSwapExecutorE2E is Helpers, RhinestoneModuleKit, InternalHelpers, SushiKatanaFixtures {
    using ModuleKitHelpers for *;

    MockRedSnwapper internal rs;
    MockRouteProcessor internal rp;
    SwapSushiSwapHook internal swapHook;
    ApproveAndSwapSushiSwapHook internal approveHook;
    ApproveERC20Hook internal approveErc20Hook;

    AccountInstance internal instance;
    address internal account;
    ISuperExecutor internal superExecutor;

    MockERC20 internal usdc;
    MockERC20 internal kat;
    MockERC20 internal weth;

    uint256 internal constant IN = 1000e18;
    uint256 internal constant QUOTE = 1000e18;
    uint256 internal constant OUTER_MIN = 990e18;
    uint256 internal constant HEADER_MIN = 995e18;

    receive() external payable { }

    function setUp() public {
        rs = new MockRedSnwapper();
        rp = new MockRouteProcessor();
        vm.deal(address(rp), 10_000 ether);
        usdc = new MockERC20("USDC", "USDC", 18);
        kat = new MockERC20("KAT", "KAT", 18);
        weth = new MockERC20("WETH", "WETH", 18);

        swapHook = new SwapSushiSwapHook(address(rs), address(rp), NATIVE);
        approveHook = new ApproveAndSwapSushiSwapHook(address(rs), address(rp), NATIVE);
        approveErc20Hook = new ApproveERC20Hook();

        instance = makeAccountInstance(keccak256("sushi-executor-e2e"));
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
        assertEq(kat.balanceOf(account), QUOTE, "output received");
        assertEq(usdc.allowance(account, address(rs)), 0, "allowance reset");
        assertEq(rp.lastInputUsed(), IN);
    }

    function test_UserOp_ApproveHook_PlusPlainSwap_Chained80_And120() public {
        _chained(IN * 80 / 100);
        _chained(IN * 120 / 100);
    }

    function _chained(uint256 actual) internal {
        uint256 usdcBefore = usdc.balanceOf(account);
        uint256 katBefore = kat.balanceOf(account);
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(address(usdc), address(rs), actual, false),
                address(swapHook),
                _data(address(usdc), address(kat), IN, HEADER_MIN, true, _tx(address(usdc), address(kat), IN))
            )
        );
        assertEq(usdcBefore - usdc.balanceOf(account), actual, "spent the predecessor amount");
        assertEq(kat.balanceOf(account) - katBefore, actual, "1:1 at the scaled size (cap scaled)");
        assertEq(rp.lastInputUsed(), actual, "executor swapped exactly the rescaled input");
        assertEq(usdc.allowance(account, address(rs)), 0, "predecessor allowance consumed");
    }

    /// @notice Sushi feeds Sushi: swap USDC→KAT, then KAT→WETH sized from the FIRST swap's outAmount/outToken. The
    ///         second header is quoted for 2x the amount the first swap actually produced, so the second hook must
    ///         read the predecessor (outToken == KAT) and rescale both heads down to 50%.
    function test_UserOp_SushiFeedsSushi_OutTokenAndAmountPropagate() public {
        uint256 secondQuoteIn = 2 * QUOTE; // deliberately mis-sized: real input will be QUOTE
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        bytes memory second = _data(
            address(kat),
            address(weth),
            secondQuoteIn,
            2 * HEADER_MIN,
            true,
            _tx(address(kat), address(weth), secondQuoteIn)
        );

        executeOp(_op2(address(approveHook), first, address(approveHook), second));

        assertEq(kat.balanceOf(account), 0, "all KAT from the first swap went into the second");
        assertEq(weth.balanceOf(account), QUOTE, "second swap output == first swap output (1:1 mock)");
        assertEq(rp.lastInputUsed(), QUOTE, "second swap consumed exactly the first swap's output");
        assertEq(kat.allowance(account, address(rs)), 0);
    }

    /// @notice REGRESSION (review finding): same hook instance chained to itself. The executor advances BaseHook's
    ///         context between build and pre/post, so a naive `prevHook.getOutAmount` in `_postExecute` read this
    ///         hook's OWN balance snapshot: a pre-seeded 2x-quote output balance produced a bogus floor (false
    ///         revert) and a zero balance produced a ZERO floor (vacuous guarantee). Both must be impossible.
    function test_UserOp_SushiFeedsSushi_PreSeededOutputBalance_DoesNotFalselyRevert() public {
        weth.mint(account, 2 * QUOTE); // pre-existing output of the SECOND swap, 2x its quote
        kat.mint(account, 3 * QUOTE); // pre-existing output of the FIRST swap too
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        bytes memory second = _data(
            address(kat), address(weth), 2 * QUOTE, 2 * HEADER_MIN, true, _tx(address(kat), address(weth), 2 * QUOTE)
        );

        executeOp(_op2(address(approveHook), first, address(approveHook), second));

        assertEq(kat.balanceOf(account), 3 * QUOTE, "second swap consumed exactly the first swap's output");
        assertEq(weth.balanceOf(account), 3 * QUOTE, "pre-seeded + swapped");
        assertEq(rp.lastInputUsed(), QUOTE);
    }

    /// @notice REGRESSION: the scaled floor on an adjacent same-instance second swap is REAL and SCALED. Rate 0.9955
    ///         keeps leg 1 above its floors (995.5 >= 995) but leg 2 (input 995.5, out 991.02) is below its scaled
    ///         floor ceil(1990 * 995.5 / 2000) = 991.03e18... i.e. 991.0225e18 < 991.0225e18? — see exact numbers:
    ///         required = ceil(1990e18 * 995.5e18 / 2000e18) = 990.5225e18... the mock's 1:1 cap makes out == input
    ///         * rate = 991.02e18 >= 990.52e18, so use a header min that binds: 2x(996e18) -> required 991.518e18.
    function test_UserOp_SushiFeedsSushi_ScaledFloorStillEnforced() public {
        rp.setRate(0.9955e18);
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        // second header min 2 * 996e18 scaled by the actual (995.5e18 / 2000e18) = 991.518e18 > 991.02e18 received
        bytes memory second = _data(
            address(kat), address(weth), 2 * QUOTE, 2 * 996e18, true, _tx(address(kat), address(weth), 2 * QUOTE)
        );
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op2(address(approveHook), first, address(approveHook), second);
        instance.expect4337Revert(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(op);

        assertEq(usdc.balanceOf(account), usdcBefore, "whole op rolled back");
        assertEq(weth.balanceOf(account), 0);
    }

    /// @notice The SCALED hook floor fires through a real executor with the flag on (review F1): at 50% the floor
    ///         is ceil(995e18 / 2) = 497.5e18; rate 0.994 -> 497e18 received -> revert; rate 0.996 -> 498e18 -> ok
    ///         (the UNSCALED 995e18 would have rejected it, proving the threshold is the scaled one).
    function test_UserOp_Chained_ScaledHookFloor_ThroughExecutor() public {
        uint256 actual = IN / 2;
        bytes memory approve = _createApproveHookData(address(usdc), address(rs), actual, false);
        bytes memory swap =
            _data(address(usdc), address(kat), IN, HEADER_MIN, true, _tx(address(usdc), address(kat), IN));

        rp.setRate(0.994e18);
        uint256 usdcBefore = usdc.balanceOf(account);
        instance.expect4337Revert(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(_op2(address(approveErc20Hook), approve, address(approveHook), swap));
        assertEq(usdc.balanceOf(account), usdcBefore, "revert path: nothing spent");
        assertEq(kat.balanceOf(account), 0);

        rp.setRate(0.996e18);
        executeOp(_op2(address(approveErc20Hook), approve, address(approveHook), swap));
        assertEq(usdcBefore - usdc.balanceOf(account), actual, "pass path: spent the actual amount");
        assertEq(kat.balanceOf(account), 498e18, "498 >= scaled floor 497.5 (unscaled 995 would have rejected)");
    }

    /// @notice The predecessor publishes the WRONG token for the second swap's header: the second hook refuses the
    ///         context and the whole UserOp reverts, leaving the first swap undone too (atomic batch).
    function test_UserOp_SushiFeedsSushi_PrevTokenMismatch_RevertsWholeOp() public {
        bytes memory first =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        // second header claims its input is USDC, but the predecessor's outToken is KAT
        bytes memory second =
            _data(address(usdc), address(weth), IN, HEADER_MIN, true, _tx(address(usdc), address(weth), IN));
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op2(address(approveHook), first, address(approveHook), second);
        instance.expect4337Revert(ApproveAndSwapSushiSwapHook.PREV_TOKEN_MISMATCH.selector);
        executeOp(op);

        assertEq(usdc.balanceOf(account), usdcBefore, "first swap rolled back with the op");
        assertEq(kat.balanceOf(account), 0);
        assertEq(weth.balanceOf(account), 0);
    }

    /// @notice Sushi's floor passes, the standardized header floor does not: the hook's `_postExecute` reverts and
    ///         the UserOp is atomic, so no input leaves the account and no approval survives.
    function test_UserOp_HookFloor_RevertsAtomically() public {
        rp.setRate(0.992e18); // 992 > outer 990, < header 995
        bytes memory data =
            _data(address(usdc), address(kat), IN, HEADER_MIN, false, _tx(address(usdc), address(kat), IN));
        uint256 usdcBefore = usdc.balanceOf(account);

        UserOpData memory op = _op1(address(approveHook), data);
        instance.expect4337Revert(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
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
        assertEq(kat.balanceOf(account), QUOTE, "native-in output");
        assertGe(ethBefore - account.balance, IN, "value forwarded");
        assertEq(rp.lastValue(), IN);

        uint256 ethMid = account.balance;
        executeOp(
            _op1(
                address(approveHook),
                _data(address(usdc), NATIVE, IN, HEADER_MIN, false, _tx(address(usdc), NATIVE, IN))
            )
        );
        // the account pays its own UserOp prefund in this local setup, hence the small tolerance
        assertApproxEqAbs(account.balance - ethMid, QUOTE, 0.01 ether, "native-out delivered to the account");
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
        assertEq(kat.balanceOf(account), amounts[0]);
    }

    /// @notice The executor's transient context is per (hook, account): a second account running the same hook
    ///         in a later op does not see the first account's snapshot.
    function test_UserOp_TwoAccounts_IndependentContext() public {
        AccountInstance memory other = makeAccountInstance(keccak256("sushi-executor-e2e-other"));
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
        assertEq(kat.balanceOf(other.account), 777e18 + QUOTE);
        assertEq(kat.balanceOf(account), QUOTE);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function executeOpExternal(UserOpData memory op) external {
        executeOp(op);
    }

    function _inner(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address to
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IRouteProcessor7.processRoute.selector,
            tokenIn,
            amountIn,
            tokenOut,
            amountIn,
            /* 1:1 cap */
            to,
            hex"01",
            true,
            uint32(0)
        );
    }

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
        return abi.encodeWithSelector(
            IRedSnwapper.snwap.selector,
            tokenIn,
            amountIn,
            recipient,
            tokenOut,
            amountIn * OUTER_MIN / QUOTE,
            address(rp),
            _inner(tokenIn, tokenOut, amountIn, recipient)
        );
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
