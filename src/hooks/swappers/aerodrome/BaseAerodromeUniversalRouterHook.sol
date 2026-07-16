// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Vendor
import { IAerodromeUniversalRouter } from "../../../vendor/aerodrome/IAerodromeUniversalRouter.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";

/// @title BaseAerodromeUniversalRouterHook
/// @author Superform Labs
/// @notice Shared implementation for exact-input Aerodrome Universal Router swap hooks
/// @dev Supports one homogeneous classic or Slipstream route using ERC20 tokens, including WETH
/// @dev Payload: abi.encode(uint8 routeKind, uint256 deadline, bytes packedPath)
/// @dev Native ETH, mixed routes, Permit2 flows, exact output, and arbitrary router commands are unsupported
abstract contract BaseAerodromeUniversalRouterHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    using BytesLib for bytes;

    struct AerodromeSwapParams {
        address tokenIn;
        address tokenOut;
        uint8 routeKind;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
        bytes packedPath;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Aerodrome Universal Router used for swaps
    IAerodromeUniversalRouter public immutable UNIVERSAL_ROUTER;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant ROUTE_KIND_CLASSIC = 0;
    uint8 internal constant ROUTE_KIND_SLIPSTREAM = 1;

    bytes1 internal constant V3_SWAP_EXACT_IN = 0x00;
    bytes1 internal constant V2_SWAP_EXACT_IN = 0x08;

    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;
    uint256 private constant PAYLOAD_STATIC_HEAD_LENGTH = 96;
    uint256 private constant PAYLOAD_BYTES_LENGTH_OFFSET = 96;
    uint256 private constant PAYLOAD_BYTES_DATA_OFFSET = 128;
    uint256 private constant MAX_HOPS = 9;

    uint24 private constant TICK_SPACING_MASK = 0x07ffff;
    uint24 private constant FACTORY_SELECTOR_MASK = 0x180000;
    uint24 private constant FACTORY_SELECTOR_LATEST = 0x080000;
    uint24 private constant FACTORY_SELECTOR_ORIGINAL = 0x100000;
    uint24 private constant RESERVED_POOL_PARAM_MASK = 0xe00000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the standard hook-data envelope is malformed
    error INVALID_HOOK_DATA();

    /// @notice Thrown when the protocol payload is not canonical ABI encoding
    error INVALID_PAYLOAD();

    /// @notice Thrown when the route kind is neither classic nor Slipstream
    error INVALID_ROUTE_KIND();

    /// @notice Thrown when a native-token representation is supplied instead of WETH
    error NATIVE_TOKEN_NOT_SUPPORTED();

    /// @notice Thrown when the input and output token are equal
    error SAME_INPUT_OUTPUT_TOKEN();

    /// @notice Thrown when quoted and minimum output amounts are inconsistent
    error INVALID_OUTPUT_AMOUNTS();

    /// @notice Thrown when a configured previous hook cannot provide a result
    error INVALID_PREV_HOOK();

    /// @notice Thrown when a previous hook's output token does not match this hook's input token
    error PREV_HOOK_TOKEN_MISMATCH();

    /// @notice Thrown when the swap deadline has passed
    /// @param deadline Provided deadline
    /// @param currentTimestamp Current block timestamp
    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);

    /// @notice Thrown when a packed path has zero or too many hops, or has an invalid length
    error INVALID_PATH_LENGTH();

    /// @notice Thrown when path tokens or endpoints are invalid
    error INVALID_PATH();

    /// @notice Thrown when a classic route's stable flag is not zero or one
    error INVALID_STABLE_FLAG();

    /// @notice Thrown when a Slipstream pool parameter uses an invalid tick spacing or factory selector
    error INVALID_POOL_PARAM();

    /// @notice Thrown when the output-token balance decreased during execution
    error OUTPUT_BALANCE_DECREASED();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the shared Aerodrome Universal Router hook implementation
    /// @param universalRouter_ Aerodrome Universal Router address
    constructor(address universalRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (universalRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        UNIVERSAL_ROUTER = IAerodromeUniversalRouter(universalRouter_);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
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
        AerodromeSwapParams memory params = _decodeSwapParams(prevHook, account, data);

        bytes memory commands = new bytes(1);
        commands[0] = params.routeKind == ROUTE_KIND_CLASSIC ? V2_SWAP_EXACT_IN : V3_SWAP_EXACT_IN;

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(account, params.amountIn, params.amountOutMin, params.packedPath, true, false);

        bytes memory swapCallData =
            abi.encodeCall(IAerodromeUniversalRouter.execute, (commands, inputs, params.deadline));

        if (!_includeApproval()) {
            executions = new Execution[](1);
            executions[0] = Execution({ target: address(UNIVERSAL_ROUTER), value: 0, callData: swapCallData });
            return executions;
        }

        executions = new Execution[](4);
        executions[0] = Execution({
            target: params.tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (address(UNIVERSAL_ROUTER), 0))
        });
        executions[1] = Execution({
            target: params.tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(UNIVERSAL_ROUTER), params.amountIn))
        });
        executions[2] = Execution({ target: address(UNIVERSAL_ROUTER), value: 0, callData: swapCallData });
        executions[3] = Execution({
            target: params.tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (address(UNIVERSAL_ROUTER), 0))
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(IERC20(outputToken).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 initialBalance = getOutAmount(account);
        uint256 finalBalance = IERC20(outputToken).balanceOf(account);
        if (finalBalance < initialBalance) revert OUTPUT_BALANCE_DECREASED();

        _setOutAmount(finalBalance - initialBalance, account);
        _setOutToken(outputToken, account);
    }

    /*//////////////////////////////////////////////////////////////
                              SWAP LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        if (data.length <= SwapCalldataLayout.USE_PREV_HOOK_OFFSET) revert INVALID_HOOK_DATA();
        uint8 rawValue = uint8(data[SwapCalldataLayout.USE_PREV_HOOK_OFFSET]);
        if (rawValue > 1) revert INVALID_HOOK_DATA();
        return rawValue == 1;
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        if (data.length < AMOUNT_POSITION + 32) revert INVALID_HOOK_DATA();
        amounts = new uint256[](1);
        amounts[0] = data.toUint256(AMOUNT_POSITION);
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
        if (data.length < AMOUNT_POSITION + 32) revert INVALID_HOOK_DATA();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        if (data.length < SwapCalldataLayout.OUTPUT_TOKEN_OFFSET + 20) revert INVALID_HOOK_DATA();
        return abi.encodePacked(data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET));
    }

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
        return data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputToken(bytes calldata data) external pure override returns (address) {
        return data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputAmount(bytes calldata data) external pure override returns (uint256) {
        return data.toUint256(SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputQuote(bytes calldata data) external pure override returns (uint256) {
        return data.toUint256(SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputMin(bytes calldata data) external pure override returns (uint256) {
        return data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodePayload(bytes calldata data) external pure override returns (bytes memory) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();
        uint256 payloadLength = data.toUint256(SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        if (payloadLength != data.length - SwapCalldataLayout.PAYLOAD_DATA_OFFSET) revert INVALID_HOOK_DATA();
        return BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
    }

    /// @dev This hook implements ISuperHookInflowOutflow and ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Selects whether this concrete hook includes temporary ERC20 approvals
    function _includeApproval() internal pure virtual returns (bool);

    function _decodeSwapParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        private
        view
        returns (AerodromeSwapParams memory params)
    {
        if (account == address(0)) revert ADDRESS_NOT_VALID();
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();

        uint8 rawUsePrevHookAmount = uint8(data[SwapCalldataLayout.USE_PREV_HOOK_OFFSET]);
        if (rawUsePrevHookAmount > 1) revert INVALID_HOOK_DATA();

        uint256 payloadLength = data.toUint256(SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        if (payloadLength != data.length - SwapCalldataLayout.PAYLOAD_DATA_OFFSET) revert INVALID_HOOK_DATA();

        params.tokenIn = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        params.tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (_isNative(params.tokenIn) || _isNative(params.tokenOut)) revert NATIVE_TOKEN_NOT_SUPPORTED();
        if (params.tokenIn == params.tokenOut) revert SAME_INPUT_OUTPUT_TOKEN();

        uint256 originalAmountIn = data.toUint256(SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        uint256 outputQuote = data.toUint256(SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
        uint256 originalAmountOutMin = data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        if (originalAmountIn == 0) revert AMOUNT_NOT_VALID();
        if (originalAmountOutMin == 0 || outputQuote < originalAmountOutMin) revert INVALID_OUTPUT_AMOUNTS();

        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
        (params.routeKind, params.deadline, params.packedPath) = _decodeCanonicalPayload(payload);

        if (params.routeKind > ROUTE_KIND_SLIPSTREAM) revert INVALID_ROUTE_KIND();
        if (params.deadline < block.timestamp) revert EXPIRED_DEADLINE(params.deadline, block.timestamp);

        if (params.routeKind == ROUTE_KIND_CLASSIC) {
            _validateClassicPath(params.packedPath, params.tokenIn, params.tokenOut);
        } else {
            _validateSlipstreamPath(params.packedPath, params.tokenIn, params.tokenOut);
        }

        params.amountIn = originalAmountIn;
        params.amountOutMin = originalAmountOutMin;

        if (rawUsePrevHookAmount == 1) {
            (params.amountIn, params.amountOutMin) =
                _scaleFromPreviousHook(prevHook, account, params.tokenIn, originalAmountIn, originalAmountOutMin);
        }
    }

    function _decodeCanonicalPayload(bytes memory payload)
        private
        pure
        returns (uint8 routeKind, uint256 deadline, bytes memory packedPath)
    {
        if (payload.length < PAYLOAD_BYTES_DATA_OFFSET) revert INVALID_PAYLOAD();

        uint256 routeKindWord = payload.toUint256(0);
        if (routeKindWord > type(uint8).max) revert INVALID_PAYLOAD();
        if (payload.toUint256(64) != PAYLOAD_STATIC_HEAD_LENGTH) revert INVALID_PAYLOAD();

        uint256 packedPathLength = payload.toUint256(PAYLOAD_BYTES_LENGTH_OFFSET);
        if (packedPathLength > 20 + 23 * MAX_HOPS) revert INVALID_PAYLOAD();

        uint256 paddedPathLength = (packedPathLength + 31) & ~uint256(31);
        if (payload.length != PAYLOAD_BYTES_DATA_OFFSET + paddedPathLength) revert INVALID_PAYLOAD();

        for (uint256 i = PAYLOAD_BYTES_DATA_OFFSET + packedPathLength; i < payload.length; ++i) {
            if (payload[i] != 0) revert INVALID_PAYLOAD();
        }

        routeKind = uint8(routeKindWord);
        deadline = payload.toUint256(32);
        packedPath = payload.slice(PAYLOAD_BYTES_DATA_OFFSET, packedPathLength);

        if (keccak256(payload) != keccak256(abi.encode(routeKind, deadline, packedPath))) {
            revert INVALID_PAYLOAD();
        }
    }

    function _scaleFromPreviousHook(
        address prevHook,
        address account,
        address inputToken,
        uint256 originalAmountIn,
        uint256 originalAmountOutMin
    )
        private
        view
        returns (uint256 amountIn, uint256 amountOutMin)
    {
        if (prevHook == address(0) || prevHook.code.length == 0) revert INVALID_PREV_HOOK();

        (bool success, bytes memory returnData) =
            prevHook.staticcall(abi.encodeCall(ISuperHookResult.getOutToken, (account)));
        if (!success || returnData.length != 32) revert INVALID_PREV_HOOK();

        uint256 previousTokenWord;
        assembly ("memory-safe") {
            previousTokenWord := mload(add(returnData, 0x20))
        }
        if (previousTokenWord > type(uint160).max) revert INVALID_PREV_HOOK();

        address previousToken = address(uint160(previousTokenWord));
        if (previousToken != inputToken) revert PREV_HOOK_TOKEN_MISMATCH();

        (success, returnData) = prevHook.staticcall(abi.encodeCall(ISuperHookResult.getOutAmount, (account)));
        if (!success || returnData.length != 32) revert INVALID_PREV_HOOK();
        assembly ("memory-safe") {
            amountIn := mload(add(returnData, 0x20))
        }
        if (amountIn == 0) revert AMOUNT_NOT_VALID();

        amountOutMin = HookDataUpdater.getUpdatedOutputAmount(amountIn, originalAmountIn, originalAmountOutMin);
        if (amountOutMin == 0) revert INVALID_OUTPUT_AMOUNTS();
    }

    function _validateClassicPath(
        bytes memory packedPath,
        address inputToken,
        address outputToken
    )
        private
        pure
    {
        if (packedPath.length < 41 || (packedPath.length - 20) % 21 != 0) revert INVALID_PATH_LENGTH();

        uint256 hops = (packedPath.length - 20) / 21;
        if (hops == 0 || hops > MAX_HOPS) revert INVALID_PATH_LENGTH();

        address currentToken = packedPath.toAddress(0);
        _validatePathToken(currentToken);
        if (currentToken != inputToken) revert INVALID_PATH();

        for (uint256 i; i < hops; ++i) {
            uint256 stableFlagOffset = 20 + i * 21;
            if (uint8(packedPath[stableFlagOffset]) > 1) revert INVALID_STABLE_FLAG();

            address nextToken = packedPath.toAddress(stableFlagOffset + 1);
            _validatePathToken(nextToken);
            if (nextToken == currentToken) revert INVALID_PATH();
            currentToken = nextToken;
        }

        if (currentToken != outputToken) revert INVALID_PATH();
    }

    function _validateSlipstreamPath(
        bytes memory packedPath,
        address inputToken,
        address outputToken
    )
        private
        pure
    {
        if (packedPath.length < 43 || (packedPath.length - 20) % 23 != 0) revert INVALID_PATH_LENGTH();

        uint256 hops = (packedPath.length - 20) / 23;
        if (hops == 0 || hops > MAX_HOPS) revert INVALID_PATH_LENGTH();

        address currentToken = packedPath.toAddress(0);
        _validatePathToken(currentToken);
        if (currentToken != inputToken) revert INVALID_PATH();

        for (uint256 i; i < hops; ++i) {
            uint256 poolParamOffset = 20 + i * 23;
            uint24 poolParam = (uint24(uint8(packedPath[poolParamOffset])) << 16)
                | (uint24(uint8(packedPath[poolParamOffset + 1])) << 8) | uint24(uint8(packedPath[poolParamOffset + 2]));

            uint24 selector = poolParam & FACTORY_SELECTOR_MASK;
            if (
                (poolParam & TICK_SPACING_MASK) == 0 || (poolParam & RESERVED_POOL_PARAM_MASK) != 0
                    || (selector != 0 && selector != FACTORY_SELECTOR_LATEST && selector != FACTORY_SELECTOR_ORIGINAL)
            ) {
                revert INVALID_POOL_PARAM();
            }

            address nextToken = packedPath.toAddress(poolParamOffset + 3);
            _validatePathToken(nextToken);
            if (nextToken == currentToken) revert INVALID_PATH();
            currentToken = nextToken;
        }

        if (currentToken != outputToken) revert INVALID_PATH();
    }

    function _validatePathToken(address token) private pure {
        if (_isNative(token)) revert NATIVE_TOKEN_NOT_SUPPORTED();
    }

    function _isNative(address token) private pure returns (bool) {
        return token == address(0) || token == NATIVE_TOKEN;
    }
}
