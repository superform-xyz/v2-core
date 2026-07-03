// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "../../../vendor/1inch/I1InchAggregationRouterV6.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Swap1InchHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         uint256   placeholder0      = BytesLib.toUint256(data, 0);
/// @notice         address   placeholder1      = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken         = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken        = BytesLib.toAddress(data, 72);
/// @notice         uint256   value              = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote        = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin          = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount  = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength      = BytesLib.toUint256(data, 189);
/// @notice         address   dstReceiver        = BytesLib.toAddress(data, 221);
/// @notice         bytes     txData_            = BytesLib.slice(data, 241, payload_paramLength - 20);
contract Swap1InchHook is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow {
    using ProtocolLib for Address;
    using AddressLib for Address;
    using SafeCast for uint256;
    using SafeCast for int256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    I1InchAggregationRouterV6 public immutable AGGREGATION_ROUTER;
    uint256 private constant PRECISION = 1e5;

    /// @dev Position of dstReceiver in the payload (first 20 bytes of Layer 2)
    uint256 private constant DST_RECEIVER_POSITION = SwapCalldataLayout.PAYLOAD_DATA_OFFSET; // 221

    /// @dev Position of txData in the payload (after the 20-byte dstReceiver)
    uint256 private constant TXDATA_POSITION = SwapCalldataLayout.PAYLOAD_DATA_OFFSET + 20; // 241

    address public immutable NATIVE;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_RECEIVER();
    error INVALID_SELECTOR();
    error INVALID_TOKEN_PAIR();
    error INVALID_INPUT_AMOUNT();
    error INVALID_OUTPUT_AMOUNT();
    error INVALID_SELECTOR_OFFSET();
    error PARTIAL_FILL_NOT_ALLOWED();
    error INVALID_DESTINATION_TOKEN();

    constructor(address aggregationRouter_, address nativeToken_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (aggregationRouter_ == address(0)) {
            revert ZERO_ADDRESS();
        }

        AGGREGATION_ROUTER = I1InchAggregationRouterV6(aggregationRouter_);
        NATIVE = nativeToken_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap 1inch";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via 1inch aggregator";
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
        address dstToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 value = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        address dstReceiver = BytesLib.toAddress(data, DST_RECEIVER_POSITION);
        bytes memory txData_ = BytesLib.slice(data, TXDATA_POSITION, payloadLength - 20);

        bytes memory updatedTxData =
            _validateTxData(dstToken, dstReceiver, prevHook, account, usePrevHookAmount, txData_);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(AGGREGATION_ROUTER),
            value: usePrevHookAmount && value > 0 ? ISuperHookResult(prevHook).getOutAmount(account) : value,
            callData: usePrevHookAmount ? updatedTxData : txData_
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory packed) {
        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory txData_ = BytesLib.slice(data, TXDATA_POSITION, payloadLength - 20);

        bytes4 selector;
        assembly ("memory-safe") {
            selector := mload(add(txData_, 32))
        }

        if (selector == I1InchAggregationRouterV6.unoswapTo.selector) {
            (Address to, Address token,,, Address dex) =
                abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4), (Address, Address, uint256, uint256, Address));
            packed = abi.encodePacked(to.get(), token.get(), dex.get());
        } else if (selector == I1InchAggregationRouterV6.swap.selector) {
            (IAggregationExecutor executor, I1InchAggregationRouterV6.SwapDescription memory desc,) =
                abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4), (IAggregationExecutor, I1InchAggregationRouterV6.SwapDescription, bytes));
            packed = abi.encodePacked(
                address(executor),
                address(desc.srcToken),
                address(desc.dstToken),
                address(desc.srcReceiver),
                address(desc.dstReceiver)
            );
        } else if (selector == I1InchAggregationRouterV6.clipperSwapTo.selector) {
            (IClipperExchange clipperExchange, address recipient, Address srcToken, IERC20 dstToken,,,,,) = abi.decode(
                BytesLib.slice(txData_, 4, txData_.length - 4),
                (IClipperExchange, address, Address, IERC20, uint256, uint256, uint256, bytes32, bytes32)
            );
            packed = abi.encodePacked(address(clipperExchange), recipient, srcToken.get(), address(dstToken));
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless — 3 selectors with different amount positions in opaque txData
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
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

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _validateTxData(
        address dstToken,
        address dstReceiver,
        address prevHook,
        address account,
        bool usePrevHookAmount,
        bytes memory txData_
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        bytes4 selector;
        assembly ("memory-safe") {
            selector := mload(add(txData_, 32))
        }

        if (selector == I1InchAggregationRouterV6.unoswapTo.selector) {
            /// @dev support UNISWAP_V2, UNISWAP_V3, CURVE and all uniswap-based forks
            updatedTxData = _validateUnoswap(
                BytesLib.slice(txData_, 4, txData_.length - 4), dstReceiver, dstToken, prevHook, account, usePrevHookAmount
            );
        } else if (selector == I1InchAggregationRouterV6.swap.selector) {
            /// @dev support for generic router call
            updatedTxData = _validateGenericSwap(
                BytesLib.slice(txData_, 4, txData_.length - 4), dstReceiver, dstToken, prevHook, account, usePrevHookAmount
            );
        } else if (selector == I1InchAggregationRouterV6.clipperSwapTo.selector) {
            updatedTxData = _validateClipperSwap(
                BytesLib.slice(txData_, 4, txData_.length - 4), dstReceiver, dstToken, prevHook, account, usePrevHookAmount
            );
        } else {
            revert INVALID_SELECTOR();
        }

        if (updatedTxData.length > 0) {
            updatedTxData = bytes.concat(selector, updatedTxData);
        }
    }

    function _validateUnoswap(
        bytes memory txData_,
        address receiver,
        address toToken,
        address prevHook,
        address account,
        bool usePrevHookAmount
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        (Address to, Address token, uint256 amount, uint256 minReturn, Address dex) =
            abi.decode(txData_, (Address, Address, uint256, uint256, Address));

        address dstToken;

        ProtocolLib.Protocol protocol = dex.protocol();
        if (protocol == ProtocolLib.Protocol.Curve) {
            // CURVE
            uint256 selectorOffset =
                (Address.unwrap(dex) >> _CURVE_TO_COINS_SELECTOR_OFFSET) & _CURVE_TO_COINS_SELECTOR_MASK;
            uint256 dstTokenIndex = (Address.unwrap(dex) >> _CURVE_TO_COINS_ARG_OFFSET) & _CURVE_TO_COINS_ARG_MASK;
            uint128 dstTokenIndex128 = dstTokenIndex.toUint128();

            if (selectorOffset == 0) {
                dstToken = ICurvePool(dex.get()).base_coins(dstTokenIndex);
            } else if (selectorOffset == 4) {
                dstToken = ICurvePool(dex.get()).coins(int256(uint256(dstTokenIndex128)).toInt128());
            } else if (selectorOffset == 8) {
                dstToken = ICurvePool(dex.get()).coins(dstTokenIndex);
            } else if (selectorOffset == 12) {
                dstToken = ICurvePool(dex.get()).underlying_coins(int256(uint256(dstTokenIndex128)).toInt128());
            } else if (selectorOffset == 16) {
                dstToken = ICurvePool(dex.get()).underlying_coins(dstTokenIndex);
            } else {
                revert INVALID_SELECTOR_OFFSET();
            }
        } else {
            // UNISWAPV2 and UNISWAPV3
            address token0 = IUniswapPair(dex.get()).token0();
            address token1 = IUniswapPair(dex.get()).token1();

            address fromToken = token.get();
            if (token0 == fromToken) {
                dstToken = token1;
            } else if (token1 == fromToken) {
                dstToken = token0;
            } else {
                revert INVALID_TOKEN_PAIR();
            }
        }

        /// @dev remap of WETH to Native if unwrapWeth flag is true
        if (dex.shouldUnwrapWeth()) {
            dstToken = NATIVE;
        }

        if (usePrevHookAmount) {
            uint256 _prevAmount = amount;
            amount = ISuperHookResult(prevHook).getOutAmount(account);
            minReturn = HookDataUpdater.getUpdatedOutputAmount(amount, _prevAmount, minReturn);
        }

        if (amount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (minReturn == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (toToken != dstToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        address dstReceiver = to.get();
        if (dstReceiver != receiver) {
            revert INVALID_RECEIVER();
        }

        if (usePrevHookAmount) {
            updatedTxData = abi.encode(to, token, amount, minReturn, dex);
        }
    }

    function _validateGenericSwap(
        bytes memory txData_,
        address receiver,
        address toToken,
        address prevHook,
        address account,
        bool usePrevHookAmount
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        (IAggregationExecutor executor, I1InchAggregationRouterV6.SwapDescription memory desc, bytes memory data) =
            abi.decode(txData_, (IAggregationExecutor, I1InchAggregationRouterV6.SwapDescription, bytes));

        if (desc.flags & _PARTIAL_FILL != 0) {
            revert PARTIAL_FILL_NOT_ALLOWED();
        }

        if (address(desc.dstToken) != toToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        if (desc.dstReceiver != receiver) {
            revert INVALID_RECEIVER();
        }

        if (usePrevHookAmount) {
            uint256 _prevAmount = desc.amount;
            desc.amount = ISuperHookResult(prevHook).getOutAmount(account);
            desc.minReturnAmount =
                HookDataUpdater.getUpdatedOutputAmount(desc.amount, _prevAmount, desc.minReturnAmount);
        }

        if (desc.amount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (desc.minReturnAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (usePrevHookAmount) {
            updatedTxData = abi.encode(executor, desc, data);
        }
    }

    function _validateClipperSwap(
        bytes memory txData_,
        address receiver,
        address toToken,
        address prevHook,
        address account,
        bool usePrevHookAmount
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        // Decode all fields but only assign the ones we need to validate/modify
        (, address recipient,, IERC20 dstToken, uint256 inputAmount, uint256 outputAmount,,,) = abi.decode(
            txData_, (IClipperExchange, address, Address, IERC20, uint256, uint256, uint256, bytes32, bytes32)
        );

        if (recipient != receiver) {
            revert INVALID_RECEIVER();
        }

        if (address(dstToken) != toToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        if (usePrevHookAmount) {
            uint256 _prevAmount = inputAmount;
            inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
            outputAmount = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputAmount);
        }

        if (inputAmount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (outputAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (usePrevHookAmount) {
            // Create a copy of txData_ and update only the inputAmount field (5th parameter, position 128 bytes in) and
            // outputAmount field (6th parameter, position 160 bytes in)
            updatedTxData = txData_;
            // inputAmount is at position: 32 (clipperExchange) + 32 (recipient) + 32 (srcToken) + 32 (dstToken) = 128
            // outputAmount is at position: 32 (clipperExchange) + 32 (recipient) + 32 (srcToken) + 32 (dstToken) + 32
            // (inputAmount) = 160
            // bytes
            assembly ("memory-safe") {
                mstore(add(updatedTxData, add(0x20, 128)), inputAmount)
                mstore(add(updatedTxData, add(0x20, 160)), outputAmount)
            }
        }
    }

    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address dstToken = address(bytes20(data[SwapCalldataLayout.OUTPUT_TOKEN_OFFSET:SwapCalldataLayout.OUTPUT_TOKEN_OFFSET + 20]));
        address dstReceiver = address(bytes20(data[DST_RECEIVER_POSITION:DST_RECEIVER_POSITION + 20]));
        if (dstReceiver == address(0)) {
            dstReceiver = account;
        }

        if (dstToken == NATIVE || dstToken == address(0)) {
            return dstReceiver.balance;
        }
        return IERC20(dstToken).balanceOf(dstReceiver);
    }
}
