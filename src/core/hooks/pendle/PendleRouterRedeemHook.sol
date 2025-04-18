// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IPendleRouterV4, TokenOutput } from "../../../vendor/pendle/IPendleRouterV4.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";
import { ISuperHook, ISuperHookResult, ISuperHookContextAware } from "../../interfaces/ISuperHook.sol";

/// @title PendleRouterRedeemHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         uint256 amount = BytesLib.toUint256(data, 0);
/// @notice         address receiver = BytesLib.toAddress(data, 32);
/// @notice         address YT = BytesLib.toAddress(data, 52);
/// @notice         address tokenOut = BytesLib.toAddress(data, 72);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 92);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
contract PendleRouterRedeemHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 124;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable pendleRouterV4;

    struct RedeemData {
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
    error ORDER_NOT_MATURE();
    error RECEIVER_NOT_VALID();
    error TOKEN_OUT_NOT_VALID();
    error MIN_TOKEN_OUT_NOT_VALID();

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
        RedeemData memory redeemVars = _decodeData(data);
        _validateRedeemData(redeemVars);

        if (redeemVars.usePrevHookAmount) {
            redeemVars.amount = ISuperHookResult(prevHook).outAmount();
        }

        TokenOutput memory output = pendleRouterV4.createTokenOutputSimple(redeemVars.tokenOut, redeemVars.minTokenOut);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(pendleRouterV4),
            value: 0,
            callData: abi.encodeWithSelector(
                IPendleRouterV4.redeemPyToToken.selector, redeemVars.receiver, redeemVars.YT, redeemVars.amount, output
            )
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
    function _decodeData(bytes calldata data) internal view returns (RedeemData memory redeemData) {
        uint256 amount = BytesLib.toUint256(data, 0);
        address receiver = BytesLib.toAddress(data, 32);
        address YT = BytesLib.toAddress(data, 52);
        address tokenOut = BytesLib.toAddress(data, 72);
        uint256 minTokenOut = BytesLib.toUint256(data, 92);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        return RedeemData({
            usePrevHookAmount: usePrevHookAmount,
            amount: amount,
            receiver: receiver,
            YT: YT,
            tokenOut: tokenOut,
            minTokenOut: minTokenOut
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
