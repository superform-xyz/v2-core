// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order
} from "../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";

/// @title PendleRouterSwapHook
/// @author Superform Labs
/// @notice Hook for swapping tokens via Pendle Router V4
/// @dev Payload: abi.encode(address yieldSource, uint256 value, bytes txData_)
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
/// @custom:deprecated Use PendleUnifiedHook instead which supports all Pendle operations including swap routing for redemptions
contract PendleRouterSwapHook is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow {

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ORDER_EXPIRED();
    error EPS_NOT_VALID();
    error MARKET_NOT_VALID();
    error INVALID_SWAP_TYPE();
    error MIN_OUT_NOT_VALID();
    error RECEIVER_NOT_VALID();
    error AMOUNT_IN_NOT_VALID();
    error INVALID_GUESS_PT_OUT();
    error MAKING_AMOUNT_NOT_VALID();
    error OUTPUT_TOKEN_MISMATCH();

    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Pendle Router Swap";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via Pendle router";
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
        (address pendleMarket, uint256 value, bytes memory txData_) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (address, uint256, bytes));

        bytes memory updatedTxData = _validateTxData(txData_, account, usePrevHookAmount, prevHook, pendleMarket);
        bytes memory finalTxData = usePrevHookAmount ? updatedTxData : txData_;

        // Extract tokenIn & compute execValue
        (bool isTokenForPt, address tokenIn) = _extractTokenIn(finalTxData);
        uint256 netTokenIn = usePrevHookAmount ? ISuperHookResult(prevHook).getOutAmount(account) : value;

        uint256 execValue = (isTokenForPt && tokenIn == address(0)) ? netTokenIn : 0;

        // Validate header outputToken matches txData-derived output
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (headerOutputToken != _decodeTokenOut(finalTxData)) revert OUTPUT_TOKEN_MISMATCH();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: execValue,
            callData: finalTxData
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(outputToken);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
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
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _validateTxData(
        bytes memory data,
        address account,
        bool usePrevHookAmount,
        address prevHook,
        address pendleMarket
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        bytes4 selector = bytes4(BytesLib.toBytes32(data, 0));
        bytes memory encoded = BytesLib.slice(data, 4, data.length - 4);
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (
                address receiver,
                address market,
                uint256 minPtOut,
                ApproxParams memory guessPtOut,
                TokenInput memory input,
                LimitOrderData memory limit
            ) = abi.decode(encoded, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

            if (receiver != account) revert RECEIVER_NOT_VALID();
            if (market != pendleMarket) revert MARKET_NOT_VALID();
            if (minPtOut == 0) revert MIN_OUT_NOT_VALID();

            if (guessPtOut.guessMin > guessPtOut.guessMax) revert INVALID_GUESS_PT_OUT();
            if (guessPtOut.eps > 1e18) revert EPS_NOT_VALID();

            if (usePrevHookAmount) {
                input.netTokenIn = ISuperHookResult(prevHook).getOutAmount(account);
            }
            if (input.netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();

            if (limit.normalFills.length > 0) {
                _validateFillOrders(limit.normalFills);
            }
            if (limit.flashFills.length > 0) {
                _validateFillOrders(limit.flashFills);
            }

            updatedTxData = abi.encodeWithSelector(selector, receiver, market, minPtOut, guessPtOut, input, limit);
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            (
                address receiver,
                address market,
                uint256 exactPtIn,
                TokenOutput memory output,
                LimitOrderData memory limit
            ) = abi.decode(encoded, (address, address, uint256, TokenOutput, LimitOrderData));

            if (receiver != account) revert RECEIVER_NOT_VALID();
            if (market != pendleMarket) revert MARKET_NOT_VALID();

            if (usePrevHookAmount) {
                exactPtIn = ISuperHookResult(prevHook).getOutAmount(account);
            }
            if (exactPtIn == 0) revert AMOUNT_IN_NOT_VALID();

            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

            if (limit.normalFills.length > 0) {
                _validateFillOrders(limit.normalFills);
            }
            if (limit.flashFills.length > 0) {
                _validateFillOrders(limit.flashFills);
            }

            updatedTxData = abi.encodeWithSelector(selector, receiver, market, exactPtIn, output, limit);
        } else {
            revert INVALID_SWAP_TYPE();
        }
    }

    function _validateFillOrders(FillOrderParams[] memory fills) internal view {
        for (uint256 i; i < fills.length; ++i) {
            if (fills[i].makingAmount == 0) revert MAKING_AMOUNT_NOT_VALID();
            _validateOrder(fills[i].order);
        }
    }

    function _validateOrder(Order memory order) internal view {
        if (order.expiry < block.timestamp) revert ORDER_EXPIRED();
        if (order.maker == address(0) || order.receiver == address(0)) revert ADDRESS_NOT_VALID();
    }

    function _decodeTokenOut(bytes memory data) private view returns (address tokenOut) {
        bytes4 selector = bytes4(BytesLib.toBytes32(data, 0));
        bytes memory encoded = BytesLib.slice(data, 4, data.length - 4);
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (, address market,,,,) =
                abi.decode(encoded, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
            (, tokenOut,) = IPendleMarket(market).readTokens();
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            (,, , TokenOutput memory output,) =
                abi.decode(encoded, (address, address, uint256, TokenOutput, LimitOrderData));
            tokenOut = output.tokenOut;
        } else {
            revert INVALID_SWAP_TYPE();
        }
    }

    function _extractTokenIn(bytes memory txData) private pure returns (bool isTokenForPt, address tokenIn) {
        bytes4 selector = bytes4(BytesLib.slice(txData, 0, 4));
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (, , , , TokenInput memory input, ) = abi.decode(
                BytesLib.slice(txData, 4, txData.length - 4),
                (address, address, uint256, ApproxParams, TokenInput, LimitOrderData)
            );
            return (true, input.tokenIn);
        }
        return (false, address(0));
    }

    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }
}
