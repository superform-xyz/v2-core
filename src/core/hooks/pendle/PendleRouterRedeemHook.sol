// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { ISuperHook, ISuperHookResult, ISuperHookContextAware } from "../../interfaces/ISuperHook.sol";
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
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";

/// @title PendleRouterRedeemHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 24);
/// @notice         uint256 value = BytesLib.toUint256(data, 25);
/// @notice         address receiver = BytesLib.toAddress(data, 57);
/// @notice         address YT = BytesLib.toAddress(data, 89);
/// @notice         address tokenOut = BytesLib.toAddress(data, 121);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 153);
contract PendleRouterRedeemHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 24;

    /// @dev Creates a TokenOutput struct without using any swap aggregator
    /// @param tokenOut must be one of the SY's tokens out (obtain via `IStandardizedYield#getTokensOut`)
    /// @param minTokenOut minimum amount of token out
    // function createTokenOutputSimple(address tokenOut, uint256 minTokenOut) pure returns (TokenOutput memory) {
    //     return
    //         TokenOutput({
    //             tokenOut: tokenOut,
    //             minTokenOut: minTokenOut,
    //             tokenRedeemSy: tokenOut,
    //             pendleSwap: address(0),
    //             swapData: createSwapTypeNoAggregator()
    //         });
    // }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable pendleRouterV4;

    struct RedeemData {
        address yieldSource; // Pendle Market
        bool usePrevHookAmount;
        uint256 amount; // netPyIn
        address receiver;
        address YT;
        address tokenOut;
        uint256 minTokenOut;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error YT_NOT_VALID();
    error AMOUNT_NOT_VALID();
    error ORDER_NOT_MATURE();
    error RECEIVER_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        pendleRouterV4 = IPendleRouterV4(pendleRouterV4_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes calldata data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        RedeemData memory redeemData = _decodeData(data);
        _validateRedeemData(redeemData);

        if (redeemData.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).outAmount();
        }

        TokenOutput memory output = pendleV4Router.createTokenOutputSimple(redeemData.tokenOut, redeemData.minTokenOut);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(pendleRouterV4),
            value: 0,
            callData: abi.encodeWithSelector(IPendleRouterV4.redeemPyToToken.selector, redeemData.receiver, redeemData.YT, redeemData.amount, output)
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
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
    function _decodeData(bytes calldata data)
        internal
        view
        returns (RedeemData memory redeemData)
    {
        address pendleMarket = data.extractYieldSource();
        address receiver = data.extractReceiver();
        address YT = data.extractYT();
        uint256 amount = data.extractAmount();
        address tokenOut = data.extractTokenOut();
        uint256 minTokenOut = data.extractMinTokenOut();

        RedeemData memory redeemData = RedeemData({
            yieldSource: pendleMarket,
            usePrevHookAmount: usePrevHookAmount,
            amount: amount,
            receiver: receiver,
            YT: YT,
        });
    }

    function _validateRedeemData(RedeemData memory redeemData) internal view {
        if (redeemData.YT == address(0)) revert YT_NOT_VALID();
        if (redeemData.amount == 0) revert AMOUNT_NOT_VALID();
        if (redeemData.tokenOut == address(0)) revert TOKEN_OUT_NOT_VALID();
        if (redeemData.minTokenOut == 0) revert MIN_TOKEN_OUT_NOT_VALID();
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address tokenOut = BytesLib.toAddress(data, 121);
        address receiver = BytesLib.toAddress(data, 57);

        if (tokenOut == address(0)) {
            return receiver.balance;
        }

        return IERC20(tokenOut).balanceOf(receiver);
    }
}
