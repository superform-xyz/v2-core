// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// morpho vendor
import { IMorphoStaticTyping, MarketParams, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";

/// @title MorphoBlueMarketRegistry
/// @author Superform Labs
/// @notice Permissioned registry that maps pseudo-addresses (derived from Morpho market IDs)
///         to MarketParams. Enables MorphoBlueYieldSourceOracle to be a singleton that
///         supports any registered Morpho Blue market without per-market wrapper deployments.
/// @dev Market key derivation: `address(uint160(uint256(Id.unwrap(marketId))))` takes the lower
///      20 bytes of the 32-byte keccak256 Morpho market ID. Accidental collision probability is
///      negligible: by the birthday bound, the chance of any pair colliding among 2^20 markets in
///      a 2^160 key space is ~2^-121. Deliberately grinding a colliding pair costs ~2^80 work
///      (birthday attack), and targeting a specific existing key costs ~2^160 — both infeasible.
///      Either way a collision merely prevents registration of the second market — it cannot
///      overwrite an existing market's stored data.
///
///      IRM safety: Only IRMs explicitly approved via `setIrmApproval` can be used in registered
///      markets. This prevents a rogue IRM from returning arbitrary `borrowRateView` values that
///      would corrupt the oracle's PPS computation. Zero-IRM markets (irm == address(0)) bypass
///      interest accrual entirely and are always safe to register without approval.
///
///      Morpho address trust: `morpho_` is trusted by the MARKET_MANAGER_ROLE operator; it must
///      be the canonical Morpho Blue singleton for this chain. No on-chain whitelist is enforced
///      because the permissioned role is sufficient to gate registration.
///
///      SAFETY INVARIANT — deregistration:
///      A deregistered market makes the oracle revert for that key. If any Superform-managed
///      position still references the market (SuperLedger, SuperVault, monitoring), deregistration
///      bricks PPS/TVL reads and fee-charging outflow accounting — users cannot withdraw through
///      SuperLedger without the oracle returning a valid PPS.
///      **Do NOT deregister a market with active Superform accounting positions.** The market must
///      first be fully migrated or deprecated (all positions withdrawn / oracle unregistered from
///      SuperLedgerConfiguration) before deregistration is executed.
contract MorphoBlueMarketRegistry is AccessControl {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when querying a market key that has not been registered
    error MARKET_NOT_REGISTERED();

    /// @notice Thrown when registering params that don't match an existing Morpho market
    error MARKET_DOES_NOT_EXIST_ON_MORPHO();

    /// @notice Thrown when registering a market key that is already registered
    error MARKET_ALREADY_REGISTERED();

    /// @notice Thrown when registering a market with a zero loanToken address
    error INVALID_LOAN_TOKEN();

    /// @notice Thrown when registering a market whose IRM has not been approved via setIrmApproval
    /// @dev Zero-address IRM (no-interest markets) is always permitted without approval
    error IRM_NOT_APPROVED();

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /// @notice Thrown when attempting to execute or cancel a deregistration that was never proposed
    error DEREGISTRATION_NOT_PENDING();

    /// @notice Thrown when executing a deregistration before its timelock has elapsed
    error DEREGISTRATION_TIMELOCK_NOT_ELAPSED();

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to register markets, manage IRM approvals, and propose/execute/cancel
    ///         deregistrations
    bytes32 public constant MARKET_MANAGER_ROLE = keccak256("MARKET_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum delay between proposing and executing a market deregistration
    uint256 public constant DEREGISTER_DELAY = 2 days;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MarketInfo {
        address morpho;
        MarketParams params;
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a market is successfully registered
    event MarketRegistered(address indexed marketKey, address indexed morpho, Id indexed id);

    /// @notice Emitted when a pending deregistration is executed and the market is removed
    event MarketDeregistered(address indexed marketKey);

    /// @notice Emitted when a deregistration is proposed, starting the 2-day timelock
    event MarketDeregistrationProposed(address indexed marketKey, uint256 executeAfter);

    /// @notice Emitted when a pending deregistration is cancelled before execution
    event MarketDeregistrationCancelled(address indexed marketKey);

    /// @notice Emitted when an IRM's approval status is changed
    event IrmApprovalSet(address indexed irm, bool approved);

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Registered markets indexed by their pseudo-address market key
    mapping(address marketKey => MarketInfo) private _markets;

    /// @notice IRMs that are approved for use in registered markets
    /// @dev Only non-zero IRMs require approval; address(0) is always permitted
    mapping(address irm => bool) public approvedIrms;

    /// @notice Pending deregistrations: marketKey => timestamp after which execution is allowed
    /// @dev Zero means no pending deregistration for that key
    mapping(address marketKey => uint256 executeAfter) public pendingDeregistrations;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the registry and grant all roles to `admin_`
    /// @dev Call `setIrmApproval` for each IRM before registering markets that use it.
    ///      MARKET_MANAGER_ROLE is granted to `admin_` for operational convenience; consider
    ///      transferring it to a separate hot-key address to limit blast radius.
    /// @param admin_ Address granted DEFAULT_ADMIN_ROLE and MARKET_MANAGER_ROLE; must be non-zero
    constructor(address admin_) {
        if (admin_ == address(0)) revert ZERO_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MARKET_MANAGER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Approve or revoke an IRM for use in registered markets
    /// @dev Must be called before registering any market that uses a non-zero IRM.
    ///      Revoking an already-approved IRM does not affect previously registered markets;
    ///      it only prevents future `registerMarket` calls with that IRM.
    /// @param irm_ The IRM contract address to update
    /// @param approved_ True to approve, false to revoke
    function setIrmApproval(address irm_, bool approved_) external onlyRole(MARKET_MANAGER_ROLE) {
        approvedIrms[irm_] = approved_;
        emit IrmApprovalSet(irm_, approved_);
    }

    /// @notice Register a Morpho Blue market by its params
    /// @dev Validates the market exists on Morpho via `idToMarketParams`. The `morpho_` address
    ///      is trusted by the MARKET_MANAGER_ROLE operator and must be the canonical Morpho Blue
    ///      singleton for this chain. Non-zero IRMs must be pre-approved via `setIrmApproval` to
    ///      prevent rogue IRMs from corrupting the oracle's PPS via malicious `borrowRateView`.
    ///      Reverts if already registered or market doesn't exist on Morpho.
    /// @param morpho_ Address of the Morpho Blue singleton on this chain (trusted by caller)
    /// @param loanToken_ Loan token of the market; must be non-zero
    /// @param collateralToken_ Collateral token of the market (may be zero for supply-only markets)
    /// @param oracle_ Price oracle used by the market (may be zero)
    /// @param irm_ Interest rate model used by the market; must be approved or zero
    /// @param lltv_ Liquidation LTV of the market (1e18 = 100%)
    /// @return marketKey The pseudo-address used as yieldSourceAddress for this market
    function registerMarket(
        address morpho_,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    )
        external
        onlyRole(MARKET_MANAGER_ROLE)
        returns (address marketKey)
    {
        if (loanToken_ == address(0)) revert INVALID_LOAN_TOKEN();
        if (irm_ != address(0) && !approvedIrms[irm_]) revert IRM_NOT_APPROVED();

        MarketParams memory params = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });

        Id id = params.id();

        // Validate market exists on Morpho
        (address registeredLoanToken,,,,) = IMorphoStaticTyping(morpho_).idToMarketParams(id);
        if (registeredLoanToken == address(0)) revert MARKET_DOES_NOT_EXIST_ON_MORPHO();

        // Derive pseudo-address from the lower 20 bytes of the 32-byte market ID
        marketKey = address(uint160(uint256(Id.unwrap(id))));

        if (_markets[marketKey].registered) revert MARKET_ALREADY_REGISTERED();

        _markets[marketKey] = MarketInfo({ morpho: morpho_, params: params, registered: true });

        emit MarketRegistered(marketKey, morpho_, id);
    }

    /// @notice Propose deregistration of a registered market, starting the 2-day timelock
    /// @dev Call `executeDeregisterMarket` after the timelock to complete removal.
    ///      Call `cancelDeregisterMarket` to abort before execution.
    ///      Re-proposing an already-pending deregistration resets the timelock.
    /// @dev SAFETY: Before proposing, confirm no active Superform positions reference this
    ///      marketKey and the oracle is not registered in SuperLedgerConfiguration.
    ///      See contract-level SAFETY INVARIANT.
    /// @param marketKey The pseudo-address to deregister
    function proposeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (!_markets[marketKey].registered) revert MARKET_NOT_REGISTERED();
        uint256 executeAfter = block.timestamp + DEREGISTER_DELAY;
        pendingDeregistrations[marketKey] = executeAfter;
        emit MarketDeregistrationProposed(marketKey, executeAfter);
    }

    /// @notice Execute a previously proposed market deregistration after the 2-day timelock
    /// @dev After deregistration the oracle will revert with MARKET_NOT_REGISTERED for this key.
    ///      Reverts if no deregistration is pending or the timelock has not elapsed.
    /// @dev SAFETY: Executing this with active Superform positions will brick PPS/TVL reads and
    ///      fee-charging outflow accounting. Users cannot withdraw through SuperLedger without
    ///      the oracle returning a valid PPS. See contract-level SAFETY INVARIANT.
    ///      Pre-execution checklist:
    ///        1. Oracle is NOT registered in SuperLedgerConfiguration for this marketKey
    ///        2. No SuperVault or monitoring config references this marketKey
    ///        3. All user positions have been withdrawn or migrated
    ///      If unsure, call `cancelDeregisterMarket` to abort.
    /// @param marketKey The pseudo-address to deregister
    function executeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        uint256 executeAfter = pendingDeregistrations[marketKey];
        if (executeAfter == 0) revert DEREGISTRATION_NOT_PENDING();
        if (block.timestamp < executeAfter) revert DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
        delete pendingDeregistrations[marketKey];
        delete _markets[marketKey];
        emit MarketDeregistered(marketKey);
    }

    /// @notice Cancel a pending market deregistration before it is executed
    /// @param marketKey The pseudo-address whose pending deregistration to cancel
    function cancelDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
        if (pendingDeregistrations[marketKey] == 0) revert DEREGISTRATION_NOT_PENDING();
        delete pendingDeregistrations[marketKey];
        emit MarketDeregistrationCancelled(marketKey);
    }

    /// @notice Get market params and morpho address for a registered market key
    /// @param marketKey The pseudo-address derived from the market ID
    /// @return params The MarketParams struct for this market
    /// @return morpho The Morpho Blue singleton address for this market
    function getMarketInfo(address marketKey) external view returns (MarketParams memory params, address morpho) {
        MarketInfo storage info = _markets[marketKey];
        if (!info.registered) revert MARKET_NOT_REGISTERED();
        return (info.params, info.morpho);
    }

    /// @notice Returns true if the market key is registered
    /// @param marketKey The pseudo-address to query
    /// @return True if registered, false otherwise
    function isRegistered(address marketKey) external view returns (bool) {
        return _markets[marketKey].registered;
    }

    /// @notice Compute the market key for a given set of params without registering
    /// @dev Pure computation matching `registerMarket` key derivation.
    ///      The key is the lower 20 bytes of the 32-byte keccak256 Morpho market ID.
    ///      Accidental collision probability is negligible (~2^-121 for any pair among 2^20
    ///      markets; see contract-level docs) and a collision merely prevents registration of
    ///      the second market — existing data is never overwritten.
    /// @param loanToken_ Loan token address
    /// @param collateralToken_ Collateral token address
    /// @param oracle_ Oracle address
    /// @param irm_ IRM address
    /// @param lltv_ Liquidation LTV
    /// @return The pseudo-address market key
    function computeMarketKey(
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    )
        external
        pure
        returns (address)
    {
        MarketParams memory params = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        Id id = params.id();
        return address(uint160(uint256(Id.unwrap(id))));
    }
}
