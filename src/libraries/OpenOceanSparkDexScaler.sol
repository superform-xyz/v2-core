// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { HookDataUpdater } from "./HookDataUpdater.sol";
import { BytesLib } from "../vendor/BytesLib.sol";
import { IOpenOceanCaller } from "../vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../vendor/openocean/IOpenOceanExchange.sol";

/// @title OpenOceanSparkDexScaler
/// @author Superform Labs
/// @notice Selector-aware calldata scaler for OpenOcean V4 routes constrained to SparkDexV4.
library OpenOceanSparkDexScaler {
    uint256 private constant PARTIAL_FILL = 0x01;
    uint256 private constant DISTRIBUTION_SENTINEL = (uint256(1) << 128) + 1;
    uint256 private constant DISTRIBUTION_UNISWAP_AMOUNT_BIAS = 0x44;
    uint256 private constant DISTRIBUTION_SAFE_TRANSFER_AMOUNT_BIAS = 0x44;
    uint256 private constant DISTRIBUTION_WITHDRAW_AMOUNT_BIAS = 0x04;
    uint256 private constant DISTRIBUTION_PATCH_SENTINEL = 1;
    uint256 private constant COLLECT_SLIPPAGE_LOW_MASK = (uint256(1) << 240) - 1;
    uint256 private constant MAX_NESTED_MAKE_CALL_DEPTH = 10;

    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes4 private constant UNISWAP_V3_SWAP_SELECTOR = 0xe5b07cdb;
    bytes4 private constant SINGLE_DISTRIBUTION_CALL_SELECTOR = 0x9f865422;
    bytes4 private constant MULTI_DISTRIBUTION_CALL_SELECTOR = 0x51a74316;
    bytes4 private constant COLLECT_SLIPPAGE_SELECTOR = 0x8a6a1e85;
    bytes4 private constant SAFE_TRANSFER_SELECTOR = 0xd1660f99;
    bytes4 private constant DEPOSIT_SELECTOR = 0xd0e30db0;
    bytes4 private constant WITHDRAW_SELECTOR = 0x2e1a7d4d;
    bytes4 private constant MAKE_CALL_SELECTOR = 0x0c7e1209;
    bytes4 private constant MAKE_CALLS_SELECTOR = 0xa8920d2b;

    error ZERO_AMOUNT();
    error INVALID_SELECTOR();
    error INVALID_OPENOCEAN_CALLER();
    error PARTIAL_FILL_NOT_ALLOWED();
    error INVALID_DISTRIBUTION();
    error INVALID_AMOUNT_BIAS();
    error INVALID_AMOUNT();
    error INVALID_CALL_VALUE();
    error DIRECT_SAFE_TRANSFER_NOT_SUPPORTED();
    error MAX_CALL_DEPTH_EXCEEDED();

    function updateTxDataAmounts(
        bytes memory txData_,
        address expectedCaller_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        if (newAmount_ == 0 || originalAmount_ == 0) revert ZERO_AMOUNT();
        if (_selector(txData_) != IOpenOceanExchange.swap.selector) revert INVALID_SELECTOR();

        (
            IOpenOceanCaller caller,
            IOpenOceanExchange.SwapDescription memory desc,
            IOpenOceanCaller.CallDescription[] memory calls
        ) = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );

        if (address(caller) != expectedCaller_) revert INVALID_OPENOCEAN_CALLER();
        if ((desc.flags & PARTIAL_FILL) != 0) revert PARTIAL_FILL_NOT_ALLOWED();

        bool isNativeInput = _isNative(address(desc.srcToken));

        desc.amount = newAmount_;
        desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.minReturnAmount);
        desc.guaranteedAmount =
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.guaranteedAmount);

        _updateCalls(calls, newAmount_, originalAmount_, isNativeInput);

        return abi.encodePacked(IOpenOceanExchange.swap.selector, abi.encode(caller, desc, calls));
    }

    function _updateCalls(
        IOpenOceanCaller.CallDescription[] memory calls_,
        uint256 newAmount_,
        uint256 originalAmount_,
        bool isNativeInput_
    )
        private
        pure
    {
        uint256 originalValueSum;
        uint256 lastValueIndex = type(uint256).max;
        uint256 originalInputAmountSum;
        uint256 lastInputAmountIndex = type(uint256).max;

        for (uint256 i; i < calls_.length; ++i) {
            if (calls_[i].value > 0) {
                originalValueSum += calls_[i].value;
                lastValueIndex = i;
            }

            uint256 inputAmount = _directInputAmount(calls_[i].data);
            if (inputAmount > 0) {
                originalInputAmountSum += inputAmount;
                lastInputAmountIndex = i;
            }
        }

        if (isNativeInput_) {
            if (originalValueSum != originalAmount_) revert INVALID_CALL_VALUE();
        } else if (originalValueSum != 0) {
            revert INVALID_CALL_VALUE();
        }

        uint256 remainingValue = newAmount_;
        uint256 remainingInputAmount = newAmount_;
        bool exactInputScaling = originalInputAmountSum == originalAmount_ && originalInputAmountSum > 0;
        for (uint256 i; i < calls_.length; ++i) {
            (calls_[i].data, remainingInputAmount) = _updateCallData(
                calls_[i].data,
                newAmount_,
                originalAmount_,
                exactInputScaling ? originalInputAmountSum : 0,
                remainingInputAmount,
                i == lastInputAmountIndex,
                0
            );

            if (calls_[i].value > 0) {
                if (i == lastValueIndex) {
                    calls_[i].value = remainingValue;
                } else {
                    uint256 scaledValue = Math.mulDiv(calls_[i].value, newAmount_, originalValueSum);
                    remainingValue -= scaledValue;
                    calls_[i].value = scaledValue;
                }
            }
        }
    }

    function _updateCallData(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_,
        uint256 exactInputDenominator_,
        uint256 remainingInputAmount_,
        bool isLastInputAmount_,
        uint256 callDepth_
    )
        private
        pure
        returns (bytes memory updatedData, uint256 remainingInputAmount)
    {
        bytes4 selector = _selector(data_);
        remainingInputAmount = remainingInputAmount_;

        if (selector == UNISWAP_V3_SWAP_SELECTOR) {
            updatedData = _updateUniswapV3Swap(
                data_, newAmount_, originalAmount_, exactInputDenominator_, remainingInputAmount_, isLastInputAmount_
            );
            if (exactInputDenominator_ > 0) {
                remainingInputAmount = isLastInputAmount_ ? 0 : remainingInputAmount_ - _directInputAmount(updatedData);
            }
            return (updatedData, remainingInputAmount);
        }
        if (selector == SINGLE_DISTRIBUTION_CALL_SELECTOR) {
            return (_validateSingleDistributionCall(data_), remainingInputAmount);
        }
        if (selector == MULTI_DISTRIBUTION_CALL_SELECTOR) {
            return (_validateMultiDistributionCall(data_), remainingInputAmount);
        }
        if (selector == COLLECT_SLIPPAGE_SELECTOR) {
            return (_updateCollectSlippage(data_, newAmount_, originalAmount_), remainingInputAmount);
        }
        if (selector == SAFE_TRANSFER_SELECTOR) {
            revert DIRECT_SAFE_TRANSFER_NOT_SUPPORTED();
        }
        if (selector == DEPOSIT_SELECTOR) {
            if (data_.length != 4) revert INVALID_SELECTOR();
            return (data_, remainingInputAmount);
        }
        if (selector == WITHDRAW_SELECTOR) {
            updatedData = _updateWithdraw(
                data_, newAmount_, originalAmount_, exactInputDenominator_, remainingInputAmount_, isLastInputAmount_
            );
            if (exactInputDenominator_ > 0) {
                remainingInputAmount = isLastInputAmount_ ? 0 : remainingInputAmount_ - _directInputAmount(updatedData);
            }
            return (updatedData, remainingInputAmount);
        }
        if (selector == MAKE_CALL_SELECTOR) {
            return
                (_updateMakeCall(data_, newAmount_, originalAmount_, _nextCallDepth(callDepth_)), remainingInputAmount);
        }
        if (selector == MAKE_CALLS_SELECTOR) {
            return
                (_updateMakeCalls(data_, newAmount_, originalAmount_, _nextCallDepth(callDepth_)), remainingInputAmount);
        }

        revert INVALID_SELECTOR();
    }

    function _updateUniswapV3Swap(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_,
        uint256 exactInputDenominator_,
        uint256 remainingInputAmount_,
        bool isLastInputAmount_
    )
        private
        pure
        returns (bytes memory)
    {
        (address pool, bool zeroForOne, int256 amountSpecified, address recipient, bytes memory path) =
            abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (address, bool, int256, address, bytes));

        if (amountSpecified <= 0) revert INVALID_AMOUNT();
        amountSpecified = int256(
            exactInputDenominator_ == 0
                ? Math.mulDiv(uint256(amountSpecified), newAmount_, originalAmount_)
                : isLastInputAmount_
                    ? remainingInputAmount_
                    : Math.mulDiv(uint256(amountSpecified), newAmount_, exactInputDenominator_)
        );
        if (amountSpecified == 0) revert INVALID_AMOUNT();

        return
            abi.encodePacked(UNISWAP_V3_SWAP_SELECTOR, abi.encode(pool, zeroForOne, amountSpecified, recipient, path));
    }

    function _validateSingleDistributionCall(bytes memory data_) private pure returns (bytes memory) {
        (address token, uint256 distribution, IOpenOceanCaller.CallDescription memory desc, uint256 amountBias) = abi.decode(
            BytesLib.slice(data_, 4, data_.length - 4), (address, uint256, IOpenOceanCaller.CallDescription, uint256)
        );

        _validateDistribution(distribution, desc, amountBias);
        return abi.encodePacked(SINGLE_DISTRIBUTION_CALL_SELECTOR, abi.encode(token, distribution, desc, amountBias));
    }

    function _validateMultiDistributionCall(bytes memory data_) private pure returns (bytes memory) {
        (
            address token,
            uint256 distribution,
            IOpenOceanCaller.CallDescription[] memory descs,
            uint256[] memory amountBiases
        ) = abi.decode(
            BytesLib.slice(data_, 4, data_.length - 4),
            (address, uint256, IOpenOceanCaller.CallDescription[], uint256[])
        );

        if (descs.length != amountBiases.length) revert INVALID_DISTRIBUTION();
        for (uint256 i; i < descs.length; ++i) {
            _validateDistribution(distribution, descs[i], amountBiases[i]);
        }

        return abi.encodePacked(MULTI_DISTRIBUTION_CALL_SELECTOR, abi.encode(token, distribution, descs, amountBiases));
    }

    function _validateDistribution(
        uint256 distribution_,
        IOpenOceanCaller.CallDescription memory desc_,
        uint256 amountBias_
    )
        private
        pure
    {
        if (distribution_ != DISTRIBUTION_SENTINEL) revert INVALID_DISTRIBUTION();
        if (desc_.value != 0) revert INVALID_CALL_VALUE();
        _validateDistributionPatchTarget(desc_.data, amountBias_);
    }

    function _validateDistributionPatchTarget(bytes memory data_, uint256 amountBias_) private pure {
        if (amountBias_ + 32 > data_.length) revert INVALID_AMOUNT_BIAS();

        bytes4 selector = _selector(data_);
        if (selector == UNISWAP_V3_SWAP_SELECTOR) {
            if (amountBias_ != DISTRIBUTION_UNISWAP_AMOUNT_BIAS) revert INVALID_AMOUNT_BIAS();
            if (BytesLib.toUint256(data_, amountBias_) != DISTRIBUTION_PATCH_SENTINEL) revert INVALID_AMOUNT();
            return;
        }
        if (selector == SAFE_TRANSFER_SELECTOR) {
            if (amountBias_ != DISTRIBUTION_SAFE_TRANSFER_AMOUNT_BIAS) revert INVALID_AMOUNT_BIAS();
            if (BytesLib.toUint256(data_, amountBias_) != DISTRIBUTION_PATCH_SENTINEL) revert INVALID_AMOUNT();
            return;
        }
        if (selector == WITHDRAW_SELECTOR) {
            if (amountBias_ != DISTRIBUTION_WITHDRAW_AMOUNT_BIAS) revert INVALID_AMOUNT_BIAS();
            if (BytesLib.toUint256(data_, amountBias_) != DISTRIBUTION_PATCH_SENTINEL) revert INVALID_AMOUNT();
            return;
        }

        revert INVALID_SELECTOR();
    }

    function _updateCollectSlippage(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        private
        pure
        returns (bytes memory)
    {
        (address token, address receiver, uint256 encodedAmount) =
            abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (address, address, uint256));

        uint256 lowAmount = encodedAmount & COLLECT_SLIPPAGE_LOW_MASK;
        if (lowAmount == 0) revert INVALID_AMOUNT();

        uint256 highBits = encodedAmount & ~COLLECT_SLIPPAGE_LOW_MASK;
        uint256 scaledLowAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, lowAmount);

        return abi.encodePacked(COLLECT_SLIPPAGE_SELECTOR, abi.encode(token, receiver, highBits | scaledLowAmount));
    }

    function _updateWithdraw(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_,
        uint256 exactInputDenominator_,
        uint256 remainingInputAmount_,
        bool isLastInputAmount_
    )
        private
        pure
        returns (bytes memory)
    {
        uint256 amount = abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (uint256));
        amount = exactInputDenominator_ == 0
            ? Math.mulDiv(amount, newAmount_, originalAmount_)
            : isLastInputAmount_ ? remainingInputAmount_ : Math.mulDiv(amount, newAmount_, exactInputDenominator_);
        if (amount == 0) revert INVALID_AMOUNT();

        return abi.encodePacked(WITHDRAW_SELECTOR, abi.encode(amount));
    }

    function _updateMakeCall(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_,
        uint256 callDepth_
    )
        private
        pure
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription memory desc =
            abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (IOpenOceanCaller.CallDescription));
        (desc.data,) = _updateCallData(desc.data, newAmount_, originalAmount_, 0, newAmount_, false, callDepth_);
        desc.value = Math.mulDiv(desc.value, newAmount_, originalAmount_);
        return abi.encodePacked(MAKE_CALL_SELECTOR, abi.encode(desc));
    }

    function _updateMakeCalls(
        bytes memory data_,
        uint256 newAmount_,
        uint256 originalAmount_,
        uint256 callDepth_
    )
        private
        pure
        returns (bytes memory)
    {
        IOpenOceanCaller.CallDescription[] memory descs =
            abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (IOpenOceanCaller.CallDescription[]));
        for (uint256 i; i < descs.length; ++i) {
            (descs[i].data,) =
                _updateCallData(descs[i].data, newAmount_, originalAmount_, 0, newAmount_, false, callDepth_);
            descs[i].value = Math.mulDiv(descs[i].value, newAmount_, originalAmount_);
        }
        return abi.encodePacked(MAKE_CALLS_SELECTOR, abi.encode(descs));
    }

    function _nextCallDepth(uint256 callDepth_) private pure returns (uint256) {
        if (callDepth_ >= MAX_NESTED_MAKE_CALL_DEPTH) revert MAX_CALL_DEPTH_EXCEEDED();
        return callDepth_ + 1;
    }

    function _directInputAmount(bytes memory data_) private pure returns (uint256) {
        bytes4 selector = _selector(data_);
        if (selector == UNISWAP_V3_SWAP_SELECTOR) {
            (,, int256 amountSpecified,,) =
                abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (address, bool, int256, address, bytes));
            if (amountSpecified <= 0) revert INVALID_AMOUNT();
            return uint256(amountSpecified);
        }
        if (selector == WITHDRAW_SELECTOR) {
            return abi.decode(BytesLib.slice(data_, 4, data_.length - 4), (uint256));
        }
        return 0;
    }

    function _selector(bytes memory data_) private pure returns (bytes4) {
        if (data_.length < 4) revert INVALID_SELECTOR();
        bytes4 selector;
        assembly {
            selector := mload(add(data_, 0x20))
        }
        return selector;
    }

    function _isNative(address token_) private pure returns (bool) {
        return token_ == address(0) || token_ == ETH_ADDRESS;
    }
}
