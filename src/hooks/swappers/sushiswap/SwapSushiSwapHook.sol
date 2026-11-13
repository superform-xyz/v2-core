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
import { SushiSwapAmountUpdater } from "../../../libraries/SushiSwapAmountUpdater.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title SwapSushiSwapHook
/// @author Superform Labs
/// @notice Forwards SushiSwap v7 `RedSnwapper.snwap` calldata (wrapping a nested RouteProcessor `processRoute`).
///         The caller approves RedSnwapper for ERC20 inputs; native input forwards value. With `usePrevHookAmount`
///         the outer and nested amounts and minimums are rescaled together.
///         Caller conventions: quote with `sender = recipient = account`; header `inputAmount` == embedded `amountIn`;
///         header `outputMin` > 0 (enforced on the account's real output delta, scaled to the executed amount).
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
contract SwapSushiSwapHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /// @notice RedSnwapper: approval spender and call target; it pulls `amountIn` and forwards it to the executor
    address public immutable RED_SNWAPPER;

    /// @notice The only executor accepted in the calldata. RedSnwapper hands the input to whatever executor is named,
    ///         so this pin is the fund-safety gate. Per chain; see `IRouteProcessor7` for the Katana ABI caveats.
    address public immutable ROUTE_PROCESSOR;

    /// @notice Native sentinel (0xEeee…), the same one RedSnwapper uses
    address public immutable NATIVE;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /// @dev Own transient slots (EIP-1153). The executor advances BaseHook's context between `build` and `pre`, so a
    ///      predecessor that is this same hook cannot be read through BaseHook in pre/post: the execution amount is
    ///      pinned in `_preExecute` and the output is published here for an adjacent successor (as FeeSplittingHook).
    bytes32 private constant SUSHI_TRANSIENT_NAMESPACE = keccak256("superform.sushiswap.transient.v1");
    uint256 private constant SLOT_EXEC_AMOUNT = 0;
    uint256 private constant SLOT_PUBLISHED_AMOUNT = 1;
    uint256 private constant SLOT_PUBLISHED_TOKEN = 2;

    /// @notice Thrown when inputToken and outputToken are the same token
    error SAME_INPUT_OUTPUT_TOKEN();
    /// @notice Thrown when the `snwap` tokenIn does not match the header inputToken
    error INPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the `snwap` tokenOut does not match the header outputToken
    error OUTPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the `snwap` recipient is not the executing account
    error INVALID_RECIPIENT();
    /// @notice Thrown when the `snwap` executor is not the pinned ROUTE_PROCESSOR
    error INVALID_EXECUTOR();
    /// @notice Thrown when the header inputAmount does not equal the embedded `snwap` amountIn
    error INPUT_AMOUNT_MISMATCH();
    /// @notice Thrown when the resolved execution amount is zero
    error ZERO_EXECUTION_AMOUNT();
    /// @notice Thrown when the previous hook's output token is not the header inputToken
    error PREV_TOKEN_MISMATCH();
    /// @notice Thrown when the header outputMin is zero (the in-hook floor would be vacuous)
    error ZERO_OUTPUT_MIN();
    /// @notice Thrown when the account's output delta is below the (scaled) header outputMin
    error INSUFFICIENT_OUTPUT_AMOUNT(uint256 received, uint256 required);

    constructor(
        address redSnwapper_,
        address routeProcessor_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (redSnwapper_ == address(0) || routeProcessor_ == address(0) || nativeToken_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        RED_SNWAPPER = redSnwapper_;
        ROUTE_PROCESSOR = routeProcessor_;
        NATIVE = nativeToken_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap SushiSwap";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via SushiSwap aggregator";
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

        executions = new Execution[](1);
        executions[0] = Execution({ target: RED_SNWAPPER, value: nativeIn ? executionAmount : 0, callData: txData_ });
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
    /// @dev Rescales the header amount, quote (floor) and min (ceil) together with the four embedded words, so the
    ///      enforced header floor tracks the new size. Fails closed on any payload the updater rejects.
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
        if (oldAmount == 0 || newAmount == 0) revert SushiSwapAmountUpdater.ZERO_AMOUNT();

        uint256 newQuote = Math.mulDiv(
            BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET), newAmount, oldAmount, Math.Rounding.Floor
        );
        uint256 newMin = Math.mulDiv(
            BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET), newAmount, oldAmount, Math.Rounding.Ceil
        );

        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory txData_ =
            abi.decode(BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength), (bytes));
        // Header and embedded amount must already agree, or the two halves would scale by different denominators.
        if (SushiSwapAmountUpdater.readFields(txData_).amountIn != oldAmount) revert INPUT_AMOUNT_MISMATCH();
        SushiSwapAmountUpdater.rescale(txData_, newAmount);
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
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            // Pin the execution amount before any venue call (see SUSHI_TRANSIENT_NAMESPACE).
            (uint256 executionAmount,) = _resolvePrevOutput(prevHook, account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            _tstore(_key(account, SLOT_EXEC_AMOUNT), executionAmount);
        }
    }

    /// @dev Enforces the header `outputMin`, scaled to the executed amount, on the account's real output delta,
    ///      independently of the two Sushi minimums carried in the signed calldata.
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 received = _getBalance(account, data) - getOutAmount(account);
        uint256 required = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            uint256 executionAmount = _tload(_key(account, SLOT_EXEC_AMOUNT));
            uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
            required = Math.mulDiv(required, executionAmount, inputAmount, Math.Rounding.Ceil);
        }
        if (received < required) revert INSUFFICIENT_OUTPUT_AMOUNT(received, required);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(received, account);
        _setOutToken(outputToken, account);
        // Publish for an adjacent same-address successor.
        _tstore(_key(account, SLOT_PUBLISHED_AMOUNT), received);
        _tstore(_key(account, SLOT_PUBLISHED_TOKEN), uint256(uint160(outputToken)));
    }

    /// @dev Predecessor (outAmount, outToken); reads this hook's own published slots when it is its own predecessor.
    function _resolvePrevOutput(address prevHook, address account) private view returns (uint256, address) {
        if (prevHook == address(this)) {
            return (
                _tload(_key(account, SLOT_PUBLISHED_AMOUNT)),
                address(uint160(_tload(_key(account, SLOT_PUBLISHED_TOKEN))))
            );
        }
        return (ISuperHookResult(prevHook).getOutAmount(account), ISuperHookResult(prevHook).getOutToken(account));
    }

    function _key(address account, uint256 slot) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(SUSHI_TRANSIENT_NAMESPACE, account, slot));
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

    /// @dev Shared validation and sizing for the build path.
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

        SushiSwapAmountUpdater.Fields memory f = SushiSwapAmountUpdater.readFields(txData_);
        if (f.executor != ROUTE_PROCESSOR) revert INVALID_EXECUTOR();
        nativeIn = _isNative(inputToken);
        // RedSnwapper only recognises the 0xEeee… sentinel for native; ERC20 must match the header exactly.
        if (nativeIn ? f.tokenIn != NATIVE : f.tokenIn != inputToken) revert INPUT_TOKEN_MISMATCH();
        if (_isNative(outputToken) ? f.tokenOut != NATIVE : f.tokenOut != outputToken) revert OUTPUT_TOKEN_MISMATCH();
        if (f.recipient != account) revert INVALID_RECIPIENT();
        // Header == embedded on both paths, so one denominator serves the payload rescale and the hook floor.
        if (inputAmount != f.amountIn) revert INPUT_AMOUNT_MISMATCH();

        executionAmount = inputAmount;
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            address prevToken;
            (executionAmount, prevToken) = _resolvePrevOutput(prevHook, account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            if (!_isSameToken(prevToken, inputToken)) revert PREV_TOKEN_MISMATCH();
            SushiSwapAmountUpdater.rescale(txData_, executionAmount);
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
