// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { MockAaveV4Spoke } from "./AaveV4Oracles.t.sol";

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

    address internal underlying = makeAddr("underlying");

    uint256 internal constant RESERVE_ID = 11;

    function setUp() public {
        registry = new AaveV4ReserveRegistryV2(address(this));
        spoke = new MockAaveV4Spoke();
        spoke.setReserve(RESERVE_ID, underlying, 8);
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
}
