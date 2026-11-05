// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { GyldBondRegistry } from "./GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "./GyldBondYieldSourceOracle.sol";
import { IGyldTradePolicy } from "../../interfaces/accounting/IGyldTradePolicy.sol";
import { ISuperVaultStrategyState } from "../../interfaces/ISuperVaultStrategyState.sol";

/// @title GyldTradePolicy
/// @author Superform Labs
/// @notice Decides whether a Gyld bond trade may proceed, and whether the price it got was acceptable.
/// @dev THE F1 FIX. `ApproveAndTradeGyldBondHook` calls `validateTrade` from its own `_preExecute` and
///      `validateFill` from its own `_postExecute`. Because `BaseHook.build` always emits both executions
///      and reverts `INCOMPLETE_HOOK_EXECUTION` unless both ran, these checks cannot be omitted by a leaf
///      author the way the separate `GyldTradeGuardHook` leaf could be.
/// @dev NOT A HOOK, AND DELIBERATELY NOT UNDER `src/hooks/`. `tooling/generate_hook_manifest.py` discovers
///      hooks by rglobbing `*Hook.sol` under `src/hooks/` and the manifest lint fails any discovered file
///      absent from `hook-classification.yaml`. This directory already hosts non-oracles for the same
///      reason: `GyldBondRegistry`, `AaveV4ReserveRegistryV2`, `MorphoBlueMarketRegistry`, `UniV3CLPRegistry`.
/// @dev NO STORAGE, NO ROLES, NO OWNER. Every knob is either an immutable here or per-instrument state on
///      `GyldBondRegistry`, which already has `INSTRUMENT_MANAGER_ROLE` and timelocks. A second governable
///      surface would be a second fail-open vector.
/// @dev WHY IT READS THE REGISTRY DIRECTLY AND NOT ONLY THE ORACLE. `previewNav` returns
///      `nav == 0, failureCode == SUSPENDED` for a suspended instrument and returns BEFORE consulting the
///      recovery override, and `NavStatus` carries no `recoveryNavSet` field — so through the oracle alone a
///      governance recovery mark is indistinguishable from a fresh feed price, and a distressed exit mark is
///      unobtainable. The registry read is mandatory, not a convenience.
contract GyldTradePolicy is IGyldTradePolicy {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ADDRESS_NOT_VALID();
    error REGISTRY_MISMATCH();
    error INSTRUMENT_NOT_REGISTERED();
    error CASH_DENOMINATION_MISMATCH();
    error NAV_SUSPENDED();
    /// @notice BUY into an instrument carrying a terminal governance mark is never authorised
    error RECOVERY_MARK_SET();
    /// @notice SELL of a suspended or unusable instrument with no recovery mark published: there is no
    ///         on-chain number against which an exit price could be judged, so the exit must wait for one.
    error NO_EXIT_MARK();
    error NAV_PUBLICATION_STALE();
    error NAV_OBSERVATION_STALE();
    error OBSERVATION_TIME_UNAVAILABLE();
    error INVALID_TIMESTAMP();
    error CIRCUIT_BREAKER();
    error SEQUENCER_DOWN();
    error GRACE_PERIOD_NOT_OVER();
    error CASH_FEED_FAILED();
    error INVALID_PRICE();
    error STRATEGY_PAUSED();
    error STALE_PPS();
    error PPS_EXPIRED();
    error INVALID_PPS_TIMESTAMP();
    error NOT_A_REGISTERED_STRATEGY();
    error ZERO_FILL();
    /// @notice The instrument has no tolerance configured for this direction.
    /// @dev Fails CLOSED and says so. An unset tolerance is zero, which would otherwise compute a floor at
    ///      the exact NAV value and reject every honest trade with the far more confusing
    ///      `PRICE_OUTSIDE_POLICY`. Deliberately NOT defaulted to some built-in tolerance: a silent default
    ///      is a number nobody chose, applied to real value, in the fail-open direction. Call
    ///      `GyldBondRegistry.setTradeFloors` for this instrument.
    error TRADE_FLOORS_NOT_SET();
    /// @notice The registry has an aggregator wired but no PPS freshness tolerance set.
    /// @dev Fails CLOSED, like `TRADE_FLOORS_NOT_SET`. Zero means unconfigured rather than "no age check",
    ///      so forgetting to call `GyldBondRegistry.setMaxPpsAge` cannot silently drop the check.
    error PPS_AGE_NOT_CONFIGURED();
    /// @notice The realised price breached the instrument's configured tolerance
    error PRICE_OUTSIDE_POLICY(uint256 realised, uint256 floor);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant BPS_DENOMINATOR = 10_000;

    /// @notice `previewTrade` codes above this are policy conditions; at or below are `NavFailure` codes
    uint256 public constant POLICY_CODE_BASE = 100;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    GyldBondRegistry public immutable REGISTRY;
    GyldBondYieldSourceOracle public immutable ORACLE;

    /// @notice SuperVaultAggregator. `address(0)` disables the strategy pause / PPS checks entirely.
    /// @dev Set it. Zero is for unit fixtures, not for a shipping deployment: with zero, a paused strategy
    ///      can still trade.
    ISuperVaultStrategyState public immutable AGGREGATOR;

    constructor(address registry_, address oracle_, address aggregator_) {
        if (registry_ == address(0) || oracle_ == address(0)) revert ADDRESS_NOT_VALID();
        // A policy wired to an oracle that reads a DIFFERENT registry would check one instrument list and
        // price against another. One comparison closes it at deploy time.
        if (address(GyldBondYieldSourceOracle(oracle_).REGISTRY()) != registry_) revert REGISTRY_MISMATCH();
        REGISTRY = GyldBondRegistry(registry_);
        ORACLE = GyldBondYieldSourceOracle(oracle_);
        AGGREGATOR = ISuperVaultStrategyState(aggregator_);
    }

    /*//////////////////////////////////////////////////////////////
                              ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGyldTradePolicy
    function validateTrade(
        address account,
        TradeSide side,
        address inputToken,
        address outputToken,
        bytes calldata
    )
        external
        view
    {
        (address bond,) = _resolvePair(side, inputToken, outputToken);
        GyldBondRegistry.InstrumentConfig memory cfg = _requireInstrument(bond, side, inputToken, outputToken);
        _requireValuationUsable(bond, side, cfg);
        _requireStrategyState(account);
    }

    /// @dev Which token must be the bond follows from the side, so a SELL instance presented with
    ///      `(cash, bond)` resolves `cash` as the bond and fails `INSTRUMENT_NOT_REGISTERED`. That is what
    ///      stops a SELL instance being used to ACQUIRE bonds under the relaxed exit rules.
    function _resolvePair(
        TradeSide side,
        address inputToken,
        address outputToken
    )
        private
        pure
        returns (address bond, address cash)
    {
        if (side == TradeSide.BUY) return (outputToken, inputToken);
        return (inputToken, outputToken);
    }

    function _requireInstrument(
        address bond,
        TradeSide side,
        address inputToken,
        address outputToken
    )
        private
        view
        returns (GyldBondRegistry.InstrumentConfig memory cfg)
    {
        cfg = REGISTRY.getInstrumentConfig(bond);
        if (!cfg.registered) revert INSTRUMENT_NOT_REGISTERED();
        (, address cash) = _resolvePair(side, inputToken, outputToken);
        if (cfg.cashToken != cash) revert CASH_DENOMINATION_MISMATCH();
    }

    /// @dev The three-tier valuation gate. T1 live feed, T2 terminal governance mark, T3 dark.
    function _requireValuationUsable(
        address bond,
        TradeSide side,
        GyldBondRegistry.InstrumentConfig memory cfg
    )
        private
        view
    {
        // T2: a terminal mark is in force. SELL prices against it; BUY is never authorised into one.
        if (cfg.recoveryNavSet) {
            if (side == TradeSide.BUY) revert RECOVERY_MARK_SET();
            return;
        }
        // T3: SUSPENDED with no mark. There is no on-chain number an exit price could be judged against,
        // so the exit waits for governance to publish one. `NO_EXIT_MARK` names that specific situation and
        // is NOT used for an ordinary feed problem — conflating the two would tell an operator to publish a
        // recovery mark when the real fix is a stale feed.
        if (cfg.navSuspended) {
            if (side == TradeSide.SELL) revert NO_EXIT_MARK();
            revert NAV_SUSPENDED();
        }
        // T1: the feed must be healthy in every respect the oracle checks. This applies to BOTH sides: a
        // SELL with no usable NAV has no floor either, so it is refused with the real feed failure rather
        // than silently permitted or mislabelled.
        uint8 code = ORACLE.previewNav(bond).failureCode;
        if (code != uint8(GyldBondYieldSourceOracle.NavFailure.OK)) _revertForNavFailure(code);
    }

    /// @dev One named error per oracle failure code, matching `GyldTradeGuardHook`'s mapping so operators
    ///      see identical names from either surface.
    /// @dev Split into clock failures and value failures purely to stay under the repo's cyclomatic-complexity
    ///      limit — the guard hook solved the identical problem the identical way. The split is categorical,
    ///      not arbitrary: a clock failure means "the number may be fine but we cannot date it", a value
    ///      failure means "the number itself is unusable".
    function _revertForNavFailure(uint8 code) private pure {
        GyldBondYieldSourceOracle.NavFailure f = GyldBondYieldSourceOracle.NavFailure(code);
        _revertForClockFailure(f);
        _revertForValueFailure(f);
        revert INVALID_PRICE();
    }

    function _revertForClockFailure(GyldBondYieldSourceOracle.NavFailure f) private pure {
        if (f == GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE) revert NAV_PUBLICATION_STALE();
        if (f == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE) revert NAV_OBSERVATION_STALE();
        if (f == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_UNAVAILABLE) {
            revert OBSERVATION_TIME_UNAVAILABLE();
        }
        if (f == GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP) revert INVALID_TIMESTAMP();
        if (f == GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE) revert SEQUENCER_DOWN();
        if (f == GyldBondYieldSourceOracle.NavFailure.GRACE_PERIOD) revert GRACE_PERIOD_NOT_OVER();
    }

    function _revertForValueFailure(GyldBondYieldSourceOracle.NavFailure f) private pure {
        if (f == GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED) revert INSTRUMENT_NOT_REGISTERED();
        if (f == GyldBondYieldSourceOracle.NavFailure.SUSPENDED) revert NAV_SUSPENDED();
        if (f == GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER) revert CIRCUIT_BREAKER();
        if (f == GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED) revert CASH_FEED_FAILED();
    }

    /// @dev Registration must be established BEFORE the other three reads are trusted: only `getPPS` carries
    ///      `validStrategy`, so an unregistered address reports "not paused" and timestamp zero.
    function _requireStrategyState(address account) private view {
        if (address(AGGREGATOR) == address(0)) return;

        // Bare `catch` on purpose: `catch (bytes memory)` copies unbounded revert data and is the
        // EIP-150 returnbomb this codebase has already been bitten by.
        try AGGREGATOR.getPPS(account) returns (uint256) { }
        catch {
            revert NOT_A_REGISTERED_STRATEGY();
        }

        if (AGGREGATOR.isStrategyPaused(account)) revert STRATEGY_PAUSED();
        if (AGGREGATOR.isPPSStale(account)) revert STALE_PPS();

        // Read live from the registry, so retuning this is one role-gated transaction.
        uint256 maxPpsAge = REGISTRY.maxPpsAge();
        if (maxPpsAge == 0) revert PPS_AGE_NOT_CONFIGURED();
        uint256 ts = AGGREGATOR.getLastUpdateTimestamp(account);
        // Zero or future is WRONG, not merely old. Skipping the subtraction here was a real bug class in
        // this contract family; do not reintroduce it by comparing ages first.
        if (ts == 0 || ts > block.timestamp) revert INVALID_PPS_TIMESTAMP();
        if (block.timestamp - ts > maxPpsAge) revert PPS_EXPIRED();
    }

    /*//////////////////////////////////////////////////////////////
                                 OUTCOME
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGyldTradePolicy
    function validateFill(FillArgs calldata args) external view {
        if (args.inputSpent == 0 || args.received == 0) revert ZERO_FILL();

        (address bond,) = _resolvePair(args.side, args.inputToken, args.outputToken);
        GyldBondRegistry.InstrumentConfig memory cfg =
            _requireInstrument(bond, args.side, args.inputToken, args.outputToken);

        uint256 nav = _exitOrEntryNav(bond, cfg);
        if (nav == 0) {
            // A total-loss mark (`recoveryNav == 0`) has no meaningful floor. The hook's own
            // `outputMin != 0` requirement still forces the trade to deliver something.
            return;
        }

        uint256 floor_;
        if (args.side == TradeSide.SELL) {
            if (cfg.maxExitDiscountBps == 0) revert TRADE_FLOORS_NOT_SET();
            uint256 expectedCash = Math.mulDiv(args.inputSpent, nav, cfg.bondScale);
            floor_ = Math.mulDiv(expectedCash, BPS_DENOMINATOR - cfg.maxExitDiscountBps, BPS_DENOMINATOR);
        } else {
            if (cfg.maxEntryPremiumBps == 0) revert TRADE_FLOORS_NOT_SET();
            uint256 expectedBond = Math.mulDiv(args.inputSpent, cfg.bondScale, nav);
            // A nav so large that the expectation floors to zero would make the check vacuous.
            if (expectedBond == 0) revert INVALID_PRICE();
            floor_ = Math.mulDiv(expectedBond, BPS_DENOMINATOR - cfg.maxEntryPremiumBps, BPS_DENOMINATOR);
        }
        if (args.received < floor_) revert PRICE_OUTSIDE_POLICY(args.received, floor_);
    }

    /// @dev A terminal mark outranks the feed, mirroring the oracle's own precedence.
    function _exitOrEntryNav(
        address bond,
        GyldBondRegistry.InstrumentConfig memory cfg
    )
        private
        view
        returns (uint256)
    {
        if (cfg.recoveryNavSet) return cfg.recoveryNav;
        return ORACLE.previewNav(bond).nav;
    }

    /*//////////////////////////////////////////////////////////////
                                 PREVIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGyldTradePolicy
    /// @dev Mirrors `validateTrade` CONDITION FOR CONDITION AND IN THE SAME ORDER. A divergence between a
    ///      preview and its strict counterpart was a real bug in the guard hook, so the ordering identity is
    ///      pinned by test rather than left to inspection.
    function previewTrade(
        address account,
        TradeSide side,
        address inputToken,
        address outputToken
    )
        external
        view
        returns (uint256 reasonCode)
    {
        (address bond, address cash) = _resolvePair(side, inputToken, outputToken);

        GyldBondRegistry.InstrumentConfig memory cfg;
        try REGISTRY.getInstrumentConfig(bond) returns (GyldBondRegistry.InstrumentConfig memory c) {
            cfg = c;
        } catch {
            return uint256(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED);
        }
        if (!cfg.registered) return uint256(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED);
        if (cfg.cashToken != cash) return POLICY_CODE_BASE + 1;

        uint256 valuationCode = _previewValuation(bond, side, cfg);
        if (valuationCode != 0) return valuationCode;

        return _previewStrategyState(account);
    }

    /// @dev The preview twin of `_requireValuationUsable`, in the same order and over the same tiers.
    function _previewValuation(
        address bond,
        TradeSide side,
        GyldBondRegistry.InstrumentConfig memory cfg
    )
        private
        view
        returns (uint256)
    {
        if (cfg.recoveryNavSet) {
            return side == TradeSide.BUY ? POLICY_CODE_BASE + 3 : 0;
        }
        if (cfg.navSuspended) {
            return side == TradeSide.SELL
                ? POLICY_CODE_BASE + 4
                : uint256(GyldBondYieldSourceOracle.NavFailure.SUSPENDED);
        }
        uint8 code = ORACLE.previewNav(bond).failureCode;
        return code == uint8(GyldBondYieldSourceOracle.NavFailure.OK) ? 0 : uint256(code);
    }

    function _previewStrategyState(address account) private view returns (uint256) {
        if (address(AGGREGATOR) == address(0)) return 0;
        try AGGREGATOR.getPPS(account) returns (uint256) { }
        catch {
            return POLICY_CODE_BASE + 13;
        }
        if (AGGREGATOR.isStrategyPaused(account)) return POLICY_CODE_BASE + 10;
        if (AGGREGATOR.isPPSStale(account)) return POLICY_CODE_BASE + 11;
        uint256 maxPpsAge = REGISTRY.maxPpsAge();
        if (maxPpsAge == 0) return POLICY_CODE_BASE + 15;
        uint256 ts = AGGREGATOR.getLastUpdateTimestamp(account);
        if (ts == 0 || ts > block.timestamp) return POLICY_CODE_BASE + 14;
        if (block.timestamp - ts > maxPpsAge) return POLICY_CODE_BASE + 12;
        return 0;
    }
}
