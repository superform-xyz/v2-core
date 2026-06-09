// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { OpenOceanDynamicAmountUpdater } from "../../../src/libraries/OpenOceanDynamicAmountUpdater.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanAPIParser } from "../../utils/parsers/OpenOceanAPIParser.sol";

interface IWFLR {
    function deposit() external payable;
}

/// @title OpenOceanDynamicAmountValidationTest
/// @notice Validates Superform's OpenOcean referrer-gated dynamic updater on a live Flare fork.
/// @dev Requires FFI/Surl network access. Run with:
///      RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test
///        --match-contract OpenOceanDynamicAmountValidationTest -vvv
contract OpenOceanDynamicAmountValidationTest is Test, OpenOceanAPIParser {
    string internal constant FLARE_RPC = "https://flare-api.flare.network/ext/C/rpc";

    address internal constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address internal constant OPENOCEAN_DYNAMIC_REFERRER = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9;

    address internal constant FLR = 0x0000000000000000000000000000000000000000;
    address internal constant WFLR = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d;
    address internal constant SPRK = 0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0;

    string internal constant ONE_TOKEN = "1000000000000000000";
    string internal constant WIDE_SLIPPAGE = "50";

    receive() external payable { }

    modifier onlyWhenEnabled() {
        if (!vm.envOr("RUN_OPENOCEAN_DYNAMIC_VALIDATION", false)) {
            vm.skip(true);
        }
        _;
    }

    function test_OpenOceanDynamicAmount_NativeInput_ScalesDown() public onlyWhenEnabled {
        _validateNativeInput(95);
    }

    function test_OpenOceanDynamicAmount_NativeInput_ScalesUp() public onlyWhenEnabled {
        _validateNativeInput(105);
    }

    function test_OpenOceanDynamicAmount_Erc20Input_ScalesDown() public onlyWhenEnabled {
        _validateErc20Input(95);
    }

    function test_OpenOceanDynamicAmount_Erc20Input_ScalesUp() public onlyWhenEnabled {
        _validateErc20Input(105);
    }

    function _validateNativeInput(uint256 scalePercent_) private {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );
        (IOpenOceanCaller caller,,) = _decodeSwap(quote.txData);
        uint256 newAmount = quote.inAmount * scalePercent_ / 100;
        bytes memory scaled = _scaleTxDataAndAssertInvariants(quote.txData, address(this), newAmount, quote.inAmount);
        (, IOpenOceanExchange.SwapDescription memory scaledDesc,) = _decodeSwap(scaled);

        vm.createSelectFork(FLARE_RPC);
        vm.deal(address(this), newAmount);

        uint256 callerNativeBefore = address(caller).balance;
        uint256 callerWrappedNativeBefore = IERC20(WFLR).balanceOf(address(caller));
        uint256 outputBefore = IERC20(SPRK).balanceOf(address(this));
        _executeSwap(quote.to, scaled, newAmount);
        uint256 callerNativeDelta = address(caller).balance - callerNativeBefore;
        uint256 callerWrappedNativeDelta = IERC20(WFLR).balanceOf(address(caller)) - callerWrappedNativeBefore;
        uint256 outputDelta = IERC20(SPRK).balanceOf(address(this)) - outputBefore;

        assertEq(callerNativeDelta, 0, "caller retained native dust");
        assertEq(callerWrappedNativeDelta, 0, "caller retained wrapped native dust");
        assertGt(outputDelta, 0, "no SPRK received");
        assertGe(outputDelta, scaledDesc.minReturnAmount, "output below scaled wide-slippage min");
    }

    function _validateErc20Input(uint256 scalePercent_) private {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            WFLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );
        (IOpenOceanCaller caller,,) = _decodeSwap(quote.txData);
        uint256 newAmount = quote.inAmount * scalePercent_ / 100;
        bytes memory scaled = _scaleTxDataAndAssertInvariants(quote.txData, address(this), newAmount, quote.inAmount);
        (, IOpenOceanExchange.SwapDescription memory scaledDesc,) = _decodeSwap(scaled);

        vm.createSelectFork(FLARE_RPC);
        vm.deal(address(this), newAmount);
        IWFLR(WFLR).deposit{ value: newAmount }();
        IERC20(WFLR).approve(quote.to, newAmount);

        uint256 inputBefore = IERC20(WFLR).balanceOf(address(this));
        uint256 callerInputBefore = IERC20(WFLR).balanceOf(address(caller));
        uint256 outputBefore = IERC20(SPRK).balanceOf(address(this));
        _executeSwap(quote.to, scaled, quote.value);
        uint256 inputDelta = inputBefore - IERC20(WFLR).balanceOf(address(this));
        uint256 callerInputDelta = IERC20(WFLR).balanceOf(address(caller)) - callerInputBefore;
        uint256 outputDelta = IERC20(SPRK).balanceOf(address(this)) - outputBefore;

        assertEq(inputDelta, newAmount, "router did not consume patched ERC20 amount");
        assertEq(callerInputDelta, 0, "caller retained input dust");
        assertGt(outputDelta, 0, "no SPRK received");
        assertGe(outputDelta, scaledDesc.minReturnAmount, "output below scaled wide-slippage min");
    }

    function _scaleTxDataAndAssertInvariants(
        bytes memory txData_,
        address receiver_,
        uint256 newAmount_,
        uint256 originalAmount_
    )
        private
        pure
        returns (bytes memory scaled)
    {
        bytes4 originalSelector = _selector(txData_);
        assertEq(originalSelector, IOpenOceanExchange.swap.selector, "unexpected top-level selector");

        (
            IOpenOceanCaller originalCaller,
            IOpenOceanExchange.SwapDescription memory originalDesc,
            IOpenOceanCaller.CallDescription[] memory originalCalls
        ) = _decodeSwap(txData_);

        assertEq(originalDesc.referrer, OPENOCEAN_DYNAMIC_REFERRER, "dynamic referrer missing");

        (scaled,,) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            txData_, OPENOCEAN_DYNAMIC_REFERRER, receiver_, newAmount_, originalAmount_
        );

        (
            IOpenOceanCaller scaledCaller,
            IOpenOceanExchange.SwapDescription memory scaledDesc,
            IOpenOceanCaller.CallDescription[] memory scaledCalls
        ) = _decodeSwap(scaled);

        assertEq(_selector(scaled), originalSelector, "top-level selector changed");
        assertEq(address(scaledCaller), address(originalCaller), "caller changed");
        assertEq(scaledDesc.amount, newAmount_, "amount not scaled");
        assertEq(
            scaledDesc.minReturnAmount,
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, originalDesc.minReturnAmount),
            "min return not scaled"
        );
        assertEq(
            scaledDesc.guaranteedAmount,
            HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, originalDesc.guaranteedAmount),
            "guaranteed amount not scaled"
        );
        assertEq(scaledDesc.referrer, OPENOCEAN_DYNAMIC_REFERRER, "referrer changed");

        if (address(scaledDesc.srcToken) == FLR) {
            _assertNativeCallValues(originalCalls, scaledCalls, originalAmount_, newAmount_);
        }
        for (uint256 i; i < scaledCalls.length; ++i) {
            assertEq(keccak256(scaledCalls[i].data), keccak256(originalCalls[i].data), "route calldata changed");
        }
    }

    function _executeSwap(address router_, bytes memory txData_, uint256 value_) private {
        assertEq(router_, OPENOCEAN_ROUTER, "unexpected OpenOcean router");

        (bool success, bytes memory returnData) = router_.call{ value: value_ }(txData_);
        if (!success) {
            emit log_bytes(returnData);
        }
        assertTrue(success, "OpenOcean dynamic amount call failed");

        if (returnData.length >= 32) {
            assertGt(abi.decode(returnData, (uint256)), 0, "zero return amount");
        }
    }

    function _decodeSwap(bytes memory txData_)
        private
        pure
        returns (
            IOpenOceanCaller caller_,
            IOpenOceanExchange.SwapDescription memory desc_,
            IOpenOceanCaller.CallDescription[] memory calls_
        )
    {
        return abi.decode(
            _sliceAfterSelector(txData_),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
    }

    function _sumCallValues(IOpenOceanCaller.CallDescription[] memory calls_) private pure returns (uint256 sum) {
        for (uint256 i; i < calls_.length; ++i) {
            sum += calls_[i].value;
        }
    }

    function _assertNativeCallValues(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory scaledCalls_,
        uint256 originalAmount_,
        uint256 newAmount_
    )
        private
        pure
    {
        uint256 originalValueSum = _sumCallValues(originalCalls_);
        uint256 scaledValueSum = _sumCallValues(scaledCalls_);

        if (originalValueSum == 0) {
            assertEq(scaledValueSum, 0, "zero-value native route changed call values");
            for (uint256 i; i < scaledCalls_.length; ++i) {
                assertEq(scaledCalls_[i].value, originalCalls_[i].value, "native call value changed");
            }
        } else {
            assertEq(originalValueSum, originalAmount_, "native original value sum mismatch");
            assertEq(scaledValueSum, newAmount_, "native call values not scaled");
        }
    }

    // ───── Security Validation Tests ─────

    /// @notice Validates that updateTxDataAmounts returns correct srcToken and dstToken from real API calldata.
    function test_OpenOceanDynamicAmount_ReturnsSrcAndDstTokens() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        (, address srcToken, address dstToken) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, address(this), quote.inAmount, quote.inAmount
        );

        assertTrue(srcToken == FLR || srcToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, "unexpected srcToken");
        assertEq(dstToken, SPRK, "unexpected dstToken");
    }

    /// @notice Validates that updateTxDataAmounts returns correct tokens for an ERC-20 input swap.
    function test_OpenOceanDynamicAmount_Erc20Input_ReturnsSrcAndDstTokens() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            WFLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        (, address srcToken, address dstToken) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, address(this), quote.inAmount, quote.inAmount
        );

        assertEq(srcToken, WFLR, "unexpected srcToken for ERC20");
        assertEq(dstToken, SPRK, "unexpected dstToken for ERC20");
    }

    /// @notice Validates that a tampered dstReceiver in real API calldata is rejected.
    function test_OpenOceanDynamicAmount_RevertWhenReceiverTampered() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        address attacker = makeAddr("attacker");
        // The API produces calldata with dstReceiver == address(this), so passing attacker should revert
        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_DST_RECEIVER.selector);
        OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, attacker, quote.inAmount, quote.inAmount
        );
    }

    /// @notice Validates that a tampered dstReceiver is also rejected for ERC-20 input swaps.
    function test_OpenOceanDynamicAmount_Erc20Input_RevertWhenReceiverTampered() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            WFLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        address attacker = makeAddr("attacker");
        vm.expectRevert(OpenOceanDynamicAmountUpdater.INVALID_DST_RECEIVER.selector);
        OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, attacker, quote.inAmount, quote.inAmount
        );
    }

    /// @notice Validates that dstReceiver in real API calldata matches the account we requested.
    function test_OpenOceanDynamicAmount_DstReceiverMatchesRequestedAccount() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        (, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(quote.txData);
        assertEq(desc.dstReceiver, address(this), "API dstReceiver does not match requested account");
    }

    /// @notice Validates that native swap on fork with correct receiver succeeds end-to-end.
    function test_OpenOceanDynamicAmount_NativeInput_E2EWithReceiverValidation() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            FLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        // This call succeeds because dstReceiver == address(this) as passed to the API
        (bytes memory scaled, address srcToken, address dstToken) = OpenOceanDynamicAmountUpdater
            .updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, address(this), quote.inAmount, quote.inAmount
        );

        assertTrue(srcToken == FLR || srcToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, "srcToken not native");
        assertEq(dstToken, SPRK, "dstToken mismatch");

        vm.createSelectFork(FLARE_RPC);
        vm.deal(address(this), quote.inAmount);

        uint256 outputBefore = IERC20(SPRK).balanceOf(address(this));
        _executeSwap(quote.to, scaled, quote.inAmount);
        uint256 outputDelta = IERC20(SPRK).balanceOf(address(this)) - outputBefore;
        assertGt(outputDelta, 0, "no SPRK received after receiver-validated swap");
    }

    /// @notice Validates that ERC-20 swap on fork with correct receiver succeeds end-to-end.
    function test_OpenOceanDynamicAmount_Erc20Input_E2EWithReceiverValidation() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanDynamicSwap(
            WFLR, SPRK, ONE_TOKEN, address(this), OPENOCEAN_DYNAMIC_REFERRER, WIDE_SLIPPAGE
        );

        (bytes memory scaled, address srcToken, address dstToken) = OpenOceanDynamicAmountUpdater
            .updateTxDataAmounts(
            quote.txData, OPENOCEAN_DYNAMIC_REFERRER, address(this), quote.inAmount, quote.inAmount
        );

        assertEq(srcToken, WFLR, "srcToken not WFLR");
        assertEq(dstToken, SPRK, "dstToken mismatch");

        vm.createSelectFork(FLARE_RPC);
        vm.deal(address(this), quote.inAmount);
        IWFLR(WFLR).deposit{ value: quote.inAmount }();
        IERC20(WFLR).approve(quote.to, quote.inAmount);

        uint256 outputBefore = IERC20(SPRK).balanceOf(address(this));
        _executeSwap(quote.to, scaled, quote.value);
        uint256 outputDelta = IERC20(SPRK).balanceOf(address(this)) - outputBefore;
        assertGt(outputDelta, 0, "no SPRK received after receiver-validated ERC20 swap");
    }

    // ───── Helpers ─────

    function _selector(bytes memory data_) private pure returns (bytes4 selector) {
        if (data_.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(data_, 0x20))
        }
    }

    function _sliceAfterSelector(bytes memory data_) private pure returns (bytes memory result) {
        result = new bytes(data_.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data_[i + 4];
        }
    }
}
