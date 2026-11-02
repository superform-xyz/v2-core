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
/// @dev WHY THIS IS A SEPARATE HOOK AND NOT A CHECK INSIDE THE TRADE HOOK. Freshness is a property of the ROOT
///      the curator signs, not of the venue call. Baking it into the trade hook would mean you could not SELL
///      during a credit event, which is exactly when selling matters most. As a separate leaf it becomes a
///      root-authoring choice: mandatory in buy roots, omitted or loosened in sell roots.
/// @dev WHY IT IS NEEDED AT ALL, given strategy permissions already exist. `SuperVaultStrategy.executeHooks`
///      gates on the manager role, hook registration and the Merkle proof. It does NOT call
///      `_validateStrategyState`, so today a manager holding a valid leaf can trade while the strategy is
///      paused and its price per share is stale. This hook closes that on-chain, which is precisely the brief's
///      point that existing strategy permissions alone do not establish these protections.
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
        if (status.failureCode != 0) return status.failureCode;
        if (status.cashToken != vars.cashToken) return 101;
        // The `block.timestamp >` comparisons are not redundant: a feed may report a timestamp in the future,
        // and an unguarded subtraction would make this preview PANIC. It must never revert, so the age of a
        // future-dated publication is treated as zero and left to the strict path to judge.
        if (block.timestamp > status.publishedAt && block.timestamp - status.publishedAt > vars.maxPublicationAge) {
            return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE));
        }
        if (status.observedAt != 0 && block.timestamp > status.observedAt) {
            if (block.timestamp - status.observedAt > vars.maxObservationAge) {
                return uint256(uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE));
            }
        }
        return 0;
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
        // A feed or denomination change between signing and execution must not go unnoticed.
        if (status.cashToken != vars.cashToken) revert CASH_DENOMINATION_MISMATCH();

        _revertForFailure(GyldBondYieldSourceOracle.NavFailure(status.failureCode));
        if (status.nav == 0) revert INVALID_PRICE();

        // The leaf's bounds may be stricter than the registry's; enforce the leaf's.
        if (block.timestamp > status.publishedAt && block.timestamp - status.publishedAt > vars.maxPublicationAge) {
            revert NAV_PUBLICATION_STALE();
        }
        if (status.observedAt != 0 && block.timestamp > status.observedAt) {
            if (block.timestamp - status.observedAt > vars.maxObservationAge) revert NAV_OBSERVATION_STALE();
        }
    }

    /// @dev Translates the oracle's diagnostic code into this hook's named errors, so an operator sees why a
    ///      guarded leaf refused rather than an opaque price failure.
    function _revertForFailure(GyldBondYieldSourceOracle.NavFailure failure) private pure {
        if (failure == GyldBondYieldSourceOracle.NavFailure.OK) return;
        if (failure == GyldBondYieldSourceOracle.NavFailure.SUSPENDED) revert NAV_SUSPENDED();
        if (failure == GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE) revert NAV_PUBLICATION_STALE();
        if (failure == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE) revert NAV_OBSERVATION_STALE();
        if (failure == GyldBondYieldSourceOracle.NavFailure.OBSERVATION_UNAVAILABLE) {
            revert OBSERVATION_TIME_UNAVAILABLE();
        }
        if (failure == GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE) revert SEQUENCER_DOWN();
        if (failure == GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED) revert CASH_FEED_FAILED();
        revert INVALID_PRICE();
    }
}
