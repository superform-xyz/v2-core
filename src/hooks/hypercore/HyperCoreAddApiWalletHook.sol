// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BaseHyperCoreWriterHook } from "./BaseHyperCoreWriterHook.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

/// @title HyperCoreAddApiWalletHook
/// @author Superform Labs
/// @notice Enrols an API wallet (agent) on HyperCore for the executing account
/// @dev CoreWriter action 9, arguments (address agent, string agentName).
/// @dev The enrolled agent expires exactly 90 days from the enrolment block — not the 180 days of
///      the API path. Renewal is mandatory, not optional.
/// @dev SECURITY: agentName is the eviction key. Re-enrolling an existing name with a different
///      address replaces the prior key within seconds (~6.2s measured on mainnet). A signed intent
///      whose name collides with an existing agent silently revokes that agent, so this field must
///      never be attacker-chosen.
/// @dev An empty agentName is the default unnamed API wallet slot and is a VALID input. Do not add
///      a zero-length rejection.
/// @dev CoreWriter performs no validation and cannot revert. Payload correctness is entirely this
///      hook's responsibility.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address agent = BytesLib.toAddress(data, 52);
/// @notice         uint256 agentName_paramLength = BytesLib.toUint256(data, 72);
/// @notice         bytes agentName = BytesLib.slice(data, 104, agentName_paramLength);
contract HyperCoreAddApiWalletHook is BaseHyperCoreWriterHook {
    uint256 private constant AGENT_POSITION = 52;
    uint256 private constant AGENT_NAME_LENGTH_POSITION = 72;
    uint256 private constant AGENT_NAME_POSITION = 104;
    uint256 private constant MIN_DATA_LENGTH = 104;

    /// @notice Upper bound on the agent name, in bytes
    /// @dev A real bound, not hygiene. Without it a signed intent can smuggle an arbitrarily large
    ///      blob into a payload CoreWriter will accept and ignore — gas griefing against HyperEVM's
    ///      3M small-block limit. Hyperliquid agent names are short by construction.
    uint256 private constant MAX_AGENT_NAME_LENGTH = 64;

    constructor(address coreWriter_) BaseHyperCoreWriterHook(coreWriter_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "HyperCore Add API Wallet";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Enrols a trading agent on HyperCore";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < MIN_DATA_LENGTH) revert DATA_NOT_VALID();

        address agent = BytesLib.toAddress(data, AGENT_POSITION);
        if (agent == address(0)) revert ADDRESS_NOT_VALID();

        uint256 nameLen = BytesLib.toUint256(data, AGENT_NAME_LENGTH_POSITION);
        // Bound before the addition: MIN_DATA_LENGTH + nameLen is checked arithmetic and would
        // panic (0x11) on a near-max length instead of surfacing the custom error.
        if (nameLen > MAX_AGENT_NAME_LENGTH) revert DATA_NOT_VALID();
        // Strict equality: exactly one trailing field, so the total is fully determined. Rejects
        // both trailing bytes and an under-declared length.
        if (data.length != MIN_DATA_LENGTH + nameLen) revert DATA_NOT_VALID();

        // NOTE: nameLen == 0 is deliberately permitted — it is the default unnamed API wallet slot.
        string memory agentName = string(BytesLib.slice(data, AGENT_NAME_POSITION, nameLen));

        executions = _coreWriterExecution(ACTION_ADD_API_WALLET, abi.encode(agent, agentName));
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev PROTOCOL REQUIREMENT: inspector functions MUST only return addresses
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return abi.encodePacked(CORE_WRITER, BytesLib.toAddress(data, AGENT_POSITION));
    }
}
