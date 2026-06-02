// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { OpenOceanSparkDexScaler } from "../../../src/libraries/OpenOceanSparkDexScaler.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanAPIParser } from "../../utils/parsers/OpenOceanAPIParser.sol";

/// @title OpenOceanSparkDexAPIScaleTest
/// @notice Uses real OpenOcean V4 SparkDexV4 calldata and verifies the scaler updates amounts safely.
/// @dev Requires FFI/Surl network access. Run with:
///      forge test --match-contract OpenOceanSparkDexAPIScaleTest --skip CCTPHooksFork -vvv
contract OpenOceanSparkDexAPIScaleTest is Test, OpenOceanAPIParser {
    address internal constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address internal constant OPENOCEAN_CALLER_FLARE = 0x6dd434082EAB5Cd134B33719ec1FF05fE985B97b;

    address internal constant FLR = 0x0000000000000000000000000000000000000000;
    address internal constant SPRK = 0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0;

    function test_OpenOceanAPI_SparkDexCalldataScalesUp() public {
        OpenOceanSwapResponse memory quote =
            surlCallOpenOceanSparkDexSwap(FLR, SPRK, "1.000000000000000000", address(this));

        uint256 newAmount = quote.inAmount * 105 / 100;
        bytes memory updated = OpenOceanSparkDexScaler.updateTxDataAmounts(
            quote.txData, OPENOCEAN_CALLER_FLARE, newAmount, quote.inAmount
        );

        _assertScaledSwap(quote, updated, newAmount);
    }

    function test_OpenOceanAPI_SparkDexCalldataScalesDown() public {
        OpenOceanSwapResponse memory quote =
            surlCallOpenOceanSparkDexSwap(FLR, SPRK, "1.000000000000000000", address(this));

        uint256 newAmount = quote.inAmount * 95 / 100;
        bytes memory updated = OpenOceanSparkDexScaler.updateTxDataAmounts(
            quote.txData, OPENOCEAN_CALLER_FLARE, newAmount, quote.inAmount
        );

        _assertScaledSwap(quote, updated, newAmount);
    }

    function _assertScaledSwap(
        OpenOceanSwapResponse memory quote_,
        bytes memory updated_,
        uint256 newAmount_
    )
        internal
        pure
    {
        assertEq(quote_.to, OPENOCEAN_ROUTER);
        assertEq(quote_.value, quote_.inAmount);

        (IOpenOceanCaller originalCaller, IOpenOceanExchange.SwapDescription memory originalDesc,) =
            _decodeSwap(quote_.txData);
        (
            IOpenOceanCaller updatedCaller,
            IOpenOceanExchange.SwapDescription memory updatedDesc,
            IOpenOceanCaller.CallDescription[] memory updatedCalls
        ) = _decodeSwap(updated_);

        assertEq(address(originalCaller), OPENOCEAN_CALLER_FLARE);
        assertEq(address(updatedCaller), OPENOCEAN_CALLER_FLARE);
        assertEq(address(originalDesc.srcToken), FLR);
        assertEq(address(originalDesc.dstToken), SPRK);
        assertEq(originalDesc.amount, quote_.inAmount);
        assertEq(originalDesc.minReturnAmount, quote_.minOutAmount);

        assertEq(updatedDesc.amount, newAmount_);
        assertEq(
            updatedDesc.minReturnAmount,
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, quote_.inAmount, quote_.minOutAmount)
        );
        assertEq(
            updatedDesc.guaranteedAmount,
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, quote_.inAmount, originalDesc.guaranteedAmount)
        );
        assertEq(_sumCallValues(updatedCalls), newAmount_);
        assertEq(_sumDirectPositiveSwapAmounts(updatedCalls), newAmount_);
    }

    function _decodeSwap(bytes memory txData_)
        internal
        pure
        returns (
            IOpenOceanCaller caller_,
            IOpenOceanExchange.SwapDescription memory desc_,
            IOpenOceanCaller.CallDescription[] memory calls_
        )
    {
        bytes memory payload = new bytes(txData_.length - 4);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = txData_[i + 4];
        }

        return abi.decode(
            payload, (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
    }

    function _sumCallValues(IOpenOceanCaller.CallDescription[] memory calls_) internal pure returns (uint256 sum) {
        for (uint256 i; i < calls_.length; ++i) {
            sum += calls_[i].value;
        }
    }

    function _sumDirectPositiveSwapAmounts(IOpenOceanCaller.CallDescription[] memory calls_)
        internal
        pure
        returns (uint256 sum)
    {
        for (uint256 i; i < calls_.length; ++i) {
            if (_selector(calls_[i].data) == 0xe5b07cdb) {
                (,, int256 amount,,) =
                    abi.decode(_sliceAfterSelector(calls_[i].data), (address, bool, int256, address, bytes));
                if (amount > 0) {
                    sum += uint256(amount);
                }
            }
        }
    }

    function _selector(bytes memory data_) internal pure returns (bytes4 selector) {
        if (data_.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(data_, 0x20))
        }
    }

    function _sliceAfterSelector(bytes memory data_) internal pure returns (bytes memory result) {
        result = new bytes(data_.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data_[i + 4];
        }
    }
}
