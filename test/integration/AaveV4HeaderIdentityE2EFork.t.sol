// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperHookInspector } from "../../src/interfaces/ISuperHook.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { AaveV4SupplyHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { BaseAaveV4LoanHookV2 } from "../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { AaveV4ReserveKey } from "../../src/libraries/AaveV4ReserveKey.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4HeaderIdentityE2EFork
/// @notice Header identity end-to-end on the live Ethereum Main Spoke through the real SuperExecutor,
///         SuperLedger, AaveV4ReserveRegistryV2 and the merged Aave V4 reserve oracle: every Aave V4 hook
///         header resolves through the registry to the thing the hook acts on — idle USDC lending and a
///         WETH-collateral USDC borrow on the SAME spoke are keyed apart, the two-way mode partition holds,
///         and an operator can recover from routing an OPEN onto an idle reserve.
/// @dev SUP-21239 split the header namespace in two, and both halves are exercised here against one live
///      spoke: since SUP-21254 the idle INFLOW / OUTFLOW pair ALSO pins a market key (which is also its SuperLedger
///      key and an oracle argument), while the six V2 LOAN hooks carry the MARKET key of their pair, which
///      resolves only through `getMarketInfo` and never reaches the ledger or the oracle.
contract AaveV4HeaderIdentityE2EFork is MinimalBaseIntegrationTest {
    address public constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant WETH_RESERVE_ID = 0;
    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant LEND = 2000e6;
    uint256 public constant PLEDGE = 1 ether;
    uint256 public constant BORROW = 500e6;
    bytes32 public constant ORACLE_SALT = bytes32("AaveV4ReserveOracle");

    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    SuperLedger public superLedger;
    ISuperNativePaymaster public superNativePaymaster;
    bytes32 public oracleId;
    address public wethKey;
    address public wethDebtKey;
    address public usdcKey;
    /// @dev SUP-21254: the idle pair's header is now a MARKET key whose SUPPLY leg is the reserve the op
    ///      moves. For an idle USDC lend that is the (USDC collateral, WETH loan) market — the MIRROR of
    ///      the loan market, which is (WETH collateral, USDC loan).
    address public idleUsdcMarketKey;
    address public usdcDebtKey;

    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    AaveV4SupplyAndBorrowHookV2 public openHook;
    AaveV4RepayHookV2 public repayHook;
    AaveV4RepayAndWithdrawHookV2 public closeHook;
    AaveV4SupplyHookV2 public pledgeHook;
    AaveV4BorrowHookV2 public borrowHook;
    AaveV4WithdrawHookV2 public releaseHook;

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        registry = new AaveV4ReserveRegistryV2(address(this));
        (wethKey, wethDebtKey) = registry.registerReserve(SPOKE, WETH_RESERVE_ID);
        (usdcKey, usdcDebtKey) = registry.registerReserve(SPOKE, USDC_RESERVE_ID);
        // the oracle resolves an idle header through `_resolveLeg`, which reverts for an unregistered
        // market, so an idle op can only settle under a blessed market
        idleUsdcMarketKey = registry.registerMarket(SPOKE, USDC_RESERVE_ID, WETH_RESERVE_ID);
        oracle = new AaveV4ReserveOracle(address(ledgerConfig), address(registry));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: makeAddr("aaveFeeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));
        superLedger = SuperLedger(address(ledger));

        lendHook = new AaveV4LendHook();
        redeemHook = new AaveV4RedeemHook();
        openHook = new AaveV4SupplyAndBorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();
        pledgeHook = new AaveV4SupplyHookV2();
        borrowHook = new AaveV4BorrowHookV2();
        releaseHook = new AaveV4WithdrawHookV2();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_1_WETH, accountEth, 10 ether);
        _getTokens(CHAIN_1_USDC, accountEth, 10_000e6);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Idle 189-byte layout: oracle id | MARKET key | underlying | spoke |
    ///      reserveId | amount | usePrev
    function _idleData(
        address underlying,
        uint256 reserveId,
        uint256 amount,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        // SUP-21254: the idle header is the MARKET key whose SUPPLY leg is the reserve this op moves.
        // The borrow leg is identity only; USDC(7) pairs with WETH(0) and vice versa.
        uint256 borrowReserveId = reserveId == USDC_RESERVE_ID ? WETH_RESERVE_ID : USDC_RESERVE_ID;
        return abi.encodePacked(
            oracleId,
            AaveV4ReserveKey.computeMarketKey(SPOKE, reserveId, borrowReserveId),
            underlying,
            SPOKE,
            reserveId,
            amount,
            usePrev,
            borrowReserveId
        );
    }

    /// @dev LOAN 241-byte layout, header = the MARKET key of (SPOKE, supplyId, borrowId) (SUP-21239). The
    ///      idle builder above also carries a market key since SUP-21254 — the market whose SUPPLY leg is
    ///      the reserve the idle op moves, which is the mirror of the loan market's pair.
    function _loanData(
        address loanToken,
        address collateralToken,
        uint256 supplyId,
        uint256 borrowId,
        uint256 a1,
        uint256 a2,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            oracleId,
            AaveV4ReserveKey.computeMarketKey(SPOKE, supplyId, borrowId),
            loanToken,
            collateralToken,
            SPOKE,
            supplyId,
            borrowId,
            a1,
            a2,
            usePrev
        );
    }

    function _pledge(uint256 amount) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, amount, 0, false);
    }

    function _release(uint256 amount) internal view returns (bytes memory) {
        return _pledge(amount);
    }

    function _borrow(uint256 amount) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, amount, 0, false);
    }

    function _repay(uint256 cap, bool usePrev) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, cap, 0, usePrev);
    }

    function _open(uint256 supply, uint256 borrow) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, supply, borrow, false);
    }

    function _close(uint256 cap, uint256 withdraw) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, cap, withdraw, false);
    }

    /*//////////////////////////////////////////////////////////////
                              EXECUTION
    //////////////////////////////////////////////////////////////*/

    function _exec(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return _execHooks(hooks, datas);
    }

    function _execHooks(address[] memory hooks, bytes[] memory datas) internal returns (ExecutionReturnData memory) {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _execExpectFailure(address hook, bytes memory data, bytes4 expectedSelector) internal {
        ExecutionReturnData memory ret = _exec(hook, data);
        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length && !found; ++i) {
            VmSafe.Log memory log = ret.logs[i];
            if (log.topics.length == 0 || log.topics[0] != revertTopic) continue;
            bytes memory blob = log.data;
            for (uint256 j; j + 4 <= blob.length; ++j) {
                if (
                    blob[j] == expectedSelector[0] && blob[j + 1] == expectedSelector[1]
                        && blob[j + 2] == expectedSelector[2] && blob[j + 3] == expectedSelector[3]
                ) {
                    found = true;
                    break;
                }
            }
        }
        assertTrue(found, "expected UserOperationRevertReason with the given selector");
    }

    function _supplied(uint256 id) internal view returns (uint256) {
        return IAaveV4Spoke(SPOKE).getUserSuppliedAssets(id, accountEth);
    }

    function _debt(uint256 id) internal view returns (uint256) {
        (uint256 d, uint256 p) = IAaveV4Spoke(SPOKE).getUserDebt(id, accountEth);
        return d + p;
    }

    function _flag(uint256 id) internal view returns (bool f) {
        (f,) = IAaveV4Spoke(SPOKE).getUserReserveStatus(id, accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                    E2E-1: KEY RESOLUTION FOR EVERY AAVE V4 HOOK
    //////////////////////////////////////////////////////////////*/

    /// @notice inspect()[0:20] of all eight Aave V4 hooks resolves through the deployed registry — but through
    ///         the namespace that op belongs to (SUP-21239). The idle lend / redeem pair resolves through
    ///         `getReserveInfo` to the SUPPLY leg of its own reserve, still a NAV and SuperLedger key. The six
    ///         V2 LOAN ops resolve through `getMarketInfo` to the ONE market key of (WETH collateral, USDC
    ///         loan) — the same 20 bytes for all six, where the per-reserve rule gave OPEN / CLOSE / PLEDGE /
    ///         RELEASE the WETH key and REPAY / BORROW the USDC one — and are asserted NOT to be registered
    ///         reserve keys at all; the oracle resolves them one-directionally, to the collateral leg only.
    function test_E2E_HeaderKey_ResolvesThroughRegistry_AllEightOps() external {
        address marketKey = registry.registerMarket(SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID);
        assertEq(marketKey, AaveV4ReserveKey.computeMarketKey(SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID));

        // the idle pair: reserve namespace, SUPPLY leg, its own reserve
        _assertIdleHeaderResolvesToItsMarketSupplyLeg(
            address(lendHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false)
        );
        _assertIdleHeaderResolvesToItsMarketSupplyLeg(
            address(redeemHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false)
        );

        // the six V2 LOAN ops: market namespace, one key, never a reserve leg
        address[6] memory loanHooks = [
            address(openHook),
            address(closeHook),
            address(pledgeHook),
            address(releaseHook),
            address(repayHook),
            address(borrowHook)
        ];
        bytes[6] memory loanDatas = [
            _open(PLEDGE, BORROW),
            _close(BORROW, PLEDGE),
            _pledge(PLEDGE),
            _release(PLEDGE),
            _repay(BORROW, false),
            _borrow(BORROW)
        ];
        for (uint256 i; i < loanHooks.length; ++i) {
            address key = BytesLib.toAddress(ISuperHookInspector(loanHooks[i]).inspect(loanDatas[i]), 0);
            assertEq(key, BytesLib.toAddress(loanDatas[i], 32), "inspect key == header key");
            assertEq(key, marketKey, "all six V2 ops resolve to the one market key");
            assertTrue(registry.isMarketRegistered(key), "resolves in the MARKET namespace");
            assertFalse(registry.isRegistered(key), "and is never a registered reserve leg");
            assertTrue(key != wethKey && key != wethDebtKey && key != usdcKey && key != usdcDebtKey, "no leg key");
        }
        _assertMarketBinding(marketKey);
    }

    /// @dev One idle header's resolution. SUP-21254 moved this from the reserve namespace to the market
    ///      namespace, with the supply-leg convention as the bridge: the header is a market key, and the
    ///      ORACLE resolves it to the SUPPLY leg of that market — which by the one-word construction in the
    ///      decoder is exactly the reserve the op moved. Factored out for the stack frame.
    function _assertIdleHeaderResolvesToItsMarketSupplyLeg(address hook, bytes memory data) internal view {
        address key = BytesLib.toAddress(ISuperHookInspector(hook).inspect(data), 0);
        assertEq(key, BytesLib.toAddress(data, 32), "inspect key == header key");
        assertEq(key, idleUsdcMarketKey, "the idle pair pins the market whose SUPPLY leg is its reserve");
        assertTrue(registry.isMarketRegistered(key), "key is a registered market");
        assertFalse(registry.isRegistered(key), "and never a reserve leg");
        assertTrue(key != usdcKey && key != usdcDebtKey, "distinct from both legs of its own reserve");

        (address spoke, uint256 supplyId,,,) = registry.getMarketInfo(key);
        assertEq(spoke, SPOKE, "live Main Spoke");
        assertEq(supplyId, USDC_RESERVE_ID, "the market's SUPPLY leg is the idle op's own reserve");
        // and the oracle reads exactly that leg through the market key
        assertEq(
            oracle.getBalanceOfOwner(key, accountEth),
            oracle.getBalanceOfOwner(usdcKey, accountEth),
            "market key resolves to the reserve the idle op moved"
        );
    }

    /// @dev The market binding read from the live spoke. Separate for the same stack-frame reason.
    function _assertMarketBinding(address marketKey) internal view {
        (address spoke, uint256 supplyId, uint256 borrowId, address collateralToken, address loanToken) =
            registry.getMarketInfo(marketKey);
        assertEq(spoke, SPOKE, "live Main Spoke");
        assertEq(supplyId, WETH_RESERVE_ID, "collateral reserve id");
        assertEq(borrowId, USDC_RESERVE_ID, "loan reserve id");
        assertEq(collateralToken, IAaveV4Spoke(SPOKE).getReserve(WETH_RESERVE_ID).underlying, "live collateral");
        assertEq(loanToken, IAaveV4Spoke(SPOKE).getReserve(USDC_RESERVE_ID).underlying, "live loan token");
    }

    /// @notice Market registration does NOT gate execution, proved on the live spoke rather than asserted in
    ///         prose: the full PLEDGE → BORROW → REPAY(max) → RELEASE(max) sequence runs to completion with
    ///         the market UNREGISTERED, and then again after registering it, with identical live deltas. The
    ///         market key is simultaneously shown never to become a SuperLedger key — the accumulator under it
    ///         is zero throughout, while the idle pair's MARKET key is the only Aave V4 key the ledger ever
    ///         holds.
    /// @dev This is the fail-closed/fail-open boundary stated plainly: the hooks pin the key by DERIVATION, so
    ///      an unregistered market still executes, and whitelisting which markets a vault may touch remains an
    ///      off-chain (Erebor) decision. If a future change ever made the hooks consult the registry, the
    ///      first half of this test would fail.
    function test_E2E_MarketRegistration_DoesNotGateExecution_AndIsNeverALedgerKey() external {
        address marketKey = AaveV4ReserveKey.computeMarketKey(SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID);
        assertFalse(registry.isMarketRegistered(marketKey), "unregistered to start with");

        (uint256 unregisteredWethDelta, uint256 unregisteredUsdcDelta) = _runLoanRoundTrip();
        assertEq(superLedger.usersAccumulatorShares(accountEth, marketKey), 0, "market key is never a ledger key");

        registry.registerMarket(SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID);
        assertTrue(registry.isMarketRegistered(marketKey), "now registered");

        (uint256 registeredWethDelta, uint256 registeredUsdcDelta) = _runLoanRoundTrip();
        assertEq(registeredWethDelta, unregisteredWethDelta, "registration changed no collateral outcome");
        assertEq(registeredUsdcDelta, unregisteredUsdcDelta, "registration changed no loan outcome");
        assertEq(superLedger.usersAccumulatorShares(accountEth, marketKey), 0, "still never a ledger key");
        assertEq(superLedger.usersAccumulatorShares(accountEth, wethKey), 0, "LOAN legs never reach the ledger");
        assertEq(superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), 0, "no idle leg was opened here");
    }

    /// @dev One full PLEDGE → BORROW → REPAY(max) → RELEASE(max) round trip on the live spoke, returning the
    ///      net wallet deltas (collateral shortfall from share rounding, loan token net). Ends with no
    ///      position and no debt, so the caller can run it twice and compare.
    function _runLoanRoundTrip() internal returns (uint256 wethShortfall, uint256 usdcNet) {
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _exec(address(pledgeHook), _pledge(PLEDGE));
        _exec(address(borrowHook), _borrow(BORROW));
        assertApproxEqAbs(_debt(USDC_RESERVE_ID), BORROW, 1, "borrowed");
        _exec(address(repayHook), _repay(type(uint256).max, false));
        _exec(address(releaseHook), _release(type(uint256).max));
        assertEq(_debt(USDC_RESERVE_ID), 0, "round trip clears the debt");
        assertEq(_supplied(WETH_RESERVE_ID), 0, "round trip clears the position");
        wethShortfall = wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        usdcNet = usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth);
    }

    /*//////////////////////////////////////////////////////////////
        E2E-2: IDLE USDC LENDER + WETH-COLLATERAL USDC BORROWER, SAME SPOKE
    //////////////////////////////////////////////////////////////*/

    /// @notice The ticket's motivating scenario. The account idle-lends USDC (INFLOW, ledger keyed by the USDC reserve
    ///         key), then pledges WETH and borrows USDC (LOAN, NONACCOUNTING, keyed WETH / USDC). Per key: the oracle
    ///         reports the idle USDC and the pledged WETH separately on their SUPPLY keys and the USDC debt on the
    ///         DEBT key of the very same reserve the idle lend used, and the ledger only ever saw the idle leg.
    ///         Redeeming the idle leg nets the ledger to zero and leaves the LOAN legs untouched; repay + release
    ///         then close the loan.
    function test_E2E_IdleUsdcLender_And_WethCollateralUsdcBorrower_KeyedApart() external {
        // 1. idle lend USDC
        _exec(address(lendHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false));
        uint256 idleCredited = _supplied(USDC_RESERVE_ID);
        assertFalse(_flag(USDC_RESERVE_ID), "idle: never flagged");
        assertEq(
            superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey),
            idleCredited,
            "ledger keyed by the idle market key"
        );
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), idleCredited, "supply key == idle position");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, accountEth), 0, "no debt yet under the USDC debt key");

        // 2. pledge WETH + borrow USDC in one userOp (LOAN legs, NONACCOUNTING)
        address[] memory hooks = new address[](2);
        hooks[0] = address(pledgeHook);
        hooks[1] = address(borrowHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _pledge(PLEDGE);
        datas[1] = _borrow(BORROW);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _execHooks(hooks, datas);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore, BORROW, "borrowed USDC received");
        assertTrue(_flag(WETH_RESERVE_ID), "WETH flagged (LOAN)");
        assertFalse(_flag(USDC_RESERVE_ID), "USDC still idle (never flagged by the borrow)");

        // per-key identities: the SAME USDC reserve carries the idle supply (supply key) and the debt (debt key)
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), idleCredited, "idle USDC untouched by the borrow");
        assertApproxEqAbs(oracle.getBalanceOfOwner(usdcDebtKey, accountEth), BORROW, 1, "debt under the USDC debt key");
        assertApproxEqAbs(oracle.getBalanceOfOwner(wethKey, accountEth), PLEDGE, 2, "pledged WETH under WETH key");
        assertEq(oracle.getBalanceOfOwner(wethDebtKey, accountEth), 0, "no WETH debt");
        // the ledger never saw the LOAN legs
        assertEq(
            superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), idleCredited, "ledger: idle leg only"
        );
        assertEq(superLedger.usersAccumulatorShares(accountEth, wethKey), 0, "ledger: no LOAN entry");

        // 3. redeem the idle leg fully: ledger nets to zero; LOAN legs untouched
        _exec(address(redeemHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, type(uint256).max, false));
        assertEq(superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), 0, "ledger nets to zero");
        assertEq(_supplied(USDC_RESERVE_ID), 0, "idle USDC gone");
        assertApproxEqAbs(_debt(USDC_RESERVE_ID), BORROW, 1, "debt untouched by the idle redeem");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), PLEDGE, 2, "collateral untouched by the idle redeem");

        // 4. close the loan: repay(max) + release(max)
        _exec(address(repayHook), _repay(type(uint256).max, false));
        _exec(address(releaseHook), _release(type(uint256).max));
        assertEq(_debt(USDC_RESERVE_ID), 0);
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, accountEth), 0);
        assertEq(oracle.getBalanceOfOwner(wethKey, accountEth), 0);
    }

    /*//////////////////////////////////////////////////////////////
                E2E-3: TWO-WAY MODE PARTITION IN ONE PLACE
    //////////////////////////////////////////////////////////////*/

    /// @notice On one reserve the account is either idle or LOAN, enforced from both sides: a flagged (pledged) WETH
    ///         reserve refuses the idle LEND and REDEEM; an idle (lent) USDC reserve refuses PLEDGE, OPEN and RELEASE
    function test_E2E_ModePartition_BothDirections_LiveSpoke() external {
        _exec(address(pledgeHook), _pledge(PLEDGE));
        _execExpectFailure(
            address(lendHook),
            _idleData(CHAIN_1_WETH, WETH_RESERVE_ID, 0.1 ether, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        _execExpectFailure(
            address(redeemHook),
            _idleData(CHAIN_1_WETH, WETH_RESERVE_ID, type(uint256).max, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );

        _exec(address(lendHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false));
        // LOAN hooks on the USDC reserve as COLLATERAL (borrowing WETH against it) are refused while it is idle
        bytes memory pledgeUsdc =
            _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, 100e6, 0, false);
        bytes memory openUsdc =
            _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, 100e6, 0.01 ether, false);
        bytes memory releaseUsdc =
            _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, type(uint256).max, 0, false);
        _execExpectFailure(address(pledgeHook), pledgeUsdc, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _execExpectFailure(address(openHook), openUsdc, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _execExpectFailure(address(releaseHook), releaseUsdc, bytes4(keccak256("RESERVE_NOT_COLLATERAL()")));
        assertEq(
            superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), _supplied(USDC_RESERVE_ID), "idle intact"
        );
    }

    /*//////////////////////////////////////////////////////////////
            E2E-4: OPERATOR RECOVERY FROM AN OPEN ROUTED ONTO AN IDLE RESERVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Real-life routing mistake: the account idle-lends USDC, then an OPEN using USDC as collateral is routed
    ///         to it. The guard refuses it atomically. The correct sequence — redeem the idle leg (ledger nets to
    /// zero), then OPEN — succeeds and the USDC position is now LOAN-mode (flagged), keyed by the same USDC key but
    /// no
    ///         longer ledger-tracked; the idle LEND is refused from then on
    function test_E2E_OpenOverIdle_Refused_ThenRedeemAndOpen_Succeeds() external {
        _exec(address(lendHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false));
        bytes memory openUsdcCollateral =
            _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, 1000e6, 0.05 ether, false);
        _execExpectFailure(
            address(openHook), openUsdcCollateral, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector
        );
        assertFalse(_flag(USDC_RESERVE_ID), "flag untouched");
        assertEq(_debt(WETH_RESERVE_ID), 0, "no WETH debt");

        _exec(address(redeemHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, type(uint256).max, false));
        assertEq(superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), 0, "idle leg netted");

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _exec(address(openHook), openUsdcCollateral);
        assertTrue(_flag(USDC_RESERVE_ID), "USDC now LOAN-mode collateral");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.05 ether, "WETH borrowed exactly");
        assertApproxEqAbs(
            oracle.getBalanceOfOwner(wethDebtKey, accountEth), 0.05 ether, 1, "WETH debt under WETH debt key"
        );
        assertApproxEqAbs(oracle.getBalanceOfOwner(usdcKey, accountEth), 1000e6, 2, "USDC collateral under USDC key");
        assertEq(
            superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), 0, "LOAN leg never reaches the ledger"
        );
        // the reserve is LOAN-mode now: the idle LEND is refused
        _execExpectFailure(
            address(lendHook),
            _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, 100e6, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
    }

    /*//////////////////////////////////////////////////////////////
            E2E-5: SAME-USEROP IDLE→LOAN CONFLICT IS ATOMIC
    //////////////////////////////////////////////////////////////*/

    /// @notice [LEND USDC (idle), OPEN USDC-collateral] in ONE userOp: the OPEN guard trips on the position the LEND
    ///         just created, the whole userOp reverts and the ledger never records the inflow
    function test_E2E_LendThenOpen_SameUserOp_RevertsAtomically_NoLedgerInflow() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(lendHook);
        hooks[1] = address(openHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false);
        datas[1] = _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, 1000e6, 0.05 ether, false);
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _execHooksExpectFailure(hooks, datas, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "lend rolled back");
        assertEq(_supplied(USDC_RESERVE_ID), 0, "no position");
        assertEq(superLedger.usersAccumulatorShares(accountEth, idleUsdcMarketKey), 0, "ledger saw nothing");
        assertEq(_debt(WETH_RESERVE_ID), 0);
    }

    /*//////////////////////////////////////////////////////////////
                E2E-6: OPEN → CLOSE(max, max) → OPEN AGAIN
    //////////////////////////////////////////////////////////////*/

    /// @notice A fully closed LOAN position leaves an empty reserve (flag kept by the Spoke); the guard treats that
    ///         as LOAN-mode and a second OPEN proceeds with exactly its own numbers
    function test_E2E_OpenCloseOpen_SameReserve_SecondOpenExact() external {
        _exec(address(openHook), _open(PLEDGE, BORROW));
        uint256 debt = _debt(USDC_RESERVE_ID);
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + debt);
        _exec(address(closeHook), _close(type(uint256).max, type(uint256).max));
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(_debt(USDC_RESERVE_ID), 0);
        assertTrue(_flag(WETH_RESERVE_ID), "flag kept after a full close");
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _exec(address(openHook), _open(0.5 ether, 200e6));
        assertEq(wethBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), 0.5 ether, "second open supplies exactly");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), 0.5 ether, 2, "position == second open only");
        assertApproxEqAbs(_debt(USDC_RESERVE_ID), 200e6, 1, "debt == second open only");
    }

    /*//////////////////////////////////////////////////////////////
        E2E-7: LOAN → FULL RELEASE → (flag cleared by the account) → IDLE LEND / REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice After PLEDGE + RELEASE(max) the reserve is empty but stays LOAN-mode (flag kept), so the idle LEND is
    ///         refused until the account clears the flag itself; then LEND → REDEEM(max) rounds through whatever dust
    ///         shares the full release left behind and the ledger still nets to zero
    function test_E2E_ReleaseThenIdle_RequiresManualFlagClear_LedgerNetsWithDust() external {
        _exec(address(pledgeHook), _pledge(PLEDGE));
        _exec(address(releaseHook), _release(type(uint256).max));
        assertEq(_supplied(WETH_RESERVE_ID), 0, "position empty");
        assertTrue(_flag(WETH_RESERVE_ID), "flag kept by the Spoke after a full withdrawal");
        _execExpectFailure(
            address(lendHook),
            _idleData(CHAIN_1_WETH, WETH_RESERVE_ID, 0.2 ether, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(WETH_RESERVE_ID, false, accountEth);
        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _exec(address(lendHook), _idleData(CHAIN_1_WETH, WETH_RESERVE_ID, 0.2 ether, false));
        uint256 credited = _supplied(WETH_RESERVE_ID);
        assertEq(superLedger.usersAccumulatorShares(accountEth, wethKey), credited, "ledger keyed by WETH key");
        _exec(address(redeemHook), _idleData(CHAIN_1_WETH, WETH_RESERVE_ID, type(uint256).max, false));
        assertEq(_supplied(WETH_RESERVE_ID), 0, "idle leg fully redeemed (incl. any dust shares' value)");
        assertEq(superLedger.usersAccumulatorShares(accountEth, wethKey), 0, "ledger nets to zero");
        assertApproxEqAbs(IERC20(CHAIN_1_WETH).balanceOf(accountEth), wethBefore, 2, "WETH back within rounding");
    }

    function _execHooksExpectFailure(address[] memory hooks, bytes[] memory datas, bytes4 expectedSelector) internal {
        ExecutionReturnData memory ret = _execHooks(hooks, datas);
        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length && !found; ++i) {
            if (ret.logs[i].topics.length == 0 || ret.logs[i].topics[0] != revertTopic) continue;
            bytes memory blob = ret.logs[i].data;
            for (uint256 j; j + 4 <= blob.length; ++j) {
                if (
                    blob[j] == expectedSelector[0] && blob[j + 1] == expectedSelector[1]
                        && blob[j + 2] == expectedSelector[2] && blob[j + 3] == expectedSelector[3]
                ) {
                    found = true;
                    break;
                }
            }
        }
        assertTrue(found, "expected UserOperationRevertReason with the given selector");
    }
}
