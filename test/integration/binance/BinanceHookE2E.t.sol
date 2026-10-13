// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { console2 } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

import { ApproveAndSwapBinanceHook } from "../../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { BinanceAPIParser } from "../../utils/parsers/BinanceAPIParser.sol";
import { MockBinanceRouter } from "../../mocks/MockBinanceRouter.sol";
import { ProdBinanceConstants } from "../../unit/hooks/swappers/binance/BinanceDeployConfig.t.sol";

/// @title BinanceHookE2EBase
/// @notice Shared BSC fork setup for the ApproveAndSwapBinanceHook suites (SUP-21203).
/// @dev `MockBinanceRouter` is `vm.etch`ed at the pinned router so the adversary is scriptable while the
///      tokens (USDT, bStocks) are the REAL bytecode. The hook is deployed with the PRODUCTION cap read from
///      `ProdBinanceConstants`, so a cap change in `ConstantsOtherHooks` is exercised here, not pinned.
///      Needs `BSC_RPC_URL`; everything skips cleanly without it. Excluded from `ftest-ci` via FLARE_FORK_TESTS.
abstract contract BinanceHookE2EBase is Helpers, RhinestoneModuleKit, InternalHelpers, BinanceAPIParser {
    using ModuleKitHelpers for *;

    ApproveAndSwapBinanceHook public hook;

    AccountInstance public instance;
    address public smartAccount;
    ISuperExecutor public superExecutor;

    address public constant ROUTER = CHAIN_56_BINANCE_LIQUIDMESH_ROUTER;
    address public constant USDT = CHAIN_56_USDT;
    address public constant AAPLB = CHAIN_56_AAPLB;
    address public constant NVDAB = CHAIN_56_NVDAB;

    /// @dev `BINANCE_MAX_INPUT_AMOUNT_BNB`, the deploy-time cap. Read, not re-declared.
    uint256 public cap;

    address public account;
    bool internal forked;

    receive() external payable { }

    function setUp() public virtual {
        string memory rpc = vm.envOr(BSC_RPC_URL_KEY, string(""));
        if (bytes(rpc).length == 0) return;

        vm.createSelectFork(rpc);
        forked = true;
        account = address(this);
        cap = new ProdBinanceConstants().cap();
        hook = new ApproveAndSwapBinanceHook(ROUTER, cap);

        // ERC-7579 smart account + SuperExecutor for the UserOp path
        instance = makeAccountInstance(keccak256(abi.encode("binance-acc")));
        smartAccount = instance.account;
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /// @dev USDT -> AAPLB hook data; outputQuote is informational and left at zero.
    function _hookData(
        uint256 amountIn,
        uint256 minOut,
        address to,
        bytes memory txData
    )
        internal
        pure
        returns (bytes memory)
    {
        return _createBinanceSwapHookData(USDT, AAPLB, amountIn, 0, minOut, false, to, txData);
    }

    /// @dev Replaces the pinned router's code with the scriptable mock and returns a typed handle.
    function _etchHarness(uint256 amountIn, uint256 amountOut) internal returns (MockBinanceRouter harness) {
        vm.etch(ROUTER, address(new MockBinanceRouter()).code);
        harness = MockBinanceRouter(payable(ROUTER));
        // Etch copies code only: the diamond's real storage stays. Pin that it does not pre-configure the
        // mock (slots 0..13 are zero on BSC today) so a future diamond storage change cannot silently
        // flip the harness into another mode.
        assertEq(uint256(harness.mode()), uint256(MockBinanceRouter.Mode.HONEST), "etched storage not clean");
        assertEq(harness.calls(), 0, "etched storage not clean");
        assertEq(harness.lastSelector(), bytes4(0), "etched storage not clean");
        harness.setHook(address(hook));
        harness.configure(USDT, amountIn, AAPLB, amountOut);
        deal(AAPLB, ROUTER, amountOut);
    }

    /// @dev Any >= 4-byte blob; the harness runs from `fallback()`. Selector is the LiquidMesh swap facet's.
    function _harnessTxData() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(0xad43f73d, bytes("harness"));
    }

    function _userOp(bytes memory hookData) internal returns (UserOpData memory) {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        return _getExecOps(instance, superExecutor, abi.encode(entry));
    }

    function _userOpTwoEntries(bytes memory a, bytes memory b) internal returns (UserOpData memory) {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(hook);
        hooksAddresses[1] = address(hook);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = a;
        hooksData[1] = b;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        return _getExecOps(instance, superExecutor, abi.encode(entry));
    }
}

