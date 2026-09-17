// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { BaseLedger } from "../../../src/accounting/BaseLedger.sol";
import { MorphoBlueMarketRegistry } from "../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { MorphoBlueYieldSourceOracle } from "../../../src/accounting/oracles/MorphoBlueYieldSourceOracle.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
// V1 lender hooks (MONEY_MARKET: INFLOW / OUTFLOW)
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { BaseMorphoMoneyMarketHook } from "../../../src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol";
// V2 borrower hooks (LOAN: NONACCOUNTING)
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";

/// @title MorphoHeaderIdentityE2E
/// @notice End-to-end proof on a real Ethereum-mainnet fork, through the real ERC-4337
///         SuperExecutor + paymaster against the ONE real Morpho Blue singleton, on TWO distinct real
///         markets sharing that Morpho (WBTC/USDC and wstETH/WETH). No mocks.
///
///         SUP-21038: the standardized 52-byte header (oracleId at offset 0 + Morpho at offset 32)
///         drives both the V1 lender hooks and the V2 borrower hooks; real on-chain state is asserted.
///
///         SUP-21024: the lender hooks are MONEY_MARKET (lend = INFLOW, redeem = OUTFLOW). Their
///         header offset 32 is the registry MARKET KEY of the body MarketParams (the Morpho singleton
///         is fixed in the hook), so the unchanged executor posts SuperLedger per market and two
///         markets on the same Morpho keep DISTINCT cost basis and price-per-share; a header naming
///         another market fails closed in the hook, an unregistered market at accounting.
contract MorphoHeaderIdentityE2ETest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    // SuperLedger event signatures — asserted by scanning the userOp's returned logs (expectEmit binds
    // to the NEXT external call, which for a userOp is its construction, not its execution).
    bytes32 internal constant INFLOW_SIG = keccak256("AccountingInflow(address,address,address,uint256,uint256)");
    bytes32 internal constant OUTFLOW_SIG = keccak256("AccountingOutflow(address,address,address,uint256,uint256)");

    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    MorphoSupplyAndBorrowHookV2 internal openHook;
    MorphoRepayAndWithdrawHookV2 internal closeHook;
    MorphoSupplyHookV2 internal pledgeHook;
    MorphoWithdrawCollateralHookV2 internal releaseHook;
    MorphoBorrowHookV2 internal borrowHook;
    MorphoRepayHookV2 internal repayHook;
    ISuperNativePaymaster internal paymaster;

    // Money-market accounting stack (registry + Superform Morpho Blue YS oracle + ledger config)
    MorphoBlueMarketRegistry internal registry;
    MorphoBlueYieldSourceOracle internal morphoOracle;
    bytes32 internal morphoOracleId; // derived config id the header must carry at offset 0
    address internal feeRecipient;
    address internal keyA; // registry market key (accounting key) for market A
    address internal keyB; // registry market key (accounting key) for market B

    uint256 internal constant MAX = type(uint256).max;
    uint256 internal constant FEE_BPS = 100; // 1% of realized profit

    // Market A — WBTC/USDC (loan USDC 6dp, collateral WBTC 8dp)
    address internal aLoan; // USDC
    address internal aColl; // WBTC
    uint256 internal aLltv;
    Id internal aId;
    // Market B — wstETH/WETH (loan WETH 18dp, collateral wstETH 18dp) — distinct real market, same Morpho
    address internal constant B_ORACLE = 0x2a01EB9496094dA03c4E364Def50f5aD1280AD72;
    uint256 internal constant B_LLTV = 945_000_000_000_000_000; // 94.5%
    address internal bLoan; // WETH
    address internal bColl; // wstETH
    Id internal bId;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        aLoan = CHAIN_1_USDC;
        aColl = CHAIN_1_WBTC;
        aLltv = 860_000_000_000_000_000; // 86%
        aId = _params(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv).id();

        bLoan = CHAIN_1_WETH;
        bColl = CHAIN_1_WST_ETH;
        bId = _params(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV).id();

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        openHook = new MorphoSupplyAndBorrowHookV2(MORPHO);
        closeHook = new MorphoRepayAndWithdrawHookV2(MORPHO);
        pledgeHook = new MorphoSupplyHookV2(MORPHO);
        releaseHook = new MorphoWithdrawCollateralHookV2(MORPHO);
        borrowHook = new MorphoBorrowHookV2(MORPHO);
        repayHook = new MorphoRepayHookV2(MORPHO);
        paymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        // Both markets must be live on the fork (not just well-formed parameter tuples)
        _assertMarketExists(aId);
        _assertMarketExists(bId);
        _setUpMoneyMarketAccounting();
    }

    /// @dev Registers both real markets (same Morpho, same shared IRM) and wires the Superform
    ///      Morpho Blue YS oracle into SuperLedgerConfiguration. The id the header must carry at
    ///      offset 0 is the DERIVED config id `keccak256(salt, configSetter)`, not the raw salt.
    function _setUpMoneyMarketAccounting() internal {
        registry = new MorphoBlueMarketRegistry(address(this));
        registry.setIrmApproval(MORPHO_IRM_WBTC_USDC, true);
        keyA = registry.registerMarket(MORPHO, aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv);
        keyB = registry.registerMarket(MORPHO, bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV);

        morphoOracle = new MorphoBlueYieldSourceOracle(address(ledgerConfig), address(registry));
        feeRecipient = makeAddr("feeRecipient");

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = MORPHO_YS_ORACLE_ID;
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(morphoOracle),
            feePercent: FEE_BPS,
            feeRecipient: feeRecipient,
            ledger: address(ledger)
        });
        ledgerConfig.setYieldSourceOracles(salts, configs);
        morphoOracleId = _getYieldSourceOracleId(MORPHO_YS_ORACLE_ID, address(this));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                       V1 LENDER: lend -> withdraw (both markets)
    //////////////////////////////////////////////////////////////*/

    function test_E2E_V1_LendWithdraw_MarketA_WbtcUsdc() external {
        _lendWithdrawCycle(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, aId, 10_000e6);
    }

    function test_E2E_V1_LendWithdraw_MarketB_WstethWeth() external {
        _lendWithdrawCycle(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, bId, 1e18);
    }

    function _lendWithdrawCycle(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        Id id,
        uint256 lendAmount
    )
        internal
    {
        _getTokens(loan, accountEth, lendAmount);
        uint256 loanBefore = IERC20(loan).balanceOf(accountEth);

        // LEND: supply the loan token
        _execSingle(address(lendHook), _lend(loan, coll, oracle, irm, lltv, lendAmount));

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(id, accountEth);
        assertGt(supplyShares, 0, "lend: supply shares created");
        assertEq(loanBefore - IERC20(loan).balanceOf(accountEth), lendAmount, "lend: exact loan token supplied");

        // WITHDRAW: redeem all supply shares back to the loan token
        _execSingle(address(withdrawHook), _withdrawShares(loan, coll, oracle, irm, lltv, supplyShares));

        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(id, accountEth);
        assertEq(supplySharesAfter, 0, "withdraw: all supply shares redeemed");
        // Withdraw is OUTFLOW: the executor charges FEE_BPS of realized P&L. Even with no accrual the
        // ledger's cost basis (shares * pps / 10^decimals, pps truncated at ~1e-6 relative) reads a
        // <=1e-8 phantom gain, so the principal comes back net of a dust fee (tens of wei on 10k USDC).
        assertApproxEqRel(
            IERC20(loan).balanceOf(accountEth), loanBefore, 1e12, "withdraw: principal returned net of dust fee"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     V2 BORROWER: pledge -> release (both markets)
    //////////////////////////////////////////////////////////////*/

    function test_E2E_V2_PledgeRelease_MarketA_WbtcUsdc() external {
        _pledgeReleaseCycle(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, aId, 1_000_000);
    }

    function test_E2E_V2_PledgeRelease_MarketB_WstethWeth() external {
        _pledgeReleaseCycle(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, bId, 1e18);
    }

    function _pledgeReleaseCycle(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        Id id,
        uint256 collAmount
    )
        internal
    {
        _getTokens(coll, accountEth, collAmount);
        uint256 collBefore = IERC20(coll).balanceOf(accountEth);

        // PLEDGE: supply collateral (standalone)
        _execSingle(address(pledgeHook), _v2(loan, coll, oracle, irm, lltv, collAmount, 0));

        (,, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(id, accountEth);
        assertEq(uint256(collateral), collAmount, "pledge: collateral position == supplied");
        assertEq(collBefore - IERC20(coll).balanceOf(accountEth), collAmount, "pledge: exact collateral spent");

        // RELEASE: withdraw the full collateral via the max sentinel
        _execSingle(address(releaseHook), _v2(loan, coll, oracle, irm, lltv, MAX, 0));

        (,, uint128 collateralAfter) = IMorphoStaticTyping(MORPHO).position(id, accountEth);
        assertEq(uint256(collateralAfter), 0, "release: collateral fully withdrawn");
        assertEq(IERC20(coll).balanceOf(accountEth), collBefore, "release: collateral returned in full");
    }

    /*//////////////////////////////////////////////////////////////
             V2 BORROWER FULL LIFECYCLE: open -> close (borrow-liquid market A)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full borrow lifecycle on the real WBTC/USDC market: open (supply collateral + borrow)
    ///         then close (repay all + withdraw all via max sentinels), asserting real debt/collateral.
    function test_E2E_V2_OpenClose_MarketA_WbtcUsdc() external {
        uint256 collAmount = 1_000_000; // 0.01 WBTC
        uint256 borrowAmount = 400e6; // 400 USDC — well under the 86% LTV cap
        _getTokens(aColl, accountEth, collAmount);

        uint256 loanBefore = IERC20(aLoan).balanceOf(accountEth);

        // OPEN
        _execSingle(
            address(openHook),
            _v2(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, collAmount, borrowAmount)
        );

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        assertEq(uint256(collateral), collAmount, "open: collateral supplied");
        assertGt(uint256(borrowShares), 0, "open: debt created");
        assertEq(IERC20(aLoan).balanceOf(accountEth) - loanBefore, borrowAmount, "open: exact borrow received");

        // CLOSE (repay all + withdraw all). _getTokens uses deal() (sets, not adds), so preserve the
        // borrowed balance and add a small buffer for any accrued interest.
        _getTokens(aLoan, accountEth, IERC20(aLoan).balanceOf(accountEth) + 10e6);
        _execSingle(
            address(closeHook), _v2(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, MAX, MAX)
        );

        (, uint128 borrowSharesAfter, uint128 collateralAfter) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        assertEq(uint256(borrowSharesAfter), 0, "close: debt fully repaid");
        assertEq(uint256(collateralAfter), 0, "close: collateral fully withdrawn");
    }

    /*//////////////////////////////////////////////////////////////
        V2 DEBT LIFECYCLE ON BOTH MARKETS: open -> borrow -> repay -> close, isolated per market
    //////////////////////////////////////////////////////////////*/

    struct Mkt {
        address loan;
        address coll;
        address oracle;
        address irm;
        uint256 lltv;
        Id id;
        uint256 collAmount;
        uint256 borrowAmount; // open leg
        uint256 extraBorrow; // standalone BORROW leg
        uint256 partialRepay; // standalone REPAY cap
    }

    function _mktA() internal view returns (Mkt memory) {
        return
            Mkt(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, aId, 1_000_000, 400e6, 100e6, 50e6);
    }

    function _mktB() internal view returns (Mkt memory) {
        return Mkt(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, bId, 1e18, 0.3e18, 0.1e18, 0.05e18);
    }

    /// @notice Every debt-bearing op executed for real on the SECOND market (wstETH/WETH), with the
    ///         first market's position provably untouched throughout.
    function test_E2E_V2_DebtLifecycle_MarketB_IsolatedFromA() external {
        _debtLifecycleIsolated(_mktB(), _mktA());
    }

    /// @notice Same lifecycle on the first market, isolated from the second.
    function test_E2E_V2_DebtLifecycle_MarketA_IsolatedFromB() external {
        _debtLifecycleIsolated(_mktA(), _mktB());
    }

    /// @dev open (pledge+borrow) -> standalone borrow -> standalone partial repay -> close (repay
    ///      all + withdraw all), asserting real provider state on `m` and no change on `other`.
    function _debtLifecycleIsolated(Mkt memory m, Mkt memory other) internal {
        // Give `other` a real position too, so "unchanged" is a meaningful assertion
        _getTokens(other.coll, accountEth, other.collAmount);
        _execSingle(address(openHook), _v2m(other, other.collAmount, other.borrowAmount));
        (uint256 oS, uint128 oB, uint128 oC) = IMorphoStaticTyping(MORPHO).position(other.id, accountEth);
        assertGt(uint256(oB), 0, "other: seeded debt");

        _getTokens(m.coll, accountEth, m.collAmount);
        uint256 loanBefore = IERC20(m.loan).balanceOf(accountEth);

        // OPEN
        _execSingle(address(openHook), _v2m(m, m.collAmount, m.borrowAmount));
        (, uint128 sharesOpen, uint128 coll) = IMorphoStaticTyping(MORPHO).position(m.id, accountEth);
        assertEq(uint256(coll), m.collAmount, "open: collateral");
        assertGt(uint256(sharesOpen), 0, "open: debt");
        assertEq(IERC20(m.loan).balanceOf(accountEth) - loanBefore, m.borrowAmount, "open: exact borrow");

        // BORROW (standalone)
        _execSingle(address(borrowHook), _v2m(m, m.extraBorrow, 0));
        (, uint128 sharesBorrow,) = IMorphoStaticTyping(MORPHO).position(m.id, accountEth);
        assertGt(uint256(sharesBorrow), uint256(sharesOpen), "borrow: debt increased");
        assertEq(IERC20(m.loan).balanceOf(accountEth) - loanBefore, m.borrowAmount + m.extraBorrow, "borrow: exact");

        // REPAY (standalone, partial cap)
        _execSingle(address(repayHook), _v2m(m, m.partialRepay, 0));
        (, uint128 sharesRepay,) = IMorphoStaticTyping(MORPHO).position(m.id, accountEth);
        assertLt(uint256(sharesRepay), uint256(sharesBorrow), "repay: debt reduced");
        assertGt(uint256(sharesRepay), 0, "repay: residual debt");
        assertEq(
            IERC20(m.loan).balanceOf(accountEth) - loanBefore,
            m.borrowAmount + m.extraBorrow - m.partialRepay,
            "repay: exact"
        );

        // CLOSE (repay all + withdraw all) — keep the borrowed balance, add an interest buffer
        _getTokens(m.loan, accountEth, IERC20(m.loan).balanceOf(accountEth) + m.partialRepay);
        _execSingle(address(closeHook), _v2m(m, MAX, MAX));
        (, uint128 sharesClose, uint128 collClose) = IMorphoStaticTyping(MORPHO).position(m.id, accountEth);
        assertEq(uint256(sharesClose), 0, "close: debt cleared");
        assertEq(uint256(collClose), 0, "close: collateral withdrawn");

        // ISOLATION: the other market's position is byte-for-byte unchanged
        (uint256 oS2, uint128 oB2, uint128 oC2) = IMorphoStaticTyping(MORPHO).position(other.id, accountEth);
        assertEq(oS2, oS, "other: supply shares unchanged");
        assertEq(uint256(oB2), uint256(oB), "other: borrow shares unchanged");
        assertEq(uint256(oC2), uint256(oC), "other: collateral unchanged");
    }

    function _assertMarketExists(Id id) internal view {
        (,,,, uint128 lastUpdate,) = IMorphoStaticTyping(MORPHO).market(id);
        assertGt(uint256(lastUpdate), 0, "market must exist on the fork");
    }

    function _v2m(Mkt memory m, uint256 a1, uint256 a2) internal pure returns (bytes memory) {
        return _v2(m.loan, m.coll, m.oracle, m.irm, m.lltv, a1, a2);
    }

    /*//////////////////////////////////////////////////////////////
        SUP-21024: MONEY_MARKET ACCOUNTING — INFLOW/OUTFLOW keyed per market
    //////////////////////////////////////////////////////////////*/

    /// @notice Lend posts an INFLOW keyed by the market key (never by the Morpho singleton), and the
    ///         ledger accumulators reflect the real supply-share position.
    function test_E2E_Lend_PostsInflow_KeyedByMarketKey() external {
        uint256 lendAmount = 10_000e6;
        _getTokens(aLoan, accountEth, lendAmount);

        // Header offset 32 is the market key the hook derives from the body — identical to the
        // registry's — never the singleton.
        assertEq(
            _key(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv), keyA, "header key == registry key"
        );
        assertTrue(keyA != MORPHO, "market key is never the Morpho singleton");

        ExecutionReturnData memory ret = _execSingleReturn(address(lendHook), _lendA(lendAmount));
        assertTrue(_hasLedgerEvent(ret.logs, INFLOW_SIG, keyA), "AccountingInflow emitted, keyed by the market key");
        assertFalse(_hasLedgerEvent(ret.logs, INFLOW_SIG, MORPHO), "never keyed by the Morpho singleton");

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        BaseLedger l = BaseLedger(address(ledger));
        assertEq(l.usersAccumulatorShares(accountEth, keyA), supplyShares, "accumulator shares == position");
        assertApproxEqRel(l.usersAccumulatorCostBasis(accountEth, keyA), lendAmount, 1e15, "cost basis ~= assets lent");
        assertEq(l.usersAccumulatorShares(accountEth, MORPHO), 0, "singleton never keyed");
    }

    /// @notice Two markets on the same Morpho keep DISTINCT accounting: different keys, per-market
    ///         accumulators, per-market oracle decimals/PPS; withdrawing one leaves the other intact.
    function test_E2E_TwoMarkets_DistinctCostBasis_AndPps() external {
        uint256 amtA = 10_000e6; // USDC
        uint256 amtB = 1e18; // WETH
        _getTokens(aLoan, accountEth, amtA);
        _getTokens(bLoan, accountEth, amtB);

        assertTrue(keyA != keyB, "distinct market keys");
        _execSingle(address(lendHook), _lendA(amtA));
        _execSingle(address(lendHook), _lend(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, amtB));

        (uint256 sharesA,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        (uint256 sharesB,,) = IMorphoStaticTyping(MORPHO).position(bId, accountEth);
        BaseLedger l = BaseLedger(address(ledger));
        assertEq(l.usersAccumulatorShares(accountEth, keyA), sharesA, "A accumulator == A position");
        assertEq(l.usersAccumulatorShares(accountEth, keyB), sharesB, "B accumulator == B position");
        assertApproxEqRel(l.usersAccumulatorCostBasis(accountEth, keyA), amtA, 1e15, "A cost basis in USDC");
        assertApproxEqRel(l.usersAccumulatorCostBasis(accountEth, keyB), amtB, 1e15, "B cost basis in WETH");

        // Per-market oracle identity: decimals = loanDecimals + 6, PPS differ
        assertEq(morphoOracle.decimals(keyA), 12, "USDC market: 6 + 6");
        assertEq(morphoOracle.decimals(keyB), 24, "WETH market: 18 + 6");
        assertTrue(morphoOracle.getPricePerShare(keyA) != morphoOracle.getPricePerShare(keyB), "distinct PPS");

        // Withdraw all of A: A accumulators clear, B untouched
        _execSingle(
            address(withdrawHook),
            _withdrawShares(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, sharesA)
        );
        assertEq(l.usersAccumulatorShares(accountEth, keyA), 0, "A cleared");
        assertEq(l.usersAccumulatorCostBasis(accountEth, keyA), 0, "A cost basis cleared");
        assertEq(l.usersAccumulatorShares(accountEth, keyB), sharesB, "B untouched");
    }

    /// @notice Withdraw posts an OUTFLOW keyed by the market key; after 30 days of accrual the
    ///         realized profit is fee'd (1%) in the loan token by the executor, paid to feeRecipient.
    function test_E2E_Withdraw_PostsOutflow_UsedShares_AndFee() external {
        uint256 lendAmount = 10_000e6;
        _getTokens(aLoan, accountEth, lendAmount);
        _execSingle(address(lendHook), _lendA(lendAmount));
        (uint256 shares,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);

        vm.warp(block.timestamp + 30 days);

        uint256 feeBefore = IERC20(aLoan).balanceOf(feeRecipient);
        ExecutionReturnData memory ret = _execSingleReturn(
            address(withdrawHook),
            _withdrawShares(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, shares)
        );
        assertTrue(_hasLedgerEvent(ret.logs, OUTFLOW_SIG, keyA), "AccountingOutflow emitted, keyed by the market key");

        BaseLedger l = BaseLedger(address(ledger));
        assertEq(l.usersAccumulatorShares(accountEth, keyA), 0, "all shares consumed");
        assertGt(IERC20(aLoan).balanceOf(feeRecipient), feeBefore, "profit fee paid in loan token");
        assertGt(IERC20(aLoan).balanceOf(accountEth), lendAmount, "account still nets a profit after fee");
    }

    /// @notice Partial withdraw by ASSETS (no accrual): usedShares = shares actually burned (position
    ///         diff) reduces the accumulator exactly. With no accrual the only "profit" is the ledger's
    ///         pps-truncation rounding, so any fee is dust (<= 1e-5 of principal by a wide margin).
    function test_E2E_PartialWithdrawByAssets_UsedSharesIsPositionDiff_DustFeeOnly() external {
        uint256 lendAmount = 10_000e6;
        _getTokens(aLoan, accountEth, lendAmount);
        _execSingle(address(lendHook), _lendA(lendAmount));
        (uint256 sharesBefore,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);

        uint256 feeBefore = IERC20(aLoan).balanceOf(feeRecipient);
        _execSingle(
            address(withdrawHook),
            _withdrawAssets(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, lendAmount / 2)
        );

        (uint256 sharesAfter,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        BaseLedger l = BaseLedger(address(ledger));
        assertEq(l.usersAccumulatorShares(accountEth, keyA), sharesAfter, "accumulator reduced by burned shares");
        assertGt(sharesBefore, sharesAfter, "shares burned");
        assertLt(
            IERC20(aLoan).balanceOf(feeRecipient) - feeBefore,
            lendAmount / 1e5,
            "no accrual => at most a rounding-dust fee"
        );
    }

    /// @notice Fail-closed allowlist: a market not registered in MorphoBlueMarketRegistry reverts at
    ///         accounting (MARKET_NOT_REGISTERED) — the lend cannot execute through the executor.
    function test_E2E_Lend_RevertIf_MarketNotRegistered() external {
        registry.proposeDeregisterMarket(keyB);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() + 1);
        registry.executeDeregisterMarket(keyB);
        assertFalse(registry.isRegistered(keyB), "B deregistered");

        _getTokens(bLoan, accountEth, 1e18);
        _execSingleExpectRevert(
            address(lendHook),
            _lend(bLoan, bColl, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, 1e18),
            MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector
        );
        (uint256 sharesB,,) = IMorphoStaticTyping(MORPHO).position(bId, accountEth);
        assertEq(sharesB, 0, "nothing supplied");
    }

    /// @notice A header carrying ANOTHER market's key (here market B's, on a market-A body) fails
    ///         closed in the hook itself — before any Morpho call or ledger posting.
    function test_E2E_Lend_RevertIf_HeaderKeyIsAnotherMarket() external {
        _getTokens(aLoan, accountEth, 1000e6);
        _execSingleExpectRevert(
            address(lendHook),
            abi.encodePacked(
                morphoOracleId,
                keyB,
                aLoan,
                aColl,
                MORPHO_ORACLE_WBTC_USDC,
                MORPHO_IRM_WBTC_USDC,
                uint256(1000e6),
                aLltv,
                false
            ),
            BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector
        );
        (uint256 sharesA,,) = IMorphoStaticTyping(MORPHO).position(aId, accountEth);
        assertEq(sharesA, 0, "nothing supplied");
        assertEq(BaseLedger(address(ledger)).usersAccumulatorShares(accountEth, keyB), 0, "nothing posted");
    }

    /// @notice The V2 LOAN hooks stay NONACCOUNTING even on a registered market: no ledger posting.
    function test_E2E_LoanHooks_StayNonAccounting() external {
        _pledgeReleaseCycle(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, aId, 1_000_000);

        BaseLedger l = BaseLedger(address(ledger));
        assertEq(l.usersAccumulatorShares(accountEth, keyA), 0, "no accounting for LOAN ops");
        assertEq(l.usersAccumulatorShares(accountEth, MORPHO), 0, "singleton never keyed");
    }

    /*//////////////////////////////////////////////////////////////
                              EXEC HELPERS
    //////////////////////////////////////////////////////////////*/

    function _entry(address hook, bytes memory data) internal pure returns (ISuperExecutor.ExecutorEntry memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
    }

    function _execSingle(address hook, bytes memory data) internal {
        _execSingleReturn(hook, data);
    }

    function _execSingleReturn(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(_entry(hook, data)));
        return executeOpsThroughPaymaster(userOpData, paymaster, 1e18);
    }

    /// @dev True if the ledger emitted `sig` for (accountEth, morphoOracle, yieldSource) in these logs
    function _hasLedgerEvent(VmSafe.Log[] memory logs, bytes32 sig, address yieldSource) internal view returns (bool) {
        for (uint256 i; i < logs.length; ++i) {
            VmSafe.Log memory l = logs[i];
            if (
                l.emitter == address(ledger) && l.topics.length == 4 && l.topics[0] == sig
                    && l.topics[1] == bytes32(uint256(uint160(accountEth)))
                    && l.topics[2] == bytes32(uint256(uint160(address(morphoOracle))))
                    && l.topics[3] == bytes32(uint256(uint160(yieldSource)))
            ) return true;
        }
        return false;
    }

    /// @dev Executes and asserts the account-level execution reverted with the expected custom
    ///      error (the EntryPoint swallows it and emits UserOperationRevertReason).
    function _execSingleExpectRevert(address hook, bytes memory data, bytes4 expectedSelector) internal {
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(_entry(hook, data)));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, paymaster, 1e18);

        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory logEntry = ret.logs[i];
            if (
                logEntry.topics.length > 0 && logEntry.topics[0] == revertTopic
                    && _contains(logEntry.data, expectedSelector)
            ) {
                found = true;
                break;
            }
        }
        assertTrue(found, "expected UserOperationRevertReason carrying the error selector");
    }

    function _contains(bytes memory haystack, bytes4 needle) internal pure returns (bool) {
        if (haystack.length < 4) return false;
        for (uint256 i; i + 4 <= haystack.length; ++i) {
            if (
                bytes4(
                        (bytes32(haystack[i]) >> 0) | (bytes32(haystack[i + 1]) >> 8) | (bytes32(haystack[i + 2]) >> 16)
                            | (bytes32(haystack[i + 3]) >> 24)
                    ) == needle
            ) return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _params(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (MarketParams memory)
    {
        return MarketParams({ loanToken: loan, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv });
    }

    function _lendA(uint256 amount) internal view returns (bytes memory) {
        return _lend(aLoan, aColl, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, aLltv, amount);
    }

    /// @dev Lender hooks are INFLOW/OUTFLOW: the executor looks the header oracle id up, so it must
    ///      be the DERIVED config id (morphoOracleId), and offset 32 the registry MARKET KEY of the
    ///      body MarketParams (the executor posts SuperLedger against it; the Morpho singleton is
    ///      fixed in the hook).
    function _lend(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 amount
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            morphoOracleId, _key(loan, coll, oracle, irm, lltv), loan, coll, oracle, irm, amount, lltv, false
        );
    }

    function _withdrawShares(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 shares
    )
        internal
        view
        returns (bytes memory)
    {
        // withdraw layout: header + market + lltv at 132 + assets at 164 (0) + shares at 196
        return abi.encodePacked(
            morphoOracleId, _key(loan, coll, oracle, irm, lltv), loan, coll, oracle, irm, lltv, uint256(0), shares
        );
    }

    function _withdrawAssets(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 assets
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            morphoOracleId, _key(loan, coll, oracle, irm, lltv), loan, coll, oracle, irm, lltv, assets, uint256(0)
        );
    }

    /// @dev Registry market key of a market == MorphoBlueMarketRegistry.computeMarketKey
    function _key(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(Id.unwrap(_params(loan, coll, oracle, irm, lltv).id()))));
    }

    /// @dev V2 LOAN hooks are NONACCOUNTING: the executor never looks the oracle id up, so the raw
    ///      salt constant is fine here (it only needs to be nonzero for the hook's own checks).
    function _v2(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 a1,
        uint256 a2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, MORPHO, loan, coll, oracle, irm, a1, a2, false, lltv, uint8(0));
    }
}
