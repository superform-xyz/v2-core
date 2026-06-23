// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { OpenOceanDynamicAmountUpdater } from "../../../src/libraries/OpenOceanDynamicAmountUpdater.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanAPIParser } from "../../utils/parsers/OpenOceanAPIParser.sol";

/// @title OpenOceanAPIScaleTest
/// @notice Uses real OpenOcean V4 calldata and verifies the dynamic updater only changes owned fields.
/// @dev Requires FFI/Surl network access. Run with:
///      forge test --match-contract OpenOceanAPIScaleTest --skip CCTPHooksFork -vvv
contract OpenOceanAPIScaleTest is Test, OpenOceanAPIParser {
    address internal constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address internal constant OPENOCEAN_REFERRER_FLARE = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9;

    address internal constant FLR = 0x0000000000000000000000000000000000000000;
    address internal constant SPRK = 0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0;
    string internal constant ONE_TOKEN = "1000000000000000000";
    string internal constant SLIPPAGE = "1";

    function test_OpenOceanAPI_OpenOceanCalldataScalesUp() public {
        OpenOceanSwapResponse memory quote =
            surlCallOpenOceanDynamicSwap(FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_REFERRER_FLARE, SLIPPAGE);

        uint256 newAmount = quote.inAmount * 105 / 100;
        (bytes memory updated,,) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_REFERRER_FLARE, address(this), newAmount, quote.inAmount
        );

        _assertScaledSwap(quote, updated, newAmount);
    }

    function test_OpenOceanAPI_OpenOceanCalldataScalesDown() public {
        OpenOceanSwapResponse memory quote =
            surlCallOpenOceanDynamicSwap(FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_REFERRER_FLARE, SLIPPAGE);

        uint256 newAmount = quote.inAmount * 95 / 100;
        (bytes memory updated,,) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_REFERRER_FLARE, address(this), newAmount, quote.inAmount
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

        (
            IOpenOceanCaller originalCaller,
            IOpenOceanExchange.SwapDescription memory originalDesc,
            IOpenOceanCaller.CallDescription[] memory originalCalls
        ) = _decodeSwap(quote_.txData);
        (
            IOpenOceanCaller updatedCaller,
            IOpenOceanExchange.SwapDescription memory updatedDesc,
            IOpenOceanCaller.CallDescription[] memory updatedCalls
        ) = _decodeSwap(updated_);

        assertEq(address(updatedCaller), address(originalCaller));
        assertEq(address(originalDesc.srcToken), FLR);
        assertEq(address(originalDesc.dstToken), SPRK);
        assertEq(originalDesc.referrer, OPENOCEAN_REFERRER_FLARE);
        assertEq(updatedDesc.referrer, OPENOCEAN_REFERRER_FLARE);
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
        _assertNativeCallValues(originalCalls, updatedCalls, quote_.inAmount, newAmount_);
        _assertCallDataUnchanged(originalCalls, updatedCalls);
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

    function _assertCallDataUnchanged(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_
    )
        internal
        pure
    {
        assertEq(updatedCalls_.length, originalCalls_.length);
        for (uint256 i; i < updatedCalls_.length; ++i) {
            assertEq(updatedCalls_[i].target, originalCalls_[i].target);
            assertEq(updatedCalls_[i].gasLimit, originalCalls_[i].gasLimit);
            assertEq(keccak256(updatedCalls_[i].data), keccak256(originalCalls_[i].data));
        }
    }

    function _assertNativeCallValues(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_,
        uint256 originalAmount_,
        uint256 newAmount_
    )
        internal
        pure
    {
        uint256 originalValueSum = _sumCallValues(originalCalls_);
        uint256 updatedValueSum = _sumCallValues(updatedCalls_);

        if (originalValueSum == 0) {
            assertEq(updatedValueSum, 0);
            for (uint256 i; i < updatedCalls_.length; ++i) {
                assertEq(updatedCalls_[i].value, originalCalls_[i].value);
            }
        } else {
            assertEq(originalValueSum, originalAmount_);
            assertEq(updatedValueSum, newAmount_);
        }
    }
}
