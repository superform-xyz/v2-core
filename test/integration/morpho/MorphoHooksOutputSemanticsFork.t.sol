// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// Superform
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperHook, ISuperHookResultOutflow, ISuperHookInflowOutflow } from "../../../src/interfaces/ISuperHook.sol";
// MONEY_MARKET (V1 lender)
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
// LOAN V1 borrower
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
// LOAN V2 borrower
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { MorphoSupplyHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";

/// @title MorphoHooksOutputSemanticsFork
/// @notice Real Ethereum-mainnet fork, real Morpho Blue singleton, TWO real markets (WBTC/USDC and
///         wstETH/WETH). Every one of the 13 Morpho hooks is executed for real by the account (this
///         contract runs the exact `build()` output, pre/postExecute included) and the suite asserts:
///         - OUTPUT semantics: `outAmount` / `outToken` (and `usedShares` / `asset` for the OUTFLOW
///           hook) against measured on-chain deltas of the real Morpho position and wallet balances;
///         - SIZING semantics: `amountRoles` / `decodeAmounts` / `replaceCalldataAmounts` on real
///           market calldata, and that an OMS-resized payload executes with the resized amount.
///         MONEY_MARKET (SUP-21005 / SUP-21024): lend sizes as IN/ASSETS, outAmount = supply-share
///         delta, outToken = header market key (never the loan token); withdraw keeps
///         [IN/ASSETS, IN/SHARES] with XOR, outAmount = loan-token assets, usedShares = shares burned.
/// @dev Each hook keeps a per-(hook, account) transient execution context; `_run` opens a fresh one
///      (`setExecutionContext`) so the same hook can be driven several times in one test.
contract MorphoHooksOutputSemanticsForkTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    struct Mkt {
        address loan;
        address coll;
        address oracle;
        address irm;
        uint256 lltv;
        Id id;
        address key; // registry market key (== computeMarketKey) — MONEY_MARKET header identity
        uint256 lendAmt;
        uint256 collAmt;
        uint256 borrowAmt;
        uint256 extraBorrow;
        uint256 partialRepay;
    }

    // MONEY_MARKET
    MorphoLendHook internal lendHook;
    MorphoWithdrawHook internal withdrawHook;
    // LOAN V1
    MorphoSupplyHook internal v1Supply;
    MorphoBorrowHook internal v1Borrow;
    MorphoRepayHook internal v1Repay;
    MorphoSupplyAndBorrowHook internal v1Open;
    MorphoRepayAndWithdrawHook internal v1Close;
    // LOAN V2
    MorphoSupplyAndBorrowHookV2 internal v2Open;
    MorphoRepayHookV2 internal v2Repay;
    MorphoRepayAndWithdrawHookV2 internal v2Close;
    MorphoSupplyHookV2 internal v2Pledge;
    MorphoBorrowHookV2 internal v2Borrow;
    MorphoWithdrawCollateralHookV2 internal v2Release;

    Mkt internal A; // WBTC/USDC
    Mkt internal B; // wstETH/WETH
    address internal constant B_ORACLE = 0x2a01EB9496094dA03c4E364Def50f5aD1280AD72;
    uint256 internal constant A_LLTV = 860_000_000_000_000_000; // 86%
    uint256 internal constant B_LLTV = 945_000_000_000_000_000; // 94.5%
    // Mainnet Morpho markets share the single AdaptiveCurveIRM; the constant is named after the WBTC/USDC market
    address internal constant ADAPTIVE_CURVE_IRM = MORPHO_IRM_WBTC_USDC;
    uint256 internal constant LTV_RATIO = 500_000_000_000_000_000; // 50% (V1 supply-and-borrow)
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        v1Supply = new MorphoSupplyHook(MORPHO);
        v1Borrow = new MorphoBorrowHook(MORPHO);
        v1Repay = new MorphoRepayHook(MORPHO);
        v1Open = new MorphoSupplyAndBorrowHook(MORPHO);
        v1Close = new MorphoRepayAndWithdrawHook(MORPHO);
        v2Open = new MorphoSupplyAndBorrowHookV2(MORPHO);
        v2Repay = new MorphoRepayHookV2(MORPHO);
        v2Close = new MorphoRepayAndWithdrawHookV2(MORPHO);
        v2Pledge = new MorphoSupplyHookV2(MORPHO);
        v2Borrow = new MorphoBorrowHookV2(MORPHO);
        v2Release = new MorphoWithdrawCollateralHookV2(MORPHO);

        A = _mkt(CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, ADAPTIVE_CURVE_IRM, A_LLTV);
        A.lendAmt = 10_000e6;
        A.collAmt = 1e6; // 0.01 WBTC
        A.borrowAmt = 400e6;
        A.extraBorrow = 100e6;
        A.partialRepay = 50e6;

        B = _mkt(CHAIN_1_WETH, CHAIN_1_WST_ETH, B_ORACLE, ADAPTIVE_CURVE_IRM, B_LLTV);
        B.lendAmt = 1e18;
        B.collAmt = 1e18;
        B.borrowAmt = 0.3e18;
        B.extraBorrow = 0.1e18;
        B.partialRepay = 0.05e18;

        _assertMarketExists(A);
        _assertMarketExists(B);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                  MONEY_MARKET: LEND (INFLOW) — both markets
    //////////////////////////////////////////////////////////////*/

    /// @notice outAmount = supply-share delta of the real position (never the loan-token spend);
    ///         outToken = header market key (never the loan token, never the singleton).
    function test_Fork_Lend_OutputIsShareDelta_OutTokenIsMarketKey() external {
        _lendCase(A);
        _lendCase(B);
    }

    function _lendCase(Mkt memory m) internal {
        _getTokens(m.loan, address(this), m.lendAmt);
        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        uint256 sharesBefore = _supplyShares(m);

        _run(address(lendHook), _lend(m, m.lendAmt));

        uint256 sharesDelta = _supplyShares(m) - sharesBefore;
        assertGt(sharesDelta, 0, "supplied");
        assertEq(balBefore - IERC20(m.loan).balanceOf(address(this)), m.lendAmt, "exact loan token spent");
        assertEq(lendHook.getOutAmount(address(this)), sharesDelta, "outAmount == supply-share delta");
        assertTrue(lendHook.getOutAmount(address(this)) != m.lendAmt, "outAmount is shares, not assets");
        assertEq(lendHook.getOutToken(address(this)), m.key, "outToken == market key");
        assertTrue(lendHook.getOutToken(address(this)) != m.loan, "outToken != loan token");
        assertTrue(lendHook.getOutToken(address(this)) != MORPHO, "outToken != singleton");
        assertEq(lendHook.asset(), m.loan, "asset (fee token) = loan token");
    }

    /// @notice OMS sizing: lend is ONE IN/ASSETS slot at offset 132; a resized payload executes with
    ///         the resized amount on the real market.
    function test_Fork_Lend_SizedByOms_ReplacedAmountExecutes() external {
        _lendSizedCase(A, 2500e6);
        _lendSizedCase(B, 0.25e18);
    }

    function _lendSizedCase(Mkt memory m, uint256 sized) internal {
        // roles (IN/ASSETS) are pinned in the unit sizing suite; here: the slot is real and resizable
        bytes memory data = _lend(m, m.lendAmt);
        assertEq(lendHook.decodeAmounts(data)[0], m.lendAmt, "decode");
        bytes memory resized = lendHook.replaceCalldataAmounts(data, _one(sized));
        assertEq(resized.length, data.length, "length unchanged");
        assertEq(lendHook.decodeAmounts(resized)[0], sized, "replaced at offset 132");

        _getTokens(m.loan, address(this), sized);
        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(lendHook), resized);
        assertEq(balBefore - IERC20(m.loan).balanceOf(address(this)), sized, "executed with the resized amount");
        assertGt(lendHook.getOutAmount(address(this)), 0, "shares out");
    }

    /*//////////////////////////////////////////////////////////////
                 MONEY_MARKET: WITHDRAW (OUTFLOW) — both markets
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw-by-shares (full): outAmount = loan-token assets received, outToken = loan
    ///         token, usedShares = shares actually burned, asset = loan token; position cleared.
    function test_Fork_Withdraw_ByShares_OutputIsLoanAssets_UsedSharesBurned() external {
        _withdrawFullCase(A);
        _withdrawFullCase(B);
    }

    function _withdrawFullCase(Mkt memory m) internal {
        _getTokens(m.loan, address(this), m.lendAmt);
        _run(address(lendHook), _lend(m, m.lendAmt));
        uint256 shares = _supplyShares(m);
        assertGt(shares, 0);

        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(withdrawHook), _withdraw(m, 0, shares));

        uint256 received = IERC20(m.loan).balanceOf(address(this)) - balBefore;
        assertGt(received, 0, "loan token returned");
        assertApproxEqAbs(received, m.lendAmt, 2, "full round-trip (<= 2 wei share rounding)");
        assertEq(withdrawHook.getOutAmount(address(this)), received, "outAmount == loan-token assets received");
        assertEq(withdrawHook.getOutToken(address(this)), m.loan, "outToken == loan token");
        assertEq(ISuperHookResultOutflow(address(withdrawHook)).usedShares(), shares, "usedShares == shares burned");
        assertEq(withdrawHook.asset(), m.loan, "asset == loan token");
        assertEq(_supplyShares(m), 0, "position cleared");
    }

    /// @notice MONEY_MARKET withdraw main is sized on slot 1 (SHARES): starting from an assets-denominated
    ///         payload, the OMS replace writes shares and zeroes assets, and the resized payload burns
    ///         exactly those shares on the real market. Slot 0 (ASSETS) stays for the Morpho XOR.
    function test_Fork_Withdraw_MmSizedOnSharesSlot_ZeroesAssets_Executes() external {
        _withdrawSizedCase(A);
        _withdrawSizedCase(B);
    }

    function _withdrawSizedCase(Mkt memory m) internal {
        // roles ([IN/ASSETS, IN/SHARES]) are pinned in the unit sizing suite; here: slot 1 sizes for real
        _getTokens(m.loan, address(this), m.lendAmt);
        _run(address(lendHook), _lend(m, m.lendAmt));
        uint256 shares = _supplyShares(m);
        uint256 half = shares / 2;

        // OMS starts from an assets-denominated intent and sizes the SHARES slot
        bytes memory data = _withdraw(m, m.lendAmt / 2, 0);
        bytes memory resized = withdrawHook.replaceCalldataAmounts(data, _two(0, half));
        uint256[] memory dec = withdrawHook.decodeAmounts(resized);
        assertEq(dec[0], 0, "assets zeroed");
        assertEq(dec[1], half, "shares written");

        // XOR still enforced at replace time
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.replaceCalldataAmounts(data, _two(1, 1));

        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(withdrawHook), resized);
        assertEq(shares - _supplyShares(m), half, "exactly the sized shares burned");
        assertEq(ISuperHookResultOutflow(address(withdrawHook)).usedShares(), half, "usedShares == sized shares");
        assertEq(
            withdrawHook.getOutAmount(address(this)),
            IERC20(m.loan).balanceOf(address(this)) - balBefore,
            "outAmount == loan assets received"
        );
        assertEq(withdrawHook.getOutToken(address(this)), m.loan);
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN V1 BORROWER HOOKS — both markets
    //////////////////////////////////////////////////////////////*/

    /// @notice V1 pledge: outAmount = collateral spent, outToken = collateral token
    function test_Fork_V1_Supply_OutputIsCollateralSpent() external {
        _v1SupplyCase(A);
        _v1SupplyCase(B);
    }

    function _v1SupplyCase(Mkt memory m) internal {
        _assertOneTokenRole(address(v1Supply));
        _getTokens(m.coll, address(this), m.collAmt);
        uint256 balBefore = IERC20(m.coll).balanceOf(address(this));

        _run(address(v1Supply), _v1Supply(m, m.collAmt));

        assertEq(balBefore - IERC20(m.coll).balanceOf(address(this)), m.collAmt, "collateral spent");
        assertEq(_collateral(m), m.collAmt, "position collateral");
        assertEq(v1Supply.getOutAmount(address(this)), m.collAmt, "outAmount == collateral spent");
        assertEq(v1Supply.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /// @notice V1 borrow after pledge: outAmount = loan token received, outToken = loan token
    function test_Fork_V1_Borrow_OutputIsLoanReceived() external {
        _v1BorrowCase(A);
        _v1BorrowCase(B);
    }

    function _v1BorrowCase(Mkt memory m) internal {
        _assertOneTokenRole(address(v1Borrow));
        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v1Supply), _v1Supply(m, m.collAmt));

        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v1Borrow), _v1Borrow(m, m.borrowAmt));

        assertEq(IERC20(m.loan).balanceOf(address(this)) - balBefore, m.borrowAmt, "exact loan received");
        assertGt(_borrowShares(m), 0, "debt opened");
        assertEq(v1Borrow.getOutAmount(address(this)), m.borrowAmt, "outAmount == loan received");
        assertEq(v1Borrow.getOutToken(address(this)), m.loan, "outToken == loan token");
    }

    /// @notice V1 supply-and-borrow: amount = collateral, loan derived from ltvRatio via the market
    ///         oracle; outAmount = collateral spent, outToken = collateral token (V1 semantics).
    function test_Fork_V1_SupplyAndBorrow_OutputIsCollateralSpent_LoanDerived() external {
        _v1OpenCase(A);
        _v1OpenCase(B);
    }

    function _v1OpenCase(Mkt memory m) internal {
        _assertOneTokenRole(address(v1Open));
        _getTokens(m.coll, address(this), m.collAmt);
        uint256 collBefore = IERC20(m.coll).balanceOf(address(this));
        uint256 loanBefore = IERC20(m.loan).balanceOf(address(this));
        uint256 expectedLoan = v1Open.deriveLoanAmount(m.collAmt, LTV_RATIO, m.lltv, m.oracle);
        assertGt(expectedLoan, 0);

        _run(address(v1Open), _v1Borrow(m, m.collAmt)); // same 230-byte layout: amount = collateral

        assertEq(collBefore - IERC20(m.coll).balanceOf(address(this)), m.collAmt, "collateral spent");
        assertEq(IERC20(m.loan).balanceOf(address(this)) - loanBefore, expectedLoan, "derived loan received");
        assertEq(v1Open.getOutAmount(address(this)), m.collAmt, "outAmount == collateral spent");
        assertEq(v1Open.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /// @notice V1 partial repay: outAmount = loan token consumed, outToken = loan token; debt reduced
    function test_Fork_V1_Repay_Partial_OutputIsLoanConsumed() external {
        _v1RepayCase(A);
        _v1RepayCase(B);
    }

    function _v1RepayCase(Mkt memory m) internal {
        _assertOneTokenRole(address(v1Repay));
        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v1Supply), _v1Supply(m, m.collAmt));
        _run(address(v1Borrow), _v1Borrow(m, m.borrowAmt));
        uint256 debtBefore = _borrowShares(m);

        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v1Repay), _v1Repay(m, m.partialRepay, false));

        assertEq(balBefore - IERC20(m.loan).balanceOf(address(this)), m.partialRepay, "exact loan consumed");
        assertLt(_borrowShares(m), debtBefore, "debt reduced");
        assertGt(_borrowShares(m), 0, "residual debt");
        assertEq(v1Repay.getOutAmount(address(this)), m.partialRepay, "outAmount == loan consumed");
        assertEq(v1Repay.getOutToken(address(this)), m.loan, "outToken == loan token");
    }

    /// @notice V1 full repay + withdraw: outAmount = collateral returned, outToken = collateral;
    ///         position fully closed (debt and collateral zero).
    function test_Fork_V1_RepayAndWithdraw_Full_OutputIsCollateralReturned() external {
        _v1CloseCase(A);
        _v1CloseCase(B);
    }

    function _v1CloseCase(Mkt memory m) internal {
        _assertOneTokenRole(address(v1Close));
        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v1Supply), _v1Supply(m, m.collAmt));
        _run(address(v1Borrow), _v1Borrow(m, m.borrowAmt));
        // interest buffer on top of the borrowed balance
        _getTokens(m.loan, address(this), IERC20(m.loan).balanceOf(address(this)) + m.partialRepay);

        uint256 collBefore = IERC20(m.coll).balanceOf(address(this));
        _run(address(v1Close), _v1Repay(m, 0, true)); // isFullRepayment: amount ignored

        uint256 collReturned = IERC20(m.coll).balanceOf(address(this)) - collBefore;
        assertEq(collReturned, m.collAmt, "all collateral returned");
        assertEq(_borrowShares(m), 0, "debt cleared");
        assertEq(_collateral(m), 0, "collateral cleared");
        assertEq(v1Close.getOutAmount(address(this)), collReturned, "outAmount == collateral returned");
        assertEq(v1Close.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /// @notice V1 borrower family sizing: one IN/TOKEN slot at offset 132; resized pledge executes
    ///         with the resized amount.
    function test_Fork_V1_Sizing_RoundTrip_ResizedPledgeExecutes() external {
        _v1SizingCase(A, 2e6);
        _v1SizingCase(B, 2e18);
    }

    function _v1SizingCase(Mkt memory m, uint256 sized) internal {
        bytes memory data = _v1Supply(m, m.collAmt);
        assertEq(v1Supply.decodeAmounts(data)[0], m.collAmt);
        bytes memory resized = v1Supply.replaceCalldataAmounts(data, _one(sized));
        assertEq(resized.length, data.length);
        assertEq(v1Supply.decodeAmounts(resized)[0], sized);

        // borrow / repay / composite layouts also round-trip on offset 132
        bytes memory b = _v1Borrow(m, m.borrowAmt);
        assertEq(v1Borrow.decodeAmounts(v1Borrow.replaceCalldataAmounts(b, _one(7)))[0], 7);
        assertEq(v1Open.decodeAmounts(v1Open.replaceCalldataAmounts(b, _one(8)))[0], 8);
        bytes memory r = _v1Repay(m, m.partialRepay, false);
        assertEq(v1Repay.decodeAmounts(v1Repay.replaceCalldataAmounts(r, _one(9)))[0], 9);
        assertEq(v1Close.decodeAmounts(v1Close.replaceCalldataAmounts(r, _one(10)))[0], 10);

        _getTokens(m.coll, address(this), sized);
        _run(address(v1Supply), resized);
        assertEq(_collateral(m), sized, "resized pledge executed");
        assertEq(v1Supply.getOutAmount(address(this)), sized);
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN V2 BORROWER HOOKS — both markets
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 open: [collateral IN/TOKEN, borrow OUT/TOKEN]; outAmount = loan received, outToken = loan
    function test_Fork_V2_Open_OutputIsLoanReceived() external {
        _v2OpenCase(A);
        _v2OpenCase(B);
    }

    function _v2OpenCase(Mkt memory m) internal {
        _assertTwoTokenRoles(address(v2Open));
        bytes memory data = _v2(m, m.collAmt, m.borrowAmt);
        uint256[] memory dec = v2Open.decodeAmounts(data);
        assertEq(dec[0], m.collAmt);
        assertEq(dec[1], m.borrowAmt);

        _getTokens(m.coll, address(this), m.collAmt);
        uint256 loanBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v2Open), data);

        assertEq(IERC20(m.loan).balanceOf(address(this)) - loanBefore, m.borrowAmt, "exact borrow");
        assertEq(_collateral(m), m.collAmt, "collateral posted");
        assertEq(v2Open.getOutAmount(address(this)), m.borrowAmt, "outAmount == loan received");
        assertEq(v2Open.getOutToken(address(this)), m.loan, "outToken == loan token");
    }

    /// @notice V2 open resized by the OMS on both slots executes with the resized amounts
    function test_Fork_V2_Open_SizedByOms_ReplacedAmountsExecute() external {
        _v2OpenSizedCase(A, 2e6, 700e6);
        _v2OpenSizedCase(B, 2e18, 0.5e18);
    }

    function _v2OpenSizedCase(Mkt memory m, uint256 coll, uint256 borrow) internal {
        bytes memory resized = v2Open.replaceCalldataAmounts(_v2(m, m.collAmt, m.borrowAmt), _two(coll, borrow));
        uint256[] memory dec = v2Open.decodeAmounts(resized);
        assertEq(dec[0], coll);
        assertEq(dec[1], borrow);

        _getTokens(m.coll, address(this), coll);
        uint256 loanBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v2Open), resized);
        assertEq(_collateral(m), coll, "resized collateral");
        assertEq(IERC20(m.loan).balanceOf(address(this)) - loanBefore, borrow, "resized borrow");
        assertEq(v2Open.getOutAmount(address(this)), borrow);
    }

    /// @notice V2 standalone pledge: outAmount = 0 (nothing produced), outToken = collateral (classification)
    function test_Fork_V2_Pledge_OutputZero_OutTokenCollateral() external {
        _v2PledgeCase(A);
        _v2PledgeCase(B);
    }

    function _v2PledgeCase(Mkt memory m) internal {
        bytes memory data = _v2(m, m.collAmt, 0);
        assertEq(v2Pledge.decodeAmounts(data)[0], m.collAmt);
        assertEq(v2Pledge.amountRoles("").length, v2Pledge.decodeAmounts(data).length, "roles align with slots");

        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v2Pledge), data);

        assertEq(_collateral(m), m.collAmt, "collateral posted");
        assertEq(v2Pledge.getOutAmount(address(this)), 0, "outAmount == 0");
        assertEq(v2Pledge.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /// @notice V2 standalone borrow: [OUT/TOKEN]; outAmount = loan received, outToken = loan
    function test_Fork_V2_Borrow_OutputIsLoanReceived() external {
        _v2BorrowCase(A);
        _v2BorrowCase(B);
    }

    function _v2BorrowCase(Mkt memory m) internal {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = v2Borrow.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v2Pledge), _v2(m, m.collAmt, 0));

        uint256 loanBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v2Borrow), _v2(m, m.extraBorrow, 0));

        assertEq(IERC20(m.loan).balanceOf(address(this)) - loanBefore, m.extraBorrow, "exact borrow");
        assertEq(v2Borrow.getOutAmount(address(this)), m.extraBorrow, "outAmount == loan received");
        assertEq(v2Borrow.getOutToken(address(this)), m.loan, "outToken == loan token");
    }

    /// @notice V2 standalone repay (partial cap): outAmount = 0, outToken = loan (classification);
    ///         debt reduced by exactly the cap.
    function test_Fork_V2_Repay_Partial_OutputZero_DebtReduced() external {
        _v2RepayCase(A);
        _v2RepayCase(B);
    }

    function _v2RepayCase(Mkt memory m) internal {
        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v2Open), _v2(m, m.collAmt, m.borrowAmt));
        uint256 debtBefore = _borrowShares(m);

        uint256 balBefore = IERC20(m.loan).balanceOf(address(this));
        _run(address(v2Repay), _v2(m, m.partialRepay, 0));

        assertEq(balBefore - IERC20(m.loan).balanceOf(address(this)), m.partialRepay, "cap consumed");
        assertLt(_borrowShares(m), debtBefore, "debt reduced");
        assertEq(v2Repay.getOutAmount(address(this)), 0, "outAmount == 0");
        assertEq(v2Repay.getOutToken(address(this)), m.loan, "outToken == loan token");
    }

    /// @notice V2 standalone release (partial): [OUT/TOKEN]; outAmount = collateral received, outToken = collateral
    function test_Fork_V2_Release_Partial_OutputIsCollateralReceived() external {
        _v2ReleaseCase(A);
        _v2ReleaseCase(B);
    }

    function _v2ReleaseCase(Mkt memory m) internal {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = v2Release.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));

        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v2Pledge), _v2(m, m.collAmt, 0));

        uint256 half = m.collAmt / 2;
        uint256 collBefore = IERC20(m.coll).balanceOf(address(this));
        _run(address(v2Release), _v2(m, half, 0));

        assertEq(IERC20(m.coll).balanceOf(address(this)) - collBefore, half, "exact collateral released");
        assertEq(_collateral(m), m.collAmt - half, "remaining collateral");
        assertEq(v2Release.getOutAmount(address(this)), half, "outAmount == collateral received");
        assertEq(v2Release.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /// @notice V2 close (repay all + withdraw all): [IN/TOKEN, OUT/TOKEN]; outAmount = collateral
    ///         returned, outToken = collateral; position fully closed.
    function test_Fork_V2_Close_Full_OutputIsCollateralReturned() external {
        _v2CloseCase(A);
        _v2CloseCase(B);
    }

    function _v2CloseCase(Mkt memory m) internal {
        _assertTwoTokenRoles(address(v2Close));
        _getTokens(m.coll, address(this), m.collAmt);
        _run(address(v2Open), _v2(m, m.collAmt, m.borrowAmt));
        _getTokens(m.loan, address(this), IERC20(m.loan).balanceOf(address(this)) + m.partialRepay);

        uint256 collBefore = IERC20(m.coll).balanceOf(address(this));
        _run(address(v2Close), _v2(m, MAX, MAX));

        uint256 returned = IERC20(m.coll).balanceOf(address(this)) - collBefore;
        assertEq(returned, m.collAmt, "all collateral returned");
        assertEq(_borrowShares(m), 0, "debt cleared");
        assertEq(_collateral(m), 0, "collateral cleared");
        assertEq(v2Close.getOutAmount(address(this)), returned, "outAmount == collateral returned");
        assertEq(v2Close.getOutToken(address(this)), m.coll, "outToken == collateral");
    }

    /*//////////////////////////////////////////////////////////////
                                 RUNNER
    //////////////////////////////////////////////////////////////*/

    /// @dev Executes the hook exactly as the account would: fresh execution context, then every
    ///      execution returned by build() (preExecute, protocol calls, postExecute) called from this
    ///      contract, which IS the account.
    function _run(address hook, bytes memory data) internal {
        ISuperHook(hook).setExecutionContext(address(this));
        Execution[] memory execs = ISuperHook(hook).build(address(0), address(this), data);
        for (uint256 i; i < execs.length; ++i) {
            (bool ok, bytes memory ret) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            require(ok, string(abi.encodePacked("execution[", vm.toString(i), "] failed: ", ret)));
        }
    }

    /*//////////////////////////////////////////////////////////////
                              STATE READERS
    //////////////////////////////////////////////////////////////*/

    function _supplyShares(Mkt memory m) internal view returns (uint256 s) {
        (s,,) = IMorphoStaticTyping(MORPHO).position(m.id, address(this));
    }

    function _borrowShares(Mkt memory m) internal view returns (uint256) {
        (, uint128 b,) = IMorphoStaticTyping(MORPHO).position(m.id, address(this));
        return uint256(b);
    }

    function _collateral(Mkt memory m) internal view returns (uint256) {
        (,, uint128 c) = IMorphoStaticTyping(MORPHO).position(m.id, address(this));
        return uint256(c);
    }

    function _assertMarketExists(Mkt memory m) internal view {
        (,,,, uint128 lastUpdate,) = IMorphoStaticTyping(MORPHO).market(m.id);
        assertGt(uint256(lastUpdate), 0, "market must exist on the fork");
    }

    function _assertOneTokenRole(address hook) internal view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = ISuperHookInflowOutflow(hook).amountRoles("");
        assertEq(meta.length, 1, "V1: one slot");
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN), "V1 stays TOKEN");
    }

    function _assertTwoTokenRoles(address hook) internal view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = ISuperHookInflowOutflow(hook).amountRoles("");
        assertEq(meta.length, 2, "V2 composite: two slots");
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /*//////////////////////////////////////////////////////////////
                                ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _mkt(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (Mkt memory m)
    {
        m.loan = loan;
        m.coll = coll;
        m.oracle = oracle;
        m.irm = irm;
        m.lltv = lltv;
        m.id = MarketParams({ loanToken: loan, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv }).id();
        m.key = address(uint160(uint256(Id.unwrap(m.id))));
    }

    // MONEY_MARKET lend (197): header (oracle id + MARKET KEY) + market + amount@132 + lltv@164 + usePrev@196
    function _lend(Mkt memory m, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, m.key, m.loan, m.coll, m.oracle, m.irm, amount, m.lltv, false);
    }

    // MONEY_MARKET withdraw (228): header (oracle id + MARKET KEY) + market + lltv@132 + assets@164 + shares@196
    function _withdraw(Mkt memory m, uint256 assets, uint256 shares) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, m.key, m.loan, m.coll, m.oracle, m.irm, m.lltv, assets, shares);
    }

    // LOAN V1 pledge (197): header (oracle id + SINGLETON) + market + amount@132 + lltv@164 + usePrev@196
    function _v1Supply(Mkt memory m, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, MORPHO, m.loan, m.coll, m.oracle, m.irm, amount, m.lltv, false);
    }

    // LOAN V1 borrow / supply-and-borrow (230): + amount@132 + ltvRatio@164 + usePrev@196 + lltv@197 + reserved
    function _v1Borrow(Mkt memory m, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID, MORPHO, m.loan, m.coll, m.oracle, m.irm, amount, LTV_RATIO, false, m.lltv, false
        );
    }

    // LOAN V1 repay / repay-and-withdraw (198): + amount@132 + lltv@164 + usePrev@196 + isFullRepayment@197
    function _v1Repay(Mkt memory m, uint256 amount, bool isFull) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                MORPHO_YS_ORACLE_ID, MORPHO, m.loan, m.coll, m.oracle, m.irm, amount, m.lltv, false, isFull
            );
    }

    // LOAN V2 (230): header (oracle id + SINGLETON) + market + amount1@132 + amount2@164 + usePrev@196 + lltv@197 +
    // reserved
    function _v2(Mkt memory m, uint256 a1, uint256 a2) internal pure returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID, MORPHO, m.loan, m.coll, m.oracle, m.irm, a1, a2, false, m.lltv, uint8(0)
        );
    }

    function _one(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _two(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }
}
