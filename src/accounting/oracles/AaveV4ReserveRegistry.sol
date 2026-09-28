// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4ReserveRegistry
/// @author Superform Labs
/// @notice Permissioned registry that maps pseudo-addresses (derived from Aave V4 (spoke,
///         reserveId) pairs) to reserve bindings. Enables the AaveV4DebtOracle and
///         AaveV4SupplyYieldSourceOracle to be singletons that support any registered Aave V4
///         reserve without per-reserve wrapper deployments. Aave V4 spokes mint no aToken or
///         debtToken (positions are spoke-internal shares), so no protocol-provided
///         address-shaped handle exists — this registry supplies one.
/// @dev Reserve key derivation: `address(uint160(uint256(keccak256(abi.encode(spoke,
///      reserveId)))))` — the lower 20 bytes of the keccak256 hash of the (spoke, reserveId)
///      pair. The key is DERIVED, never operator-chosen: a key can only ever bind to the pair
///      that hashes to it, so re-registration after deregistration cannot rebind a key to a
///      different reserve. Accidental collision probability is negligible: by the birthday
///      bound, the chance of any pair colliding among 2^20 reserves in a 2^160 key space is
///      ~2^-121. Deliberately grinding a colliding pair costs ~2^80 work and targeting a
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
///      A deregistered reserve makes both oracles revert for that key. If any Superform-managed
///      position still references the reserve (SuperLedger, SuperVault, monitoring),
///      deregistration bricks PPS/TVL reads and fee-charging outflow accounting — users cannot
///      withdraw through SuperLedger without the oracle returning a valid PPS.
///      **Do NOT deregister a reserve with active Superform accounting positions.** The reserve
///      must first be fully migrated or deprecated (all positions withdrawn / oracle
///      unregistered from SuperLedgerConfiguration) before deregistration is executed.
contract AaveV4ReserveRegistry is AccessControl {
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

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @param spoke The Aave V4 spoke holding the reserve
    /// @param reserveId The reserve identifier within the spoke
    /// @param underlying The reserve's underlying asset, bound at registration
    /// @param decimals The underlying asset's decimals, bound at registration
    /// @param registered True once registered (spoke may legitimately be a nonzero sentinel)
    struct ReserveInfo {
        address spoke;
        uint256 reserveId;
        address underlying;
        uint8 decimals;
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a reserve is successfully registered
    event ReserveRegistered(
        address indexed reserveKey, address indexed spoke, uint256 indexed reserveId, address underlying
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

    /// @notice Register an Aave V4 reserve by its (spoke, reserveId) pair
    /// @dev Validates the reserve exists on the spoke via `getReserve`, which reverts for
    ///      codeless spoke addresses and unlisted reserve ids (the revert surfaces to the
    ///      caller). The returned `underlying` and `decimals` are bound at registration —
    ///      the same reserve→token binding the V2 loan hooks enforce per call. Aave V4
    ///      reserveIds are assigned sequentially and never reused, so a stored binding cannot
    ///      silently point at a different asset. Reverts if already registered.
    /// @param spoke_ Address of the Aave V4 spoke (trusted by caller; see contract-level docs)
    /// @param reserveId_ The reserve identifier within the spoke
    /// @return reserveKey The pseudo-address used as yieldSourceAddress for this reserve
    function registerReserve(
        address spoke_,
        uint256 reserveId_
    )
        external
        onlyRole(MARKET_MANAGER_ROLE)
        returns (address reserveKey)
    {
        if (spoke_ == address(0)) revert ZERO_ADDRESS();

        // Reverts for codeless spokes and unlisted reserves — validation happens on-chain
        IAaveV4Spoke.Reserve memory reserve = IAaveV4Spoke(spoke_).getReserve(reserveId_);
        if (reserve.underlying == address(0)) revert INVALID_RESERVE();

        reserveKey = computeReserveKey(spoke_, reserveId_);

        if (_reserves[reserveKey].registered) revert RESERVE_ALREADY_REGISTERED();

        _reserves[reserveKey] = ReserveInfo({
            spoke: spoke_,
            reserveId: reserveId_,
            underlying: reserve.underlying,
            decimals: reserve.decimals,
            registered: true
        });

        emit ReserveRegistered(reserveKey, spoke_, reserveId_, reserve.underlying);
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
    ///      reserveKey and neither oracle is registered in SuperLedgerConfiguration.
    ///      See contract-level SAFETY INVARIANT.
    /// @param reserveKey The pseudo-address to deregister
    function proposeDeregisterReserve(address reserveKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (!_reserves[reserveKey].registered) revert RESERVE_NOT_REGISTERED();
        uint256 executeAfter = block.timestamp + DEREGISTER_DELAY;
        pendingDeregistrations[reserveKey] = executeAfter;
        emit ReserveDeregistrationProposed(reserveKey, executeAfter);
    }

    /// @notice Execute a previously proposed reserve deregistration after the 2-day timelock
    /// @dev After deregistration both oracles revert with RESERVE_NOT_REGISTERED for this key.
    ///      Reverts if no deregistration is pending or the timelock has not elapsed.
    /// @dev SAFETY: Executing this with active Superform positions will brick PPS/TVL reads and
    ///      fee-charging outflow accounting. Users cannot withdraw through SuperLedger without
    ///      the oracle returning a valid PPS. See contract-level SAFETY INVARIANT.
    ///      Pre-execution checklist:
    ///        1. Neither oracle is registered in SuperLedgerConfiguration for this reserveKey
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
    /// @param reserveKey The pseudo-address derived from the (spoke, reserveId) pair
    /// @return spoke The Aave V4 spoke holding the reserve
    /// @return reserveId The reserve identifier within the spoke
    /// @return underlying The reserve's underlying asset bound at registration
    /// @return underlyingDecimals The underlying asset's decimals bound at registration
    function getReserveInfo(address reserveKey)
        external
        view
        returns (address spoke, uint256 reserveId, address underlying, uint8 underlyingDecimals)
    {
        ReserveInfo storage info = _reserves[reserveKey];
        if (!info.registered) revert RESERVE_NOT_REGISTERED();
        return (info.spoke, info.reserveId, info.underlying, info.decimals);
    }

    /// @notice Returns true if the reserve key is registered
    /// @param reserveKey The pseudo-address to query
    /// @return True if registered, false otherwise
    function isRegistered(address reserveKey) external view returns (bool) {
        return _reserves[reserveKey].registered;
    }

    /// @notice Compute the reserve key for a given (spoke, reserveId) pair without registering
    /// @dev Pure computation matching `registerReserve` key derivation: the lower 20 bytes of
    ///      keccak256(abi.encode(spoke, reserveId)). The pair is hashed (rather than truncating
    ///      raw values) so key uniformity holds for small structured inputs; the same collision
    ///      analysis as the contract-level docs applies, and a collision merely prevents
    ///      registration of the second reserve — existing data is never overwritten.
    /// @param spoke_ The Aave V4 spoke address
    /// @param reserveId_ The reserve identifier within the spoke
    /// @return The pseudo-address reserve key
    function computeReserveKey(address spoke_, uint256 reserveId_) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId_)))));
    }
}