/// @title BinanceHookE2E
/// @notice BSC fork tests for ApproveAndSwapBinanceHook (SUP-21203).
/// @dev Three layers:
///      1. Harness — real-token baseline for the paths the unit suite only sees against `MockERC20`. The
///         scripted-router failure modes are NOT repeated here: they are unit `test_Sequence_*` and the
///         Executor layer below already runs them against the real bytecode.
///      2. Executor — the harness driven through a real ERC-7579 smart account + `SuperExecutor` via an
///         ERC-4337 UserOp, so the whole batch (validateHookCompliance, pre/post gating, atomicity on
///         failure, the per-transaction cap) is exercised, not just the hook in isolation.
///      3. Live — a real LiquidMesh quote via the Binance Web3 Trading API. Needs `BSC_RPC_URL`,
///         `BINANCE_WEB3_API_KEY` and `BINANCE_WEB3_SECRET_KEY` (HMAC-signed GET through `vm.ffi`).
///      The cross-transaction reset of the cap accumulator lives in `BinanceHookTxCapResetE2E` below.
contract BinanceHookE2E is BinanceHookE2EBase {
    using ModuleKitHelpers for *;

    uint256 public constant MAX_RETRIES = 3;

    /*//////////////////////////////////////////////////////////////
                    HARNESS: real tokens, scripted router
    //////////////////////////////////////////////////////////////*/

    function test_Harness_HonestSwap_RealUSDT_RealBStock() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        uint256 amountOut = 4e18;
        MockBinanceRouter harness = _etchHarness(amountIn, amountOut);
        deal(USDT, account, amountIn);

        Execution[] memory executions =
            hook.build(address(0), account, _hookData(amountIn, amountOut, ROUTER, _harnessTxData()));
        assertEq(executions.length, 6);

        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, type(uint256).max, "all six steps succeed against real token bytecode");

        assertEq(IERC20(USDT).balanceOf(account), 0, "USDT spent");
        assertEq(IERC20(AAPLB).balanceOf(account), amountOut, "AAPLB received");
        assertEq(IERC20(USDT).allowance(account, ROUTER), 0, "allowance cleared on real USDT");
        assertEq(hook.getOutAmount(account), amountOut);
        assertEq(hook.getOutToken(account), AAPLB);
        assertEq(harness.lastSelector(), bytes4(_harnessTxData()));
    }

    function test_Harness_PullsSecondBStock_NoAllowance_Fails() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 4e18);
        harness.setMode(MockBinanceRouter.Mode.PULL_SECOND_TOKEN);
        harness.setSecondToken(NVDAB, 1e18);
        deal(USDT, account, amountIn);
        deal(NVDAB, account, 1e18);

        Execution[] memory executions =
            hook.build(address(0), account, _hookData(amountIn, 4e18, ROUTER, _harnessTxData()));
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, 3, "router cannot pull a bStock it was never approved for");
        assertEq(IERC20(NVDAB).balanceOf(account), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
            EXECUTOR: smart account + SuperExecutor via UserOp
    //////////////////////////////////////////////////////////////*/

    function test_Executor_HonestSwap_UserOp() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        uint256 amountOut = 4e18;
        MockBinanceRouter harness = _etchHarness(amountIn, amountOut);
        deal(USDT, smartAccount, amountIn);

        executeOp(_userOp(_hookData(amountIn, amountOut, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), 0, "USDT spent by the account");
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), amountOut, "AAPLB received by the account");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0, "allowance cleared");
        assertEq(harness.calls(), 1);
    }

    /// @dev A failing post-condition reverts the WHOLE UserOp: no approval, no transfer survives.
    function test_Executor_NoOutput_UserOpReverts_Atomically() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 4e18);
        harness.setMode(MockBinanceRouter.Mode.NO_OUTPUT);
        deal(USDT, smartAccount, amountIn);

        instance.expect4337Revert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), amountIn, "nothing spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0, "no allowance survives a reverted op");
    }

    function test_Executor_OverPull_UserOpReverts_Atomically() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 4e18);
        harness.setMode(MockBinanceRouter.Mode.PULL_MORE_THAN_APPROVED);
        harness.setOverPull(amountIn + 1);
        deal(USDT, smartAccount, 2 * amountIn);

        instance.expect4337Revert();
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), 2 * amountIn, "nothing spent");
    }

    function test_Executor_RouterMismatch_UserOpReverts() public {
        _requireFork();
        // Etch the harness so a swap WOULD succeed if the mismatch check were missing.
        MockBinanceRouter harness = _etchHarness(1000e18, 4e18);
        deal(USDT, smartAccount, 1000e18);

        instance.expect4337Revert(ApproveAndSwapBinanceHook.ROUTER_MISMATCH.selector);
        executeOp(_userOp(_hookData(1000e18, 4e18, makeAddr("otherRouter"), _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), 1000e18);
        assertEq(harness.calls(), 0, "router never reached");
    }

    /// @dev The repeated-leaf attack: two entries of 6M each against a 10M cap in ONE UserOp. The second
    ///      entry's preExecute trips the per-tx cap and the whole op reverts — nothing is spent.
    function test_Executor_RepeatedLeafAboveTxCap_UserOpReverts() public {
        _requireFork();
        uint256 each = 6_000_000e18;
        MockBinanceRouter harness = _etchHarness(each, 4e18);
        deal(USDT, smartAccount, 2 * each);
        deal(AAPLB, ROUTER, 8e18);

        bytes memory data = _hookData(each, 4e18, ROUTER, _harnessTxData());
        instance.expect4337Revert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        executeOp(_userOpTwoEntries(data, data));

        assertEq(IERC20(USDT).balanceOf(smartAccount), 2 * each, "nothing spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
        assertEq(harness.calls(), 0, "router never reached");
    }

    /// @dev Two entries whose sum is exactly the cap succeed.
    function test_Executor_RepeatedLeafAtTxCap_UserOpSucceeds() public {
        _requireFork();
        uint256 each = cap / 2;
        MockBinanceRouter harness = _etchHarness(each, 4e18);
        deal(USDT, smartAccount, 2 * each);
        deal(AAPLB, ROUTER, 8e18);

        bytes memory data = _hookData(each, 4e18, ROUTER, _harnessTxData());
        executeOp(_userOpTwoEntries(data, data));

        assertEq(IERC20(USDT).balanceOf(smartAccount), 0, "both entries spent");
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), 8e18);
        assertEq(harness.calls(), 2);
    }

    function test_Executor_AboveCap_UserOpReverts() public {
        _requireFork();
        MockBinanceRouter harness = _etchHarness(cap + 1, 4e18);
        deal(USDT, smartAccount, cap + 1);

        instance.expect4337Revert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        executeOp(_userOp(_hookData(cap + 1, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), cap + 1);
        assertEq(harness.calls(), 0, "router never reached");
    }

    /*//////////////////////////////////////////////////////////////
                    MALICIOUS FACET RE-ENTERING THE HOOK
    //////////////////////////////////////////////////////////////*/

    /// @dev A facet that calls `hook.setExecutionContext(account)` mid-swap rotates the hook's context so
    ///      the pre-snapshot is unreachable. postExecute refuses (SNAPSHOT_NOT_TAKEN) and the op reverts; the
    ///      account's pre-existing bStock position is never "credited" as swap output.
    function test_Executor_FacetReentersSetExecutionContext_UserOpReverts() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 0);
        harness.setMode(MockBinanceRouter.Mode.REENTER_SET_CONTEXT);
        deal(USDT, smartAccount, amountIn);
        deal(AAPLB, smartAccount, 5e18); // existing position

        instance.expect4337Revert(ApproveAndSwapBinanceHook.SNAPSHOT_NOT_TAKEN.selector);
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), amountIn, "nothing spent");
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), 5e18);
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
    }

    /// @dev A facet that tries to forge the snapshot via `setOutAmount` is refused by BaseHook while the pre
    ///      mutex is set; the router call reverts and so does the op.
    function test_Executor_FacetReentersSetOutAmount_UserOpReverts() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 4e18);
        harness.setMode(MockBinanceRouter.Mode.REENTER_SET_OUT_AMOUNT);
        deal(USDT, smartAccount, amountIn);

        instance.expect4337Revert(BaseHook.CANNOT_SET_OUT_AMOUNT.selector);
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), amountIn, "nothing spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
    }

    /*//////////////////////////////////////////////////////////////
            ISSUER ACTIONS ON THE bSTOCK (paused / sanctioned)
    //////////////////////////////////////////////////////////////*/

    /// @dev AAPLB's pause manager and compliance contract, read from the token on BSC
    ///      (`pauseManager()`, `compliance()`). The token consults them on transfer.
    address internal constant AAPLB_PAUSE_MANAGER = 0x9fc74Be63f3589485B2423984a7a0557e0CF700a;
    address internal constant AAPLB_COMPLIANCE = 0x53dBa7AaBDe774787A1F57236B235567dA8e14F4;

    /// @dev Issuer pauses the bStock mid-flight: the router's transfer to the account reverts, the
    ///      whole UserOp reverts, nothing is spent and no allowance survives.
    function test_Executor_BStockPaused_UserOpReverts_NothingSpent() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        MockBinanceRouter harness = _etchHarness(amountIn, 4e18);
        deal(USDT, smartAccount, amountIn);

        vm.mockCall(AAPLB_PAUSE_MANAGER, abi.encodeWithSignature("isTokenPaused(address)", AAPLB), abi.encode(true));

        instance.expect4337Revert();
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), amountIn, "nothing spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), 0);
        assertEq(harness.calls(), 0, "the router call was rolled back with the op");
    }

    /// @dev The strategy address lands on the global sanctions list: compliance rejects the transfer,
    ///      the batch fails closed (no in-hook check needed, per D14).
    function test_Executor_StrategySanctioned_UserOpReverts_NothingSpent() public {
        _requireFork();
        uint256 amountIn = 1000e18;
        _etchHarness(amountIn, 4e18);
        deal(USDT, smartAccount, amountIn);

        vm.mockCallRevert(
            AAPLB_COMPLIANCE,
            abi.encodeWithSelector(bytes4(keccak256("checkIsCompliant(address,address)"))),
            "SANCTIONED"
        );

        instance.expect4337Revert();
        executeOp(_userOp(_hookData(amountIn, 4e18, ROUTER, _harnessTxData())));

        assertEq(IERC20(USDT).balanceOf(smartAccount), amountIn, "nothing spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    LIVE: real LiquidMesh quote via the API
    //////////////////////////////////////////////////////////////*/

    /// @dev External wrapper so the API call can be try/caught and turned into a skip.
    function fetchLiveSwapExternal(uint256 amountIn) external returns (BinanceSwapTx memory swapTx) {
        swapTx = binanceQuoteAndSwap(56, USDT, AAPLB, amountIn, account, "1");
    }

    function test_Live_USDT_to_AAPLB_LiquidMesh() public {
        _requireFork();
        if (!binanceCredentialsPresent()) vm.skip(true);

        uint256 amountIn = 100e18;

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(USDT, account, amountIn);

            BinanceSwapTx memory swapTx;
            try this.fetchLiveSwapExternal(amountIn) returns (BinanceSwapTx memory result) {
                swapTx = result;
            } catch (bytes memory reason) {
                // Only a transport failure (no body) may skip; an API error body, a changed response
                // shape or a parse problem must FAIL the test, never read as green.
                if (bytes4(reason) == EmptyResponse.selector) vm.skip(true);
                assembly {
                    revert(add(reason, 0x20), mload(reason))
                }
            }

            console2.log("Attempt", attempt, "- API `to`:", swapTx.to);
            console2.log("minReceiveAmount:", swapTx.minReceiveAmount);

            // The single most important observation this test makes: is the API's `to` the pinned
            // router? If not, the deploy constant is wrong and ROUTER_MISMATCH will fire at build.
            if (swapTx.to != ROUTER) {
                console2.log("ROUTER MISMATCH: pinned", ROUTER, "api returned", swapTx.to);
                revert("LiquidMesh /swap `to` differs from the pinned router - fix BINANCE_DEX_ROUTER_BNB");
            }
            assertEq(swapTx.value, 0, "token route must not carry native value");

            uint256 minOut = swapTx.minReceiveAmount != 0 ? swapTx.minReceiveAmount : 1;
            bytes memory data = _hookData(amountIn, minOut, swapTx.to, swapTx.data);

            uint256 usdtBefore = IERC20(USDT).balanceOf(account);
            uint256 aaplBefore = IERC20(AAPLB).balanceOf(account);

            Execution[] memory executions = hook.build(address(0), account, data);
            assertEq(executions.length, 6);

            (uint256 failedAt,) = _executeBatch(executions);
            if (failedAt == type(uint256).max) {
                uint256 spent = usdtBefore - IERC20(USDT).balanceOf(account);
                uint256 received = IERC20(AAPLB).balanceOf(account) - aaplBefore;
                console2.log("USDT spent:", spent);
                console2.log("AAPLB received:", received);

                assertLe(spent, amountIn, "never spends more than the header inputAmount");
                assertGe(received, minOut, "received >= outputMin");
                assertEq(IERC20(USDT).allowance(account, ROUTER), 0, "allowance cleared");
                assertEq(hook.getOutAmount(account), received);
                return;
            }

            console2.log("Attempt", attempt, "failed at step", failedAt);
            vm.revertToState(snap);
        }
        revert("Live swap failed after all retries");
    }
}

