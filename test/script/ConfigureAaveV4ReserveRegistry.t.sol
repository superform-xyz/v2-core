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

    /// @notice Only Base has a curated market set. Other chains' pairs are a strategy decision, so
    ///         `_defaultLoanReserveId` returns the sentinel and market seeding is a documented no-op there
    ///         instead of inventing pairs.
    function test_DefaultLoanReserve_OnlyBaseHasACuratedSet() public view {
        assertEq(harness.loanReserveId(8453), 7, "Base MAG7 borrows USDC");
        assertEq(harness.loanReserveId(1), harness.noLoanReserve(), "Ethereum has no curated set");
        assertEq(harness.loanReserveId(42_161), harness.noLoanReserve(), "nor any other chain");
    }
}
