// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

/// @title AaveV4ReserveOracleSideKeyE2EFork
/// @author Superform Labs
/// @notice Live-Base coverage of the SIDE-IN-KEY contract itself, across EVERY reserve of the tokenized
///         STOCKS market (aave-address-book `AaveV4Base`: the MAG7 spoke, seven equities at 8 decimals plus
///         USDC at 6). The sibling equities suite proves the aggregation hazards that appear when a consumer
///         reads both legs of one reserve together; this file proves the narrower, more fundamental property
///         the merge introduced — that the key alone fixes what a read MEANS.
/// @dev THE MISREAD THIS DESIGN MAKES IMPOSSIBLE. Before the merge, two oracle CONTRACTS shared one key and
///      the leg was selected by which oracle address a caller passed. Pass the wrong one and
///      `getBalanceOfOwner` silently returned the other leg: a debt query answered with collateral, which on a
///      leveraged position is a balance of the wrong economic sign. After the merge there is ONE oracle
///      address and two keys, so the only way to read the debt leg is to hold the debt key — and a debt key
///      can never resolve to the supply figure, because the registry bound `Side.DEBT` into it at
///      registration. Section A asserts that per reserve across all eight; sections B and C pin what the side
///      must NOT change (the reserve binding, decimals, PPS); section D pins the per-key deregistration
///      asymmetry on a real stock reserve; section E pins per-leg `getTVL`.
/// @dev LIVE FACTS at `FORK_BLOCK` (51_778_000), all derived from spoke views inside the tests rather than
///      hardcoded: every one of the eight reserves has non-zero total supplied; `BORROWER` supplies in all
///      eight; the ONLY debt anywhere in this market — user-level and reserve-level — is on USDC (reserveId
///      7). All seven tokenized equities have `getReserveDebt == (0, 0)`: nothing has ever been borrowed
///      against them, so their DEBT keys legitimately read zero while their SUPPLY keys read the whole pool.
/// @dev SCOPE LIMIT OF THIS FORK SUITE — THE `premium` TERM IS ZERO HERE. `getBalanceOfOwner` and `getTVL`
///      return `drawnDebt + premiumDebt` on a DEBT key, but at this pinned block the premium component is
///      exactly ZERO everywhere in this market: `getUserDebt(7, BORROWER)` is `(50032162, 0)` and
///      `getReserveDebt(7)` is `(50373206, 0)`, and reserve 7 is the only reserve carrying any debt at all.
///      So no test in this file can distinguish `drawn + premium` from `drawn` alone — deleting the
///      `+ premiumDebt` term from the oracle would leave every assertion here passing. That is a property of
///      the chain at this block, not of the oracle, so this suite ACKNOWLEDGES it rather than claiming
///      otherwise: `test_E2E_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite` asserts the
///      premium is zero on every leg, so the day a live risk premium appears the acknowledgement fails and
///      these tests stop being silently degenerate. THE SUMMATION ITSELF IS COVERED IN THE UNIT SUITE
///      (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`): `test_debt_balanceOfOwner_isDrawnPlusPremium`,
///      `test_debt_balanceOfOwner_premiumOnly`, `test_debt_balanceOfOwner_drawnOnly` and
///      `test_fuzz_debt_balanceOfOwner_sumNeverTruncates` all set a non-zero premium on the mock spoke.
///      Do NOT mock a premium onto a fork test and do not re-pin the block to manufacture one.
contract AaveV4ReserveOracleSideKeyE2EFork is Test {
    // aave-address-book AaveV4Base.sol
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant TSLAc = 0xb2000000000000000000001e800a7f5189430cD0;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal constant AAPL_ID = 0;
    uint256 internal constant TSLA_ID = 6;
    uint256 internal constant USDC_ID = 7;
    uint256 internal constant RESERVE_COUNT = 8;

    /// @dev live positions at the pinned block
    address internal constant BORROWER = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F; // supplies all 8, borrows USDC
    address internal constant WHALE = 0x9e3787f9f7f0fF7Eea9e36628BecA431B61AE647; // supplies, never borrows

    uint256 internal constant FORK_BLOCK = 51_778_000;

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;
    address internal ledgerConfig;

    address[] internal keys; // SUPPLY keys, index == reserveId
    address[] internal debtKeys; // DEBT keys, index == reserveId

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (address supplyKey, address debtKey) = registry.registerReserve(MAG7_SPOKE, id);
            keys.push(supplyKey);
            debtKeys.push(debtKey);
        }
    }

    /*//////////////////////////////////////////////////////////////
       A. THE MISREAD THE SIDE-IN-KEY DESIGN MAKES IMPOSSIBLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Per reserve, across all eight live reserves: the two sibling keys return GENUINELY DIFFERENT
    ///         things from the one oracle, and the DEBT key can never hand back the SUPPLY figure. Each read is
    ///         pinned to its own spoke view — `getUserSuppliedAssets` for the supply key, `getUserDebt`
    ///         (drawn + premium) for the debt key — so neither leg can leak into the other. This is the
    ///         pre-merge failure mode (one key, leg chosen by oracle address) rendered unrepresentable.
    /// @dev PREMIUM CAVEAT: the `drawn + premium` expectation below is NOT evidence for the premium term —
    ///      `premium` is asserted zero at this block (see the contract-level SCOPE LIMIT note), so this test
    ///      verifies `drawn` only. The summation is covered by the unit suite's premium-bearing cases.
    function test_E2E_EveryReserve_DebtKeyCanNeverYieldTheSupplyFigure() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 supplied = IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(id, BORROWER);
            (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(id, BORROWER);
            uint256 debt = drawn + premium;

            assertEq(premium, 0, "premium is zero at this block: this expectation pins `drawn` only");
            assertGt(supplied, 0, "live supply position on every reserve of this market");

            // the supply key answers with supply, the debt key answers with debt — never the other way round
            assertEq(oracle.getBalanceOfOwner(keys[id], BORROWER), supplied, "SUPPLY key resolves the supply leg");
            assertEq(oracle.getBalanceOfOwner(debtKeys[id], BORROWER), debt, "DEBT key resolves the debt leg");

            // the misread itself: a debt read can never come back as the supply figure
            assertTrue(
                oracle.getBalanceOfOwner(debtKeys[id], BORROWER) != supplied,
                "a DEBT key read must never yield the SUPPLY figure"
            );
            assertTrue(keys[id] != debtKeys[id], "the two legs are keyed apart on every reserve");
        }
    }

    /// @notice The same property for a user with NO debt anywhere: every debt key reads zero while every supply
    ///         key reads its live non-zero position. A sideless read against one oracle address therefore
    ///         cannot invent a debt position out of a collateral balance.
    function test_E2E_EveryReserve_NoDebtUser_DebtKeysNeverEchoSupply() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 supplied = oracle.getBalanceOfOwner(keys[id], WHALE);
            assertGt(supplied, 0, "whale supplies on every reserve");
            assertEq(oracle.getBalanceOfOwner(debtKeys[id], WHALE), 0, "whale holds no debt on any leg");
            assertEq(oracle.getTVLByOwnerOfShares(debtKeys[id], WHALE), 0, "the TVL alias resolves the same side");
        }
    }

    /*//////////////////////////////////////////////////////////////
       B. getReserveInfo — ONE BINDING, TWO SIDES, NOTHING ELSE
    //////////////////////////////////////////////////////////////*/

    /// @notice On the live-registered legs of every reserve, the two keys share spoke, reserveId, underlying
    ///         and decimals and differ ONLY in `Side`. The side is therefore pure extra information: it adds a
    ///         discriminator without perturbing the reserve binding the oracle reads through.
    function test_E2E_ReserveInfo_BothLegs_DifferOnlyInSide() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
                registry.getReserveInfo(keys[id]);
            (address dSpoke, uint256 dId, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
                registry.getReserveInfo(debtKeys[id]);

            assertEq(sSpoke, MAG7_SPOKE, "supply leg bound to the live MAG7 spoke");
            assertEq(dSpoke, sSpoke, "same spoke on both legs");
            assertEq(sId, id, "supply leg bound to its own reserveId");
            assertEq(dId, sId, "same reserveId on both legs");
            assertEq(dUnderlying, sUnderlying, "same underlying on both legs");
            assertEq(dDecimals, sDecimals, "same decimals on both legs");
            assertTrue(sSide == AaveV4ReserveRegistryV2.Side.SUPPLY, "legacy key is the SUPPLY leg");
            assertTrue(dSide == AaveV4ReserveRegistryV2.Side.DEBT, "domain-separated key is the DEBT leg");

            // and the binding matches what the spoke itself reports for that reserve
            IAaveV4Spoke.Reserve memory reserve = IAaveV4Spoke(MAG7_SPOKE).getReserve(id);
            assertEq(sUnderlying, reserve.underlying, "underlying bound from the live reserve struct");
            assertEq(sDecimals, reserve.decimals, "decimals bound from the live reserve struct");
        }
    }

    /// @notice Named stocks, spelled out: both legs of AAPL resolve to AAPLc and both legs of TSLA to TSLAc,
    ///         so the side can never be confused with a change of underlying. A debt key that silently named a
    ///         different token would make every downstream denomination wrong.
    function test_E2E_ReserveInfo_NamedStocks_BothLegsShareTheUnderlying() public view {
        (,, address aaplSupplyUnderlying,,) = registry.getReserveInfo(keys[AAPL_ID]);
        (,, address aaplDebtUnderlying,, AaveV4ReserveRegistryV2.Side aaplDebtSide) =
            registry.getReserveInfo(debtKeys[AAPL_ID]);
        assertEq(aaplSupplyUnderlying, AAPLc, "AAPL supply leg denominated in AAPLc");
        assertEq(aaplDebtUnderlying, AAPLc, "AAPL debt leg denominated in the SAME AAPLc");
        assertTrue(aaplDebtSide == AaveV4ReserveRegistryV2.Side.DEBT, "only the side differs");

        (,, address tslaSupplyUnderlying,,) = registry.getReserveInfo(keys[TSLA_ID]);
        (,, address tslaDebtUnderlying,, AaveV4ReserveRegistryV2.Side tslaDebtSide) =
            registry.getReserveInfo(debtKeys[TSLA_ID]);
        assertEq(tslaSupplyUnderlying, TSLAc, "TSLA supply leg denominated in TSLAc");
        assertEq(tslaDebtUnderlying, TSLAc, "TSLA debt leg denominated in the SAME TSLAc");
        assertTrue(tslaDebtSide == AaveV4ReserveRegistryV2.Side.DEBT, "only the side differs");

        (,, address usdcSupplyUnderlying,,) = registry.getReserveInfo(keys[USDC_ID]);
        (,, address usdcDebtUnderlying,,) = registry.getReserveInfo(debtKeys[USDC_ID]);
        assertEq(usdcSupplyUnderlying, USDC, "USDC supply leg denominated in USDC");
        assertEq(usdcDebtUnderlying, USDC, "USDC debt leg denominated in the SAME USDC");
    }

    /*//////////////////////////////////////////////////////////////
          C. decimals / PPS ARE SIDE-INDEPENDENT ON REAL RESERVES
    //////////////////////////////////////////////////////////////*/

    /// @notice `decimals` and `getPricePerShare` resolve from the shared reserve binding, so they are
    ///         side-INDEPENDENT on the live market: 8 decimals and 1e8 identity PPS on every equity leg (both
    ///         sides), 6 and 1e6 on both USDC legs. Identity on both sides is what makes netting a reserve's
    ///         two legs unit-valid; a side-dependent PPS would silently rescale one leg against the other.
    function test_E2E_DecimalsAndPps_AreSideIndependent() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint8 expected = id == USDC_ID ? 6 : 8;
            uint256 expectedPps = 10 ** uint256(expected);

            assertEq(oracle.decimals(keys[id]), expected, "supply-leg decimals from the live reserve");
            assertEq(oracle.decimals(debtKeys[id]), expected, "debt-leg decimals identical to the supply leg");
            assertEq(oracle.getPricePerShare(keys[id]), expectedPps, "identity PPS on the supply leg");
            assertEq(oracle.getPricePerShare(debtKeys[id]), expectedPps, "identity PPS on the debt leg");
        }

        // spelled out for the two scales this market mixes
        assertEq(oracle.getPricePerShare(keys[AAPL_ID]), 1e8, "equity supply leg: 1e8");
        assertEq(oracle.getPricePerShare(debtKeys[AAPL_ID]), 1e8, "equity debt leg: 1e8");
        assertEq(oracle.getPricePerShare(keys[USDC_ID]), 1e6, "USDC supply leg: 1e6");
        assertEq(oracle.getPricePerShare(debtKeys[USDC_ID]), 1e6, "USDC debt leg: 1e6");
    }

    /*//////////////////////////////////////////////////////////////
      D. PER-KEY DEREGISTRATION ON A REAL STOCK RESERVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Registration is per RESERVE (both legs in one call) while deregistration is per KEY: dropping
    ///         one leg of a real stock reserve through the full propose/warp/execute timelock leaves the other
    ///         leg FULLY readable — binding, decimals, PPS, owner balance and reserve TVL all intact — while
    ///         the dropped key reverts `RESERVE_NOT_REGISTERED`. Both directions are exercised on two
    ///         different live stocks: TSLA loses its debt leg, AAPL loses its supply leg. This asymmetry is
    ///         deliberate (the debt leg can be withdrawn from exposure without disturbing supply NAV reads),
    ///         so the ops runbook has to name the leg it is removing.
    function test_E2E_DeregisterOneLeg_OtherLegStaysFullyReadable() public {
        bytes4 notRegistered = AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector;

        // snapshots of the legs that must survive, taken before the timelock warp
        uint256 tslaSupplyBefore = oracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER);
        uint256 tslaSupplyTvlBefore = oracle.getTVL(keys[TSLA_ID]);
        uint256 aaplDebtBefore = oracle.getBalanceOfOwner(debtKeys[AAPL_ID], BORROWER);
        uint256 aaplDebtTvlBefore = oracle.getTVL(debtKeys[AAPL_ID]);
        assertGt(tslaSupplyBefore, 0, "live TSLA collateral position to protect");
        assertGt(tslaSupplyTvlBefore, 0, "live TSLA pool to protect");

        // --- drop the DEBT leg of TSLA and the SUPPLY leg of AAPL through the timelock ---
        registry.proposeDeregisterReserve(debtKeys[TSLA_ID]);
        registry.proposeDeregisterReserve(keys[AAPL_ID]);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(debtKeys[TSLA_ID]);
        registry.executeDeregisterReserve(keys[AAPL_ID]);

        // --- the dropped keys are gone ---
        assertFalse(registry.isRegistered(debtKeys[TSLA_ID]), "TSLA debt leg dropped");
        assertFalse(registry.isRegistered(keys[AAPL_ID]), "AAPL supply leg dropped");
        vm.expectRevert(notRegistered);
        oracle.getBalanceOfOwner(debtKeys[TSLA_ID], BORROWER);
        vm.expectRevert(notRegistered);
        oracle.getTVL(keys[AAPL_ID]);

        // --- TSLA's surviving SUPPLY leg is fully readable and unchanged ---
        assertTrue(registry.isRegistered(keys[TSLA_ID]), "TSLA supply leg survives its sibling's removal");
        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(keys[TSLA_ID]);
        assertEq(sSpoke, MAG7_SPOKE, "surviving binding intact: spoke");
        assertEq(sId, TSLA_ID, "surviving binding intact: reserveId");
        assertEq(sUnderlying, TSLAc, "surviving binding intact: underlying");
        assertEq(sDecimals, 8, "surviving binding intact: decimals");
        assertTrue(sSide == AaveV4ReserveRegistryV2.Side.SUPPLY, "surviving binding intact: side");
        assertEq(oracle.decimals(keys[TSLA_ID]), 8, "surviving leg still reports decimals");
        assertEq(oracle.getPricePerShare(keys[TSLA_ID]), 1e8, "surviving leg still reports identity PPS");
        assertEq(
            oracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER),
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(TSLA_ID, BORROWER),
            "surviving leg still tracks the live spoke"
        );
        assertEq(
            oracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER),
            tslaSupplyBefore,
            "the surviving collateral read is unmoved by the sibling's removal (no borrows accrue on this reserve)"
        );
        assertEq(oracle.getTVL(keys[TSLA_ID]), tslaSupplyTvlBefore, "surviving reserve TVL unmoved");

        // --- AAPL's surviving DEBT leg is fully readable and unchanged ---
        assertTrue(registry.isRegistered(debtKeys[AAPL_ID]), "AAPL debt leg survives its sibling's removal");
        (,, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(debtKeys[AAPL_ID]);
        assertEq(dUnderlying, AAPLc, "surviving debt binding intact: underlying");
        assertEq(dDecimals, 8, "surviving debt binding intact: decimals");
        assertTrue(dSide == AaveV4ReserveRegistryV2.Side.DEBT, "surviving debt binding intact: side");
        assertEq(oracle.getPricePerShare(debtKeys[AAPL_ID]), 1e8, "surviving debt leg still reports identity PPS");
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(AAPL_ID, BORROWER);
        assertEq(premium, 0, "premium is zero at this block: the sum below pins `drawn` only");
        assertEq(
            oracle.getBalanceOfOwner(debtKeys[AAPL_ID], BORROWER),
            drawn + premium,
            "surviving debt leg still tracks the live spoke"
        );
        assertEq(oracle.getBalanceOfOwner(debtKeys[AAPL_ID], BORROWER), aaplDebtBefore, "surviving debt read unmoved");
        assertEq(oracle.getTVL(debtKeys[AAPL_ID]), aaplDebtTvlBefore, "surviving debt reserve TVL unmoved");

        // --- every other reserve is wholly untouched: deregistration reaches exactly the two named keys ---
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            if (id == TSLA_ID || id == AAPL_ID) continue;
            assertTrue(registry.isRegistered(keys[id]), "unrelated supply leg untouched");
            assertTrue(registry.isRegistered(debtKeys[id]), "unrelated debt leg untouched");
        }
    }

    /*//////////////////////////////////////////////////////////////
                 E. PER-LEG getTVL ON REAL RESERVES
    //////////////////////////////////////////////////////////////*/

    /// @notice `getTVL` is reserve-level and per leg: the SUPPLY key returns total supplied assets, the DEBT
    ///         key returns the reserve's aggregate outstanding debt (the `totalBorrows()` analog) — never total
    ///         supplied. VERIFIED against the live chain: at the pinned block every one of the seven tokenized
    ///         stock reserves has `getReserveDebt == (0, 0)` — nothing has ever been borrowed against the
    ///         equities — so each stock's DEBT key reads zero while its SUPPLY key reads the whole non-zero
    ///         pool. That split is precisely the figure a debt key must never substitute the supply one for.
    /// @dev WHAT "VERIFIED" MEANS HERE, PRECISELY: `getReserveDebt` returns `(0, 0)` on these reserves, so
    ///      BOTH components of the aggregate are zero and this test says nothing about the `+ premiumDebt`
    ///      term in `getTVL` — it would pass with that term deleted. Both components are asserted zero
    ///      individually below so the claim is explicit. See the contract-level SCOPE LIMIT note; the
    ///      premium term's real coverage is in the unit suite.
    function test_E2E_GetTVL_PerLeg_StockReservesCarryNoDebt() public view {
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            if (id == USDC_ID) continue;

            uint256 totalSupplied = IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(id);
            (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);

            assertGt(totalSupplied, 0, "every stock reserve holds a live supplied pool");
            assertEq(oracle.getTVL(keys[id]), totalSupplied, "SUPPLY key returns total supplied assets");
            assertEq(oracle.getTVL(debtKeys[id]), drawn + premium, "DEBT key returns the reserve debt aggregate");
            assertEq(drawn, 0, "no drawn borrowing against tokenized equities at the pinned block");
            assertEq(premium, 0, "and no risk premium either: the aggregate is zero in BOTH components");
            assertEq(oracle.getTVL(debtKeys[id]), 0, "so the stock DEBT key reads zero while SUPPLY reads the pool");
            assertTrue(
                oracle.getTVL(debtKeys[id]) != oracle.getTVL(keys[id]),
                "a DEBT key's reserve aggregate is never the SUPPLY key's"
            );
        }
    }

    /// @notice The USDC reserve is the market's only borrowed one, so it pins the non-degenerate case: both
    ///         legs of `getTVL` are non-zero, each equals its own spoke aggregate, and the borrowed total is a
    ///         strict subset of the supplied total — the two figures a debt key and a supply key must keep
    ///         apart.
    /// @dev NON-DEGENERATE IN `drawn`, STILL DEGENERATE IN `premium`. This is the only reserve in the market
    ///      with live debt, but its premium component is zero at this block — `getReserveDebt(7)` is
    ///      `(50373206, 0)` — so the non-zero aggregate asserted here comes entirely from `drawn`. The
    ///      premium being zero is asserted explicitly so this test reports it the day it changes; the
    ///      `drawn + premium` summation is covered by the unit suite (see the contract-level SCOPE LIMIT).
    function test_E2E_GetTVL_PerLeg_UsdcReserveIsTheOnlyBorrowedOne() public view {
        uint256 totalSupplied = IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(USDC_ID);
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(USDC_ID);

        assertGt(drawn, 0, "the live aggregate comes from the drawn component");
        assertEq(premium, 0, "premium is zero at this block: the aggregate below is `drawn` alone");
        assertEq(oracle.getTVL(keys[USDC_ID]), totalSupplied, "SUPPLY key returns total supplied USDC");
        assertEq(oracle.getTVL(debtKeys[USDC_ID]), drawn + premium, "DEBT key returns total borrowed USDC");
        assertGt(oracle.getTVL(keys[USDC_ID]), 0, "live supplied pool");
        assertGt(oracle.getTVL(debtKeys[USDC_ID]), 0, "live borrowed aggregate");
        assertLt(
            oracle.getTVL(debtKeys[USDC_ID]),
            oracle.getTVL(keys[USDC_ID]),
            "borrowed is a strict subset of supplied on a healthy reserve"
        );
    }

    /*//////////////////////////////////////////////////////////////
          F. THE premium TERM IS ZERO AT THIS BLOCK — STATED, NOT ASSUMED
    //////////////////////////////////////////////////////////////*/

    /// @notice SCOPE ACKNOWLEDGEMENT, asserted rather than commented: at the pinned block the `premiumDebt`
    ///         component of `getUserDebt` and `getReserveDebt` is EXACTLY ZERO on every leg of every reserve
    ///         in this market, for both live accounts. Every `drawn + premium` expectation in this file is
    ///         therefore verifying `drawn` alone — deleting `+ premiumDebt` from `AaveV4ReserveOracle` would
    ///         not fail a single test here. The premium term's real coverage lives in the unit suite
    ///         (`test/unit/accounting/oracles/AaveV4Oracles.t.sol`:
    ///         `test_debt_balanceOfOwner_isDrawnPlusPremium`, `test_debt_balanceOfOwner_premiumOnly`,
    ///         `test_debt_balanceOfOwner_drawnOnly`, `test_fuzz_debt_balanceOfOwner_sumNeverTruncates`),
    ///         where a non-zero premium is settable on the mock spoke.
    /// @dev THIS TEST IS A TRIPWIRE, NOT A GUARANTEE ABOUT AAVE. Premium is re-rated by
    ///      `updateUserRiskPremium` and rides the live hub index, so it CAN become non-zero on this market
    ///      in future. The day it does at this block — a reorg-independent chain fact, so in practice only
    ///      if the block is re-pinned — these assertions fail and tell the reader that the fork suite has
    ///      stopped being degenerate in `premium` and its `drawn + premium` claims have become real
    ///      evidence. Do not weaken it by mocking a premium onto a fork test.
    function test_E2E_PremiumTerm_IsZeroAtThisBlock_SummationCoveredByTheUnitSuite() public view {
        address[2] memory users = [BORROWER, WHALE];
        uint256 totalDrawn;

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (uint256 reserveDrawn, uint256 reservePremium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(id);
            assertEq(reservePremium, 0, "reserve-level premium is zero on every reserve at the pinned block");
            assertEq(
                oracle.getTVL(debtKeys[id]),
                reserveDrawn,
                "so a DEBT key's getTVL equals the drawn component alone: the premium term is unexercised"
            );
            totalDrawn += reserveDrawn;

            for (uint256 u; u < users.length; ++u) {
                (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(id, users[u]);
                assertEq(premium, 0, "user-level premium is zero on every leg for both live accounts");
                assertEq(
                    oracle.getBalanceOfOwner(debtKeys[id], users[u]),
                    drawn,
                    "so getBalanceOfOwner on a DEBT key equals the drawn component alone"
                );
            }
        }

        // the suite is not vacuous in `drawn` — only in `premium`
        assertGt(totalDrawn, 0, "there IS live drawn debt in this market, so only the premium term is degenerate");
        (uint256 usdcDrawn, uint256 usdcPremium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertGt(usdcDrawn, 0, "the borrower's USDC drawn debt is the market's only user-level debt");
        assertEq(usdcPremium, 0, "and it carries no risk premium at the pinned block");
    }
}
