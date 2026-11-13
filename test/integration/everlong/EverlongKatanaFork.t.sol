// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SwapEverlongHook } from "../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { EverlongAmountUpdater } from "../../../src/libraries/EverlongAmountUpdater.sol";
import { ISwapRouter02 } from "../../../src/vendor/everlong/ISwapRouter02.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { EverlongKatanaFixtures } from "./EverlongKatanaFixtures.sol";

/// @title EverlongKatanaFork
/// @author Superform Labs
/// @notice Same-chain end-to-end proof on REAL Katana at a pinned block: the live Everlong Router (canonical
///         SwapRouter02), live vbUSDC / KAT / vbETH liquidity and the UNMODIFIED Everlong Swap API calldata captured in
///         `EverlongKatanaFixtures` (only the tail recipient word is rewritten to the test account). Happy paths run as
///         real UserOps through `SuperExecutor` on a Nexus account.
/// @dev Fee identity asserted on every swap: the tail pays `balance x (1 - 4 bps)` to the account and the 4 bps to
///      FEE_RECIPIENT, so `fee == (out + fee) x 4 / 10_000` and the hook's post-fee header floor holds. Runs against
///      KATANA_RPC_URL (default public RPC); skips without connectivity; excluded from `ftest-ci`.
contract EverlongKatanaFork is Helpers, RhinestoneModuleKit, InternalHelpers, EverlongKatanaFixtures {
    using ModuleKitHelpers for *;

    /// @dev Production SuperExecutor on Katana (script/output/prod/747474/Katana-latest.json)
    address internal constant PROD_SUPER_EXECUTOR = 0x9cC8EDCC41154aaFC74D261aD3D87140D21F6281;

    SwapEverlongHook internal swapHook;
    ApproveAndSwapEverlongHook internal approveHook;
    ApproveERC20Hook internal approveErc20Hook;
    MockHook internal nativePrev;

    AccountInstance internal instance;
    address internal account;
    ISuperExecutor internal superExecutor;
    bool internal forked;

    receive() external payable { }

    function setUp() public {
        string memory rpc = envOr("KATANA_RPC_URL", "https://rpc.katana.network");
        if (bytes(rpc).length == 0) return;
        try vm.createSelectFork(rpc, KATANA_BLOCK) {
            forked = true;
        } catch {
            return;
        }

        swapHook = new SwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        approveHook = new ApproveAndSwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        approveErc20Hook = new ApproveERC20Hook();
        nativePrev = new MockHook(ISuperHook.HookType.NONACCOUNTING, NATIVE);

        instance = makeAccountInstance(keccak256("everlong-katana"));
        account = instance.account;
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        deal(VB_USDC, account, 1_000_000e6);
        vm.deal(account, 100 ether);
        // prefund the EntryPoint deposit so UserOp gas never leaves the account balance: native deltas are exact
        instance.aux.entrypoint.depositTo{ value: 10 ether }(account);
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /*//////////////////////////////////////////////////////////////
                               LIVE CHAIN
    //////////////////////////////////////////////////////////////*/

    function test_Fork_IsKatana_RouterLive_Weth9MatchesCtor() public {
        _requireFork();
        assertEq(block.chainid, KATANA_CHAIN_ID);
        assertGt(EVERLONG_ROUTER.code.length, 0, "router live");
        assertEq(ISwapRouter02(EVERLONG_ROUTER).WETH9(), WETH9, "router WETH9 is vbETH");
        assertLt(block.timestamp, DEADLINE_USDC_KAT, "fixtures are still valid at the pinned block");
    }

    function test_Fixtures_RecipientRewrite_AllSamples() public view {
        assertEq(_f(_withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)).recipient, account);
        assertEq(_f(_withRecipient(TX_NATIVE_IN_USDC, TAIL_RECIPIENT_OFFSET_NATIVE_USDC, account)).recipient, account);
        assertEq(_f(_withRecipient(TX_USDC_NATIVE_OUT, TAIL_RECIPIENT_OFFSET_USDC_NATIVE, account)).recipient, account);
        assertEq(_f(_withRecipient(TX_KAT_USDC, TAIL_RECIPIENT_OFFSET_KAT_USDC, account)).recipient, account);
    }

    /*//////////////////////////////////////////////////////////////
                      SAME CHAIN, usePrevHookAmount = false
    //////////////////////////////////////////////////////////////*/

    function test_SameChain_ApproveAndSwap_Equal_FlagOff() public {
        _requireFork();
        Snap memory s = _snap(KAT);
        uint256 gasBefore = gasleft();
        executeOp(_op1(address(approveHook), _usdcKatData(false)));
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_KAT_IN, "vbUSDC spent exactly");
        _assertFeeIdentityAndFloor(s, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_IN, HEADER_MIN_USDC_KAT, TAIL_MIN_USDC_KAT);
        assertEq(IERC20(VB_USDC).allowance(account, EVERLONG_ROUTER), 0, "allowance reset");
        assertLt(gasUsed, KATANA_PER_TX_GAS_CAP, "fits under Katana's per-tx gas cap");
        _assertNoDust(s, KAT);
    }

    function test_SameChain_PlainSwap_Equal_FlagOff_WithApproveHook() public {
        _requireFork();
        Snap memory s = _snap(KAT);
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, EVERLONG_ROUTER, QUOTE_USDC_KAT_IN, false),
                address(swapHook),
                _usdcKatData(false)
            )
        );
        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_KAT_IN);
        _assertFeeIdentityAndFloor(s, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_IN, HEADER_MIN_USDC_KAT, TAIL_MIN_USDC_KAT);
        _assertNoDust(s, KAT);
    }

    /// @notice Through the SuperExecutor DEPLOYED on Katana (production bytecode), chained at 95%.
    function test_SameChain_ThroughDeployedProdSuperExecutor() public {
        _requireFork();
        assertGt(PROD_SUPER_EXECUTOR.code.length, 0);
        AccountInstance memory prodInstance = makeAccountInstance(keccak256("everlong-katana-prod"));
        prodInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: PROD_SUPER_EXECUTOR, data: "" });
        address prodAccount = prodInstance.account;
        deal(VB_USDC, prodAccount, 10 * QUOTE_USDC_KAT_IN);
        uint256 actual = QUOTE_USDC_KAT_IN * 95 / 100;

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(approveHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _createApproveHookData(VB_USDC, EVERLONG_ROUTER, actual, false);
        datas[1] = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            true,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, prodAccount)
        );
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(prodAccount);
        executeOp(
            _getExecOps(
                prodInstance,
                ISuperExecutor(PROD_SUPER_EXECUTOR),
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas }))
            )
        );
        assertEq(usdcBefore - IERC20(VB_USDC).balanceOf(prodAccount), actual, "spent exactly the actual amount");
        assertGe(
            IERC20(KAT).balanceOf(prodAccount),
            Math.mulDiv(HEADER_MIN_USDC_KAT, actual, QUOTE_USDC_KAT_IN, Math.Rounding.Ceil),
            "scaled post-fee floor through the production executor"
        );
        assertEq(IERC20(VB_USDC).allowance(prodAccount, EVERLONG_ROUTER), 0);
    }

    /*//////////////////////////////////////////////////////////////
                  CHAINED, usePrevHookAmount = true (95 / 100 / 105)
    //////////////////////////////////////////////////////////////*/

    function test_Chained_Below95_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 95 / 100);
    }

    function test_Chained_Equal100_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN);
    }

    function test_Chained_Above105_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 105 / 100);
    }

    function test_Chained_Below95_ApproveAndSwap() public {
        _requireFork();
        _chainedUsdcKat(address(approveHook), QUOTE_USDC_KAT_IN * 95 / 100);
    }

    function test_Chained_Above105_ApproveAndSwap() public {
        _requireFork();
        _chainedUsdcKat(address(approveHook), QUOTE_USDC_KAT_IN * 105 / 100);
    }

    /// @notice Monotonicity across sizes on live liquidity: more input, more output (separate fork state each).
    function test_Chained_Monotone_95_100_105() public {
        _requireFork();
        uint256 snapshot = vm.snapshotState();
        uint256 o95 = _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 95 / 100);
        vm.revertToState(snapshot);
        uint256 o100 = _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN);
        vm.revertToState(snapshot);
        uint256 o105 = _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 105 / 100);
        assertLt(o95, o100);
        assertLt(o100, o105);
        // the API's assumedAmountOut (pre-fee) is reproduced within a few percent at 100%: the quote was taken ~4 h
        // after the pinned block, so pool prices differ slightly (1.6% observed)
        assertApproxEqRel(o100 + o100 * FEE_BIPS / (10_000 - FEE_BIPS), QUOTE_USDC_KAT_OUT, 0.03e18);
    }

    /// @dev `[ApproveERC20Hook(actual) -> everlong(flag)]`: the bundler's destination shape. Every leg is rescaled by
    ///      the hook, the sum equals `actual` exactly (the router pulls exactly that), the fee identity holds.
    function _chainedUsdcKat(address hook, uint256 actual) internal returns (uint256 out) {
        Snap memory s = _snap(KAT);
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, EVERLONG_ROUTER, actual, false),
                hook,
                _usdcKatData(true)
            )
        );
        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), actual, "spent exactly the actual amount");
        out = _assertFeeIdentityAndFloor(s, KAT, actual, QUOTE_USDC_KAT_IN, HEADER_MIN_USDC_KAT, TAIL_MIN_USDC_KAT);
        assertEq(IERC20(VB_USDC).allowance(account, EVERLONG_ROUTER), 0, "allowance reset");
        _assertNoDust(s, KAT);
    }

    /*//////////////////////////////////////////////////////////////
                               NATIVE IN / OUT
    //////////////////////////////////////////////////////////////*/

    function test_NativeIn_Equal_FlagOff_ApproveVariant() public {
        _requireFork();
        Snap memory s = _snap(VB_USDC);
        uint256 ethBefore = account.balance;
        executeOp(_op1(address(approveHook), _nativeInData(false)));
        assertEq(ethBefore - account.balance, QUOTE_NATIVE_USDC_IN, "exactly the swap value left the account");
        _assertFeeIdentityAndFloor(
            s, VB_USDC, QUOTE_NATIVE_USDC_IN, QUOTE_NATIVE_USDC_IN, HEADER_MIN_NATIVE_USDC, TAIL_MIN_NATIVE_USDC
        );
        assertEq(EVERLONG_ROUTER.balance, 0, "refundETH left no ETH on the router");
        _assertNoDust(s, VB_USDC);
    }

    function test_NativeIn_Chained90_PlainVariant() public {
        _requireFork();
        uint256 actual = QUOTE_NATIVE_USDC_IN * 90 / 100;
        nativePrev.setOutAmount(actual, account);
        nativePrev.setOutToken(NATIVE);
        Snap memory s = _snap(VB_USDC);
        uint256 ethBefore = account.balance;
        executeOp(_op2(address(nativePrev), hex"", address(swapHook), _nativeInData(true)));
        assertEq(ethBefore - account.balance, actual, "exactly the scaled value (sum of rescaled legs) was forwarded");
        _assertFeeIdentityAndFloor(
            s, VB_USDC, actual, QUOTE_NATIVE_USDC_IN, HEADER_MIN_NATIVE_USDC, TAIL_MIN_NATIVE_USDC
        );
        _assertNoDust(s, VB_USDC);
    }

    function test_NativeOut_Equal_FlagOff() public {
        _requireFork();
        Snap memory s = _snap(NATIVE);
        executeOp(_op1(address(approveHook), _nativeOutData(false)));
        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_NATIVE_IN);
        _assertFeeIdentityAndFloor(
            s, NATIVE, QUOTE_USDC_NATIVE_IN, QUOTE_USDC_NATIVE_IN, HEADER_MIN_USDC_NATIVE, TAIL_MIN_USDC_NATIVE
        );
        _assertNoDust(s, NATIVE);
    }

    function test_NativeOut_Chained110() public {
        _requireFork();
        uint256 actual = QUOTE_USDC_NATIVE_IN * 110 / 100;
        Snap memory s = _snap(NATIVE);
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, EVERLONG_ROUTER, actual, false),
                address(swapHook),
                _nativeOutData(true)
            )
        );
        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), actual);
        _assertFeeIdentityAndFloor(
            s, NATIVE, actual, QUOTE_USDC_NATIVE_IN, HEADER_MIN_USDC_NATIVE, TAIL_MIN_USDC_NATIVE
        );
        _assertNoDust(s, NATIVE);
    }

    /// @notice vbUSDC -> ETH then ETH -> vbUSDC in ONE UserOp, the second swap sized from the first's real native
    ///         output (~0.049 ETH vs a 1 ETH quote: every one of the 6 legs rescaled to ~4.9%).
    function test_RoundTrip_UsdcToNativeToUsdc_SecondSwapSizedFromFirst() public {
        _requireFork();
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        uint256 ethBefore = account.balance;
        executeOp(_op2(address(approveHook), _nativeOutData(false), address(swapHook), _nativeInData(true)));
        assertEq(account.balance, ethBefore, "the second swap consumed exactly the first swap's native output");
        uint256 usdcAfter = IERC20(VB_USDC).balanceOf(account);
        assertLe(usdcBefore - usdcAfter, QUOTE_USDC_NATIVE_IN * 3 / 100, "round-trip cost within two floors + fees");
    }

    /*//////////////////////////////////////////////////////////////
                         REVERTS / CHARACTERIZATION
    //////////////////////////////////////////////////////////////*/

    function test_Revert_HookFloor_TightHeaderMin_ThroughExecutor() public {
        _requireFork();
        // a header min the live output cannot reach (2x the quote): Everlong's tail floor passes, the hook floor
        // fails, the op reverts atomically
        bytes memory data = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            QUOTE_USDC_KAT_OUT * 2,
            false,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        instance.expect4337Revert(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(_op1(address(approveHook), data));
        assertEq(IERC20(VB_USDC).balanceOf(account), usdcBefore, "atomic: nothing spent");
        assertEq(IERC20(KAT).balanceOf(account), 0);
    }

    function test_Revert_RecipientNotAccount_And_InjectedExactOutput() public {
        _requireFork();
        bytes memory untouched = _hookData(
            VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, HEADER_MIN_USDC_KAT, false, bytes.concat(TX_USDC_KAT)
        );
        vm.expectRevert(SwapEverlongHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(0), account, untouched);

        // inject an exactOutput leg into the live multicall
        bytes memory raw = _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account);
        (uint256 deadline, bytes[] memory calls) = abi.decode(_body(raw), (uint256, bytes[]));
        bytes[] memory tampered = new bytes[](calls.length + 1);
        for (uint256 i; i < calls.length; ++i) {
            tampered[i] = calls[i];
        }
        tampered[calls.length] = tampered[calls.length - 1];
        tampered[calls.length - 1] = abi.encodeWithSelector(bytes4(0x09b81346), hex"", account, uint256(1), uint256(1));
        bytes memory injected = abi.encodeWithSelector(ISwapRouter02.multicall.selector, deadline, tampered);
        vm.expectRevert(
            abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bytes4(0x09b81346))
        );
        swapHook.build(
            address(0),
            account,
            _hookData(VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, HEADER_MIN_USDC_KAT, false, injected)
        );
    }

    /// @notice The API fixes the deadline at quote + 600 s: past it the router reverts 'Transaction too old' and the
    ///         UserOp fails atomically. This is what makes destination-chain use latency-sensitive.
    function test_Characterize_DeadlineExpired() public {
        _requireFork();
        vm.warp(DEADLINE_USDC_KAT + 1);
        // the exact reason, step by step from the hook's build() output (the UserOp wrapper only exposes 4 bytes)
        address me = address(this);
        deal(VB_USDC, me, QUOTE_USDC_KAT_IN);
        bytes memory data = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            false,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, me)
        );
        (uint256 failedAt, bytes memory ret) = _executeBatch(approveHook.build(address(0), me, data));
        assertEq(failedAt, 3, "the router call is the failing step");
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Transaction too old"));
        // and through the executor the op is atomic
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        instance.expect4337Revert(abi.encodeWithSignature("Error(string)", "Transaction too old"));
        executeOp(_op1(address(approveHook), _usdcKatData(false)));
        assertEq(IERC20(VB_USDC).balanceOf(account), usdcBefore);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    struct Snap {
        uint256 inBefore;
        uint256 outBefore;
        uint256 feeBefore;
        uint256 routerIn;
        uint256 routerOut;
        uint256 routerWeth;
    }

    function _bal(address token, address who) internal view returns (uint256) {
        return token == NATIVE ? who.balance : IERC20(token).balanceOf(who);
    }

    function _snap(address outToken) internal view returns (Snap memory s) {
        s.inBefore = IERC20(VB_USDC).balanceOf(account);
        s.outBefore = _bal(outToken, account);
        s.feeBefore = _bal(outToken, FEE_RECIPIENT);
        s.routerIn = IERC20(VB_USDC).balanceOf(EVERLONG_ROUTER);
        s.routerOut = _bal(outToken == NATIVE ? WETH9 : outToken, EVERLONG_ROUTER);
        s.routerWeth = IERC20(WETH9).balanceOf(EVERLONG_ROUTER);
    }

    /// @dev out = account delta (post-fee); fee = FEE_RECIPIENT delta; identity fee == (out + fee) x 4 / 10_000, the
    ///      pre-fee router balance cleared the scaled tail min, and the post-fee out cleared the scaled header min.
    function _assertFeeIdentityAndFloor(
        Snap memory s,
        address outToken,
        uint256 actual,
        uint256 quotedIn,
        uint256 headerMin,
        uint256 tailMin
    )
        internal
        view
        returns (uint256 out)
    {
        out = _bal(outToken, account) - s.outBefore;
        uint256 fee = _bal(outToken, FEE_RECIPIENT) - s.feeBefore;
        uint256 gross = out + fee;
        assertEq(fee, gross * FEE_BIPS / 10_000, "4 bps fee identity");
        assertGe(gross, Math.mulDiv(tailMin, actual, quotedIn, Math.Rounding.Ceil), "scaled tail floor (pre-fee)");
        assertGe(out, Math.mulDiv(headerMin, actual, quotedIn, Math.Rounding.Ceil), "scaled header floor (post-fee)");
    }

    function _assertNoDust(Snap memory s, address outToken) internal view {
        assertEq(IERC20(VB_USDC).balanceOf(address(swapHook)), 0);
        assertEq(_bal(outToken, address(swapHook)), 0);
        assertEq(IERC20(VB_USDC).balanceOf(address(approveHook)), 0);
        assertEq(_bal(outToken, address(approveHook)), 0);
        assertEq(address(swapHook).balance, 0);
        assertEq(address(approveHook).balance, 0);
        assertEq(IERC20(VB_USDC).balanceOf(EVERLONG_ROUTER), s.routerIn, "router input unchanged");
        assertEq(_bal(outToken == NATIVE ? WETH9 : outToken, EVERLONG_ROUTER), s.routerOut, "router output unchanged");
        assertEq(IERC20(WETH9).balanceOf(EVERLONG_ROUTER), s.routerWeth, "router WETH9 unchanged");
        assertEq(EVERLONG_ROUTER.balance, 0, "router holds no ETH");
    }

    function _f(bytes memory txData) internal pure returns (EverlongAmountUpdater.Fields memory) {
        return EverlongAmountUpdater.readFields(txData, WETH9);
    }

    function _body(bytes memory d) internal pure returns (bytes memory out) {
        out = new bytes(d.length - 4);
        for (uint256 i; i < out.length; ++i) {
            out[i] = d[i + 4];
        }
    }

    function _usdcKatData(bool flag) internal view returns (bytes memory) {
        return _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            flag,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
    }

    function _nativeInData(bool flag) internal view returns (bytes memory) {
        return _hookData(
            NATIVE,
            VB_USDC,
            QUOTE_NATIVE_USDC_IN,
            QUOTE_NATIVE_USDC_OUT,
            HEADER_MIN_NATIVE_USDC,
            flag,
            _withRecipient(TX_NATIVE_IN_USDC, TAIL_RECIPIENT_OFFSET_NATIVE_USDC, account)
        );
    }

    function _nativeOutData(bool flag) internal view returns (bytes memory) {
        return _hookData(
            VB_USDC,
            NATIVE,
            QUOTE_USDC_NATIVE_IN,
            QUOTE_USDC_NATIVE_OUT,
            HEADER_MIN_USDC_NATIVE,
            flag,
            _withRecipient(TX_USDC_NATIVE_OUT, TAIL_RECIPIENT_OFFSET_USDC_NATIVE, account)
        );
    }

    function _op1(address hook, bytes memory data) internal returns (UserOpData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas }))
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