/// @title BinanceHookTxCapResetE2E
/// @notice Proves the per-transaction cap accumulator (`txSpent`, EIP-1153 transient storage) starts from zero
///         in a new transaction, so the cap bounds loss per TRANSACTION and not per lifetime of the hook.
/// @dev HOW. Forge runs `setUp` and each test body as separate top-level transactions over the same committed
///      state. Verified on forge 1.5.1 (and pinned by the contrast test below): a `tstore` made in `setUp` reads
///      as zero in the test body, while two external calls inside one test body share it. So `setUp` is
///      transaction 1 and the test body is transaction 2. Both go through a real `EntryPoint.handleOps`, no
///      cheatcode touches the accumulator, and the mock router's storage (`calls`) spans both to show the
///      state really carried over while the transient slot did not.
/// @dev PROVEN: `txSpent == cap` at the end of transaction 1; `txSpent == 0` at the start of transaction 2; a
///      second full-cap UserOp succeeds in transaction 2; back-to-back `handleOps` INSIDE one transaction do
///      not reset it (contrast test). NOT PROVEN: the reset mechanism itself is the EVM's end-of-transaction
///      clear, which this harness can only observe, not distinguish from a hypothetical Forge-side clear.
contract BinanceHookTxCapResetE2E is BinanceHookE2EBase {
    using ModuleKitHelpers for *;

    uint256 internal constant OUT_PER_SWAP = 4e18;

    /// @dev Transaction 1: a UserOp spends exactly the cap. The accumulator sits at `cap` when this
    ///      transaction ends.
    function setUp() public override {
        super.setUp();
        if (!forked) return;

        _etchHarness(cap, OUT_PER_SWAP);
        deal(USDT, smartAccount, cap);

        executeOp(_userOp(_hookData(cap, OUT_PER_SWAP, ROUTER, _harnessTxData())));

        assertEq(hook.txSpent(smartAccount), cap, "tx 1 ends with the accumulator at the cap");
        assertEq(IERC20(USDT).balanceOf(smartAccount), 0, "tx 1 spent the full cap");
        assertEq(MockBinanceRouter(payable(ROUTER)).calls(), 1);
    }

    /// @dev Transaction 2: the accumulator reads zero and a second full-cap UserOp succeeds.
    function test_TxCap_ResetsInNextTransaction() public {
        _requireFork();
        assertEq(hook.txSpent(smartAccount), 0, "a new transaction starts from zero");
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), OUT_PER_SWAP, "tx 1's output persisted (persistent state)");
        assertEq(MockBinanceRouter(payable(ROUTER)).calls(), 1, "tx 1's router call persisted (persistent state)");

        deal(USDT, smartAccount, cap);
        deal(AAPLB, ROUTER, OUT_PER_SWAP);
        executeOp(_userOp(_hookData(cap, OUT_PER_SWAP, ROUTER, _harnessTxData())));

        assertEq(hook.txSpent(smartAccount), cap, "tx 2 accumulates from zero up to the cap");
        assertEq(IERC20(USDT).balanceOf(smartAccount), 0, "the full cap was spent again");
        assertEq(IERC20(AAPLB).balanceOf(smartAccount), 2 * OUT_PER_SWAP);
        assertEq(MockBinanceRouter(payable(ROUTER)).calls(), 2);
    }

    /// @dev Contrast: two `handleOps` calls INSIDE one transaction share the accumulator. After a full-cap
    ///      UserOp, a 1-wei UserOp in the same transaction trips INPUT_EXCEEDS_CAP at preExecute. The
    ///      harness is reconfigured to pull 1 wei so the cap is the only thing that can reject the op.
    function test_TxCap_PersistsAcrossUserOpsWithinOneTransaction() public {
        _requireFork();
        deal(USDT, smartAccount, cap + 1);
        deal(AAPLB, ROUTER, 2 * OUT_PER_SWAP);

        executeOp(_userOp(_hookData(cap, OUT_PER_SWAP, ROUTER, _harnessTxData())));
        assertEq(hook.txSpent(smartAccount), cap);

        MockBinanceRouter(payable(ROUTER)).configure(USDT, 1, AAPLB, OUT_PER_SWAP);
        instance.expect4337Revert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        executeOp(_userOp(_hookData(1, OUT_PER_SWAP, ROUTER, _harnessTxData())));

        assertEq(hook.txSpent(smartAccount), cap, "the rejected op did not move the accumulator");
        assertEq(IERC20(USDT).balanceOf(smartAccount), 1, "nothing beyond the cap was spent");
        assertEq(IERC20(USDT).allowance(smartAccount, ROUTER), 0);
    }
}
