// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Vm } from "forge-std/Vm.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ModuleKitHelpers, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";

import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ForceRedeemMorphoVaultHook } from "../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../src/vendor/morpho/IMorphoMarketV1Adapter.sol";

/// @title ForceRedeemMorphoVaultLedgerE2E
/// @notice Drives `ForceRedeemMorphoVaultHook` through the REAL `SuperExecutor` -> `_updateAccounting` ->
///         `SuperLedger` path on a mainnet fork. This is the behaviour that separates it from the
///         NONACCOUNTING siblings, and every other test replays the lifecycle by hand and never touches it.
/// @dev An INFLOW is recorded first through the same executor, so the ledger holds shares and a cost basis
///      for the account before the forced exit. Without that the outflow hits the zero-accumulator
///      short-circuit and proves nothing about cost-basis or fee arithmetic.
contract ForceRedeemMorphoVaultLedgerE2ETest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    address public constant GAUNTLET_WETH_PRIME = 0x43fCd85E8D9D003D515f886891B7C742AC9f92da;

    ForceRedeemMorphoVaultHook internal hook;
    ISuperNativePaymaster internal superNativePaymaster;
    address internal feeRecipient;

    function setUp() public override {
        blockNumber = 26_384_300;
        super.setUp();
        hook = new ForceRedeemMorphoVaultHook(MORPHO);
        feeRecipient = makeAddr("feeRecipient"); // the label MinimalBaseIntegrationTest registered
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
        _getTokens(CHAIN_1_WETH, accountEth, 8000 ether);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The whole path, end to end: inflow recorded, forced exit executed by the executor, ledger
    ///      accumulator reduced by exactly the shares the hook reported, fee routed, account paid net.
    function test_FullPathThroughSuperExecutorAndLedger() public {
        _recordInflow(3000 ether);

        // SUP-21849: the hook is sized in SHARES; the underlying it pays is the solver's quote.
        uint256 shares = 1200 ether;
        uint256 assets = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, accountEth, shares);
        uint256 sourced = _plannedSourced(shares);
        uint256 accBefore = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth);
        uint256 positionsBefore = _positions();
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_WETH).balanceOf(feeRecipient);
        assertGt(accBefore, 0, "the inflow must have been recorded by the ledger");

        ExecutionReturnData memory r = executeOp(_forceRedeemOp(_oracleId(), shares));
        (uint256 outflows, uint256 amount, uint256 fee) = _outflow(r);
        uint256 burned = sharesBefore - IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth);
        assertEq(burned, shares, "a share-sized exit consumes exactly S: P burned as penalty, S - P redeemed");

        // The OUTFLOW branch of `_updateAccounting` ran through the ledger: without this, a hook that
        // never reached the ledger would pass every balance assertion below with fee == 0.
        assertEq(outflows, 1, "exactly one AccountingOutflow from the ledger");
        assertEq(amount, assets, "with the hook's outAmount as the processed volume");

        // The ledger: realised position == what the hook said it gave up, penalty burns included.
        assertEq(hook.usedShares(), burned, "usedShares is the full share decrease");
        assertEq(
            accBefore - SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME),
            burned,
            "ledger accumulator fell by exactly usedShares"
        );
        // Fee, refresh and payout are consistent with each other and with the markets.
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(feeRecipient) - feeBefore, fee, "fee reached the recipient");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, assets - fee, "account paid net of fee");
        assertEq(hook.getOutAmount(accountEth), assets - fee, "outAmount refreshed net of fee by the executor");
        assertEq(positionsBefore - _positions(), sourced, "the markets were drawn down by exactly the planned pulls");
    }

    /// @dev The fee leg of `_updateAccounting`, with a profit that is KNOWN rather than hoped for. Vault V2's
    ///      interest controller fixes a forward rate at every accrue, so warping time after the inflow's
    ///      accrue moves the price by nothing. Instead the oracle is mocked LOW during the inflow only, so
    ///      the ledger records a cost basis below reality; the exit then runs against the real oracle and
    ///      the real ledger arithmetic, and the fee can be asserted to the wei.
    function test_PerformanceFeeIsTakenOnRealisedProfit() public {
        vm.mockCall(
            yieldSourceOracle,
            abi.encodeWithSelector(IYieldSourceOracle.getPricePerShare.selector, GAUNTLET_WETH_PRIME),
            abi.encode(uint256(0.9e18))
        );
        _recordInflow(3000 ether);
        vm.clearMockedCalls();

        uint256 shares = 1000 ether;
        uint256 assets = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, accountEth, shares);
        uint256 accShares = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        uint256 accCost = SuperLedger(address(ledger)).usersAccumulatorCostBasis(accountEth, GAUNTLET_WETH_PRIME);
        uint256 feeBefore = IERC20(CHAIN_1_WETH).balanceOf(feeRecipient);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        ExecutionReturnData memory r = executeOp(_forceRedeemOp(_oracleId(), shares));
        (,, uint256 fee) = _outflow(r);

        // Re-derive what BaseLedger must have computed: cost basis pro-rata on the shares consumed, 1% of
        // the profit above it.
        uint256 costBasis = Math.mulDiv(accCost, hook.usedShares(), accShares);
        uint256 expectedFee = Math.mulDiv(assets - costBasis, 100, 10_000);

        assertGt(fee, 0, "a profit was realised, so a fee is due");
        assertEq(fee, expectedFee, "and it is exactly 1% of the realised profit");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(feeRecipient) - feeBefore, fee, "paid to the recipient");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, assets - fee, "account paid net");
        assertEq(hook.getOutAmount(accountEth), assets - fee, "outAmount refreshed net of fee");
    }

    /// @dev Modulekit's error, as declared in `ERC4337Helpers.sol` (five params — the four-param twin in
    ///      `MinimalBaseNexusIntegrationTest` is stale against this modulekit version).
    error UserOperationReverted(
        bytes32 userOpHash, address sender, string senderLabel, uint256 nonce, bytes revertReason
    );

    /// @dev The one new precondition this hook has over its siblings: offset 0 must be the chain's REAL
    ///      oracle id. The executor refuses an unregistered id with `MANAGER_NOT_SET` before any leg runs.
    ///      The EntryPoint swallows execution-phase reverts into a log; modulekit re-raises them as
    ///      `UserOperationReverted` in the test frame, which an external self-call can catch and decode.
    function test_UnregisteredOracleIdIsRefusedByTheExecutor() public {
        _recordInflow(3000 ether);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth);
        uint256 positionsBefore = _positions();
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        UserOpData memory op = _forceRedeemOp(bytes32(uint256(0xFEED)), 1000 ether);
        try this.executeOp(op) {
            assertTrue(false, "an unregistered oracle id must not execute");
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), UserOperationReverted.selector, "the op was rejected");
            bytes memory tail = new bytes(reason.length - 4);
            for (uint256 i; i < tail.length; ++i) tail[i] = reason[i + 4];
            (,,,, bytes memory inner) = abi.decode(tail, (bytes32, address, string, uint256, bytes));
            assertEq(bytes4(inner), bytes4(0x80776599), "and the cause is MANAGER_NOT_SET");
        }

        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth), sharesBefore, "no shares burned");
        assertEq(_positions(), positionsBefore, "no market touched");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "nothing paid out");
    }

    /// @dev SUP-21849: a floor equal to the live quote passes through the executor and is met on the GROSS
    ///      delta; the ledger's fee comes out of `outAmount` afterwards, which is why the floor is pre-fee.
    function test_FloorAtTheQuoteIsMetThroughTheExecutor() public {
        _recordInflow(3000 ether);
        uint256 shares = 1000 ether;
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, accountEth, shares);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_WETH).balanceOf(feeRecipient);

        ExecutionReturnData memory r = executeOp(_forceRedeemOpWithFloor(_oracleId(), shares, quoted));
        (uint256 n,, uint256 fee) = _outflow(r);
        assertEq(n, 1, "one accounting outflow");
        uint256 gross = IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore + fee;
        assertEq(gross, quoted, "the gross delivery equals the quote the floor was set at");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(feeRecipient) - feeBefore, fee, "the fee left the account after the floor check");
    }

    /// @dev One wei above the quote is refused by `build` inside the executor's hook compliance check, so
    ///      nothing is burned, pulled or paid.
    function test_FloorAboveTheQuoteIsRefusedThroughTheExecutor() public {
        _recordInflow(3000 ether);
        uint256 shares = 1000 ether;
        uint256 quoted = hook.previewAssetsOut(GAUNTLET_WETH_PRIME, accountEth, shares);
        uint256 sharesBefore = IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth);
        uint256 positionsBefore = _positions();
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        UserOpData memory op = _forceRedeemOpWithFloor(_oracleId(), shares, quoted + 1);
        try this.executeOp(op) {
            assertTrue(false, "a floor above the quote must not execute");
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), UserOperationReverted.selector, "the op was rejected");
            bytes memory tail = new bytes(reason.length - 4);
            for (uint256 i; i < tail.length; ++i) tail[i] = reason[i + 4];
            (,,,, bytes memory inner) = abi.decode(tail, (bytes32, address, string, uint256, bytes));
            assertEq(bytes4(inner), ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, "cause is the floor");
        }

        assertEq(IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth), sharesBefore, "no shares burned");
        assertEq(_positions(), positionsBefore, "no market touched");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, "nothing paid out");
    }

    /// @dev Two forced exits through the executor: the accumulator falls by each exit's `usedShares` in
    ///      turn, each exit is accounted in its own `AccountingOutflow`, and the cost basis is drawn down
    ///      pro-rata — the ledger stays consistent across legs, not just for one.
    function test_SequentialExitsKeepTheLedgerConsistent() public {
        _recordInflow(3000 ether);
        uint256 acc0 = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        uint256 cost0 = SuperLedger(address(ledger)).usersAccumulatorCostBasis(accountEth, GAUNTLET_WETH_PRIME);

        ExecutionReturnData memory r1 = executeOp(_forceRedeemOp(_oracleId(), 600 ether));
        (uint256 n1,,) = _outflow(r1);
        uint256 used1 = hook.usedShares();
        uint256 acc1 = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        uint256 cost1 = SuperLedger(address(ledger)).usersAccumulatorCostBasis(accountEth, GAUNTLET_WETH_PRIME);
        assertEq(n1, 1, "first exit accounted once");
        assertEq(acc0 - acc1, used1, "accumulator down by the first exit's shares");
        assertEq(cost0 - cost1, Math.mulDiv(cost0, used1, acc0), "cost basis drawn pro-rata");

        ExecutionReturnData memory r2 = executeOp(_forceRedeemOp(_oracleId(), 400 ether));
        (uint256 n2,,) = _outflow(r2);
        uint256 used2 = hook.usedShares();
        uint256 acc2 = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        assertEq(n2, 1, "second exit accounted once");
        assertEq(acc1 - acc2, used2, "accumulator down by the second exit's shares");
        assertEq(acc0 - acc2, used1 + used2, "cumulative");
    }

    /// @dev Inflow and forced exit in ONE userOp — the deposit's INFLOW is recorded by the leg before, so
    ///      the exit's OUTFLOW finds an accumulator to draw on within the same op. Both accounting branches
    ///      run in one `execute`. The exit's amount is set explicitly: the deposit publishes SHARES, so it
    ///      must not be chained with `usePrevHookAmount`.
    function test_InflowAndForcedExitInOneUserOp() public {
        uint256 depositAmt = 3000 ether;
        uint256 exitShares = 1000 ether;

        address[] memory hooks = new address[](3);
        hooks[0] = approveHook;
        hooks[1] = deposit4626Hook;
        hooks[2] = address(hook);
        bytes[] memory data = new bytes[](3);
        data[0] = _createApproveHookData(CHAIN_1_WETH, GAUNTLET_WETH_PRIME, depositAmt, false);
        data[1] = _createDeposit4626HookData(_oracleId(), GAUNTLET_WETH_PRIME, depositAmt, false, address(0), 0);
        data[2] = abi.encodePacked(_oracleId(), GAUNTLET_WETH_PRIME, exitShares, false, uint256(0));
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });

        uint256 positions0 = _positions();
        uint256 weth0 = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        ExecutionReturnData memory r = executeOp(_getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry)));
        (uint256 outflows, uint256 amount, uint256 fee) = _outflow(r);

        assertEq(outflows, 1, "one outflow in the op");
        assertEq(hook.usedShares(), exitShares, "the exit consumed exactly the share input");
        assertEq(
            amount, hook.getOutAmount(accountEth) + fee, "the ledger processed the gross underlying the hook paid out"
        );
        assertGt(amount, 0);
        // the deposit landed in idle inside the same op, so the redeem may need no pull at all
        assertLe(positions0 - _positions(), amount, "the markets were drawn down by at most the exit");
        assertEq(weth0 - IERC20(CHAIN_1_WETH).balanceOf(accountEth), depositAmt - (amount - fee), "net WETH movement");
        uint256 acc = SuperLedger(address(ledger)).usersAccumulatorShares(accountEth, GAUNTLET_WETH_PRIME);
        assertEq(acc, IMorphoVaultV2(GAUNTLET_WETH_PRIME).balanceOf(accountEth), "ledger shares == real shares after both");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev What `MinimalBaseIntegrationTest` registered: salt hashed with the test contract as sender.
    function _oracleId() internal view returns (bytes32) {
        return _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this));
    }

    function _recordInflow(uint256 amount) internal {
        address[] memory hooks = new address[](2);
        hooks[0] = approveHook;
        hooks[1] = deposit4626Hook;
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(CHAIN_1_WETH, GAUNTLET_WETH_PRIME, amount, false);
        data[1] = _createDeposit4626HookData(_oracleId(), GAUNTLET_WETH_PRIME, amount, false, address(0), 0);
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        executeOp(_getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry)));
    }

    /// @dev Sum of the `forceDeallocate` pulls the hook would emit right now for `shares`.
    function _plannedSourced(uint256 shares) internal view returns (uint256 sourced) {
        Execution[] memory all = hook.build(
            address(0), accountEth, abi.encodePacked(_oracleId(), GAUNTLET_WETH_PRIME, shares, false, uint256(0))
        );
        for (uint256 i = 1; i + 2 < all.length; ++i) {
            sourced += _pullAmount(all[i].callData);
        }
    }

    /// @dev Own frame: a four-way `abi.decode` inside the loop above overflows the stack in this contract.
    function _pullAmount(bytes memory raw) internal pure returns (uint256 x) {
        bytes memory args = new bytes(raw.length - 4);
        for (uint256 b; b < args.length; ++b) {
            args[b] = raw[b + 4];
        }
        (,, x,) = abi.decode(args, (address, bytes, uint256, address));
    }

    function _forceRedeemOp(bytes32 oracleId, uint256 shares) internal returns (UserOpData memory) {
        return _forceRedeemOpWithFloor(oracleId, shares, 0);
    }

    function _forceRedeemOpWithFloor(
        bytes32 oracleId,
        uint256 shares,
        uint256 minAssetsOut
    )
        internal
        returns (UserOpData memory)
    {
        address[] memory hooks = new address[](1);
        hooks[0] = address(hook);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked(oracleId, GAUNTLET_WETH_PRIME, shares, false, minAssetsOut);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        return _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
    }

    /// @dev modulekit's `exec4337` calls `recordLogs`/`getRecordedLogs` itself, so a test-level recording
    ///      is consumed and sees nothing. The ledger's event must be read from the logs it RETURNS.
    function _outflow(ExecutionReturnData memory r) internal pure returns (uint256 n, uint256 amount, uint256 fee) {
        bytes32 topic = ISuperLedgerData.AccountingOutflow.selector;
        for (uint256 i; i < r.logs.length; ++i) {
            if (r.logs[i].topics[0] == topic) {
                ++n;
                (amount, fee) = abi.decode(r.logs[i].data, (uint256, uint256));
            }
        }
    }

    function _positions() internal view returns (uint256 total) {
        IMorphoMarketV1Adapter a = IMorphoMarketV1Adapter(IMorphoVaultV2(GAUNTLET_WETH_PRIME).adapters(0));
        for (uint256 i; i < a.marketIdsLength(); ++i) {
            total += a.expectedSupplyAssets(a.marketIds(i));
        }
    }
}
