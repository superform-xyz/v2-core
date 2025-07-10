// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPendleRouterV4, TokenOutput } from "../../../vendor/pendle/IPendleRouterV4.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title PendleRouterRedeemHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         uint256 amount = BytesLib.toUint256(data, 0);
/// @notice         address YT = BytesLib.toAddress(data, 32);
/// @notice         address PT = BytesLib.toAddress(data, 52);
/// @notice         address tokenOut = BytesLib.toAddress(data, 72);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 92);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
/// @notice         bytes output = BytesLib.slice(data, 125, data.length - 125);
contract PendleRouterRedeemHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    // Offset for bool usePrevHookAmount (after packed amount, YT, tokenOut, minTokenOut)
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 124; // 0+32+20+20+32+20
    // Offset for abi.encoded TokenOutput struct (after packed bool)
    uint256 private constant TOKEN_OUTPUT_OFFSET = 125; // USE_PREV_HOOK_AMOUNT_POSITION + 1

    // Struct for decoded parameters
    struct DecodedParams {
        uint256 amountFromData;
        address YT;
        address PT;
        address tokenOut;
        uint256 minTokenOut;
        bool usePrevHookAmount;
        TokenOutput output;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable pendleRouterV4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error YT_NOT_VALID();
    error ORDER_NOT_MATURE();
    error RECEIVER_NOT_VALID();
    error TOKEN_OUT_NOT_VALID();
    error MIN_TOKEN_OUT_NOT_VALID();
    error INVALID_DATA_LENGTH(); // Added for length check

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
            target: params.PT,
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(pendleRouterV4), finalAmount)
        });
        executions[1] = Execution({
            target: params.YT,
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(pendleRouterV4), finalAmount)
        });
        executions[2] = Execution({
            target: address(pendleRouterV4),
            value: 0,
            callData: abi.encodeWithSelector(
                IPendleRouterV4.redeemPyToToken.selector, account, params.YT, finalAmount, params.output
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        // Minimum length to read up to the bool flag + 1 byte for the flag itself
        if (data.length < TOKEN_OUTPUT_OFFSET) revert INVALID_DATA_LENGTH();
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        DecodedParams memory params = _decodeAndValidateData(data);
        return abi.encodePacked(params.YT, params.PT, params.tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes hook data based on packed encoding, validates parameters, and returns them.
    function _decodeAndValidateData(bytes calldata data) private pure returns (DecodedParams memory params) {
        // Minimum length check to read up to the start of TokenOutput
        if (data.length < TOKEN_OUTPUT_OFFSET) revert INVALID_DATA_LENGTH();

        // Decode fixed-size parameters using BytesLib and packed offsets
        params.amountFromData = BytesLib.toUint256(data, 0); // Offset 0, size 32
        params.YT = BytesLib.toAddress(data, 32); // Offset 32, size 20
        params.PT = BytesLib.toAddress(data, 52); // Offset 52, size 20
        params.tokenOut = BytesLib.toAddress(data, 72); // Offset 72, size 20
        params.minTokenOut = BytesLib.toUint256(data, 92); // Offset 92, size 32
        params.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION); // Offset 124, size 1

        // Basic validation of decoded fixed params (excluding amount check for now)
        if (params.YT == address(0)) revert YT_NOT_VALID();
        if (params.tokenOut == address(0)) revert TOKEN_OUT_NOT_VALID();
        if (params.minTokenOut == 0) revert MIN_TOKEN_OUT_NOT_VALID();

        // Decode TokenOutput struct from the correct offset (after packed data)
        params.output = abi.decode(data[TOKEN_OUTPUT_OFFSET:], (TokenOutput));

        // Validate consistency between explicitly passed params and struct params
        if (params.output.tokenOut != params.tokenOut) revert TOKEN_OUT_NOT_VALID();
        if (params.output.minTokenOut != params.minTokenOut) revert MIN_TOKEN_OUT_NOT_VALID();
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
            if (finalAmount == 0) revert AMOUNT_NOT_VALID(); // Amount from prevHook must be > 0
        } else {
            if (amountFromData == 0) revert AMOUNT_NOT_VALID(); // Amount from data must be > 0
            finalAmount = amountFromData;
        }
    }

    /// @dev Gets the balance of the output token for the receiver.
    function _getBalance(bytes calldata data, address receiver) private view returns (uint256) {
        // Need offset 72 (start of tokenOut) + 20 bytes = 92
        uint256 endOfTokenOutOffset = 92;
        if (data.length < endOfTokenOutOffset) revert INVALID_DATA_LENGTH();
        // Decode tokenOut from its correct packed offset [72:92]
        address tokenOut = BytesLib.toAddress(data, 72);

        if (tokenOut == address(0)) {
            return receiver.balance;
        }

        return IERC20(tokenOut).balanceOf(receiver);
    }
}
