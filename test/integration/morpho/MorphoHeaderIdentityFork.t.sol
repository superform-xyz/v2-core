// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoBase, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// Superform
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
// V1 leaves — lender ops + the (freeze-lifted) borrower ops, all header-aware
import { BaseMorphoLoanHook } from "../../../src/hooks/loan/morpho/BaseMorphoLoanHook.sol";
import { BaseMorphoMoneyMarketHook } from "../../../src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
// V2 base + leaves (six borrower ops)
import { BaseMorphoLoanHookV2 } from "../../../src/hooks/loan/morpho/BaseMorphoLoanHookV2.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";

/// @title MorphoHeaderIdentityFork
/// @notice SUP-21038 acceptance on a real Ethereum-mainnet fork: the 52-byte header identity holds
///         across EVERY Morpho hook for TWO real markets (both verified to exist on the fork) that
///         share the ONE real Morpho Blue singleton but differ in loan/collateral/oracle/lltv
///         (body = MarketParams filter only). For each (market, op) it asserts:
///         (a) header yieldSource (offset 32): the real Morpho singleton for the LOAN hooks (a wrong
///             Morpho reverts YIELD_SOURCE_MISMATCH); the registry MARKET KEY of the body MarketParams
///             for the MONEY_MARKET lend/withdraw hooks (a wrong key reverts MARKET_KEY_MISMATCH),
///             whose call target is the singleton fixed in the hook;
///         (b) every Morpho call and approve spender in build() targets the header Morpho — for ALL
///             eight ops, including the debt-bearing REPAY / CLOSE paths, which read a real seeded
///             borrow position for the test account on each market;
///         (c) inspect() == abi.encodePacked(Morpho, loan, collateral, oracle, irm, lltv).
///         The V1 borrower leaves are covered by the same matrix (their header freeze was lifted).
/// @dev Full end-to-end execution through the ERC-4337 executor lives in MorphoHeaderIdentityE2E.
contract MorphoHeaderIdentityForkTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    struct Mkt {
        address loan;
        address coll;
        address oracle;
        address irm;
        uint256 lltv;
        uint256 collSeed; // collateral seeded for the test account (debt-path builds)
        uint256 borrowSeed; // debt seeded for the test account
    }

    // Lender ops (V1)
    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    // V1 borrower ops (freeze lifted)
    MorphoSupplyHook internal v1PledgeHook;
    MorphoBorrowHook internal v1BorrowHook;
    MorphoRepayHook internal v1RepayHook;
    MorphoRepayAndWithdrawHook internal v1CloseHook;
    // V2 borrower ops
    MorphoSupplyAndBorrowHookV2 internal openHook;
    MorphoRepayHookV2 internal repayHook;
    MorphoRepayAndWithdrawHookV2 internal closeHook;
    MorphoSupplyHookV2 internal pledgeHook;
    MorphoBorrowHookV2 internal borrowHook;
    MorphoWithdrawCollateralHookV2 internal releaseHook;

    Mkt internal A; // WBTC/USDC
    Mkt internal B; // wstETH/WETH — a second real market on the same Morpho
    address internal constant B_ORACLE = 0x2a01EB9496094dA03c4E364Def50f5aD1280AD72;
    uint256 internal constant B_LLTV = 945_000_000_000_000_000; // 94.5%
    uint256 internal constant AMT = 1e6;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        A = Mkt(
            CHAIN_1_USDC,
            CHAIN_1_WBTC,
            MORPHO_ORACLE_WBTC_USDC,
            MORPHO_IRM_WBTC_USDC,
            860_000_000_000_000_000,
            1e6,
            100e6
        );
        B = Mkt(CHAIN_1_WETH, CHAIN_1_WST_ETH, B_ORACLE, MORPHO_IRM_WBTC_USDC, B_LLTV, 1e18, 0.2e18);

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        v1PledgeHook = new MorphoSupplyHook(MORPHO);
        v1BorrowHook = new MorphoBorrowHook(MORPHO);
        v1RepayHook = new MorphoRepayHook(MORPHO);
        v1CloseHook = new MorphoRepayAndWithdrawHook(MORPHO);
        openHook = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayHook = new MorphoRepayHookV2(MORPHO);
        closeHook = new MorphoRepayAndWithdrawHookV2(MORPHO);
        pledgeHook = new MorphoSupplyHookV2(MORPHO);
        borrowHook = new MorphoBorrowHookV2(MORPHO);
        releaseHook = new MorphoWithdrawCollateralHookV2(MORPHO);

        // Both markets must be live on the fork, and the test account holds real debt on each so
        // the debt-bearing builds (REPAY / CLOSE) resolve nonzero legs against real provider state.
        _assertMarketExists(A);
        _assertMarketExists(B);
        _seedDebt(A);
        _seedDebt(B);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              FIXTURES
    //////////////////////////////////////////////////////////////*/

    function _params(Mkt memory m) internal pure returns (MarketParams memory) {
        return MarketParams({ loanToken: m.loan, collateralToken: m.coll, oracle: m.oracle, irm: m.irm, lltv: m.lltv });
    }

    /// @dev Registry market key = MarketParams.id() truncated to an address (== computeMarketKey)
    function _key(Mkt memory m) internal pure returns (address) {
        return address(uint160(uint256(Id.unwrap(_params(m).id()))));
    }

    /// @dev == SuperVaultAggregator._createLeaf (v2-periphery)
    function _leaf(address hook, bytes memory args) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(hook, args))));
    }

    function _assertMarketExists(Mkt memory m) internal view {
        (,,,, uint128 lastUpdate,) = IMorphoStaticTyping(MORPHO).market(_params(m).id());
        assertGt(uint256(lastUpdate), 0, "market must exist on the fork");
    }

    /// @dev Real position for this test account: supply collateral, borrow the loan token.
    function _seedDebt(Mkt memory m) internal {
        _getTokens(m.coll, address(this), m.collSeed);
        IERC20(m.coll).approve(MORPHO, m.collSeed);
        IMorphoBase(MORPHO).supplyCollateral(_params(m), m.collSeed, address(this), "");
        IMorphoBase(MORPHO).borrow(_params(m), m.borrowSeed, 0, address(this), address(this));
        (, uint128 borrowShares,) = IMorphoStaticTyping(MORPHO).position(_params(m).id(), address(this));
        assertGt(uint256(borrowShares), 0, "seeded debt");
    }

    /*//////////////////////////////////////////////////////////////
                (c) INSPECT == Morpho + MarketParams, both markets, all 8 ops
    //////////////////////////////////////////////////////////////*/

    function test_Fork_TwoSharedMarkets_InspectIsMorphoPlusMarketParams() public view {
        _assertInspect(A);
        _assertInspect(B);
    }

    function _assertInspect(Mkt memory m) internal view {
        // ONE identity for the whole Morpho family: market key first, then the MarketParams filter
        bytes memory expected = abi.encodePacked(_key(m), m.loan, m.coll, m.oracle, m.irm, m.lltv);
        bytes memory singletonFirst = abi.encodePacked(MORPHO, m.loan, m.coll, m.oracle, m.irm, m.lltv);
        assertEq(lendHook.inspect(_lend(_key(m), m)), expected, "lend");
        assertEq(withdrawHook.inspect(_withdraw(_key(m), m)), expected, "withdraw");
        // SuperVaultAggregator leaf over the raw inspect bytes == leaf over the SUP-21025 encoding
        assertEq(_leaf(address(lendHook), lendHook.inspect(_lend(_key(m), m))), _leaf(address(lendHook), expected));
        assertTrue(
            _leaf(address(lendHook), expected) != _leaf(address(lendHook), singletonFirst), "singleton-first differs"
        );
        assertEq(v1PledgeHook.inspect(_v1Supply(_key(m), m)), expected, "v1 pledge");
        assertEq(v1BorrowHook.inspect(_v1Borrow(_key(m), m)), expected, "v1 borrow");
        assertEq(v1RepayHook.inspect(_v1Repay(_key(m), m)), expected, "v1 repay");
        assertEq(openHook.inspect(_v2(_key(m), m, AMT, AMT)), expected, "open");
        assertEq(repayHook.inspect(_v2(_key(m), m, AMT, 0)), expected, "repay");
        assertEq(closeHook.inspect(_v2(_key(m), m, AMT, AMT)), expected, "close");
        assertEq(pledgeHook.inspect(_v2(_key(m), m, AMT, 0)), expected, "pledge");
        assertEq(borrowHook.inspect(_v2(_key(m), m, AMT, 0)), expected, "borrow");
        assertEq(releaseHook.inspect(_v2(_key(m), m, AMT, 0)), expected, "release");
    }

    /*//////////////////////////////////////////////////////////////
          (b) every Morpho call / approve spender targets the header Morpho, all 8 ops
    //////////////////////////////////////////////////////////////*/

    function test_Fork_TwoSharedMarkets_AllOps_MorphoCallsTargetRealMorpho() public view {
        _assertTargets(A);
        _assertTargets(B);
    }

    function _assertTargets(Mkt memory m) internal view {
        address me = address(this);
        // lender ops
        _assertMorphoTargeted(lendHook.build(address(0), me, _lend(_key(m), m)), m, address(lendHook));
        _assertMorphoTargeted(withdrawHook.build(address(0), me, _withdraw(_key(m), m)), m, address(withdrawHook));
        // V1 borrower ops (repay resolves against the seeded debt)
        _assertMorphoTargeted(v1PledgeHook.build(address(0), me, _v1Supply(_key(m), m)), m, address(v1PledgeHook));
        _assertMorphoTargeted(v1BorrowHook.build(address(0), me, _v1Borrow(_key(m), m)), m, address(v1BorrowHook));
        _assertMorphoTargeted(v1RepayHook.build(address(0), me, _v1Repay(_key(m), m)), m, address(v1RepayHook));
        // V2 borrower ops — REPAY / CLOSE are non-empty because the account holds real debt
        _assertMorphoTargeted(openHook.build(address(0), me, _v2(_key(m), m, AMT, AMT)), m, address(openHook));
        _assertMorphoTargeted(repayHook.build(address(0), me, _v2(_key(m), m, AMT, 0)), m, address(repayHook));
        _assertMorphoTargeted(closeHook.build(address(0), me, _v2(_key(m), m, AMT, 1)), m, address(closeHook));
        _assertMorphoTargeted(pledgeHook.build(address(0), me, _v2(_key(m), m, AMT, 0)), m, address(pledgeHook));
        _assertMorphoTargeted(borrowHook.build(address(0), me, _v2(_key(m), m, AMT, 0)), m, address(borrowHook));
        _assertMorphoTargeted(releaseHook.build(address(0), me, _v2(_key(m), m, 1, 0)), m, address(releaseHook));
    }

    /// @dev Every execution that is not a token approve (loan/collateral target) nor a pre/postExecute
    ///      self-call must target the real Morpho singleton; approve spenders must be Morpho too.
    function _assertMorphoTargeted(Execution[] memory execs, Mkt memory m, address hook) internal pure {
        bool morphoSeen;
        for (uint256 i; i < execs.length; ++i) {
            address t = execs[i].target;
            if (t == m.loan || t == m.coll) {
                // approve(spender, amount): spender must be the header Morpho
                (address spender,) = abi.decode(_args(execs[i].callData), (address, uint256));
                assertEq(spender, MORPHO, "approve spender must be header Morpho");
            } else if (t != hook) {
                assertEq(t, MORPHO, "non-token call must target header Morpho");
                morphoSeen = true;
            }
        }
        assertTrue(morphoSeen, "at least one Morpho call expected");
    }

    function _args(bytes memory cd) internal pure returns (bytes memory out) {
        out = new bytes(cd.length - 4);
        for (uint256 i; i < out.length; ++i) {
            out[i] = cd[i + 4];
        }
    }

    /*//////////////////////////////////////////////////////////////
          Reentrancy invariant: every Morpho supply / repay carries EMPTY callback data
    //////////////////////////////////////////////////////////////*/

    /// @notice Morpho only invokes onMorphoSupply / onMorphoRepay when the trailing `data` is
    ///         non-empty. Every hook that can reach those entry points (lend + the V1 repay hooks,
    ///         against the real seeded debt on both markets) must pass "".
    function test_Fork_CallbackDataAlwaysEmpty_LendAndV1RepayHooks() public view {
        _assertCallbackEmpty(A);
        _assertCallbackEmpty(B);
    }

    function _assertCallbackEmpty(Mkt memory m) internal view {
        address me = address(this);
        _assertMorphoCallbackEmpty(
            lendHook.build(address(0), me, _lend(_key(m), m)), IMorphoBase.supply.selector, "lend"
        );
        _assertMorphoCallbackEmpty(
            v1RepayHook.build(address(0), me, _v1Repay(_key(m), m)), IMorphoBase.repay.selector, "v1 repay"
        );
        _assertMorphoCallbackEmpty(
            v1CloseHook.build(address(0), me, _v1Repay(_key(m), m)), IMorphoBase.repay.selector, "v1 close"
        );
    }

    /// @dev supply(MarketParams,uint256,uint256,address,bytes) and repay(...) share the same ABI shape
    function _assertMorphoCallbackEmpty(Execution[] memory execs, bytes4 selector, string memory label) internal pure {
        bool seen;
        for (uint256 i; i < execs.length; ++i) {
            if (execs[i].target != MORPHO || bytes4(execs[i].callData) != selector) continue;
            (,,,, bytes memory cb) =
                abi.decode(_args(execs[i].callData), (MarketParams, uint256, uint256, address, bytes));
            assertEq(cb.length, 0, string(abi.encodePacked(label, ": callback data must be empty")));
            seen = true;
        }
        assertTrue(seen, string(abi.encodePacked(label, ": Morpho call expected")));
    }

    /*//////////////////////////////////////////////////////////////
                   (a) wrong Morpho header reverts on every op
    //////////////////////////////////////////////////////////////*/

    function test_Fork_HeaderPointingAtWrongMorpho_Reverts_AllOps() public {
        address wrong = address(0xdEADbeEF00000000000000000000000000000001);
        address me = address(this);
        bytes4 mm = BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector;
        bytes4 v1 = BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector;
        bytes4 v2 = BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector;

        // MONEY_MARKET hooks: offset 32 must be THIS market's key — a foreign address, the Morpho
        // singleton itself, or the OTHER real market's key all fail closed
        vm.expectRevert(mm);
        lendHook.build(address(0), me, _lend(wrong, A));
        vm.expectRevert(mm);
        withdrawHook.build(address(0), me, _withdraw(wrong, B));
        vm.expectRevert(mm);
        lendHook.build(address(0), me, _lend(MORPHO, A));
        vm.expectRevert(mm);
        withdrawHook.build(address(0), me, _withdraw(MORPHO, B));
        vm.expectRevert(mm);
        lendHook.build(address(0), me, _lend(_key(B), A));
        vm.expectRevert(mm);
        withdrawHook.build(address(0), me, _withdraw(_key(A), B));
        // LOAN hooks: offset 32 must be the singleton
        vm.expectRevert(v1);
        v1PledgeHook.build(address(0), me, _v1Supply(wrong, A));
        vm.expectRevert(v1);
        v1BorrowHook.build(address(0), me, _v1Borrow(wrong, B));
        vm.expectRevert(v1);
        v1RepayHook.build(address(0), me, _v1Repay(wrong, A));
        vm.expectRevert(v2);
        openHook.build(address(0), me, _v2(wrong, A, AMT, AMT));
        vm.expectRevert(v2);
        repayHook.build(address(0), me, _v2(wrong, B, AMT, 0));
        vm.expectRevert(v2);
        closeHook.build(address(0), me, _v2(wrong, A, AMT, 1));
        vm.expectRevert(v2);
        pledgeHook.build(address(0), me, _v2(wrong, B, AMT, 0));
        vm.expectRevert(v2);
        borrowHook.build(address(0), me, _v2(wrong, A, AMT, 0));
        vm.expectRevert(v2);
        releaseHook.build(address(0), me, _v2(wrong, B, 1, 0));
    }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    // V1 lend (197): header (oracle id + MARKET KEY) + market + amount@132 + lltv@164 + usePrev@196
    function _lend(address ys, Mkt memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, m.loan, m.coll, m.oracle, m.irm, AMT, m.lltv, false);
    }

    // V1 withdraw (228): header (oracle id + MARKET KEY) + market + lltv@132 + assets@164 + shares@196
    function _withdraw(address ys, Mkt memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, m.loan, m.coll, m.oracle, m.irm, m.lltv, AMT, uint256(0));
    }

    // V1 supply-collateral (197): same shape as lend
    function _v1Supply(address ys, Mkt memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, m.loan, m.coll, m.oracle, m.irm, AMT, m.lltv, false);
    }

    // V1 borrow (230): header + market + amount@132 + ltvRatio@164 + usePrev@196 + lltv@197 + reserved
    function _v1Borrow(address ys, Mkt memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            ys,
            m.loan,
            m.coll,
            m.oracle,
            m.irm,
            AMT,
            uint256(500_000_000_000_000_000),
            false,
            m.lltv,
            false
        );
    }

    // V1 repay (198): header + market + amount@132 + lltv@164 + usePrev@196 + isFullRepayment@197
    function _v1Repay(address ys, Mkt memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, m.loan, m.coll, m.oracle, m.irm, AMT, m.lltv, false, false);
    }

    // V2 (230): header + market + amount1@132 + amount2@164 + usePrev@196 + lltv@197 + reserved
    function _v2(address ys, Mkt memory m, uint256 a1, uint256 a2) internal pure returns (bytes memory) {
        return
            abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, m.loan, m.coll, m.oracle, m.irm, a1, a2, false, m.lltv, uint8(0));
    }
}
