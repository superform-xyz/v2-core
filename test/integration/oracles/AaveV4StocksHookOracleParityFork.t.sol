// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { AaveV4ReserveKey } from "../../../src/libraries/AaveV4ReserveKey.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { ISuperHookInspector } from "../../../src/interfaces/ISuperHook.sol";

import { AaveV4SupplyHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4LendHook } from "../../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";

/*//////////////////////////////////////////////////////////////
                           TEST HARNESSES
//////////////////////////////////////////////////////////////*/

/// @title AaveV4ReserveKeyHarness
/// @notice Thin external wrapper around the `internal` library `AaveV4ReserveKey`, so its derivation and its
///         header pin can be exercised directly from a test (an `internal` function is not callable on a
///         library address, and `vm.expectRevert` needs a real external call boundary).
/// @dev The library itself is UNCHANGED by the oracle merge — this harness only re-exposes it.
contract AaveV4ReserveKeyHarness {
    /// @notice Library derivation of the SUPPLY (legacy two-word) key
    function computeReserveKey(address spoke, uint256 reserveId) external pure returns (address) {
        return AaveV4ReserveKey.computeReserveKey(spoke, reserveId);
    }

    /// @notice The exact pin every Aave V4 hook runs inside its pure decoder
    function requireHeaderKey(address headerKey, address spoke, uint256 reserveId) external pure {
        AaveV4ReserveKey.requireHeaderKey(headerKey, spoke, reserveId);
    }
}

/// @title AaveV4LoanHookReadHarness
/// @notice Exposes `BaseAaveV4LoanHookV2`'s `internal view` position reads (`_suppliedAssets`, `_totalDebt`)
///         through the REAL decoder (`_decodeAaveV4V2`), so a test can compare the exact spoke read a
///         deployed hook performs against the oracle's read of the matching registry key.
/// @dev Derives from the concrete PLEDGE hook so `_primaryReserveId` keeps its production meaning (the supply
///      reserve): no hook behaviour is re-implemented here, only made externally callable. The header pin
///      therefore runs on every call below exactly as it does in production.
contract AaveV4LoanHookReadHarness is AaveV4SupplyHookV2 {
    /// @notice `BaseAaveV4LoanHookV2._suppliedAssets` — the supply-reserve read, post full strict decode
    function suppliedAssets(bytes memory data, address account) external view returns (uint256) {
        return _suppliedAssets(_decodeAaveV4V2(data, true), account);
    }

    /// @notice `BaseAaveV4LoanHookV2._totalDebt` — the borrow-reserve read (drawn + premium), post decode
    function totalDebt(bytes memory data, address account) external view returns (uint256) {
        return _totalDebt(_decodeAaveV4V2(data, true), account);
    }
}

/// @title AaveV4IdleHookReadHarness
/// @notice Exposes `BaseAaveV4MoneyMarketHook._suppliedAssets` (and the idle decoder's header pin) for the
///         idle MONEY_MARKET side, derived from the concrete lend hook.
contract AaveV4IdleHookReadHarness is AaveV4LendHook {
    /// @notice `BaseAaveV4MoneyMarketHook._suppliedAssets` — the idle supply read, post full strict decode
    function idleSuppliedAssets(bytes memory data, address account) external view returns (uint256) {
        return _suppliedAssets(_decodeIdle(data), account);
    }
}

