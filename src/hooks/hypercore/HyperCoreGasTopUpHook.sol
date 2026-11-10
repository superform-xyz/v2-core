// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";

/// @title HyperCoreGasTopUpHook
/// @author Superform Labs
/// @notice Sends an independently funded native HYPE reserve from the account to HyperCore
/// @dev The HyperEVM system credits the native transfer's sender, so the smart account must execute
///      the transfer. This hook does not submit a CoreWriter action or report later Core application.
///      The bundler reserves original native principal separately; the signed reserve must never be
///      resized or derived from the previous hook's output.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint256 amountNative = BytesLib.toUint256(data, 52);
contract HyperCoreGasTopUpHook is BaseHook, ISuperHookInflowOutflow {
    /// @notice The mainnet HyperCore native HYPE system recipient; deployment is HyperEVM-only
    address public constant HYPE_SYSTEM_ADDRESS = 0x2222222222222222222222222222222222222222;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant DATA_LENGTH = 84;

    /// @notice Thrown when the payload is not exactly the declared 84-byte layout
    error DATA_NOT_VALID();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.HYPERCORE) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "HyperCore Gas Top-Up";
    }

    /// @notice One-sentence description of the hook's operation
    function description() external pure override returns (string memory) {
        return "Funds the account's HyperCore HYPE gas reserve";
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        if (data.length != DATA_LENGTH) revert DATA_NOT_VALID();
        uint256 amountNative = BytesLib.toUint256(data, AMOUNT_POSITION);
        if (amountNative == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({ target: HYPE_SYSTEM_ADDRESS, value: amountNative, callData: "" });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata) external pure override returns (bytes memory) {
        return abi.encodePacked(HYPE_SYSTEM_ADDRESS);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev S2: this signed fee instruction has no resizable user amount.
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (AmountMeta[] memory meta) {
        meta = new AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev Advertise decode-only sizing without the outflow rewrite interface.
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @dev Spending native balance invalidates upstream output; downstream consumers must use explicit amounts.
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.TRANSFORM;
    }
}
