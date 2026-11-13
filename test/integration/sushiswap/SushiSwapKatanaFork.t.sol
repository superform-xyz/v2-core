// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import { ApproveAndSwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { SushiSwapAmountUpdater } from "../../../src/libraries/SushiSwapAmountUpdater.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { SushiKatanaFixtures } from "./SushiKatanaFixtures.sol";

/// @title SushiSwapKatanaFork
/// @author Superform Labs
/// @notice Same-chain end-to-end proof on REAL Katana (747474) at a pinned block: the live RedSnwapper, the live
///         RouteProcessor executor, live vbUSDC / KAT / WETH liquidity, and the UNMODIFIED Sushi v7 API calldata
///         captured in `SushiKatanaFixtures` (only the quoting account is rewritten to the test account). Happy
///         paths run as real UserOps through `SuperExecutor` on a Nexus account; revert paths run the hook's
///         `build()` output step by step so the failing step and reason can be pinned.
/// @dev Runs against KATANA_RPC_URL, defaulting to the public https://rpc.katana.network. Skips cleanly without
///      connectivity. Excluded from `ftest-ci` via FLARE_FORK_TESTS (public RPC).
contract SushiSwapKatanaFork is Helpers, RhinestoneModuleKit, InternalHelpers, SushiKatanaFixtures {
    using ModuleKitHelpers for *;

    /// @dev Production SuperExecutor on Katana (script/output/prod/747474/Katana-latest.json)
    address internal constant PROD_SUPER_EXECUTOR = 0x9cC8EDCC41154aaFC74D261aD3D87140D21F6281;

    SwapSushiSwapHook internal swapHook;
    ApproveAndSwapSushiSwapHook internal approveHook;
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

        swapHook = new SwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        approveHook = new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        approveErc20Hook = new ApproveERC20Hook();
        nativePrev = new MockHook(ISuperHook.HookType.NONACCOUNTING, NATIVE);

        instance = makeAccountInstance(keccak256("sushi-katana"));
        account = instance.account;
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        deal(VB_USDC, account, 1_000_000e6);
        vm.deal(account, 100 ether);
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /*//////////////////////////////////////////////////////////////
                               LIVE CHAIN
    //////////////////////////////////////////////////////////////*/

    function test_Fork_IsKatana_AndContractsAreLive() public {
        _requireFork();
        assertEq(block.chainid, KATANA_CHAIN_ID, "forked the wrong chain");
        assertGt(RED_SNWAPPER.code.length, 0, "RedSnwapper live");
        assertGt(ROUTE_PROCESSOR.code.length, 0, "executor live");
        assertEq(IERC20(VB_USDC).balanceOf(account), 1_000_000e6, "fixture funded");
    }

    /*//////////////////////////////////////////////////////////////
                      SAME CHAIN, usePrevHookAmount = false
    //////////////////////////////////////////////////////////////*/

    function test_SameChain_ApproveAndSwap_Equal_FlagOff() public {
        _requireFork();
        Snapshot memory s = _snap(KAT);

        uint256 gasBefore = gasleft();
        executeOp(_op1(address(approveHook), _usdcKatData(QUOTE_USDC_KAT_IN, false)));
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_KAT_IN, "vbUSDC spent exactly");
        uint256 out = IERC20(KAT).balanceOf(account) - s.outBefore;
        assertGe(out, OUTER_MIN_USDC_KAT, "RedSnwapper floor");
        assertEq(out, QUOTE_USDC_KAT_OUT, "cap binds at the quote (probe)");
        assertEq(IERC20(VB_USDC).allowance(account, RED_SNWAPPER), 0, "allowance reset");
        assertLt(gasUsed, KATANA_PER_TX_GAS_CAP, "fits under Katana's per-tx gas cap");
        _assertNoDust(s, KAT);
    }

    function test_SameChain_PlainSwap_Equal_FlagOff_WithApproveHook() public {
        _requireFork();
        Snapshot memory s = _snap(KAT);

        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, RED_SNWAPPER, QUOTE_USDC_KAT_IN, false),
                address(swapHook),
                _usdcKatData(QUOTE_USDC_KAT_IN, false)
            )
        );

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_KAT_IN);
        assertEq(IERC20(KAT).balanceOf(account) - s.outBefore, QUOTE_USDC_KAT_OUT);
        _assertNoDust(s, KAT);
    }

    /// @notice The same swap through the SuperExecutor that is actually DEPLOYED on Katana (production bytecode),
    ///         installed as the executor module of a fresh Nexus account: proves the new hooks interoperate with the
    ///         live executor's hook-lifecycle and transient-storage protocol, not only with a locally built one.
    function test_SameChain_ThroughDeployedProdSuperExecutor() public {
        _requireFork();
        assertGt(PROD_SUPER_EXECUTOR.code.length, 0, "production SuperExecutor live on Katana");
        AccountInstance memory prodInstance = makeAccountInstance(keccak256("sushi-katana-prod-executor"));
        prodInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: PROD_SUPER_EXECUTOR, data: "" });
        address prodAccount = prodInstance.account;
        deal(VB_USDC, prodAccount, 10 * QUOTE_USDC_KAT_IN);

        uint256 actual = QUOTE_USDC_KAT_IN * 95 / 100;
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(approveHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _createApproveHookData(VB_USDC, RED_SNWAPPER, actual, false);
        datas[1] = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            OUTER_MIN_USDC_KAT,
            true,
            _withRecipient(TX_USDC_KAT, prodAccount)
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
        assertEq(
            IERC20(KAT).balanceOf(prodAccount),
            Math.mulDiv(QUOTE_USDC_KAT_OUT, actual, QUOTE_USDC_KAT_IN, Math.Rounding.Ceil),
            "scaled cap binds through the production executor"
        );
        assertEq(IERC20(VB_USDC).allowance(prodAccount, RED_SNWAPPER), 0, "allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                  CHAINED, usePrevHookAmount = true (95 / 100 / 105)
    //////////////////////////////////////////////////////////////*/

    function test_Chained_Below95_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 95 / 100, true);
    }

    function test_Chained_Equal100_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN, true);
    }

    function test_Chained_Above105_PlainSwap() public {
        _requireFork();
        _chainedUsdcKat(address(swapHook), QUOTE_USDC_KAT_IN * 105 / 100, false);
    }

    function test_Chained_Below95_ApproveAndSwap() public {
        _requireFork();
        _chainedUsdcKat(address(approveHook), QUOTE_USDC_KAT_IN * 95 / 100, true);
    }

    function test_Chained_Above105_ApproveAndSwap() public {
        _requireFork();
        _chainedUsdcKat(address(approveHook), QUOTE_USDC_KAT_IN * 105 / 100, false);
    }

    /// @dev `[ApproveERC20Hook(actual, flag=false), <sushi hook>(flag=true)]`: the approve hook publishes
    ///      outAmount = actual / outToken = vbUSDC, exactly what the bundler does on a destination when it trims the
    ///      approval for fees and leaves the swap header + payload at the original quote.
    function _chainedUsdcKat(address hook, uint256 actual, bool capBinds) internal {
        Snapshot memory s = _snap(KAT);

        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, RED_SNWAPPER, actual, false),
                hook,
                _usdcKatData(QUOTE_USDC_KAT_IN, true)
            )
        );

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), actual, "spent exactly the actual amount");
        uint256 out = IERC20(KAT).balanceOf(account) - s.outBefore;
        uint256 scaledOuterMin = Math.mulDiv(OUTER_MIN_USDC_KAT, actual, QUOTE_USDC_KAT_IN, Math.Rounding.Ceil);
        assertGe(out, scaledOuterMin, "scaled RedSnwapper floor == scaled header floor");
        if (capBinds) {
            assertEq(
                out,
                Math.mulDiv(QUOTE_USDC_KAT_OUT, actual, QUOTE_USDC_KAT_IN, Math.Rounding.Ceil),
                "scaled nested cap binds (probe)"
            );
        } else {
            assertGt(out, QUOTE_USDC_KAT_OUT, "more input, more output");
            assertLe(out, Math.mulDiv(QUOTE_USDC_KAT_OUT, actual, QUOTE_USDC_KAT_IN, Math.Rounding.Ceil), "scaled cap");
        }
        assertEq(IERC20(VB_USDC).allowance(account, RED_SNWAPPER), 0, "allowance reset");
        _assertNoDust(s, KAT);
    }

    /*//////////////////////////////////////////////////////////////
                               NATIVE IN / OUT
    //////////////////////////////////////////////////////////////*/

    function test_NativeIn_Equal_FlagOff_ApproveVariant() public {
        _requireFork();
        Snapshot memory s = _snap(VB_USDC);
        uint256 ethBefore = account.balance;

        executeOp(
            _op1(
                address(approveHook),
                _hookData(
                    NATIVE,
                    VB_USDC,
                    QUOTE_NATIVE_USDC_IN,
                    QUOTE_NATIVE_USDC_OUT,
                    OUTER_MIN_NATIVE_USDC,
                    false,
                    _withRecipient(TX_NATIVE_IN_USDC, account)
                )
            )
        );

        uint256 ethSpent = ethBefore - account.balance;
        assertGe(ethSpent, QUOTE_NATIVE_USDC_IN, "at least the swap value left the account");
        assertLe(ethSpent, QUOTE_NATIVE_USDC_IN + 0.05 ether, "nothing beyond value (+ any prefund top-up)");
        uint256 out = IERC20(VB_USDC).balanceOf(account) - s.outBefore;
        assertGe(out, OUTER_MIN_NATIVE_USDC);
        _assertNoDust(s, VB_USDC);
    }

    function test_NativeIn_Chained90_PlainVariant() public {
        _requireFork();
        uint256 actual = QUOTE_NATIVE_USDC_IN * 90 / 100;
        nativePrev.setOutAmount(actual, account);
        nativePrev.setOutToken(NATIVE);
        Snapshot memory s = _snap(VB_USDC);
        uint256 ethBefore = account.balance;

        executeOp(
            _op2(
                address(nativePrev),
                hex"",
                address(swapHook),
                _hookData(
                    NATIVE,
                    VB_USDC,
                    QUOTE_NATIVE_USDC_IN,
                    QUOTE_NATIVE_USDC_OUT,
                    OUTER_MIN_NATIVE_USDC,
                    true,
                    _withRecipient(TX_NATIVE_IN_USDC, account)
                )
            )
        );

        uint256 ethSpent = ethBefore - account.balance;
        assertGe(ethSpent, actual, "scaled value forwarded");
        assertLe(ethSpent, actual + 0.05 ether, "not the unscaled value");
        uint256 out = IERC20(VB_USDC).balanceOf(account) - s.outBefore;
        assertGe(out, Math.mulDiv(OUTER_MIN_NATIVE_USDC, 90, 100, Math.Rounding.Ceil), "scaled floor");
        assertLe(out, Math.mulDiv(QUOTE_NATIVE_USDC_OUT, 90, 100, Math.Rounding.Ceil), "scaled nested cap");
        _assertNoDust(s, VB_USDC);
    }

    function test_NativeOut_Equal_FlagOff() public {
        _requireFork();
        Snapshot memory s = _snap(NATIVE);
        uint256 ethBefore = account.balance;

        executeOp(
            _op1(
                address(approveHook),
                _hookData(
                    VB_USDC,
                    NATIVE,
                    QUOTE_USDC_NATIVE_IN,
                    QUOTE_USDC_NATIVE_OUT,
                    OUTER_MIN_USDC_NATIVE,
                    false,
                    _withRecipient(TX_USDC_NATIVE_OUT, account)
                )
            )
        );

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_NATIVE_IN);
        assertGe(account.balance - ethBefore, OUTER_MIN_USDC_NATIVE, "native output reached the account");
        _assertNoDust(s, NATIVE);
    }

    function test_NativeOut_Chained110() public {
        _requireFork();
        uint256 actual = QUOTE_USDC_NATIVE_IN * 110 / 100;
        Snapshot memory s = _snap(NATIVE);
        uint256 ethBefore = account.balance;

        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, RED_SNWAPPER, actual, false),
                address(swapHook),
                _hookData(
                    VB_USDC,
                    NATIVE,
                    QUOTE_USDC_NATIVE_IN,
                    QUOTE_USDC_NATIVE_OUT,
                    OUTER_MIN_USDC_NATIVE,
                    true,
                    _withRecipient(TX_USDC_NATIVE_OUT, account)
                )
            )
        );

        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), actual);
        uint256 nativeOut = account.balance - ethBefore;
        assertGe(nativeOut, Math.mulDiv(OUTER_MIN_USDC_NATIVE, 110, 100, Math.Rounding.Ceil), "scaled native floor");
        assertLe(nativeOut, Math.mulDiv(QUOTE_USDC_NATIVE_OUT, 110, 100, Math.Rounding.Ceil), "scaled nested cap");
        _assertNoDust(s, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                    SUSHI FEEDS SUSHI ON REAL LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice vbUSDC -> ETH (native out) then ETH -> vbUSDC (native in) in ONE UserOp, the second swap sized from
    ///         the first swap's real native output via `usePrevHookAmount`. The second header is the 1 ETH quote, the
    ///         actual input is ~0.049 ETH, so both heads of the second payload are rescaled to ~4.9% on live
    ///         liquidity and the hook floor scales with it. Proves outToken (native) + outAmount propagation
    ///         between two Sushi hooks through the executor's transient storage.
    function test_RoundTrip_UsdcToNativeToUsdc_SecondSwapSizedFromFirst() public {
        _requireFork();
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        uint256 ethBefore = account.balance;

        bytes memory first = _hookData(
            VB_USDC,
            NATIVE,
            QUOTE_USDC_NATIVE_IN,
            QUOTE_USDC_NATIVE_OUT,
            OUTER_MIN_USDC_NATIVE,
            false,
            _withRecipient(TX_USDC_NATIVE_OUT, account)
        );
        bytes memory second = _hookData(
            NATIVE,
            VB_USDC,
            QUOTE_NATIVE_USDC_IN,
            QUOTE_NATIVE_USDC_OUT,
            OUTER_MIN_NATIVE_USDC,
            true,
            _withRecipient(TX_NATIVE_IN_USDC, account)
        );
        executeOp(_op2(address(approveHook), first, address(swapHook), second));

        // The native leg: the second swap consumed everything the first produced (the account only pays its UserOp
        // prefund on top), so no native is left over and at most ~prefund is missing.
        assertLe(account.balance, ethBefore, "no native left over from the first leg");
        assertGe(account.balance, ethBefore - 0.01 ether, "only the prefund left the account besides the swap");
        uint256 usdcAfter = IERC20(VB_USDC).balanceOf(account);
        // Round-trip cost bounded by the two slippage floors (0.5% each) plus the venue spreads: never more than 3%.
        assertLe(usdcBefore - usdcAfter, QUOTE_USDC_NATIVE_IN * 3 / 100, "round-trip cost within two floors + spreads");
        // Lower bound from the two scaled floors: minOut2 = ceil(minNative * ethOut / 1e18) with ethOut >= minEth.
        uint256 minBack =
            Math.mulDiv(OUTER_MIN_NATIVE_USDC, OUTER_MIN_USDC_NATIVE, QUOTE_NATIVE_USDC_IN, Math.Rounding.Ceil);
        assertGe(usdcAfter + QUOTE_USDC_NATIVE_IN - usdcBefore, minBack, "both scaled floors held");
    }

    /*//////////////////////////////////////////////////////////////
                           MULTI-SPLIT ROUTE
    //////////////////////////////////////////////////////////////*/

    /// @dev One leg per test: the 5e10 vbUSDC fixture is large enough that a second leg in the same fork state
    ///      pays the first leg's price impact and (correctly) trips RedSnwapper's floor.
    function test_MultiSplit_Chained80() public {
        _requireFork();
        _multi(QUOTE_USDC_WETH_IN * 80 / 100);
    }

    function test_MultiSplit_Chained120() public {
        _requireFork();
        _multi(QUOTE_USDC_WETH_IN * 120 / 100);
    }

    /// @dev The 358-byte multi-split route executes at a different size WITHOUT re-encoding: route bytes are
    ///      amount-agnostic (shares), the executor swaps what it was pre-funded with.
    function _multi(uint256 actual) internal {
        Snapshot memory s = _snap(WETH);
        executeOp(
            _op2(
                address(approveErc20Hook),
                _createApproveHookData(VB_USDC, RED_SNWAPPER, actual, false),
                address(swapHook),
                _hookData(
                    VB_USDC,
                    WETH,
                    QUOTE_USDC_WETH_IN,
                    QUOTE_USDC_WETH_OUT,
                    OUTER_MIN_USDC_WETH,
                    true,
                    _withRecipient(TX_USDC_WETH_MULTI, account)
                )
            )
        );
        assertEq(s.inBefore - IERC20(VB_USDC).balanceOf(account), actual);
        uint256 wethOut = IERC20(WETH).balanceOf(account) - s.outBefore;
        assertGe(wethOut, Math.mulDiv(OUTER_MIN_USDC_WETH, actual, QUOTE_USDC_WETH_IN, Math.Rounding.Ceil), "floor");
        assertLe(
            wethOut,
            Math.mulDiv(QUOTE_USDC_WETH_OUT, actual, QUOTE_USDC_WETH_IN, Math.Rounding.Ceil),
            "scaled nested cap"
        );
        _assertNoDust(s, WETH);
    }

    /*//////////////////////////////////////////////////////////////
                         REVERT PATHS (direct batch)
    //////////////////////////////////////////////////////////////*/

    /// @dev The in-hook floor is independent of Sushi: a header min 1% above the quote passes RedSnwapper's own
    ///      floor (0.5% below the quote) but fails the hook's `_postExecute` check, reverting the batch.
    function test_Revert_HookFloor_TightHeaderMin() public {
        _requireFork();
        address me = address(this);
        deal(VB_USDC, me, QUOTE_USDC_KAT_IN);
        bytes memory data = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            QUOTE_USDC_KAT_OUT * 101 / 100,
            false,
            _withRecipient(TX_USDC_KAT, me)
        );
        Execution[] memory ex = approveHook.build(address(0), me, data);
        (uint256 failedAt, bytes memory ret) = _executeBatch(ex);
        assertEq(failedAt, ex.length - 1, "postExecute is the failing step");
        assertEq(bytes4(ret), ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
    }

    function test_Revert_WrongExecutor() public {
        _requireFork();
        bytes memory raw = _withRecipient(TX_USDC_KAT, account);
        _write(raw, 164, uint256(uint160(address(0xBAD))));
        bytes memory data =
            _hookData(VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, OUTER_MIN_USDC_KAT, false, raw);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INVALID_EXECUTOR.selector);
        approveHook.build(address(0), account, data);
    }

    function test_Revert_RecipientNotAccount() public {
        _requireFork();
        // untouched fixture: recipient is still the API sender, not the account
        bytes memory data = _hookData(
            VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, OUTER_MIN_USDC_KAT, false, bytes.concat(TX_USDC_KAT)
        );
        vm.expectRevert(SwapSushiSwapHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(0), account, data);
    }

    function test_Revert_InnerTransferValueSelector() public {
        _requireFork();
        bytes memory raw = _withRecipient(TX_USDC_KAT, account);
        // overwrite the nested selector (bytes 260..263) with processRouteWithTransferValueInput
        raw[260] = 0x9c;
        raw[261] = 0xbd;
        raw[262] = 0x7f;
        raw[263] = 0x62;
        bytes memory data =
            _hookData(VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, OUTER_MIN_USDC_KAT, false, raw);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_INNER_SELECTOR.selector);
        swapHook.build(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    struct Snapshot {
        uint256 inBefore;
        uint256 outBefore;
        uint256 rsIn;
        uint256 rsOut;
        uint256 rpIn;
        uint256 rpOut;
    }

    function _bal(address token, address who) internal view returns (uint256) {
        return token == NATIVE ? who.balance : IERC20(token).balanceOf(who);
    }

    function _snap(address outToken) internal view returns (Snapshot memory s) {
        s.inBefore = IERC20(VB_USDC).balanceOf(account);
        s.outBefore = _bal(outToken, account);
        s.rsIn = IERC20(VB_USDC).balanceOf(RED_SNWAPPER);
        s.rsOut = _bal(outToken, RED_SNWAPPER);
        s.rpIn = IERC20(VB_USDC).balanceOf(ROUTE_PROCESSOR);
        s.rpOut = _bal(outToken, ROUTE_PROCESSOR);
    }

    /// @dev Hooks never hold funds; the venue's steady 1-wei undrain dust predates and survives the swap (assert
    ///      equality, not zero).
    function _assertNoDust(Snapshot memory s, address outToken) internal view {
        assertEq(IERC20(VB_USDC).balanceOf(address(swapHook)), 0, "swap hook vbUSDC");
        assertEq(_bal(outToken, address(swapHook)), 0, "swap hook out");
        assertEq(address(swapHook).balance, 0, "swap hook native");
        assertEq(IERC20(VB_USDC).balanceOf(address(approveHook)), 0, "approve hook vbUSDC");
        assertEq(_bal(outToken, address(approveHook)), 0, "approve hook out");
        assertEq(address(approveHook).balance, 0, "approve hook native");
        assertEq(IERC20(VB_USDC).balanceOf(RED_SNWAPPER), s.rsIn, "RedSnwapper input unchanged");
        assertEq(_bal(outToken, RED_SNWAPPER), s.rsOut, "RedSnwapper output unchanged");
        assertEq(IERC20(VB_USDC).balanceOf(ROUTE_PROCESSOR), s.rpIn, "executor input unchanged");
        assertEq(_bal(outToken, ROUTE_PROCESSOR), s.rpOut, "executor output unchanged");
    }

    function _usdcKatData(uint256 headerAmount, bool flag) internal view returns (bytes memory) {
        return _hookData(
            VB_USDC,
            KAT,
            headerAmount,
            QUOTE_USDC_KAT_OUT,
            OUTER_MIN_USDC_KAT,
            flag,
            _withRecipient(TX_USDC_KAT, account)
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
