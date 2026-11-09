// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { GyldBondYieldSourceOracle } from "../../../accounting/oracles/GyldBondYieldSourceOracle.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title GyldTradeGuardHook
/// @author Superform Labs
/// @notice NONACCOUNTING guard: reverts unless the named Gyld instrument is currently tradable — registered,
///         not suspended, priced by its approved feed, and fresh on BOTH the observation and publication clocks.
///         Moves no funds, grants no approvals, emits no executions of its own.
/// @dev WHY THIS STILL EXISTS, NOW THAT THE TRADE HOOK CHECKS TRADABILITY ITSELF. It used to be separate
///      because baking freshness into the trade hook would have blocked selling during a credit event.
///      That argument is dead: `ApproveAndTradeGyldBondHook` now calls `GyldTradePolicy` from its own
///      `preExecute`/`postExecute`, and the credit-event exit is handled by the policy's recovery-mark
///      tier rather than by relaxing freshness. The guard's ONLY remaining job is letting a cautious root
///      demand STRICTER freshness than the registry's own bounds, because its leaf commits the two ages
///      while the policy reads them from governance configuration.

/// @dev WHAT THIS HOOK DOES NOT DO, stated plainly because the leaf author relies on it. It checks ONLY the
///      instrument named in its OWN calldata: registration, the expected cash denomination, suspension and
///      the two freshness clocks. It does NOT check strategy pause or price-per-share staleness. An earlier
///      version of this comment claimed it closed the `executeHooks` gap where `_validateStrategyState` is
///      never called; that was wrong, because the aggregator dependency needed for a pause or PPS check was
///      dropped during implementation. If that policy is required, it has to be added here or enforced in
///      the periphery. The `account` argument is unused for the same reason: every check is
///      account-independent.
/// @dev AND IT IS NOT BOUND TO THE TRADE IT ACCOMPANIES. `SuperVaultStrategy.executeHooks` authorises each
///      hook independently, so a trade leaf's proof does not require this leaf, its ordering, or a matching
///      bond. Including this hook in a root does not make it mandatory, and a root holding both a guard leaf
///      for bond A and a trade leaf for bond B authorises guarding A while trading B. Pairing them correctly
///      is therefore a requirement on the LEAF BUILDER, not something enforced on-chain. Binding them would
///      need a transaction-scoped attestation keyed by account, instrument, direction and the exact trade.
/// @dev THE TWO CLOCKS ARE NOT INTERCHANGEABLE. `maxPublicationAge` bounds how long ago the number reached this
///      chain; `maxObservationAge` bounds how old the issuer's valuation itself is. A feed can publish a day-old
///      valuation seconds ago and look perfectly fresh on the publication clock alone.
/// @dev BOTH BOUNDS ARE IN THE MERKLE LEAF. `inspect()` commits them, so a signer holding a proof for a tight
///      bound cannot present it with a looser one. Each distinct pair of bounds is a distinct leaf, which means
///      the off-chain leaf builder must append two `uint256` arguments.
/// @dev CHECKED TWICE, ON PURPOSE. Once at `build()` — which already observes post-action state, because the
///      executor builds hook N only after hook N-1 executed — and once authoritatively in `_postExecute`, from
///      inside the account's batch. Same rationale as the Morpho and Aave health-check guards.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific), exactly 136 bytes:
/// @notice         bytes32   placeholder0       = BytesLib.toBytes32(data, 0);
/// @notice         address   yieldSource        = BytesLib.toAddress(data, 32);
/// @notice         address   cashToken          = BytesLib.toAddress(data, 52);
/// @notice         uint256   maxObservationAge  = BytesLib.toUint256(data, 72);
/// @notice         uint256   maxPublicationAge  = BytesLib.toUint256(data, 104);
/// @dev `yieldSource` IS the bond token, matching the oracle's share model. Both age bounds are committed
///      into the Merkle leaf by `inspect()`, so a proof issued for a tight bound cannot be presented with a
///      looser one. The length is EXACT, not a minimum: trailing bytes would make the leaf ambiguous.
contract GyldTradeGuardHook is BaseHook, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Exact expected calldata length: a 52-byte strategy header (32-byte oracle id + 20-byte yield
    ///         source, which IS the bond token), then the 20-byte cash token and the two 32-byte age bounds.
    ///         32 + 20 + 20 + 32 + 32 = 136. Same shape as `MorphoHealthCheckHook`: body starts at 52.
    uint256 private constant EXPECTED_DATA_LENGTH = 136;

    uint256 private constant YIELD_SOURCE_OFFSET = 32;
    uint256 private constant CASH_TOKEN_OFFSET = 52;
    uint256 private constant MAX_OBSERVATION_AGE_OFFSET = 72;
    uint256 private constant MAX_PUBLICATION_AGE_OFFSET = 104;

    /// @notice Upper bound on either configurable age, so a signing mistake cannot authorise an ancient NAV
    uint256 public constant MAX_AGE_CEILING = 30 days;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The NAV oracle this guard consults. Its `previewNav` never reverts, so every failure below is
    ///         reported as a precise named error rather than an opaque bubble-up.
    GyldBondYieldSourceOracle public immutable GYLD_ORACLE;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_DATA_LENGTH();
    error IDENTICAL_TOKENS();
    error INVALID_STALENESS();
    error INSTRUMENT_NOT_REGISTERED();
    error CASH_DENOMINATION_MISMATCH();
    error NAV_SUSPENDED();
    error INVALID_PRICE();
    error NAV_PUBLICATION_STALE();
    error NAV_OBSERVATION_STALE();
    error OBSERVATION_TIME_UNAVAILABLE();
    error SEQUENCER_DOWN();
    error CASH_FEED_FAILED();
    /// @notice F3: a feed reported a zero or future timestamp
    error INVALID_TIMESTAMP();
    /// @notice F7: the sequencer is up but still inside its grace period
    error GRACE_PERIOD_NOT_OVER();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct Vars {
        address bondToken;
        address cashToken;
        uint256 maxObservationAge;
        uint256 maxPublicationAge;
    }

    constructor(address gyldOracle_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) {
        if (gyldOracle_ == address(0)) revert ADDRESS_NOT_VALID();
        GYLD_ORACLE = GyldBondYieldSourceOracle(gyldOracle_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Gyld Trade Guard";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Reverts unless the named Gyld bond is registered, unsuspended and freshly priced";
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Non-reverting pre-flight for the OMS: the reason this leaf would fail, or zero for tradable
    /// @dev Returns the oracle's `NavFailure` code, with guard-specific conditions mapped onto dedicated codes
    ///      above 100 so the caller can tell a stale price from a denomination mismatch without simulating.
    ///      Precedent: `MorphoHealthCheckHook.previewHealthFactor`.
    /// @return reasonCode 0 = tradable; 1-9 = the oracle's NavFailure; 101 = cash denomination mismatch
    function previewTradable(
        bytes calldata data,
        address /* account */
    )
        external
        view
        returns (uint256 reasonCode)
    {
        Vars memory vars = _decode(data);
        GyldBondYieldSourceOracle.NavStatus memory status = GYLD_ORACLE.previewNav(vars.bondToken);
        // The order MIRRORS `_requireTradable`, so the preview names the same cause the strict path would.
        // Previously the failure code was checked first, so an instrument that was both suspended and named
        // with the wrong cash token reported a transient suspension while execution reverted on the
        // permanently wrong leaf, and an OMS trusting the preview would retry forever.
        if (!status.registered) return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED));
        if (status.suspended) return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED));
        if (status.cashToken != vars.cashToken) return 101;
        if (status.failureCode != 0) return status.failureCode;
        return _clockFailure(status, vars);
    }

    /// @inheritdoc BaseHook
    /// @dev Zero executions: `build()` yields exactly `[preExecute, postExecute]`.
    function _buildHookExecutions(
        address, /* prevHook */
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        _requireTradable(account, data);
        executions = new Execution[](0);
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Commits the instrument, its expected cash denomination AND both freshness bounds (104 bytes). The
    ///      bounds are in the leaf deliberately: without them a signer could reuse a proof issued for a tight
    ///      bound while presenting a looser one.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        Vars memory vars = _decode(data);
        return abi.encodePacked(vars.bondToken, vars.cashToken, vars.maxObservationAge, vars.maxPublicationAge);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless: this hook moves nothing, so there is no amount for the OMS to size.
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @dev S2 only: declares `ISuperHookInflowOutflow` and explicitly NOT `ISuperHookOutflow`
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        if (interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId) return true;
        if (interfaceId == type(ISuperHookResult).interfaceId) return true;
        return interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Guard only — forwards the previous hook's outAmount and outToken untouched
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    /// @dev The authoritative check, run from inside the account's batch after every preceding hook executed
    function _postExecute(address, address account, bytes calldata data) internal view override {
        _requireTradable(account, data);
    }

    function _decode(bytes calldata data) private pure returns (Vars memory vars) {
        if (data.length != EXPECTED_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        vars.bondToken = BytesLib.toAddress(data, YIELD_SOURCE_OFFSET);
        vars.cashToken = BytesLib.toAddress(data, CASH_TOKEN_OFFSET);
        vars.maxObservationAge = BytesLib.toUint256(data, MAX_OBSERVATION_AGE_OFFSET);
        vars.maxPublicationAge = BytesLib.toUint256(data, MAX_PUBLICATION_AGE_OFFSET);

        if (vars.bondToken == address(0) || vars.cashToken == address(0)) revert ADDRESS_NOT_VALID();
        if (vars.bondToken == vars.cashToken) revert IDENTICAL_TOKENS();
        // Zero would make every call revert; the ceiling stops a mis-signed leaf authorising an ancient NAV.
        if (vars.maxObservationAge == 0 || vars.maxPublicationAge == 0) revert INVALID_STALENESS();
        if (vars.maxObservationAge > MAX_AGE_CEILING || vars.maxPublicationAge > MAX_AGE_CEILING) {
            revert INVALID_STALENESS();
        }
    }

    /// @notice Every reason a Gyld trade must not proceed, as a distinct named error
    function _requireTradable(
        address,
        /* account */
        bytes calldata data
    )
        private
        view
    {
        Vars memory vars = _decode(data);

        GyldBondYieldSourceOracle.NavStatus memory status = GYLD_ORACLE.previewNav(vars.bondToken);

        if (!status.registered) revert INSTRUMENT_NOT_REGISTERED();
        // F2: read the FLAG, defensively, rather than relying on the oracle's code mapping. The oracle now
        // orders suspension ahead of the recovery override, but this check means the guard stops a suspended
        // instrument even if that ordering ever regresses.
        if (status.suspended) revert NAV_SUSPENDED();
        // A feed or denomination change between signing and execution must not go unnoticed.
        if (status.cashToken != vars.cashToken) revert CASH_DENOMINATION_MISMATCH();

        _revertForFailure(GyldBondYieldSourceOracle.NavFailure(status.failureCode));
        if (status.nav == 0) revert INVALID_PRICE();

        // F3: a zero or future clock is unusable data, not age zero. One shared evaluation with the
        // preview, so the two paths cannot disagree about which clock failed.
        uint256 clock = _clockFailure(status, vars);
        if (clock == uint256(uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP))) {
            revert INVALID_TIMESTAMP();
        }
        if (clock == uint256(uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE))) {
            revert NAV_PUBLICATION_STALE();
        }
        if (clock == uint256(uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE))) {
            revert NAV_OBSERVATION_STALE();
        }
    }

    /// @dev The LEAF's freshness verdict, shared by the strict and preview paths so they cannot disagree.
    ///      Returns a `NavFailure` code as a uint256, or zero when both clocks are acceptable. The leaf's
    ///      bounds may be stricter than the registry's; this enforces the leaf's.
    function _clockFailure(
        GyldBondYieldSourceOracle.NavStatus memory status,
        Vars memory vars
    )
        private
        view
        returns (uint256)
    {
        if (status.publishedAt == 0 || status.publishedAt > block.timestamp) {
            return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP));
        }
        if (block.timestamp - status.publishedAt > vars.maxPublicationAge) {
            return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE));
        }
        if (status.observedAt == 0) return 0;
        if (status.observedAt > block.timestamp) {
            return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP));
        }
        if (block.timestamp - status.observedAt > vars.maxObservationAge) {
            return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE));
        }
        return 0;
    }

    /// @dev Translates the oracle's diagnostic code into this hook's named errors, so an operator sees why a
    ///      guarded leaf refused rather than an opaque price failure.
    function _revertForFailure(GyldBondYieldSourceOracle.NavFailure failure) private pure {
        if (failure == GyldBondYieldSourceOracle.NavFailure.OK) return;
        _revertForClock(failure);
        if (failure == GyldBondYieldSourceOracle.NavFailure.SUSPENDED) revert NAV_SUSPENDED();
        if (failure == GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE) revert SEQUENCER_DOWN();
        if (failure == GyldBondYieldSourceOracle.NavFailure.GRACE_PERIOD) revert GRACE_PERIOD_NOT_OVER();
        if (failure == GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED) revert CASH_FEED_FAILED();
        revert INVALID_PRICE();
    }

    /// @dev The freshness half of the mapping, split out to keep each function inside the complexity budget
    function _revertForClock(GyldBondYieldSourceOracle.NavFailure failure) private pure {
        if (failure == GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE) revert NAV_PUBLICATION_STALE();
        if (failure == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE) revert NAV_OBSERVATION_STALE();
        if (failure == GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP) revert INVALID_TIMESTAMP();
        if (failure == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_UNAVAILABLE) {
            revert OBSERVATION_TIME_UNAVAILABLE();
        }
    }
}
