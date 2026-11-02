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

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant INSTRUMENT_MANAGER_ROLE = keccak256("INSTRUMENT_MANAGER_ROLE");

    /// @notice Delay on changes that alter what a holding is worth
    uint256 public constant DEREGISTER_DELAY = 2 days;

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
        uint256 recoveryNav;
        bool registered;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address bondToken => InstrumentConfig config) private _instruments;
    mapping(address bondToken => uint256 executeAt) public pendingDeregistration;
    mapping(address bondToken => uint256 executeAt) public pendingRecoveryNavAt;
    mapping(address bondToken => uint256 value) public pendingRecoveryNav;
    mapping(address bondToken => uint256 executeAt) public pendingFeedAt;
    mapping(address bondToken => address feed) public pendingFeed;
    mapping(address bondToken => uint8 kind) public pendingFeedKind;

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
    event FeedChangeProposed(address indexed bondToken, address indexed newFeed, uint8 kind, uint256 executeAt);
    event FeedChanged(address indexed bondToken, address indexed newFeed, uint8 kind);
    event CircuitBreakerBoundsRefreshed(address indexed bondToken);
    event StalenessBoundsUpdated(address indexed bondToken, uint256 maxObservationAge, uint256 maxPublicationAge);

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
        stored.registered = true;
        // Deliberately NOT copied from the caller: an instrument is never born suspended or with a recovery NAV.
        stored.navSuspended = false;
        stored.recoveryNav = 0;

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
        uint256 executeAt = pendingRecoveryNavAt[bondToken];
        if (executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        uint256 value = pendingRecoveryNav[bondToken];
        _instruments[bondToken].recoveryNav = value;
        delete pendingRecoveryNav[bondToken];
        delete pendingRecoveryNavAt[bondToken];
        emit RecoveryNavSet(bondToken, value);
    }

    /// @notice Proposes a change of the approved feed source
    function proposeFeedChange(
        address bondToken,
        address newFeed,
        uint8 kind
    )
        external
        onlyRole(INSTRUMENT_MANAGER_ROLE)
    {
        _requireRegistered(bondToken);
        if (newFeed == address(0)) revert ZERO_ADDRESS();
        if (kind > FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();
        pendingFeed[bondToken] = newFeed;
        pendingFeedKind[bondToken] = kind;
        pendingFeedAt[bondToken] = block.timestamp + DEREGISTER_DELAY;
        emit FeedChangeProposed(bondToken, newFeed, kind, pendingFeedAt[bondToken]);
    }

    /// @notice Applies a proposed feed change and FORCE-SUSPENDS valuation as a side effect
    /// @dev The suspension is the point: a feed change must never silently re-point what a vault is marked at.
    ///      Resuming is a separate explicit `setNavSuspended(bondToken, false)`.
    function executeFeedChange(address bondToken) external onlyRole(INSTRUMENT_MANAGER_ROLE) {
        uint256 executeAt = pendingFeedAt[bondToken];
        if (executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();

        address newFeed = pendingFeed[bondToken];
        uint8 kind = pendingFeedKind[bondToken];
        InstrumentConfig storage cfg = _instruments[bondToken];
        if (cfg.requiresObservationTime && kind != FEED_KIND_GYLD_NATIVE) revert INVALID_FEED_KIND();

        cfg.navFeed = newFeed;
        cfg.navFeedKind = kind;
        cfg.navSuspended = true;

        delete pendingFeed[bondToken];
        delete pendingFeedKind[bondToken];
        delete pendingFeedAt[bondToken];

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
