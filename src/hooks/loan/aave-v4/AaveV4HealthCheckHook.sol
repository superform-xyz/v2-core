// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { AaveV4ReserveKey } from "../../../libraries/AaveV4ReserveKey.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4HealthCheckHook
/// @author Superform Labs
/// @notice NONACCOUNTING guard: reverts unless the executing account's Aave V4 health factor on the calldata
///         Spoke is at or above `minHealthFactor`. Moves no funds, grants no approvals, forwards the previous
///         hook's output untouched (PASSTHROUGH). Place it after a BORROW / RELEASE / swap leg so the whole
///         userOp unwinds when the position would end up too close to liquidation.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific), exactly 168 bytes:
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0); // reserved, not validated
/// @notice         address yieldSource = BytesLib.toAddress(data, 32); // AaveV4ReserveKey.computeMarketKey(spoke,
/// supplyReserveId, borrowReserveId) @notice         address spoke = BytesLib.toAddress(data, 52); // the ONLY call
/// target (staticcall)
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 72); // identity only
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 104); // identity only
/// @notice         uint256 minHealthFactor = BytesLib.toUint256(data, 136); // WAD; 1e18 = Spoke
/// HEALTH_FACTOR_LIQUIDATION_THRESHOLD @dev HEALTH FACTOR. `IAaveV4Spoke.getUserAccountData(account).healthFactor`,
/// WAD-scaled, `type(uint256).max`
///      when the account has no debt on the Spoke. The read is SPOKE-WIDE (cross-reserve): the reserve ids name
///      the market this guard belongs to so its leaf lands in the same whitelist bucket as the PLEDGE / BORROW /
///      RELEASE legs it protects (`computeMarketKey(spoke, supplyReserveId, borrowReserveId)` at offset 32, pinned
///      by `AaveV4ReserveKey.requireHeaderIsMarketKey`); they do NOT scope the check.
///      STALE CONFIG CAVEAT. The Spoke evaluates health with the account's STORED dynamic-config keys. `borrow`
///      and a flagged `withdraw` refresh the keys of all flagged reserves first, so after a BORROW / RELEASE leg
///      (the intended position) the number is exactly the Spoke's post-action health. After a PLEDGE-only or
///      swap-only leg it is the health under the last-refreshed config; if governance has since tightened a
///      collateral factor the real figure is lower. Size `minHealthFactor` with margin above 1e18 accordingly.
///      WHERE THE CHECK RUNS. `_buildHookExecutions` returns no executions, so `build()` yields exactly
///      `[preExecute, postExecute]`. The executor builds hook N only after hook N-1 executed, so the build-time
///      read already observes post-action state; `_postExecute` repeats the read as the authoritative one from
///      inside the account's batch, so the guard holds under any executor scheduling.
///      The Spoke comes from calldata (one deployment for every Spoke, as in the V2 family); `view` on the
///      interface makes the read a STATICCALL, so a calldata-supplied Spoke has no state-changing surface.
///      `minHealthFactor` below 1e18 is a signing bug (the Spoke already enforces 1e18 on its own legs) and is
///      rejected; `type(uint256).max` is allowed and means "must have no debt".
contract AaveV4HealthCheckHook is BaseHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Exact calldata length
    uint256 private constant DATA_LENGTH = 168;
    uint256 private constant SPOKE_OFFSET = 52;
    uint256 private constant SUPPLY_RESERVE_ID_OFFSET = 72;
    uint256 private constant BORROW_RESERVE_ID_OFFSET = 104;
    uint256 private constant MIN_HEALTH_FACTOR_OFFSET = 136;

    /// @dev WAD health factor at which the Spoke liquidates (`HEALTH_FACTOR_LIQUIDATION_THRESHOLD` upstream)
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The guard tripped: the account's health factor is below the committed minimum
    error HEALTH_FACTOR_BELOW_MINIMUM(uint256 healthFactor, uint256 minHealthFactor);
    /// @notice `minHealthFactor` is below the liquidation line (1e18)
    error INVALID_MIN_HEALTH_FACTOR();
    /// @notice Calldata is not exactly 168 bytes
    error INVALID_DATA_LENGTH();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Vars {
        address marketKey;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 minHealthFactor;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Health Check";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Reverts unless the account's Aave V4 Spoke health factor is at or above the minimum";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice The WAD health factor this guard would enforce for `account` with `data`, evaluated now
    /// @dev Lets the OMS size a leg against the exact number the guard reads on-chain. `type(uint256).max` = no debt.
    /// @param data The 168-byte hook data
    /// @param account The account to evaluate
    /// @return The WAD health factor
    function previewHealthFactor(bytes calldata data, address account) external view returns (uint256) {
        Vars memory vars = _decode(data);
        return _healthFactor(vars.spoke, account);
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        _requireHealthy(account, data);
        executions = new Execution[](0);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    /// @dev Identity (market key, spoke, reserve ids) followed by `minHealthFactor` (136 bytes total). The threshold
    ///      IS part of the leaf: a SuperVault strategy's permission commits to an exact minimum, so an execution
    ///      signer holding a proof for one margin cannot present it with a lower one. Each distinct threshold is
    ///      therefore a distinct leaf. The ERC-4337 path commits the full calldata anyway.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        Vars memory vars = _decode(data);
        return abi.encodePacked(
            vars.marketKey, vars.spoke, vars.supplyReserveId, vars.borrowReserveId, vars.minHealthFactor
        );
    }

    /// @inheritdoc ISuperHookInflowOutflow
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

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Authoritative read, from inside the account's batch after every preceding hook executed
    function _postExecute(address, address account, bytes calldata data) internal view override {
        _requireHealthy(account, data);
    }

    /// @dev Guard only — forwards the previous hook's outAmount + outToken
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    function _requireHealthy(address account, bytes memory data) internal view {
        Vars memory vars = _decode(data);
        uint256 healthFactor = _healthFactor(vars.spoke, account);
        if (healthFactor < vars.minHealthFactor) {
            revert HEALTH_FACTOR_BELOW_MINIMUM(healthFactor, vars.minHealthFactor);
        }
    }

    /// @dev Pure: length, zero checks, header pin, threshold floor. Reads no state so `inspect()` stays pure.
    function _decode(bytes memory data) internal pure returns (Vars memory vars) {
        if (data.length != DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.marketKey = data.extractYieldSource();
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.minHealthFactor = BytesLib.toUint256(data, MIN_HEALTH_FACTOR_OFFSET);

        if (vars.marketKey == address(0) || vars.spoke == address(0)) revert ADDRESS_NOT_VALID();
        AaveV4ReserveKey.requireHeaderIsMarketKey(
            vars.marketKey, vars.spoke, vars.supplyReserveId, vars.borrowReserveId
        );
        if (vars.minHealthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD) revert INVALID_MIN_HEALTH_FACTOR();
    }

    /// @dev Spoke-wide WAD health factor; `type(uint256).max` when the account has no debt
    function _healthFactor(address spoke, address account) internal view returns (uint256) {
        return IAaveV4Spoke(spoke).getUserAccountData(account).healthFactor;
    }
}
