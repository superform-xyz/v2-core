// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BytesLib } from "../../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISpectraRouter } from "../../../../vendor/spectra/ISpectraRouter.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { SpectraCommands } from "../../../../vendor/spectra/SpectraCommands.sol";

/// @title SpectraExchangeDepositHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 24);
/// @notice         uint256 value = BytesLib.toUint256(data, 25);
/// @notice         bytes txData_ = BytesLib.slice(data, 57, data.length - 57);
contract SpectraExchangeDepositHook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 24;
    uint256 private constant TX_DATA_POSITION = 57;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    ISpectraRouter public immutable router;

    struct RedeemParams {
        address asset;
        uint256 minAssets;
        uint256 sharesToBurn;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PT();
    error INVALID_IBT();
    error LENGTH_MISMATCH();
    error INVALID_COMMAND();
    error INVALID_SELECTOR();
    error INVALID_RECIPIENT();
    error INVALID_MIN_ASSETS();

    constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        router = ISpectraRouter(router_);
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
        address pt = data.extractYieldSource();
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 value = abi.decode(data[25:TX_DATA_POSITION], (uint256));
        bytes memory txData_ = data[TX_DATA_POSITION:];

        bytes memory updatedTxData = _validateTxData(data[TX_DATA_POSITION:], account, usePrevHookAmount, prevHook, pt);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(router),
            value: usePrevHookAmount ? ISuperHookResult(prevHook).outAmount() : value,
            callData: usePrevHookAmount ? updatedTxData : txData_
        });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        bytes calldata txData_ = data[TX_DATA_POSITION:];
        ValidateRedeemTxDataParams memory params;
        params.selector = bytes4(txData_[0:4]);

        if (params.selector == bytes4(keccak256("execute(bytes,bytes[])"))) {
            (params.commandsData, params.inputs) = abi.decode(txData_[4:], (bytes, bytes[]));
            params.inputsLength = params.inputs.length;
            params.updatedInputs = new bytes[](params.inputsLength);
        } else {
            revert INVALID_SELECTOR();
        }

        params.commands = _validateCommands(params.commandsData, params.inputsLength);
        params.commandsLength = params.commands.length;

        bytes memory packed = abi.encodePacked(data.extractYieldSource());

        for (uint256 i; i < params.commandsLength; ++i) {
            uint256 command = params.commands[i];
            bytes memory input = params.inputs[i];
            if (command == SpectraCommands.REDEEM_IBT_FOR_ASSET) {
                (params.asset, params.sharesToBurn, params.recipient) = abi.decode(input, (address, uint256, address));

                packed = abi.encodePacked(packed, params.asset, params.sharesToBurn, params.minAssets);
            } else if (command == SpectraCommands.REDEEM_PT_FOR_ASSET) {
                (params.pt, params.sharesToBurn, params.recipient, params.minAssets) =
                    abi.decode(input, (address, uint256, address, uint256));
                packed = abi.encodePacked(packed, params.pt, params.sharesToBurn, params.recipient, params.minAssets);
            }
        }

        return packed;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(data, account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(data, account) - outAmount;
    }
    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    struct ValidateRedeemTxDataParams {
        bytes4 selector;
        bytes[] updatedInputs;
        bytes commandsData;
        bytes[] inputs;
        uint256 inputsLength;
        uint256[] commands;
        uint256 commandsLength;
        address pt; // TODO
        address asset;
        address recipient;
        uint256 minAssets;
        uint256 sharesToBurn;
    }

    function _validateTxData(
        bytes calldata data,
        address account,
        bool usePrevHookAmount,
        address prevHook,
        address pt
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        ValidateRedeemTxDataParams memory params;
        params.selector = bytes4(data[0:4]);

        if (params.selector == bytes4(keccak256("execute(bytes,bytes[])"))) {
            (params.commandsData, params.inputs) = abi.decode(data[4:], (bytes, bytes[]));
            params.inputsLength = params.inputs.length;
            params.updatedInputs = new bytes[](params.inputsLength);
        } else {
            revert INVALID_SELECTOR();
        }

        params.commands = _validateCommands(params.commandsData, params.inputsLength);
        params.commandsLength = params.commands.length;

        for (uint256 i; i < params.commandsLength; ++i) {
            uint256 command = params.commands[i];
            bytes memory input = params.inputs[i];
            if (command == SpectraCommands.REDEEM_IBT_FOR_ASSET) {
                // https://dev.spectra.finance/technical-reference/contract-functions/router#redeem_ibt_for_asset-command

                (params.asset, params.sharesToBurn, params.recipient) =
                    abi.decode(input, (address, uint256, address));

                if (params.recipient != account) revert INVALID_RECIPIENT();

                if (usePrevHookAmount) {
                    params.sharesToBurn = ISuperHookResult(prevHook).outAmount();
                }
                if (params.sharesToBurn == 0) revert AMOUNT_NOT_VALID();

                params.updatedInputs[i] = abi.encode(params.asset, params.sharesToBurn, params.recipient);
            } else if (command == SpectraCommands.REDEEM_PT_FOR_ASSET) {
                // https://dev.spectra.finance/technical-reference/contract-functions/router#redeem_pt_for_asset-command

                (params.pt, params.sharesToBurn, params.recipient, params.minAssets) =
                    abi.decode(input, (address, uint256, address, uint256));
                if (params.recipient != account) revert INVALID_RECIPIENT();
                if (params.minAssets == 0) revert INVALID_MIN_ASSETS();

                if (usePrevHookAmount) {
                    params.assets = ISuperHookResult(prevHook).outAmount();
                }
                if (params.assets == 0) revert AMOUNT_NOT_VALID();

                params.updatedInputs[i] = abi.encode(params.ibt, params.assets, params.recipient);
            } else if (command == SpectraCommands.TRANSFER_FROM) {
                // https://dev.spectra.finance/technical-reference/contract-functions/router#transfer_from-command

                (params.transferToken, params.assets) = abi.decode(input, (address, uint256));
                if (params.transferToken == address(0)) revert INVALID_TRANSFER_TOKEN();

                if (usePrevHookAmount) {
                    params.assets = ISuperHookResult(prevHook).outAmount();
                }
                if (params.assets == 0) revert AMOUNT_NOT_VALID();
                params.updatedInputs[i] = abi.encode(params.transferToken, params.assets);
            }
        }

        if (params.selector == bytes4(keccak256("execute(bytes,bytes[])"))) {
            updatedTxData = abi.encodeWithSelector(params.selector, params.commandsData, params.updatedInputs);
        } else if (params.selector == bytes4(keccak256("execute(bytes,bytes[],uint256)"))) {
            updatedTxData =
                abi.encodeWithSelector(params.selector, params.commandsData, params.updatedInputs, params.deadline);
        }
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

        return commands;
    }

    function _decodeTokenOut(bytes calldata data) internal pure returns (address tokenOut) {
        bytes4 selector = bytes4(data[0:4]);
        bytes memory commandsData;
        bytes[] memory inputs;
        if (selector == bytes4(keccak256("execute(bytes,bytes[])"))) {
            (commandsData, inputs) = abi.decode(data[4:], (bytes, bytes[]));
        } else if (selector == bytes4(keccak256("execute(bytes,bytes[],uint256)"))) {
            (commandsData, inputs,) = abi.decode(data[4:], (bytes, bytes[], uint256));
        } else {
            revert INVALID_SELECTOR();
        }

        uint256 inputsLength = inputs.length;
        uint256[] memory commands = _validateCommands(commandsData, inputsLength);
        uint256 commandsLength = commands.length;
        for (uint256 i; i < commandsLength; ++i) {
            uint256 command = commands[i];
            bytes memory input = inputs[i];
            if (command == SpectraCommands.DEPOSIT_ASSET_IN_PT) {
                (tokenOut,,,) = abi.decode(input, (address, uint256, address, address));
            } else if (command == SpectraCommands.DEPOSIT_ASSET_IN_IBT) {
                (tokenOut,,) = abi.decode(input, (address, uint256, address));
            }
        }
    }

    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address tokenOut = _decodeTokenOut(data[TX_DATA_POSITION:]);

        if (tokenOut == address(0)) {
            return account.balance;
        }

        return IERC20(tokenOut).balanceOf(account);
    }

    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, TX_DATA_POSITION);
    }
}
