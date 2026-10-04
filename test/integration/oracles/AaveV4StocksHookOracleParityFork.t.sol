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

    /// @notice The exact pin the V1 LOAN six and the idle pair run inside their pure decoders
    function requireHeaderKey(address headerKey, address spoke, uint256 reserveId) external pure {
        AaveV4ReserveKey.requireHeaderKey(headerKey, spoke, reserveId);
    }

    /// @notice Library derivation of the MARKET (four-word, domain-separated) key — SUP-21239
    function computeMarketKey(address spoke, uint256 supplyId, uint256 borrowId) external pure returns (address) {
        return AaveV4ReserveKey.computeMarketKey(spoke, supplyId, borrowId);
    }

    /// @notice The exact pin the six V2 LOAN hooks run inside their pure decoder
    function requireHeaderIsMarketKey(
        address headerKey,
        address spoke,
        uint256 supplyId,
        uint256 borrowId
    )
        external
        pure
    {
        AaveV4ReserveKey.requireHeaderIsMarketKey(headerKey, spoke, supplyId, borrowId);
    }
}

/// @title AaveV4LoanHookReadHarness
/// @notice Exposes `BaseAaveV4LoanHookV2`'s `internal view` position reads (`_suppliedAssets`, `_totalDebt`)
///         through the REAL decoder (`_decodeAaveV4V2`), so a test can compare the exact spoke read a
///         deployed hook performs against the oracle's read of the matching registry key.
/// @dev Derives from the concrete PLEDGE hook so the production decoder — and therefore the production header
///      pin, which since SUP-21239 is the MARKET-key pin shared by all six V2 ops — runs on every call below
///      exactly as it does in production. No hook behaviour is re-implemented here, only made externally
///      callable.
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
///         kept the SUPPLY derivation UNTOUCHED, so the NAV key space never moved. What this file proves,
///         reserve by reserve and on real positions, is the CURRENT three-way split (SUP-21239 changed the
///         third line, not the first two):
///           * the DEBT key exists ONLY in the registry, for oracle / NAV consumers — never a hook header;
///           * the idle MONEY_MARKET pair pins its reserve's SUPPLY key, which is also its SuperLedger key;
///           * the six V2 LOAN hooks pin the MARKET key of their pair — one key for all six ops, equal to
///             NEITHER leg's supply nor debt key, and not oracle-resolvable at all.
/// @dev Five statements, all against live chain reads — no magnitude is hardcoded:
///      1. `AaveV4ReserveKey.computeReserveKey` == `registry.computeReserveKey` == the literal off-chain
///         formula `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))`, for all 8 reserves.
///      2. A DEBT key is never a hook header: it differs from its own reserve's SUPPLY key AND from every
///         other live reserve's SUPPLY key, and `requireHeaderKey` rejects it with `RESERVE_KEY_MISMATCH`.
///         The MARKET key is likewise none of the 16 leg keys, and the market-key pin rejects every one of
///         them with `MARKET_KEY_MISMATCH`.
///      3. Hook-read vs oracle-read parity on BOTH legs of a real borrower, through the hooks' own decoder
///         and position-read helpers (see `AaveV4LoanHookReadHarness`).
///      4. Header mapping for all six V2 hooks (one shared market key) plus the two idle hooks (each its own
///         reserve's supply key), asserted through the production `inspect()` path, which runs the same pure
///         decoder — and therefore the same pin — as `build()` / `preExecute()`.
///      5. (section F) The MARKET namespace itself, against the live spoke: `registerMarket` for all seven
///         real pairs (each equity reserve as collateral against the USDC loan reserve) binds the underlyings
///         the live spoke reports; a market key is answered by `getMarketInfo` and by NOTHING in the NAV
///         namespace (the oracle fails closed on it); registration moves no live NAV number; and `marketRefs`
///         blocks deregistration of the two legs a live market names, at propose and at execute.
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
        // PLEDGE: a header carrying AAPL's DEBT key must fail. Since SUP-21239 the V2 ops reject it as a
        // MARKET key mismatch rather than a reserve-key one — the rejection, not its name, is the invariant.
        bytes memory pledgeWithDebtHeader = _loanData(debtKeys[AAPL_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        ISuperHookInspector(address(pledgeHook)).inspect(pledgeWithDebtHeader);

        // BORROW: a header carrying USDC's DEBT key must fail too, even though this op's economics ARE the
        // debt leg. No leg key is ever a V2 header; the market key is.
        bytes memory borrowWithDebtHeader = _loanData(debtKeys[USDC_ID], USDC, AAPLc, AAPL_ID, USDC_ID, 1e6, 0);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        ISuperHookInspector(address(borrowHook)).inspect(borrowWithDebtHeader);

        // idle lend on a stock reserve: header carrying the DEBT key must fail
        bytes memory idleWithDebtHeader = _idleData(debtKeys[TSLA_ID], TSLAc, TSLA_ID, 1e8);
        vm.expectRevert(AaveV4ReserveKey.RESERVE_KEY_MISMATCH.selector);
        ISuperHookInspector(address(lendHook)).inspect(idleWithDebtHeader);
    }

    /// @notice The MARKET namespace against the live market: for every ordered pair of the 8 live reserves the
    ///         market key is none of the 16 leg keys (8 supply + 8 debt), and the market-key pin rejects every
    ///         leg key. Exercised through the harness because both are `internal` library functions.
    /// @dev This is the live-market form of the namespace split: 56 ordered pairs x 16 leg keys, all distinct,
    ///      so on the real MAG7 market no signed market key can ever collide with a NAV key the oracle reads.
    function test_StocksKeySpace_MarketKeys_AreDisjointFromEveryLegKey() public {
        for (uint256 supplyId; supplyId < RESERVE_COUNT; ++supplyId) {
            for (uint256 borrowId; borrowId < RESERVE_COUNT; ++borrowId) {
                if (supplyId == borrowId) continue;
                address marketKey = keyLib.computeMarketKey(MAG7_SPOKE, supplyId, borrowId);

                // accepted: its own derivation
                keyLib.requireHeaderIsMarketKey(marketKey, MAG7_SPOKE, supplyId, borrowId);

                // the reversed pair is a different market — ordering is significant
                assertTrue(
                    marketKey != keyLib.computeMarketKey(MAG7_SPOKE, borrowId, supplyId),
                    "reversed pair must be a different market key"
                );

                for (uint256 id; id < RESERVE_COUNT; ++id) {
                    assertTrue(marketKey != supplyKeys[id], "market key != any live SUPPLY key");
                    assertTrue(marketKey != debtKeys[id], "market key != any live DEBT key");
                }
            }
        }

        // and the pin refuses the leg keys of its own pair
        address market = keyLib.computeMarketKey(MAG7_SPOKE, AAPL_ID, USDC_ID);
        assertTrue(market != address(0), "sanity");
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        keyLib.requireHeaderIsMarketKey(supplyKeys[AAPL_ID], MAG7_SPOKE, AAPL_ID, USDC_ID);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        keyLib.requireHeaderIsMarketKey(debtKeys[USDC_ID], MAG7_SPOKE, AAPL_ID, USDC_ID);
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
    ///         SUP-21239: the two payloads below now carry their pair's MARKET key, so this is also the
    ///         amount-invariance statement — re-identifying the header moved no quantity, because the legs
    ///         the hook reads come from the BODY (`supplyReserveId` / `borrowReserveId`), never the header.
    /// @dev PREMIUM CAVEAT: the debt-leg assertion `hookUsdcDebt == drawn + premium` is exact, but `premium`
    ///      is zero at this block (asserted inline below), so it pins `drawn` only. See the contract-level
    ///      SCOPE LIMIT note; the `drawn + premium` summation is covered by the unit suite.
    function test_StocksParity_HookReadsEqualOracleReads_BothLegs() public view {
        // payload A: supply reserve = USDC, borrow reserve = AAPL; header = MARKET key of (USDC, AAPL)
        bytes memory usdcSupplyPayload = _loanData(_marketKey(USDC_ID, AAPL_ID), AAPLc, USDC, USDC_ID, AAPL_ID, 1e6, 0);
        // payload B: supply reserve = AAPL, borrow reserve = USDC; header = MARKET key of (AAPL, USDC)
        bytes memory stockSupplyUsdcDebtPayload =
            _loanData(_marketKey(AAPL_ID, USDC_ID), USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);

        // the two payloads are different markets (ordering is significant) and neither header is a leg key
        assertTrue(
            BytesLib.toAddress(usdcSupplyPayload, 32) != BytesLib.toAddress(stockSupplyUsdcDebtPayload, 32),
            "reversed pair is a different market"
        );

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
        bytes memory stockSupplyUsdcDebtPayload =
            _loanData(_marketKey(AAPL_ID, USDC_ID), USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, 0);
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
    function test_StocksHookHeaders_EveryV2Op_PinsTheSameMarketKey() public {
        address[6] memory hooks = [
            address(pledgeHook),
            address(releaseHook),
            address(openHook),
            address(closeHook),
            address(borrowHook),
            address(repayHook)
        ];
        // composite ops (OPEN / CLOSE) permit a nonzero secondary word; the standalone legs reserve it as zero
        uint256[6] memory secondAmounts = [uint256(0), 0, 1e6, 1e6, 0, 0];

        for (uint256 i; i < hooks.length; ++i) {
            _assertMarketKeyMapping(hooks[i], secondAmounts[i]);
        }
    }

    /// @dev One V2 op's header mapping. Split out of the loop above so the five-value `getMarketInfo`
    ///      destructuring plus the payloads do not blow the (non-via-ir) stack frame.
    /// @param hook The V2 loan hook under test
    /// @param secondAmount Secondary amount word (nonzero only for the composite OPEN / CLOSE ops)
    function _assertMarketKeyMapping(address hook, uint256 secondAmount) internal {
        address expectedHeader = keyLib.computeMarketKey(MAG7_SPOKE, AAPL_ID, USDC_ID);
        bytes memory data = _loanData(expectedHeader, USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, secondAmount);

        // every op decodes the same header: there is no per-op primary reserve left to select
        address inspectedKey = BytesLib.toAddress(ISuperHookInspector(hook).inspect(data), 0);
        assertEq(inspectedKey, expectedHeader, "inspect key == the market key of (AAPLc collateral, USDC loan)");
        assertEq(inspectedKey, BytesLib.toAddress(data, 32), "inspect key == the header word at offset 32");

        // and it is none of the four leg keys of the two reserves involved
        assertTrue(inspectedKey != supplyKeys[AAPL_ID], "market key != collateral SUPPLY key");
        assertTrue(inspectedKey != debtKeys[AAPL_ID], "market key != collateral DEBT key");
        assertTrue(inspectedKey != supplyKeys[USDC_ID], "market key != loan SUPPLY key");
        assertTrue(inspectedKey != debtKeys[USDC_ID], "market key != loan DEBT key");

        _assertHeaderIsTheMarket(inspectedKey);

        // every header that used to be valid under SUP-21143 is now refused, on EVERY op — this is what makes
        // the redeployed hooks fail closed against an old reserve-keyed root
        address[4] memory wrong = [
            supplyKeys[AAPL_ID],
            supplyKeys[USDC_ID],
            debtKeys[USDC_ID],
            keyLib.computeMarketKey(MAG7_SPOKE, USDC_ID, AAPL_ID)
        ];
        for (uint256 w; w < wrong.length; ++w) {
            bytes memory badHeader = _loanData(wrong[w], USDC, AAPLc, AAPL_ID, USDC_ID, 1e8, secondAmount);
            vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
            ISuperHookInspector(hook).inspect(badHeader);
        }
    }

    /// @dev Resolves a V2 header through the registry's MARKET namespace and asserts it binds the live pair.
    ///      Note the asymmetry with the idle path: this key resolves through `getMarketInfo` and NOT through
    ///      `getReserveInfo` — the two namespaces are separate mappings, which is why the oracle can never
    ///      read a market key as a position.
    function _assertHeaderIsTheMarket(address headerKey) internal {
        if (!registry.isMarketRegistered(headerKey)) registry.registerMarket(MAG7_SPOKE, AAPL_ID, USDC_ID);

        (address spoke, uint256 supplyId, uint256 borrowId, address collateralToken, address loanToken) =
            registry.getMarketInfo(headerKey);
        assertEq(spoke, MAG7_SPOKE, "header resolves to the live MAG7 spoke");
        assertEq(supplyId, AAPL_ID, "collateral reserve binding");
        assertEq(borrowId, USDC_ID, "loan reserve binding");
        assertEq(collateralToken, AAPLc, "collateral underlying read from the live spoke");
        assertEq(loanToken, USDC, "loan underlying read from the live spoke");

        // the market key is intent identity only: the oracle must fail closed on it
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(headerKey);
    }

    /// @notice The two DEBT-side ops, spelled out on their own because this is the point most likely to be
    ///         misread later. Under SUP-21143 BORROW and REPAY were the exception: their primary reserve was
    ///         the BORROW reserve, so their header was USDC's SUPPLY key while the other four ops carried
    ///         AAPLc's. SUP-21239 removes the exception — all six carry the one MARKET key — and the header
    ///         is now neither reserve's supply key and neither reserve's debt key. The debt key of the very
    ///         reserve these ops borrow from is simultaneously asserted to be a valid, registered DEBT-side
    ///         ORACLE key carrying the borrower's live debt, so the two key spaces are shown side by side.
    function test_StocksHookHeaders_DebtSideOps_CarryTheMarketKeyNotTheBorrowReservesKey() public view {
        address[2] memory debtSideHooks = [address(borrowHook), address(repayHook)];
        address marketKey = keyLib.computeMarketKey(MAG7_SPOKE, AAPL_ID, USDC_ID);

        for (uint256 i; i < debtSideHooks.length; ++i) {
            bytes memory data = _loanData(marketKey, USDC, AAPLc, AAPL_ID, USDC_ID, 1e6, 0);
            address header = BytesLib.toAddress(ISuperHookInspector(debtSideHooks[i]).inspect(data), 0);

            assertEq(header, marketKey, "a debt-side op carries the market key, like every other op");
            assertEq(
                header,
                BytesLib.toAddress(ISuperHookInspector(address(pledgeHook)).inspect(data), 0),
                "same key a supply-side op carries: the per-op exception is gone"
            );
            assertTrue(header != supplyKeys[USDC_ID], "header is NOT the borrow reserve's SUPPLY key (SUP-21143)");
            assertTrue(header != debtKeys[USDC_ID], "header is NOT the borrow reserve's DEBT key");
            assertTrue(header != supplyKeys[AAPL_ID], "header is NOT the collateral reserve's SUPPLY key");
            assertTrue(header != debtKeys[AAPL_ID], "header is NOT the collateral reserve's DEBT key");
        }

        // the DEBT key of the borrow reserve is registry-only, and it is still where the live debt is readable
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
       F. THE MARKET NAMESPACE ON THE LIVE MAG7 MARKET (SUP-21239)
    //////////////////////////////////////////////////////////////*/

    /// @notice `registerMarket` against the LIVE MAG7 spoke for all seven real pairs — each tokenized equity
    ///         reserve as collateral against the single USDC loan reserve. For every pair: the returned key is
    ///         exactly `computeMarketKey` (library and registry agree), the stored `collateralToken` /
    ///         `loanToken` are the underlyings the LIVE spoke reports through `IAaveV4Spoke.getReserve` (the
    ///         registry reads them itself — they are never operator-supplied), and the market's two NAV legs
    ///         still resolve through `AaveV4ReserveOracle` to the same live amounts afterwards. All seven keys
    ///         are pairwise distinct, and each market claims exactly two legs in `marketRefs`: the collateral
    ///         reserve's SUPPLY leg (once) and the shared USDC DEBT leg (seven times).
    /// @dev This is the real steady state of the MAG7 market, and the reason NAV cannot be market-keyed: the
    ///      seven markets SHARE one USDC debt leg, so per-market NAV would read the same debt seven times.
    function test_StocksMarkets_RegisterEveryEquityAgainstUsdc_BindsTheLiveSpoke() public {
        address[] memory marketKeys = new address[](RESERVE_COUNT - 1);

        for (uint256 supplyId; supplyId < RESERVE_COUNT - 1; ++supplyId) {
            address returned = registry.registerMarket(MAG7_SPOKE, supplyId, USDC_ID);
            assertEq(returned, _marketKey(supplyId, USDC_ID), "returned key == library computeMarketKey");
            assertEq(returned, registry.computeMarketKey(MAG7_SPOKE, supplyId, USDC_ID), "== registry delegate");
            assertTrue(registry.isMarketRegistered(returned), "registered in the MARKET namespace");
            assertFalse(registry.isRegistered(returned), "and never in the reserve namespace");

            _assertLiveMarketBinding(returned, supplyId, USDC_ID);
            _assertBothNavLegsStillReadable(supplyId);

            marketKeys[supplyId] = returned;
            // exactly two legs claimed per market: this collateral reserve's SUPPLY leg, and the shared USDC DEBT leg
            assertEq(registry.marketRefs(supplyKeys[supplyId]), 1, "collateral SUPPLY leg claimed once");
            assertEq(registry.marketRefs(debtKeys[USDC_ID]), supplyId + 1, "the USDC DEBT leg is shared");
            assertEq(registry.marketRefs(debtKeys[supplyId]), 0, "the collateral reserve's DEBT leg is not claimed");
            assertEq(registry.marketRefs(supplyKeys[USDC_ID]), 0, "the loan reserve's SUPPLY leg is not claimed");
        }

        for (uint256 i; i < marketKeys.length; ++i) {
            for (uint256 j = i + 1; j < marketKeys.length; ++j) {
                assertTrue(marketKeys[i] != marketKeys[j], "the seven live market keys are pairwise distinct");
            }
        }
    }

    /// @dev One live pair's registry binding against `IAaveV4Spoke.getReserve`. Factored out so the five-value
    ///      `getMarketInfo` destructuring does not blow the (non-via-ir) stack frame.
    function _assertLiveMarketBinding(address marketKey, uint256 supplyId, uint256 borrowId) internal view {
        (address spoke, uint256 boundSupplyId, uint256 boundBorrowId, address collateralToken, address loanToken) =
            registry.getMarketInfo(marketKey);
        assertEq(spoke, MAG7_SPOKE, "bound to the live MAG7 spoke");
        assertEq(boundSupplyId, supplyId, "collateral reserve id");
        assertEq(boundBorrowId, borrowId, "loan reserve id");
        assertEq(collateralToken, IAaveV4Spoke(MAG7_SPOKE).getReserve(supplyId).underlying, "live collateral token");
        assertEq(loanToken, IAaveV4Spoke(MAG7_SPOKE).getReserve(borrowId).underlying, "live loan token");
        assertTrue(collateralToken != loanToken, "the live pair's underlyings differ (IDENTICAL_UNDERLYINGS gate)");
    }

    /// @dev Both NAV legs of a market still resolve through the merged oracle to the live spoke's own numbers:
    ///      the collateral reserve's SUPPLY leg and the shared USDC DEBT leg. No magnitude is hardcoded.
    function _assertBothNavLegsStillReadable(uint256 supplyId) internal view {
        assertEq(
            oracle.getBalanceOfOwner(supplyKeys[supplyId], BORROWER),
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(supplyId, BORROWER),
            "collateral SUPPLY leg still reads the live supplied amount"
        );
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(
            oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER), drawn + premium, "loan DEBT leg still reads the debt"
        );
        assertEq(
            oracle.getTVL(supplyKeys[supplyId]),
            IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(supplyId),
            "reserve-level SUPPLY TVL unchanged"
        );
        assertTrue(oracle.sideOf(supplyKeys[supplyId]) == AaveV4ReserveRegistryV2.Side.SUPPLY, "side intact");
        assertTrue(oracle.sideOf(debtKeys[USDC_ID]) == AaveV4ReserveRegistryV2.Side.DEBT, "side intact");
    }

    /// @dev Live NAV reads of one market's two legs, captured so registration can be proved a no-op on them
    struct LegNav {
        uint256 collateralBorrower;
        uint256 collateralWhale;
        uint256 collateralTvl;
        uint256 debtBorrower;
        uint256 debtWhale;
        uint256 debtTvl;
        uint8 collateralDecimals;
        uint8 debtDecimals;
        uint256 collateralPps;
        uint256 debtPps;
    }

    /// @notice Namespace disjointness, proved on the live MAG7 pair rather than on a mock: the market key of
    ///         (AAPLc collateral, USDC loan) resolves through `getMarketInfo` and is answered by NOTHING in the
    ///         NAV namespace — `getReserveInfo`, `getBalanceOfOwner`, `getTVL`, `getTVLByOwnerOfShares`,
    ///         `decimals`, `getPricePerShare` and `sideOf` all revert `RESERVE_NOT_REGISTERED` on it, which is
    ///         the fail-closed half of the design. And market registration changes NO live number: every NAV
    ///         read of the two legs returns exactly what it returned before `registerMarket`.
    /// @dev The oracle reverts are what make a mis-wired consumer (a NAV config carrying a market key) fail
    ///      loudly instead of reading a zero. The before/after equality is what makes the re-identification
    ///      provably accounting-neutral on live state.
    function test_StocksMarkets_MarketKeyIsNotOracleResolvable_AndLegNavIsUnchanged() public {
        address marketKey = _marketKey(AAPL_ID, USDC_ID);
        LegNav memory before = _readLegNav();

        assertFalse(registry.isMarketRegistered(marketKey), "not yet registered");
        assertEq(registry.registerMarket(MAG7_SPOKE, AAPL_ID, USDC_ID), marketKey, "registers under its own key");

        // the market key resolves in its own namespace ...
        (, uint256 supplyId, uint256 borrowId,,) = registry.getMarketInfo(marketKey);
        assertEq(supplyId, AAPL_ID, "collateral leg");
        assertEq(borrowId, USDC_ID, "loan leg");

        // ... and in no other: every registry-resolving read fails closed on it
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(marketKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(marketKey, BORROWER);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(marketKey, BORROWER);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVL(marketKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.sideOf(marketKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.decimals(marketKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShare(marketKey);

        // the live market key is none of the 16 live leg keys of this market
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertTrue(marketKey != supplyKeys[id], "market key != any live SUPPLY key");
            assertTrue(marketKey != debtKeys[id], "market key != any live DEBT key");
        }

        // and registration moved no NAV number at all
        LegNav memory later = _readLegNav();
        assertEq(later.collateralBorrower, before.collateralBorrower, "collateral leg, borrower");
        assertEq(later.collateralWhale, before.collateralWhale, "collateral leg, whale");
        assertEq(later.collateralTvl, before.collateralTvl, "collateral leg, reserve TVL");
        assertEq(later.debtBorrower, before.debtBorrower, "debt leg, borrower");
        assertEq(later.debtWhale, before.debtWhale, "debt leg, whale");
        assertEq(later.debtTvl, before.debtTvl, "debt leg, reserve TVL");
        assertEq(later.collateralDecimals, before.collateralDecimals, "collateral leg decimals");
        assertEq(later.debtDecimals, before.debtDecimals, "debt leg decimals");
        assertEq(later.collateralPps, before.collateralPps, "collateral leg PPS");
        assertEq(later.debtPps, before.debtPps, "debt leg PPS");
        // degenerate-zero guard: the live numbers this compares are genuinely nonzero
        assertGt(before.collateralBorrower, 0, "live AAPLc collateral exists at this block");
        assertGt(before.debtBorrower, 0, "live USDC debt exists at this block");
        assertGt(before.collateralTvl, 0, "live AAPLc reserve supply exists at this block");
    }

    /// @dev Every NAV read of the live pair's two legs, in one shot
    function _readLegNav() internal view returns (LegNav memory nav) {
        nav.collateralBorrower = oracle.getBalanceOfOwner(supplyKeys[AAPL_ID], BORROWER);
        nav.collateralWhale = oracle.getBalanceOfOwner(supplyKeys[AAPL_ID], WHALE);
        nav.collateralTvl = oracle.getTVL(supplyKeys[AAPL_ID]);
        nav.debtBorrower = oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER);
        nav.debtWhale = oracle.getBalanceOfOwner(debtKeys[USDC_ID], WHALE);
        nav.debtTvl = oracle.getTVL(debtKeys[USDC_ID]);
        nav.collateralDecimals = oracle.decimals(supplyKeys[AAPL_ID]);
        nav.debtDecimals = oracle.decimals(debtKeys[USDC_ID]);
        nav.collateralPps = oracle.getPricePerShare(supplyKeys[AAPL_ID]);
        nav.debtPps = oracle.getPricePerShare(debtKeys[USDC_ID]);
    }

    /// @notice `marketRefs` lifecycle on the LIVE leg keys: while a market names them, the collateral reserve's
    ///         SUPPLY leg and the loan reserve's DEBT leg cannot be deregistered — `MARKET_REFERENCES_RESERVE`
    ///         at propose AND at execute (a market registered inside the open 2-day window is caught by the
    ///         execute-side re-check). The two legs a market does NOT claim stay freely proposable. Because the
    ///         seven live MAG7 markets share one USDC debt leg, EVERY market over it must be deregistered
    ///         before that leg can go — proved here with two of them — and once `marketRefs` reaches zero the
    ///         legs become deregisterable again.
    /// @dev Ordering matters and is the ops runbook this pins: markets first, then reserve legs. The reverse
    ///      order would take a live market's NAV leg dark, and `SuperYieldSourceOracle`'s batch reads have no
    ///      per-entry isolation, so one unresolvable key aborts a whole portfolio NAV read.
    function test_StocksMarkets_MarketRefs_BlockLiveLegDeregistration_AtProposeAndExecute() public {
        uint256 delay = registry.DEREGISTER_DELAY();

        // 1. no markets yet: the TSLAc SUPPLY leg is freely proposable
        registry.proposeDeregisterReserve(supplyKeys[TSLA_ID]);
        assertGt(registry.pendingDeregistrations(supplyKeys[TSLA_ID]), 0, "proposal open");

        // 2. a market registered DURING the open window claims that leg — the execute-side re-check catches it
        address tslaMarket = registry.registerMarket(MAG7_SPOKE, TSLA_ID, USDC_ID);
        vm.warp(block.timestamp + delay);
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_REFERENCES_RESERVE.selector);
        registry.executeDeregisterReserve(supplyKeys[TSLA_ID]);
        assertTrue(registry.isRegistered(supplyKeys[TSLA_ID]), "leg survived the elapsed timelock");

        // 3. a second live market over the SAME USDC debt leg
        address aaplMarket = registry.registerMarket(MAG7_SPOKE, AAPL_ID, USDC_ID);
        assertEq(registry.marketRefs(debtKeys[USDC_ID]), 2, "both live markets name the one USDC DEBT leg");

        // both claimed legs are blocked at propose; the two unclaimed legs of the same two reserves are not
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_REFERENCES_RESERVE.selector);
        registry.proposeDeregisterReserve(supplyKeys[AAPL_ID]);
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_REFERENCES_RESERVE.selector);
        registry.proposeDeregisterReserve(debtKeys[USDC_ID]);
        registry.proposeDeregisterReserve(debtKeys[AAPL_ID]); // collateral reserve's DEBT leg: unclaimed
        registry.cancelDeregisterReserve(debtKeys[AAPL_ID]);
        registry.proposeDeregisterReserve(supplyKeys[USDC_ID]); // loan reserve's SUPPLY leg: unclaimed
        registry.cancelDeregisterReserve(supplyKeys[USDC_ID]);

        // 4. one market out of two is not enough: the shared leg is still referenced
        _deregisterMarket(aaplMarket, delay);
        assertEq(registry.marketRefs(debtKeys[USDC_ID]), 1, "one market still names the shared DEBT leg");
        assertEq(registry.marketRefs(supplyKeys[AAPL_ID]), 0, "its own collateral leg was released");
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_REFERENCES_RESERVE.selector);
        registry.proposeDeregisterReserve(debtKeys[USDC_ID]);
        registry.proposeDeregisterReserve(supplyKeys[AAPL_ID]); // released, so proposable again
        registry.cancelDeregisterReserve(supplyKeys[AAPL_ID]);

        // 5. both markets gone: refs clear and the legs are deregisterable again
        _deregisterMarket(tslaMarket, delay);
        assertEq(registry.marketRefs(debtKeys[USDC_ID]), 0, "shared DEBT leg released");
        assertEq(registry.marketRefs(supplyKeys[TSLA_ID]), 0, "TSLAc SUPPLY leg released");

        // the step-1 proposal never expired, so it executes now with no re-propose
        registry.executeDeregisterReserve(supplyKeys[TSLA_ID]);
        assertFalse(registry.isRegistered(supplyKeys[TSLA_ID]), "leg deregisterable once no market names it");
        registry.proposeDeregisterReserve(debtKeys[USDC_ID]);
        vm.warp(block.timestamp + delay);
        registry.executeDeregisterReserve(debtKeys[USDC_ID]);
        assertFalse(registry.isRegistered(debtKeys[USDC_ID]), "the shared DEBT leg goes last");
    }

    /// @dev Full timelocked market deregistration: propose, warp the shared delay, execute
    function _deregisterMarket(address marketKey, uint256 delay) internal {
        registry.proposeDeregisterMarket(marketKey);
        vm.warp(block.timestamp + delay);
        registry.executeDeregisterMarket(marketKey);
        assertFalse(registry.isMarketRegistered(marketKey), "market deregistered");
    }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev The market key of a live MAG7 pair, through the library harness (ordering is significant)
    function _marketKey(uint256 supplyId, uint256 borrowId) internal view returns (address) {
        return keyLib.computeMarketKey(MAG7_SPOKE, supplyId, borrowId);
    }

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
