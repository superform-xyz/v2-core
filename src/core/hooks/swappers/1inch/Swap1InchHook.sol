// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";


/// @title Swap1InchHook
/// @dev data has the following structure
/// @notice  Swap1InchHookParams
/// address dstToken;
/// bytes swapData;
contract Swap1InchHook is BaseHook, ISuperHook {
    using AddressLib for Address;
    using ProtocolLib for Address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    I1InchAggregationRouterV6 public immutable aggregationRouter;

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
        address author_,
        address aggregationRouter_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
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
        executions[0] = Execution({
            target: address(aggregationRouter),
            value: value,
            callData: txData_
        });

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
    function _validateTxData(address account, address dstToken, address dstReceiver, bytes calldata txData_) private view {
        bytes4 selector = bytes4(txData_[:4]);

        if (selector == I1InchAggregationRouterV6.unoswapTo.selector) {
            /// @dev support UNISWAP_V2, UNISWAP_V3, CURVE and all uniswap-based forks
            _validateUnoswapTo(txData_[4:], dstToken, dstReceiver);
        } else if (selector == I1InchAggregationRouterV6.swap.selector) {
            /// @dev support for generic router call
            _validateGenericRouterSwap(txData_[4:], dstToken, dstReceiver, account);
        } else if (selector == I1InchAggregationRouterV6.clipperSwapTo.selector) {
            _validateClipperSwapTo(txData_[4:], dstReceiver, dstToken);
        } else {
            revert INVALID_SELECTOR();
        }
    }

    function _validateClipperSwapTo(bytes calldata txData_, address dstReceiver, address dstToken) private pure {
        (, address recipient,, IERC20 toToken, uint256 inputAmount, uint256 outputAmount,,,) =
            abi.decode(txData_, (IClipperExchange, address, Address, IERC20, uint256, uint256, uint256, bytes32, bytes32));


        if (recipient != dstReceiver) {
            revert INVALID_RECEIVER();
        }

        if (inputAmount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (outputAmount == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (address(toToken) != dstToken) {
            revert INVALID_DESTINATION_TOKEN();
        }
    }


    function _validateGenericRouterSwap(bytes calldata txData_, address dstToken, address dstReceiver, address account) private pure {
        //swap(IAggregationExecutor executor, SwapDescription calldata desc, bytes calldata permit, bytes calldata data) external payable
        (, I1InchAggregationRouterV6.SwapDescription memory swapDescription,,) =
            abi.decode(txData_, (IAggregationExecutor, I1InchAggregationRouterV6.SwapDescription, bytes, bytes));

        if (swapDescription.flags & _PARTIAL_FILL != 0) {
            revert PARTIAL_FILL_NOT_ALLOWED();
        }

        if (address(swapDescription.dstToken) != dstToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        if (swapDescription.dstReceiver != dstReceiver) {
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

    function _validateUnoswapTo(bytes calldata txData_, address dstToken, address dstReceiver) private view {
        ///function unoswapTo(Address to,Address token,uint256 amount,uint256 minReturn,Address dex)
        (Address receiverUint256, Address fromTokenUint256, uint256 decodedFromAmount, uint256 minReturn, Address dex) =
            abi.decode(txData_, (Address, Address, uint256, uint256, Address));

        address toToken;

        ProtocolLib.Protocol protocol = dex.protocol();
        /// @dev if protocol is curve
        if (protocol == ProtocolLib.Protocol.Curve) {
            uint256 toTokenIndex = (Address.unwrap(dex) >> _CURVE_TO_COINS_ARG_OFFSET) & _CURVE_TO_COINS_ARG_MASK;
            toToken = ICurvePool(dex.get()).underlying_coins(int128(uint128(toTokenIndex)));
        } else {
            address token0 = IUniswapPair(dex.get()).token0();
            address token1 = IUniswapPair(dex.get()).token1();

            address fromToken = fromTokenUint256.get();
            if (token0 == fromToken) {
                toToken = token1;
            } else if (token1 == fromToken) {
                toToken = token0;
            } else {
                revert INVALID_TOKEN_PAIR();
            }
        }

        /// @dev remap of WETH to Native if unwrapWeth flag is true
        if (dex.shouldUnwrapWeth()) {
            toToken = NATIVE;
        }

        if (decodedFromAmount == 0) {
            revert INVALID_INPUT_AMOUNT();
        }

        if (minReturn == 0) {
            revert INVALID_OUTPUT_AMOUNT();
        }

        if (toToken != dstToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        address receiver = receiverUint256.get();
        if (receiver != dstReceiver) {
            revert INVALID_RECEIVER();
        }
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));

        return IERC20(dstToken).balanceOf(dstReceiver);
    }
}