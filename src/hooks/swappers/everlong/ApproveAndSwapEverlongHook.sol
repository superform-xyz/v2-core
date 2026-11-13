// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { EverlongAmountUpdater } from "../../../libraries/EverlongAmountUpdater.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapEverlongHook
/// @author Superform Labs
/// @notice Approves the Everlong Router (Uniswap SwapRouter02 on Katana) for the exact amount, forwards the Everlong
///         Swap API `multicall(deadline, calls)` and resets the approval. Native input skips approvals and forwards
///         value. With `usePrevHookAmount` every leg amountIn and every minimum are rescaled.
///         Caller conventions: quote with `recipient = account`; header `inputAmount` == sum of leg amountIn; header
///         `outputMin` > 0 and POST-fee (enforced on the account's real output delta); native input keeps the API's
///         trailing `refundETH`.
/// @dev Payload: abi.encode(bytes txData)
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
contract ApproveAndSwapEverlongHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /// @notice Everlong Router (Uniswap SwapRouter02): approval spender and call target
    address public immutable ROUTER;

    /// @notice The router's WETH9 (vbETH on Katana): native-input legs use it, native output unwraps it
    address public immutable WETH9;

    /// @notice Native sentinel (0xEeee…); address(0) is accepted too
    address public immutable NATIVE;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /// @dev Own transient slots: the execution amount is pinned in `_preExecute` and the output published for an
    ///      adjacent same-address successor (BaseHook's context has already advanced by then; see FeeSplittingHook).
    bytes32 private constant EVERLONG_TRANSIENT_NAMESPACE = keccak256("superform.everlong.transient.v1");
    uint256 private constant SLOT_EXEC_AMOUNT = 0;
    uint256 private constant SLOT_PUBLISHED_AMOUNT = 1;
    uint256 private constant SLOT_PUBLISHED_TOKEN = 2;
    uint256 private constant SLOT_INPUT_BEFORE = 3;
    uint256 private constant SLOT_WETH9_BEFORE = 4;

    /// @notice Thrown when inputToken and outputToken are the same token
    error SAME_INPUT_OUTPUT_TOKEN();
    /// @notice Thrown when the legs' tokenIn is not the header inputToken (WETH9 for native input)
    error INPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the legs' tokenOut or tail kind is not the header outputToken
    error OUTPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the tail recipient is not the executing account
    error INVALID_RECIPIENT();
    /// @notice Thrown when the header inputAmount does not equal the sum of the legs' amountIn
    error INPUT_AMOUNT_MISMATCH();
    /// @notice Thrown when the resolved execution amount is zero
    error ZERO_EXECUTION_AMOUNT();
    /// @notice Thrown when a native-input swap lacks the trailing `refundETH` leg
    error REFUND_REQUIRED_FOR_NATIVE_INPUT();
    /// @notice Thrown when the account's input delta exceeds the execution amount (any WETH9 on native input)
    error INPUT_OVERSPENT(uint256 spent, uint256 allowed);
    /// @notice Thrown when the previous hook's output token is not the header inputToken
    error PREV_TOKEN_MISMATCH();
    /// @notice Thrown when the header outputMin is zero
    error ZERO_OUTPUT_MIN();
    /// @notice Thrown when the account's output delta is below the (scaled) header outputMin
    error INSUFFICIENT_OUTPUT_AMOUNT(uint256 received, uint256 required);

    constructor(
        address router_,
        address weth9_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0) || weth9_ == address(0) || nativeToken_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        ROUTER = router_;
        WETH9 = weth9_;
        NATIVE = nativeToken_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Everlong";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Everlong Router aggregator";
    }

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
        (bytes memory txData_, uint256 executionAmount, bool nativeIn) = _validateAndResolve(prevHook, account, data);

        if (nativeIn) {
            executions = new Execution[](1);
            executions[0] = Execution({ target: ROUTER, value: executionAmount, callData: txData_ });
            return executions;
        }

        // approval bounded to the execution amount (== sum of the rescaled legs) and reset
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        executions = new Execution[](4);
        executions[0] =
            Execution({ target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (ROUTER, 0)) });
        executions[1] = Execution({
            target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (ROUTER, executionAmount))
        });
        executions[2] = Execution({ target: ROUTER, value: 0, callData: txData_ });
        executions[3] =
            Execution({ target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (ROUTER, 0)) });
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Rescales the header amount, quote (floor), min (ceil) and the embedded legs/tail together
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
        uint256 newAmount = amounts[0];
        uint256 oldAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (oldAmount == 0 || newAmount == 0) revert EverlongAmountUpdater.ZERO_AMOUNT();

        uint256 newQuote = Math.mulDiv(
            BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET), newAmount, oldAmount, Math.Rounding.Floor
        );
        uint256 newMin = Math.mulDiv(
            BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET), newAmount, oldAmount, Math.Rounding.Ceil
        );

        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory txData_ =
            abi.decode(BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength), (bytes));
        // header and embedded amount must agree (one denominator); address(0) = pure path, build() re-validates
        if (EverlongAmountUpdater.readFields(txData_, address(0)).totalIn != oldAmount) revert INPUT_AMOUNT_MISMATCH();
        txData_ = EverlongAmountUpdater.rescale(txData_, address(0), newAmount);
        bytes memory newPayload = abi.encode(txData_);

        bytes memory head = BytesLib.slice(data, 0, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        head = _replaceCalldataAmount(head, newAmount, AMOUNT_POSITION);
        head = _replaceCalldataAmount(head, newQuote, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
        head = _replaceCalldataAmount(head, newMin, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        return bytes.concat(head, bytes32(newPayload.length), newPayload);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(outputToken);
    }

    // ─── ISuperHookSwap
    // ──────────────────────────────────────────────────────

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

    // ─── Internal
    // ────────────────────────────────────────────────────────────

    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
        // input-side snapshot for _checkInputSpend
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        if (_isNative(inputToken)) {
            _tstore(_key(account, SLOT_INPUT_BEFORE), account.balance);
            _tstore(_key(account, SLOT_WETH9_BEFORE), IERC20(WETH9).balanceOf(account));
        } else {
            _tstore(_key(account, SLOT_INPUT_BEFORE), IERC20(inputToken).balanceOf(account));
        }
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            // pin before any venue call
            (uint256 executionAmount,) = _resolvePrevOutput(prevHook, account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            _tstore(_key(account, SLOT_EXEC_AMOUNT), executionAmount);
        }
    }

    /// @dev Enforces the (scaled) header `outputMin` on the account's real output delta, then the input-side cap
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 received = _getBalance(account, data) - getOutAmount(account);
        uint256 required = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        uint256 executionAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            uint256 inputAmount = executionAmount;
            executionAmount = _tload(_key(account, SLOT_EXEC_AMOUNT));
            required = Math.mulDiv(required, executionAmount, inputAmount, Math.Rounding.Ceil);
        }
        if (received < required) revert INSUFFICIENT_OUTPUT_AMOUNT(received, required);
        _checkInputSpend(account, data, executionAmount);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(received, account);
        _setOutToken(outputToken, account);
        // publish for an adjacent same-address successor
        _tstore(_key(account, SLOT_PUBLISHED_AMOUNT), received);
        _tstore(_key(account, SLOT_PUBLISHED_TOKEN), uint256(uint160(outputToken)));
    }

    /// @dev Predecessor (outAmount, outToken); own published slots when the predecessor is this hook
    function _resolvePrevOutput(address prevHook, address account) private view returns (uint256, address) {
        if (prevHook == address(this)) {
            return (
                _tload(_key(account, SLOT_PUBLISHED_AMOUNT)),
                address(uint160(_tload(_key(account, SLOT_PUBLISHED_TOKEN))))
            );
        }
        return (ISuperHookResult(prevHook).getOutAmount(account), ISuperHookResult(prevHook).getOutToken(account));
    }

    /// @dev At most `executionAmount` of the input may leave the account; on native input no WETH9 at all (the router
    ///      could otherwise pull it through a standing allowance)
    function _checkInputSpend(address account, bytes calldata data, uint256 executionAmount) private view {
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        uint256 before = _tload(_key(account, SLOT_INPUT_BEFORE));
        if (_isNative(inputToken)) {
            uint256 wethBefore = _tload(_key(account, SLOT_WETH9_BEFORE));
            uint256 wethNow = IERC20(WETH9).balanceOf(account);
            if (wethNow < wethBefore) revert INPUT_OVERSPENT(wethBefore - wethNow, 0);
            uint256 ethNow = account.balance;
            if (ethNow < before && before - ethNow > executionAmount) {
                revert INPUT_OVERSPENT(before - ethNow, executionAmount);
            }
            return;
        }
        uint256 nowBal = IERC20(inputToken).balanceOf(account);
        if (nowBal < before && before - nowBal > executionAmount) {
            revert INPUT_OVERSPENT(before - nowBal, executionAmount);
        }
    }

    function _key(address account, uint256 slot) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(EVERLONG_TRANSIENT_NAMESPACE, account, slot));
    }

    function _tload(bytes32 key) private view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(key)
        }
    }

    function _tstore(bytes32 key, uint256 value) private {
        assembly ("memory-safe") {
            tstore(key, value)
        }
    }

    /// @dev Validation and sizing for the build path
    function _validateAndResolve(
        address prevHook,
        address account,
        bytes calldata data
    )
        private
        view
        returns (bytes memory txData_, uint256 executionAmount, bool nativeIn)
    {
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);

        if (_isSameToken(inputToken, outputToken)) revert SAME_INPUT_OUTPUT_TOKEN();
        if (BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET) == 0) revert ZERO_OUTPUT_MIN();

        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        txData_ = abi.decode(BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength), (bytes));

        EverlongAmountUpdater.Fields memory f = EverlongAmountUpdater.readFields(txData_, WETH9);
        nativeIn = _isNative(inputToken);
        // native input is expressed in WETH9 inside the legs
        if (nativeIn ? f.tokenIn != WETH9 : f.tokenIn != inputToken) revert INPUT_TOKEN_MISMATCH();
        // native output = unwrap tail; ERC20 output (WETH9 included) = sweep tail of that token
        if (_isNative(outputToken) ? !f.nativeOut : (f.nativeOut || f.tokenOut != outputToken)) {
            revert OUTPUT_TOKEN_MISMATCH();
        }
        if (f.recipient != account) revert INVALID_RECIPIENT();
        if (nativeIn && !f.hasRefund) revert REFUND_REQUIRED_FOR_NATIVE_INPUT();
        // header == sum of legs: one denominator for the payload rescale and the hook floor
        if (inputAmount != f.totalIn) revert INPUT_AMOUNT_MISMATCH();

        executionAmount = inputAmount;
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            address prevToken;
            (executionAmount, prevToken) = _resolvePrevOutput(prevHook, account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            if (!_isSameToken(prevToken, inputToken)) revert PREV_TOKEN_MISMATCH();
            txData_ = EverlongAmountUpdater.rescale(txData_, WETH9, executionAmount);
        }
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

    function _isSameToken(address tokenA_, address tokenB_) private view returns (bool) {
        if (_isNative(tokenA_) && _isNative(tokenB_)) {
            return true;
        }
        return tokenA_ == tokenB_;
    }
}