/// @title AaveV4StocksHookOracleParityFork
/// @author Superform Labs
/// @notice Pins THE back-compat invariant of the Aave V4 oracle merge against the live Base tokenized-stocks
///         market (MAG7 spoke: seven equities at 8 decimals + USDC at 6): `src/libraries/AaveV4ReserveKey.sol`
///         was deliberately left UNTOUCHED so all 14 deployed Aave V4 hooks keep byte-identical creation code
///         and their deployed addresses. The consequence this file proves, reserve by reserve and on real
///         positions: EVERY hook header pins the SUPPLY key (the legacy two-word derivation), the new DEBT key
///         exists ONLY in the registry for oracle / NAV consumers, and the merge moved nothing in the hooks'
///         key space.
/// @dev Four statements, all against live chain reads — no magnitude is hardcoded:
///      1. `AaveV4ReserveKey.computeReserveKey` == `registry.computeReserveKey` == the literal off-chain
///         formula `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))`, for all 8 reserves.
///      2. A DEBT key is never a hook header: it differs from its own reserve's SUPPLY key AND from every
///         other live reserve's SUPPLY key, and `requireHeaderKey` rejects it with `RESERVE_KEY_MISMATCH`.
///      3. Hook-read vs oracle-read parity on BOTH legs of a real borrower, through the hooks' own decoder
///         and position-read helpers (see `AaveV4LoanHookReadHarness`).
///      4. Per-op primary-side mapping for all six V2 hooks plus the two idle hooks, asserted through the
///         production `inspect()` path, which runs the same pure decoder — and therefore the same pin — as
///         `build()` / `preExecute()`.
/// @dev Deliberately disjoint from `AaveV4BaseEquitiesE2EFork` (aggregation / double-count / ledger-slot
///      hazards of the two legs) and `AaveV4HeaderIdentityE2EFork` (Ethereum Main Spoke, full userOp path).
///      This file is the KEY-SPACE and HOOK-PARITY file for the Base stocks market.
/// @dev SCOPE LIMIT — THE `premium` TERM IS ZERO AT THIS BLOCK. Statement 3 above pins hook/oracle parity on
///      the debt leg through `drawn + premium` (`BaseAaveV4LoanHookV2._totalDebt` against
///      `AaveV4ReserveOracle.getBalanceOfOwner`), but the premium component is EXACTLY ZERO everywhere in
///      this market at `FORK_BLOCK`: `getUserDebt(7, BORROWER)` is `(50032162, 0)` and `getReserveDebt(7)`
///      is `(50373206, 0)`, and reserve 7 is the only reserve with any debt. The parity statement is still
///      exact — hook and oracle perform the IDENTICAL read, so they agree whatever the components are — but
///      it is evidence for the `drawn` term only: deleting `+ premiumDebt` from BOTH sides, or from the
///      oracle alone, would leave this suite green. That is acknowledged, not assumed:
///      `test_StocksParity_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite` asserts it. THE
///      SUMMATION ITSELF IS COVERED IN THE UNIT SUITE
///      (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`: `test_debt_balanceOfOwner_isDrawnPlusPremium`,
///      `test_debt_balanceOfOwner_premiumOnly`, `test_fuzz_debt_balanceOfOwner_sumNeverTruncates`), where
///      the premium is settable on a mock spoke. Do NOT mock a premium onto a fork test and do not re-pin
///      the block to manufacture one.
contract AaveV4StocksHookOracleParityFork is Test {
    /*//////////////////////////////////////////////////////////////
                         LIVE BASE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // aave-address-book AaveV4Base.sol
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    address internal constant EQUITIES_HUB = 0xa4d5947Eb727A052bae69C593FfC84247EC9864E;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant TSLAc = 0xb2000000000000000000001e800a7f5189430cD0;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal constant AAPL_ID = 0;
    uint256 internal constant TSLA_ID = 6;
    uint256 internal constant USDC_ID = 7;
    uint256 internal constant RESERVE_COUNT = 8;

    /// @dev live positions at the pinned block
    address internal constant BORROWER = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F; // stock + USDC supply, USDC debt
    address internal constant WHALE = 0x9e3787f9f7f0fF7Eea9e36628BecA431B61AE647; // supply only

    uint256 internal constant FORK_BLOCK = 51_778_000;

    /// @dev nonzero header oracle id — the decoders reject bytes32(0) with ORACLE_ID_NOT_VALID
    bytes32 internal constant HEADER_ORACLE_ID = keccak256("AaveV4StocksHookOracleParityFork");

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;

    address[] internal supplyKeys; // index == reserveId
    address[] internal debtKeys; // index == reserveId

    AaveV4ReserveKeyHarness internal keyLib;
    AaveV4LoanHookReadHarness internal loanReader;
    AaveV4IdleHookReadHarness internal idleReader;

    AaveV4SupplyHookV2 internal pledgeHook; // PLEDGE  — primary: supply reserve
    AaveV4WithdrawHookV2 internal releaseHook; // RELEASE — primary: supply reserve
    AaveV4SupplyAndBorrowHookV2 internal openHook; // OPEN    — primary: supply reserve
    AaveV4RepayAndWithdrawHookV2 internal closeHook; // CLOSE   — primary: supply reserve
    AaveV4BorrowHookV2 internal borrowHook; // BORROW  — primary: BORROW reserve
    AaveV4RepayHookV2 internal repayHook; // REPAY   — primary: BORROW reserve
    AaveV4LendHook internal lendHook; // idle lend   — primary: supply reserve
    AaveV4RedeemHook internal redeemHook; // idle redeem — primary: supply reserve

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(address(new SuperLedgerConfiguration()), address(registry));

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (address supplyKey, address debtKey) = registry.registerReserve(MAG7_SPOKE, id);
            supplyKeys.push(supplyKey);
            debtKeys.push(debtKey);
        }

        keyLib = new AaveV4ReserveKeyHarness();
        loanReader = new AaveV4LoanHookReadHarness();
        idleReader = new AaveV4IdleHookReadHarness();

        pledgeHook = new AaveV4SupplyHookV2();
        releaseHook = new AaveV4WithdrawHookV2();
        openHook = new AaveV4SupplyAndBorrowHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();
        borrowHook = new AaveV4BorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        lendHook = new AaveV4LendHook();
        redeemHook = new AaveV4RedeemHook();
    }

    /*//////////////////////////////////////////////////////////////
        A. THE BACK-COMPAT GUARANTEE — ONE SUPPLY-KEY DERIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice For every one of the 8 live reserves, the untouched library, the registry's `public pure`
    ///         accessor and the literal off-chain formula all produce the SAME address, and that address is
    ///         the key the registry actually bound to the SUPPLY side. This is the guarantee that keeps all
    ///         14 deployed hooks and every off-chain indexer correct across the merge.
    function test_StocksKeySpace_SupplyKey_LibraryRegistryAndLiteralFormulaAgree() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            address literal = address(uint160(uint256(keccak256(abi.encode(MAG7_SPOKE, id)))));

            assertEq(keyLib.computeReserveKey(MAG7_SPOKE, id), literal, "library == literal two-word formula");
            assertEq(registry.computeReserveKey(MAG7_SPOKE, id), literal, "registry == literal two-word formula");
            assertEq(
                registry.computeReserveKey(MAG7_SPOKE, id),
                keyLib.computeReserveKey(MAG7_SPOKE, id),
                "registry delegates to the untouched library"
            );
            assertEq(supplyKeys[id], literal, "the registered SUPPLY key IS the legacy derivation");

            (,,,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(literal);
            assertTrue(side == AaveV4ReserveRegistryV2.Side.SUPPLY, "the legacy derivation binds to the SUPPLY leg");
        }
    }

    /// @notice The DEBT key is a strictly additive, domain-separated third-word derivation: it reproduces
    ///         `keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))` for all 8 reserves and the domain
    ///         word is exactly `keccak256("AaveV4ReserveRegistryV2.DEBT")`. Nothing about it reaches the
    ///         library the hooks link against.
    function test_StocksKeySpace_DebtKey_IsDomainSeparatedThirdWord() public view {
        assertEq(registry.DEBT_KEY_DOMAIN(), keccak256("AaveV4ReserveRegistryV2.DEBT"), "debt domain separator");

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            address literalDebt =
                address(uint160(uint256(keccak256(abi.encode(MAG7_SPOKE, id, registry.DEBT_KEY_DOMAIN())))));
            assertEq(registry.computeDebtKey(MAG7_SPOKE, id), literalDebt, "registry == literal three-word formula");
            assertEq(debtKeys[id], literalDebt, "the registered DEBT key IS the three-word derivation");

            (,,,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(literalDebt);
            assertTrue(side == AaveV4ReserveRegistryV2.Side.DEBT, "the third-word derivation binds to the DEBT leg");
        }
    }

    /*//////////////////////////////////////////////////////////////
       B. NO HOOK HEADER CAN EVER BE A DEBT KEY (AND VICE VERSA)
    //////////////////////////////////////////////////////////////*/

    /// @notice Across the whole live stocks market, the DEBT key of any reserve differs from the SUPPLY key of
    ///         its own reserve AND from the SUPPLY key of every other live reserve. A header key is therefore
    ///         never mistakable for a debt key in either direction, so the hooks' key space is disjoint from
    ///         the oracle-only debt key space. All 16 keys are pairwise distinct.
    function test_StocksKeySpace_DebtKeysNeverCollideWithAnyLiveHeaderKey() public view {
        for (uint256 i; i < RESERVE_COUNT; ++i) {
            assertTrue(debtKeys[i] != supplyKeys[i], "debt key != own reserve's supply key");
            for (uint256 j; j < RESERVE_COUNT; ++j) {
                assertTrue(debtKeys[i] != supplyKeys[j], "debt key != ANY live reserve's supply key");
                if (i == j) continue;
                assertTrue(supplyKeys[i] != supplyKeys[j], "supply keys pairwise distinct");
                assertTrue(debtKeys[i] != debtKeys[j], "debt keys pairwise distinct");
            }
        }
    }

    /// @notice The library pin itself: for each of the 8 live reserves `requireHeaderKey` ACCEPTS the SUPPLY
    ///         key and REVERTS `RESERVE_KEY_MISMATCH` on that reserve's DEBT key, on another reserve's SUPPLY
    ///         key and on another reserve's DEBT key. Exercised through `AaveV4ReserveKeyHarness` because
    ///         `requireHeaderKey` is an `internal` library function.
    function test_StocksKeySpace_RequireHeaderKey_AcceptsSupplyRejectsDebt() public {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            // accepted: the SUPPLY key of this very reserve
            keyLib.requireHeaderKey(supplyKeys[id], MAG7_SPOKE, id);

            // rejected: this reserve's DEBT key
            vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
            keyLib.requireHeaderKey(debtKeys[id], MAG7_SPOKE, id);

            uint256 other = (id + 1) % RESERVE_COUNT;

            // rejected: a different live reserve's SUPPLY key
            vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
            keyLib.requireHeaderKey(supplyKeys[other], MAG7_SPOKE, id);

            // rejected: a different live reserve's DEBT key
            vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
            keyLib.requireHeaderKey(debtKeys[other], MAG7_SPOKE, id);
        }
    }

    /// @notice The same rejection reaches every production decode path: a real hook's `inspect()` — which runs
    ///         the identical pure decoder as `build()` / `preExecute()` — reverts `RESERVE_KEY_MISMATCH` when
    ///         the header carries the DEBT key of its own primary reserve instead of the SUPPLY key. Pinned
    ///         on a stock-collateral / USDC-debt position, for a supply-primary and a debt-primary hook.
    function test_StocksHookHeaders_RejectDebtKeyInHeader_OnRealHooks() public {
        // PLEDGE: primary is the supply reserve (AAPL) — header carrying AAPL's DEBT key must fail
        bytes memory pledgeWithDebtHeader = _loanData(debtKeys[AAPL_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);
        vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
        ISuperHookInspector(address(pledgeHook)).inspect(pledgeWithDebtHeader);

        // BORROW: primary is the BORROW reserve (USDC) — header carrying USDC's DEBT key must fail too,
        // even though this op's economics ARE the debt leg. The header is a SUPPLY key, always.
        bytes memory borrowWithDebtHeader = _loanData(debtKeys[USDC_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e6, 0);
        vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
        ISuperHookInspector(address(borrowHook)).inspect(borrowWithDebtHeader);

        // idle lend on a stock reserve: header carrying the DEBT key must fail
        bytes memory idleWithDebtHeader = _idleData(debtKeys[TSLA_ID], TSLAc, TSLA_ID, 1e8);
        vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
        ISuperHookInspector(address(lendHook)).inspect(idleWithDebtHeader);
    }

    /*//////////////////////////////////////////////////////////////
       C. HOOK-READ vs ORACLE-READ PARITY ON REAL LIVE POSITIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice THE correctness statement: on a real leveraged Base position, the oracle's read of a registry
    ///         key equals the spoke read the hook code performs for the same leg — BOTH legs. The hook-side
    ///         numbers come from `BaseAaveV4LoanHookV2._suppliedAssets` / `._totalDebt` executed behind the
    ///         production strict decoder (`AaveV4LoanHookReadHarness`, a subclass of the deployed PLEDGE hook
    ///         — the helpers are `internal`, so a subclass is the only way to call the real code), not from
    ///         re-implemented calls. Hook-resolved and oracle-resolved amounts therefore cannot disagree.
    /// @dev PREMIUM CAVEAT: the debt-leg assertion `hookUsdcDebt == drawn + premium` is exact, but `premium`
    ///      is zero at this block (asserted inline below), so it pins `drawn` only. See the contract-level
    ///      SCOPE LIMIT note; the `drawn + premium` summation is covered by the unit suite.
    function test_StocksParity_HookReadsEqualOracleReads_BothLegs() public view {
        // payload A: supply reserve = USDC, borrow reserve = AAPL; header = SUPPLY key of USDC
        bytes memory usdcSupplyPayload = _loanData(supplyKeys[USDC_ID], AAPLc, USDC, USDC_ID, AAPL_ID, 1e6, 0);
        // payload B: supply reserve = AAPL, borrow reserve = USDC; header = SUPPLY key of AAPL
        bytes memory stockSupplyUsdcDebtPayload = _loanData(supplyKeys[AAPL_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);

        // --- supply leg, USDC reserve ---
        uint256 hookUsdcSupplied = loanReader.suppliedAssets(usdcSupplyPayload, BORROWER);
        assertGt(hookUsdcSupplied, 0, "live USDC supply position at the pinned block");
        assertEq(
            oracle.getBalanceOfOwner(supplyKeys[USDC_ID], BORROWER),
            hookUsdcSupplied,
            "oracle(supply key) == hook _suppliedAssets on the USDC reserve"
        );
        assertEq(
            hookUsdcSupplied,
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_ID, BORROWER),
            "and both equal the raw spoke view"
        );

        // --- debt leg, USDC reserve (drawn + premium) ---
        uint256 hookUsdcDebt = loanReader.totalDebt(stockSupplyUsdcDebtPayload, BORROWER);
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertGt(hookUsdcDebt, 0, "live USDC debt position at the pinned block");
        assertEq(premium, 0, "premium is zero at this block: the sum below pins the drawn component only");
        assertEq(hookUsdcDebt, drawn + premium, "hook _totalDebt is drawn + premium");
        assertEq(
            oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER),
            hookUsdcDebt,
            "oracle(debt key) == hook _totalDebt on the USDC reserve"
        );

        // --- supply leg, TOKENIZED STOCK reserve ---
        uint256 hookStockSupplied = loanReader.suppliedAssets(stockSupplyUsdcDebtPayload, BORROWER);
        assertGt(hookStockSupplied, 0, "live AAPLc collateral position at the pinned block");
        assertEq(
            oracle.getBalanceOfOwner(supplyKeys[AAPL_ID], BORROWER),
            hookStockSupplied,
            "oracle(supply key) == hook _suppliedAssets on the AAPLc reserve"
        );
        assertEq(oracle.getBalanceOfOwner(debtKeys[AAPL_ID], BORROWER), 0, "the stock reserve carries no debt");

        // the two legs of the leveraged position are genuinely different numbers, read through one oracle
        assertTrue(hookUsdcSupplied != hookUsdcDebt, "supply and debt legs are independent quantities");
        assertTrue(hookStockSupplied != hookUsdcSupplied, "8-decimal stock leg is not the 6-decimal USDC leg");
    }

    /// @notice The same parity for the idle MONEY_MARKET side: `BaseAaveV4MoneyMarketHook._suppliedAssets`
    ///         equals the oracle's SUPPLY-key read, on a tokenized stock reserve and on USDC, for a
    ///         supply-only live account (the WHALE). Read through the deployed lend hook's own decoder.
    function test_StocksParity_IdleHookReadsEqualOracleReads_SupplyOnlyAccount() public view {
        uint256[2] memory ids = [TSLA_ID, USDC_ID];
        address[2] memory tokens = [TSLAc, USDC];

        for (uint256 i; i < ids.length; ++i) {
            bytes memory data = _idleData(supplyKeys[ids[i]], tokens[i], ids[i], 1);
            uint256 hookSupplied = idleReader.idleSuppliedAssets(data, WHALE);
            assertGt(hookSupplied, 0, "live supply-only position on this reserve");
            assertEq(
                oracle.getBalanceOfOwner(supplyKeys[ids[i]], WHALE),
                hookSupplied,
                "oracle(supply key) == idle hook _suppliedAssets"
            );
            assertEq(oracle.getBalanceOfOwner(debtKeys[ids[i]], WHALE), 0, "supply-only account has no debt leg");
        }
    }

    /// @notice SCOPE ACKNOWLEDGEMENT, asserted rather than commented: at the pinned block the `premiumDebt`
    ///         component of `getUserDebt` and `getReserveDebt` is EXACTLY ZERO on every leg of every reserve
    ///         of this market, for both live accounts. The hook/oracle debt parity this file proves is
    ///         therefore evidence for the `drawn` component alone — deleting `+ premiumDebt` from
    ///         `AaveV4ReserveOracle` would not fail an assertion here (nor would deleting it from
    ///         `BaseAaveV4LoanHookV2._totalDebt`, since parity compares two reads of the same zero). The
    ///         premium term's real coverage lives in the unit suite
    ///         (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`:
    ///         `test_debt_balanceOfOwner_isDrawnPlusPremium`, `test_debt_balanceOfOwner_premiumOnly`,
    ///         `test_fuzz_debt_balanceOfOwner_sumNeverTruncates`), where the premium is settable on a mock.
    /// @dev TRIPWIRE, NOT A CLAIM ABOUT AAVE. Premium is re-rated by `updateUserRiskPremium` and rides the
    ///      live hub index, so it can become non-zero on this market later. If these assertions ever fail,
    ///      the suite has stopped being degenerate in `premium` and its parity claims have become real
    ///      evidence for the summed term — update the SCOPE LIMIT note rather than deleting this test. Do
    ///      not mock a premium onto a fork test to make the term non-zero.
    function test_StocksParity_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite() public view {
        address[2] memory users = [BORROWER, WHALE];
        uint256 totalDrawn;

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (uint256 reserveDrawn, uint256 reservePremium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);
            assertEq(reservePremium, 0, "reserve-level premium is zero on every reserve at the pinned block");
            assertEq(oracle.getTVL(debtKeys[id]), reserveDrawn, "DEBT key getTVL carries no premium contribution");
            totalDrawn += reserveDrawn;

            for (uint256 u; u < users.length; ++u) {
                (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(id, users[u]);
                assertEq(premium, 0, "user-level premium is zero on every leg for both live accounts");
                assertEq(
                    oracle.getBalanceOfOwner(debtKeys[id], users[u]),
                    drawn,
                    "DEBT key getBalanceOfOwner carries no premium contribution"
                );
            }
        }

        // the HOOK side of the parity statement is equally premium-free, read through the production decoder
        bytes memory stockSupplyUsdcDebtPayload = _loanData(supplyKeys[AAPL_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);
        (uint256 usdcDrawn, uint256 usdcPremium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(usdcPremium, 0, "the one live user-level debt in this market carries no risk premium");
        assertEq(
            loanReader.totalDebt(stockSupplyUsdcDebtPayload, BORROWER),
            usdcDrawn,
            "hook _totalDebt equals the drawn component alone: its premium addend is unexercised here"
        );

        // degenerate in `premium` only — the drawn component is genuinely live
        assertGt(totalDrawn, 0, "there IS live drawn debt in this market, so only the premium term is degenerate");
        assertGt(usdcDrawn, 0, "the borrower's USDC drawn debt is the market's only user-level debt");
    }

    /*//////////////////////////////////////////////////////////////
          D. PER-OP PRIMARY SIDE — HEADER IS ALWAYS A SUPPLY KEY
    //////////////////////////////////////////////////////////////*/

    /// @notice Per-op primary-reserve mapping for all six V2 hooks on the live stocks market, read out of the
    ///         production `inspect()` path (same pure decoder, same pin as `build()` / `preExecute()`):
    ///         PLEDGE / RELEASE / OPEN / CLOSE select the SUPPLY reserve (AAPLc) as primary, while BORROW and
    ///         REPAY select the BORROW reserve (USDC). In EVERY case — including the two DEBT-side ops —
    ///         primary reserve is the borrow reserve; the header key is still that reserve's SUPPLY key.
    ///         The registry confirms `Side.SUPPLY` on all six headers, and each one is also asserted NOT to
    ///         be any debt key.
    /// @dev Mapping derived from the `_primaryReserveId` overrides: `AaveV4SupplyHookV2`,
    ///      `AaveV4WithdrawHookV2`, `AaveV4SupplyAndBorrowHookV2`, `AaveV4RepayAndWithdrawHookV2` return
    ///      `vars.supplyReserveId`; `AaveV4BorrowHookV2` and `AaveV4RepayHookV2` return `vars.borrowReserveId`.
    function test_StocksHookHeaders_PerOpPrimaryReserve_AlwaysPinsTheSupplyKey() public {
        address[6] memory hooks = [
            address(pledgeHook),
            address(releaseHook),
            address(openHook),
            address(closeHook),
            address(borrowHook),
            address(repayHook)
        ];
        // primary reserve each op's `_primaryReserveId` selects
        uint256[6] memory primaryIds = [AAPL_ID, AAPL_ID, AAPL_ID, AAPL_ID, USDC_ID, USDC_ID];
        // composite ops (OPEN / CLOSE) permit a nonzero secondary word; the standalone legs reserve it as zero
        uint256[6] memory secondAmounts = [uint256(0), 0, 1e6, 1e6, 0, 0];

        for (uint256 i; i < hooks.length; ++i) {
            _assertPrimarySideMapping(hooks[i], primaryIds[i], secondAmounts[i]);
        }
    }

    /// @dev One op's primary-side mapping. Split out of the loop above so the five-value `getReserveInfo`
    ///      destructuring plus the two payloads do not blow the (non-via-ir) stack frame.
    /// @param hook The V2 loan hook under test
    /// @param primaryId The reserve id its `_primaryReserveId` override selects
    /// @param secondAmount Secondary amount word (nonzero only for the composite OPEN / CLOSE ops)
    function _assertPrimarySideMapping(address hook, uint256 primaryId, uint256 secondAmount) internal {
        address expectedHeader = supplyKeys[primaryId];
        bytes memory data = _loanData(expectedHeader, USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, secondAmount);

        // the op decodes, so its `_primaryReserveId` agrees with the header we pinned
        address inspectedKey = BytesLib.toAddress(ISuperHookInspector(hook).inspect(data), 0);
        assertEq(inspectedKey, expectedHeader, "inspect key == the primary reserve's SUPPLY key");
        assertEq(inspectedKey, BytesLib.toAddress(data, 32), "inspect key == the header word at offset 32");
        assertTrue(inspectedKey != debtKeys[primaryId], "header is never the primary reserve's debt key");

        // and it is a SUPPLY key in the registry, bound to the op's primary reserve
        _assertHeaderIsSupplyKeyOf(inspectedKey, primaryId);

        // the complementary header is rejected: an op may only carry ITS primary reserve's supply key
        uint256 otherId = primaryId == USDC_ID ? AAPL_ID : USDC_ID;
        bytes memory wrongPrimary = _loanData(supplyKeys[otherId], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, secondAmount);
        vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
        ISuperHookInspector(hook).inspect(wrongPrimary);
    }

    /// @dev Resolves a header key through the registry and asserts it is the SUPPLY leg of `expectedId`
    function _assertHeaderIsSupplyKeyOf(address headerKey, uint256 expectedId) internal view {
        (address spoke, uint256 reserveId, address underlying,, AaveV4ReserveRegistryV2.Side side) =
            registry.getReserveInfo(headerKey);
        assertEq(spoke, MAG7_SPOKE, "header resolves to the live MAG7 spoke");
        assertEq(reserveId, expectedId, "header resolves to the op's primary reserve");
        assertEq(underlying, expectedId == USDC_ID ? USDC : AAPLc, "underlying of the primary reserve");
        assertTrue(side == AaveV4ReserveRegistryV2.Side.SUPPLY, "every hook header pins the SUPPLY leg");
    }

    /// @notice The two DEBT-side ops, spelled out on their own because this is the point most likely to be
    ///         misread later: for BORROW and REPAY the primary reserve is the BORROW reserve (USDC), and the
    ///         header key is still that reserve's SUPPLY key — NOT its DEBT key. The debt key of the very
    ///         reserve these ops borrow from is simultaneously asserted to be a valid, registered DEBT-side
    ///         oracle key carrying the borrower's live debt, so the two key spaces are shown side by side.
    function test_StocksHookHeaders_DebtSideOps_PrimaryIsBorrowReserve_HeaderIsItsSupplyKey() public view {
        address[2] memory debtSideHooks = [address(borrowHook), address(repayHook)];

        for (uint256 i; i < debtSideHooks.length; ++i) {
            bytes memory data = _loanData(supplyKeys[USDC_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e6, 0);
            address header = BytesLib.toAddress(ISuperHookInspector(debtSideHooks[i]).inspect(data), 0);

            assertEq(header, supplyKeys[USDC_ID], "primary is the borrow reserve; header is its SUPPLY key");
            assertTrue(header != debtKeys[USDC_ID], "header is NOT the borrow reserve's debt key");
            assertTrue(header != supplyKeys[AAPL_ID], "header is not the collateral reserve's key");

            (, uint256 reserveId,,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(header);
            assertEq(reserveId, USDC_ID, "primary reserve is the BORROW reserve");
            assertTrue(side == AaveV4ReserveRegistryV2.Side.SUPPLY, "still the SUPPLY leg of that reserve");
        }

        // the DEBT key of the same reserve is registry-only, and it is where the live debt is readable
        (, uint256 debtReserveId,,, AaveV4ReserveRegistryV2.Side debtSide) = registry.getReserveInfo(debtKeys[USDC_ID]);
        assertEq(debtReserveId, USDC_ID, "same reserve, other leg");
        assertTrue(debtSide == AaveV4ReserveRegistryV2.Side.DEBT, "the debt leg lives only in the registry");
        assertGt(oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER), 0, "and it carries the live debt");
    }

    /// @notice Idle MONEY_MARKET headers: the lend and redeem hooks' primary is their single supply reserve, so
    ///         the header key equals that reserve's SUPPLY key — pinned for a tokenized stock (TSLAc, 8dp) and
    ///         for USDC (6dp), with the registry confirming `Side.SUPPLY` and the underlying binding.
    function test_StocksIdleHookHeaders_PinTheSupplyKeyOfTheirReserve() public view {
        address[2] memory idleHooks = [address(lendHook), address(redeemHook)];
        uint256[2] memory ids = [TSLA_ID, USDC_ID];
        address[2] memory tokens = [TSLAc, USDC];

        for (uint256 h; h < idleHooks.length; ++h) {
            for (uint256 i; i < ids.length; ++i) {
                bytes memory data = _idleData(supplyKeys[ids[i]], tokens[i], ids[i], 1e6);
                address header = BytesLib.toAddress(ISuperHookInspector(idleHooks[h]).inspect(data), 0);

                assertEq(header, supplyKeys[ids[i]], "idle header == SUPPLY key of its reserve");
                assertEq(header, registry.computeReserveKey(MAG7_SPOKE, ids[i]), "and the legacy derivation");
                assertTrue(header != debtKeys[ids[i]], "idle header is never a debt key");

                (address spoke, uint256 reserveId, address underlying, uint8 dec, AaveV4ReserveRegistryV2.Side side) =
                    registry.getReserveInfo(header);
                assertEq(spoke, MAG7_SPOKE, "live MAG7 spoke");
                assertEq(reserveId, ids[i], "the idle op's own reserve");
                assertEq(underlying, tokens[i], "underlying binding");
                assertEq(dec, IAaveV4Spoke(MAG7_SPOKE).getReserve(ids[i]).decimals, "live decimals");
                assertTrue(side == AaveV4ReserveRegistryV2.Side.SUPPLY, "idle headers pin the SUPPLY leg");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
       E. REGISTRY BINDING PARITY WITH THE LIVE SPOKE, BOTH LEGS
    //////////////////////////////////////////////////////////////*/

    /// @notice For all 8 live reserves, `getReserveInfo` on the SUPPLY key and on the DEBT key report the
    ///         SAME spoke, reserveId, underlying and decimals as `IAaveV4Spoke.getReserve(id)` — the two
    ///         bindings differ in `Side` and nothing else. The oracle's `decimals` / `getPricePerShare` are
    ///         therefore side-independent, derived here from the live spoke rather than hardcoded.
    function test_StocksRegistry_BothLegsBindTheSameLiveReserve_DifferingOnlyInSide() public view {
        uint256 stockReserves;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            IAaveV4Spoke.Reserve memory live = IAaveV4Spoke(MAG7_SPOKE).getReserve(id);
            assertTrue(live.underlying != address(0), "reserve is listed on the live spoke");
            assertEq(live.hub, EQUITIES_HUB, "all MAG7 reserves share the equities hub");

            // identical binding on both legs; only `Side` differs
            _assertLegBindsLiveReserve(supplyKeys[id], id, live, AaveV4ReserveRegistryV2.Side.SUPPLY);
            _assertLegBindsLiveReserve(debtKeys[id], id, live, AaveV4ReserveRegistryV2.Side.DEBT);

            // every oracle view that resolves decimals is side-independent for the same reason
            assertEq(oracle.decimals(supplyKeys[id]), live.decimals, "oracle decimals, supply leg");
            assertEq(oracle.decimals(debtKeys[id]), live.decimals, "oracle decimals, debt leg");
            assertEq(
                oracle.getPricePerShare(supplyKeys[id]),
                oracle.getPricePerShare(debtKeys[id]),
                "identity PPS on both legs of one reserve"
            );
            assertEq(oracle.getPricePerShare(supplyKeys[id]), 10 ** uint256(live.decimals), "identity PPS == 1 unit");

            if (id == USDC_ID) {
                assertEq(live.underlying, USDC, "reserve 7 is USDC");
            } else {
                assertEq(live.decimals, IAaveV4Spoke(MAG7_SPOKE).getReserve(AAPL_ID).decimals, "stocks share a scale");
                ++stockReserves;
            }
        }
        assertEq(stockReserves, RESERVE_COUNT - 1, "seven tokenized stock reserves plus USDC");
        assertEq(IAaveV4Spoke(MAG7_SPOKE).getReserve(AAPL_ID).underlying, AAPLc, "reserve 0 is AAPLc");
        assertEq(IAaveV4Spoke(MAG7_SPOKE).getReserve(TSLA_ID).underlying, TSLAc, "reserve 6 is TSLAc");
    }

    /// @dev One leg's registry binding against the live spoke struct. Factored out of the loop above so the
    ///      five-value destructuring does not blow the (non-via-ir) stack frame.
    function _assertLegBindsLiveReserve(
        address key,
        uint256 id,
        IAaveV4Spoke.Reserve memory live,
        AaveV4ReserveRegistryV2.Side expectedSide
    )
        internal
        view
    {
        (address spoke, uint256 reserveId, address underlying, uint8 dec, AaveV4ReserveRegistryV2.Side side) =
            registry.getReserveInfo(key);
        assertEq(spoke, MAG7_SPOKE, "leg binds the live MAG7 spoke");
        assertEq(reserveId, id, "leg binds the same reserveId");
        assertEq(underlying, live.underlying, "leg underlying == live spoke underlying");
        assertEq(dec, live.decimals, "leg decimals == live spoke decimals");
        assertTrue(side == expectedSide, "leg carries the expected Side and nothing else differs");
    }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 241-byte Aave V4 V2 LOAN layout: oracle id | header key | loan token | collateral token |
    ///      spoke | supplyReserveId | borrowReserveId | amount1 | amount2 | usePrevHookAmount
    function _loanData(
        address headerKey,
        address loanToken,
        address collateralToken,
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 amount1,
        uint256 amount2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            HEADER_ORACLE_ID,
            headerKey,
            loanToken,
            collateralToken,
            MAG7_SPOKE,
            supplyReserveId,
            borrowReserveId,
            amount1,
            amount2,
            false
        );
    }

    /// @dev Canonical 157-byte idle MONEY_MARKET layout: oracle id | header key | underlying | spoke |
    ///      reserveId | amount | usePrevHookAmount
    function _idleData(
        address headerKey,
        address underlying,
        uint256 reserveId,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(HEADER_ORACLE_ID, headerKey, underlying, MAG7_SPOKE, reserveId, amount, false);
    }
}
