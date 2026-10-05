// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";
import { AaveV4ReserveKey } from "../../libraries/AaveV4ReserveKey.sol";

/// @title AaveV4ReserveRegistryV2
/// @author Superform Labs
/// @dev VERSION 2. `AaveV4ReserveRegistry` (V1) remains in this repo, unmodified, because it is deployed
///      and seeded on production networks and must stay reproducible and source-verifiable at its live
///      address. V2 is a NEW contract under a NEW deploy name — not an edit to V1 — because the struct
///      gained a `side` field and `getReserveInfo` went from a 4- to a 5-tuple. Editing V1 in place would
///      have changed its creation code and therefore its CREATE2 address, and the deploy framework would
///      have silently deployed a second, empty registry under the same name while overwriting the output
///      record that points at the seeded one. A distinct name gives a distinct salt, a distinct artifact
///      and a distinct output key, so both can coexist for the migration window.
///      V1 serves the two legacy oracles (`AaveV4DebtOracle` / `AaveV4SupplyYieldSourceOracle`, which
///      disambiguated the leg by ORACLE ADDRESS); V2 serves the merged `AaveV4ReserveOracle`, which
///      disambiguates by the side bound into the key.
/// @notice Permissioned registry holding TWO disjoint namespaces. (1) ACCOUNTING / NAV: pseudo-addresses —
///         TWO per Aave V4 (spoke, reserveId) reserve, one per leg — mapped to reserve bindings.
///         (2) INTENT (SUP-21239): one pseudo-address per (spoke, supplyReserveId, borrowReserveId) market
///         pair, mapped to that market's collateral/loan binding, for the V2 LOAN hooks' header identity.
///         Only namespace (1) is oracle-resolvable; see MARKET KEYS below. Enables `AaveV4ReserveOracle` to be a
///         single singleton serving BOTH the supply and debt legs of any registered Aave V4
///         reserve without per-reserve wrapper deployments. Aave V4 spokes mint no aToken or
///         debtToken (positions are spoke-internal shares), so no protocol-provided
///         address-shaped handle exists — this registry supplies one.
/// @dev WHY THE SIDE LIVES IN THE KEY: `IYieldSourceOracle`'s reads take `(yieldSourceAddress, owner)`
///      with no side parameter, and the aggregator `SuperYieldSourceOracle` calls them polymorphically
///      (`getTVLByOwnerOfShares(yieldSourceAddresses[i], ownersOfShares[i])` on
///      `yieldSourceOracles[i]`). Two separate oracle contracts previously disambiguated the leg by
///      ORACLE ADDRESS. Collapsing them into one address removes that discriminator, so the side has to
///      move into the key — otherwise a single `getBalanceOfOwner` could not tell a supply query from a
///      debt query. Registering one key per leg restores a single unambiguous meaning per key.
/// @dev Reserve key derivation — TWO keys per reserve, each the lower 20 bytes of a keccak256 hash:
///      SUPPLY is `keccak256(abi.encode(spoke, reserveId))` (the unchanged legacy two-word preimage,
///      defined in `AaveV4ReserveKey` and shared with every hook header and off-chain indexer), and
///      DEBT is `keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))`. The `Side` is NOT a
///      preimage element — the debt leg is separated by a domain constant and the side is recorded in
///      `ReserveInfo.side`. Both keys are DERIVED, never operator-chosen: a key can only ever bind to
///      the inputs that hash to it, so re-registration after deregistration cannot rebind a key to a
///      different reserve. Accidental collision probability is negligible: by the birthday bound, the
///      chance of any collision among 2^21 keys (two per reserve, 2^20 reserves) in a 2^160 key space
///      is ~2^-119. Deliberately grinding a colliding pair costs ~2^80 work and targeting a
///      specific existing key ~2^160 — both infeasible. Either way a collision merely prevents
///      registration of the second reserve — it cannot overwrite an existing reserve's data.
///
///      Spoke address trust: `spoke_` is trusted by the MARKET_MANAGER_ROLE operator; it must
///      be a canonical Aave V4 spoke (TransparentUpgradeableProxy governed by Aave) for this
///      chain. No on-chain whitelist is enforced because the permissioned role is sufficient to
///      gate registration — the same trust shape as MorphoBlueMarketRegistry's caller-trusted
///      singleton. There is no IRM-approval analog: Aave V4 interest accrual is internal to the
///      governance-controlled hub, so nothing external executes during oracle reads.
///
///      Multi-spoke note: Aave V4 supports multiple spokes per chain, and the same economic
///      asset may be listed as a reserve on more than one spoke. Registering both creates two
///      distinct keys, splitting a user's real exposure across two yieldSource entries with no
///      on-chain detection. ACCEPTED OPERATIONAL RISK — the ops runbook rule is one key per
///      economic reserve per chain unless intentionally tracking distinct spoke positions.
///
///      SAFETY INVARIANT — deregistration:
///      Deregistration is PER KEY, while registration is per reserve (both legs at once). Deregistering
///      one leg leaves the other resolvable — intentional, so the debt leg can be withdrawn from exposure
///      without disturbing supply NAV reads, but it means the ops runbook must state which leg it is
///      removing. A deregistered key makes the oracle revert for that key. If any Superform-managed
///      position still references the reserve (SuperLedger, SuperVault, monitoring),
///      deregistration bricks PPS/TVL reads and fee-charging outflow accounting — users cannot
///      withdraw through SuperLedger without the oracle returning a valid PPS.
///      **Do NOT deregister a reserve with active Superform accounting positions.** The reserve
///      must first be fully migrated or deprecated (all positions withdrawn / oracle
///      unregistered from SuperLedgerConfiguration) before deregistration is executed.
///
///      MARKET KEYS (SUP-21239) — the SECOND namespace this contract holds:
///      `_markets` maps a market key — `computeMarketKey(spoke, supplyReserveId, borrowReserveId)`, a
///      four-word domain-separated preimage — to the collateral/loan binding of ONE Aave V4 market pair.
///      The two namespaces have DISJOINT consumers and must never be mixed:
///        * reserve keys (`_reserves`) are ACCOUNTING / NAV identity: `AaveV4ReserveOracle` resolves them,
///          and the idle INFLOW / OUTFLOW pair posts SuperLedger accounting under them.
///        * market keys (`_markets`) are INTENT identity: the header `yieldSource` of the V2 LOAN hooks,
///          hence merkle leaves, vault whitelists and off-chain indexing. `AaveV4ReserveOracle` resolves a
///          market key ONE-DIRECTIONALLY (SUP-21255): through `getMarketInfo` to the market's COLLATERAL
///          leg, so its sideless reads keep returning one number in one asset. The DEBT leg is never
///          reachable from a market key — one reserve is borrowed by N markets, so market-keyed debt would
///          be counted once per market — and the legs are never netted. `getMarketPosition` returns both
///          raw legs, and `getOwnerSnapshot` de-duplicates legs across a requested set; both are pinned by
///          test.
///      Separate mappings, plus the defensive `KEY_NAMESPACE_COLLISION` guard on all THREE registration paths
///      (`registerReserve` checks both leg keys, `repairLeg` checks the repaired key, `registerMarket` checks
///      the market key), are what keep one 20-byte value from meaning a reserve leg here and a market there.
///      Those three branches are unreachable without a ~2^-160 collision, so they are exercised only by tests
///      that write the mappings directly (`vm.store`); do not read their absence from a coverage report as
///      dead code.
///
///      MARKET REGISTRATION DOES NOT GATE EXECUTION. The V2 LOAN hooks are NONACCOUNTING: the executor never
///      reads their header, and the hooks never call this registry. They pin only that the header equals the
///      market key of the body they act on. Registering a market records its binding for off-chain consumers;
///      which markets a vault may touch stays an Erebor/whitelist decision.
///
///      WHY A MARKET IS A CURATION DECISION: Aave V4 has no market object. `getUserSuppliedAssets(reserveId,
///      owner)` and `getUserDebt(reserveId, owner)` take no market parameter, so a supply position on one
///      reserve collateralises EVERY borrow the owner holds on that spoke — one reserve participates in N
///      markets. Markets therefore cannot be enumerated from the protocol (no `assertMigrationParity`
///      analogue, no auto-seeding), and NAV must stay per reserve leg: market-keyed NAV would return the same
///      supplied amount once per market and `SuperYieldSourceOracle`'s batch reads sum without de-duplication.
///      A strategy with two collateral reserves against one debt reserve is TWO markets — which is how the
///      hooks model it: one pair per call.
///
///      SAFETY INVARIANT — market lifecycle:
///      `registerMarket` requires BOTH NAV legs (the collateral reserve's SUPPLY key and the loan reserve's
///      DEBT key) to be registered first, and counts itself in `marketRefs` against each. A reserve leg a
///      market still names cannot be deregistered — `MARKET_REFERENCES_RESERVE`, checked at both propose and
///      execute. NOTE WHICH legs: a market claims exactly TWO of its two reserves' four legs — the collateral
///      reserve's SUPPLY leg and the loan reserve's DEBT leg. The collateral reserve's DEBT leg and the loan
///      reserve's SUPPLY leg stay freely deregisterable, by design, because this market never reads them.
///      Order of operations for removal: deregister the markets, then the reserve legs.
///      A pending reserve-leg deregistration also BLOCKS `registerMarket` over that leg
///      (`RESERVE_DEREGISTRATION_PENDING`): without it a proposal armed before the market existed would sit
///      un-executable behind `marketRefs` and then fire with no fresh warning window the moment the market
///      was removed, which is the opposite of what the timelock is for.
contract AaveV4ReserveRegistryV2 is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when querying a reserve key that has not been registered
    error RESERVE_NOT_REGISTERED();

    /// @notice Thrown when registering a reserve key that is already registered
    error RESERVE_ALREADY_REGISTERED();

    /// @notice Thrown when the spoke reports a zero underlying for the reserve
    error INVALID_RESERVE();

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /// @notice Thrown when attempting to execute or cancel a deregistration that was never proposed
    error DEREGISTRATION_NOT_PENDING();

    /// @notice Thrown when executing a deregistration before its timelock has elapsed
    error DEREGISTRATION_TIMELOCK_NOT_ELAPSED();

    /// @notice Thrown when querying a market key that has not been registered
    error MARKET_NOT_REGISTERED();

    /// @notice Thrown when registering a market key that is already registered
    error MARKET_ALREADY_REGISTERED();

    /// @notice Thrown when registering a market whose two legs are the same reserve
    error IDENTICAL_RESERVES();

    /// @notice Thrown when a market's collateral and loan underlyings are the same token
    /// @dev Registry/hook parity on the STATIC checks only: every V2 LOAN hook refuses
    ///      `loanToken == collateralToken` (`BaseAaveV4LoanHookV2.IDENTICAL_TOKENS`), so a market this
    ///      registry accepts satisfies the hooks' format checks. It does NOT follow that the market is
    ///      executable: the hooks still refuse at runtime on `RESERVE_HAS_IDLE_POSITION` /
    ///      `RESERVE_NOT_COLLATERAL`, and Aave itself on LTV, caps and freeze state.
    error IDENTICAL_UNDERLYINGS();

    /// @notice Thrown when registering a market before both of its NAV legs are registered
    error MARKET_LEG_NOT_REGISTERED();

    /// @notice Thrown when a key is already registered in the other namespace
    /// @dev Defensive only: reaching this requires a ~2^-160 cross-namespace collision. It exists so such a
    ///      collision can never make one 20-byte key mean a reserve leg to the oracle and a market to an
    ///      off-chain whitelist.
    error KEY_NAMESPACE_COLLISION();

    /// @notice Thrown when deregistering a reserve leg that a registered market still depends on
    error MARKET_REFERENCES_RESERVE();

    /// @notice Thrown when registering a market over a reserve leg whose deregistration is already pending
    /// @dev Keeps the two timelocks non-overlapping. Without it: propose a leg's deregistration while no
    ///      market names it, register the market during the window, and the execute then reverts
    ///      `MARKET_REFERENCES_RESERVE` WITHOUT clearing the proposal — which would stay armed and fire
    ///      immediately, days later, the moment the market was deregistered. Cancel the proposal first.
    error RESERVE_DEREGISTRATION_PENDING();

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to register reserves and markets, and to propose/execute/cancel either kind of
    ///         deregistration
    bytes32 public constant MARKET_MANAGER_ROLE = keccak256("MARKET_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum delay between proposing and executing a deregistration — shared by BOTH the reserve-leg
    ///         and the market lifecycle
    uint256 public constant DEREGISTER_DELAY = 2 days;

    /// @notice Domain separator mixed into the DEBT key preimage
    /// @dev Off-chain consumers reproduce the debt key as
    ///      `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN)))))` — three
    ///      fixed 32-byte words. The SUPPLY key deliberately keeps the two-word legacy preimage
    ///      `keccak256(abi.encode(spoke, reserveId))` defined in `AaveV4ReserveKey`, so every existing
    ///      consumer (hook headers, indexers, the already-seeded prod registry) stays correct and only the
    ///      debt leg gains a new key. The differing preimage lengths remove any STRUCTURAL ambiguity between
    ///      the two derivations, but they do not make collision impossible: keccak256 is not injective across
    ///      input lengths and both results are truncated to 160 bits. Residual resistance is probabilistic and
    ///      rests on the same 160-bit second-preimage argument as `computeReserveKey` — a same-reserve
    ///      supply/debt collision is ~2^-160, and any supply-vs-debt collision across N registered reserves is
    ///      ~N^2/2^160 (~2^-120 at N = 2^20). NOTE the one asymmetry: unlike a cross-reserve collision, which
    ///      `registerReserve`'s guard rejects, a same-reserve supply/debt self-collision would pass both
    ///      `registered` checks and the DEBT write would then overwrite the SUPPLY write. Accepted as
    ///      computationally unreachable. Do NOT simplify the two-key guard in `registerReserve` on the
    ///      assumption that collisions cannot happen — that guard is what makes cross-reserve collisions
    ///      non-corrupting.
    bytes32 public constant DEBT_KEY_DOMAIN = AaveV4ReserveKey.DEBT_KEY_DOMAIN;

    /// @notice Domain separator mixed into the MARKET key preimage
    /// @dev Off-chain consumers reproduce a market key from a FOUR-word preimage:
    ///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))`,
    ///      truncated to its lower 20 bytes exactly as the two leg derivations are.
    ///      Four words makes the preimage structurally distinct from the two-word SUPPLY
    ///      and the three-word DEBT preimage. Differing lengths are NOT a collision proof:
    ///      keccak256 is not injective across lengths and all three truncate to 160 bits.
    ///      The domain constant is what makes the separation intentional and auditable, and
    ///      `KEY_NAMESPACE_COLLISION` is what makes a collision non-corrupting.
    ///      Re-exported from `AaveV4ReserveKey` so there is one definition; pinned equal by test.
    bytes32 public constant MARKET_KEY_DOMAIN = AaveV4ReserveKey.MARKET_KEY_DOMAIN;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Which leg of a reserve a key denotes
    /// @dev SUPPLY is the collateral/deposit leg (NAV-positive, `getUserSuppliedAssets`); DEBT is the borrow
    ///      leg (`getUserDebt`, drawn + premium). The side is bound into the key at registration and returned
    ///      by `getReserveInfo`, which is what lets a single oracle serve both legs through the sideless
    ///      `IYieldSourceOracle` surface — the per-key side IS the discriminator.
    enum Side {
        SUPPLY,
        DEBT
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @param spoke The Aave V4 spoke holding the reserve
    /// @param reserveId The reserve identifier within the spoke
    /// @param underlying The reserve's underlying asset, bound at registration
    /// @param decimals The underlying asset's decimals, bound at registration
    /// @param side Which leg this key denotes — SUPPLY or DEBT
    /// @param registered True once registered (spoke may legitimately be a nonzero sentinel)
    struct ReserveInfo {
        address spoke;
        uint256 reserveId;
        address underlying;
        uint8 decimals;
        Side side;
        bool registered;
    }

    /// @notice An Aave V4 market pair: one collateral (supply) reserve against one loan (borrow) reserve
    /// @dev Aave V4 has no market object on-chain — positions are reserve-granular — so a market is a
    ///      Superform curation decision recorded here, never something enumerable from the protocol.
    ///      Both underlyings are read from the spoke at registration, never operator-supplied, so the binding
    ///      rule matches the hooks' per-call `_validateReserves`.
    /// @param spoke The Aave V4 spoke holding both reserves
    /// @param supplyReserveId The collateral (supply) reserve identifier within the spoke
    /// @param borrowReserveId The loan (borrow) reserve identifier within the spoke
    /// @param collateralToken The supply reserve's underlying, bound at registration
    /// @param loanToken The borrow reserve's underlying, bound at registration
    /// @param registered True once registered
    struct MarketInfo {
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        address collateralToken;
        address loanToken;
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted once per registered key — twice per `registerReserve` call, one per side
    /// @dev `side` is non-indexed: the three indexed slots are already taken by reserveKey/spoke/reserveId,
    ///      and consumers filter by key anyway.
    event ReserveRegistered(
        address indexed reserveKey, address indexed spoke, uint256 indexed reserveId, address underlying, Side side
    );

    /// @notice Emitted when a pending deregistration is executed and the reserve is removed
    event ReserveDeregistered(address indexed reserveKey);

    /// @notice Emitted when a deregistration is proposed, starting the 2-day timelock
    event ReserveDeregistrationProposed(address indexed reserveKey, uint256 executeAfter);

    /// @notice Emitted when a pending deregistration is cancelled before execution
    event ReserveDeregistrationCancelled(address indexed reserveKey);

    /// @notice Emitted once per registered market
    /// @dev `borrowReserveId` is non-indexed: the three indexed slots are taken by marketKey/spoke/
    ///      supplyReserveId, and consumers filter by key. Indexers enumerate markets from this event —
    ///      nothing on-chain lists them.
    event MarketRegistered(
        address indexed marketKey,
        address indexed spoke,
        uint256 indexed supplyReserveId,
        uint256 borrowReserveId,
        address collateralToken,
        address loanToken
    );

    /// @notice Emitted when a pending market deregistration is executed and the market is removed
    event MarketDeregistered(address indexed marketKey);

    /// @notice Emitted when a market deregistration is proposed, starting the 2-day timelock
    event MarketDeregistrationProposed(address indexed marketKey, uint256 executeAfter);

    /// @notice Emitted when a pending market deregistration is cancelled before execution
    event MarketDeregistrationCancelled(address indexed marketKey);

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Registered reserves indexed by their pseudo-address reserve key
    mapping(address reserveKey => ReserveInfo) private _reserves;

    /// @notice Pending deregistrations: reserveKey => timestamp after which execution is allowed
    /// @dev Zero means no pending deregistration for that key
    mapping(address reserveKey => uint256 executeAfter) public pendingDeregistrations;

    /// @notice Registered markets indexed by their pseudo-address market key
    /// @dev A SEPARATE mapping from `_reserves` on purpose: a key means a market here or a reserve leg
    ///      there, never both (`KEY_NAMESPACE_COLLISION` guards all three write paths). The oracle crosses
    ///      the two namespaces in ONE direction only (SUP-21255): it resolves a market key to that market's
    ///      COLLATERAL leg for its sideless reads, and the DEBT leg is never reachable that way, because one
    ///      reserve is borrowed by N markets and market-keyed debt would be counted once per market.
    mapping(address marketKey => MarketInfo) private _markets;

    /// @notice Pending market deregistrations: marketKey => timestamp after which execution is allowed
    /// @dev Zero means no pending deregistration for that key
    mapping(address marketKey => uint256 executeAfter) public pendingMarketDeregistrations;

    /// @notice How many registered markets depend on a given reserve leg key
    /// @dev Incremented for both claimed legs by `registerMarket`, decremented by `executeDeregisterMarket`.
    ///      Guards the one genuinely new lifecycle hazard this namespace introduces: deregistering a reserve
    ///      leg a market still names takes that market's NAV leg dark. Blast radius, stated precisely:
    ///      `AbstractYieldSourceOracle.getTVLByOwnerOfSharesMultiple` DOES isolate per entry (try/catch), so a
    ///      per-owner NAV read degrades to zero for that entry rather than aborting; but
    ///      `getPricePerShareMultiple` and `getTVLMultiple` loop WITHOUT isolation, so for those one
    ///      unresolvable key aborts the whole batch.
    mapping(address reserveKey => uint256 marketCount) public marketRefs;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the registry and grant all roles to `admin_`
    /// @dev Deployment grants both roles to `admin_` (the deployer) for bootstrap only. Handing
    ///      MARKET_MANAGER_ROLE to the governor and DEFAULT_ADMIN_ROLE to the SuperGovernor —
    ///      then revoking both from the deployer — is a BLOCKING production-activation task; run
    ///      script/TransferAaveV4ReserveRegistryRoles.s.sol (idempotent, with runCheck). The
    ///      manager must be a governed entity, never a hot EOA (see the 2026-09-02 security
    ///      report).
    /// @param admin_ Address granted DEFAULT_ADMIN_ROLE and MARKET_MANAGER_ROLE; must be non-zero
    constructor(address admin_) {
        if (admin_ == address(0)) revert ZERO_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MARKET_MANAGER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register an Aave V4 reserve by its (spoke, reserveId) pair — writes BOTH legs
    /// @dev Validates the reserve exists on the spoke via `getReserve`, which reverts for
    ///      codeless spoke addresses and unlisted reserve ids (the revert surfaces to the
    ///      caller). The returned `underlying` and `decimals` are bound at registration —
    ///      the same reserve→token binding the V2 loan hooks enforce per call. Aave V4
    ///      reserveIds are assigned sequentially and never reused, so a stored binding cannot
    ///      silently point at a different asset. Reverts if already registered.
    /// @dev BOTH legs are registered in a single call — the SUPPLY key (legacy two-word preimage) and the
    ///      DEBT key (`DEBT_KEY_DOMAIN`-separated) — so a half-registered reserve, where one leg resolves and
    ///      the other reverts, is unrepresentable. Either both keys are written or the call reverts.
    /// @param spoke_ Address of the Aave V4 spoke (trusted by caller; see contract-level docs)
    /// @param reserveId_ The reserve identifier within the spoke
    /// @return supplyKey The pseudo-address naming this reserve's SUPPLY leg (unchanged legacy derivation)
    /// @return debtKey The pseudo-address naming this reserve's DEBT leg
    function registerReserve(
        address spoke_,
        uint256 reserveId_
    )
        external
        onlyRole(MARKET_MANAGER_ROLE)
        returns (address supplyKey, address debtKey)
    {
        if (spoke_ == address(0)) revert ZERO_ADDRESS();

        // Reverts for codeless spokes and unlisted reserves — validation happens on-chain
        IAaveV4Spoke.Reserve memory reserve = IAaveV4Spoke(spoke_).getReserve(reserveId_);
        if (reserve.underlying == address(0)) revert INVALID_RESERVE();

        supplyKey = computeReserveKey(spoke_, reserveId_);
        debtKey = computeDebtKey(spoke_, reserveId_);

        // Either leg already present means this reserve was registered before: reject as a whole
        if (_reserves[supplyKey].registered || _reserves[debtKey].registered) {
            revert RESERVE_ALREADY_REGISTERED();
        }

        // Defensive cross-namespace guard: a key may mean a reserve leg OR a market, never both
        if (_markets[supplyKey].registered || _markets[debtKey].registered) revert KEY_NAMESPACE_COLLISION();

        _reserves[supplyKey] = ReserveInfo({
            spoke: spoke_,
            reserveId: reserveId_,
            underlying: reserve.underlying,
            decimals: reserve.decimals,
            side: Side.SUPPLY,
            registered: true
        });
        _reserves[debtKey] = ReserveInfo({
            spoke: spoke_,
            reserveId: reserveId_,
            underlying: reserve.underlying,
            decimals: reserve.decimals,
            side: Side.DEBT,
            registered: true
        });

        emit ReserveRegistered(supplyKey, spoke_, reserveId_, reserve.underlying, Side.SUPPLY);
        emit ReserveRegistered(debtKey, spoke_, reserveId_, reserve.underlying, Side.DEBT);
    }

    /// @notice Restore a single missing leg of an otherwise-registered reserve
    /// @dev WHY THIS EXISTS: `registerReserve` guards per RESERVE (it rejects if EITHER leg is present)
    ///      while deregistration deletes per KEY, so the two are not inverses. Without this, an accidental
    ///      single-leg deregistration could only be repaired by deregistering the surviving leg too — a
    ///      second full `DEREGISTER_DELAY` — and the execute/re-register pair would have to be batched or
    ///      the reserve goes dark on BOTH legs in the gap. That matters more than it looks: the aggregator
    ///      `SuperYieldSourceOracle` loops `getTVLMultiple` / `getTVLByOwnerOfSharesMultiple` WITHOUT
    ///      per-entry isolation, so one unresolvable key aborts a whole portfolio NAV read rather than one
    ///      entry.
    ///      SAFETY: this cannot rebind anything and needs no timelock. The key is re-DERIVED from
    ///      (spoke_, reserveId_) and the side it is stored under is the side whose derivation produced it,
    ///      and the sibling leg must already be registered — so the only key it can ever write is the
    ///      missing leg of a reserve `registerReserve` already created. It reverts if the leg is already
    ///      present, so it is never an overwrite, and the binding is re-read from the Spoke rather than
    ///      copied from the sibling — a reserve that has since been delisted cannot be restored.
    /// @param spoke_ Address of the Aave V4 spoke (trusted by caller; see contract-level docs)
    /// @param reserveId_ The reserve identifier within the spoke
    /// @param side_ Which leg to restore
    /// @return reserveKey The restored leg's pseudo-address
    function repairLeg(
        address spoke_,
        uint256 reserveId_,
        Side side_
    )
        external
        onlyRole(MARKET_MANAGER_ROLE)
        returns (address reserveKey)
    {
        if (spoke_ == address(0)) revert ZERO_ADDRESS();

        reserveKey = side_ == Side.DEBT ? computeDebtKey(spoke_, reserveId_) : computeReserveKey(spoke_, reserveId_);
        if (_reserves[reserveKey].registered) revert RESERVE_ALREADY_REGISTERED();

        if (_markets[reserveKey].registered) revert KEY_NAMESPACE_COLLISION();

        // The SIBLING leg must already exist. Without this, `repairLeg` could mint a lone leg on a reserve
        // that was never registered — creating exactly the half-registered state this contract documents as
        // unrepresentable, and wedging the reserve permanently, since `registerReserve`'s two-key guard then
        // rejects the normal path forever. Requiring the sibling makes `repairLeg` strictly a COMPLETION of
        // a reserve that `registerReserve` already created, never an alternative way to create one.
        address siblingKey =
            side_ == Side.DEBT ? computeReserveKey(spoke_, reserveId_) : computeDebtKey(spoke_, reserveId_);
        if (!_reserves[siblingKey].registered) revert RESERVE_NOT_REGISTERED();

        // Re-read from the Spoke: reverts for codeless spokes and unlisted reserves
        IAaveV4Spoke.Reserve memory reserve = IAaveV4Spoke(spoke_).getReserve(reserveId_);
        if (reserve.underlying == address(0)) revert INVALID_RESERVE();

        _reserves[reserveKey] = ReserveInfo({
            spoke: spoke_,
            reserveId: reserveId_,
            underlying: reserve.underlying,
            decimals: reserve.decimals,
            side: side_,
            registered: true
        });

        emit ReserveRegistered(reserveKey, spoke_, reserveId_, reserve.underlying, side_);
    }

    /// @notice Propose deregistration of a registered reserve, starting the 2-day timelock
    /// @dev Call `executeDeregisterReserve` after the timelock to complete removal.
    ///      Call `cancelDeregisterReserve` to abort before execution.
    ///      Re-proposing an already-pending deregistration resets (extends) the timelock — it can
    ///      never shorten it, matching the OZ TimelockController convention.
    ///      NOTE — proposals never expire: a ripe proposal that is neither executed nor cancelled
    ///      stays executable indefinitely, so a stale abandoned proposal defeats the 2-day warning
    ///      window at execution time. Ops runbook rule: cancel abandoned proposals promptly and
    ///      alert on any pending proposal older than a few days (monitor
    ///      ReserveDeregistrationProposed with no matching Deregistered/Cancelled event).
    ///      Precedent-identical to MorphoBlueMarketRegistry.
    /// @dev SAFETY: Before proposing, confirm no active Superform positions reference this
    ///      reserveKey and the oracle is not registered in SuperLedgerConfiguration.
    ///      See contract-level SAFETY INVARIANT.
    /// @param reserveKey The pseudo-address to deregister
    function proposeDeregisterReserve(address reserveKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (!_reserves[reserveKey].registered) revert RESERVE_NOT_REGISTERED();
        // Immediate operator feedback: deregister the markets that name this leg first
        if (marketRefs[reserveKey] != 0) revert MARKET_REFERENCES_RESERVE();
        uint256 executeAfter = block.timestamp + DEREGISTER_DELAY;
        pendingDeregistrations[reserveKey] = executeAfter;
        emit ReserveDeregistrationProposed(reserveKey, executeAfter);
    }

    /// @notice Execute a previously proposed reserve deregistration after the 2-day timelock
    /// @dev After deregistration the oracle reverts with RESERVE_NOT_REGISTERED for this key.
    ///      Reverts if no deregistration is pending or the timelock has not elapsed.
    /// @dev SAFETY: Executing this with active Superform positions will brick PPS/TVL reads and
    ///      fee-charging outflow accounting. Users cannot withdraw through SuperLedger without
    ///      the oracle returning a valid PPS. See contract-level SAFETY INVARIANT.
    ///      Pre-execution checklist:
    ///        1. The oracle is not registered in SuperLedgerConfiguration for this reserveKey
    ///        2. No SuperVault or monitoring config references this reserveKey
    ///        3. All user positions have been withdrawn or migrated
    ///      If unsure, call `cancelDeregisterReserve` to abort.
    /// @param reserveKey The pseudo-address to deregister
    function executeDeregisterReserve(address reserveKey) external onlyRole(MARKET_MANAGER_ROLE) {
        uint256 executeAfter = pendingDeregistrations[reserveKey];
        if (executeAfter == 0) revert DEREGISTRATION_NOT_PENDING();
        if (block.timestamp < executeAfter) revert DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
        // DEFENCE IN DEPTH, currently unreachable: `RESERVE_DEREGISTRATION_PENDING` in `registerMarket` and
        // `MARKET_REFERENCES_RESERVE` in `proposeDeregisterReserve` make "claimed leg with a pending proposal"
        // unrepresentable, so this cannot fire today. Kept as the backstop if either guard is ever relaxed —
        // one SLOAD on an admin-only path. See `test_legProposalAndMarketClaim_areMutuallyExclusive`.
        if (marketRefs[reserveKey] != 0) revert MARKET_REFERENCES_RESERVE();
        delete pendingDeregistrations[reserveKey];
        delete _reserves[reserveKey];
        emit ReserveDeregistered(reserveKey);
    }

    /// @notice Cancel a pending reserve deregistration before it is executed
    /// @param reserveKey The pseudo-address whose pending deregistration to cancel
    function cancelDeregisterReserve(address reserveKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (pendingDeregistrations[reserveKey] == 0) revert DEREGISTRATION_NOT_PENDING();
        delete pendingDeregistrations[reserveKey];
        emit ReserveDeregistrationCancelled(reserveKey);
    }

    /// @notice Get the reserve binding for a registered reserve key
    /// @param reserveKey The SUPPLY or DEBT pseudo-address of a registered reserve leg
    /// @return spoke The Aave V4 spoke holding the reserve
    /// @return reserveId The reserve identifier within the spoke
    /// @return underlying The reserve's underlying asset bound at registration
    /// @return underlyingDecimals The underlying asset's decimals bound at registration
    /// @return side Which leg this key denotes — SUPPLY or DEBT
    function getReserveInfo(address reserveKey)
        external
        view
        returns (address spoke, uint256 reserveId, address underlying, uint8 underlyingDecimals, Side side)
    {
        ReserveInfo storage info = _reserves[reserveKey];
        if (!info.registered) revert RESERVE_NOT_REGISTERED();
        return (info.spoke, info.reserveId, info.underlying, info.decimals, info.side);
    }

    /// @notice Returns true if the reserve key is registered
    /// @param reserveKey The pseudo-address to query
    /// @return True if registered, false otherwise
    function isRegistered(address reserveKey) external view returns (bool) {
        return _reserves[reserveKey].registered;
    }

    /// @notice Compute the SUPPLY key for a given (spoke, reserveId) pair without registering
    /// @dev Pure computation matching `registerReserve` key derivation: the lower 20 bytes of
    ///      keccak256(abi.encode(spoke, reserveId)). The pair is hashed (rather than truncating
    ///      raw values) so key uniformity holds for small structured inputs; the same collision
    ///      analysis as the contract-level docs applies, and a collision merely prevents
    ///      registration of the second reserve — existing data is never overwritten.
    /// @param spoke_ The Aave V4 spoke address
    /// @param reserveId_ The reserve identifier within the spoke
    /// @return The pseudo-address reserve key
    function computeReserveKey(address spoke_, uint256 reserveId_) public pure returns (address) {
        return AaveV4ReserveKey.computeReserveKey(spoke_, reserveId_);
    }

    /// @notice Compute the DEBT key for a given (spoke, reserveId) pair without registering
    /// @dev Delegates to `AaveV4ReserveKey.computeDebtKey` so Aave V4 key derivation has exactly one home,
    ///      exactly as `computeReserveKey` delegates for the supply leg. Putting it in that library costs
    ///      the hooks nothing: it is `internal` and unused by them, so it is dead-code-eliminated from
    ///      their creation code — verified, not assumed, by `AaveV4LoanBytecodeUnchanged.t.sol`.
    ///      Collision surface is the same 160-bit second-preimage argument as `computeReserveKey`, and a
    ///      collision can only block a registration — it never rebinds existing data.
    /// @param spoke_ The Aave V4 spoke address
    /// @param reserveId_ The reserve identifier within the spoke
    /// @return The pseudo-address debt key
    function computeDebtKey(address spoke_, uint256 reserveId_) public pure returns (address) {
        return AaveV4ReserveKey.computeDebtKey(spoke_, reserveId_);
    }

    /*//////////////////////////////////////////////////////////////
                    MARKET ENTRIES (SUP-21239)
    //////////////////////////////////////////////////////////////*/

    /// @notice Register an Aave V4 market pair — one collateral reserve against one loan reserve
    /// @dev Records the market the V2 LOAN hooks name in their header `yieldSource`, so one economic market
    ///      is ONE yield source in merkle leaves, vault whitelists and the UI instead of two unrelated
    ///      reserve keys. Both underlyings are read from the spoke here, never operator-supplied.
    ///      WHAT THIS DOES NOT DO: it does not gate execution. The V2 LOAN hooks are NONACCOUNTING and never
    ///      call this registry — they only pin that the header equals `computeMarketKey` of the body they
    ///      act on. Whitelisting which markets a vault may touch remains an off-chain (Erebor) decision.
    ///      Markets are not enumerable from Aave V4 (there is no market object on-chain, positions are
    ///      reserve-granular), so registration is explicit curation and there is no auto-seeding analogue of
    ///      `ConfigureAaveV4ReserveRegistry`'s reserve enumeration.
    /// @param spoke_ Address of the Aave V4 spoke (trusted by caller; see contract-level docs)
    /// @param supplyReserveId_ The collateral (supply) reserve identifier within the spoke
    /// @param borrowReserveId_ The loan (borrow) reserve identifier within the spoke
    /// @return marketKey The pseudo-address naming this market
    function registerMarket(
        address spoke_,
        uint256 supplyReserveId_,
        uint256 borrowReserveId_
    )
        external
        onlyRole(MARKET_MANAGER_ROLE)
        returns (address marketKey)
    {
        if (spoke_ == address(0)) revert ZERO_ADDRESS();
        if (supplyReserveId_ == borrowReserveId_) revert IDENTICAL_RESERVES();

        // Reverts for codeless spokes and unlisted reserves — validation happens on-chain
        IAaveV4Spoke.Reserve memory supplyReserve = IAaveV4Spoke(spoke_).getReserve(supplyReserveId_);
        IAaveV4Spoke.Reserve memory borrowReserve = IAaveV4Spoke(spoke_).getReserve(borrowReserveId_);
        if (supplyReserve.underlying == address(0) || borrowReserve.underlying == address(0)) {
            revert INVALID_RESERVE();
        }
        if (supplyReserve.underlying == borrowReserve.underlying) revert IDENTICAL_UNDERLYINGS();

        // Both NAV legs must already resolve through the oracle: the collateral reserve's SUPPLY leg and the
        // loan reserve's DEBT leg are exactly the two keys a consumer reads to value this market. Registering
        // a market whose legs are absent would record a market whose NAV a consumer could not read. (It would
        // not "whitelist" anything — registration gates nothing on-chain; see the function docblock.)
        address supplyLegKey = computeReserveKey(spoke_, supplyReserveId_);
        address debtLegKey = computeDebtKey(spoke_, borrowReserveId_);
        if (!_reserves[supplyLegKey].registered || !_reserves[debtLegKey].registered) {
            revert MARKET_LEG_NOT_REGISTERED();
        }
        // Keep the two timelocks non-overlapping: a leg whose deregistration is already pending cannot be
        // claimed by a new market, because `MARKET_REFERENCES_RESERVE` would then block that execute without
        // clearing the proposal, leaving it armed to fire with no warning window once the market is removed.
        if (pendingDeregistrations[supplyLegKey] != 0 || pendingDeregistrations[debtLegKey] != 0) {
            revert RESERVE_DEREGISTRATION_PENDING();
        }

        marketKey = computeMarketKey(spoke_, supplyReserveId_, borrowReserveId_);
        if (_markets[marketKey].registered) revert MARKET_ALREADY_REGISTERED();
        // Defensive cross-namespace guard, the mirror of `registerReserve`'s
        if (_reserves[marketKey].registered) revert KEY_NAMESPACE_COLLISION();

        _markets[marketKey] = MarketInfo({
            spoke: spoke_,
            supplyReserveId: supplyReserveId_,
            borrowReserveId: borrowReserveId_,
            collateralToken: supplyReserve.underlying,
            loanToken: borrowReserve.underlying,
            registered: true
        });

        ++marketRefs[supplyLegKey];
        ++marketRefs[debtLegKey];

        emit MarketRegistered(
            marketKey, spoke_, supplyReserveId_, borrowReserveId_, supplyReserve.underlying, borrowReserve.underlying
        );
    }

    /// @notice Propose deregistration of a registered market, starting the 2-day timelock
    /// @dev Mirrors the reserve flow: `executeDeregisterMarket` after the timelock, `cancelDeregisterMarket`
    ///      to abort, re-proposing extends but never shortens, and proposals never expire (same ops runbook
    ///      rule — alert on a proposal with no matching Deregistered/Cancelled event).
    /// @dev SAFETY — READ THIS BEFORE PROPOSING. Two distinct hazards, and the second is new:
    ///      (1) a deregistered market key stops resolving through `getMarketInfo`, which off-chain consumers
    ///          use to join a signed intent back to its reserve legs, so deregister only after no root names
    ///          this market. The pin itself is pure derivation, so this does NOT stop the hooks accepting
    ///          the key.
    ///      (2) SINCE SUP-21254 THE IDLE PAIR'S LEDGER KEY IS A MARKET KEY. `AaveV4LendHook` is INFLOW and
    ///          `AaveV4RedeemHook` is OUTFLOW, so `SuperExecutorBase._updateAccounting` resolves the header
    ///          through `AaveV4ReserveOracle`, which reverts `RESERVE_NOT_REGISTERED` for an unregistered
    ///          market. Deregistering a market under which an account still holds an OPEN idle position
    ///          therefore bricks that account's redeem through Superform accounting — it could only exit by
    ///          calling the Spoke directly, outside the ledger. There is no on-chain refcount for this: the
    ///          registry cannot see user positions, so it cannot enforce it the way `marketRefs` enforces the
    ///          reserve-leg direction.
    ///      OPS RULE, therefore: before proposing a market used by the idle pair, confirm no account holds a
    ///      live idle position under it (`AaveV4ReserveOracle.getBalanceOfOwner(marketKey, account)` and the
    ///      ledger's `usersAccumulatorShares(account, marketKey)` must both be zero for every holder). The
    ///      2-day timelock is the window in which to check. Deregistering a LOAN-only market carries hazard
    ///      (1) alone, because LOAN hooks are NONACCOUNTING.
    /// @param marketKey The pseudo-address to deregister
    function proposeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (!_markets[marketKey].registered) revert MARKET_NOT_REGISTERED();
        uint256 executeAfter = block.timestamp + DEREGISTER_DELAY;
        pendingMarketDeregistrations[marketKey] = executeAfter;
        emit MarketDeregistrationProposed(marketKey, executeAfter);
    }

    /// @notice Execute a previously proposed market deregistration after the 2-day timelock
    /// @dev Releases this market's claim on both reserve legs (`marketRefs`), so a leg becomes
    ///      deregisterable again once no market names it.
    ///      WHY THERE IS NO `repairMarket` ANALOGUE OF `repairLeg`: `repairLeg` exists only because reserve
    ///      REGISTRATION is per reserve (two keys) while DEREGISTRATION is per key, so the two are not
    ///      inverses and a half-registered reserve is reachable. A market is exactly ONE key:
    ///      `registerMarket` and this function ARE inverses, no partial state is representable, and the key
    ///      is derived rather than operator-chosen — so re-registering after deregistration reproduces the
    ///      identical key, and the identical binding too UNLESS the spoke has since re-pointed a reserveId's
    ///      underlying (which the reserve path assumes cannot happen: ids are assigned sequentially and never
    ///      reused). A repair primitive would be pure attack surface.
    /// @param marketKey The pseudo-address to deregister
    function executeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        uint256 executeAfter = pendingMarketDeregistrations[marketKey];
        if (executeAfter == 0) revert DEREGISTRATION_NOT_PENDING();
        if (block.timestamp < executeAfter) revert DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
        // DEPENDENCY: there is no `registered` check here because `pendingMarketDeregistrations != 0` implies
        // it — `proposeDeregisterMarket` requires a registered market, and execute (which deletes the market)
        // and cancel are the only ways to clear a proposal, so a second execute hits the guard above. If a
        // future edit ever lets a proposal outlive its market, the decrements below would underflow on
        // `computeReserveKey(address(0), 0)`. Pinned by `test_executeDeregisterMarket_cannotRunTwice`.

        MarketInfo storage market = _markets[marketKey];
        --marketRefs[computeReserveKey(market.spoke, market.supplyReserveId)];
        --marketRefs[computeDebtKey(market.spoke, market.borrowReserveId)];

        delete pendingMarketDeregistrations[marketKey];
        delete _markets[marketKey];
        emit MarketDeregistered(marketKey);
    }

    /// @notice Cancel a pending market deregistration before it is executed
    /// @param marketKey The pseudo-address whose pending deregistration to cancel
    function cancelDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (pendingMarketDeregistrations[marketKey] == 0) revert DEREGISTRATION_NOT_PENDING();
        delete pendingMarketDeregistrations[marketKey];
        emit MarketDeregistrationCancelled(marketKey);
    }

    /// @notice Get the market binding for a registered market key
    /// @dev The off-chain join from a signed intent back to the two NAV keys: derive
    ///      `computeReserveKey(spoke, supplyReserveId)` and `computeDebtKey(spoke, borrowReserveId)` from
    ///      what this returns. Reverts for an unregistered key AND for a reserve key — the namespaces are
    ///      separate mappings.
    /// @param marketKey The pseudo-address of a registered market
    /// @return spoke The Aave V4 spoke holding both reserves
    /// @return supplyReserveId The collateral (supply) reserve identifier
    /// @return borrowReserveId The loan (borrow) reserve identifier
    /// @return collateralToken The supply reserve's underlying bound at registration
    /// @return loanToken The borrow reserve's underlying bound at registration
    function getMarketInfo(address marketKey)
        external
        view
        returns (
            address spoke,
            uint256 supplyReserveId,
            uint256 borrowReserveId,
            address collateralToken,
            address loanToken
        )
    {
        MarketInfo storage market = _markets[marketKey];
        if (!market.registered) revert MARKET_NOT_REGISTERED();
        return (market.spoke, market.supplyReserveId, market.borrowReserveId, market.collateralToken, market.loanToken);
    }

    /// @notice Returns true if the market key is registered
    /// @dev False for every reserve key, by construction — separate mapping, separate namespace
    /// @param marketKey The pseudo-address to query
    /// @return True if registered, false otherwise
    function isMarketRegistered(address marketKey) external view returns (bool) {
        return _markets[marketKey].registered;
    }

    /// @notice Compute the market key for a (spoke, supplyReserveId, borrowReserveId) triple without
    ///         registering
    /// @dev Delegates to `AaveV4ReserveKey.computeMarketKey` so Aave V4 key derivation has exactly one home,
    ///      exactly as `computeReserveKey` / `computeDebtKey` do. ORDER IS SIGNIFICANT: the legs are
    ///      asymmetric, so `(spoke, a, b)` and `(spoke, b, a)` are different markets with different keys and
    ///      the ids must never be sorted. This is the entry point off-chain consumers call to reproduce a
    ///      header before signing it.
    /// @param spoke_ The Aave V4 spoke address
    /// @param supplyReserveId_ The collateral (supply) reserve identifier within the spoke
    /// @param borrowReserveId_ The loan (borrow) reserve identifier within the spoke
    /// @return The pseudo-address market key
    function computeMarketKey(
        address spoke_,
        uint256 supplyReserveId_,
        uint256 borrowReserveId_
    )
        public
        pure
        returns (address)
    {
        return AaveV4ReserveKey.computeMarketKey(spoke_, supplyReserveId_, borrowReserveId_);
    }
}
