// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
// V1 lender hooks
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
// V2 borrower hooks
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";

/// @title MorphoHeaderIdentityE2E
/// @notice SUP-21038 end-to-end proof on a real Ethereum-mainnet fork: with the standardized 52-byte
///         header (oracleId at offset 0 + Morpho at offset 32), BOTH the V1 lender hooks and the V2 borrower hooks
///         execute correctly through the real ERC-4337 SuperExecutor + paymaster against the ONE real
///         Morpho Blue singleton, on TWO distinct real markets sharing that Morpho
///         (WBTC/USDC and wstETH/WETH). Real on-chain state (supply shares, collateral, borrow
///         shares, wallet balances) is asserted throughout — no mocks.
contract MorphoHeaderIdentityE2ETest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    MorphoSupplyAndBorrowHookV2 internal openHook;
    MorphoRepayAndWithdrawHookV2 internal closeHook;
    MorphoSupplyHookV2 internal pledgeHook;
    MorphoWithdrawCollateralHookV2 internal releaseHook;
    MorphoBorrowHookV2 internal borrowHook;
    MorphoRepayHookV2 internal repayHook;
    ISuperNativePaymaster internal paymaster;

    uint256 internal constant MAX = type(uint256).max;

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
        assertApproxEqAbs(
            IERC20(loan).balanceOf(accountEth), loanBefore, 2, "withdraw: loan token returned (<=2wei share rounding)"
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
                              EXEC + ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _execSingle(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, paymaster, 1e18);
    }

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

    function _lend(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, MORPHO, loan, coll, oracle, irm, amount, lltv, false);
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
        pure
        returns (bytes memory)
    {
        // withdraw layout: header + market + lltv@132 + assets@164 (0) + shares@196
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, MORPHO, loan, coll, oracle, irm, lltv, uint256(0), shares);
    }

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
