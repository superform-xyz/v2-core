// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { PancakeSwapAmountUpdater } from "../../../libraries/PancakeSwapAmountUpdater.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title SwapPancakeSwapHook
/// @author Superform Labs
/// @notice Forwards a PancakeSwap aggregator `swapExactIn` calldata to the router in a single execution.
///         The caller is responsible for approving the router for ERC20 inputs (use
///         ApproveAndSwapPancakeSwapHook for the self-contained approve-swap-reset variant).
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
contract SwapPancakeSwapHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /// @notice The pinned PancakeSwap aggregation router (approval spender + execution target)
    address public immutable PANCAKE_ROUTER;

    /// @notice Superform's native-token sentinel used in the hook header (0xEeee… on all chains)
    address public immutable NATIVE;

    /// @notice The native-token sentinel the ROUTER's own calldata uses. Equals NATIVE on most chains,
    ///         but PancakeSwap's Arc calldata uses 0x3600…0000.
    address public immutable AGGREGATOR_NATIVE;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /// @notice Thrown when inputToken and outputToken are the same address
    error SAME_INPUT_OUTPUT_TOKEN();
    /// @notice Thrown when request.outputToken in txData does not match the header outputToken
    error OUTPUT_TOKEN_MISMATCH();
    /// @notice Thrown when request.inputToken in txData does not match the header inputToken
    error INPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the txData recipient is not the executing account
    error INVALID_RECIPIENT();
    /// @notice Thrown when the resolved execution amount is zero
    error ZERO_EXECUTION_AMOUNT();
    /// @notice Thrown when the header inputAmount does not equal the embedded routesAmount sum (fixed path)
    error INPUT_AMOUNT_MISMATCH();

    constructor(
        address router_,
        address aggregatorNativePlaceholder_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0) || nativeToken_ == address(0) || aggregatorNativePlaceholder_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        PANCAKE_ROUTER = router_;
        NATIVE = nativeToken_;
        AGGREGATOR_NATIVE = aggregatorNativePlaceholder_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap PancakeSwap";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via PancakeSwap aggregator";
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
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
        bytes memory txData_ = abi.decode(payload, (bytes));

        uint256 executionAmount = inputAmount;
        if (usePrevHookAmount) {
            executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
            // Rescales routesAmount[0] + the floor against the EMBEDDED route amount (single-route/zero-fee).
            PancakeSwapAmountUpdater.rescaleSingleRoute(txData_, executionAmount);
        } else if (inputAmount != PancakeSwapAmountUpdater.totalRoutesAmount(txData_)) {
            // Fixed path: the header amount MUST equal what the router will actually pull, so the sized slot
            // is truthful and the approve/native value below match the embedded routesAmount. Fail closed.
            // (A non-zero feeConfig is left to the signed calldata here: it is bounded by the forwarded
            // value/approval == sum(routesAmount) and gated by the embedded minOutputAmount, so it cannot
            // over-pull; only the chained rescale path forbids feeConfig, where it would skew the ratio.)
            revert INPUT_AMOUNT_MISMATCH();
        }

        (address srcToken, address dstToken, address recipient) = PancakeSwapAmountUpdater.readFields(txData_);

        _validateTokenPair(inputToken, outputToken);
        if (!_isSameToken(inputToken, srcToken)) revert INPUT_TOKEN_MISMATCH();
        if (!_isSameToken(dstToken, outputToken)) revert OUTPUT_TOKEN_MISMATCH();
        if (recipient != account) revert INVALID_RECIPIENT();

        // NOTE: slippage is intentionally NOT re-enforced here against the header `outputMin`. Like the
        // other opaque-calldata aggregator forwarders (KyberSwap, OpenOcean, 1inch, Odos), the slippage
        // floor is the `minOutputAmount` carried inside the signed router calldata (scaled proportionally
        // by the updater when usePrevHookAmount rescales the input). We do NOT copy the in-hook
        // `received >= outputMin` check that ApproveAndSwapBinanceHook performs in _postExecute: that hook
        // can only do so because it forbids usePrevHookAmount and is sizeless, so its header `outputMin`
        // always matches a fixed swap size. This hook supports single-route usePrevHookAmount, so a static
        // header-min check would falsely revert a legitimately rescaled-down swap.
        uint256 value = _isNative(srcToken) ? executionAmount : 0;

        executions = new Execution[](1);
        executions[0] = Execution({ target: PANCAKE_ROUTER, value: value, callData: txData_ });
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
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] =
            ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
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
        // Keep the sized header AND the embedded router calldata consistent: rewrite routesAmount[0] and
        // scale the floor in the payload too, so the advertised sizing interface is truthful. Single-route /
        // zero-fee only; rescaleSingleRoute reverts for multi-route or fixed-fee payloads (fail closed).
        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory txData_ =
            abi.decode(BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength), (bytes));
        PancakeSwapAmountUpdater.rescaleSingleRoute(txData_, amounts[0]);
        bytes memory newPayload = abi.encode(txData_);
        return bytes.concat(
            _replaceCalldataAmount(
                BytesLib.slice(data, 0, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET), amounts[0], AMOUNT_POSITION
            ),
            bytes32(newPayload.length),
            newPayload
        );
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

    // ─── Internal ────────────────────────────────────────────────────────────

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (_isNative(outputToken)) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }

    function _isNative(address token_) private view returns (bool) {
        return token_ == address(0) || token_ == NATIVE || token_ == AGGREGATOR_NATIVE;
    }

    function _validateTokenPair(address inputToken_, address outputToken_) private view {
        if (_isSameToken(inputToken_, outputToken_)) revert SAME_INPUT_OUTPUT_TOKEN();
    }

    function _isSameToken(address tokenA_, address tokenB_) private view returns (bool) {
        if (_isNative(tokenA_) && _isNative(tokenB_)) {
            return true;
        }
        return tokenA_ == tokenB_;
    }
}
