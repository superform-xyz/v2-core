// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { IOpenOceanCaller } from "../../../vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanDynamicAmountUpdater } from "../../../libraries/OpenOceanDynamicAmountUpdater.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapOpenOceanHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         bytes     placeholder      = BytesLib.slice(data, 0, 52);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payloadLength    = BytesLib.toUint256(data, 189);
/// @notice         bytes     txData_          = BytesLib.slice(data, 221, payloadLength);
contract ApproveAndSwapOpenOceanHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    IOpenOceanExchange public immutable OPENOCEAN_ROUTER;
    address public immutable OPENOCEAN_REFERRER;

    address public immutable NATIVE;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = SwapCalldataLayout.USE_PREV_HOOK_OFFSET;
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /// @notice Thrown when inputToken and outputToken are the same address
    error SAME_INPUT_OUTPUT_TOKEN();

    /// @notice Thrown when dstToken in txData does not match the expected outputToken
    error OUTPUT_TOKEN_MISMATCH();

    /// @notice Thrown when inputToken in hookData does not match srcToken in txData
    error INPUT_TOKEN_MISMATCH();

    /// @notice Thrown when resolved execution amount is zero
    error ZERO_EXECUTION_AMOUNT();

    constructor(
        address router_,
        address referrer_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0) || referrer_ == address(0)) revert ADDRESS_NOT_VALID();
        OPENOCEAN_ROUTER = IOpenOceanExchange(router_);
        OPENOCEAN_REFERRER = referrer_;
        NATIVE = nativeToken_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap OpenOcean";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via OpenOcean aggregator";
    }

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
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        bytes memory txData_ =
            BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET));

        uint256 executionAmount = inputAmount;
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            inputAmount = executionAmount;
        }

        {
            address srcToken;
            address dstToken;
            (txData_, srcToken, dstToken) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
                txData_, OPENOCEAN_REFERRER, account, executionAmount, BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET)
            );

            _validateTokenPair(inputToken, outputToken);
            _validateTokenPair(srcToken, outputToken);
            if (!_isSameToken(inputToken, srcToken)) revert INPUT_TOKEN_MISMATCH();
            if (!_isSameToken(dstToken, outputToken)) revert OUTPUT_TOKEN_MISMATCH();

            if (_isNative(srcToken)) {
                executions = new Execution[](1);
                executions[0] =
                    Execution({ target: address(OPENOCEAN_ROUTER), value: executionAmount, callData: txData_ });
                return executions;
            }
        }

        executions = new Execution[](4);
        executions[0] = Execution({
            target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (address(OPENOCEAN_ROUTER), 0))
        });

        executions[1] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(OPENOCEAN_ROUTER), inputAmount))
        });

        executions[2] = Execution({ target: address(OPENOCEAN_ROUTER), value: 0, callData: txData_ });

        executions[3] = Execution({
            target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (address(OPENOCEAN_ROUTER), 0))
        });
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
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
        uint256 txDataLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory txData_ = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, txDataLength);

        (, IOpenOceanExchange.SwapDescription memory desc,) = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );

        return abi.encodePacked(desc.dstReceiver);
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

    // ─── Internal ────────────────────────────────────────────────────────────

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (_isNative(outputToken)) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }

    function _isNative(address token_) private view returns (bool) {
        return token_ == address(0) || token_ == NATIVE;
    }

    function _validateTokenPair(address inputToken_, address outputToken_) private view {
        if (_isSameToken(inputToken_, outputToken_)) revert SAME_INPUT_OUTPUT_TOKEN();
    }

    function _isSameToken(address tokenA_, address tokenB_) private view returns (bool) {
        if (_isNative(tokenA_) && _isNative(tokenB_)) {
            return true;
        }
        return tokenA_ == tokenB_;
    }
}
