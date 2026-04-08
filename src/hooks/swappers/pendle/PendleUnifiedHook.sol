// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
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
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";

/// @title PendleUnifiedHook
/// @author Superform Labs
/// @notice Unified hook supporting all Pendle router operations: swaps (pre-maturity) and redemptions (post-maturity)
/// @dev Merges PendleRouterSwapHook and PendleRouterRedeemHook with fix for tokenRedeemSy validation
/// @dev Data layout (same for all selectors):
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);  // market for swaps, YT for redeem
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
/// @notice         uint256 value = BytesLib.toUint256(data, 53);
/// @notice         bytes txData_ = BytesLib.slice(data, 85, data.length - 85);
contract PendleUnifiedHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;
    uint256 private constant VALUE_OFFSET = 53;
    uint256 private constant TX_DATA_OFFSET = 85;

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

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
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
        address yieldSource = data.extractYieldSource();
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        bytes calldata txData = data[TX_DATA_OFFSET:];

        bytes4 selector = bytes4(txData[0:4]);

        if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            return _buildRedeemExecutions(prevHook, account, yieldSource, usePrevHookAmount, txData);
        } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            uint256 value = BytesLib.toUint256(data, VALUE_OFFSET);
            return _buildSwapTokenForPtExecutions(
                prevHook, account, yieldSource, usePrevHookAmount, value, txData
            );
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            return _buildSwapPtForTokenExecutions(prevHook, account, yieldSource, usePrevHookAmount, txData);
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Returns packed data for inspection, excluding redundant fields (market, yt, tokenRedeemSy)
    ///      since yieldSource already provides the market address
    function inspect(bytes calldata data) external view override returns (bytes memory packed) {
        bytes calldata txData = data[TX_DATA_OFFSET:];
        bytes4 selector = bytes4(txData[0:4]);
        address yieldSource = data.extractYieldSource();

        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (address receiver,,,, TokenInput memory input,) =
                abi.decode(txData[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

            packed = abi.encodePacked(
                yieldSource,
                receiver,
                input.tokenIn,
                input.pendleSwap,
                input.swapData.extRouter
            );
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            (address receiver,,, TokenOutput memory output,) =
                abi.decode(txData[4:], (address, address, uint256, TokenOutput, LimitOrderData));

            packed = abi.encodePacked(
                yieldSource,
                receiver,
                output.tokenOut,
                output.pendleSwap,
                output.swapData.extRouter
            );
        } else if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            (address receiver,,, TokenOutput memory output) =
                abi.decode(txData[4:], (address, address, uint256, TokenOutput));

            // Get PT from market (yieldSource is always the market)
            (, address pt,) = IPendleMarket(yieldSource).readTokens();

            packed = abi.encodePacked(
                yieldSource,
                receiver,
                pt,
                output.tokenOut,
                output.pendleSwap,
                output.swapData.extRouter
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds executions for redeemPyToToken (PT+YT redemption)
    /// @param yieldSource The market address (always use market as yieldSource for consistency)
    function _buildRedeemExecutions(
        address prevHook,
        address account,
        address yieldSource,
        bool usePrevHookAmount,
        bytes calldata txData
    )
        private
        view
        returns (Execution[] memory executions)
    {
        // Decode and validate parameters
        (address receiver, address ytFromTxData, uint256 netPyIn, TokenOutput memory output) =
            abi.decode(txData[4:], (address, address, uint256, TokenOutput));

        // yieldSource is the market address - get SY, PT, YT from market
        (address sy, address pt, address yt) = IPendleMarket(yieldSource).readTokens();
        if (sy == address(0)) revert SY_NOT_VALID();

        // Validate YT in txData matches the market's YT
        if (ytFromTxData != yt) revert YT_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

        // CORE FIX: Validate based on swap routing
        if (output.swapData.swapType != SwapType.NONE) {
            // Swap routing: validate tokenRedeemSy (intermediate token), NOT tokenOut
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                revert TOKEN_REDEEM_SY_NOT_VALID();
            }
            // Validate external router is provided (except for ETH_WETH which uses internal wrap/unwrap)
            if (output.swapData.swapType != SwapType.ETH_WETH) {
                if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                    revert INVALID_EXT_ROUTER();
                }
            }
        } else {
            // Direct redemption: validate tokenOut
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                revert TOKEN_OUT_NOT_LISTED();
            }
        }

        // Determine final amount and scale minTokenOut proportionally
        uint256 finalAmount;
        if (usePrevHookAmount) {
            finalAmount = ISuperHookResult(prevHook).getOutAmount(account);
            output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalAmount, netPyIn, output.minTokenOut);
            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();
        } else {
            finalAmount = netPyIn;
        }
        if (finalAmount == 0) revert AMOUNT_IN_NOT_VALID();

        // Build executions: approve(0) PT, approve PT, approve(0) YT, approve YT, redeem, reset PT, reset YT
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
        bytes calldata txData
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
        ) = abi.decode(txData[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        // yieldSource should be the market address
        if (yieldSource != market) revert MARKET_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (minPtOut == 0) revert MIN_OUT_NOT_VALID();

        // Validate approx params
        if (guessPtOut.guessMin > guessPtOut.guessMax) revert INVALID_GUESS_PT_OUT();
        if (guessPtOut.eps > MAX_EPS) revert EPS_NOT_VALID();
        if (guessPtOut.maxIteration > MAX_ITERATIONS) revert INVALID_MAX_ITERATION();

        // Determine final amount and scale minPtOut proportionally
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

        // Validate limit orders
        _validateLimitOrders(limit);

        // Compute exec value (if tokenIn is native ETH)
        uint256 execValue = (input.tokenIn == address(0)) ? netTokenIn : 0;
        // Use provided value if usePrevHookAmount is false and value > 0 (backwards compat)
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
        bytes calldata txData
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
        ) = abi.decode(txData[4:], (address, address, uint256, TokenOutput, LimitOrderData));

        // yieldSource should be the market address
        if (yieldSource != market) revert MARKET_NOT_VALID();
        if (receiver != account) revert RECEIVER_NOT_VALID();
        if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

        // Validate swap routing
        if (output.swapData.swapType != SwapType.NONE) {
            if (output.swapData.swapType != SwapType.ETH_WETH) {
                if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                    revert INVALID_EXT_ROUTER();
                }
            }
        }

        // Determine final amount and scale minTokenOut proportionally
        uint256 finalPtIn;
        if (usePrevHookAmount) {
            finalPtIn = ISuperHookResult(prevHook).getOutAmount(account);
            output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalPtIn, exactPtIn, output.minTokenOut);
            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();
        } else {
            finalPtIn = exactPtIn;
        }
        if (finalPtIn == 0) revert AMOUNT_IN_NOT_VALID();

        // Validate limit orders
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
        // an order can execute until the block timestamp strictly exceeds the expiry time
        if (order.expiry < block.timestamp) revert ORDER_EXPIRED();
        if (order.maker == address(0) || order.receiver == address(0)) revert ADDRESS_NOT_VALID();
    }

    /// @dev Extracts tokenOut based on selector for balance tracking
    function _decodeTokenOut(bytes calldata txData) private view returns (address tokenOut) {
        bytes4 selector = bytes4(txData[0:4]);

        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (, address market,,,,) =
                abi.decode(txData[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
            // For token → PT, output is PT which we get from market
            (, tokenOut,) = IPendleMarket(market).readTokens();
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            (,,, TokenOutput memory output,) =
                abi.decode(txData[4:], (address, address, uint256, TokenOutput, LimitOrderData));
            tokenOut = output.tokenOut;
        } else if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            (,,, TokenOutput memory output) =
                abi.decode(txData[4:], (address, address, uint256, TokenOutput));
            tokenOut = output.tokenOut;
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /// @dev Gets balance of output token for the account
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address tokenOut = _decodeTokenOut(data[TX_DATA_OFFSET:]);

        if (tokenOut == address(0)) {
            return account.balance;
        }

        return IERC20(tokenOut).balanceOf(account);
    }
}
