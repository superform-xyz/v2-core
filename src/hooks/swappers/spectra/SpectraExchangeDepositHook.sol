// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import { ISpectraRouter } from "../../../vendor/spectra/ISpectraRouter.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { SpectraCommands } from "../../../vendor/spectra/SpectraCommands.sol";

/// @title SpectraExchangeDepositHook
/// @author Superform Labs
/// @dev Payload: abi.encode(address pt, uint256 value, bytes txData_)
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         bytes32   placeholder0     = BytesLib.toBytes32(data, 0);
/// @notice         address   placeholder1     = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload          = BytesLib.slice(data, 221, payload_paramLength);
contract SpectraExchangeDepositHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    bytes4 private constant EXECUTE_SELECTOR = bytes4(keccak256("execute(bytes,bytes[])"));
    bytes4 private constant EXECUTE_DEADLINE_SELECTOR = bytes4(keccak256("execute(bytes,bytes[],uint256)"));

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISpectraRouter public immutable ROUTER;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PT();
    error INVALID_IBT();
    error LENGTH_MISMATCH();
    error INVALID_COMMAND();
    error INVALID_SELECTOR();
    error INVALID_DEADLINE();
    error INVALID_RECIPIENT();
    error INVALID_MIN_SHARES();
    error INVALID_LAST_COMMAND();
    error INVALID_TRANSFER_TOKEN();

    /// @notice Thrown when pt in payload does not match the expected outputToken
    error OUTPUT_TOKEN_MISMATCH();

    constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        ROUTER = ISpectraRouter(router_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Spectra Exchange Deposit";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Deposits into a yield position via Spectra exchange";
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
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
        (address pt, uint256 value, bytes memory txData_) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (address, uint256, bytes));

        // Validate that the pt in payload matches the header's outputToken
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (headerOutputToken != pt) revert OUTPUT_TOKEN_MISMATCH();

        return _buildFromTxData(prevHook, account, pt, usePrevHookAmount, value, txData_);
    }

    function _buildFromTxData(
        address prevHook,
        address account,
        address pt,
        bool usePrevHookAmount,
        uint256 value,
        bytes memory txData_
    )
        private
        view
        returns (Execution[] memory executions)
    {
        bytes memory updatedTxData = _validateTxData(txData_, account, usePrevHookAmount, prevHook, pt);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(ROUTER),
            value: usePrevHookAmount && value > 0 ? ISuperHookResult(prevHook).getOutAmount(account) : value,
            callData: usePrevHookAmount ? updatedTxData : txData_
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(outputToken);
    }

    // ─── ISuperHookSwap ──────────────────────────────────────────────────────

    /// @inheritdoc ISuperHookSwap
    function encodeSwapData(
        ISuperHookSwap.SwapHeader calldata header,
        bytes calldata payload
    )
        external
        pure
        override
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(SwapCalldataLayout.HEADER_SIZE)),
            bytes20(header.inputToken),
            bytes20(header.outputToken),
            bytes32(header.inputAmount),
            bytes32(header.outputQuote),
            bytes32(header.outputMin),
            bytes1(header.usePrevHookAmount ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputAmount(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputQuote(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputMin(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodePayload(bytes calldata data) external pure override returns (bytes memory) {
        uint256 payloadLen = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        return BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLen);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    struct ValidateTxDataParams {
        bytes4 selector;
        bytes[] updatedInputs;
        bytes commandsData;
        bytes[] inputs;
        uint256 inputsLength;
        uint256 deadline;
        uint256[] commands;
        uint256 commandsLength;
        address pt;
        uint256 assets;
        address ptRecipient;
        address ytRecipient;
        address ibt;
        address recipient;
        uint256 minShares;
        address transferToken;
    }

    function _validateTxData(
        bytes memory data,
        address account,
        bool usePrevHookAmount,
        address prevHook,
        address pt
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        ValidateTxDataParams memory params;
        params.selector = bytes4(BytesLib.toBytes32(data, 0));

        if (params.selector == EXECUTE_SELECTOR) {
            (params.commandsData, params.inputs) =
                abi.decode(BytesLib.slice(data, 4, data.length - 4), (bytes, bytes[]));
            params.inputsLength = params.inputs.length;
            params.updatedInputs = new bytes[](params.inputsLength);
        } else if (params.selector == EXECUTE_DEADLINE_SELECTOR) {
            (params.commandsData, params.inputs, params.deadline) =
                abi.decode(BytesLib.slice(data, 4, data.length - 4), (bytes, bytes[], uint256));
            if (params.deadline < block.timestamp) revert INVALID_DEADLINE();
            params.inputsLength = params.inputs.length;
            params.updatedInputs = new bytes[](params.inputsLength);
        } else {
            revert INVALID_SELECTOR();
        }

        params.commands = _validateCommands(params.commandsData, params.inputsLength);
        params.commandsLength = params.commands.length;

        // last command cannot be TRANSFER_FROM
        if (params.commands[params.commandsLength - 1] == SpectraCommands.TRANSFER_FROM) {
            revert INVALID_LAST_COMMAND();
        }

        for (uint256 i; i < params.commandsLength; ++i) {
            uint256 command = params.commands[i];
            bytes memory input = params.inputs[i];
            if (command == SpectraCommands.DEPOSIT_ASSET_IN_PT) {
                (params.pt, params.assets, params.ptRecipient, params.ytRecipient, params.minShares) =
                    abi.decode(input, (address, uint256, address, address, uint256));

                if (params.minShares == 0) revert INVALID_MIN_SHARES();
                if (params.pt != pt) revert INVALID_PT();
                if (params.ptRecipient != account || params.ytRecipient != account) revert INVALID_RECIPIENT();

                if (usePrevHookAmount) {
                    params.assets = ISuperHookResult(prevHook).getOutAmount(account);
                }
                if (params.assets == 0) revert AMOUNT_NOT_VALID();

                params.updatedInputs[i] =
                    abi.encode(params.pt, params.assets, params.ptRecipient, params.ytRecipient, params.minShares);
            } else if (command == SpectraCommands.DEPOSIT_ASSET_IN_IBT) {
                (params.ibt, params.assets, params.recipient) = abi.decode(input, (address, uint256, address));
                if (params.ibt == address(0)) revert INVALID_IBT();
                if (params.recipient != account) revert INVALID_RECIPIENT();

                if (usePrevHookAmount) {
                    params.assets = ISuperHookResult(prevHook).getOutAmount(account);
                }
                if (params.assets == 0) revert AMOUNT_NOT_VALID();

                params.updatedInputs[i] = abi.encode(params.ibt, params.assets, params.recipient);
            } else if (command == SpectraCommands.TRANSFER_FROM) {
                (params.transferToken, params.assets) = abi.decode(input, (address, uint256));
                if (params.transferToken == address(0)) revert INVALID_TRANSFER_TOKEN();

                if (usePrevHookAmount) {
                    params.assets = ISuperHookResult(prevHook).getOutAmount(account);
                }
                if (params.assets == 0) revert AMOUNT_NOT_VALID();
                params.updatedInputs[i] = abi.encode(params.transferToken, params.assets);
            }
        }

        updatedTxData = _encodeResult(params);
    }

    function _encodeResult(ValidateTxDataParams memory params) private pure returns (bytes memory) {
        if (params.deadline > 0) {
            return abi.encodeWithSelector(EXECUTE_DEADLINE_SELECTOR, params.commandsData, params.updatedInputs, params.deadline);
        }
        return abi.encodeWithSelector(EXECUTE_SELECTOR, params.commandsData, params.updatedInputs);
    }

    function _validateCommands(
        bytes memory _commands,
        uint256 inputsLength
    )
        private
        pure
        returns (uint256[] memory commands)
    {
        uint256 commandsLength = _commands.length;
        if (commandsLength != inputsLength) {
            revert LENGTH_MISMATCH();
        }

        commands = new uint256[](commandsLength);
        for (uint256 i; i < commandsLength; ++i) {
            bytes1 commandType = _commands[i];

            uint256 command = uint8(commandType & SpectraCommands.COMMAND_TYPE_MASK);
            if (
                command != SpectraCommands.DEPOSIT_ASSET_IN_PT && command != SpectraCommands.DEPOSIT_ASSET_IN_IBT
                    && command != SpectraCommands.TRANSFER_FROM
            ) {
                revert INVALID_COMMAND();
            }
            commands[i] = command;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }
}
