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
import { AaveV4ReserveRegistry } from "../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { AaveV4DebtOracle } from "../../src/accounting/oracles/AaveV4DebtOracle.sol";
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
/// @notice SUP-21143 end-to-end on the live Ethereum Main Spoke through the real SuperExecutor, SuperLedger,
///         AaveV4ReserveRegistry and both Aave V4 oracles: the reserve key carried in every Aave V4 hook header is
///         the identity the registry, the supply / debt oracles and the ledger agree on — idle USDC lending and a
///         WETH-collateral USDC borrow on the SAME spoke are keyed apart, the two-way mode partition holds, and an
///         operator can recover from routing an OPEN onto an idle reserve.
contract AaveV4HeaderIdentityE2EFork is MinimalBaseIntegrationTest {
    address public constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant WETH_RESERVE_ID = 0;
    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant LEND = 2000e6;
    uint256 public constant PLEDGE = 1 ether;
    uint256 public constant BORROW = 500e6;
    bytes32 public constant ORACLE_SALT = bytes32("AaveV4SupplyYieldSourceOracle");

    AaveV4ReserveRegistry public registry;
    AaveV4SupplyYieldSourceOracle public supplyOracle;
    AaveV4DebtOracle public debtOracle;
    SuperLedger public superLedger;
    ISuperNativePaymaster public superNativePaymaster;
    bytes32 public oracleId;
    address public wethKey;
    address public usdcKey;

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

        registry = new AaveV4ReserveRegistry(address(this));
        wethKey = registry.registerReserve(SPOKE, WETH_RESERVE_ID);
        usdcKey = registry.registerReserve(SPOKE, USDC_RESERVE_ID);
        supplyOracle = new AaveV4SupplyYieldSourceOracle(address(ledgerConfig), address(registry));
        debtOracle = new AaveV4DebtOracle(address(ledgerConfig), address(registry));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(supplyOracle),
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

    /// @dev Idle 157-byte layout: oracle id (the registered supply YS oracle) | reserve key | underlying | spoke |
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
        return abi.encodePacked(
            oracleId,
            AaveV4ReserveKey.computeReserveKey(SPOKE, reserveId),
            underlying,
            SPOKE,
            reserveId,
            amount,
            usePrev
        );
    }

    /// @dev LOAN 241-byte layout keyed to `primaryId`
    function _loanData(
        address loanToken,
        address collateralToken,
        uint256 supplyId,
        uint256 borrowId,
        uint256 primaryId,
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
            AaveV4ReserveKey.computeReserveKey(SPOKE, primaryId),
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
        return
            _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, WETH_RESERVE_ID, amount, 0, false);
    }

    function _release(uint256 amount) internal view returns (bytes memory) {
        return _pledge(amount);
    }

    function _borrow(uint256 amount) internal view returns (bytes memory) {
        return
            _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, USDC_RESERVE_ID, amount, 0, false);
    }

    function _repay(uint256 cap, bool usePrev) internal view returns (bytes memory) {
        return _loanData(CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, USDC_RESERVE_ID, cap, 0, usePrev);
    }

    function _open(uint256 supply, uint256 borrow) internal view returns (bytes memory) {
        return _loanData(
            CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, WETH_RESERVE_ID, supply, borrow, false
        );
    }

    function _close(uint256 cap, uint256 withdraw) internal view returns (bytes memory) {
        return _loanData(
            CHAIN_1_USDC, CHAIN_1_WETH, WETH_RESERVE_ID, USDC_RESERVE_ID, WETH_RESERVE_ID, cap, withdraw, false
        );
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

    /// @notice inspect()[0:20] of all eight Aave V4 hooks resolves through the deployed registry to the (spoke,
    ///         reserveId) each op acts on as its primary: idle lend / redeem → their reserve; OPEN / CLOSE / PLEDGE /
    ///         RELEASE → the supply reserve; REPAY / BORROW → the borrow reserve
    function test_E2E_HeaderKey_ResolvesThroughRegistry_AllEightOps() external view {
        address[8] memory hooks = [
            address(lendHook),
            address(redeemHook),
            address(openHook),
            address(closeHook),
            address(pledgeHook),
            address(releaseHook),
            address(repayHook),
            address(borrowHook)
        ];
        bytes[8] memory datas = [
            _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false),
            _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false),
            _open(PLEDGE, BORROW),
            _close(BORROW, PLEDGE),
            _pledge(PLEDGE),
            _release(PLEDGE),
            _repay(BORROW, false),
            _borrow(BORROW)
        ];
        uint256[8] memory expectedReserve = [
            USDC_RESERVE_ID,
            USDC_RESERVE_ID,
            WETH_RESERVE_ID,
            WETH_RESERVE_ID,
            WETH_RESERVE_ID,
            WETH_RESERVE_ID,
            USDC_RESERVE_ID,
            USDC_RESERVE_ID
        ];
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory id = ISuperHookInspector(hooks[i]).inspect(datas[i]);
            address key = BytesLib.toAddress(id, 0);
            assertEq(key, BytesLib.toAddress(datas[i], 32), "inspect key == header key");
            assertTrue(registry.isRegistered(key), "key is a registered reserve");
            (address spoke, uint256 reserveId, address underlying,) = registry.getReserveInfo(key);
            assertEq(spoke, SPOKE);
            assertEq(reserveId, expectedReserve[i]);
            assertEq(underlying, expectedReserve[i] == USDC_RESERVE_ID ? CHAIN_1_USDC : CHAIN_1_WETH);
        }
    }

    /*//////////////////////////////////////////////////////////////
        E2E-2: IDLE USDC LENDER + WETH-COLLATERAL USDC BORROWER, SAME SPOKE
    //////////////////////////////////////////////////////////////*/

    /// @notice The ticket's motivating scenario. The account idle-lends USDC (INFLOW, ledger keyed by the USDC reserve
    ///         key), then pledges WETH and borrows USDC (LOAN, NONACCOUNTING, keyed WETH / USDC). Per key: the supply
    ///         oracle reports the idle USDC and the pledged WETH separately, the debt oracle reports the USDC debt
    /// under the very same USDC key the idle lend used, and the ledger only ever saw the idle leg. Redeeming the idle
    ///         leg nets the ledger to zero and leaves the LOAN legs untouched; repay + release then close the loan.
    function test_E2E_IdleUsdcLender_And_WethCollateralUsdcBorrower_KeyedApart() external {
        // 1. idle lend USDC
        _exec(address(lendHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, LEND, false));
        uint256 idleCredited = _supplied(USDC_RESERVE_ID);
        assertFalse(_flag(USDC_RESERVE_ID), "idle: never flagged");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), idleCredited, "ledger keyed by USDC key");
        assertEq(supplyOracle.getBalanceOfOwner(usdcKey, accountEth), idleCredited, "supply oracle == idle position");
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, accountEth), 0, "no debt yet under the USDC key");

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

        // per-key identities: the SAME USDC key carries the idle supply (supply oracle) and the debt (debt oracle)
        assertEq(supplyOracle.getBalanceOfOwner(usdcKey, accountEth), idleCredited, "idle USDC untouched by the borrow");
        assertApproxEqAbs(debtOracle.getBalanceOfOwner(usdcKey, accountEth), BORROW, 1, "debt under the USDC key");
        assertApproxEqAbs(supplyOracle.getBalanceOfOwner(wethKey, accountEth), PLEDGE, 2, "pledged WETH under WETH key");
        assertEq(debtOracle.getBalanceOfOwner(wethKey, accountEth), 0, "no WETH debt");
        // the ledger never saw the LOAN legs
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), idleCredited, "ledger: idle leg only");
        assertEq(superLedger.usersAccumulatorShares(accountEth, wethKey), 0, "ledger: no LOAN entry");

        // 3. redeem the idle leg fully: ledger nets to zero; LOAN legs untouched
        _exec(address(redeemHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, type(uint256).max, false));
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "ledger nets to zero");
        assertEq(_supplied(USDC_RESERVE_ID), 0, "idle USDC gone");
        assertApproxEqAbs(_debt(USDC_RESERVE_ID), BORROW, 1, "debt untouched by the idle redeem");
        assertApproxEqAbs(_supplied(WETH_RESERVE_ID), PLEDGE, 2, "collateral untouched by the idle redeem");

        // 4. close the loan: repay(max) + release(max)
        _exec(address(repayHook), _repay(type(uint256).max, false));
        _exec(address(releaseHook), _release(type(uint256).max));
        assertEq(_debt(USDC_RESERVE_ID), 0);
        assertEq(_supplied(WETH_RESERVE_ID), 0);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, accountEth), 0);
        assertEq(supplyOracle.getBalanceOfOwner(wethKey, accountEth), 0);
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
            _loanData(CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, USDC_RESERVE_ID, 100e6, 0, false);
        bytes memory openUsdc = _loanData(
            CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, USDC_RESERVE_ID, 100e6, 0.01 ether, false
        );
        bytes memory releaseUsdc = _loanData(
            CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, USDC_RESERVE_ID, type(uint256).max, 0, false
        );
        _execExpectFailure(address(pledgeHook), pledgeUsdc, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _execExpectFailure(address(openHook), openUsdc, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _execExpectFailure(address(releaseHook), releaseUsdc, bytes4(keccak256("RESERVE_NOT_COLLATERAL()")));
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), _supplied(USDC_RESERVE_ID), "idle intact");
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
        bytes memory openUsdcCollateral = _loanData(
            CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, USDC_RESERVE_ID, 1000e6, 0.05 ether, false
        );
        _execExpectFailure(
            address(openHook), openUsdcCollateral, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector
        );
        assertFalse(_flag(USDC_RESERVE_ID), "flag untouched");
        assertEq(_debt(WETH_RESERVE_ID), 0, "no WETH debt");

        _exec(address(redeemHook), _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, type(uint256).max, false));
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "idle leg netted");

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        _exec(address(openHook), openUsdcCollateral);
        assertTrue(_flag(USDC_RESERVE_ID), "USDC now LOAN-mode collateral");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth) - wethBefore, 0.05 ether, "WETH borrowed exactly");
        assertApproxEqAbs(debtOracle.getBalanceOfOwner(wethKey, accountEth), 0.05 ether, 1, "WETH debt under WETH key");
        assertApproxEqAbs(
            supplyOracle.getBalanceOfOwner(usdcKey, accountEth), 1000e6, 2, "USDC collateral under USDC key"
        );
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "LOAN leg never reaches the ledger");
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
        datas[1] = _loanData(
            CHAIN_1_WETH, CHAIN_1_USDC, USDC_RESERVE_ID, WETH_RESERVE_ID, USDC_RESERVE_ID, 1000e6, 0.05 ether, false
        );
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _execHooksExpectFailure(hooks, datas, BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore, "lend rolled back");
        assertEq(_supplied(USDC_RESERVE_ID), 0, "no position");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "ledger saw nothing");
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
