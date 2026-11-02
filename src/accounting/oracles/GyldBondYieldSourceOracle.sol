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
        CASH_FEED_FAILED
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

        // A terminal override short-circuits the feed entirely: default or maturity is a decided number.
        if (cfg.recoveryNav != 0) {
            status.nav = cfg.recoveryNav;
            status.observedAt = block.timestamp;
            status.publishedAt = block.timestamp;
            status.failureCode = uint8(NavFailure.OK);
            return status;
        }
        if (cfg.navSuspended) {
            status.failureCode = uint8(NavFailure.SUSPENDED);
            return status;
        }

        (uint256 nav, uint256 observedAt, uint256 publishedAt, NavFailure failure) = _tryNav(cfg);
        status.nav = failure == NavFailure.OK ? nav : 0;
        status.observedAt = observedAt;
        status.publishedAt = publishedAt;
        status.failureCode = uint8(failure);
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
        return assetsIn.mulDiv(cfg.bondScale, _nav(cfg), Math.Rounding.Floor);
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
        return assetsIn.mulDiv(cfg.bondScale, _nav(cfg), Math.Rounding.Ceil);
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
        if (cfg.recoveryNav != 0) return cfg.recoveryNav;
        if (cfg.navSuspended) revert NAV_SUSPENDED();
        (uint256 nav,,, NavFailure failure) = _tryNav(cfg);
        if (failure != NavFailure.OK) _revertFor(failure);
        return nav;
    }

    /// @dev Maps a diagnostic failure code onto its named revert, so the strict and diagnostic paths share one
    ///      source of truth about what each condition means.
    function _revertFor(NavFailure failure) private pure {
        if (failure == NavFailure.PUBLICATION_STALE) revert STALE_PRICE();
        if (failure == NavFailure.OBSERVATION_STALE) revert STALE_OBSERVATION();
        if (failure == NavFailure.OBSERVATION_UNAVAILABLE) revert OBSERVATION_TIME_UNAVAILABLE();
        if (failure == NavFailure.SEQUENCER_DOWN_CODE) revert SEQUENCER_DOWN();
        if (failure == NavFailure.NOT_REGISTERED) revert INSTRUMENT_NOT_REGISTERED();
        if (failure == NavFailure.SUSPENDED) revert NAV_SUSPENDED();
        revert INVALID_PRICE();
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
        if (!_sequencerOk(cfg)) return (0, 0, 0, NavFailure.SEQUENCER_DOWN_CODE);

        uint256 rawNav;
        (rawNav, observedAt, publishedAt, failure) = _readNavFeed(cfg);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);

        failure = _checkFreshness(cfg, observedAt, publishedAt);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);

        (nav, failure) = _toCashUnits(cfg, rawNav);
        if (failure != NavFailure.OK) return (0, observedAt, publishedAt, failure);
        if (nav == 0) return (0, observedAt, publishedAt, NavFailure.ZERO_OR_NEGATIVE);
    }

    /// @dev True when there is no sequencer feed, or the sequencer is up and past its grace period
    function _sequencerOk(GyldBondRegistry.InstrumentConfig memory cfg) private view returns (bool) {
        if (cfg.sequencerUptimeFeed == address(0)) return true;
        (, int256 answer,, uint256 startedAt,) = IAggregatorV3(cfg.sequencerUptimeFeed).latestRoundData();
        if (answer != 0) return false;
        return block.timestamp - startedAt >= cfg.gracePeriod;
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
        if (block.timestamp > publishedAt && block.timestamp - publishedAt > cfg.maxPublicationAge) {
            return NavFailure.PUBLICATION_STALE;
        }
        if (cfg.requiresObservationTime && observedAt == 0) return NavFailure.OBSERVATION_UNAVAILABLE;
        if (observedAt != 0) {
            // A valuation dated in the future is not fresh, it is wrong.
            if (observedAt > block.timestamp) return NavFailure.ZERO_OR_NEGATIVE;
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
        if (block.timestamp > updatedAt && block.timestamp - updatedAt > cfg.maxPublicationAge) {
            return (0, NavFailure.CASH_FEED_FAILED);
        }
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
