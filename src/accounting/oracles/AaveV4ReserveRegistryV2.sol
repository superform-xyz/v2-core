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
/// @notice Permissioned registry that maps pseudo-addresses — TWO per Aave V4 (spoke, reserveId)
///         reserve, one per leg — to reserve bindings. Enables `AaveV4ReserveOracle` to be a
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

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to register reserves and propose/execute/cancel deregistrations
    bytes32 public constant MARKET_MANAGER_ROLE = keccak256("MARKET_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum delay between proposing and executing a reserve deregistration
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

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Registered reserves indexed by their pseudo-address reserve key
    mapping(address reserveKey => ReserveInfo) private _reserves;

    /// @notice Pending deregistrations: reserveKey => timestamp after which execution is allowed
    /// @dev Zero means no pending deregistration for that key
    mapping(address reserveKey => uint256 executeAfter) public pendingDeregistrations;

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
}
