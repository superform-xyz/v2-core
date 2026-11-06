// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { GyldBondRegistry } from "./GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "./GyldBondYieldSourceOracle.sol";
import { IGyldTradePolicy } from "../../interfaces/accounting/IGyldTradePolicy.sol";
import { ISuperVaultStrategyState, ISuperVaultStrategyVault } from "../../interfaces/ISuperVaultStrategyState.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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
    /// @notice R4-1: the account is a registered strategy but its vault could not be read, so the share
    ///         supply cannot be committed and the fill measurement cannot be trusted. Fails closed.
    error ACCOUNT_VAULT_UNREADABLE();
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
        // `getInstrumentConfig` already reverts `INSTRUMENT_NOT_REGISTERED` for an unknown bond, and the
        // registry declares an error of the SAME NAME, so the selectors collide (0x9de5b712) and a caller
        // cannot tell the two apart. Kept as defence in depth in case that getter is ever relaxed to return
        // a zeroed struct instead of reverting — but note a test asserting this selector is catching the
        // REGISTRY's revert, not this line.
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
        // T1: the feed must be healthy in every respect the oracle checks. This applies to BOTH sides,
        // with exactly one exception: R4-3's bounded exit grace lets a SELL price against a recently
        // stale publication. A BUY is never graced, and a SELL with no usable reference at all is still
        // refused with the real feed failure rather than silently permitted or mislabelled.
        uint8 code = ORACLE.previewNav(bond).failureCode;
        if (code == uint8(GyldBondYieldSourceOracle.NavFailure.OK)) return;
        if (side == TradeSide.SELL && _exitGraceNav(bond, cfg, code) != 0) return;
        _revertForNavFailure(code);
    }

    /// @dev R4-3: the bounded exit grace. Returns the last good NAV when a SELL may price against a
    ///      recently stale publication, or ZERO when it may not — callers treat zero as "no grace" and
    ///      fall through to the real feed error, which is more useful to an operator than a grace-specific
    ///      one would be.
    /// @dev THREE DELIBERATE NARROWINGS, each of which is load-bearing:
    ///      1. CLOCK failures only. `PUBLICATION_STALE` and `OBSERVATION_STALE` mean "the number may be
    ///         fine but it is late". A VALUE failure means the number itself is unusable:
    ///         `CIRCUIT_BREAKER` is a value judgement and `CASH_FEED_FAILED` means we cannot denominate in
    ///         cash at all, so no amount of grace makes either safe.
    ///      2. Never reached while SUSPENDED. T3 above returns first, and `previewNavRaw` independently
    ///         refuses to emit a feed value for a suspended instrument. Suspension is governance saying
    ///         "do not trust this"; lateness is an operational hiccup. Collapsing the two is exactly what
    ///         the `NO_EXIT_MARK`-versus-feed-error split exists to prevent.
    ///      3. SELL only, enforced by the caller. On this leg the floor RISES with nav, so a stale
    ///         reference can only demand more cash and block the fill. On a BUY the same staleness lowers
    ///         the bar, which is why the grace must never be mirrored there.
    function _exitGraceNav(
        address bond,
        GyldBondRegistry.InstrumentConfig memory cfg,
        uint8 code
    )
        private
        view
        returns (uint256)
    {
        uint256 window = cfg.emergencyExitMaxPublicationAge;
        if (window == 0 || cfg.emergencyExitDiscountBps == 0) return 0;
        if (
            code != uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE)
                && code != uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE)
        ) return 0;

        (uint256 nav, uint256 observedAt, uint256 publishedAt,) = ORACLE.previewNavRaw(bond);
        if (nav == 0) return 0;
        if (!_withinWindow(publishedAt, window)) return 0;
        // An instrument that requires observation time must satisfy the window on BOTH clocks, or the
        // grace would accept a freshly republished quote of an ancient observation.
        if (cfg.requiresObservationTime && !_withinWindow(observedAt, window)) return 0;
        return nav;
    }

    /// @dev Zero or future is WRONG rather than merely old — the same bug class the PPS read guards against.
    function _withinWindow(uint256 ts, uint256 window) private view returns (bool) {
        if (ts == 0 || ts > block.timestamp) return false;
        return block.timestamp - ts <= window;
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

        // R4-3: resolved together, because a graced SELL must be floored against the graced NAV with the
        // graced discount — mixing a stale reference with the tight discount would reject the exit the
        // grace exists to permit, and mixing a live reference with the wide discount would loosen a
        // healthy trade. Both are re-derived rather than carried over from `validateTrade`: feeds, time
        // and registry state are fixed within a transaction, so the two calls cannot disagree, and
        // re-deriving avoids trusting anything the hook passes in.
        (uint256 nav, uint16 exitDiscountBps) = _fillReference(bond, args.side, cfg);
        if (nav == 0) {
            // A total-loss MARK has no meaningful floor, and that is intended: the hook's own
            // `outputMin != 0` still forces the trade to deliver something.
            if (cfg.recoveryNavSet) return;
            // But a zero from the FEED means the valuation is unusable, not that the bond is worthless —
            // `previewNav` zeroes `nav` for every non-OK code. Returning here would silently drop the floor
            // for that fill, so refuse instead. `validateTrade` normally catches this earlier; this closes
            // the window where the feed degrades between `preExecute` and `postExecute`.
            revert INVALID_PRICE();
        }

        uint256 floor_ = _floorFor(args.side, args.inputSpent, nav, cfg, exitDiscountBps);
        if (args.received < floor_) revert PRICE_OUTSIDE_POLICY(args.received, floor_);
    }

    /// @dev R4-3: the (nav, exit discount) pair one fill must be judged against.
    /// @dev Precedence mirrors `_requireValuationUsable` exactly, and must keep doing so: a terminal mark
    ///      outranks the feed, a healthy feed needs no grace, and the grace is the last resort on a SELL.
    ///      The returned discount is meaningless on a BUY (that leg uses `maxEntryPremiumBps`) and is
    ///      returned as the normal one there so a future caller cannot read a graced value by accident.
    function _fillReference(
        address bond,
        TradeSide side,
        GyldBondRegistry.InstrumentConfig memory cfg
    )
        private
        view
        returns (uint256 nav, uint16 exitDiscountBps)
    {
        exitDiscountBps = cfg.maxExitDiscountBps;
        if (cfg.recoveryNavSet) return (cfg.recoveryNav, exitDiscountBps);

        GyldBondYieldSourceOracle.NavStatus memory status = ORACLE.previewNav(bond);
        if (status.failureCode == uint8(GyldBondYieldSourceOracle.NavFailure.OK)) {
            return (status.nav, exitDiscountBps);
        }
        if (side != TradeSide.SELL) return (0, exitDiscountBps);
        uint256 graced = _exitGraceNav(bond, cfg, status.failureCode);
        if (graced == 0) return (0, exitDiscountBps);
        return (graced, cfg.emergencyExitDiscountBps);
    }

    /// @dev The realised-price floor for one side, from MEASURED input and the authoritative nav.
    /// @dev Split out only to stay under the repo's cyclomatic-complexity limit.
    /// @dev ROUNDING IS LENIENT, DELIBERATELY ACKNOWLEDGED. `mulDiv` floors, and for a FLOOR the
    ///      conservative direction would be ceiling, so both legs discard in the counterparty's favour —
    ///      under one raw unit on SELL and under two on BUY, which truncates twice. Measured at under
    ///      2e-6 cash units per fill against ~150k gas, i.e. negative-EV by orders of magnitude.
    /// @dev The one case that mattered was a truncation to a ZERO floor, which is no floor at all. Both
    ///      legs now reject it below. The old guard tested `expectedBond == 0` and was one unit short: an
    ///      expectation of exactly 1 also truncates to zero (`1 * 10_000 / 10_200 == 0`), and the SELL leg
    ///      had no equivalent guard, so the real zero-floor region was `fair < 2` raw units rather than
    ///      `< 1`. Guarding the COMPUTED floor covers both legs and both units.
    function _floorFor(
        TradeSide side,
        uint256 inputSpent,
        uint256 nav,
        GyldBondRegistry.InstrumentConfig memory cfg,
        uint16 exitDiscountBps
    )
        private
        pure
        returns (uint256)
    {
        uint256 floor_;
        if (side == TradeSide.SELL) {
            // R4-3: `exitDiscountBps` is the NORMAL discount on a healthy feed and the WIDER graced one
            // inside the exit window. Both are capped at `MAX_TOLERANCE_BPS` by the registry, so the
            // subtraction below cannot underflow and the floor can never be disabled outright.
            if (exitDiscountBps == 0) revert TRADE_FLOORS_NOT_SET();
            uint256 expectedCash = Math.mulDiv(inputSpent, nav, cfg.bondScale);
            floor_ = Math.mulDiv(expectedCash, BPS_DENOMINATOR - exitDiscountBps, BPS_DENOMINATOR);
        } else {
            if (cfg.maxEntryPremiumBps == 0) revert TRADE_FLOORS_NOT_SET();
            uint256 expectedBond = Math.mulDiv(inputSpent, cfg.bondScale, nav);
            // R4-2: `expected * (1 - p)` is the WRONG inverse for a PREMIUM — receiving `expected * (1 - p)`
            // means paying `nav / (1 - p)`, a 25% premium at the 20% ceiling. A premium of at most `p` means
            // paying at most `nav * (1 + p)`, i.e. receiving at least `expected / (1 + p)`. The ceiling is
            // pinned across every legal tolerance by `testFuzz_EntryPremiumNeverExceedsTheConfiguredCeiling`
            // and at a worked value by `test_Fixed_R4_2_EntryPremiumCeilingIsTheConfiguredValue`.
            // ASSUMES AN 18-DECIMAL BOND. The guarantee is tight only while `expectedBond` is large: it
            // degrades as ~1/expectedBond, so a 0-2 decimal bond would be loose by hundreds of bps. Nothing
            // at registration constrains token decimals — same unverified assumption as
            // GYLD_MAX_BOND_INPUT_AMOUNT_KATANA.
            floor_ = Math.mulDiv(expectedBond, BPS_DENOMINATOR, BPS_DENOMINATOR + cfg.maxEntryPremiumBps);
        }
        // A floor of zero is no floor at all, so refuse rather than wave the fill through. Guarding the
        // COMPUTED floor rather than the expectation catches both legs and is one unit tighter than the
        // old `expectedBond == 0` check: an expectation of exactly 1 also truncates to a zero floor
        // (1 * 10_000 / 10_200 == 0), and that case slipped through.
        if (floor_ == 0) revert INVALID_PRICE();
        return floor_;
    }


    /*//////////////////////////////////////////////////////////////
                          LEG-SCOPED STATE COMMITMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGyldTradePolicy
    function accountStateCommitment(address account) external view returns (bytes32) {
        // A call to a CODELESS address succeeds with empty returndata, and Solidity cannot catch the
        // resulting decode failure — `try/catch` would bubble a bare revert instead of entering the catch.
        // So code presence has to be checked explicitly, not delegated to the catch below.
        if (account.code.length == 0) {
            if (address(AGGREGATOR) != address(0)) revert ACCOUNT_VAULT_UNREADABLE();
            return bytes32(0);
        }
        try ISuperVaultStrategyVault(account).getVaultInfo() returns (address vault, address, uint8) {
            // A strategy with no vault wired yet has nothing to commit — but a ZERO commitment makes the
            // whole check vacuous (pre and post both zero), so it must not be reachable on a deployment
            // that has an aggregator. Unreachable with the real implementation (`initialize` rejects a zero
            // vault and `_vault` is never reassigned), but that is a periphery invariant this contract
            // would otherwise be trusting rather than checking — the exact shape R4-1 exists to remove.
            if (vault == address(0)) {
                if (address(AGGREGATOR) != address(0)) revert ACCOUNT_VAULT_UNREADABLE();
                return bytes32(0);
            }
            return keccak256(abi.encode(vault, IERC20(vault).totalSupply()));
        } catch {
            // A REVERT from `getVaultInfo` means this is not a SuperVault strategy — a plain ERC-7579
            // account on the 4337 path, which has no vault supply to fake. Returning zero keeps that
            // working.
            // NARROWER THAN IT LOOKS: this catch is entered ONLY on an actual revert. A target that has
            // code and returns EMPTY or SHORT data produces an uncatchable revert, because Solidity cannot
            // catch a return-data decoding failure. So an account with a permissive fallback bricks every
            // leg with a nameless revert rather than landing here. Nexus reverts `MissingFallbackHandler`
            // on an unknown selector, so the supported path reaches this branch correctly.
            // But when an aggregator IS configured, `validateTrade` has already established the account is
            // a registered strategy, so an unreadable vault is a contradiction and must not silently
            // disable the check.
            if (address(AGGREGATOR) != address(0)) revert ACCOUNT_VAULT_UNREADABLE();
            return bytes32(0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PREVIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGyldTradePolicy
    /// @dev Mirrors `validateTrade` condition for condition. A divergence between a preview and its strict
    ///      counterpart was a real bug in the guard hook, so `test_PreviewAndStrictAgreeAcrossStates` pins
    ///      it — but be precise about what is pinned: the VALUATION-BEFORE-STRATEGY-STATE boundary, via two
    ///      matrix states that break two conditions at once plus a code-to-error mapping. Intra-block order
    ///      (recovery-mark vs suspension; paused vs stale vs expired) is NOT pinned and rests on reading.
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
            return
                side == TradeSide.SELL ? POLICY_CODE_BASE + 4 : uint256(GyldBondYieldSourceOracle.NavFailure.SUSPENDED);
        }
        uint8 code = ORACLE.previewNav(bond).failureCode;
        if (code == uint8(GyldBondYieldSourceOracle.NavFailure.OK)) return 0;
        // R4-3: the preview MUST agree with the strict path, or the OMS would skip a leg the policy would
        // in fact authorise — the exact failure mode `previewTrade` exists to prevent.
        if (side == TradeSide.SELL && _exitGraceNav(bond, cfg, code) != 0) return 0;
        return uint256(code);
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
