// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../vendor/morpho/IMorphoVaultV2.sol";

/// @title ForceDeallocateMorphoHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook that calls Morpho Vault V2's forceDeallocate() for emergency asset extraction
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address morphoVaultV2 = BytesLib.toAddress(data, 32);
/// @notice         address adapter = BytesLib.toAddress(data, 52);
/// @notice         uint256 assets = BytesLib.toUint256(data, 72);
/// @notice         uint256 deadline = BytesLib.toUint256(data, 104);
/// @notice         uint256 maxPenaltyBps = BytesLib.toUint256(data, 136);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 168);
/// @notice         bytes adapterData = BytesLib.slice(data, 169, data.length - 169);
/// @dev TRUST ASSUMPTION: This hook trusts Morpho Vault V2's internal reentrancy guards and adapter validation.
///      The hook pre-checks the penalty via forceDeallocatePenalty() and validates deadline before execution.
///      onBehalf is always set to the executing smart account (msg.sender).
contract ForceDeallocateMorphoHook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);
    error PENALTY_TOO_HIGH(uint256 actualPenaltyBps, uint256 maxPenaltyBps);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant ADAPTER_OFFSET = 52;
    uint256 private constant ASSETS_OFFSET = 72;
    uint256 private constant DEADLINE_OFFSET = 104;
    uint256 private constant MAX_PENALTY_BPS_OFFSET = 136;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 168;
    uint256 private constant ADAPTER_DATA_OFFSET = 169;
    uint256 private constant MIN_DATA_LENGTH = 169;

    /// @notice Conversion factor from WAD (1e18) to BPS (1e4): 1e18 / 1e4 = 1e14
    uint256 private constant WAD_TO_BPS = 1e14;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Force Deallocate Morpho";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Force deallocates liquidity from a Morpho market";
    }


    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < MIN_DATA_LENGTH) revert AMOUNT_NOT_VALID();

        address vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        address adapter = data.toAddress(ADAPTER_OFFSET);
        if (adapter == address(0)) revert ADDRESS_NOT_VALID();

        uint256 assets = data.toUint256(ASSETS_OFFSET);

        // Deadline check (0 = no deadline)
        {
            uint256 deadline = data.toUint256(DEADLINE_OFFSET);
            if (deadline != 0 && block.timestamp > deadline) {
                revert EXPIRED_DEADLINE(deadline, block.timestamp);
            }
        }

        // Use previous hook amount if specified
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (assets == 0) revert AMOUNT_NOT_VALID();

        // Pre-check penalty against tolerance (ceiling division to never understate penalty)
        {
            uint256 penaltyBps = (IMorphoVaultV2(vault).forceDeallocatePenalty(adapter) + WAD_TO_BPS - 1) / WAD_TO_BPS;
            uint256 maxPenaltyBps = data.toUint256(MAX_PENALTY_BPS_OFFSET);
            if (penaltyBps > maxPenaltyBps) {
                revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
            }
        }

        // Extract adapter data (raw tail)
        bytes memory adapterData;
        if (data.length > ADAPTER_DATA_OFFSET) {
            adapterData = data.slice(ADAPTER_DATA_OFFSET, data.length - ADAPTER_DATA_OFFSET);
        }

        // Build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IMorphoVaultV2.forceDeallocate, (adapter, adapterData, assets, account))
        });

    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice On-chain pre-execution: re-validates deadline and penalty tolerance, then sets outAmount.
    /// @dev outAmount is set to the requested `assets` value because `forceDeallocate` deallocates exactly
    ///      `assets` worth of underlying — the penalty is a separate share burn on `onBehalf`, not a reduction
    ///      in assets received.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        // Re-validate deadline on-chain (0 = no deadline)
        {
            uint256 deadline = data.toUint256(DEADLINE_OFFSET);
            if (deadline != 0 && block.timestamp > deadline) {
                revert EXPIRED_DEADLINE(deadline, block.timestamp);
            }
        }

        // Re-validate penalty on-chain (ceiling division to never understate penalty)
        {
            address vault = data.extractYieldSource();
            address adapter = data.toAddress(ADAPTER_OFFSET);
            uint256 penaltyBps = (IMorphoVaultV2(vault).forceDeallocatePenalty(adapter) + WAD_TO_BPS - 1) / WAD_TO_BPS;
            uint256 maxPenaltyBps = data.toUint256(MAX_PENALTY_BPS_OFFSET);
            if (penaltyBps > maxPenaltyBps) {
                revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
            }
        }

        uint256 assets = data.toUint256(ASSETS_OFFSET);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }
        _setOutAmount(assets, account);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address vault = data.extractYieldSource();
        address adapter = data.toAddress(ADAPTER_OFFSET);
        return abi.encodePacked(vault, adapter);
    }
}
