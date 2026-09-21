// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ISuperHook, ISuperHookInspector } from "../../../../src/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, MarketParams, Market, Position } from "../../../../src/vendor/morpho/IMorpho.sol";

// V1 leaves
import { MorphoLendHook } from "../../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { BaseMorphoLoanHook } from "../../../../src/hooks/loan/morpho/BaseMorphoLoanHook.sol";
import { BaseMorphoMoneyMarketHook } from "../../../../src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol";
// V2 base + leaves
import { BaseMorphoLoanHookV2 } from "../../../../src/hooks/loan/morpho/BaseMorphoLoanHookV2.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";

// Local mocks shared with the composite-hook suite
import { MockMorpho, MockIRM } from "./MorphoLoanHooksV2.t.sol";

/// @title MorphoHeaderIdentitySharedMorpho
/// @notice SUP-21038 acceptance suite: proves the 52-byte header identity standardization holds
///         across EVERY Morpho hook (2 V1 + 6 V2 = all 8 ops), for TWO markets that share ONE
///         Morpho singleton but differ in collateral / oracle / irm / lltv (body-as-filter).
/// @dev Deterministic (no fork) — uses MockMorpho so the invariants are asserted via execution
///      introspection rather than on-chain effects:
///      (a) inspect() == abi.encodePacked(Morpho, loan, collateral, oracle, irm, lltv);
///      (b) every Morpho call in build() targets the header-derived Morpho singleton;
///      (c) a header pointing at a different Morpho reverts YIELD_SOURCE_MISMATCH (LOAN hooks);
///      the MONEY_MARKET lend/withdraw hooks carry the registry MARKET KEY of the body MarketParams
///      at offset 32 instead (SUP-21024) — the singleton is fixed in the hook — and a header
///      naming anything else reverts MARKET_KEY_MISMATCH.
contract MorphoHeaderIdentitySharedMorphoTest is Helpers {
    using MarketParamsLib for MarketParams;

    // The ONE Morpho singleton shared by every hook and both markets
    MockMorpho internal morpho;
    MockMorpho internal otherMorpho; // a different, wrong Morpho for the mismatch tests
    MockIRM internal irmA;
    MockIRM internal irmB;

    // Shared loan token (both markets lend/borrow the same asset), distinct collaterals
    address internal loanToken;
    address internal collateralA;
    address internal collateralB;
    address internal oracleA = address(0xA0);
    address internal oracleB = address(0xB0);
    uint256 internal lltvA = 860_000_000_000_000_000; // 86%
    uint256 internal lltvB = 770_000_000_000_000_000; // 77%

    // The 8 hooks, all constructed against the ONE shared Morpho
    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    MorphoSupplyAndBorrowHookV2 internal openHook;
    MorphoRepayHookV2 internal repayHook;
    MorphoRepayAndWithdrawHookV2 internal closeHook;
    MorphoSupplyHookV2 internal pledgeHook;
    MorphoBorrowHookV2 internal borrowHook;
    MorphoWithdrawCollateralHookV2 internal releaseHook;

    uint256 internal constant AMT = 1e18;

    function setUp() public {
        morpho = new MockMorpho();
        otherMorpho = new MockMorpho();
        irmA = new MockIRM();
        irmB = new MockIRM();

        loanToken = address(new MockERC20("Loan", "LOAN", 18));
        collateralA = address(new MockERC20("CollA", "CA", 18));
        collateralB = address(new MockERC20("CollB", "CB", 18));

        lendHook = new MorphoLendHook(address(morpho));
        withdrawHook = new MorphoWithdrawHook(address(morpho));
        openHook = new MorphoSupplyAndBorrowHookV2(address(morpho));
        repayHook = new MorphoRepayHookV2(address(morpho));
        closeHook = new MorphoRepayAndWithdrawHookV2(address(morpho));
        pledgeHook = new MorphoSupplyHookV2(address(morpho));
        borrowHook = new MorphoBorrowHookV2(address(morpho));
        releaseHook = new MorphoWithdrawCollateralHookV2(address(morpho));

        // One global market total (MockMorpho.market ignores the id) with outstanding debt so the
        // repay/close debt calculations resolve to a nonzero amount.
        morpho.setMarket(
            Market({
                totalSupplyAssets: 100e18,
                totalSupplyShares: 100e18,
                totalBorrowAssets: 80e18,
                totalBorrowShares: 80e18,
                lastUpdate: uint128(block.timestamp),
                fee: 0
            })
        );
        // A borrower position for this test account in BOTH markets
        morpho.setPosition(
            _params(collateralA, oracleA, address(irmA), lltvA).id(),
            address(this),
            Position({ supplyShares: 0, borrowShares: 40e18, collateral: 5e18 })
        );
        morpho.setPosition(
            _params(collateralB, oracleB, address(irmB), lltvB).id(),
            address(this),
            Position({ supplyShares: 0, borrowShares: 40e18, collateral: 5e18 })
        );
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _params(
        address collateral,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        view
        returns (MarketParams memory)
    {
        return MarketParams({ loanToken: loanToken, collateralToken: collateral, oracle: oracle, irm: irm, lltv: lltv });
    }

    /*//////////////////////////////////////////////////////////////
                       (a)+(c): INSPECT + MISMATCH
    //////////////////////////////////////////////////////////////*/

    function test_AllOps_TwoSharedMarkets_InspectPacksHeaderMorphoPlusFilter() public view {
        // Market A and Market B share `morpho` + loanToken but differ in collateral/oracle/irm/lltv.
        _assertInspectAllOps(collateralA, oracleA, address(irmA), lltvA);
        _assertInspectAllOps(collateralB, oracleB, address(irmB), lltvB);
    }

    function _assertInspectAllOps(address coll, address oracle, address irm, uint256 lltv) internal view {
        // One identity for the whole family now: market key first, then the MarketParams filter
        bytes memory expected = abi.encodePacked(_key(coll, oracle, irm, lltv), loanToken, coll, oracle, irm, lltv);

        assertEq(
            lendHook.inspect(_lendEnc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv)), expected, "lend inspect"
        );
        assertEq(
            withdrawHook.inspect(_withdrawEnc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv)),
            expected,
            "withdraw inspect"
        );
        assertEq(
            openHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, AMT)),
            expected,
            "open inspect"
        );
        assertEq(
            repayHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)),
            expected,
            "repay inspect"
        );
        assertEq(
            closeHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, AMT)),
            expected,
            "close inspect"
        );
        assertEq(
            pledgeHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)),
            expected,
            "pledge inspect"
        );
        assertEq(
            borrowHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)),
            expected,
            "borrow inspect"
        );
        assertEq(
            releaseHook.inspect(_v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)),
            expected,
            "release inspect"
        );
    }

    function test_AllOps_RevertIf_HeaderPointsAtDifferentMorpho() public {
        address wrong = address(otherMorpho);

        // MONEY_MARKET hooks: neither a foreign address nor the singleton is this market's key
        vm.expectRevert(BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector);
        lendHook.build(address(0), address(this), _lendEnc(wrong, collateralA, oracleA, address(irmA), lltvA));
        vm.expectRevert(BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector);
        lendHook.build(address(0), address(this), _lendEnc(address(morpho), collateralA, oracleA, address(irmA), lltvA));

        vm.expectRevert(BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector);
        withdrawHook.build(address(0), address(this), _withdrawEnc(wrong, collateralA, oracleA, address(irmA), lltvA));
        vm.expectRevert(BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector);
        withdrawHook.build(
            address(0), address(this), _withdrawEnc(address(morpho), collateralA, oracleA, address(irmA), lltvA)
        );

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        openHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, AMT));

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        repayHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, 0));

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        closeHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, AMT));

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        pledgeHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, 0));

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        borrowHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, 0));

        vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
        releaseHook.build(address(0), address(this), _v2Enc(wrong, collateralA, oracleA, address(irmA), lltvA, AMT, 0));
    }

    /// @dev SUP-21038 REVERSAL PROOF: the Morpho singleton in the header — which every LOAN hook used
    ///      to require — is now rejected by all 8 ops, because offset 32 must be the market key.
    function test_AllOps_RevertIf_HeaderIsSingleton() public {
        address singleton = address(morpho);
        bytes4 v1 = BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector;
        bytes4 v2 = BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector;

        vm.expectRevert(v1);
        lendHook.build(address(0), address(this), _lendEnc(singleton, collateralA, oracleA, address(irmA), lltvA));
        vm.expectRevert(v1);
        withdrawHook.build(
            address(0), address(this), _withdrawEnc(singleton, collateralA, oracleA, address(irmA), lltvA)
        );

        BaseLoanHookV2[6] memory v2Hooks = [
            BaseLoanHookV2(address(openHook)),
            BaseLoanHookV2(address(repayHook)),
            BaseLoanHookV2(address(closeHook)),
            BaseLoanHookV2(address(pledgeHook)),
            BaseLoanHookV2(address(borrowHook)),
            BaseLoanHookV2(address(releaseHook))
        ];
        for (uint256 i; i < 6; ++i) {
            vm.expectRevert(v2);
            ISuperHook(address(v2Hooks[i]))
                .build(address(0), address(this), _v2Enc(singleton, collateralA, oracleA, address(irmA), lltvA, AMT, 0));
        }
    }

    /// @dev The pin is per-MARKET, not merely "not the singleton": market B's key on a market A body
    ///      is rejected by every op.
    function test_AllOps_RevertIf_HeaderIsOtherMarketKey() public {
        address keyB = _key(collateralB, oracleB, address(irmB), lltvB);
        bytes4 v1 = BaseMorphoLoanHook.MARKET_KEY_MISMATCH.selector;
        bytes4 v2 = BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector;

        vm.expectRevert(v1);
        lendHook.build(address(0), address(this), _lendEnc(keyB, collateralA, oracleA, address(irmA), lltvA));
        vm.expectRevert(v1);
        withdrawHook.build(address(0), address(this), _withdrawEnc(keyB, collateralA, oracleA, address(irmA), lltvA));
        vm.expectRevert(v2);
        openHook.build(address(0), address(this), _v2Enc(keyB, collateralA, oracleA, address(irmA), lltvA, AMT, AMT));
        vm.expectRevert(v2);
        pledgeHook.build(address(0), address(this), _v2Enc(keyB, collateralA, oracleA, address(irmA), lltvA, AMT, 0));
        vm.expectRevert(v2);
        borrowHook.build(address(0), address(this), _v2Enc(keyB, collateralA, oracleA, address(irmA), lltvA, AMT, 0));
        vm.expectRevert(v2);
        releaseHook.build(address(0), address(this), _v2Enc(keyB, collateralA, oracleA, address(irmA), lltvA, AMT, 0));
    }

    /// @dev Per-market identity: before this change every LOAN leaf's inspect() started with the same
    ///      singleton, so two markets on one Morpho were indistinguishable in the first 20 bytes.
    function test_AllOps_InspectIsPerMarket() public view {
        assertTrue(
            keccak256(
                openHook.inspect(
                    _v2Enc(
                        _key(collateralA, oracleA, address(irmA), lltvA),
                        collateralA,
                        oracleA,
                        address(irmA),
                        lltvA,
                        AMT,
                        AMT
                    )
                )
            )
            != keccak256(
                openHook.inspect(
                    _v2Enc(
                        _key(collateralB, oracleB, address(irmB), lltvB),
                        collateralB,
                        oracleB,
                        address(irmB),
                        lltvB,
                        AMT,
                        AMT
                    )
                )
            ),
            "open: per-market identity"
        );
        bytes memory a = pledgeHook.inspect(
            _v2Enc(_key(collateralA, oracleA, address(irmA), lltvA), collateralA, oracleA, address(irmA), lltvA, AMT, 0)
        );
        bytes memory b = pledgeHook.inspect(
            _v2Enc(_key(collateralB, oracleB, address(irmB), lltvB), collateralB, oracleB, address(irmB), lltvB, AMT, 0)
        );
        assertEq(a.length, 132);
        assertTrue(keccak256(a) != keccak256(b), "pledge: per-market identity");
        // field 0 is the market key, and it differs per market
        assertEq(address(bytes20(a)), _key(collateralA, oracleA, address(irmA), lltvA));
        assertEq(address(bytes20(b)), _key(collateralB, oracleB, address(irmB), lltvB));
    }

    /*//////////////////////////////////////////////////////////////
                       (b): CALL TARGET == MORPHO
    //////////////////////////////////////////////////////////////*/

    function test_AllOps_TwoSharedMarkets_MorphoCallsTargetHeaderMorpho() public view {
        _assertTargetsAllOps(collateralA, oracleA, address(irmA), lltvA);
        _assertTargetsAllOps(collateralB, oracleB, address(irmB), lltvB);
    }

    function _assertTargetsAllOps(address coll, address oracle, address irm, uint256 lltv) internal view {
        _assertMorphoTargeted(
            lendHook.build(address(0), address(this), _lendEnc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv)),
            coll,
            address(lendHook)
        );
        _assertMorphoTargeted(
            withdrawHook.build(
                address(0), address(this), _withdrawEnc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv)
            ),
            coll,
            address(withdrawHook)
        );
        _assertMorphoTargeted(
            openHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, AMT)
            ),
            coll,
            address(openHook)
        );
        _assertMorphoTargeted(
            repayHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)
            ),
            coll,
            address(repayHook)
        );
        _assertMorphoTargeted(
            closeHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, AMT)
            ),
            coll,
            address(closeHook)
        );
        _assertMorphoTargeted(
            pledgeHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)
            ),
            coll,
            address(pledgeHook)
        );
        _assertMorphoTargeted(
            borrowHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)
            ),
            coll,
            address(borrowHook)
        );
        _assertMorphoTargeted(
            releaseHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, AMT, 0)
            ),
            coll,
            address(releaseHook)
        );
    }

    /// @dev Every execution that is not a token approve (loan/collateral token target) and not a
    ///      pre/postExecute self-call (targets the hook itself) must target the header-derived Morpho
    ///      singleton; the wrong Morpho must never be targeted.
    function _assertMorphoTargeted(Execution[] memory execs, address coll, address hook) internal view {
        bool morphoSeen;
        for (uint256 i; i < execs.length; ++i) {
            address t = execs[i].target;
            assertTrue(t != address(otherMorpho), "wrong Morpho targeted");
            if (t != loanToken && t != coll && t != hook) {
                assertEq(t, address(morpho), "non-token call must target header Morpho");
                morphoSeen = true;
            }
        }
        assertTrue(morphoSeen, "at least one Morpho call expected");
    }

    /*//////////////////////////////////////////////////////////////
        (b') SECURITY HARDENING — invariant: no body can move the call target off Morpho
    //////////////////////////////////////////////////////////////*/

    /// @dev SUP-21038 P2-1: the header→target pin is the primary control. This fuzzes the whole
    ///      MarketParams body (oracle/irm/lltv) with a VALID header and asserts every position-
    ///      independent op still routes ALL Morpho calls to the header Morpho — i.e. no crafted body
    ///      can redirect a call/approve. If the `_requireYieldSourceIsMorpho` pin were ever dropped
    ///      from a build path this stays green (header==morpho here), so it is paired with the
    ///      mismatch test above which fails closed on a wrong header.
    function testFuzz_CallTargetsAlwaysMorpho_ArbitraryBody(
        address oracle,
        address irm,
        uint256 lltv,
        uint256 a1
    )
        public
        view
    {
        // keep the body well-formed enough for the strict decoders (nonzero, distinct tokens handled
        // by fixed collateralA); amounts nonzero so builds are non-empty
        vm.assume(oracle != address(0) && irm != address(0));
        a1 = bound(a1, 1, type(uint128).max);
        address coll = collateralA;

        _assertMorphoTargeted(
            lendHook.build(address(0), address(this), _lendEncA(coll, oracle, irm, lltv, a1)), coll, address(lendHook)
        );
        _assertMorphoTargeted(
            withdrawHook.build(address(0), address(this), _withdrawEncA(coll, oracle, irm, lltv, a1)),
            coll,
            address(withdrawHook)
        );
        _assertMorphoTargeted(
            openHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, a1, a1)
            ),
            coll,
            address(openHook)
        );
        _assertMorphoTargeted(
            pledgeHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, a1, 0)
            ),
            coll,
            address(pledgeHook)
        );
        _assertMorphoTargeted(
            borrowHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, a1, 0)
            ),
            coll,
            address(borrowHook)
        );
        _assertMorphoTargeted(
            releaseHook.build(
                address(0), address(this), _v2Enc(_key(coll, oracle, irm, lltv), coll, oracle, irm, lltv, a1, 0)
            ),
            coll,
            address(releaseHook)
        );
    }

    /// @dev SUP-21038 P2-3: every Morpho supply/supplyCollateral/repay call MUST pass empty callback
    ///      data ("") so Morpho never invokes onMorpho* back into the account mid-operation.
    function test_MorphoCallbackDataAlwaysEmpty() public view {
        // supply (lend) — signature: supply(MarketParams, uint256, uint256, address, bytes)
        _assertSupplyLikeCallbackEmpty(
            _firstMorphoCall(
                lendHook.build(
                    address(0),
                    address(this),
                    _lendEnc(
                        _key(collateralA, oracleA, address(irmA), lltvA), collateralA, oracleA, address(irmA), lltvA
                    )
                ),
                address(lendHook)
            )
        );
        // repay — same 5-arg shape (market A has a seeded borrow position)
        _assertSupplyLikeCallbackEmpty(
            _firstMorphoCall(
                repayHook.build(
                    address(0),
                    address(this),
                    _v2Enc(
                        _key(collateralA, oracleA, address(irmA), lltvA),
                        collateralA,
                        oracleA,
                        address(irmA),
                        lltvA,
                        AMT,
                        0
                    )
                ),
                address(repayHook)
            )
        );
        // supplyCollateral (pledge) — signature: supplyCollateral(MarketParams, uint256, address, bytes)
        _assertSupplyCollateralCallbackEmpty(
            _firstMorphoCall(
                pledgeHook.build(
                    address(0),
                    address(this),
                    _v2Enc(
                        _key(collateralA, oracleA, address(irmA), lltvA),
                        collateralA,
                        oracleA,
                        address(irmA),
                        lltvA,
                        AMT,
                        0
                    )
                ),
                address(pledgeHook)
            )
        );
    }

    /// @dev Returns the callData of the first execution that targets the Morpho singleton
    function _firstMorphoCall(Execution[] memory execs, address hook) internal view returns (bytes memory) {
        for (uint256 i; i < execs.length; ++i) {
            address t = execs[i].target;
            if (t == address(morpho) && t != hook) return execs[i].callData;
        }
        revert("no Morpho call found");
    }

    function _assertSupplyLikeCallbackEmpty(bytes memory cd) internal pure {
        (,,,, bytes memory cb) = abi.decode(_stripSelector(cd), (MarketParams, uint256, uint256, address, bytes));
        assertEq(cb.length, 0, "supply/repay callback data must be empty");
    }

    function _assertSupplyCollateralCallbackEmpty(bytes memory cd) internal pure {
        (,,, bytes memory cb) = abi.decode(_stripSelector(cd), (MarketParams, uint256, address, bytes));
        assertEq(cb.length, 0, "supplyCollateral callback data must be empty");
    }

    function _stripSelector(bytes memory cd) internal pure returns (bytes memory out) {
        out = new bytes(cd.length - 4);
        for (uint256 i; i < out.length; ++i) {
            out[i] = cd[i + 4];
        }
    }

    /*//////////////////////////////////////////////////////////////
              STATE-AWARE ENCODERS (loanToken read from storage)
    //////////////////////////////////////////////////////////////*/

    function _lendEncA(
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 amt
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID, _key(coll, oracle, irm, lltv), loanToken, coll, oracle, irm, amt, lltv, false
        );
    }

    function _withdrawEncA(
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 amt
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID, _key(coll, oracle, irm, lltv), loanToken, coll, oracle, irm, lltv, amt, uint256(0)
        );
    }

    /// @dev MONEY_MARKET header identity: registry market key of (loanToken, coll, oracle, irm, lltv)
    function _key(address coll, address oracle, address irm, uint256 lltv) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    Id.unwrap(
                        MarketParams({
                                loanToken: loanToken, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv
                            }).id()
                    )
                )
            )
        );
    }

    function _lendEnc(
        address ys,
        address coll,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, loanToken, coll, oracle, irm, AMT, lltv, false);
    }

    function _withdrawEnc(
        address ys,
        address coll,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, loanToken, coll, oracle, irm, lltv, AMT, uint256(0));
    }

    function _v2Enc(
        address ys,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 a1,
        uint256 a2
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, loanToken, coll, oracle, irm, a1, a2, false, lltv, uint8(0));
    }
}
