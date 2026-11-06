// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title GyldBondRegistry
/// @author Superform Labs
/// @notice The approved-instrument list for Gyld tokenized bonds: which bond tokens may be valued and traded,
///         which feed is authoritative for each, and in which cash denomination.
/// @dev KEYED DIRECTLY BY BOND TOKEN. Unlike the Morpho (market id) and UniV3 (pool + tick range) registries
///      there is exactly one configuration per bond token, so no pseudo-address derivation is needed and a whole
///      class of key-mismatch bugs disappears.
/// @dev APPROVED FEED SOURCES. `navFeed` is THE approved source for an instrument; the oracle reads nothing else.
///      Changing it is timelocked AND force-suspends valuation, so a feed swap can never silently re-point what
///      a vault is marked at. Unsuspending is a separate, deliberate call.
/// @dev THE SUSPENSION SWITCH IS NOT TIMELOCKED, ON PURPOSE. `setNavSuspended` is the incident control for a
///      credit event, a feed failure or maturity. It cannot live behind a delay and it cannot live in a Merkle
///      leaf, because roots cannot be re-signed fast enough while an instrument is impairing.
/// @dev DO NOT DEREGISTER AN INSTRUMENT WHILE ANY SUPERFORM-MANAGED POSITION STILL HOLDS IT. Deregistration
///      bricks valuation for that instrument. Suspend instead; suspension preserves visible holdings while
///      blocking NAV-sensitive actions.
contract GyldBondRegistry is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error INSTRUMENT_ALREADY_REGISTERED();
    error INSTRUMENT_NOT_REGISTERED();
    error DEREGISTRATION_NOT_PENDING();
    error DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
    error CHANGE_NOT_PENDING();
    error CHANGE_TIMELOCK_NOT_ELAPSED();
    error INVALID_STALENESS();
    error IDENTICAL_TOKENS();
    /// @notice A USD-denominated NAV feed cannot be converted without a cash/USD feed
    error CASH_FEED_REQUIRED();
    error INVALID_FEED_KIND();
    error INVALID_BOUNDS();
    /// @notice F4: clearing an override and recording a total loss are different actions
    error RECOVERY_NOT_SET();
    /// @notice F1: a trade-floor tolerance above `MAX_TOLERANCE_BPS` (20%), not above 100%
    error INVALID_BPS();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant INSTRUMENT_MANAGER_ROLE = keccak256("INSTRUMENT_MANAGER_ROLE");

    /// @notice Delay on changes that alter what a holding is worth
    uint256 public constant DEREGISTER_DELAY = 2 days;
    /// @notice Basis-point denominator for the trade-floor tolerances
    uint16 public constant BPS_DENOMINATOR = 10_000;
    /// @notice Hard ceiling on either trade-floor tolerance, in bps (20%).
    /// @dev F1: stops a fat-fingered or malicious 10_000 — which would make the realised-price floor
    ///      vacuous — from being settable at all. A tolerance wider than this is not a tolerance, and
    ///      widening past it has to be a deliberate contract change rather than one ops transaction.
    ///      Note 0 is NOT rejected here: it stores as "unconfigured", which `GyldTradePolicy` reports as a
    ///      named `TRADE_FLOORS_NOT_SET` failure rather than silently applying a default nobody chose.
    uint16 public constant MAX_TOLERANCE_BPS = 2000;

    /// @notice Upper bound on any configurable age, so a mis-signed configuration cannot authorise a year-old NAV
    uint256 public constant MAX_AGE_CEILING = 30 days;

    /// @notice `navFeedKind` for a Chainlink-style `AggregatorV3` feed: publication time only, no observation time
    uint8 public constant FEED_KIND_CHAINLINK = 0;
    /// @notice `navFeedKind` for a Gyld-native feed exposing both observation and publication time
    uint8 public constant FEED_KIND_GYLD_NATIVE = 1;

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Everything the oracle needs to value one instrument, with scales precomputed at registration.
    /// @dev Scales are stored rather than recomputed per call, following the UniV3 registry's explicit reasoning.
    struct InstrumentConfig {
        address bondToken;
        uint256 bondScale;
        address navFeed;
        uint8 navFeedKind;
        uint256 navFeedScale;
        bool navIsUsdDenominated;
        int192 navMinAnswer;
        int192 navMaxAnswer;
        address cashToken;
        uint256 cashScale;
        address cashFeed;
        uint256 cashFeedScale;
        int192 cashMinAnswer;
        int192 cashMaxAnswer;
        uint256 maxObservationAge;
        uint256 maxPublicationAge;
        bool requiresObservationTime;
        address sequencerUptimeFeed;
        uint256 gracePeriod;
        bool navSuspended;
        /// @notice Terminal valuation override, in CASH-TOKEN UNITS per one whole bond token.
        /// @dev NOT feed units. The oracle returns this verbatim where the converted feed value would sit,
        ///      so a 6-decimal cash token means 40.00 is `40e6`, NOT `40e8`. Entering feed units overstates
        ///      the mark by `navFeedScale / cashScale` — 100x for 6-decimal cash against an 8-decimal feed.
        /// @dev AND UNDERSTATING IS THE DANGEROUS DIRECTION. Overstating fails CLOSED: the SELL floor rises
        ///      and exits revert. Understating lowers the floor proportionally — entering `40e4` for a
        ///      40-cash-unit mark drops it 100x and lets the whole position exit at 1% of its mark. There is
        ///      no on-chain check in either direction. A cheap one exists if wanted: require
        ///      `recoveryNav <= navMaxAnswer * cashScale / navFeedScale` whenever `navMaxAnswer != 0` —
        ///      noting that form is only right for a NON-USD instrument; a `navIsUsdDenominated` one also
        ///      divides by the cash/USD price.
        ///      Nothing on-chain catches it: `navMinAnswer`/`navMaxAnswer` are in FEED units and are applied
        ///      only inside the feed read, so a recovery mark bypasses the circuit breaker entirely. The
        ///      2-day timelock plus human review is the only guard.
        uint256 recoveryNav;
        /// @notice F4: whether `recoveryNav` is in force. Separate from the value, so a recovery of ZERO
        ///         (a total loss) is expressible. Previously `recoveryNav != 0` was the enable flag, which
        ///         made executing a zero recovery indistinguishable from clearing the override and
        ///         silently resumed the feed on a defaulted instrument.
        bool recoveryNavSet;
        /// @notice F1: how far the REALISED entry price may sit above NAV, in bps. Read by
        ///         `GyldTradePolicy.validateFill` on a BUY and applied to observed balance deltas, so it
        ///         binds regardless of the `outputMin` the caller put in the header.
        /// @dev Lives here rather than in the policy's initcode so a tolerance can be recalibrated with one
        ///      role-gated transaction instead of two fresh CREATE2 hook addresses and a Merkle root re-sign.
        ///      Capped at `MAX_TOLERANCE_BPS` (20%). Note 10_000 is NOT symmetric between the legs after
        ///      R4-2: on the EXIT leg it would disable the floor entirely, while on the ENTRY leg it means
        ///      `expected / 2`, i.e. a 100% premium cap. Neither is settable. Zero stores as
        ///      "unconfigured" and the policy fails closed on it.
        uint16 maxEntryPremiumBps;
        /// @notice F1: how far the REALISED exit price may sit below NAV, in bps. The SELL counterpart of
        ///         `maxEntryPremiumBps`, applied against the live NAV or, during a credit event, the
        ///         timelocked `recoveryNav`.
        uint16 maxExitDiscountBps;
        /// @notice R4-3: how stale the NAV publication may be and still authorise a SELL, in seconds.
        /// @dev THE BOUNDED EXIT GRACE. Without it the policy refuses a SELL the moment the feed goes
        ///      stale, so the only exit is a `recoveryNav` behind a 2-day timelock — i.e. the vault is
        ///      locked in for two days during exactly the incident it would want out of. That contradicted
        ///      the stated "sell mode allows emergency unwinding under relaxed freshness rules".
        /// @dev WHY A STALE REFERENCE IS SAFE ON THIS LEG, AND ONLY THIS LEG. The SELL floor is
        ///      `inputSpent * nav / bondScale * (1 - discount)`, so it RISES with `nav`. A stale, too-high
        ///      NAV therefore makes the vault demand MORE cash and the trade fail — it cannot underprice
        ///      the exit. The knob that can actually authorise a bad exit is the DISCOUNT below, which is
        ///      why that one is governance-set in advance and hard-capped, while this one only widens a
        ///      time window. Never mirror this onto the BUY leg: there the same staleness is dangerous.
        /// @dev Zero means the grace is OFF and the policy keeps failing closed. Capped at
        ///      `MAX_AGE_CEILING`. Deliberately NOT accepted at registration, like `navSuspended` and
        ///      `recoveryNav`: an incident control must be a separate, visible, role-gated act.
        uint32 emergencyExitMaxPublicationAge;
        /// @notice R4-3: the wider exit discount that applies ONLY while trading inside the grace window.
        /// @dev Separate from `maxExitDiscountBps` on purpose. Reusing the normal discount would mean the
        ///      degraded exit is priced as tightly as a healthy one and would mostly fail to fill, which is
        ///      the same lock-in by another route. Capped at `MAX_TOLERANCE_BPS` like the others, and it
        ///      must be at least `maxExitDiscountBps` — a grace NARROWER than normal is incoherent.
        /// @dev Zero means OFF. Both fields are set together or not at all.
        uint16 emergencyExitDiscountBps;
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Max age of the SuperVault aggregator's price-per-share observation a trade may rely on.
    /// @dev F1: REGISTRY-LEVEL, not per-instrument, because PPS freshness is a property of the STRATEGY
    ///      rather than of any one bond. Lives here rather than in `GyldTradePolicy`'s initcode for the same
    ///      reason the trade floors do: retuning a tolerance should be one role-gated transaction, not two
    ///      fresh CREATE2 hook addresses plus a Merkle root re-sign.
    /// @dev ZERO MEANS UNCONFIGURED, NOT DISABLED. The policy refuses to trade on a chain that has an
    ///      aggregator while this is unset, rather than silently skipping the age check.
    uint256 public maxPpsAge;

    mapping(address bondToken => InstrumentConfig config) private _instruments;
    mapping(address bondToken => uint256 executeAt) public pendingDeregistration;
    mapping(address bondToken => uint256 executeAt) public pendingRecoveryNavAt;
    mapping(address bondToken => uint256 value) public pendingRecoveryNav;
    /// @notice R2-1: removing an override is as much a valuation change as installing one, so it carries the
    ///         same delay. Clearing hands the mark back to the feed, which may be a fresh, in-bounds par
    ///         value, so an immediate clear could lift an impaired mark to par in a single transaction.
    mapping(address bondToken => uint256 executeAt) public pendingClearRecoveryNavAt;
    mapping(address bondToken => uint256 executeAt) public pendingFeedAt;
    mapping(address bondToken => address feed) public pendingFeed;
    mapping(address bondToken => uint8 kind) public pendingFeedKind;
    /// @notice F6: bounds travel WITH the feed change. A replacement feed with different decimals needs
    ///         bounds in its own units, and leaving the old ones in place made every normal value trip the
    ///         circuit breaker.
    mapping(address bondToken => int192 min) public pendingFeedMinAnswer;
    mapping(address bondToken => int192 max) public pendingFeedMaxAnswer;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event InstrumentRegistered(address indexed bondToken, address indexed navFeed, address indexed cashToken);
    event InstrumentDeregistrationProposed(address indexed bondToken, uint256 executeAt);
    event InstrumentDeregistrationCancelled(address indexed bondToken);
    event InstrumentDeregistered(address indexed bondToken);
    /// @notice Emitted whenever valuation is stopped or resumed. The incident signal for off-chain monitoring.
    event NavSuspended(address indexed bondToken, bool suspended);
    event RecoveryNavProposed(address indexed bondToken, uint256 recoveryNav, uint256 executeAt);
    event RecoveryNavSet(address indexed bondToken, uint256 recoveryNav);
    event RecoveryNavCleared(address indexed bondToken);
    event RecoveryNavProposalCancelled(address indexed bondToken);
    /// @notice R2-1: the clear direction is timelocked too, so it has its own propose/cancel signals.
    event RecoveryNavClearProposed(address indexed bondToken, uint256 executeAt);
    event RecoveryNavClearProposalCancelled(address indexed bondToken);
    event FeedChangeProposalCancelled(address indexed bondToken);
    event PendingChangesCleared(address indexed bondToken);
    event FeedChangeProposed(address indexed bondToken, address indexed newFeed, uint8 kind, uint256 executeAt);
    event FeedChanged(address indexed bondToken, address indexed newFeed, uint8 kind);
    event CircuitBreakerBoundsRefreshed(address indexed bondToken);
    event StalenessBoundsUpdated(address indexed bondToken, uint256 maxObservationAge, uint256 maxPublicationAge);
    /// @notice F1: alert on this — a widening tolerance is the fail-open direction.
    event TradeFloorsUpdated(address indexed bondToken, uint16 maxEntryPremiumBps, uint16 maxExitDiscountBps);
    /// @notice F1: registry-wide PPS freshness tolerance changed
    event MaxPpsAgeUpdated(uint256 maxPpsAge);
    /// @notice R4-3: the bounded exit grace was opened, retuned or closed for one instrument
    event EmergencyExitUpdated(address indexed bondToken, uint32 maxPublicationAge, uint16 discountBps);

    constructor(address admin) {
        if (admin == address(0)) revert ZERO_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(INSTRUMENT_MANAGER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                              REGISTRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers an instrument and precomputes its scales
    /// @dev Reverts rather than defaulting on every field that could silently mis-value a holding. In particular
    ///      a USD-denominated NAV feed with no cash feed is rejected outright: that combination is the
    ///      "assume cash equals one dollar" bug, and it must be impossible to configure.
    function registerInstrument(InstrumentConfig calldata cfg) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        address bondToken = cfg.bondToken;
        if (_instruments[bondToken].registered) revert INSTRUMENT_ALREADY_REGISTERED();
        _validateRegistration(cfg);

        InstrumentConfig storage stored = _instruments[bondToken];
        stored.bondToken = bondToken;
        stored.navFeed = cfg.navFeed;
        stored.navFeedKind = cfg.navFeedKind;
        stored.navIsUsdDenominated = cfg.navIsUsdDenominated;
        stored.navMinAnswer = cfg.navMinAnswer;
        stored.navMaxAnswer = cfg.navMaxAnswer;
        stored.cashToken = cfg.cashToken;
        stored.cashFeed = cfg.cashFeed;
        stored.cashMinAnswer = cfg.cashMinAnswer;
        stored.cashMaxAnswer = cfg.cashMaxAnswer;
        stored.maxObservationAge = cfg.maxObservationAge;
        stored.maxPublicationAge = cfg.maxPublicationAge;
        stored.requiresObservationTime = cfg.requiresObservationTime;
        stored.sequencerUptimeFeed = cfg.sequencerUptimeFeed;
        stored.gracePeriod = cfg.gracePeriod;
        stored.maxEntryPremiumBps = cfg.maxEntryPremiumBps;
        stored.maxExitDiscountBps = cfg.maxExitDiscountBps;
        stored.registered = true;
        // Deliberately NOT copied from the caller: an instrument is never born suspended, with a recovery
        // NAV, or with an exit grace already open. All three are incident controls and each has to be a
        // separate role-gated act so it shows up in the event log on its own.
        stored.navSuspended = false;
        stored.recoveryNav = 0;
        stored.recoveryNavSet = false;
        stored.emergencyExitMaxPublicationAge = 0;
        stored.emergencyExitDiscountBps = 0;

        _precomputeScales(bondToken);

        emit InstrumentRegistered(bondToken, cfg.navFeed, cfg.cashToken);
    }

    /// @dev Every branch here is a way a holding could be silently mis-valued, so each one reverts rather than
    ///      defaulting. The USD-without-cash-feed rejection is the "assume cash equals one dollar" bug: it must
    ///      be impossible to configure, not merely discouraged.
    function _validateRegistration(InstrumentConfig calldata cfg) private pure {
        if (cfg.bondToken == address(0) || cfg.navFeed == address(0) || cfg.cashToken == address(0)) {
            revert ZERO_ADDRESS();
        }
        if (cfg.bondToken == cfg.cashToken) revert IDENTICAL_TOKENS();
        _validateFloors(cfg.maxEntryPremiumBps, cfg.maxExitDiscountBps);
        if (cfg.navFeedKind > FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();
        if (cfg.navIsUsdDenominated && cfg.cashFeed == address(0)) revert CASH_FEED_REQUIRED();
        // An instrument that requires observation time cannot be served by a feed that cannot express it.
        if (cfg.requiresObservationTime && cfg.navFeedKind != FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();
        _validateAges(cfg.maxObservationAge, cfg.maxPublicationAge);
        _validateBounds(cfg.navMinAnswer, cfg.navMaxAnswer);
        _validateBounds(cfg.cashMinAnswer, cfg.cashMaxAnswer);
    }

    function _validateBounds(int192 minAnswer, int192 maxAnswer) private pure {
        if (minAnswer < 0 || maxAnswer < 0) revert INVALID_BOUNDS();
        if (maxAnswer != 0 && minAnswer >= maxAnswer) revert INVALID_BOUNDS();
    }

    /// @notice Re-reads `decimals()` on the bond, cash and feed contracts and refreshes the stored scales
    function refreshScales(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        _requireRegistered(bondToken);
        _precomputeScales(bondToken);
        emit CircuitBreakerBoundsRefreshed(bondToken);
    }

    /// @notice Updates the staleness bounds for an instrument
    function setStalenessBounds(
        address bondToken,
        uint256 maxObservationAge,
        uint256 maxPublicationAge
    )
        external
        onlyRole(INSTRUMENT_MANAGER_ROLE)
    {
        _requireRegistered(bondToken);
        _validateAges(maxObservationAge, maxPublicationAge);
        _instruments[bondToken].maxObservationAge = maxObservationAge;
        _instruments[bondToken].maxPublicationAge = maxPublicationAge;
        emit StalenessBoundsUpdated(bondToken, maxObservationAge, maxPublicationAge);
    }

    /// @notice Sets the max age of the aggregator's price-per-share observation a trade may rely on
    /// @dev Mirrors `setStalenessBounds`: a freshness tolerance, role-gated, not timelocked. Bounded by
    ///      `MAX_AGE_CEILING` so a mis-signed configuration cannot authorise a year-old PPS.
    /// @param newMaxPpsAge Seconds; 0 stores as UNCONFIGURED and the policy then refuses to trade
    function setMaxPpsAge(uint256 newMaxPpsAge) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        if (newMaxPpsAge > MAX_AGE_CEILING) revert INVALID_STALENESS();
        maxPpsAge = newMaxPpsAge;
        emit MaxPpsAgeUpdated(newMaxPpsAge);
    }

    /// @notice Sets how far a REALISED trade price may deviate from NAV, in bps, per direction
    /// @dev F1: these bound `GyldTradePolicy.validateFill`, which measures observed balance deltas, so they
    ///      cap value leakage per trade even when the caller's header `outputMin` is permissive.
    /// @dev NOT timelocked, matching `setStalenessBounds` above: both are risk tolerances rather than
    ///      valuations, and the two timelocked paths in this contract (`recoveryNav`, feed changes) both
    ///      change what an instrument is WORTH. Loosening is the fail-open direction and is deliberately
    ///      left as a single role-gated transaction so an incident can be responded to at incident speed —
    ///      alert on `TradeFloorsUpdated` and treat a widening as an event needing a reason.
    /// @param bondToken The registered instrument
    /// @param maxEntryPremiumBps BUY tolerance, 1..MAX_TOLERANCE_BPS; 0 stores as unconfigured
    /// @param maxExitDiscountBps SELL tolerance, 1..MAX_TOLERANCE_BPS; 0 stores as unconfigured
    function setTradeFloors(
        address bondToken,
        uint16 maxEntryPremiumBps,
        uint16 maxExitDiscountBps
    )
        external
        onlyRole(INSTRUMENT_MANAGER_ROLE)
    {
        _requireRegistered(bondToken);
        // D7: the DESIGNATED setter must not be able to write "unconfigured". Zero is accepted at
        // registration (an instrument may legitimately be onboarded before its tolerances are agreed, and
        // the policy fails closed until they are), but a deliberate call here with zero could only ever
        // brick that direction, so it is refused rather than stored.
        if (maxEntryPremiumBps == 0 || maxExitDiscountBps == 0) revert INVALID_BPS();
        _validateFloors(maxEntryPremiumBps, maxExitDiscountBps);
        // R4-3: raising the NORMAL discount above an OPEN grace discount would invert them, leaving the
        // degraded exit tighter than the healthy one. Refuse rather than silently re-order; close or
        // retune the grace first.
        uint16 graceBps = _instruments[bondToken].emergencyExitDiscountBps;
        if (graceBps != 0 && maxExitDiscountBps > graceBps) revert INVALID_BPS();
        _instruments[bondToken].maxEntryPremiumBps = maxEntryPremiumBps;
        _instruments[bondToken].maxExitDiscountBps = maxExitDiscountBps;
        emit TradeFloorsUpdated(bondToken, maxEntryPremiumBps, maxExitDiscountBps);
    }

    /// @notice R4-3: open, retune or close the bounded exit grace for one instrument.
    /// @dev Pass (0, 0) to CLOSE it. That is the one zero this setter accepts, because closing an incident
    ///      control must stay possible — unlike `setTradeFloors`, where zero could only ever brick a leg.
    /// @dev Only widens a TIME window, never lowers the price reference. See the field NatSpec for why a
    ///      stale NAV cannot underprice this leg; the governed risk is `discountBps`, capped as elsewhere.
    /// @param bondToken The instrument
    /// @param maxPublicationAge Seconds of publication staleness a SELL may still price against; 0 = off
    /// @param discountBps The wider exit discount applying inside the window; 0 = off
    function setEmergencyExit(
        address bondToken,
        uint32 maxPublicationAge,
        uint16 discountBps
    )
        external
        onlyRole(INSTRUMENT_MANAGER_ROLE)
    {
        _requireRegistered(bondToken);
        // Both or neither. One without the other is a half-configured incident control: a window with no
        // discount still fails the normal floor, and a discount with no window never applies.
        if ((maxPublicationAge == 0) != (discountBps == 0)) revert INVALID_BPS();
        if (maxPublicationAge != 0) {
            if (maxPublicationAge > MAX_AGE_CEILING) revert INVALID_STALENESS();
            if (discountBps > MAX_TOLERANCE_BPS) revert INVALID_BPS();
            // A grace narrower than the normal discount is incoherent — it would make the degraded exit
            // HARDER to fill than the healthy one.
            if (discountBps < _instruments[bondToken].maxExitDiscountBps) revert INVALID_BPS();
        }
        _instruments[bondToken].emergencyExitMaxPublicationAge = maxPublicationAge;
        _instruments[bondToken].emergencyExitDiscountBps = discountBps;
        emit EmergencyExitUpdated(bondToken, maxPublicationAge, discountBps);
    }

    /// @dev Rejected rather than clamped, so a mis-set value is visible instead of silently narrowed.
    ///      The ceiling is `MAX_TOLERANCE_BPS`, not 100%: a floor computed from a 100% tolerance is
    ///      vacuous, and allowing it would let one ops transaction disable the F1 price protection.
    function _validateFloors(uint16 maxEntryPremiumBps, uint16 maxExitDiscountBps) private pure {
        if (maxEntryPremiumBps > MAX_TOLERANCE_BPS || maxExitDiscountBps > MAX_TOLERANCE_BPS) {
            revert INVALID_BPS();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           THE INCIDENT SWITCH
    //////////////////////////////////////////////////////////////*/

    /// @notice Stops or resumes valuation of an instrument. NOT timelocked, by design.
    /// @dev Use this for a credit event, a feed failure, or maturity. Suspension makes every value read revert
    ///      while identity reads (`decimals`, `getBalanceOfOwner`) keep working, so holdings stay visible and
    ///      only NAV-sensitive actions are blocked.
    function setNavSuspended(address bondToken, bool suspended) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        _requireRegistered(bondToken);
        _instruments[bondToken].navSuspended = suspended;
        emit NavSuspended(bondToken, suspended);
    }

    /*//////////////////////////////////////////////////////////////
                           TIMELOCKED CHANGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a terminal valuation override for default or maturity
    /// @dev A non-zero recovery NAV replaces the feed entirely. This is the "agree recovery behaviour rather
    ///      than assuming repayment at par" control: par is a choice someone must make explicitly, not a default.
    function proposeRecoveryNav(address bondToken, uint256 recoveryNav) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        _requireRegistered(bondToken);
        pendingRecoveryNav[bondToken] = recoveryNav;
        pendingRecoveryNavAt[bondToken] = block.timestamp + DEREGISTER_DELAY;
        emit RecoveryNavProposed(bondToken, recoveryNav, pendingRecoveryNavAt[bondToken]);
    }

    function executeRecoveryNav(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        // F5: a proposal must apply to a LIVE registration. Without this, a matured proposal could be
        // executed against a deregistered instrument, or inherited by a later re-registration.
        _requireRegistered(bondToken);
        uint256 executeAt = pendingRecoveryNavAt[bondToken];
        if (executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        uint256 value = pendingRecoveryNav[bondToken];
        _instruments[bondToken].recoveryNav = value;
        // F4: the flag, not the value, is what enables the override, so zero is a valid total loss.
        _instruments[bondToken].recoveryNavSet = true;
        delete pendingRecoveryNav[bondToken];
        delete pendingRecoveryNavAt[bondToken];
        // R2-1: a new recovery decision invalidates any outstanding clear. Without this, a clear proposed
        // and aged BEFORE a later impairment could be executed immediately afterwards and undo it.
        delete pendingClearRecoveryNavAt[bondToken];
        emit RecoveryNavSet(bondToken, value);
    }

    /// @notice F4: proposes removal of a terminal override, returning the instrument to its feed. A SEPARATE
    ///         action from recording a recovery of zero, which is a total loss and keeps the override in force.
    /// @dev R2-1: this carries the SAME delay as installing an override. The earlier reasoning — that
    ///      restoring the feed "cannot be used to install a number" — was wrong: the feed can hold a fresh,
    ///      in-bounds par value while the override records a credit impairment, so an immediate clear raises
    ///      the mark from the impaired figure to par in one transaction (40 -> 100 cash units in the
    ///      reproduction), and reopens the feed-based tradability path. Freshness and the circuit breaker
    ///      validate the feed's ordinary range, not whether it should supersede a recorded credit event.
    function proposeClearRecoveryNav(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        _requireRegistered(bondToken);
        if (!_instruments[bondToken].recoveryNavSet) revert RECOVERY_NOT_SET();
        pendingClearRecoveryNavAt[bondToken] = block.timestamp + DEREGISTER_DELAY;
        emit RecoveryNavClearProposed(bondToken, pendingClearRecoveryNavAt[bondToken]);
    }

    /// @notice Executes a matured clear proposal, returning the instrument to feed-based valuation.
    function executeClearRecoveryNav(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        // F5: a proposal must apply to a LIVE registration, so it cannot be inherited by a re-registration.
        _requireRegistered(bondToken);
        uint256 executeAt = pendingClearRecoveryNavAt[bondToken];
        if (executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        // Defence in depth: `executeRecoveryNav` already invalidates an outstanding clear, so a cleared or
        // re-impaired instrument cannot reach here with a stale proposal.
        if (!_instruments[bondToken].recoveryNavSet) revert RECOVERY_NOT_SET();
        _instruments[bondToken].recoveryNav = 0;
        _instruments[bondToken].recoveryNavSet = false;
        delete pendingClearRecoveryNavAt[bondToken];
        emit RecoveryNavCleared(bondToken);
    }

    /// @notice Withdraws a pending clear proposal, keeping the override in force.
    function cancelClearRecoveryNav(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        if (pendingClearRecoveryNavAt[bondToken] == 0) revert CHANGE_NOT_PENDING();
        delete pendingClearRecoveryNavAt[bondToken];
        emit RecoveryNavClearProposalCancelled(bondToken);
    }

    /// @notice F5: withdraws a pending recovery proposal. Re-proposing only restarts a clock; it is not
    ///         cancellation, and a stale matured proposal is executable forever without this.
    function cancelRecoveryNav(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        if (pendingRecoveryNavAt[bondToken] == 0) revert CHANGE_NOT_PENDING();
        delete pendingRecoveryNav[bondToken];
        delete pendingRecoveryNavAt[bondToken];
        emit RecoveryNavProposalCancelled(bondToken);
    }

    /// @notice F5: withdraws a pending feed change.
    function cancelFeedChange(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        if (pendingFeedAt[bondToken] == 0) revert CHANGE_NOT_PENDING();
        _clearPendingFeed(bondToken);
        emit FeedChangeProposalCancelled(bondToken);
    }

    /// @notice Proposes a change of the approved feed source
    /// @param minAnswer Circuit-breaker floor in the NEW feed's units; zero disables that side
    /// @param maxAnswer Circuit-breaker ceiling in the NEW feed's units; zero disables that side
    /// @dev F6: THE BOUNDS TRAVEL WITH THE FEED. A replacement whose `decimals()` differ needs bounds in its
    ///      own units. Previously only `navFeedScale` was refreshed, so an 8-decimal feed replaced by an
    ///      economically identical 18-decimal one left the old ceiling in place and tripped the circuit
    ///      breaker on every normal value, with no setter to repair it.
    function proposeFeedChange(
        address bondToken,
        address newFeed,
        uint8 kind,
        int192 minAnswer,
        int192 maxAnswer
    )
        external
        onlyRole(INSTRUMENT_MANAGER_ROLE)
    {
        _requireRegistered(bondToken);
        if (newFeed == address(0)) revert ZERO_ADDRESS();
        if (kind > FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();
        _validateBounds(minAnswer, maxAnswer);
        pendingFeed[bondToken] = newFeed;
        pendingFeedKind[bondToken] = kind;
        pendingFeedMinAnswer[bondToken] = minAnswer;
        pendingFeedMaxAnswer[bondToken] = maxAnswer;
        pendingFeedAt[bondToken] = block.timestamp + DEREGISTER_DELAY;
        emit FeedChangeProposed(bondToken, newFeed, kind, pendingFeedAt[bondToken]);
    }

    /// @notice Applies a proposed feed change and FORCE-SUSPENDS valuation as a side effect
    /// @dev The suspension is the point: a feed change must never silently re-point what a vault is marked at.
    ///      Resuming is a separate explicit `setNavSuspended(bondToken, false)`.
    function executeFeedChange(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        // F5: the proposal must apply to a live registration.
        _requireRegistered(bondToken);
        uint256 executeAt = pendingFeedAt[bondToken];
        if (executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();

        address newFeed = pendingFeed[bondToken];
        uint8 kind = pendingFeedKind[bondToken];
        InstrumentConfig storage cfg = _instruments[bondToken];
        if (cfg.requiresObservationTime && kind != FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();

        cfg.navFeed = newFeed;
        cfg.navFeedKind = kind;
        // F6: install the bounds the proposal carried, in the new feed's units.
        cfg.navMinAnswer = pendingFeedMinAnswer[bondToken];
        cfg.navMaxAnswer = pendingFeedMaxAnswer[bondToken];
        cfg.navSuspended = true;

        _clearPendingFeed(bondToken);

        _precomputeScales(bondToken);

        emit FeedChanged(bondToken, newFeed, kind);
        emit NavSuspended(bondToken, true);
    }

    /*//////////////////////////////////////////////////////////////
                             DEREGISTRATION
    //////////////////////////////////////////////////////////////*/

    function proposeDeregisterInstrument(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        _requireRegistered(bondToken);
        pendingDeregistration[bondToken] = block.timestamp + DEREGISTER_DELAY;
        emit InstrumentDeregistrationProposed(bondToken, pendingDeregistration[bondToken]);
    }

    function executeDeregisterInstrument(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        uint256 executeAt = pendingDeregistration[bondToken];
        if (executeAt == 0) revert DEREGISTRATION_NOT_PENDING();
        if (block.timestamp < executeAt) revert DEREGISTRATION_TIMELOCK_NOT_ELAPSED();
        delete _instruments[bondToken];
        delete pendingDeregistration[bondToken];
        // F5: clear every other pending change too. Previously a matured recovery or feed proposal survived
        // deregistration and could be executed against a LATER re-registration of the same bond token,
        // installing a value proposed for a configuration that no longer exists, with no fresh delay.
        _clearPendingFeed(bondToken);
        delete pendingRecoveryNav[bondToken];
        delete pendingRecoveryNavAt[bondToken];
        // R2-1: the clear proposal is pending state like any other and must not outlive the registration.
        delete pendingClearRecoveryNavAt[bondToken];
        emit PendingChangesCleared(bondToken);
        emit InstrumentDeregistered(bondToken);
    }

    function cancelDeregisterInstrument(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        if (pendingDeregistration[bondToken] == 0) revert DEREGISTRATION_NOT_PENDING();
        delete pendingDeregistration[bondToken];
        emit InstrumentDeregistrationCancelled(bondToken);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full configuration for a registered instrument
    /// @dev Reverts for an unregistered instrument: no zero-valued fallback, ever.
    function getInstrumentConfig(address bondToken) external view returns (InstrumentConfig memory) {
        _requireRegistered(bondToken);
        return _instruments[bondToken];
    }

    /// @notice Whether an instrument is registered. NEVER reverts.
    /// @dev The guard hook and `previewNav` rely on this being total.
    function isRegistered(address bondToken) external view returns (bool) {
        return _instruments[bondToken].registered;
    }

    /// @notice Whether `cashToken` is the configured cash denomination for `bondToken`. NEVER reverts.
    function isApprovedPair(address bondToken, address cashToken) external view returns (bool) {
        InstrumentConfig storage cfg = _instruments[bondToken];
        return cfg.registered && cfg.cashToken == cashToken;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _clearPendingFeed(address bondToken) private {
        delete pendingFeed[bondToken];
        delete pendingFeedKind[bondToken];
        delete pendingFeedMinAnswer[bondToken];
        delete pendingFeedMaxAnswer[bondToken];
        delete pendingFeedAt[bondToken];
    }

    function _requireRegistered(address bondToken) private view {
        if (!_instruments[bondToken].registered) revert INSTRUMENT_NOT_REGISTERED();
    }

    function _validateAges(uint256 maxObservationAge, uint256 maxPublicationAge) private pure {
        // Zero would make every read revert; the ceiling stops a signing mistake authorising a year-old NAV.
        if (maxObservationAge == 0 || maxPublicationAge == 0) revert INVALID_STALENESS();
        if (maxObservationAge > MAX_AGE_CEILING || maxPublicationAge > MAX_AGE_CEILING) revert INVALID_STALENESS();
    }

    function _precomputeScales(address bondToken) private {
        InstrumentConfig storage cfg = _instruments[bondToken];
        cfg.bondScale = 10 ** IERC20Metadata(cfg.bondToken).decimals();
        cfg.cashScale = 10 ** IERC20Metadata(cfg.cashToken).decimals();
        cfg.navFeedScale = 10 ** IGyldFeedDecimals(cfg.navFeed).decimals();
        cfg.cashFeedScale = cfg.cashFeed == address(0) ? 0 : 10 ** IGyldFeedDecimals(cfg.cashFeed).decimals();
    }
}

/// @dev Both feed kinds expose `decimals()`; this avoids importing two interfaces for one selector.
interface IGyldFeedDecimals {
    function decimals() external view returns (uint8);
}
