// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../src/vendor/okx/IOkxSwapRouter.sol";
import "../../../src/vendor/okx/PMMLib.sol";

// Superform
import {BaseHook} from "../../../src/core/hooks/BaseHook.sol";

/// @title SwapperOkxHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address dstToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address dstReceiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
/// @notice         bytes calldata txData_ = BytesLib.slice(data, 72, txData_.length - 72);
contract SwapOkxHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IOkxSwapRouter public router;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error INVALID_VALUE();
    error INVALID_BATCH();
    error INVALID_RECEIVER();
    error INVALID_SELECTOR();
    error INVALID_ORDER_ID();
    error INVALID_BATCH_LENGTH();

    constructor(address router_) BaseHook(HookType.NONACCOUNTING, "Swap") {
        if (router_ == address(0)) {
            revert ZERO_ADDRESS();
        }

        router = IOkxSwapRouter(router_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function build(address, address, bytes calldata data)
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));
        uint256 value = uint256(bytes32(data[40:72]));

        bytes calldata txData_ = data[72:];
        _validateTxData(dstToken, dstReceiver, txData_, value);

        executions = new Execution[](1);
        executions[0] = Execution({target: address(router), value: value, callData: txData_});
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
    function _validateTxData(address dstToken, address dstReceiver, bytes calldata txData_, uint256 value)
        private
        pure
    {
        bytes4 selector = bytes4(txData_[:4]);

        if (selector == IOkxSwapRouter.smartSwapTo.selector) {
            _validateSmartSwap(txData_[4:], dstReceiver, dstToken);
        } else if (selector == IOkxSwapRouter.swapWrap.selector) {
            _validateSwapWrap(txData_[4:], dstReceiver, value);
        } else if (selector == IOkxSwapRouter.uniswapV3SwapTo.selector) {
            _validateUniswapV3Swap(txData_[4:], dstReceiver);
        } else {
            revert INVALID_SELECTOR();
        }
    }

    function _validateSmartSwap(bytes calldata txData_, address dstReceiver, address toToken) private pure {
        (
            uint256 orderId,
            address receiver,
            IOkxSwapRouter.BaseRequest memory baseRequest,
            uint256[] memory batchesAmount,
            IOkxSwapRouter.RouterPath[][] memory batches,
        ) = abi.decode(
            txData_,
            (
                uint256,
                address,
                IOkxSwapRouter.BaseRequest,
                uint256[],
                IOkxSwapRouter.RouterPath[][],
                PMMLib.PMMSwapRequest[]
            )
        );

        // the following is used as an unique identifier; it should be non-zero
        if (orderId == 0) revert INVALID_ORDER_ID();
        if (receiver != dstReceiver) revert INVALID_RECEIVER();
        if (baseRequest.toToken != toToken) revert INVALID_TOKEN();

        uint256 batchCount = batches.length;
        if (batchCount != batchesAmount.length) revert INVALID_BATCH_LENGTH();

        bool found;
        for (uint256 i; i < batchCount; ++i) {
            IOkxSwapRouter.RouterPath[] memory _batches = batches[i];
            for (uint256 j; j < _batches.length; ++j) {
                IOkxSwapRouter.RouterPath memory _batch = _batches[j];
                uint256 assetToLength = _batch.assetTo.length;
                for (uint256 k; k < assetToLength; ++k) {
                    if (_batch.assetTo[k] == toToken) {
                        found = true;
                        break;
                    }
                }
            }
        }
        if (!found) revert INVALID_BATCH();
    }

    function _validateSwapWrap(bytes calldata txData_, address dstReceiver, uint256 value) private pure {
        (uint256 orderId, address receiver,) = abi.decode(txData_, (uint256, address, uint256));
        // the following is used as an unique identifier; it should be non-zero
        if (orderId == 0) revert INVALID_ORDER_ID();
        if (receiver != dstReceiver) revert INVALID_RECEIVER();
        if (value == 0) revert INVALID_VALUE();

        //rawdata is validated on the router contract
    }

    function _validateUniswapV3Swap(bytes calldata txData_, address dstReceiver) private pure {
        (uint256 receiver,,,) = abi.decode(txData_, (uint256, uint256, uint256, uint256[]));

        if (address(uint160(receiver)) != dstReceiver) revert INVALID_RECEIVER();
    }

    function _getBalance(bytes calldata data) private view returns (uint256) {
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));

        return IERC20(dstToken).balanceOf(dstReceiver);
    }
}
