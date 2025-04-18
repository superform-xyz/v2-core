// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IPendleRouterV4, TokenOutput } from "../../../vendor/pendle/IPendleRouterV4.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

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
/// @notice         address YT = BytesLib.toAddress(data, 32);
/// @notice         address tokenOut = BytesLib.toAddress(data, 52);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
contract PendleRouterRedeemHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable pendleRouterV4;

    struct RedeemData {
        bool usePrevHookAmount;
        uint256 amount; // netPyIn
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
        uint256 amount = BytesLib.toUint256(data, 0);
        address YT = BytesLib.toAddress(data, 32);
        address tokenOut = BytesLib.toAddress(data, 52);
        uint256 minTokenOut = BytesLib.toUint256(data, 72);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        _validateRedeemData(amount, YT, tokenOut, minTokenOut);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        TokenOutput memory output = pendleRouterV4.createTokenOutputSimple(tokenOut, minTokenOut);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(pendleRouterV4),
            value: 0,
            callData: abi.encodeWithSelector(IPendleRouterV4.redeemPyToToken.selector, account, YT, amount, output)
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

    function _validateRedeemData(uint256 amount, address YT, address tokenOut, uint256 minTokenOut) internal pure {
        if (YT == address(0)) revert YT_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (tokenOut == address(0)) revert TOKEN_OUT_NOT_VALID();
        if (minTokenOut == 0) revert MIN_TOKEN_OUT_NOT_VALID();
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address tokenOut = BytesLib.toAddress(data, 52);
        address receiver = BytesLib.toAddress(data, 32);

        if (tokenOut == address(0)) {
            return receiver.balance;
        }

        return IERC20(tokenOut).balanceOf(receiver);
    }
}
