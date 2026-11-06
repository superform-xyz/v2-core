// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { GyldBondRegistry } from "./GyldBondRegistry.sol";
import { IGyldNavFeed } from "../../vendor/gyld/IGyldNavFeed.sol";

/// @title GyldBondYieldSourceOracle
/// @author Superform Labs
/// @notice Values Gyld tokenized bonds at COMPLETE NAV, expressed in the instrument's cash denomination.
/// @dev `yieldSourceAddress` IS the bond token. The share model is identity: one share is one bond token, and
///      the "asset" is the instrument's configured `cashToken`.
/// @dev COMPLETE NAV is the bond token's accounting value INCLUDING coupon accrual, coupon-pool amounts and
///      accrued fees. It is the feed's job to represent that; this contract cannot verify it and must not be
///      pointed at a catalog price or an executable quote. See `IGyldNavFeed`.
/// @dev THE STALENESS SPLIT, which is the whole design. The brief requires that a missing or stale price blocks
///      unsupported valuations and new NAV-sensitive actions WHILE PRESERVING VISIBLE HOLDINGS. A blanket revert
///      would also break price-per-share publication and withdrawals, which is not what is wanted. So:
///        - IDENTITY reads never revert: `decimals`, `getBalanceOfOwner`, `previewNav`. Holdings stay visible
///          and a suspended instrument still shows its balance.
///        - VALUE reads always revert when the price is unsupported: `getPricePerShare`, `getAssetOutput`,
///          `getShareOutput`, `getWithdrawalShareOutput`, `getTVLByOwnerOfShares`, `getTVL`.
///        - The inherited `getTVLByOwnerOfSharesMultiple` already converts a per-item revert into a `succeeded`
///          flag, so the pricing pipeline declines to publish rather than publishing a wrong number.
///        - `previewNav` returns a non-reverting status with a `failureCode`, so the guard hook and the OMS get
///          an actionable reason without decoding a revert.
/// @dev FEES ARE BYPASSED, exactly as `ERC20YieldSourceOracle` does. This oracle MUST be configured with
///      `feePercent = 0` and `FlatFeeLedger` is categorically forbidden: a bond's coupon accrual is not
///      performance yield and must never be charged as such. Combined with NONACCOUNTING trade hooks, the
///      ledger never touches this oracle, so a suspended instrument cannot brick accounting.
/// @dev NEVER ASSUMES CASH EQUALS ONE DOLLAR. A USD-denominated NAV feed is converted through the instrument's
///      cash/USD feed, and that feed is staleness-checked just as strictly as the NAV feed.
contract GyldBondYieldSourceOracle is AbstractYieldSourceOracle {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error INSTRUMENT_NOT_REGISTERED();
    error NAV_SUSPENDED();
    error INVALID_PRICE();
    error STALE_PRICE();
    error STALE_OBSERVATION();
    error OBSERVATION_TIME_UNAVAILABLE();
    error FUTURE_OBSERVATION();
    error SEQUENCER_DOWN();
    error GRACE_PERIOD_NOT_OVER();
    /// @notice A feed reported a zero or future timestamp
    error INVALID_TIMESTAMP();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Why a NAV read would fail, without having to decode a revert
    enum NavFailure {
        OK,
        NOT_REGISTERED,
        SUSPENDED,
        PUBLICATION_STALE,
        OBSERVATION_STALE,
        OBSERVATION_UNAVAILABLE,
        CIRCUIT_BREAKER,
        SEQUENCER_DOWN_CODE,
        ZERO_OR_NEGATIVE,
        CASH_FEED_FAILED,
        /// @notice A clock reported zero or a time in the future. Not stale, WRONG. (F3)
        INVALID_TIMESTAMP,
        /// @notice The sequencer is up but still inside its grace period, as distinct from being down. (F7)
        GRACE_PERIOD
    }

    /// @notice Non-reverting NAV status for the guard hook and the OMS
    /// @param nav Complete NAV of one whole bond token, in cash-token units. Zero when unusable.
    /// @param observedAt Issuer valuation instant; zero when the feed cannot express it
    /// @param publishedAt On-chain publication instant
    /// @param suspended Whether governance has stopped valuation
    /// @param registered Whether the instrument is known at all
    /// @param cashToken The configured cash denomination
    /// @param navFeed The approved feed source
    /// @param failureCode `NavFailure` as a uint8; `OK` means every value read would succeed right now
    struct NavStatus {
        uint256 nav;
        uint256 observedAt;
        uint256 publishedAt;
        bool suspended;
        bool registered;
        address cashToken;
        address navFeed;
        uint8 failureCode;
    }

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The approved-instrument list. The only source of feeds and cash denominations.
    GyldBondRegistry public immutable REGISTRY;

    /// @dev Mirrors `GyldBondRegistry.FEED_KIND_GYLD_NATIVE`. A contract's `public constant` is not statically
    ///      reachable from another contract, and reading it through an external call on every valuation would be
    ///      wasteful, so the value is mirrored here and the two are asserted equal in the unit tests.
    uint8 private constant FEED_KIND_GYLD_NATIVE = 1;

    constructor(
        address superLedgerConfiguration_,
        address registry_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = GyldBondRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                         IDENTITY READS — NEVER REVERT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identity read: the bond token's own decimals. Never consults a feed.
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IERC20Metadata(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identity read, and the "preserve visible holdings" escape hatch: a suspended, stale or
    ///      unregistered instrument still reports the balance a strategy holds.
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @notice Non-reverting NAV status
    /// @dev Reverts for nothing. An unregistered instrument comes back with `registered == false` rather than a
    ///      revert, so the guard hook can produce a precise error and the OMS can pre-flight a leaf.
    function previewNav(address bondToken) external view returns (NavStatus memory status) {
        if (!REGISTRY.isRegistered(bondToken)) {
            status.failureCode = uint8(NavFailure.NOT_REGISTERED);
            return status;
        }
        GyldBondRegistry.InstrumentConfig memory cfg = REGISTRY.getInstrumentConfig(bondToken);
        status.registered = true;
        status.suspended = cfg.navSuspended;
        status.cashToken = cfg.cashToken;
        status.navFeed = cfg.navFeed;

        // F2: SUSPENSION FIRST, BEFORE THE OVERRIDE. The incident switch is the one control that must
        // always work; previously a non-zero recovery NAV short-circuited ahead of it, so an instrument
        // could report `suspended == true` and `failureCode == OK` at the same time and the guard would
        // authorise a trade on it. Reporting a recovery value while suspended is the caller's business via
        // `recoveryNav` on the config; this status must never say "tradable".
        if (cfg.navSuspended) {
            status.failureCode = uint8(NavFailure.SUSPENDED);
            return status;
        }
        // A terminal override short-circuits the feed entirely: default or maturity is a decided number.
        if (cfg.recoveryNavSet) {
            status.nav = cfg.recoveryNav;
            status.observedAt = block.timestamp;
            status.publishedAt = block.timestamp;
            // F4: a recovery of ZERO is a total loss. The holding stays VISIBLE and values at zero on the
            // asset side, but it is not a tradable price, so the status says so and the guard refuses.
            status.failureCode = cfg.recoveryNav == 0 ? uint8(NavFailure.ZERO_OR_NEGATIVE) : uint8(NavFailure.OK);
            return status;
        }

        (uint256 nav, uint256 observedAt, uint256 publishedAt, NavFailure failure) = _tryNav(cfg);
        status.nav = failure == NavFailure.OK ? nav : 0;
        status.observedAt = observedAt;
        status.publishedAt = publishedAt;
        status.failureCode = uint8(failure);
    }

    /// @notice R4-3: the feed value WITHOUT the usability verdict applied, for the bounded exit grace.
    /// @dev NEVER USE THIS TO VALUE A HOLDING, and never treat a non-zero `nav` here as tradable.
    ///      `previewNav` zeroes `nav` for every non-OK code precisely so a caller cannot accidentally
    ///      price against an unusable number, and the whole policy depends on that. This exists because
    ///      `GyldTradePolicy`'s exit grace needs the LAST GOOD value on a leg where staleness is
    ///      conservative (the SELL floor rises with nav, so a stale reference blocks rather than
    ///      underprices). Any caller must check `failureCode` and decide deliberately.
    /// @dev Additive on purpose: changing `previewNav`'s zeroing would alter the meaning of every existing
    ///      consumer, including the guard hook and the OMS pre-flight.
    /// @param bondToken The instrument
    /// @return nav Feed-derived NAV in cash units, NOT zeroed on failure
    /// @return observedAt Observation time, 0 when the feed cannot express one
    /// @return publishedAt Publication time
    /// @return failureCode The verdict the caller MUST still apply
    function previewNavRaw(address bondToken)
        external
        view
        returns (uint256 nav, uint256 observedAt, uint256 publishedAt, uint8 failureCode)
    {
        if (!REGISTRY.isRegistered(bondToken)) return (0, 0, 0, uint8(NavFailure.NOT_REGISTERED));
        GyldBondRegistry.InstrumentConfig memory cfg = REGISTRY.getInstrumentConfig(bondToken);
        // Suspension is governance stating the number is unusable, so no feed value leaves here at all —
        // the exit grace must not be able to reach around an explicit incident switch.
        if (cfg.navSuspended) return (0, 0, 0, uint8(NavFailure.SUSPENDED));
        if (cfg.recoveryNavSet) {
            return (
                cfg.recoveryNav,
                block.timestamp,
                block.timestamp,
                cfg.recoveryNav == 0 ? uint8(NavFailure.ZERO_OR_NEGATIVE) : uint8(NavFailure.OK)
            );
        }
        // Composed here rather than delegated to `_tryNav`, which zeroes `nav` on a freshness failure
        // before returning and converts to cash units only AFTER that check — so it can never hand back a
        // last-good value. The order below is deliberate and must not be rearranged:
        NavFailure failure = _sequencerStatus(cfg);
        // 1. A down or grace-period sequencer invalidates every feed beneath it. Never graced.
        if (failure != NavFailure.OK) return (0, 0, 0, uint8(failure));

        uint256 rawNav;
        (rawNav, observedAt, publishedAt, failure) = _readNavFeed(cfg);
        // 2. A feed that cannot be read at all has no last-good value to offer.
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, uint8(failure));

        // 3. Record the clock verdict but do NOT return on it — that verdict is the whole point of this
        //    function, and the caller decides whether its grace covers it.
        NavFailure freshness = _checkFreshness(cfg, observedAt, publishedAt);

        // 4. Convert REGARDLESS of the clock. Note what this means and why it is right: the bond's LAST
        //    PUBLISHED nav is expressed at TODAY's cash price. The stale thing is the instrument's
        //    valuation, not the denomination, so re-denominating at the live cash rate is more accurate
        //    than carrying a stale cash rate alongside it.
        (nav, failure) = _toCashUnits(cfg, rawNav);
        // 5. VALUE failures still outrank the clock: a dead cash feed means no usable number exists.
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, uint8(failure));
        if (nav == 0) return (0, observedAt, publishedAt, uint8(NavFailure.ZERO_OR_NEGATIVE));

        failureCode = uint8(freshness);
    }

    /*//////////////////////////////////////////////////////////////
                          VALUE READS — REVERT ON STALE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Complete NAV of one whole bond token, in cash-token units
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return _nav(_config(yieldSourceAddress));
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Rounds DOWN: value out of the vault is never overstated.
    function getAssetOutput(
        address yieldSourceAddress,
        address assetOut,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        GyldBondRegistry.InstrumentConfig memory cfg = _config(yieldSourceAddress);
        // address(0) is the "whatever the configured cash is" convention used across the oracle family.
        if (assetOut != address(0) && assetOut != cfg.cashToken) revert INVALID_BASE_ASSET();
        return sharesIn.mulDiv(_nav(cfg), cfg.bondScale, Math.Rounding.Floor);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Rounds DOWN: shares credited for a deposit are never overstated.
    function getShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        public
        view
        override
        returns (uint256)
    {
        GyldBondRegistry.InstrumentConfig memory cfg = _config(yieldSourceAddress);
        if (assetIn != address(0) && assetIn != cfg.cashToken) revert INVALID_BASE_ASSET();
        uint256 nav = _nav(cfg);
        // F4: a total-loss recovery value is a legitimate mark but not a legitimate divisor.
        if (nav == 0) revert INVALID_PRICE();
        return assetsIn.mulDiv(cfg.bondScale, nav, Math.Rounding.Floor);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Rounds UP: a withdrawal burns at least enough shares, favouring the vault over the withdrawer.
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        public
        view
        override
        returns (uint256)
    {
        GyldBondRegistry.InstrumentConfig memory cfg = _config(yieldSourceAddress);
        if (assetIn != address(0) && assetIn != cfg.cashToken) revert INVALID_BASE_ASSET();
        uint256 nav = _nav(cfg);
        if (nav == 0) revert INVALID_PRICE();
        return assetsIn.mulDiv(cfg.bondScale, nav, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Short-circuits to zero on a zero balance BEFORE touching any feed, so a strategy holding none of a
    ///      suspended instrument is still priceable. Same precedent as the UniV3 CLP oracle.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 balance = IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
        if (balance == 0) return 0;
        GyldBondRegistry.InstrumentConfig memory cfg = _config(yieldSourceAddress);
        return balance.mulDiv(_nav(cfg), cfg.bondScale, Math.Rounding.Floor);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev GLOBAL, MONITORING ONLY. Never a pricing input for any single strategy; total supply spans every
    ///      holder on the chain. Same caveat as `ERC20YieldSourceOracle.getTVL`.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        GyldBondRegistry.InstrumentConfig memory cfg = _config(yieldSourceAddress);
        return IERC20(yieldSourceAddress).totalSupply().mulDiv(_nav(cfg), cfg.bondScale, Math.Rounding.Floor);
    }

    /// @notice Asset output ignoring performance fees
    /// @dev FEES BYPASSED, deliberately and identically to `ERC20YieldSourceOracle`. Coupon accrual is not
    ///      performance yield. This oracle must be registered with `feePercent = 0`.
    function getAssetOutputWithFees(
        bytes32,
        address yieldSourceAddress,
        address assetOut,
        address,
        uint256 usedShares
    )
        external
        view
        override
        returns (uint256)
    {
        return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _config(address bondToken) private view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        if (!REGISTRY.isRegistered(bondToken)) revert INSTRUMENT_NOT_REGISTERED();
        cfg = REGISTRY.getInstrumentConfig(bondToken);
    }

    /// @notice Reverting NAV read, in cash-token units per whole bond token
    function _nav(GyldBondRegistry.InstrumentConfig memory cfg) private view returns (uint256) {
        // F2: suspension takes precedence over the override. See `previewNav`.
        if (cfg.navSuspended) revert NAV_SUSPENDED();
        // F4: an explicit flag, NOT `recoveryNav != 0`, so a total loss (zero) is representable.
        if (cfg.recoveryNavSet) return cfg.recoveryNav;
        (uint256 nav,,, NavFailure failure) = _tryNav(cfg);
        if (failure != NavFailure.OK) _revertFor(failure);
        return nav;
    }

    /// @dev Maps a diagnostic failure code onto its named revert, so the strict and diagnostic paths share one
    ///      source of truth about what each condition means.
    function _revertFor(NavFailure failure) private pure {
        _revertForClock(failure);
        if (failure == NavFailure.SEQUENCER_DOWN_CODE) revert SEQUENCER_DOWN();
        if (failure == NavFailure.GRACE_PERIOD) revert GRACE_PERIOD_NOT_OVER();
        if (failure == NavFailure.NOT_REGISTERED) revert INSTRUMENT_NOT_REGISTERED();
        if (failure == NavFailure.SUSPENDED) revert NAV_SUSPENDED();
        revert INVALID_PRICE();
    }

    /// @dev The freshness half of the mapping, split out to keep each function inside the complexity budget
    function _revertForClock(NavFailure failure) private pure {
        if (failure == NavFailure.PUBLICATION_STALE) revert STALE_PRICE();
        if (failure == NavFailure.OBSERVATION_STALE) revert STALE_OBSERVATION();
        if (failure == NavFailure.OBSERVATION_UNAVAILABLE) revert OBSERVATION_TIME_UNAVAILABLE();
        if (failure == NavFailure.INVALID_TIMESTAMP) revert INVALID_TIMESTAMP();
    }

    /// @notice Non-reverting NAV computation shared by `previewNav` and `_nav`
    /// @dev Split into staged helpers so each stage stays readable: liveness, then the feed read, then the two
    ///      freshness clocks, then denomination. Returns a `NavFailure` instead of reverting so one code path
    ///      serves both the strict and the diagnostic caller.
    function _tryNav(GyldBondRegistry.InstrumentConfig memory cfg)
        private
        view
        returns (uint256 nav, uint256 observedAt, uint256 publishedAt, NavFailure failure)
    {
        // L2 liveness first: a down sequencer makes every feed below untrustworthy.
        failure = _sequencerStatus(cfg);
        if (failure != NavFailure.OK) return (0, 0, 0, failure);

        uint256 rawNav;
        (rawNav, observedAt, publishedAt, failure) = _readNavFeed(cfg);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);

        failure = _checkFreshness(cfg, observedAt, publishedAt);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);

        (nav, failure) = _toCashUnits(cfg, rawNav);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);
        if (nav == 0) return (0, observedAt, publishedAt, NavFailure.ZERO_OR_NEGATIVE);
    }

    /// @dev F7: L2 liveness. Reads the THIRD return value, `startedAt`, which is the status TRANSITION
    ///      time, per Chainlink's own L2 sequencer consumer example. The fourth value is `updatedAt`, the
    ///      round's publication time: a feed that refreshed recently after being up for a long time would
    ///      wrongly fail the grace check if `updatedAt` were used. Other oracles in this repo read the
    ///      fourth value; that does not make it right here.
    /// @dev Zero is Chainlink's signal for a round that has not started, so it is rejected rather than read
    ///      as an ancient healthy timestamp, and a future transition time is rejected rather than panicking
    ///      on the subtraction.
    /// @return failure `OK`, `SEQUENCER_DOWN_CODE`, `GRACE_PERIOD` or `INVALID_TIMESTAMP`
    function _sequencerStatus(GyldBondRegistry.InstrumentConfig memory cfg) private view returns (NavFailure) {
        if (cfg.sequencerUptimeFeed == address(0)) return NavFailure.OK;
        (, int256 answer, uint256 startedAt,,) = IAggregatorV3(cfg.sequencerUptimeFeed).latestRoundData();
        // answer == 0: sequencer up, answer == 1: sequencer down
        if (answer != 0) return NavFailure.SEQUENCER_DOWN_CODE;
        if (startedAt == 0 || startedAt > block.timestamp) return NavFailure.INVALID_TIMESTAMP;
        if (block.timestamp - startedAt < cfg.gracePeriod) return NavFailure.GRACE_PERIOD;
        return NavFailure.OK;
    }

    /// @dev Reads the approved feed per its kind. A Chainlink-style feed returns `observedAt == 0`, because it
    ///      exposes only the publication clock.
    function _readNavFeed(GyldBondRegistry.InstrumentConfig memory cfg)
        private
        view
        returns (uint256 rawNav, uint256 observedAt, uint256 publishedAt, NavFailure failure)
    {
        if (cfg.navFeedKind == FEED_KIND_GYLD_NATIVE) {
            (rawNav, observedAt, publishedAt) = IGyldNavFeed(cfg.navFeed).latestNav(cfg.bondToken);
            if (rawNav == 0) return (0, observedAt, publishedAt, NavFailure.ZERO_OR_NEGATIVE);
            if (_outsideBounds(int256(rawNav), cfg.navMinAnswer, cfg.navMaxAnswer)) {
                return (0, observedAt, publishedAt, NavFailure.CIRCUIT_BREAKER);
            }
            return (rawNav, observedAt, publishedAt, NavFailure.OK);
        }

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            IAggregatorV3(cfg.navFeed).latestRoundData();
        if (answer <= 0) return (0, 0, updatedAt, NavFailure.ZERO_OR_NEGATIVE);
        if (answeredInRound < roundId) return (0, 0, updatedAt, NavFailure.PUBLICATION_STALE);
        if (_outsideBounds(answer, cfg.navMinAnswer, cfg.navMaxAnswer)) {
            return (0, 0, updatedAt, NavFailure.CIRCUIT_BREAKER);
        }
        return (uint256(answer), 0, updatedAt, NavFailure.OK);
    }

    /// @dev The two clocks. `maxPublicationAge` bounds how long ago the number reached this chain;
    ///      `maxObservationAge` bounds how old the issuer's valuation itself is. A fresh publication of a stale
    ///      valuation must not pass, which is the whole reason both are tracked.
    function _checkFreshness(
        GyldBondRegistry.InstrumentConfig memory cfg,
        uint256 observedAt,
        uint256 publishedAt
    )
        private
        view
        returns (NavFailure)
    {
        // F3: a zero or FUTURE publication time is not age zero, it is unusable data. Previously the age
        // comparison was simply skipped when `publishedAt >= block.timestamp`, so a feed stamped ahead of
        // the chain bypassed the staleness bound entirely for as long as the stamp stayed in the future.
        if (publishedAt == 0 || publishedAt > block.timestamp) return NavFailure.INVALID_TIMESTAMP;
        if (block.timestamp - publishedAt > cfg.maxPublicationAge) return NavFailure.PUBLICATION_STALE;

        if (cfg.requiresObservationTime && observedAt == 0) return NavFailure.OBSERVATION_UNAVAILABLE;
        if (observedAt != 0) {
            // A valuation dated in the future is not fresh, it is wrong.
            if (observedAt > block.timestamp) return NavFailure.INVALID_TIMESTAMP;
            if (block.timestamp - observedAt > cfg.maxObservationAge) return NavFailure.OBSERVATION_STALE;
        }
        return NavFailure.OK;
    }

    /// @dev Converts a raw feed answer into cash-token units. NEVER assumes the cash token is worth one dollar:
    ///      a USD-denominated NAV is divided by the instrument's cash/USD feed, which is staleness-checked and
    ///      bounds-checked just as strictly as the NAV feed itself.
    function _toCashUnits(
        GyldBondRegistry.InstrumentConfig memory cfg,
        uint256 rawNav
    )
        private
        view
        returns (uint256 nav, NavFailure failure)
    {
        if (!cfg.navIsUsdDenominated) {
            // Feed already quotes NAV in cash terms; only rescale to the cash token's decimals.
            return (rawNav.mulDiv(cfg.cashScale, cfg.navFeedScale, Math.Rounding.Floor), NavFailure.OK);
        }

        (uint80 round, int256 answer,, uint256 updatedAt, uint80 answeredIn) =
            IAggregatorV3(cfg.cashFeed).latestRoundData();
        if (answer <= 0 || answeredIn < round) return (0, NavFailure.CASH_FEED_FAILED);
        // F3: same rule as the NAV clock. A cash feed stamped in the future is unusable, not fresh, and it
        // sits in the DENOMINATOR, so accepting it is the most damaging version of this bug.
        if (updatedAt == 0 || updatedAt > block.timestamp) return (0, NavFailure.INVALID_TIMESTAMP);
        if (block.timestamp - updatedAt > cfg.maxPublicationAge) return (0, NavFailure.CASH_FEED_FAILED);
        if (_outsideBounds(answer, cfg.cashMinAnswer, cfg.cashMaxAnswer)) {
            return (0, NavFailure.CASH_FEED_FAILED);
        }
        nav = rawNav.mulDiv(cfg.cashFeedScale * cfg.cashScale, cfg.navFeedScale * uint256(answer), Math.Rounding.Floor);
        failure = NavFailure.OK;
    }

    /// @dev Circuit breaker. A zero bound means that side is disabled.
    function _outsideBounds(int256 answer, int192 minAnswer, int192 maxAnswer) private pure returns (bool) {
        if (minAnswer > 0 && answer <= int256(minAnswer)) return true;
        if (maxAnswer > 0 && answer >= int256(maxAnswer)) return true;
        return false;
    }
}
