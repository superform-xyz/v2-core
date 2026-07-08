// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPendleRouterV4, TokenOutput } from "../../../vendor/pendle/IPendleRouterV4.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";

/// @title PendleRouterRedeemHook
/// @author Superform Labs
/// @notice Hook for redeeming PT+YT via Pendle Router V4
/// @dev Payload: abi.encode(address yieldSource, address yt, address pt, address tokenOut, uint256 minTokenOut, TokenOutput output)
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
/// @custom:deprecated Use PendleUnifiedHook instead which supports swap routing for tokenOut that is not directly redeemable from SY
contract PendleRouterRedeemHook is
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

    // Struct for decoded parameters
    struct DecodedParams {
        uint256 amountFromData;
        address yt;
        address pt;
        address tokenOut;
        uint256 minTokenOut;
        bool usePrevHookAmount;
        TokenOutput output;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error YT_NOT_VALID();
    error RECEIVER_NOT_VALID();
    error TOKEN_OUT_NOT_VALID();
    error MIN_TOKEN_OUT_NOT_VALID();
    error INVALID_DATA_LENGTH();
    error SY_NOT_VALID();
    error TOKEN_OUT_NOT_LISTED();
    error OUTPUT_TOKEN_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Pendle Router Redeem";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Redeems Pendle PT tokens for underlying assets";
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
        DecodedParams memory params = _decodeAndValidateData(data);

        uint256 finalAmount = _determineFinalAmount(params.amountFromData, params.usePrevHookAmount, prevHook, account);

        executions = new Execution[](3);
        executions[0] = Execution({
            target: params.pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount))
        });
        executions[1] = Execution({
            target: params.yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount))
        });
        executions[2] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(IPendleRouterV4.redeemPyToToken, (account, params.yt, finalAmount, params.output))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();
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

    /// @dev Decodes hook data, validates parameters, and returns them.
    function _decodeAndValidateData(bytes calldata data) private view returns (DecodedParams memory params) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        params.amountFromData = BytesLib.toUint256(data, AMOUNT_POSITION);
        params.usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        // Decode payload: abi.encode(address yieldSource, address yt, address pt, address tokenOut, uint256 minTokenOut, TokenOutput output)
        (, params.yt, params.pt, params.tokenOut, params.minTokenOut, params.output) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (address, address, address, address, uint256, TokenOutput));

        // Basic validation
        if (params.yt == address(0)) revert YT_NOT_VALID();
        if (params.tokenOut == address(0)) revert TOKEN_OUT_NOT_VALID();
        if (params.minTokenOut == 0) revert MIN_TOKEN_OUT_NOT_VALID();

        // Validate consistency between explicitly passed params and struct params
        if (params.output.tokenOut != params.tokenOut) revert TOKEN_OUT_NOT_VALID();
        if (params.output.minTokenOut != params.minTokenOut) revert MIN_TOKEN_OUT_NOT_VALID();

        // Validate header outputToken matches payload tokenOut
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (headerOutputToken != params.tokenOut) revert OUTPUT_TOKEN_MISMATCH();

        // Validate tokenOut against the SY derived from YT
        (bool ok, bytes memory ret) = params.yt.staticcall(abi.encodeWithSignature("SY()"));
        if (!ok || ret.length < 32) revert SY_NOT_VALID();
        if (
            !IStandardizedYield(abi.decode(ret, (address))).isValidTokenOut(
                params.tokenOut
            )
        ) revert TOKEN_OUT_NOT_LISTED();
    }

    /// @dev Determines the final amount to use based on the flag and previous hook.
    function _determineFinalAmount(
        uint256 amountFromData,
        bool usePrevHookAmount,
        address prevHook,
        address account
    )
        private
        view
        returns (uint256 finalAmount)
    {
        if (usePrevHookAmount) {
            finalAmount = ISuperHookResult(prevHook).getOutAmount(account);
            if (finalAmount == 0) revert AMOUNT_NOT_VALID();
        } else {
            if (amountFromData == 0) revert AMOUNT_NOT_VALID();
            finalAmount = amountFromData;
        }
    }

    /// @dev Gets the balance of the output token for the account.
    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }
}
