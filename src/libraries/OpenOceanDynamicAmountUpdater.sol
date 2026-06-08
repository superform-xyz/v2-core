// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { HookDataUpdater } from "./HookDataUpdater.sol";
import { BytesLib } from "../vendor/BytesLib.sol";
import { IOpenOceanCaller } from "../vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../vendor/openocean/IOpenOceanExchange.sol";

/// @title OpenOceanDynamicAmountUpdater
/// @author Superform Labs
/// @notice Applies OpenOcean referrer-gated dynamic amount updates without decoding route internals.
library OpenOceanDynamicAmountUpdater {
    uint256 private constant PARTIAL_FILL = 0x01;

    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error ZERO_AMOUNT();
    error INVALID_SELECTOR();
    error INVALID_OPENOCEAN_REFERRER();
    error PARTIAL_FILL_NOT_ALLOWED();
    error INVALID_CALL_VALUE();

    function updateTxDataAmounts(
        bytes memory txData_,
        address expectedReferrer_,
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

        if (desc.referrer != expectedReferrer_) revert INVALID_OPENOCEAN_REFERRER();
        if ((desc.flags & PARTIAL_FILL) != 0) revert PARTIAL_FILL_NOT_ALLOWED();

        bool isNativeInput = _isNative(address(desc.srcToken));

        desc.amount = newAmount_;
        desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.minReturnAmount);
        desc.guaranteedAmount =
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.guaranteedAmount);

        if (isNativeInput) {
            _scaleNativeCallValues(calls, newAmount_, originalAmount_);
        } else {
            _validateNoCallValues(calls);
        }

        return abi.encodePacked(IOpenOceanExchange.swap.selector, abi.encode(caller, desc, calls));
    }

    function _scaleNativeCallValues(
        IOpenOceanCaller.CallDescription[] memory calls_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        private
        pure
    {
        uint256 originalValueSum;
        uint256 lastValueIndex = type(uint256).max;

        for (uint256 i; i < calls_.length; ++i) {
            if (calls_[i].value > 0) {
                originalValueSum += calls_[i].value;
                lastValueIndex = i;
            }
        }

        if (originalValueSum != originalAmount_) revert INVALID_CALL_VALUE();

        uint256 remainingValue = newAmount_;
        for (uint256 i; i < calls_.length; ++i) {
            if (calls_[i].value == 0) continue;

            if (i == lastValueIndex) {
                calls_[i].value = remainingValue;
            } else {
                uint256 scaledValue = Math.mulDiv(calls_[i].value, newAmount_, originalValueSum);
                remainingValue -= scaledValue;
                calls_[i].value = scaledValue;
            }
        }
    }

    function _validateNoCallValues(IOpenOceanCaller.CallDescription[] memory calls_) private pure {
        for (uint256 i; i < calls_.length; ++i) {
            if (calls_[i].value != 0) revert INVALID_CALL_VALUE();
        }
    }

    function _isNative(address token_) private pure returns (bool) {
        return token_ == address(0) || token_ == ETH_ADDRESS;
    }

    function _selector(bytes memory data_) private pure returns (bytes4 selector) {
        if (data_.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(data_, 0x20))
        }
    }
}
