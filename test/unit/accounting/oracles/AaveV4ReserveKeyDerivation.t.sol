// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import { MockAaveV4Spoke } from "./AaveV4Oracles.t.sol";
import { AaveV4ReserveKeyLibHarness } from "./AaveV4ReserveOracleDispatch.t.sol";

/// @title AaveV4ReserveKeyDerivationTest
/// @author Superform Labs
/// @notice Property/fuzz coverage of the TWO-KEY scheme `AaveV4ReserveRegistryV2` introduced when the supply
///         and debt oracles were merged into the single `AaveV4ReserveOracle`. One reserve now names two
///         pseudo-addresses — a SUPPLY key and a DEBT key — and the side bound into the key is the only thing
///         that tells the sideless `IYieldSourceOracle` surface which leg a read means.
/// @dev Two separate guarantees are pinned here, and they pull in opposite directions:
///
///      1. BACK-COMPAT (the supply key must NOT move). `computeReserveKey` is the key that 14 already-deployed
///         Aave V4 hooks pin in their headers, that the production registry is already seeded with, and that
///         every off-chain indexer re-derives. It is therefore asserted against the LITERAL legacy expression
///         `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))` written out in full, never
///         against `AaveV4ReserveKey` — pinning the library against itself would pass through any edit to the
///         library and the deployed hooks would silently disagree with the registry.
///
///      2. SEPARATION (the debt key must never be mistakable for a supply key). The debt preimage adds a third
///         word, `DEBT_KEY_DOMAIN`, so the two preimages differ in LENGTH (2 words vs 3) as well as content.
///         That removes any STRUCTURAL ambiguity between the derivations, but NOT collision itself: keccak256
///         is not injective across input lengths and both results truncate to 160 bits, so separation is
///         probabilistic (~2^-160 per reserve) exactly as `AaveV4ReserveRegistryV2` documents. The fuzz tests
///         below can therefore only demonstrate infeasibility, never impossibility — do not read them as
///         proving a structural guarantee. Everything downstream of the merge still rests on that
///         separation holding: a key has exactly one meaning, forever.
contract AaveV4ReserveKeyDerivationTest is Test {
    AaveV4ReserveRegistryV2 internal registry;
    MockAaveV4Spoke internal spoke;
    AaveV4ReserveKeyLibHarness internal lib;

    address internal underlying = makeAddr("underlying");

    uint256 internal constant RESERVE_ID = 11;

    function setUp() public {
        registry = new AaveV4ReserveRegistryV2(address(this));
        spoke = new MockAaveV4Spoke();
        spoke.setReserve(RESERVE_ID, underlying, 8);
        lib = new AaveV4ReserveKeyLibHarness();
    }

    /*//////////////////////////////////////////////////////////////
          A. SUPPLY KEY — THE UNCHANGED LEGACY DERIVATION (BACK-COMPAT)
    //////////////////////////////////////////////////////////////*/

    /// @notice The SUPPLY key is byte-for-byte the legacy two-word derivation. Pinned against the literal
    ///         expression rather than `AaveV4ReserveKey` so that any change to the library — which is linked
    ///         into 14 deployed hooks whose headers pin this exact key, and which every off-chain indexer
    ///         reproduces — fails here instead of silently desynchronising the registry from the hooks.
    function testFuzz_ComputeReserveKey_MatchesLegacyLiteralFormula(address spoke_, uint256 reserveId_) public view {
        assertEq(
            registry.computeReserveKey(spoke_, reserveId_),
            address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId_))))),
            "SUPPLY key must stay the lower 20 bytes of keccak256(abi.encode(spoke, reserveId))"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    B. DEBT KEY — DOMAIN-SEPARATED DERIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The domain separator is the literal namespaced string off-chain consumers must hash. Pinned
    ///         independently because the debt key is unreproducible without this exact value.
    function test_DebtKeyDomain_IsTheNamespacedConstant() public view {
        assertEq(
            registry.DEBT_KEY_DOMAIN(),
            keccak256("AaveV4ReserveRegistryV2.DEBT"),
            "DEBT_KEY_DOMAIN must be keccak256 of the namespaced literal"
        );
    }

    /// @notice The DEBT key is the lower 20 bytes of the THREE-word preimage
    ///         `keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))`. Pinned against the literal formula,
    ///         for the same reason as the supply key: off-chain consumers re-derive it from this expression.
    function testFuzz_ComputeDebtKey_MatchesLiteralFormulaWithDomain(address spoke_, uint256 reserveId_) public view {
        assertEq(
            registry.computeDebtKey(spoke_, reserveId_),
            address(
                uint160(uint256(keccak256(abi.encode(spoke_, reserveId_, keccak256("AaveV4ReserveRegistryV2.DEBT")))))
            ),
            "DEBT key must be the lower 20 bytes of keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  C. THE LEGS CAN NEVER SHARE A KEY
    //////////////////////////////////////////////////////////////*/

    /// @notice The two legs of ONE reserve are always keyed apart. This is the invariant the whole merged-oracle
    ///         design rests on: a single key would make `getBalanceOfOwner` ambiguous between a collateral
    ///         balance and a debt balance. The preimages differ in length (2 words vs 3), which removes
    ///         structural ambiguity; the remaining separation is probabilistic (see the contract docs), so a
    ///         passing fuzz run shows infeasibility rather than impossibility.
    function testFuzz_SupplyAndDebtKeys_AlwaysDistinct(address spoke_, uint256 reserveId_) public view {
        assertTrue(
            registry.computeReserveKey(spoke_, reserveId_) != registry.computeDebtKey(spoke_, reserveId_),
            "the SUPPLY and DEBT legs of one reserve must never share a key"
        );
    }

    /// @notice Cross-reserve separation: reserve A's DEBT key never equals reserve B's SUPPLY key on the same
    ///         spoke, for ANY pair of ids (the equal-id case is the sibling-leg invariant above). Were it to
    ///         hold for some pair, registering both reserves would make one leg unrepresentable and a debt read
    ///         would resolve to another reserve's collateral.
    function testFuzz_DebtKey_NeverEqualsAnyReservesSupplyKey(
        address spoke_,
        uint256 reserveIdA_,
        uint256 reserveIdB_
    )
        public
        view
    {
        assertTrue(
            registry.computeDebtKey(spoke_, reserveIdA_) != registry.computeReserveKey(spoke_, reserveIdB_),
            "a DEBT key must never collide with any reserve's SUPPLY key on the same spoke"
        );
    }

    /*//////////////////////////////////////////////////////////////
        D. BOTH DERIVATIONS ARE DETERMINISTIC AND USE BOTH INPUTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Both derivations are pure functions of their inputs: repeated calls return the same key. A
    ///         non-deterministic key would make the registry's "a key can only ever bind to the pair that
    ///         hashes to it" guarantee — and re-registration after deregistration — meaningless.
    function testFuzz_Keys_AreDeterministic(address spoke_, uint256 reserveId_) public view {
        assertEq(
            registry.computeReserveKey(spoke_, reserveId_),
            registry.computeReserveKey(spoke_, reserveId_),
            "SUPPLY key derivation must be deterministic"
        );
        assertEq(
            registry.computeDebtKey(spoke_, reserveId_),
            registry.computeDebtKey(spoke_, reserveId_),
            "DEBT key derivation must be deterministic"
        );
    }

    /// @notice Both derivations depend on the reserveId: two reserves on ONE spoke get four distinct keys. If
    ///         the id were dropped from either preimage, every reserve on a spoke would share a key.
    function testFuzz_Keys_DependOnReserveId(address spoke_, uint256 reserveIdA_, uint256 reserveIdB_) public view {
        vm.assume(reserveIdA_ != reserveIdB_);

        assertTrue(
            registry.computeReserveKey(spoke_, reserveIdA_) != registry.computeReserveKey(spoke_, reserveIdB_),
            "distinct reserveIds must yield distinct SUPPLY keys"
        );
        assertTrue(
            registry.computeDebtKey(spoke_, reserveIdA_) != registry.computeDebtKey(spoke_, reserveIdB_),
            "distinct reserveIds must yield distinct DEBT keys"
        );
    }

    /// @notice Both derivations depend on the spoke: the same reserveId on two spokes gets four distinct keys.
    ///         Aave V4 allows multiple spokes per chain and reserve ids restart per spoke, so dropping the
    ///         spoke from either preimage would alias unrelated reserves onto one key.
    function testFuzz_Keys_DependOnSpoke(address spokeA_, address spokeB_, uint256 reserveId_) public view {
        vm.assume(spokeA_ != spokeB_);

        assertTrue(
            registry.computeReserveKey(spokeA_, reserveId_) != registry.computeReserveKey(spokeB_, reserveId_),
            "distinct spokes must yield distinct SUPPLY keys"
        );
        assertTrue(
            registry.computeDebtKey(spokeA_, reserveId_) != registry.computeDebtKey(spokeB_, reserveId_),
            "distinct spokes must yield distinct DEBT keys"
        );
    }

    /*//////////////////////////////////////////////////////////////
          E. REGISTRATION WRITES EXACTLY THE TWO DERIVED KEYS
    //////////////////////////////////////////////////////////////*/

    /// @notice `registerReserve` returns, and marks registered, EXACTLY the two derived keys — no third
    ///         pseudo-address becomes resolvable as a side effect. The fuzzed third address stands for every
    ///         key the registry must keep rejecting, so the oracle can never resolve an unregistered key to a
    ///         live reserve binding.
    function testFuzz_RegisterReserve_StoresExactlyTheTwoDerivedKeys(address other_) public {
        (address supplyKey, address debtKey) = registry.registerReserve(address(spoke), RESERVE_ID);

        assertEq(supplyKey, registry.computeReserveKey(address(spoke), RESERVE_ID), "returned SUPPLY key derivation");
        assertEq(debtKey, registry.computeDebtKey(address(spoke), RESERVE_ID), "returned DEBT key derivation");

        assertTrue(registry.isRegistered(supplyKey), "SUPPLY leg registered by the single call");
        assertTrue(registry.isRegistered(debtKey), "DEBT leg registered by the same call");

        vm.assume(other_ != supplyKey && other_ != debtKey);
        assertFalse(registry.isRegistered(other_), "no key other than the two derived ones may be registered");
    }

    /// @notice The two keys written by registration carry the two SIDES — the per-key discriminator the merged
    ///         oracle branches on — while sharing one reserve binding. Keyed apart, bound identically: that
    ///         pairing is what makes a single oracle able to serve both legs through a sideless interface.
    function test_RegisterReserve_TheTwoKeysCarryTheTwoSides() public {
        (address supplyKey, address debtKey) = registry.registerReserve(address(spoke), RESERVE_ID);

        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(supplyKey);
        (address dSpoke, uint256 dId, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(debtKey);

        assertEq(dSpoke, sSpoke, "one spoke across both legs");
        assertEq(dId, sId, "one reserveId across both legs");
        assertEq(dUnderlying, sUnderlying, "one underlying across both legs");
        assertEq(dDecimals, sDecimals, "one decimals value across both legs");
        assertTrue(sSide == AaveV4ReserveRegistryV2.Side.SUPPLY, "the legacy key is the SUPPLY leg");
        assertTrue(dSide == AaveV4ReserveRegistryV2.Side.DEBT, "the domain-separated key is the DEBT leg");
    }

    /*//////////////////////////////////////////////////////////////
       F. MARKET KEY — THE INTENT NAMESPACE (SUP-21239)
    //////////////////////////////////////////////////////////////*/

    /// @notice The market domain separator is the literal namespaced string off-chain consumers must hash.
    ///         Pinned independently because no market key is reproducible without this exact value, and it is
    ///         FROZEN the moment a market key is signed into a merkle root.
    /// @dev Deliberately named after the LIBRARY, not after a registry version, unlike its `DEBT_KEY_DOMAIN`
    ///      sibling — see the library docs. A reviewer "aligning" the two literals must fail here.
    function test_MarketKeyDomain_IsTheNamespacedConstant() public view {
        assertEq(
            lib.marketDomain(),
            keccak256("AaveV4ReserveKey.MARKET"),
            "MARKET_KEY_DOMAIN must be keccak256 of the namespaced literal"
        );
    }

    /// @notice THE FROZEN FORMULA. The market key is the lower 20 bytes of the FOUR-word preimage
    ///         `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))`. Asserted
    ///         against the literal expression written out in full — never against `AaveV4ReserveKey` — because
    ///         Erebor merkle leaves, the vault whitelist, snapshotd and the Superman UI all re-derive it from
    ///         this expression. Pinning the library against itself would pass through any edit and silently
    ///         desynchronise every signed intent from the V2 LOAN hooks that enforce it.
    function testFuzz_ComputeMarketKey_MatchesLiteralFormula(
        address spoke_,
        uint256 supplyId_,
        uint256 borrowId_
    )
        public
        view
    {
        assertEq(
            lib.marketKey(spoke_, supplyId_, borrowId_),
            address(
                uint160(
                    uint256(keccak256(abi.encode(spoke_, supplyId_, borrowId_, keccak256("AaveV4ReserveKey.MARKET"))))
                )
            ),
            "MARKET key must be the lower 20 bytes of keccak256(abi.encode(spoke, supplyId, borrowId, MARKET_KEY_DOMAIN))"
        );
    }

    /// @notice ORDER IS SIGNIFICANT. The legs are asymmetric: "equity collateral, borrow USDC" and "USDC
    ///         collateral, borrow equity" are different strategies with different risk, so the derivation must
    ///         NOT sort its ids. A sorted preimage would collapse the two into one key and let a signed intent
    ///         for one execute as the other.
    function testFuzz_MarketKey_OrderingIsSignificant(address spoke_, uint256 idA_, uint256 idB_) public view {
        vm.assume(idA_ != idB_);

        assertTrue(
            lib.marketKey(spoke_, idA_, idB_) != lib.marketKey(spoke_, idB_, idA_),
            "swapping the supply and borrow legs must yield a different market key"
        );
    }

    /// @notice Namespace separation: a market key never equals either of its own legs' NAV keys. That is what
    ///         keeps the two derivations of `AaveV4ReserveKey` disjoint — a market key is never ITSELF a
    ///         registered reserve leg. (Since SUP-21255 the oracle does resolve a market key to its
    ///         collateral leg; it looks the market up and reads that leg's key, which is why the keys staying
    ///         distinct is what makes the projection unambiguous.)
    ///         Separation is probabilistic (~2^-160), as the library documents: a passing fuzz run shows
    ///         infeasibility, not impossibility.
    function testFuzz_MarketKey_NeverEqualsEitherLegsNavKey(
        address spoke_,
        uint256 supplyId_,
        uint256 borrowId_
    )
        public
        view
    {
        address market = lib.marketKey(spoke_, supplyId_, borrowId_);

        assertTrue(market != registry.computeReserveKey(spoke_, supplyId_), "market key vs collateral SUPPLY key");
        assertTrue(market != registry.computeDebtKey(spoke_, supplyId_), "market key vs collateral DEBT key");
        assertTrue(market != registry.computeReserveKey(spoke_, borrowId_), "market key vs loan SUPPLY key");
        assertTrue(market != registry.computeDebtKey(spoke_, borrowId_), "market key vs loan DEBT key");
    }

    /// @notice The market key depends on the spoke: the same reserve pair on two spokes gets two keys. Aave V4
    ///         allows multiple spokes per chain and reserve ids restart per spoke, so dropping the spoke would
    ///         alias unrelated markets onto one key.
    function testFuzz_MarketKey_DependsOnSpoke(
        address spokeA_,
        address spokeB_,
        uint256 supplyId_,
        uint256 borrowId_
    )
        public
        view
    {
        vm.assume(spokeA_ != spokeB_);

        assertTrue(
            lib.marketKey(spokeA_, supplyId_, borrowId_) != lib.marketKey(spokeB_, supplyId_, borrowId_),
            "distinct spokes must yield distinct market keys"
        );
    }

    /// @notice The market key depends on BOTH ids independently: changing either leg changes the key. If either
    ///         were dropped from the preimage, every market sharing the surviving leg would collide — on the
    ///         live MAG7 spoke, where seven equity reserves all borrow the one USDC reserve, that is every
    ///         market on the spoke.
    function testFuzz_MarketKey_DependsOnBothLegs(
        address spoke_,
        uint256 supplyId_,
        uint256 borrowId_,
        uint256 otherId_
    )
        public
        view
    {
        vm.assume(otherId_ != supplyId_ && otherId_ != borrowId_);

        address market = lib.marketKey(spoke_, supplyId_, borrowId_);

        assertTrue(market != lib.marketKey(spoke_, otherId_, borrowId_), "changing the supply leg must move the key");
        assertTrue(market != lib.marketKey(spoke_, supplyId_, otherId_), "changing the borrow leg must move the key");
    }

    /// @notice The header pin accepts exactly the derived key and rejects everything else. This is the
    ///         on-chain guarantee the V2 LOAN hooks buy: a crafted header cannot name a different market — nor
    ///         either leg's reserve key — than the body acts on.
    function testFuzz_RequireHeaderIsMarketKey_AcceptsTheDerivedKeyAndRejectsOthers(
        address spoke_,
        uint256 supplyId_,
        uint256 borrowId_,
        address wrongKey_
    )
        public
    {
        address market = lib.marketKey(spoke_, supplyId_, borrowId_);

        // the derived key passes
        lib.requireHeaderIsMarketKey(market, spoke_, supplyId_, borrowId_);

        vm.assume(wrongKey_ != market);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lib.requireHeaderIsMarketKey(wrongKey_, spoke_, supplyId_, borrowId_);
    }

    /// @notice The reserve-key pin and the market-key pin are not interchangeable: a reserve key presented to
    ///         the market pin is rejected. A V2 hook deployed at its NEW address therefore fails closed against
    ///         an old reserve-key header instead of silently accepting it — the migration property that makes
    ///         "no flag day" safe.
    function test_RequireHeaderIsMarketKey_RejectsEitherLegsReserveKey() public {
        uint256 supplyId = 5;
        uint256 borrowId = 7;

        // Derive BEFORE arming the cheatcode: an external call inside the argument list would be the call
        // `vm.expectRevert` observes.
        address collateralSupplyKey = registry.computeReserveKey(address(spoke), supplyId);
        address loanSupplyKey = registry.computeReserveKey(address(spoke), borrowId);
        address loanDebtKey = registry.computeDebtKey(address(spoke), borrowId);

        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lib.requireHeaderIsMarketKey(collateralSupplyKey, address(spoke), supplyId, borrowId);

        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lib.requireHeaderIsMarketKey(loanSupplyKey, address(spoke), supplyId, borrowId);

        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lib.requireHeaderIsMarketKey(loanDebtKey, address(spoke), supplyId, borrowId);
    }
}
