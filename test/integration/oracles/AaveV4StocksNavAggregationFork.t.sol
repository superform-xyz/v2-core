// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { SuperYieldSourceOracle } from "../../../src/accounting/oracles/SuperYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4StocksNavAggregationFork
/// @author Superform Labs
/// @notice NAV-level coverage of THE REAL CONSUMER PATH against the live Base tokenized-equities market
///         (aave-address-book `AaveV4Base`: MAG7 spoke, seven tokenized stocks at 8 decimals plus USDC at
///         6). SuperVault price-per-share does not call `AaveV4ReserveOracle` directly — it calls
///         `SuperYieldSourceOracle.getTVLByOwnerOfSharesMultiple(sources, oracles, owners)`, whose loop is
///         `IYieldSourceOracle(oracles[i]).getTVLByOwnerOfShares(sources[i], owners[i])`. That surface is
///         SIDELESS: nothing in the call says "this entry is the debt leg", so the leg is known ONLY from
///         the key. `AaveV4BaseEquitiesE2EFork` covers the four basic aggregator shapes; this file pins the
///         hazards and guarantees a NAV reader actually inherits from that sideless surface.
/// @dev THE OPERATIONAL HAZARD THIS FILE IS THE EVIDENCE FOR — registration is per RESERVE (both legs in
///      one call) but deregistration is per KEY. A single executed deregistration therefore leaves a
///      HALF-REGISTERED reserve: one leg resolves, the sibling reverts `RESERVE_NOT_REGISTERED`. What a NAV
///      consumer then observes depends entirely on WHICH batch entry point it used, and the two behave
///      differently:
///        - `AbstractYieldSourceOracle.getTVLByOwnerOfSharesMultiple(keys, owners[][])` ISOLATES per entry
///          (try/catch): the dropped leg silently becomes `(0, ok = false)` and the surviving sibling still
///          returns a live number. Silence is the danger: drop the SUPPLY leg and assets vanish while debt
///          keeps counting, which DEPRESSES PPS; drop the DEBT leg and liabilities vanish while assets keep
///          counting, which INFLATES PPS. The asymmetry is pinned explicitly below.
///        - every other batch — `getPricePerShareMultiple`, `getTVLMultiple`, and the aggregator's OWN
///          `getTVLByOwnerOfSharesMultiple` (no try/catch anywhere in `SuperYieldSourceOracle`) — ABORTS
///          the whole read on the first dropped leg. Loud, but it takes down NAV wholesale.
/// @dev DERIVATION RULE for this file: every expectation is derived from the live spoke views
///      (`getUserSuppliedAssets`, `getUserDebt`, `getReserveSuppliedAssets`, `getReserveDebt`) at the
///      pinned block. No magnitude is hardcoded.
/// @dev SCOPE LIMIT — THE `premium` TERM IS ZERO AT THIS BLOCK. The `_debt` / `_reserveDebt` helpers below
///      sum `drawn + premium` exactly as `AaveV4ReserveOracle` does, but the premium component is EXACTLY
///      ZERO everywhere in this market at `FORK_BLOCK`: `getUserDebt(7, BORROWER)` is `(50032162, 0)` and
///      `getReserveDebt(7)` is `(50373206, 0)`, and reserve 7 is the only reserve with any debt. Every
///      netting, double-count and aggregate claim in this file is therefore evidence for the `drawn`
///      component alone — deleting `+ premiumDebt` from the oracle would leave this suite green. That is
///      acknowledged, not assumed: `test_Nav_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite`
///      asserts it on every leg, so the day a live premium appears the suite says so. THE SUMMATION ITSELF
///      IS COVERED IN THE UNIT SUITE (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`:
///      `test_debt_balanceOfOwner_isDrawnPlusPremium`, `test_debt_balanceOfOwner_premiumOnly`,
///      `test_fuzz_debt_balanceOfOwner_sumNeverTruncates`), where the premium is settable on a mock spoke.
///      Do NOT mock a premium onto a fork test and do not re-pin the block to manufacture one.
/// @dev QUOTE VARIANTS ARE NOT COVERED HERE. `getTVLByOwnerOfSharesQuote`,
///      `getTVLByOwnerOfSharesMultipleQuote`, `getPricePerShareQuote` and `getPricePerShareMultipleQuote`
///      all terminate in `IOracle(oracle).getQuote(amount, base, quote)`. There is no deployed `IOracle`
///      price feed for these node-native tokenized equities to point at on Base, and substituting a mock
///      would make every asserted number an artifact of the mock rather than of the live chain. They are
///      deliberately left to the unit suite.
contract AaveV4StocksNavAggregationFork is Test {
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
    address internal constant BORROWER = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F; // equities + USDC supply + USDC
    // debt
    address internal constant WHALE = 0x9e3787f9f7f0fF7Eea9e36628BecA431B61AE647; // equities + USDC supply, no debt

    uint256 internal constant FORK_BLOCK = 51_778_000;

    /// @dev 10 ** (stock decimals - USDC decimals); the scale gap that makes naive cross-reserve summation
    ///      meaningless. Derived on-chain in setUp from the registry-bound decimals, never assumed.
    uint256 internal scaleGap;

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;
    SuperYieldSourceOracle internal aggregator;
    address internal ledgerConfig;

    address[] internal keys; // SUPPLY keys, index == reserveId
    address[] internal debtKeys; // DEBT keys, index == reserveId

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));
        aggregator = new SuperYieldSourceOracle();

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (address supplyKey, address debtKey) = registry.registerReserve(MAG7_SPOKE, id);
            keys.push(supplyKey);
            debtKeys.push(debtKey);
        }

        scaleGap = 10 ** uint256(oracle.decimals(keys[AAPL_ID]) - oracle.decimals(keys[USDC_ID]));
    }

    /*//////////////////////////////////////////////////////////////
        A. HALF-REGISTERED RESERVE — PER-ENTRY FAILURE IS SILENT
    //////////////////////////////////////////////////////////////*/

    /// @notice THE CORE HAZARD. Deregistering ONE stock reserve's SUPPLY leg leaves its DEBT sibling live.
    ///         The isolating batch then reports the supply entry as `(0, ok = false)` — a value a consumer
    ///         that ignores `succeeded` cannot distinguish from "this user supplies nothing" — while all
    ///         fifteen other entries, the dropped reserve's own debt leg included, still resolve. The amount
    ///         silently erased is exactly the live spoke figure, asserted non-zero so the understatement is
    ///         real and not vacuous.
    function test_Nav_DropStockSupplyLeg_IsolatedFailure_DebtSiblingStaysLive() public {
        uint256 erased = _supplied(AAPL_ID, BORROWER);
        assertGt(erased, 0, "precondition: borrower supplies the stock reserve whose supply leg is dropped");

        _deregister(keys[AAPL_ID]);

        // registration asymmetry: one leg gone, the sibling untouched
        assertFalse(registry.isRegistered(keys[AAPL_ID]), "stock SUPPLY key deregistered");
        assertTrue(registry.isRegistered(debtKeys[AAPL_ID]), "stock DEBT sibling survives deregistration");

        (address[] memory allKeys,,) = _portfolio(BORROWER);
        (uint256[][] memory tvls, bool[][] memory ok) =
            oracle.getTVLByOwnerOfSharesMultiple(allKeys, _ownersMatrix(BORROWER, allKeys.length));

        for (uint256 i; i < allKeys.length; ++i) {
            if (i == AAPL_ID) {
                assertFalse(ok[i][0], "dropped supply leg reports ok = false");
                assertEq(tvls[i][0], 0, "dropped supply leg reports 0: indistinguishable from an empty position");
            } else {
                assertTrue(ok[i][0], "every other entry in the sweep still resolves");
            }
        }

        // the sibling debt leg of the SAME reserve is still a live, resolvable read
        assertEq(
            tvls[RESERVE_COUNT + AAPL_ID][0],
            _debt(AAPL_ID, BORROWER),
            "surviving debt sibling still agrees with the spoke"
        );
        // and the erased magnitude is exactly the live supply the spoke still reports
        assertEq(_supplied(AAPL_ID, BORROWER), erased, "the spoke position never moved, only the key was dropped");
        assertGt(erased, 0, "NAV silently understates assets by the full dropped-leg balance");
    }

    /// @notice THE ASYMMETRY, on the one reserve that carries live debt. Dropping the USDC SUPPLY leg makes
    ///         the isolating batch report zero assets for that reserve while STILL returning the full live
    ///         debt — observed net exposure falls below the true net by exactly the supplied amount, so the
    ///         consumer's PPS is DEPRESSED. The reserve's true net is read from the spoke after the timelock
    ///         warp, so debt accrual over the warp cannot be mistaken for the effect under test.
    function test_Nav_DropUsdcSupplyLeg_UnderstatesAssets_DepressesPps() public {
        _deregister(keys[USDC_ID]);

        uint256 liveSupply = _supplied(USDC_ID, BORROWER);
        uint256 liveDebt = _debt(USDC_ID, BORROWER);
        assertGt(liveSupply, 0, "precondition: live USDC supply leg");
        assertGt(liveDebt, 0, "precondition: live USDC debt leg");

        address[] memory pair = new address[](2);
        pair[0] = keys[USDC_ID];
        pair[1] = debtKeys[USDC_ID];
        (uint256[][] memory tvls, bool[][] memory ok) =
            oracle.getTVLByOwnerOfSharesMultiple(pair, _ownersMatrix(BORROWER, 2));

        assertFalse(ok[0][0], "supply leg failed in isolation");
        assertEq(tvls[0][0], 0, "assets erased");
        assertTrue(ok[1][0], "debt leg unaffected");
        assertEq(tvls[1][0], liveDebt, "liabilities still counted in full");

        int256 observedNet = int256(tvls[0][0]) - int256(tvls[1][0]);
        int256 trueNet = int256(liveSupply) - int256(liveDebt);
        assertEq(observedNet, trueNet - int256(liveSupply), "understatement is exactly the dropped supply leg");
        assertLt(observedNet, trueNet, "DEPRESSED PPS: assets dropped, debt retained");
    }

    /// @notice THE CONVERSE, and the more dangerous direction. Dropping only the USDC DEBT leg erases
    ///         liabilities while assets keep counting: observed net exceeds the true net by exactly the live
    ///         debt, INFLATING the consumer's PPS. Same half-registered reserve, opposite sign of error —
    ///         which is why the ops runbook must state which leg a deregistration removes.
    function test_Nav_DropUsdcDebtLeg_ErasesLiabilities_InflatesPps() public {
        _deregister(debtKeys[USDC_ID]);

        assertTrue(registry.isRegistered(keys[USDC_ID]), "USDC SUPPLY leg survives");
        assertFalse(registry.isRegistered(debtKeys[USDC_ID]), "USDC DEBT key deregistered");

        uint256 liveSupply = _supplied(USDC_ID, BORROWER);
        uint256 liveDebt = _debt(USDC_ID, BORROWER);
        assertGt(liveDebt, 0, "precondition: the erased liability is real");

        address[] memory pair = new address[](2);
        pair[0] = keys[USDC_ID];
        pair[1] = debtKeys[USDC_ID];
        (uint256[][] memory tvls, bool[][] memory ok) =
            oracle.getTVLByOwnerOfSharesMultiple(pair, _ownersMatrix(BORROWER, 2));

        assertTrue(ok[0][0], "supply leg unaffected");
        assertEq(tvls[0][0], liveSupply, "assets still counted in full");
        assertFalse(ok[1][0], "debt leg failed in isolation");
        assertEq(tvls[1][0], 0, "liabilities erased");

        int256 observedNet = int256(tvls[0][0]) - int256(tvls[1][0]);
        int256 trueNet = int256(liveSupply) - int256(liveDebt);
        assertEq(observedNet, trueNet + int256(liveDebt), "overstatement is exactly the dropped debt leg");
        assertGt(observedNet, trueNet, "INFLATED PPS: debt dropped, assets retained");
        assertEq(observedNet, int256(liveSupply), "the position reads as unlevered collateral");
    }

    /*//////////////////////////////////////////////////////////////
       B. NON-ISOLATING BATCHES ABORT THE WHOLE NAV READ
    //////////////////////////////////////////////////////////////*/

    /// @notice Only `AbstractYieldSourceOracle.getTVLByOwnerOfSharesMultiple` isolates. Every other batch
    ///         path over an array containing a dropped leg reverts `RESERVE_NOT_REGISTERED` and takes the
    ///         ENTIRE NAV read down — including the aggregator's own `getTVLByOwnerOfSharesMultiple`, which
    ///         is the function SuperVault pricing actually calls and which has no try/catch at all. One
    ///         deregistered key out of sixteen is enough.
    function test_Nav_NonIsolatingBatches_AbortOnDroppedLeg() public {
        _deregister(keys[AAPL_ID]);

        (address[] memory allKeys, address[] memory oracles, address[] memory owners) = _portfolio(BORROWER);

        // the aggregator — the real consumer path — does not isolate
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        aggregator.getTVLByOwnerOfSharesMultiple(allKeys, oracles, owners);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        aggregator.getPricePerShareMultiple(allKeys, oracles);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        aggregator.getTVLMultiple(allKeys, oracles);

        // same on the oracle's own non-isolating batches
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShareMultiple(allKeys);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLMultiple(allKeys);

        // CONTRAST: the isolating batch still returns, so the two entry points disagree about whether a
        // half-registered reserve is a failure or a zero
        (uint256[][] memory tvls, bool[][] memory ok) =
            oracle.getTVLByOwnerOfSharesMultiple(allKeys, _ownersMatrix(BORROWER, allKeys.length));
        assertFalse(ok[AAPL_ID][0], "isolating batch degrades instead of aborting");
        assertEq(tvls[AAPL_ID][0], 0, "and reports a zero where the other paths revert");
    }

    /// @notice A dropped leg poisons the batch regardless of position in the array: the non-isolating paths
    ///         abort on a two-entry read whose ONLY bad member is the dropped sibling, even when the other
    ///         entry is the surviving leg of the very same reserve.
    function test_Nav_NonIsolatingBatch_AbortsEvenOnTheSiblingPair() public {
        _deregister(debtKeys[TSLA_ID]);

        address[] memory pair = new address[](2);
        pair[0] = keys[TSLA_ID]; // live
        pair[1] = debtKeys[TSLA_ID]; // dropped
        address[] memory oracles = new address[](2);
        oracles[0] = address(oracle);
        oracles[1] = address(oracle);
        address[] memory owners = new address[](2);
        owners[0] = BORROWER;
        owners[1] = BORROWER;

        // the surviving leg on its own is fine
        assertEq(
            aggregator.getTVLByOwnerOfSharesMultiple(_one(pair[0]), _one(oracles[0]), _one(owners[0]))[0],
            _supplied(TSLA_ID, BORROWER),
            "surviving supply leg reads correctly when queried alone"
        );

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        aggregator.getTVLByOwnerOfSharesMultiple(pair, oracles, owners);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        aggregator.getTVLMultiple(pair, oracles);
    }

    /*//////////////////////////////////////////////////////////////
          C. MIXED DECIMALS — PER ENTRY SOUND, SUMMATION IS NOT
    //////////////////////////////////////////////////////////////*/

    /// @notice A sweep mixing 8-decimal stock supply legs with the 6-decimal USDC supply leg: every entry
    ///         individually equals its own spoke view at its own scale, and the aggregator never rescales
    ///         anything. HAZARD, not a correctness claim: the raw sum of those entries is not a portfolio
    ///         value — rescaling the single 6-decimal entry to the 8-decimal scale moves the total by
    ///         exactly `(scaleGap - 1) * usdcEntry`, which is only possible because the raw total mixes
    ///         scales. No price feed is involved; cross-asset valuation is a periphery concern.
    function test_Nav_MixedDecimals_PerEntryExact_RawSumIsScaleMixed() public view {
        address[] memory sources = new address[](RESERVE_COUNT);
        address[] memory oracles = new address[](RESERVE_COUNT);
        address[] memory owners = new address[](RESERVE_COUNT);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            sources[id] = keys[id];
            oracles[id] = address(oracle);
            owners[id] = WHALE;
        }

        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);

        uint256 rawTotal;
        uint256 rescaledTotal;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertEq(tvls[id], _supplied(id, WHALE), "entry matches its own spoke view, unrescaled");
            assertGt(tvls[id], 0, "whale supplies every reserve at the pinned block");

            uint8 dec = oracle.decimals(keys[id]);
            assertEq(dec, id == USDC_ID ? 6 : 8, "registry-bound decimals: stocks at 8, USDC at 6");
            assertEq(oracle.getPricePerShare(keys[id]), 10 ** uint256(dec), "identity PPS at the entry's own scale");

            rawTotal += tvls[id];
            rescaledTotal += id == USDC_ID ? tvls[id] * scaleGap : tvls[id];
        }

        assertEq(
            rescaledTotal - rawTotal,
            (scaleGap - 1) * tvls[USDC_ID],
            "the raw total mixes a 6-decimal entry into 8-decimal entries"
        );
        assertTrue(rawTotal != rescaledTotal, "HAZARD: the naive sum is not a portfolio value in any unit");
    }

    /*//////////////////////////////////////////////////////////////
                  D. MULTI-USER — PARALLEL OWNERS ARRAY
    //////////////////////////////////////////////////////////////*/

    /// @notice One aggregator call, both live users, same 16-key set each (32 entries). The `owners` array
    ///         is positional and per entry, so each user's legs resolve against that user alone: the whale's
    ///         eight debt entries are all zero while the borrower's USDC debt entry is live, and no supply
    ///         entry of one user ever carries the other's balance.
    function test_Nav_MultiUser_ParallelOwners_FullIsolation() public view {
        uint256 half = RESERVE_COUNT * 2;
        uint256 n = half * 2;
        address[] memory sources = new address[](n);
        address[] memory oracles = new address[](n);
        address[] memory owners = new address[](n);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            sources[id] = keys[id];
            sources[RESERVE_COUNT + id] = debtKeys[id];
            sources[half + id] = keys[id];
            sources[half + RESERVE_COUNT + id] = debtKeys[id];
            owners[id] = BORROWER;
            owners[RESERVE_COUNT + id] = BORROWER;
            owners[half + id] = WHALE;
            owners[half + RESERVE_COUNT + id] = WHALE;
        }
        for (uint256 i; i < n; ++i) {
            oracles[i] = address(oracle);
        }

        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertEq(tvls[id], _supplied(id, BORROWER), "borrower supply entry");
            assertEq(tvls[RESERVE_COUNT + id], _debt(id, BORROWER), "borrower debt entry");
            assertEq(tvls[half + id], _supplied(id, WHALE), "whale supply entry");
            assertEq(tvls[half + RESERVE_COUNT + id], _debt(id, WHALE), "whale debt entry");

            assertEq(tvls[half + RESERVE_COUNT + id], 0, "whale carries no debt on any leg");
            assertTrue(tvls[id] != tvls[half + id], "the two users' supply entries are distinct balances");
        }

        assertGt(tvls[RESERVE_COUNT + USDC_ID], 0, "borrower's USDC debt is live");
        assertEq(tvls[half + RESERVE_COUNT + USDC_ID], 0, "and did not leak into the whale's entry");
        // the whale's own supply legs are non-zero through the identical oracle address, so "all zero" is
        // a property of the user, not of the key set
        assertGt(tvls[half + USDC_ID], 0, "whale does supply USDC");
    }

    /*//////////////////////////////////////////////////////////////
          E. WHOLE-PORTFOLIO NAV, DONE CORRECTLY: NET PER RESERVE
    //////////////////////////////////////////////////////////////*/

    /// @notice The CORRECT reading of a 16-entry sweep: net the two legs WITHIN each reserve. Valid because
    ///         the sibling keys share one underlying and both carry identity PPS, so no conversion is
    ///         implied. Each per-reserve net equals the spoke-derived net exactly. The naive all-entries sum
    ///         differs from the sum of nets by exactly twice the total debt — the debt leg is added where it
    ///         should be subtracted — and since only USDC carries debt at the pinned block that difference
    ///         is `2 * usdcDebt`, asserted to the wei.
    /// @dev PREMIUM CAVEAT: "to the wei" is exact, but the debt figure it is exact about is `drawn` alone —
    ///      the premium component is zero at this block (asserted below). See the contract-level SCOPE LIMIT
    ///      note; the `drawn + premium` summation itself is covered by the unit suite.
    function test_Nav_PerReserveNetting_MatchesSpoke_AndNaiveSumIsOffByTwiceTheDebt() public view {
        (address[] memory sources, address[] memory oracles, address[] memory owners) = _portfolio(BORROWER);
        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);

        int256 sumOfNets;
        uint256 naiveTotal;
        uint256 totalDebt;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 supplyEntry = tvls[id];
            uint256 debtEntry = tvls[RESERVE_COUNT + id];

            int256 observedNet = int256(supplyEntry) - int256(debtEntry);
            int256 spokeNet = int256(_supplied(id, BORROWER)) - int256(_debt(id, BORROWER));
            assertEq(observedNet, spokeNet, "per-reserve net from aggregator output equals the spoke net");

            if (id == USDC_ID) {
                assertLt(observedNet, 0, "borrower is net short USDC at the pinned block");
            } else {
                assertEq(observedNet, int256(supplyEntry), "stock reserves net to their supply leg: no debt");
                assertGt(observedNet, 0, "stock net exposure is long");
            }

            sumOfNets += observedNet;
            naiveTotal += supplyEntry + debtEntry;
            totalDebt += debtEntry;
        }

        assertEq(totalDebt, _debt(USDC_ID, BORROWER), "USDC is the only reserve contributing debt");
        (, uint256 usdcPremium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(usdcPremium, 0, "that debt figure is `drawn` alone: premium is zero at this block");
        assertEq(
            int256(naiveTotal) - sumOfNets,
            2 * int256(totalDebt),
            "the naive sum adds the debt leg where netting subtracts it: off by exactly 2x debt"
        );
        assertGt(int256(naiveTotal), sumOfNets, "the naive all-entries sum overstates the netted figure");

        // and the single-reserve statement of the same identity, on the only levered reserve
        uint256 s = tvls[USDC_ID];
        uint256 d = tvls[RESERVE_COUNT + USDC_ID];
        assertEq(int256(s + d) - (int256(s) - int256(d)), 2 * int256(d), "sum vs net on one reserve differs by 2x debt");
    }

    /*//////////////////////////////////////////////////////////////
          F. RESERVE-LEVEL TVL PER LEG ACROSS ALL EIGHT RESERVES
    //////////////////////////////////////////////////////////////*/

    /// @notice `getTVLMultiple` through the aggregator resolves reserve-level totals per leg across all
    ///         sixteen keys: a SUPPLY key yields total supplied assets, a DEBT key yields aggregate
    ///         outstanding borrows — never total supplied for a debt key. VERIFIED AGAINST THE LIVE CHAIN at
    ///         the pinned block: all seven tokenized stock reserves have an aggregate debt of exactly zero
    ///         (nothing is borrowed against the equities market), and USDC is the only reserve with
    ///         non-zero borrows. The assertions state what the chain actually reports, read from
    ///         `getReserveDebt`, not an assumption that equities cannot be borrowed.
    /// @dev WHAT "VERIFIED" DOES NOT COVER: the `premium` half of the `drawn + premium` aggregate. It is
    ///      zero on every reserve at this block (asserted below), so these reserve totals verify `drawn`
    ///      alone. See the contract-level SCOPE LIMIT note; the premium term's coverage is in the unit suite.
    function test_Nav_GetTVLMultiple_PerLegReserveTotals_AllEightReserves() public view {
        (address[] memory sources, address[] memory oracles,) = _portfolio(BORROWER);
        uint256[] memory tvls = aggregator.getTVLMultiple(sources, oracles);

        uint256 reservesWithDebt;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertEq(tvls[id], _reserveSupplied(id), "SUPPLY key yields reserve total supplied");
            assertEq(tvls[RESERVE_COUNT + id], _reserveDebt(id), "DEBT key yields reserve aggregate borrows");
            assertGt(tvls[id], 0, "every reserve has supply at the pinned block");
            assertTrue(tvls[RESERVE_COUNT + id] != tvls[id], "a debt key never returns total supplied");

            if (tvls[RESERVE_COUNT + id] != 0) ++reservesWithDebt;
            if (id != USDC_ID) {
                assertEq(_reserveDebt(id), 0, "live chain: tokenized stock reserves carry zero aggregate debt");
            }
            (, uint256 reservePremium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);
            assertEq(reservePremium, 0, "the premium half of this aggregate is zero: it verifies `drawn` only");
        }

        assertEq(reservesWithDebt, 1, "USDC is the only reserve with outstanding borrows at the pinned block");
        assertGt(_reserveDebt(USDC_ID), 0, "and its aggregate borrows are non-zero");
        assertLt(_reserveDebt(USDC_ID), _reserveSupplied(USDC_ID), "borrowed is a subset of supplied");

        // reserve-level totals are subject to the identical cross-reserve scale hazard
        assertEq(oracle.decimals(keys[USDC_ID]) + 2, oracle.decimals(keys[AAPL_ID]), "6-decimal vs 8-decimal totals");
    }

    /// @notice Reserve-level PPS through the aggregator is identity on BOTH legs of every reserve, at that
    ///         reserve's own scale. This is what makes within-reserve netting unit-safe and cross-reserve
    ///         addition unsafe: the aggregator returns eight 1e8 values and one 1e6 value per leg and
    ///         performs no normalization.
    function test_Nav_GetPricePerShareMultiple_IdentityOnBothLegs() public view {
        (address[] memory sources, address[] memory oracles,) = _portfolio(BORROWER);
        uint256[] memory pps = aggregator.getPricePerShareMultiple(sources, oracles);

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 expected = 10 ** uint256(oracle.decimals(keys[id]));
            assertEq(pps[id], expected, "supply leg identity PPS at the reserve's scale");
            assertEq(pps[RESERVE_COUNT + id], expected, "debt leg identity PPS at the same scale");
            assertEq(pps[id], id == USDC_ID ? 1e6 : 1e8, "stocks at 1e8, USDC at 1e6");
        }
    }

    /*//////////////////////////////////////////////////////////////
          G. THE premium TERM IS ZERO AT THIS BLOCK — STATED, NOT ASSUMED
    //////////////////////////////////////////////////////////////*/

    /// @notice SCOPE ACKNOWLEDGEMENT, asserted rather than commented: at the pinned block the `premiumDebt`
    ///         component of `getUserDebt` and `getReserveDebt` is EXACTLY ZERO on every leg of every reserve
    ///         of this market, for both live accounts. So every debt magnitude this NAV suite nets,
    ///         double-counts or aggregates is the `drawn` component alone, and deleting `+ premiumDebt` from
    ///         `AaveV4ReserveOracle.getBalanceOfOwner` / `getTVL` would not fail one assertion in this file.
    ///         The premium term's real coverage lives in the unit suite
    ///         (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`:
    ///         `test_debt_balanceOfOwner_isDrawnPlusPremium`, `test_debt_balanceOfOwner_premiumOnly`,
    ///         `test_fuzz_debt_balanceOfOwner_sumNeverTruncates`), where a premium is settable on the mock.
    /// @dev TRIPWIRE, NOT A CLAIM ABOUT AAVE. Premium is re-rated by `updateUserRiskPremium` and rides the
    ///      live hub index, so it can become non-zero on this market later. If these assertions ever fail,
    ///      the fork suite has stopped being degenerate in `premium` and its `drawn + premium` claims have
    ///      become real evidence — update the SCOPE LIMIT note rather than deleting this test. Do not mock a
    ///      premium onto a fork test to make the term non-zero.
    function test_Nav_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite() public view {
        address[2] memory users = [BORROWER, WHALE];
        uint256 totalDrawn;

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (uint256 reserveDrawn, uint256 reservePremium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);
            assertEq(reservePremium, 0, "reserve-level premium is zero on every reserve at the pinned block");
            assertEq(_reserveDebt(id), reserveDrawn, "so the `_reserveDebt` helper's sum is its drawn component alone");
            assertEq(oracle.getTVL(debtKeys[id]), reserveDrawn, "and the DEBT key's getTVL carries no premium");
            totalDrawn += reserveDrawn;

            for (uint256 u; u < users.length; ++u) {
                (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(id, users[u]);
                assertEq(premium, 0, "user-level premium is zero on every leg for both live accounts");
                assertEq(_debt(id, users[u]), drawn, "so the `_debt` helper's sum is its drawn component alone");
                assertEq(
                    oracle.getBalanceOfOwner(debtKeys[id], users[u]),
                    drawn,
                    "and every debt entry this suite nets is premium-free"
                );
            }
        }

        // degenerate in `premium` only — the drawn component is genuinely live
        assertGt(totalDrawn, 0, "there IS live drawn debt in this market, so only the premium term is degenerate");
        assertGt(_debt(USDC_ID, BORROWER), 0, "the borrower's USDC debt is the market's only user-level debt");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the realistic 16-entry SuperVault pricing shape: eight SUPPLY keys then eight DEBT keys,
    ///      one oracle address for every entry, one owner for every entry.
    function _portfolio(address owner_)
        internal
        view
        returns (address[] memory sources, address[] memory oracles, address[] memory owners)
    {
        uint256 n = RESERVE_COUNT * 2;
        sources = new address[](n);
        oracles = new address[](n);
        owners = new address[](n);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            sources[id] = keys[id];
            sources[RESERVE_COUNT + id] = debtKeys[id];
        }
        for (uint256 i; i < n; ++i) {
            oracles[i] = address(oracle);
            owners[i] = owner_;
        }
    }

    /// @dev `address[][]` owners shape required by the ISOLATING batch on the oracle itself.
    function _ownersMatrix(address owner_, uint256 n) internal pure returns (address[][] memory owners) {
        owners = new address[][](n);
        for (uint256 i; i < n; ++i) {
            owners[i] = new address[](1);
            owners[i][0] = owner_;
        }
    }

    function _one(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    /// @dev Propose, warp past DEREGISTER_DELAY, execute. Mirrors the real governed sequence; the warp is
    ///      why every expectation in a deregistration test is re-read from the spoke afterwards.
    function _deregister(address key) internal {
        registry.proposeDeregisterReserve(key);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() + 1);
        registry.executeDeregisterReserve(key);
    }

    function _supplied(uint256 id, address user) internal view returns (uint256) {
        return IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(id, user);
    }

    /// @dev `drawn + premium`, mirroring `AaveV4ReserveOracle.getBalanceOfOwner` on a DEBT key. NOTE the
    ///      `premium` addend is zero at this block (see the contract-level SCOPE LIMIT note), so no caller
    ///      of this helper exercises it.
    function _debt(uint256 id, address user) internal view returns (uint256) {
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(id, user);
        return drawn + premium;
    }

    function _reserveSupplied(uint256 id) internal view returns (uint256) {
        return IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(id);
    }

    /// @dev `drawn + premium`, mirroring `AaveV4ReserveOracle.getTVL` on a DEBT key. Same caveat as `_debt`:
    ///      the `premium` addend is zero at this block, so this helper's sum is its drawn component alone.
    function _reserveDebt(uint256 id) internal view returns (uint256) {
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);
        return drawn + premium;
    }
}
