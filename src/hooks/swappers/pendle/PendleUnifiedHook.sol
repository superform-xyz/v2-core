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
    Order,
    SwapType
} from "../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";

/// @title PendleUnifiedHook
/// @author Superform Labs
/// @notice Unified hook supporting all Pendle router operations: swaps (pre-maturity) and redemptions (post-maturity)
/// @dev Merges PendleRouterSwapHook and PendleRouterRedeemHook with fix for tokenRedeemSy validation
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
contract PendleUnifiedHook is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow {

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Maximum number of fill orders allowed per array to prevent gas griefing
    uint256 private constant MAX_FILLS = 64;

    /// @dev Maximum epsilon for Pendle's binary search approximation (100% in 1e18 scale)
    uint256 private constant MAX_EPS = 1e18;

    /// @dev Maximum iterations for Pendle's binary search approximation
    uint256 private constant MAX_ITERATIONS = 256;

    /// @dev Native token sentinel address
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                 IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ORDER_EXPIRED();
    error EPS_NOT_VALID();
    error YT_NOT_VALID();
    error SY_NOT_VALID();
    error MARKET_NOT_VALID();
    error INVALID_SELECTOR();
    error MIN_OUT_NOT_VALID();
    error RECEIVER_NOT_VALID();
    error AMOUNT_IN_NOT_VALID();
    error INVALID_GUESS_PT_OUT();
    error INVALID_EXT_ROUTER();
    error MAKING_AMOUNT_NOT_VALID();
    error TOKEN_OUT_NOT_LISTED();
    error TOKEN_REDEEM_SY_NOT_VALID();
    error TOO_MANY_FILLS();
    error INVALID_MAX_ITERATION();
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
        return "Pendle Unified";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Executes unified Pendle operations (swap or redeem)";
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
        (address yieldSource, uint256 value, bytes memory txData) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (address, uint256, bytes));

        bytes4 selector = bytes4(BytesLib.toBytes32(txData, 0));

        if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            executions = _buildRedeemExecutions(prevHook, account, yieldSource, usePrevHookAmount, txData);
        } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            executions = _buildSwapTokenForPtExecutions(
                prevHook, account, yieldSource, usePrevHookAmount, value, txData
            );
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            executions = _buildSwapPtForTokenExecutions(prevHook, account, yieldSource, usePrevHookAmount, txData);
        } else {
            revert INVALID_SELECTOR();
        }

        // Validate header outputToken matches txData-derived output
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (headerOutputToken != _decodeTokenOut(txData)) revert OUTPUT_TOKEN_MISMATCH();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless — amounts are inside variable-position ABI-encoded txData per selector
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
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds executions for redeemPyToToken (PT+YT redemption)
    function _buildRedeemExecutions(
        address prevHook,
        address account,
        address yieldSource,
        bool usePrevHookAmount,
        bytes memory txData
    )
        private
        view
        returns (Execution[] memory executions)
    {
        (address receiver, address ytFromTxData, uint256 netPyIn, TokenOutput memory output) =
            abi.decode(BytesLib.slice(txData, 4, txData.length - 4), (address, address, uint256, TokenOutput));

        (address sy, address pt, address yt) = IPendleMarket(yieldSource).readTokens();
        if (sy == address(0)) revert SY_NOT_VALID();

        if (ytFromTxData != yt) revert YT_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

        if (output.swapData.swapType != SwapType.NONE) {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                revert TOKEN_REDEEM_SY_NOT_VALID();
            }
            if (output.swapData.swapType != SwapType.ETH_WETH) {
                if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                    revert INVALID_EXT_ROUTER();
                }
            }
        } else {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                revert TOKEN_OUT_NOT_LISTED();
            }
        }

        uint256 finalAmount;
        if (usePrevHookAmount) {
            finalAmount = ISuperHookResult(prevHook).getOutAmount(account);
            output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalAmount, netPyIn, output.minTokenOut);
            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();
        } else {
            finalAmount = netPyIn;
        }
        if (finalAmount == 0) revert AMOUNT_IN_NOT_VALID();

        executions = new Execution[](7);
        executions[0] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[1] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount))
        });
        executions[2] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[3] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount))
        });
        executions[4] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(IPendleRouterV4.redeemPyToToken, (account, yt, finalAmount, output))
        });
        executions[5] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[6] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
    }

    /// @dev Builds executions for swapExactTokenForPt (token → PT)
    function _buildSwapTokenForPtExecutions(
        address prevHook,
        address account,
        address yieldSource,
        bool usePrevHookAmount,
        uint256 value,
        bytes memory txData
    )
        private
        view
        returns (Execution[] memory executions)
    {
        (
            address receiver,
            address market,
            uint256 minPtOut,
            ApproxParams memory guessPtOut,
            TokenInput memory input,
            LimitOrderData memory limit
        ) = abi.decode(BytesLib.slice(txData, 4, txData.length - 4), (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        if (yieldSource != market) revert MARKET_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (minPtOut == 0) revert MIN_OUT_NOT_VALID();

        if (guessPtOut.guessMin > guessPtOut.guessMax) revert INVALID_GUESS_PT_OUT();
        if (guessPtOut.eps > MAX_EPS) revert EPS_NOT_VALID();
        if (guessPtOut.maxIteration > MAX_ITERATIONS) revert INVALID_MAX_ITERATION();

        uint256 netTokenIn;
        if (usePrevHookAmount) {
            netTokenIn = ISuperHookResult(prevHook).getOutAmount(account);
            minPtOut = HookDataUpdater.getUpdatedOutputAmount(netTokenIn, input.netTokenIn, minPtOut);
            if (minPtOut == 0) revert MIN_OUT_NOT_VALID();
            input.netTokenIn = netTokenIn;
        } else {
            netTokenIn = input.netTokenIn;
        }
        if (netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();

        _validateLimitOrders(limit);

        uint256 execValue = (input.tokenIn == address(0)) ? netTokenIn : 0;
        if (!usePrevHookAmount && value > 0 && input.tokenIn == address(0)) {
            execValue = value;
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: execValue,
            callData: abi.encodeCall(
                IPendleRouterV4.swapExactTokenForPt,
                (receiver, market, minPtOut, guessPtOut, input, limit)
            )
        });
    }

    /// @dev Builds executions for swapExactPtForToken (PT → token)
    function _buildSwapPtForTokenExecutions(
        address prevHook,
        address account,
        address yieldSource,
        bool usePrevHookAmount,
        bytes memory txData
    )
        private
        view
        returns (Execution[] memory executions)
    {
        (
            address receiver,
            address market,
            uint256 exactPtIn,
            TokenOutput memory output,
            LimitOrderData memory limit
        ) = abi.decode(BytesLib.slice(txData, 4, txData.length - 4), (address, address, uint256, TokenOutput, LimitOrderData));

        if (yieldSource != market) revert MARKET_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

        if (output.swapData.swapType != SwapType.NONE) {
            if (output.swapData.swapType != SwapType.ETH_WETH) {
                if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                    revert INVALID_EXT_ROUTER();
                }
            }
        }

        uint256 finalPtIn;
        if (usePrevHookAmount) {
            finalPtIn = ISuperHookResult(prevHook).getOutAmount(account);
            output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalPtIn, exactPtIn, output.minTokenOut);
            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();
        } else {
            finalPtIn = exactPtIn;
        }
        if (finalPtIn == 0) revert AMOUNT_IN_NOT_VALID();

        _validateLimitOrders(limit);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(
                IPendleRouterV4.swapExactPtForToken,
                (receiver, market, finalPtIn, output, limit)
            )
        });
    }

    /// @dev Validates limit order parameters
    function _validateLimitOrders(LimitOrderData memory limit) private view {
        if (limit.normalFills.length > 0) {
            _validateFillOrders(limit.normalFills);
        }
        if (limit.flashFills.length > 0) {
            _validateFillOrders(limit.flashFills);
        }
    }

    /// @dev Validates fill order parameters
    function _validateFillOrders(FillOrderParams[] memory fills) private view {
        if (fills.length > MAX_FILLS) revert TOO_MANY_FILLS();
        for (uint256 i; i < fills.length; ++i) {
            if (fills[i].makingAmount == 0) revert MAKING_AMOUNT_NOT_VALID();
            _validateOrder(fills[i].order);
        }
    }

    /// @dev Validates individual order parameters
    function _validateOrder(Order memory order) private view {
        if (order.expiry < block.timestamp) revert ORDER_EXPIRED();
        if (order.maker == address(0) || order.receiver == address(0)) revert ADDRESS_NOT_VALID();
    }

    /// @dev Extracts tokenOut based on selector for balance tracking
    function _decodeTokenOut(bytes memory txData) private view returns (address tokenOut) {
        bytes4 selector = bytes4(BytesLib.toBytes32(txData, 0));
        bytes memory encoded = BytesLib.slice(txData, 4, txData.length - 4);

        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (, address market,,,,) =
                abi.decode(encoded, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
            (, tokenOut,) = IPendleMarket(market).readTokens();
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            (,,, TokenOutput memory output,) =
                abi.decode(encoded, (address, address, uint256, TokenOutput, LimitOrderData));
            tokenOut = output.tokenOut;
        } else if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            (,,, TokenOutput memory output) =
                abi.decode(encoded, (address, address, uint256, TokenOutput));
            tokenOut = output.tokenOut;
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /// @dev Gets balance of output token for the account
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }
}
