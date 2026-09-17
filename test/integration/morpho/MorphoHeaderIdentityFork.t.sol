// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
// V1 leaves (lender ops)
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { BaseMorphoLoanHook } from "../../../src/hooks/loan/morpho/BaseMorphoLoanHook.sol";
// V2 base + leaves (six borrower ops)
import { BaseMorphoLoanHookV2 } from "../../../src/hooks/loan/morpho/BaseMorphoLoanHookV2.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";

/// @title MorphoHeaderIdentityFork
/// @notice SUP-21038 acceptance: mainnet-fork proof that the 52-byte header identity holds across
///         EVERY Morpho hook (2 lender + 6 borrower ops) for TWO real markets sharing the ONE real
///         Morpho Blue singleton but differing in collateral / oracle / lltv (body = MarketParams
///         filter only). For each (market, op) it asserts:
///         (a) header yieldSource (offset 32) == real Morpho singleton (a wrong Morpho reverts);
///         (b) every Morpho call in build() targets the header Morpho;
///         (c) inspect() == abi.encodePacked(Morpho, loan, collateral, oracle, irm, lltv).
/// @dev Runs against the real Morpho at MORPHO. The identity assertions are body-agnostic (decode /
///      build / inspect), so no market liquidity or seeded position is required. Full end-to-end
///      execution of the six borrower ops on a real market is covered by MorphoV2HooksFork; the
///      lender ops by MorphoBlueMarketFork. Here the emphasis is the >=2-markets / one-Morpho
///      identity invariant.
contract MorphoHeaderIdentityForkTest is MinimalBaseIntegrationTest {
    // Hooks — all constructed against the ONE real Morpho singleton
    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    MorphoSupplyAndBorrowHookV2 internal openHook;
    MorphoRepayHookV2 internal repayHook;
    MorphoRepayAndWithdrawHookV2 internal closeHook;
    MorphoSupplyHookV2 internal pledgeHook;
    MorphoBorrowHookV2 internal borrowHook;
    MorphoWithdrawCollateralHookV2 internal releaseHook;

    // Market A: WBTC/USDC — real market (oracle/irm from Constants)
    address internal constant LOAN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (shared loan token)
    address internal constant COLL_A = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
    uint256 internal constant LLTV_A = 860_000_000_000_000_000; // 86%
    // Market B: a SECOND market on the same Morpho + shared AdaptiveCurve IRM, differing in
    // collateral (WETH), oracle and lltv. Distinct MarketParams (=> distinct market id) is all the
    // body-as-filter identity assertions here require; the oracle need not be a live market oracle.
    address internal constant COLL_B = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address internal constant ORACLE_B = 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2; // distinct market oracle
    uint256 internal constant LLTV_B = 770_000_000_000_000_000; // 77%

    uint256 internal constant AMT = 1e6;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        openHook = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayHook = new MorphoRepayHookV2(MORPHO);
        closeHook = new MorphoRepayAndWithdrawHookV2(MORPHO);
        pledgeHook = new MorphoSupplyHookV2(MORPHO);
        borrowHook = new MorphoBorrowHookV2(MORPHO);
        releaseHook = new MorphoWithdrawCollateralHookV2(MORPHO);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                       (c) INSPECT == Morpho + MarketParams
    //////////////////////////////////////////////////////////////*/

    function test_Fork_TwoSharedMarkets_InspectIsMorphoPlusMarketParams() public view {
        _assertInspect(COLL_A, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, LLTV_A);
        _assertInspect(COLL_B, ORACLE_B, MORPHO_IRM_WBTC_USDC, LLTV_B);
    }

    function _assertInspect(address coll, address oracle, address irm, uint256 lltv) internal view {
        bytes memory expected = abi.encodePacked(MORPHO, LOAN, coll, oracle, irm, lltv);
        assertEq(lendHook.inspect(_lend(MORPHO, coll, oracle, irm, lltv)), expected, "lend");
        assertEq(withdrawHook.inspect(_withdraw(MORPHO, coll, oracle, irm, lltv)), expected, "withdraw");
        assertEq(openHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, AMT)), expected, "open");
        assertEq(repayHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), expected, "repay");
        assertEq(closeHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, AMT)), expected, "close");
        assertEq(pledgeHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), expected, "pledge");
        assertEq(borrowHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), expected, "borrow");
        assertEq(releaseHook.inspect(_v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), expected, "release");
    }

    /*//////////////////////////////////////////////////////////////
                       (b) Morpho calls target header Morpho
    //////////////////////////////////////////////////////////////*/

    /// @dev The six position-independent ops build non-empty executions without any on-chain
    ///      position; each Morpho call must target the real Morpho singleton. (repay/close read live
    ///      debt and no-op when zero — their real-state call-target is covered by MorphoV2HooksFork.)
    function test_Fork_TwoSharedMarkets_MorphoCallsTargetRealMorpho() public view {
        _assertTargets(COLL_A, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, LLTV_A);
        _assertTargets(COLL_B, ORACLE_B, MORPHO_IRM_WBTC_USDC, LLTV_B);
    }

    function _assertTargets(address coll, address oracle, address irm, uint256 lltv) internal view {
        _assertMorphoTargeted(lendHook.build(address(0), address(this), _lend(MORPHO, coll, oracle, irm, lltv)), coll, address(lendHook));
        _assertMorphoTargeted(withdrawHook.build(address(0), address(this), _withdraw(MORPHO, coll, oracle, irm, lltv)), coll, address(withdrawHook));
        _assertMorphoTargeted(openHook.build(address(0), address(this), _v2(MORPHO, coll, oracle, irm, lltv, AMT, AMT)), coll, address(openHook));
        _assertMorphoTargeted(pledgeHook.build(address(0), address(this), _v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), coll, address(pledgeHook));
        _assertMorphoTargeted(borrowHook.build(address(0), address(this), _v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), coll, address(borrowHook));
        _assertMorphoTargeted(releaseHook.build(address(0), address(this), _v2(MORPHO, coll, oracle, irm, lltv, AMT, 0)), coll, address(releaseHook));
    }

    function _assertMorphoTargeted(Execution[] memory execs, address coll, address hook) internal view {
        bool morphoSeen;
        for (uint256 i; i < execs.length; ++i) {
            address t = execs[i].target;
            if (t != LOAN && t != coll && t != hook) {
                assertEq(t, MORPHO, "non-token call must target header Morpho");
                morphoSeen = true;
            }
        }
        assertTrue(morphoSeen, "at least one Morpho call expected");
    }

    /*//////////////////////////////////////////////////////////////
                       (a) wrong Morpho header reverts
    //////////////////////////////////////////////////////////////*/

    function test_Fork_HeaderPointingAtWrongMorpho_Reverts() public {
        address wrong = address(0xdEADbeEF00000000000000000000000000000001);

        vm.expectRevert(BaseMorphoLoanHook.YIELD_SOURCE_MISMATCH.selector);
        lendHook.build(address(0), address(this), _lend(wrong, COLL_A, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, LLTV_A));

        vm.expectRevert(BaseMorphoLoanHook.YIELD_SOURCE_MISMATCH.selector);
        withdrawHook.build(address(0), address(this), _withdraw(wrong, COLL_B, ORACLE_B, MORPHO_IRM_WBTC_USDC, LLTV_B));

        vm.expectRevert(BaseMorphoLoanHookV2.YIELD_SOURCE_MISMATCH.selector);
        openHook.build(address(0), address(this), _v2(wrong, COLL_A, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, LLTV_A, AMT, AMT));

        vm.expectRevert(BaseMorphoLoanHookV2.YIELD_SOURCE_MISMATCH.selector);
        pledgeHook.build(address(0), address(this), _v2(wrong, COLL_B, ORACLE_B, MORPHO_IRM_WBTC_USDC, LLTV_B, AMT, 0));

        vm.expectRevert(BaseMorphoLoanHookV2.YIELD_SOURCE_MISMATCH.selector);
        borrowHook.build(address(0), address(this), _v2(wrong, COLL_A, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, LLTV_A, AMT, 0));

        vm.expectRevert(BaseMorphoLoanHookV2.YIELD_SOURCE_MISMATCH.selector);
        releaseHook.build(address(0), address(this), _v2(wrong, COLL_B, ORACLE_B, MORPHO_IRM_WBTC_USDC, LLTV_B, AMT, 0));
    }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _lend(address ys, address coll, address oracle, address irm, uint256 lltv) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, LOAN, coll, oracle, irm, AMT, lltv, false);
    }

    function _withdraw(address ys, address coll, address oracle, address irm, uint256 lltv) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, LOAN, coll, oracle, irm, lltv, AMT, uint256(0));
    }

    function _v2(
        address ys,
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
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, ys, LOAN, coll, oracle, irm, a1, a2, false, lltv, uint8(0));
    }
}
