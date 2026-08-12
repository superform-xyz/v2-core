// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IPYieldToken } from "../../../src/vendor/pendle/IPYieldToken.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import {
    LimitOrderData,
    TokenInput,
    TokenOutput,
    ApproxParams
} from "../../../src/vendor/pendle/IPendleRouterV4.sol";
import { IPendlePTAmortizedOracle } from "../../../src/vendor/pendle/IPendlePTAmortizedOracle.sol";
import { IPendlePTAmortizedOracleV2 } from "../../../src/vendor/pendle/IPendlePTAmortizedOracleV2.sol";

import { PendlePTAmortizedOracle } from "../../../src/accounting/oracles/PendlePTAmortizedOracle.sol";
import { PendlePTHook } from "../../../src/hooks/swappers/pendle/PendlePTHook.sol";
import { RecordPurchasePendlePTHook } from "../../../src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol";
import { RecordRedemptionPendlePTHook } from "../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { IPendlePTHookResult } from "../../../src/interfaces/IPendlePTHookResult.sol";
import { MockHook } from "../../mocks/MockHook.sol";

/// @title PendlePTHookV1AmortizedOracleE2E
/// @notice End-to-end mainnet-fork tests for the production trio:
///         PendlePTHook -> RecordPurchasePendlePTHook / RecordRedemptionPendlePTHook
///         registering into PendlePTAmortizedOracle (V1).
/// @dev Uses the live mAPOLLO market (PT-mAPOLLO-24SEP2026, USDC accounting asset) with REAL swaps
///      through the real Pendle Router V4, against BOTH a source-built V1 oracle and the actually
///      deployed mainnet V1 oracle instance.
/// @dev Fork block 25_735_000 (2026-08-12): after the mAPOLLO market's observation cardinality was
///      increased, so the V1 oracle's fixed 900s TWAP works (it reverts OracleTargetTooOld before
///      block ~25_731_500).
contract PendlePTHookV1AmortizedOracleE2E is Test {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Pendle Router V4 (same address on all chains)
    address constant PENDLE_ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    /// @dev mAPOLLO Pendle market on Ethereum mainnet (PT-mAPOLLO-24SEP2026, accounting asset USDC)
    address constant MAPOLLO_MARKET = 0xA268168E73791e2A0ab48DED41ECf6dC923cd17F;

    /// @dev USDC on Ethereum mainnet — the SY-mAPOLLO accounting asset and a direct SY tokenIn/out
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev mAPOLLO (Midas Apollo) — the SY underlying; used as sell/redeem tokenOut (plain SY
    ///      unwrap; PT->USDC exits route through Midas' redemption vault which enforces a minimum)
    address constant MAPOLLO = 0x7CF9DEC92ca9FD46f8d86e7798B72624Bc116C05;

    /// @dev PRODUCTION PendlePTAmortizedOracle (V1) on Ethereum mainnet
    address constant DEPLOYED_V1_ORACLE = 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62;

    /// @dev PRODUCTION SuperLedgerConfiguration on Ethereum mainnet
    address constant SUPER_LEDGER_CONFIGURATION = 0x2e2D71289CBA19f831856f85DEC7f194B0165e69;

    /// @dev First block where the mAPOLLO market supports the V1 oracle's 900s TWAP
    uint256 constant FORK_BLOCK = 25_735_000;

    uint32 constant TWAP_15_MIN = 900;

    /*//////////////////////////////////////////////////////////////
                                   STATE
    //////////////////////////////////////////////////////////////*/

    PendlePTHook public hook;
    MockHook public dummyPrevHook;

    PendlePTAmortizedOracle public oracle; // source-built V1
    RecordPurchasePendlePTHook public recordPurchase; // bound to source-built V1
    RecordRedemptionPendlePTHook public recordRedemption; // bound to source-built V1

    address public sy;
    address public pt;
    address public yt;
    address public admin;
    address public user;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        admin = makeAddr("admin");
        user = makeAddr("user");

        hook = new PendlePTHook(PENDLE_ROUTER);
        dummyPrevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(0));

        oracle = new PendlePTAmortizedOracle(admin, SUPER_LEDGER_CONFIGURATION);
        recordPurchase = new RecordPurchasePendlePTHook(address(oracle), address(hook));
        recordRedemption = new RecordRedemptionPendlePTHook(address(oracle), address(hook));

        (sy, pt, yt) = IPendleMarket(MAPOLLO_MARKET).readTokens();

        _primeMarketOracle();
    }

    /// @dev PRODUCTION PREREQUISITE, reproduced on the fork: the mAPOLLO market ships with
    ///      observation cardinality 1, so ANY trade kills the 900s TWAP for the next 15 minutes —
    ///      which makes same-transaction swap -> record impossible (getAssetOutput reverts
    ///      OracleTargetTooOld). Ops must call the permissionless increaseObservationsCardinalityNext
    ///      and let trades fill the buffer before onboarding the market to the V1 oracle flow.
    function _primeMarketOracle() internal {
        (bool ok,) = MAPOLLO_MARKET.call(abi.encodeWithSignature("increaseObservationsCardinalityNext(uint16)", uint16(32)));
        assertTrue(ok, "increaseObservationsCardinalityNext failed");

        address primer = makeAddr("twapPrimer");
        for (uint256 i; i < 4; i++) {
            _buyPt(primer, 25e6);
            vm.warp(block.timestamp + 400);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    V1 <> V2 ABI COMPATIBILITY (DOCUMENTATION)
    //////////////////////////////////////////////////////////////*/

    /// @notice Documents WHY the record-purchase hook had to be rebound: the V1 and V2 purchase
    ///         selectors differ, while the redemption selector is identical in both.
    function test_SelectorCompatibility_V1vsV2() public pure {
        assertTrue(
            IPendlePTAmortizedOracle.recordPurchase.selector != IPendlePTAmortizedOracleV2.recordPurchase.selector,
            "V1 recordPurchase(address,uint256,uint256) != V2 recordPurchase(address,uint256,uint32)"
        );
        assertEq(
            IPendlePTAmortizedOracle.recordRedemption.selector,
            IPendlePTAmortizedOracleV2.recordRedemption.selector,
            "recordRedemption(address,uint256) is identical in V1 and V2"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    V1 ORACLE MARKET VIEWS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Source-built V1 oracle prices the live mAPOLLO market sanely and matches the
    ///         deployed production instance exactly.
    function test_V1Oracle_MarketViews_RealMarket() public view {
        assertEq(oracle.decimals(MAPOLLO_MARKET), 6, "PT-mAPOLLO has 6 decimals");

        uint256 pps = oracle.getPricePerShare(MAPOLLO_MARKET);
        assertGt(pps, 0.97e18, "PT should trade near par ~6 weeks to maturity");
        assertLt(pps, 1e18, "PT must trade at a discount pre-maturity");

        // Source-built and deployed production V1 oracles must price identically
        uint256 deployedPps = PendlePTAmortizedOracle(DEPLOYED_V1_ORACLE).getPricePerShare(MAPOLLO_MARKET);
        assertEq(pps, deployedPps, "source-built V1 == deployed V1 pricing");

        // getAssetOutput converts PT (6 dec) to USDC (6 dec) at the TWAP rate
        uint256 assetOut = oracle.getAssetOutput(MAPOLLO_MARKET, address(0), 1_000_000);
        assertEq(assetOut, pps / 1e12, "1.0 PT valued at pps in USDC units");

        assertGt(oracle.getTVL(MAPOLLO_MARKET), 0, "market TVL > 0");
    }

    /*//////////////////////////////////////////////////////////////
                BUY PT -> RECORD PURCHASE (REAL SWAP + REAL ORACLE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Real USDC->PT swap through the router, then the purchase recorder registers the
    ///         ACTUAL PT received into the real V1 oracle with an on-chain computed cost.
    function test_Execute_BuyPt_RecordPurchase_RealMarket() public {
        (uint256 usdcSpent, uint256 ptReceived) = _buyPt(user, 1000e6);
        assertGt(ptReceived, 0, "PT received");

        // TradeResult mirrors actual balance deltas
        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.BUY_PT), "op BUY_PT");
        assertEq(r.outputAmount, ptReceived, "outputAmount == actual PT received");

        // Expected on-chain cost: the oracle's own TWAP valuation of the recorded PT
        uint256 expectedSySpent = oracle.getAssetOutput(MAPOLLO_MARKET, address(0), ptReceived);

        _execRecordPurchase(user);

        assertTrue(oracle.hasPosition(user, MAPOLLO_MARKET), "position registered");
        uint256 bookValue = oracle.getBookValue(user, MAPOLLO_MARKET);
        assertEq(bookValue, expectedSySpent, "book value == oracle TWAP valuation of PT received");

        // The on-chain valuation must track the ACTUAL USDC spent closely (AMM fee + price impact only)
        assertApproxEqRel(bookValue, usdcSpent, 0.01e18, "cost basis ~= actual USDC spent (within 1%)");
        assertLt(bookValue, ptReceived, "book value below face (PT bought at discount)");

        // IYieldSourceOracle surface agrees
        assertEq(oracle.getTVLByOwnerOfShares(MAPOLLO_MARKET, user), bookValue, "TVL == amortized book value");
        assertEq(oracle.getBalanceOfOwner(MAPOLLO_MARKET, user), ptReceived, "PT balance tracked");
    }

    /// @notice The encoded twapDuration must satisfy the V1 oracle's configured minimum (900s).
    function test_Execute_BuyPt_RecordPurchase_TwapBelowMinimum_Reverts() public {
        _buyPt(user, 100e6);
        bytes memory data = _recordPurchaseData(MAPOLLO_MARKET, 0, TWAP_15_MIN - 1, true);
        vm.expectRevert(RecordPurchasePendlePTHook.TWAP_DURATION_TOO_SHORT.selector);
        recordPurchase.build(address(hook), user, data);
    }

    /// @notice Two real buys accumulate: second record adds its valuation on top of the amortized book.
    function test_MultiplePurchases_Accumulate_RealMarket() public {
        _buyPt(user, 500e6);
        _execRecordPurchase(user);
        uint256 bookAfterFirst = oracle.getBookValue(user, MAPOLLO_MARKET);

        _freezeSyRate();
        vm.warp(block.timestamp + 5 days);
        uint256 amortizedBeforeSecond = oracle.getBookValue(user, MAPOLLO_MARKET);
        assertGt(amortizedBeforeSecond, bookAfterFirst, "book value amortizes upward");

        // Second buy paid in mAPOLLO (plain SY wrap): Midas' USDC deposit vault checks its own
        // data feed, which is stale after the warp on a fork. Also exercises a tokenIn that is
        // NOT the accounting asset — the on-chain valuation must be unaffected by the pay token.
        uint256 ptReceived2 = _buyPtWithMApollo(user, 270e18);
        uint256 valuation2 = oracle.getAssetOutput(MAPOLLO_MARKET, address(0), ptReceived2);
        _execRecordPurchase(user);

        assertEq(
            oracle.getBookValue(user, MAPOLLO_MARKET),
            amortizedBeforeSecond + valuation2,
            "book == amortized(first) + valuation(second)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                SELL PT -> RECORD REDEMPTION (REAL SWAP + REAL ORACLE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Real partial PT->USDC sale, then the redemption recorder registers the ACTUAL PT
    ///         spent (never the USDC received) and the V1 oracle reduces book value pro rata.
    function test_Execute_SellPt_RecordRedemption_RealMarket() public {
        _buyPt(user, 1000e6);
        _execRecordPurchase(user);

        _freezeSyRate();
        vm.warp(block.timestamp + 3 days);

        uint256 ptBalanceBefore = IERC20(pt).balanceOf(user);
        uint256 bookBefore = oracle.getBookValue(user, MAPOLLO_MARKET);
        uint256 ptToSell = ptBalanceBefore / 2;

        uint256 mApolloReceived = _sellPt(user, ptToSell);
        assertGt(mApolloReceived, 0, "mAPOLLO received from sale");

        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.SELL_PT), "op SELL_PT");
        assertEq(r.inputAmount, ptToSell, "inputAmount == PT actually spent");
        assertTrue(r.outputAmount != r.inputAmount, "sanity: asset received != PT spent");

        _execRecordRedemption(user);

        // Pro-rata cost-basis reduction: newBook = book - book * ptSold / prevBalance
        uint256 expectedBook = bookBefore - (bookBefore * ptToSell) / ptBalanceBefore;
        assertApproxEqAbs(
            oracle.getBookValue(user, MAPOLLO_MARKET), expectedBook, 1, "book reduced pro rata by PT sold"
        );
        assertEq(IERC20(pt).balanceOf(user), ptBalanceBefore - ptToSell, "PT balance reduced");
    }

    /// @notice Redemption recording without a prior recorded purchase must revert NO_POSITION in V1.
    function test_RecordRedemption_NoPosition_Reverts_RealMarket() public {
        // Real sale of dealt PT — but nothing was ever recorded for this user
        deal(pt, user, 10e6);
        _sellPt(user, 10e6);

        Execution[] memory ex =
            recordRedemption.build(address(hook), user, _recordRedemptionData(MAPOLLO_MARKET, 0, true));
        vm.prank(user);
        (bool ok, bytes memory ret) = ex[1].target.call(ex[1].callData);
        assertFalse(ok, "recordRedemption must revert without a position");
        assertEq(_revertSelector(ret), PendlePTAmortizedOracle.NO_POSITION.selector, "reverts NO_POSITION");
    }

    /*//////////////////////////////////////////////////////////////
                        AMORTIZATION (REAL MARKET CLOCK)
    //////////////////////////////////////////////////////////////*/

    /// @notice After a real recorded buy, book value pulls to par monotonically and equals face
    ///         value (PT balance, USDC units) at maturity.
    function test_Amortization_PullsToPar_RealMarket() public {
        (, uint256 ptReceived) = _buyPt(user, 1000e6);
        _execRecordPurchase(user);

        _freezeSyRate();
        uint256 maturity = IPYieldToken(yt).expiry();
        uint256 bv0 = oracle.getBookValue(user, MAPOLLO_MARKET);
        uint256 quarter = (maturity - block.timestamp) / 4;

        vm.warp(block.timestamp + quarter);
        uint256 bv25 = oracle.getBookValue(user, MAPOLLO_MARKET);
        assertGt(bv25, bv0, "book value increases at 25% of time to maturity");

        vm.warp(block.timestamp + quarter);
        uint256 bv50 = oracle.getBookValue(user, MAPOLLO_MARKET);
        assertGt(bv50, bv25, "book value keeps increasing at 50%");

        vm.warp(maturity);
        assertEq(
            oracle.getBookValue(user, MAPOLLO_MARKET), ptReceived, "book value == face value (1 PT = 1 USDC) at maturity"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    FULL LIFECYCLE INCL. MATURED REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice buy -> record -> partial sell -> record -> maturity -> real redeem -> record.
    ///         Ends with zero PT and zero book value on the real V1 oracle.
    function test_FullLifecycle_BuySellRedeem_RealMarket() public {
        _buyPt(user, 1000e6);
        _execRecordPurchase(user);

        // Partial sale pre-maturity
        _freezeSyRate();
        vm.warp(block.timestamp + 2 days);
        uint256 ptToSell = IERC20(pt).balanceOf(user) / 3;
        _sellPt(user, ptToSell);
        _execRecordRedemption(user);
        assertGt(oracle.getBookValue(user, MAPOLLO_MARKET), 0, "book value remains after partial sale");

        // Matured redemption of the remainder via the same PendlePTHook data (expiry routing)
        uint256 maturity = IPYieldToken(yt).expiry();
        vm.warp(maturity + 1 days);
        uint256 remainingPt = IERC20(pt).balanceOf(user);
        assertGt(_sellPt(user, remainingPt), 0, "mAPOLLO received from matured redemption");
        assertEq(IERC20(pt).balanceOf(user), 0, "all PT redeemed");

        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.REDEEM_PT), "op REDEEM_PT");
        assertEq(r.inputAmount, remainingPt, "inputAmount == PT redeemed");

        _execRecordRedemption(user);
        assertEq(oracle.getBookValue(user, MAPOLLO_MARKET), 0, "book value zero once all PT is gone");
    }

    /*//////////////////////////////////////////////////////////////
                    ISOLATION GUARDS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Independent strategies get independent book values on the shared V1 oracle.
    function test_MultiStrategy_Isolation_RealMarket() public {
        address userB = makeAddr("userB");

        _buyPt(user, 1000e6);
        _execRecordPurchase(user);
        _buyPt(userB, 250e6);
        _execRecordPurchase(userB);

        uint256 bookA = oracle.getBookValue(user, MAPOLLO_MARKET);
        uint256 bookB = oracle.getBookValue(userB, MAPOLLO_MARKET);
        assertGt(bookA, bookB, "independent book values");

        // userB's redemption must not affect userA
        uint256 ptToSell = IERC20(pt).balanceOf(userB) / 2;
        _sellPt(userB, ptToSell);
        _execRecordRedemption(userB);

        assertEq(oracle.getBookValue(user, MAPOLLO_MARKET), bookA, "userA book untouched by userB redemption");
        assertLt(oracle.getBookValue(userB, MAPOLLO_MARKET), bookB, "userB book reduced");
    }

    /// @notice A stale execution context must not be recordable (regression guard, V1 binding).
    function test_ContextIsolation_RealMarket() public {
        _buyPt(user, 100e6);

        hook.setExecutionContext(user);

        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        recordPurchase.build(address(hook), user, _recordPurchaseData(MAPOLLO_MARKET, 0, TWAP_15_MIN, true));
    }

    /// @notice Cross-hook wrong-direction guard with the V1-bound recorder after a REAL sale.
    function test_RecordPurchase_RejectsSell_RealMarket() public {
        deal(pt, user, 10e6);
        _sellPt(user, 10e6);

        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        recordPurchase.build(address(hook), user, _recordPurchaseData(MAPOLLO_MARKET, 0, TWAP_15_MIN, true));
    }

    /// @notice PASSTHROUGH: the record hooks forward the swap hook's output downstream unchanged.
    function test_Passthrough_PreservesPrevOutput_RealMarket() public {
        (, uint256 ptReceived) = _buyPt(user, 100e6);
        _execRecordPurchase(user);

        assertEq(recordPurchase.getOutAmount(user), hook.getOutAmount(user), "outAmount forwarded");
        assertEq(recordPurchase.getOutAmount(user), ptReceived, "forwarded amount == PT received");
        assertEq(recordPurchase.getOutToken(user), pt, "outToken forwarded");
    }

    /*//////////////////////////////////////////////////////////////
            FULL FLOW AGAINST THE DEPLOYED PRODUCTION V1 ORACLE
    //////////////////////////////////////////////////////////////*/

    /// @notice The exact production wiring: record hooks bound to the DEPLOYED mainnet V1 oracle
    ///         (0xD640...eB62). Real buy, real sale, real recording on the production contract.
    function test_DeployedV1Oracle_RealAddresses_FullFlow() public {
        RecordPurchasePendlePTHook prodPurchase =
            new RecordPurchasePendlePTHook(DEPLOYED_V1_ORACLE, address(hook));
        RecordRedemptionPendlePTHook prodRedemption =
            new RecordRedemptionPendlePTHook(DEPLOYED_V1_ORACLE, address(hook));
        PendlePTAmortizedOracle prodOracle = PendlePTAmortizedOracle(DEPLOYED_V1_ORACLE);

        // Real buy + record on the production oracle
        (, uint256 ptReceived) = _buyPt(user, 1000e6);
        uint256 expectedSySpent = prodOracle.getAssetOutput(MAPOLLO_MARKET, address(0), ptReceived);

        prodPurchase.setExecutionContext(user);
        Execution[] memory ex =
            prodPurchase.build(address(hook), user, _recordPurchaseData(MAPOLLO_MARKET, 0, TWAP_15_MIN, true));
        assertEq(ex[1].target, DEPLOYED_V1_ORACLE, "records into the production V1 oracle");
        _exec(user, ex);

        assertTrue(prodOracle.hasPosition(user, MAPOLLO_MARKET), "position on production oracle");
        uint256 bookBefore = prodOracle.getBookValue(user, MAPOLLO_MARKET);
        assertEq(bookBefore, expectedSySpent, "production book value == on-chain valuation");

        // Real partial sale + record on the production oracle
        uint256 ptBalance = IERC20(pt).balanceOf(user);
        uint256 ptToSell = ptBalance / 2;
        _sellPt(user, ptToSell);
        prodRedemption.setExecutionContext(user);
        _exec(user, prodRedemption.build(address(hook), user, _recordRedemptionData(MAPOLLO_MARKET, 0, true)));

        uint256 expectedBook = bookBefore - (bookBefore * ptToSell) / ptBalance;
        assertApproxEqAbs(
            prodOracle.getBookValue(user, MAPOLLO_MARKET), expectedBook, 1, "production book reduced pro rata"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            EXECUTION HELPERS
    //////////////////////////////////////////////////////////////*/

    function _exec(address account, Execution[] memory executions) internal {
        vm.startPrank(account);
        for (uint256 i; i < executions.length; i++) {
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(ok, string(abi.encodePacked("exec ", vm.toString(i), " failed: ", ret)));
        }
        vm.stopPrank();
    }

    /// @dev Real buy: deal USDC, swap USDC -> PT through the real router via PendlePTHook.
    ///      Advances the swap hook's execution context first, exactly as SuperExecutor does
    ///      before executing each hook (pre/post-execute mutexes are context-keyed).
    function _buyPt(address account, uint256 usdcAmount) internal returns (uint256 usdcSpent, uint256 ptReceived) {
        deal(USDC, account, usdcAmount);
        uint256 ptBefore = IERC20(pt).balanceOf(account);

        hook.setExecutionContext(account);
        _exec(account, hook.build(address(dummyPrevHook), account, _buildBuyPtData(MAPOLLO_MARKET, USDC, pt, usdcAmount, 1, false)));

        usdcSpent = usdcAmount - IERC20(USDC).balanceOf(account);
        ptReceived = IERC20(pt).balanceOf(account) - ptBefore;
    }

    /// @dev Real buy paid in mAPOLLO (the SY underlying) instead of USDC.
    function _buyPtWithMApollo(address account, uint256 mApolloAmount) internal returns (uint256 ptReceived) {
        deal(MAPOLLO, account, mApolloAmount);
        uint256 ptBefore = IERC20(pt).balanceOf(account);

        hook.setExecutionContext(account);
        _exec(
            account,
            hook.build(address(dummyPrevHook), account, _buildBuyPtData(MAPOLLO_MARKET, MAPOLLO, pt, mApolloAmount, 1, false))
        );

        ptReceived = IERC20(pt).balanceOf(account) - ptBefore;
    }

    /// @dev Real sell (or matured redeem — the hook routes on YT.isExpired()): PT -> mAPOLLO.
    function _sellPt(address account, uint256 ptAmount) internal returns (uint256 mApolloReceived) {
        uint256 before = IERC20(MAPOLLO).balanceOf(account);
        hook.setExecutionContext(account);
        _exec(account, hook.build(address(dummyPrevHook), account, _buildSellPtData(MAPOLLO_MARKET, pt, MAPOLLO, ptAmount, 1, false)));
        mApolloReceived = IERC20(MAPOLLO).balanceOf(account) - before;
    }

    /// @dev Executes the purchase recorder in automatic mode (amount from PendlePTHook TradeResult).
    ///      Advances only the RECORD hook's context — PendlePTHook's context must stay live so the
    ///      recorder can read the TradeResult of the swap that just executed.
    function _execRecordPurchase(address account) internal {
        recordPurchase.setExecutionContext(account);
        _exec(
            account,
            recordPurchase.build(address(hook), account, _recordPurchaseData(MAPOLLO_MARKET, 0, TWAP_15_MIN, true))
        );
    }

    /// @dev Executes the redemption recorder in automatic mode (amount from PendlePTHook TradeResult).
    function _execRecordRedemption(address account) internal {
        recordRedemption.setExecutionContext(account);
        _exec(
            account, recordRedemption.build(address(hook), account, _recordRedemptionData(MAPOLLO_MARKET, 0, true))
        );
    }

    /// @dev Midas' mAPOLLO data feed goes stale under multi-day vm.warp on a fork ("DF: feed is
    ///      unhealthy"); in production keepers keep it fresh. Freeze SY.exchangeRate at its last
    ///      real value so router swaps and PT-rate reads keep working across warps.
    function _freezeSyRate() internal {
        uint256 rate = IStandardizedYield(sy).exchangeRate();
        vm.mockCall(sy, abi.encodeWithSelector(IStandardizedYield.exchangeRate.selector), abi.encode(rate));
    }

    function _revertSelector(bytes memory ret) internal pure returns (bytes4 sel) {
        assembly {
            sel := mload(add(ret, 32))
        }
    }

    /*//////////////////////////////////////////////////////////////
                            DATA ENCODING HELPERS
    //////////////////////////////////////////////////////////////*/

    function _recordPurchaseData(
        address market_,
        uint256 amount_,
        uint32 twap_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, twap_, usePrev_);
    }

    function _recordRedemptionData(
        address market_,
        uint256 amount_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, usePrev_);
    }

    /// @dev Builds buy PT data: tokenIn -> PT. Payload = abi.encode(ApproxParams, LimitOrderData)
    function _buildBuyPtData(
        address market_,
        address tokenIn_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 minPtOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1e15 });
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(guessPtOut, emptyLimit);

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(tokenIn_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minPtOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Builds sell/redeem PT data: PT -> tokenOut. Payload = abi.encode(LimitOrderData).
    ///      Routing (sell vs matured redeem) is decided by the hook from YT.isExpired().
    function _buildSellPtData(
        address market_,
        address inputToken_,
        address tokenOut_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(emptyLimit);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(inputToken_),
            bytes20(tokenOut_),
            bytes32(exactPtIn_),
            bytes32(uint256(0)),
            bytes32(minTokenOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }
}
