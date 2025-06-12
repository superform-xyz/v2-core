// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order
} from "../../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../../vendor/pendle/IPendleMarket.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title PendleRouterSwapHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 24);
/// @notice         uint256 value = BytesLib.toUint256(data, 25);
/// @notice         bytes txData_ = BytesLib.slice(data, 57, data.length - 57);
contract PendleRouterSwapHook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 24;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable pendleRouterV4;

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

    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        pendleRouterV4 = IPendleRouterV4(pendleRouterV4_);
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
        address pendleMarket = data.extractYieldSource();
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 value = BytesLib.toUint256(data, 25);
        bytes memory txData_ = data[57:];

        bytes memory updatedTxData = _validateTxData(data[57:], account, usePrevHookAmount, prevHook, pendleMarket);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(pendleRouterV4),
            value: value,
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
        bytes calldata txData_ = data[57:];
        bytes4 selector = bytes4(txData_[0:4]);

        bytes memory packed;
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            // skip selector
            (address receiver, address market,,, TokenInput memory input, LimitOrderData memory limit) =
                abi.decode(txData_[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

            packed = abi.encodePacked(
                data.extractYieldSource(),
                receiver,
                market,
                input.tokenIn,
                input.tokenMintSy,
                input.pendleSwap,
                input.swapData.extRouter,
                limit.limitRouter
            );

            uint256 normalFillsLen = limit.normalFills.length;
            for (uint256 i; i < normalFillsLen; i++) {
                packed = abi.encodePacked(
                    packed,
                    limit.normalFills[i].order.token,
                    limit.normalFills[i].order.YT,
                    limit.normalFills[i].order.maker,
                    limit.normalFills[i].order.receiver
                );
            }
            uint256 flashFillsLen = limit.flashFills.length;
            for (uint256 i; i < flashFillsLen; i++) {
                packed = abi.encodePacked(
                    packed,
                    limit.flashFills[i].order.token,
                    limit.flashFills[i].order.YT,
                    limit.flashFills[i].order.maker,
                    limit.flashFills[i].order.receiver
                );
            }
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            // skip selector
            (address receiver, address market,, TokenOutput memory output, LimitOrderData memory limit) =
                abi.decode(txData_[4:], (address, address, uint256, TokenOutput, LimitOrderData));

            packed = abi.encodePacked(
                data.extractYieldSource(),
                receiver,
                market,
                output.tokenOut,
                output.tokenRedeemSy,
                output.pendleSwap,
                output.swapData.extRouter
            );

            uint256 normalFillsLen = limit.normalFills.length;
            for (uint256 i; i < normalFillsLen; i++) {
                packed = abi.encodePacked(
                    packed,
                    limit.normalFills[i].order.token,
                    limit.normalFills[i].order.YT,
                    limit.normalFills[i].order.maker,
                    limit.normalFills[i].order.receiver
                );
            }
            uint256 flashFillsLen = limit.flashFills.length;
            for (uint256 i; i < flashFillsLen; i++) {
                packed = abi.encodePacked(
                    packed,
                    limit.flashFills[i].order.token,
                    limit.flashFills[i].order.YT,
                    limit.flashFills[i].order.maker,
                    limit.flashFills[i].order.receiver
                );
            }
        }

        return packed;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _validateTxData(
        bytes calldata data,
        address account,
        bool usePrevHookAmount,
        address prevHook,
        address pendleMarket
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        bytes4 selector = bytes4(data[0:4]);
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            // skip selector
            (
                address receiver,
                address market,
                uint256 minPtOut,
                ApproxParams memory guessPtOut,
                TokenInput memory input,
                LimitOrderData memory limit
            ) = abi.decode(data[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

            if (receiver != account) revert RECEIVER_NOT_VALID();
            if (market != pendleMarket) revert MARKET_NOT_VALID();
            if (minPtOut == 0) revert MIN_OUT_NOT_VALID();

            // validate approx params
            if (guessPtOut.guessMin > guessPtOut.guessMax) revert INVALID_GUESS_PT_OUT();
            if (guessPtOut.eps > 1e18) revert EPS_NOT_VALID();

            // validate token input
            if (input.tokenMintSy == address(0) || input.pendleSwap == address(0)) revert ADDRESS_NOT_VALID();

            if (usePrevHookAmount) {
                input.netTokenIn = ISuperHookResult(prevHook).outAmount();
            }
            if (input.netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();

            // validate limit order
            if (limit.normalFills.length > 0) {
                _validateFillOrders(limit.normalFills);
            }
            if (limit.flashFills.length > 0) {
                _validateFillOrders(limit.flashFills);
            }

            updatedTxData = abi.encodeWithSelector(selector, receiver, market, minPtOut, guessPtOut, input, limit);
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            // skip selector
            (
                address receiver,
                address market,
                uint256 exactPtIn,
                TokenOutput memory output,
                LimitOrderData memory limit
            ) = abi.decode(data[4:], (address, address, uint256, TokenOutput, LimitOrderData));

            if (receiver != account) revert RECEIVER_NOT_VALID();
            if (market != pendleMarket) revert MARKET_NOT_VALID();

            if (usePrevHookAmount) {
                exactPtIn = ISuperHookResult(prevHook).outAmount();
            }
            if (exactPtIn == 0) revert AMOUNT_IN_NOT_VALID();

            // validate token output
            if (output.pendleSwap == address(0)) revert ADDRESS_NOT_VALID();
            if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

            // validate limit order
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

    function _decodeTokenOut(bytes calldata data) internal view returns (address tokenOut) {
        bytes4 selector = bytes4(data[0:4]);
        if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            // 0-4 selector
            // 4-36 receiver
            // 36-68 market

            address market = abi.decode(data[36:68], (address));
            (, tokenOut,) = IPendleMarket(market).readTokens();
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            // 0-4 selector
            // 4-36 receiver
            // 36-68 market
            // 68-100 exactPtIn
            // 100-250 output
            tokenOut = abi.decode(data[100:132], (address));
        } else {
            revert INVALID_SWAP_TYPE();
        }
    }

    function _decodeReceiver(bytes calldata data) internal pure returns (address receiver) {
        // same offset for both selectors
        receiver = abi.decode(data[4:36], (address));
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address tokenOut = _decodeTokenOut(data[57:]);
        address receiver = _decodeReceiver(data[57:]);

        if (tokenOut == address(0)) {
            return receiver.balance;
        }

        return IERC20(tokenOut).balanceOf(receiver);
    }
}
