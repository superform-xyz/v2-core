// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import "../../../../vendor/1inch/I1InchAggregationRouterV6.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";

/// @title Swap1InchHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address dstToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address dstReceiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
/// @notice         bytes calldata txData_ = BytesLib.slice(data, 72, txData_.length - 72);
contract Swap1InchHook is BaseHook, ISuperHook {
    using AddressLib for Address;
    using ProtocolLib for Address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    I1InchAggregationRouterV6 public aggregationRouter;

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_RECEIVER();
    error INVALID_SELECTOR();
    error INVALID_TOKEN_PAIR();
    error INVALID_INPUT_AMOUNT();
    error INVALID_OUTPUT_AMOUNT();
    error INVALID_SOURCE_RECEIVER();
    error PARTIAL_FILL_NOT_ALLOWED();
    error INVALID_DESTINATION_TOKEN();

    constructor(
        address registry_,
        address aggregationRouter_
    )
        BaseHook(registry_, HookType.NONACCOUNTING)
    {
        if (aggregationRouter_ == address(0)) {
            revert ZERO_ADDRESS();
        }

        aggregationRouter = I1InchAggregationRouterV6(aggregationRouter_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    /// @dev doesn't use prevHook!
    function build(
        address,
        address account,
        bytes calldata data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));
        uint256 value = uint256(bytes32(data[40:72]));

        bytes calldata txData_ = data[72:];
        _validateTxData(account, dstToken, dstReceiver, txData_);

        executions = new Execution[](1);
        executions[0] = Execution({ target: address(aggregationRouter), value: value, callData: txData_ });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes calldata data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes calldata data) external {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _validateTxData(
        address account,
        address dstToken,
        address dstReceiver,
        bytes calldata txData_
    )
        private
        view
    {
        bytes4 selector = bytes4(txData_[:4]);

        if (selector == I1InchAggregationRouterV6.unoswapTo.selector) {
            /// @dev support UNISWAP_V2, UNISWAP_V3, CURVE and all uniswap-based forks
            _validateUnoswap(txData_[4:], dstReceiver, dstToken);
        } else if (selector == I1InchAggregationRouterV6.swap.selector) {
            /// @dev support for generic router call
            _validateGenericSwap(txData_[4:], dstReceiver, dstToken, account);
        } else if (selector == I1InchAggregationRouterV6.clipperSwapTo.selector) {
            _validateClipperSwap(txData_[4:], dstReceiver, dstToken);
        } else {
            revert INVALID_SELECTOR();
        }
    }

    function _validateClipperSwap(bytes calldata txData_, address receiver, address toToken) private pure {
        (, address dstReceiver,, IERC20 dstToken, uint256 amount, uint256 minReturnAmount,,,) = abi.decode(
            txData_, (IClipperExchange, address, Address, IERC20, uint256, uint256, uint256, bytes32, bytes32)
        );

        if (dstReceiver != receiver) {
            revert INVALID_RECEIVER();
        }

        if (amount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (minReturnAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (address(dstToken) != toToken) {
            revert INVALID_DESTINATION_TOKEN();
        }
    }

    function _validateGenericSwap(
        bytes calldata txData_,
        address receiver,
        address toToken,
        address account
    )
        private
        pure
    {
        //swap(IAggregationExecutor executor, SwapDescription calldata desc, bytes calldata permit, bytes calldata data)
        // external payable
        (, I1InchAggregationRouterV6.SwapDescription memory swapDescription,,) =
            abi.decode(txData_, (IAggregationExecutor, I1InchAggregationRouterV6.SwapDescription, bytes, bytes));

        if (swapDescription.flags & _PARTIAL_FILL != 0) {
            revert PARTIAL_FILL_NOT_ALLOWED();
        }

        if (address(swapDescription.dstToken) != toToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        if (swapDescription.dstReceiver != receiver) {
            revert INVALID_RECEIVER();
        }

        if (swapDescription.srcReceiver != account) {
            revert INVALID_SOURCE_RECEIVER();
        }

        if (swapDescription.amount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (swapDescription.minReturnAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }
    }

    function _validateUnoswap(bytes calldata txData_, address receiver, address toToken) private view {
        ///function unoswapTo(Address to,Address token,uint256 amount,uint256 minReturn,Address dex)
        (
            Address receiverUint256,
            Address fromTokenUint256,
            uint256 decodedFromAmount,
            uint256 minReturnAmount,
            Address dex
        ) = abi.decode(txData_, (Address, Address, uint256, uint256, Address));

        address dstToken;

        ProtocolLib.Protocol protocol = dex.protocol();
        if (protocol == ProtocolLib.Protocol.Curve) {
            // CURVE
            uint256 dstTokenIndex = (Address.unwrap(dex) >> _CURVE_TO_COINS_ARG_OFFSET) & _CURVE_TO_COINS_ARG_MASK;
            dstToken = ICurvePool(dex.get()).underlying_coins(int128(uint128(dstTokenIndex)));
        } else {
            // UNISWAPV2 and UNISWAPV3
            address token0 = IUniswapPair(dex.get()).token0();
            address token1 = IUniswapPair(dex.get()).token1();

            address fromToken = fromTokenUint256.get();
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

        if (decodedFromAmount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (minReturnAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (toToken != dstToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        address dstReceiver = receiverUint256.get();
        if (dstReceiver != receiver) {
            revert INVALID_RECEIVER();
        }
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));

        return IERC20(dstToken).balanceOf(dstReceiver);
    }
}
