// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ConfigureAaveV4ReserveRegistry } from "../../script/ConfigureAaveV4ReserveRegistry.s.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveRegistry } from "../../src/accounting/oracles/AaveV4ReserveRegistry.sol";

/// @dev Exposes the seeding primitive so it can run against a fresh registry on a live fork
///      without a broadcast or the env/role preamble.
contract SeedHarness is ConfigureAaveV4ReserveRegistry {
    function seed(AaveV4ReserveRegistryV2 registry, address spoke) external returns (SeedResult memory) {
        return _seedSpoke(registry, spoke);
    }

    function defaultSpokes(uint64 chainId) external pure returns (address[] memory) {
        return _defaultSpokes(chainId);
    }

    function mag7Spoke() external pure returns (address) {
        return BASE_MAG7_SPOKE;
    }

    /// @dev Lets the test drop a single leg while holding MARKET_MANAGER_ROLE, so the half-registered state
    ///      the repair branch exists for can actually be constructed.
    function dropLeg(AaveV4ReserveRegistryV2 registry, address key) external {
        registry.proposeDeregisterReserve(key);
    }

    function executeDrop(AaveV4ReserveRegistryV2 registry, address key) external {
        registry.executeDeregisterReserve(key);
    }

    function seedMarkets(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        external
        returns (MarketResult memory)
    {
        return _seedMarkets(registry, chainId, spoke);
    }

    function registerOne(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 supplyId,
        uint256 borrowId
    )
        external
        returns (bool)
    {
        return _registerOneMarket(registry, spoke, supplyId, borrowId);
    }

    function assertFullyConfigured(AaveV4ReserveRegistryV2 registry, uint64 chainId, address spoke) external view {
        _assertSpokeFullyConfigured(registry, chainId, spoke);
    }

    function loanReserveId(uint64 chainId) external pure returns (uint256) {
        return _defaultLoanReserveId(chainId);
    }

    /// @dev Registers a market on the registry DIRECTLY, bypassing `_registerOneMarket`'s guards. This is
    ///      how an ambiguous configuration can really arise — a manager calling the registry rather than
    ///      this script — and it is the only way to build the pre-existing state the check path must reject.
    function registerMarketRaw(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 supplyId,
        uint256 borrowId
    )
        external
        returns (address)
    {
        return registry.registerMarket(spoke, supplyId, borrowId);
    }

    function printIdleCanonicality(AaveV4ReserveRegistryV2 registry, address spoke) external view returns (uint256) {
        return _printIdleCanonicality(registry, spoke);
    }

    function idleSettlementCandidates(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 reserveId
    )
        external
        view
        returns (uint256)
    {
        return _idleSettlementCandidates(registry, spoke, reserveId);
    }

    function idleSettlementMarket(
        uint64 chainId,
        address spoke,
        uint256 reserveId,
        AaveV4ReserveRegistryV2 registry
    )
        external
        view
        returns (address)
    {
        return _idleSettlementMarket(chainId, spoke, reserveId, registry);
    }

    function assertIdleSettlementDesignated(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke,
        uint256 reserveId
    )
        external
        view
    {
        _assertIdleSettlementDesignated(registry, chainId, spoke, reserveId);
    }

    function printIdleSettlement(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        external
        view
        returns (uint256)
    {
        return _printIdleSettlement(registry, chainId, spoke);
    }

    /// @dev The printer `runCheckAll` actually calls, so a test can prove the section is reachable.
    function printMarketStatus(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        external
        view
        returns (uint256)
    {
        return _printMarketStatus(registry, chainId, spoke);
    }

    function proposeDropMarket(AaveV4ReserveRegistryV2 registry, address marketKey) external {
        registry.proposeDeregisterMarket(marketKey);
    }

    function executeDropMarket(AaveV4ReserveRegistryV2 registry, address marketKey) external {
        registry.executeDeregisterMarket(marketKey);
    }

    function noLoanReserve() external pure returns (uint256) {
        return NO_LOAN_RESERVE;
    }
}

/// @title ConfigureAaveV4ReserveRegistryTest
/// @notice The seeding script must register exactly the reserves Aave lists on the spoke, bind the same
///         underlying/decimals the registry reads itself, and be a no-op on a second run.
contract ConfigureAaveV4ReserveRegistryTest is Test {
    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 internal constant MAG7_LISTED_RESERVES = 8; // 7 equities + USDC at the pinned block

    SeedHarness internal harness;
    AaveV4ReserveRegistryV2 internal registry;
    address internal spoke;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);
        harness = new SeedHarness();
        spoke = harness.mag7Spoke();
        // Admin = harness so it holds MARKET_MANAGER_ROLE, exactly like DEPLOYER after a real deploy.
        registry = new AaveV4ReserveRegistryV2(address(harness));
    }

    function test_Seed_RegistersEveryListedReserveOnce() public {
        ConfigureAaveV4ReserveRegistry.SeedResult memory first = harness.seed(registry, spoke);
        assertEq(first.listed, MAG7_LISTED_RESERVES, "listed");
        assertEq(first.registered, MAG7_LISTED_RESERVES, "registered on first run");
        assertEq(first.skipped, 0);

        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            // Both legs must be present: one registerReserve call registers supply AND debt
            address key = registry.computeReserveKey(spoke, id);
            address debtKey = registry.computeDebtKey(spoke, id);
            assertTrue(registry.isRegistered(key), "every id registered (supply leg)");
            assertTrue(registry.isRegistered(debtKey), "every id registered (debt leg)");
            (address spoke_, uint256 id_,,, AaveV4ReserveRegistryV2.Side supplySide) = registry.getReserveInfo(key);
            assertEq(spoke_, spoke);
            assertEq(id_, id);
            assertTrue(supplySide == AaveV4ReserveRegistryV2.Side.SUPPLY, "supply leg side");
            (address dSpoke, uint256 dId,,, AaveV4ReserveRegistryV2.Side debtSide) = registry.getReserveInfo(debtKey);
            assertEq(dSpoke, spoke, "debt leg binds the same spoke");
            assertEq(dId, id, "debt leg binds the same reserveId");
            assertTrue(debtSide == AaveV4ReserveRegistryV2.Side.DEBT, "debt leg side");
        }
        (,, address u0, uint8 d0,) = registry.getReserveInfo(registry.computeReserveKey(spoke, 0));
        assertEq(u0, AAPLc, "reserve 0 is AAPLc");
        assertEq(d0, 8);
        (,, address u7, uint8 d7,) = registry.getReserveInfo(registry.computeReserveKey(spoke, 7));
        assertEq(u7, USDC_BASE, "reserve 7 is USDC");
        assertEq(d7, 6);
        assertFalse(registry.isRegistered(registry.computeReserveKey(spoke, MAG7_LISTED_RESERVES)), "no phantom id");
        assertFalse(registry.isRegistered(registry.computeDebtKey(spoke, MAG7_LISTED_RESERVES)), "no phantom debt id");
    }

    function test_Seed_SecondRunIsANoOp() public {
        harness.seed(registry, spoke);
        ConfigureAaveV4ReserveRegistry.SeedResult memory second = harness.seed(registry, spoke);
        assertEq(second.listed, MAG7_LISTED_RESERVES);
        assertEq(second.registered, 0, "nothing new");
        assertEq(second.skipped, MAG7_LISTED_RESERVES);
    }

    function test_Seed_FillsOnlyTheGapAfterAPartialRegistration() public {
        // Operator registered two reserves by hand earlier: the script must add the other six only.
        vm.startPrank(address(harness));
        registry.registerReserve(spoke, 3);
        registry.registerReserve(spoke, 7);
        vm.stopPrank();

        ConfigureAaveV4ReserveRegistry.SeedResult memory r = harness.seed(registry, spoke);
        assertEq(r.registered, MAG7_LISTED_RESERVES - 2);
        assertEq(r.skipped, 2);
    }

    function test_Seed_RevertsForASpokeWithoutCode() public {
        vm.expectRevert(bytes("SPOKE_HAS_NO_CODE"));
        harness.seed(registry, address(0xdead));
    }

    function test_DefaultSpokes_BaseAndEthereumOnly() public view {
        assertEq(harness.defaultSpokes(8453)[0], spoke);
        assertEq(harness.defaultSpokes(1).length, 1);
        assertEq(harness.defaultSpokes(42_161).length, 0, "no default elsewhere: runSpoke is explicit");
    }

    function test_RunCheck_DoesNotRevertBeforeOrAfterSeeding() public {
        harness.runCheck(8453, address(registry), spoke);
        harness.seed(registry, spoke);
        harness.runCheck(8453, address(registry), spoke);
    }

    /*//////////////////////////////////////////////////////////////
            HALF-REGISTERED RESERVES: THE REPAIR BRANCH
    //////////////////////////////////////////////////////////////*/

    /// @dev Seeds, then drops one leg of reserve `id` through the full timelock
    function _dropOneLeg(uint256 id, bool dropDebt) internal returns (address droppedKey) {
        harness.seed(registry, spoke);
        droppedKey = dropDebt ? registry.computeDebtKey(spoke, id) : registry.computeReserveKey(spoke, id);
        harness.dropLeg(registry, droppedKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        harness.executeDrop(registry, droppedKey);
        assertFalse(registry.isRegistered(droppedKey), "leg dropped");
    }

    /// @notice A half-registered reserve must be REPAIRED by a re-seed, not skipped. Before the repair
    ///         branch existed the seeder saw the supply key present and `continue`d, leaving the debt key
    ///         permanently unresolvable while reporting success — and `registerReserve` can never fix it,
    ///         because its two-key guard rejects the surviving leg.
    function test_Seed_RepairsAHalfRegisteredReserve_DebtLegMissing() public {
        address droppedDebtKey = _dropOneLeg(0, true);

        ConfigureAaveV4ReserveRegistry.SeedResult memory r = harness.seed(registry, spoke);
        assertEq(r.repaired, 1, "exactly the one missing leg was repaired");
        assertEq(r.registered, 0, "nothing newly registered");
        assertEq(r.skipped, MAG7_LISTED_RESERVES - 1, "the other reserves were skipped as whole");
        assertTrue(registry.isRegistered(droppedDebtKey), "debt leg restored");
        (,,,, AaveV4ReserveRegistryV2.Side restoredSide) = registry.getReserveInfo(droppedDebtKey);
        assertTrue(restoredSide == AaveV4ReserveRegistryV2.Side.DEBT, "restored as DEBT");
    }

    /// @notice The mirror case: a missing SUPPLY leg is repaired and restored under the SUPPLY side
    function test_Seed_RepairsAHalfRegisteredReserve_SupplyLegMissing() public {
        address droppedSupplyKey = _dropOneLeg(6, false);

        ConfigureAaveV4ReserveRegistry.SeedResult memory r = harness.seed(registry, spoke);
        assertEq(r.repaired, 1, "one leg repaired");
        assertTrue(registry.isRegistered(droppedSupplyKey), "supply leg restored");
        (,,,, AaveV4ReserveRegistryV2.Side restoredSide) = registry.getReserveInfo(droppedSupplyKey);
        assertTrue(restoredSide == AaveV4ReserveRegistryV2.Side.SUPPLY, "restored as SUPPLY");
    }

    /// @notice A healthy registry needs no repairs — the counter stays zero, so a non-zero `repaired` is a
    ///         real signal that someone deregistered a single leg rather than routine noise
    function test_Seed_HealthyRegistry_RepairsNothing() public {
        harness.seed(registry, spoke);
        ConfigureAaveV4ReserveRegistry.SeedResult memory r = harness.seed(registry, spoke);
        assertEq(r.repaired, 0, "no repairs on a whole registry");
        assertEq(r.skipped, MAG7_LISTED_RESERVES, "every reserve skipped as whole");
    }

    /// @notice After repair the reserve is whole: both legs resolve and share one binding
    function test_Seed_AfterRepair_BothLegsResolveAndAgree() public {
        _dropOneLeg(3, true);
        harness.seed(registry, spoke);

        address supplyKey = registry.computeReserveKey(spoke, 3);
        address debtKey = registry.computeDebtKey(spoke, 3);
        (address s1, uint256 i1, address u1, uint8 d1,) = registry.getReserveInfo(supplyKey);
        (address s2, uint256 i2, address u2, uint8 d2,) = registry.getReserveInfo(debtKey);
        assertEq(s2, s1, "same spoke");
        assertEq(i2, i1, "same reserveId");
        assertEq(u2, u1, "same underlying");
        assertEq(d2, d1, "same decimals");
    }

    /*//////////////////////////////////////////////////////////////
                V1 -> V2 MIGRATION PARITY
    //////////////////////////////////////////////////////////////*/

    /// @notice The V2 seed must carry across every reserve V1 holds — on Base that is the live MAG7
    ///         tokenized-stocks market. Parity passes once V2 is seeded from the same spoke.
    function test_MigrationParity_V2CarriesEveryV1Reserve() public {
        AaveV4ReserveRegistry legacy = new AaveV4ReserveRegistry(address(this));
        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            legacy.registerReserve(spoke, id);
        }
        harness.seed(registry, spoke);

        uint256 carried = harness.assertMigrationParity(legacy, registry, spoke);
        assertEq(carried, MAG7_LISTED_RESERVES, "all 8 stock-market reserves carried to V2");
    }

    /// @notice Parity must FAIL LOUDLY when a reserve V1 holds is missing a leg in V2 — this is the check's
    ///         whole purpose, since the seeder enumerates from the spoke and not from V1
    function test_MigrationParity_RevertIf_V2MissingALeg() public {
        AaveV4ReserveRegistry legacy = new AaveV4ReserveRegistry(address(this));
        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            legacy.registerReserve(spoke, id);
        }
        _dropOneLeg(2, true); // seeds V2, then removes reserve 2's debt leg

        vm.expectRevert(bytes("MIGRATION_DEBT_LEG_MISSING"));
        harness.assertMigrationParity(legacy, registry, spoke);
    }

    /// @notice Parity refuses to pass vacuously: an empty V1 means the comparison proved nothing, so it
    ///         reverts rather than reporting success
    function test_MigrationParity_RevertIf_V1IsEmpty() public {
        AaveV4ReserveRegistry emptyLegacy = new AaveV4ReserveRegistry(address(this));
        harness.seed(registry, spoke);

        vm.expectRevert(bytes("MIGRATION_PARITY_FOUND_NOTHING_IN_V1"));
        harness.assertMigrationParity(emptyLegacy, registry, spoke);
    }

    /*//////////////////////////////////////////////////////////////
                MARKET SEEDING (SUP-21239)
    //////////////////////////////////////////////////////////////*/

    /// @notice THE ONE-SHOT CLAIM, on live Base state: seeding then market-seeding registers a market for
    ///         EVERY tokenized stock the MAG7 spoke lists, each against the USDC loan reserve — 7 markets
    ///         from 8 listed reserves — with every binding read from the live spoke.
    /// @dev Enumerated from the spoke rather than a hardcoded pair list, so an eighth equity listed by Aave
    ///         is picked up by a re-run instead of being silently skipped. That is what this asserts: the
    ///         candidate count equals "listed reserves minus the loan reserve", not a magic 7.
    function test_SeedMarkets_RegistersEveryStockAgainstUsdc() public {
        harness.seed(registry, spoke);
        uint256 loanId = harness.loanReserveId(uint64(block.chainid));
        assertEq(loanId, 7, "USDC is the curated loan reserve on Base");

        ConfigureAaveV4ReserveRegistry.MarketResult memory r =
            harness.seedMarkets(registry, uint64(block.chainid), spoke);

        assertEq(r.candidates, MAG7_LISTED_RESERVES - 1, "every listed reserve except the loan reserve");
        assertEq(r.registered, MAG7_LISTED_RESERVES - 1, "all registered on the first run");
        assertEq(r.skipped, 0, "nothing skipped on a fresh registry");

        // every stock resolves, bound to the live spoke's tokens, and claims its two NAV legs
        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            if (id == loanId) continue;
            address marketKey = registry.computeMarketKey(spoke, id, loanId);
            assertTrue(registry.isMarketRegistered(marketKey), "stock market registered");
            (address mSpoke, uint256 mSupply, uint256 mBorrow,, address loanToken) = registry.getMarketInfo(marketKey);
            assertEq(mSpoke, spoke, "spoke binding");
            assertEq(mSupply, id, "collateral reserve binding");
            assertEq(mBorrow, loanId, "loan reserve binding");
            assertEq(loanToken, USDC_BASE, "every stock borrows USDC");
            assertEq(registry.marketRefs(registry.computeReserveKey(spoke, id)), 1, "collateral leg claimed once");
        }

        // the shared USDC debt leg is claimed by all seven — the 7-to-1 shape that makes the guard matter
        assertEq(
            registry.marketRefs(registry.computeDebtKey(spoke, loanId)),
            MAG7_LISTED_RESERVES - 1,
            "one debt leg, seven claims"
        );
    }

    /// @notice A second run registers nothing and reverts nothing — `configureAll` is re-runnable after a
    ///         partial failure or a newly listed reserve.
    function test_SeedMarkets_SecondRunIsANoOp() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);

        ConfigureAaveV4ReserveRegistry.MarketResult memory second =
            harness.seedMarkets(registry, uint64(block.chainid), spoke);
        assertEq(second.candidates, MAG7_LISTED_RESERVES - 1, "same candidates");
        assertEq(second.registered, 0, "nothing written twice");
        assertEq(second.skipped, MAG7_LISTED_RESERVES - 1, "all skipped as already registered");
    }

    /// @notice Markets cannot be seeded before reserves: both NAV legs must exist first. This is why
    ///         `configureAll` orders reserves -> parity -> markets, and the ordering is load-bearing rather
    ///         than cosmetic.
    function test_SeedMarkets_RevertIf_ReservesNotSeededFirst() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_LEG_NOT_REGISTERED.selector);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
    }

    /// @notice An explicit non-default pair (stock against stock) registers through the same primitive, and
    ///         the reversed pair is a DIFFERENT market — the ordering rule, on live state.
    function test_RegisterOne_ExplicitPair_AndReversedIsDistinct() public {
        harness.seed(registry, spoke);

        assertTrue(harness.registerOne(registry, spoke, 0, 1), "stock/stock pair registers");
        assertTrue(harness.registerOne(registry, spoke, 1, 0), "the reversed pair is a separate market");
        assertFalse(harness.registerOne(registry, spoke, 0, 1), "re-registering the same pair is a no-op");

        assertTrue(
            registry.computeMarketKey(spoke, 0, 1) != registry.computeMarketKey(spoke, 1, 0), "ordering is significant"
        );
    }

    /// @notice The final gate of `configureAll` fails on a half-configured registry rather than reporting
    ///         success — reserves seeded but markets missing must not pass.
    function test_AssertFullyConfigured_RevertIf_MarketsMissing() public {
        harness.seed(registry, spoke);

        vm.expectRevert(bytes("VERIFY_MARKET_MISSING"));
        harness.assertFullyConfigured(registry, uint64(block.chainid), spoke);

        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        harness.assertFullyConfigured(registry, uint64(block.chainid), spoke); // now passes
    }

    /*//////////////////////////////////////////////////////////////
       F1 (PR #1025 review, P2): COLLATERAL_LEG_CLAIMED_TWICE
    //////////////////////////////////////////////////////////////*/

    /// @dev The exact revert string, so a test cannot pass against a differently-named guard.
    bytes internal constant CLAIMED_TWICE =
        bytes("COLLATERAL_LEG_CLAIMED_TWICE: reserve is the supply leg of two markets, idle identity is ambiguous");

    /// @notice THE FINDING. The idle MONEY_MARKET pair's ledger key is the MARKET key, resolved to the
    ///         market's collateral leg — so a reserve claimed as the supply leg of two markets gives one
    ///         Aave position two accepted ledger identities. The seeder must refuse the second claim.
    ///         Reserve 0 is already AAPLc/USDC's collateral after `seedMarkets`; pairing it against another
    ///         stock would claim it a second time.
    function test_RegisterOne_RevertIf_CollateralLegAlreadyClaimed() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        assertEq(registry.marketRefs(registry.computeReserveKey(spoke, 0)), 1, "claimed exactly once");

        vm.expectRevert(CLAIMED_TWICE);
        harness.registerOne(registry, spoke, 0, 1);
    }

    /// @notice The SHARED LOAN LEG stays legal. All seven Base equity markets borrow USDC, so the USDC DEBT
    ///         key's refcount is 7 by design — the guard constrains SUPPLY legs only, and a test that
    ///         confused the two would break the live configuration.
    function test_SeedMarkets_SharedLoanLegIsNotAViolation() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);

        uint256 loanId = harness.loanReserveId(uint64(block.chainid));
        assertEq(
            registry.marketRefs(registry.computeDebtKey(spoke, loanId)),
            MAG7_LISTED_RESERVES - 1,
            "every equity market claims the one USDC debt leg"
        );
        assertEq(harness.printIdleCanonicality(registry, spoke), 0, "and that is not an ambiguity");
    }

    /// @notice CHECKING an already-ambiguous registry fails too. The ambiguity is built the way it would
    ///         really happen — a manager registering on the registry directly, outside this script — and the
    ///         verification gate must reject it rather than inherit it.
    function test_AssertFullyConfigured_RevertIf_CollateralLegClaimedTwice() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        harness.assertFullyConfigured(registry, uint64(block.chainid), spoke); // canonical: passes

        harness.registerMarketRaw(registry, spoke, 0, 1); // out-of-band second claim on reserve 0
        assertEq(registry.marketRefs(registry.computeReserveKey(spoke, 0)), 2, "ambiguity now exists");

        vm.expectRevert(CLAIMED_TWICE);
        harness.assertFullyConfigured(registry, uint64(block.chainid), spoke);
    }

    /// @notice And an idempotent RE-RUN rejects it. Re-running is the normal way to use this script, so the
    ///         already-registered branch must assert the binding instead of skipping — which is precisely
    ///         the hole the review found: before the fix a rerun over an ambiguous registry reported
    ///         "all skipped as already registered" and exited 0.
    function test_SeedMarkets_RerunRejectsAnAmbiguityIntroducedOutOfBand() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        harness.registerMarketRaw(registry, spoke, 0, 1);

        vm.expectRevert(CLAIMED_TWICE);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
    }

    /// @notice The read-only audit reports the violation as a non-zero count, which is what makes
    ///         `runCheckAll` revert after printing the diagnostic rather than blessing the registry.
    function test_PrintIdleCanonicality_CountsTheOverClaimedReserve() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        assertEq(harness.printIdleCanonicality(registry, spoke), 0, "canonical to begin with");

        harness.registerMarketRaw(registry, spoke, 0, 1);
        assertEq(harness.printIdleCanonicality(registry, spoke), 1, "one reserve over-claimed");
    }

    /// @notice A reserve with NO market is not a violation: `<= 1`, not `== 1`. Freshly seeded reserves are
    ///         simply not idle-lendable yet, and failing on that would make the gate unreachable.
    function test_PrintIdleCanonicality_UnclaimedReserveIsFine() public {
        harness.seed(registry, spoke);
        assertEq(registry.marketRefs(registry.computeReserveKey(spoke, 0)), 0, "no market yet");
        assertEq(harness.printIdleCanonicality(registry, spoke), 0, "zero claims is not ambiguous");
    }

    /*//////////////////////////////////////////////////////////////
       SUP-21263: IDLE SETTLEMENT DESIGNATION
    //////////////////////////////////////////////////////////////*/

    /// @dev The designation error strings, so a test cannot pass against a differently-named guard.
    bytes internal constant UNDESIGNATED = bytes("IDLE_SETTLEMENT_UNDESIGNATED: reserve settles under many markets");

    /// @notice WHY THIS GUARD EXISTS. After SUP-21263 the idle hooks accept EITHER leg of the header market,
    ///         so the shared USDC loan reserve can settle an idle position under any of the seven equity
    ///         markets — seven SuperLedger identities for one physical position, and a cross-market redeem
    ///         strands the first accumulator. The supply legs are already unique (`marketRefs <= 1`); this
    ///         pins that the loan leg is the one with many candidates, which is what needs designating.
    function test_IdleSettlement_SharedLoanLegHasManyCandidates() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        uint256 loanId = harness.loanReserveId(uint64(block.chainid));

        assertEq(
            harness.idleSettlementCandidates(registry, spoke, loanId),
            MAG7_LISTED_RESERVES - 1,
            "every equity market is a candidate settlement key for the loan reserve"
        );
        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            if (id == loanId) continue;
            assertEq(
                harness.idleSettlementCandidates(registry, spoke, id),
                1,
                "an equity reserve belongs to exactly one market, so there is nothing to choose"
            );
        }
    }

    /// @notice The curated designation resolves to a REGISTERED market that really names the reserve, for
    ///         every listed reserve — including the shared loan leg.
    function test_IdleSettlement_DesignationIsRegisteredAndNamesTheReserve() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        uint64 chainId = uint64(block.chainid);

        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            address designated = harness.idleSettlementMarket(chainId, spoke, id, registry);
            assertTrue(designated != address(0), "every listed reserve has a designation on Base");
            assertTrue(registry.isMarketRegistered(designated), "and it is registered");
            (, uint256 supplyId, uint256 borrowId,,) = registry.getMarketInfo(designated);
            assertTrue(id == supplyId || id == borrowId, "and the reserve really is one of its legs");
            // and it is STABLE across calls - ops signs against this value
            assertEq(designated, harness.idleSettlementMarket(chainId, spoke, id, registry));
        }
    }

    /// @notice The gate passes on the real curated topology and reports no ambiguity.
    function test_IdleSettlement_CuratedBaseTopologyPasses() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        uint64 chainId = uint64(block.chainid);

        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            harness.assertIdleSettlementDesignated(registry, chainId, spoke, id);
        }
        assertEq(harness.printIdleSettlement(registry, chainId, spoke), 0, "no undesignated reserve");
        harness.assertFullyConfigured(registry, chainId, spoke);
    }

    /// @notice A reserve with NO market needs no designation — `<= 1` candidates means there is nothing to
    ///         choose between, so the gate must not fail a freshly seeded registry.
    function test_IdleSettlement_NoMarketsNeedsNoDesignation() public {
        harness.seed(registry, spoke);
        uint64 chainId = uint64(block.chainid);
        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            assertEq(harness.idleSettlementCandidates(registry, spoke, id), 0, "no markets yet");
            harness.assertIdleSettlementDesignated(registry, chainId, spoke, id);
        }
        assertEq(harness.printIdleSettlement(registry, chainId, spoke), 0);
    }

    /// @notice AMBIGUITY ON A CHAIN WITH NO DESIGNATION TABLE: the SEEDING gate warns and continues, while
    ///         the AUDIT reports a violation. That split is deliberate. Requiring a designation during
    ///         `configureAll` would be a trap on such a chain: this script registers no markets there
    ///         (`_seedMarkets` returns early), so the ambiguity can only have come from a manual
    ///         `registerMarket`, and reverting would permanently block the RESERVE seeding `configureAll` is
    ///         still needed for — with no table an operator could fill. The audit is the right gate because
    ///         failing it blocks nothing.
    /// @dev Simulated by asking about a non-Base chain id, where `_defaultLoanReserveId` returns the
    ///      sentinel. Exactly the state an operator is in on a spoke whose pairs are a strategy decision.
    function test_IdleSettlement_UncuratedChain_SeedingWarnsButAuditFails() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        uint256 loanId = harness.loanReserveId(uint64(block.chainid));
        assertGt(harness.idleSettlementCandidates(registry, spoke, loanId), 1, "many candidates exist");

        uint64 uncuratedChain = 42_161; // Arbitrum: no curated market set, hence no designation
        assertEq(harness.idleSettlementMarket(uncuratedChain, spoke, loanId, registry), address(0));

        // seeding is NOT blocked...
        harness.assertIdleSettlementDesignated(registry, uncuratedChain, spoke, loanId);
        // ...but the audit counts it, which is what makes `runCheckAll` revert
        assertGt(harness.printIdleSettlement(registry, uncuratedChain, spoke), 0, "the audit reports it");
    }

    /// @notice And the audit section is REACHABLE on an uncurated chain. An earlier version returned from
    ///         `_printMarketStatus` before `_printIdleSettlement` when the chain had no curated loan
    ///         reserve — so the one chain where the designation is not curated was also the one chain whose
    ///         audit never mentioned it. This pins that the count propagates.
    function test_IdleSettlement_AuditSectionIsReachableWithoutACuratedLoanReserve() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);

        uint64 uncuratedChain = 42_161;
        uint256 viaMarketStatus = harness.printMarketStatus(registry, uncuratedChain, spoke);
        assertGt(viaMarketStatus, 0, "the violation surfaces through the printer runCheckAll actually calls");
        assertEq(
            viaMarketStatus,
            harness.printIdleCanonicality(registry, spoke)
                + harness.printIdleSettlement(registry, uncuratedChain, spoke),
            "and it is the sum of both idle-identity checks"
        );
    }

    /// @notice A designation that exists but does NOT name the reserve is still rejected outright — the
    ///         warn-and-continue path above applies ONLY to "no table for this chain", never to a wrong one.
    function test_IdleSettlement_RevertIf_DesignationDoesNotNameTheReserve() public {
        harness.seed(registry, spoke);
        harness.seedMarkets(registry, uint64(block.chainid), spoke);
        uint64 chainId = uint64(block.chainid);
        uint256 loanId = harness.loanReserveId(chainId);

        // Drop the designated market (0, loanId) so the designation resolves to an UNREGISTERED key while
        // reserve 7 still has six other candidates.
        address designated = harness.idleSettlementMarket(chainId, spoke, loanId, registry);
        harness.proposeDropMarket(registry, designated);
        vm.warp(block.timestamp + 2 days + 1);
        harness.executeDropMarket(registry, designated);
        assertFalse(registry.isMarketRegistered(designated), "designation is now unregistered");

        vm.expectRevert(bytes("IDLE_SETTLEMENT_MARKET_NOT_REGISTERED"));
        harness.assertIdleSettlementDesignated(registry, chainId, spoke, loanId);
    }

    /// @notice Only Base has a curated market set. Other chains' pairs are a strategy decision, so
    ///         `_defaultLoanReserveId` returns the sentinel and market seeding is a documented no-op there
    ///         instead of inventing pairs.
    function test_DefaultLoanReserve_OnlyBaseHasACuratedSet() public view {
        assertEq(harness.loanReserveId(8453), 7, "Base MAG7 borrows USDC");
        assertEq(harness.loanReserveId(1), harness.noLoanReserve(), "Ethereum has no curated set");
        assertEq(harness.loanReserveId(42_161), harness.noLoanReserve(), "nor any other chain");
    }
}
