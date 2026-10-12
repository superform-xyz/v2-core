// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ApproveAndSwapBinanceHook } from "../../../../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { SwapCalldataLayout } from "../../../../../src/libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";

import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockBinanceRouter } from "../../../../mocks/MockBinanceRouter.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";

/// @title BinanceHookBranches
/// @notice Branch / boundary completion for ApproveAndSwapBinanceHook: every conditional in the hook has a
///         test on BOTH sides, and every decoder is exercised at its minimum-length input. Complements
///         BinanceUnitTests (behaviour) and BinanceLeafCommitment (leaf encoding).
contract BinanceHookBranches is Helpers, InternalHelpers {
    ApproveAndSwapBinanceHook public hook;
    MockBinanceRouter public router;
    MockERC20 public inputToken;
    MockERC20 public outputToken;

    address public account;
    uint256 public constant CAP = 10_000e18;
    bytes public txData = hex"ad43f73d00000000";

    receive() external payable { }

    function setUp() public {
        account = address(this);
        inputToken = new MockERC20("USDT", "USDT", 18);
        outputToken = new MockERC20("AAPLB", "AAPLB", 18);
        router = new MockBinanceRouter();
        hook = new ApproveAndSwapBinanceHook(address(router), CAP);
    }

    function _data(
        uint256 amountIn,
        uint256 minOut,
        bool usePrev,
        address to,
        bytes memory tx_
    )
        internal
        view
        returns (bytes memory)
    {
        return
            _createBinanceSwapHookData(address(inputToken), address(outputToken), amountIn, 0, minOut, usePrev, to, tx_);
    }

    /// @dev Layer-1 only (exactly MIN_DATA_LENGTH bytes) with payloadLength = 0.
    function _layer1Only(uint256 amountIn, uint256 minOut) internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(inputToken)),
            bytes20(address(outputToken)),
            amountIn,
            uint256(0),
            minOut,
            false,
            uint256(0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                      _buildHookExecutions — remaining edges
    //////////////////////////////////////////////////////////////*/

    /// @dev Payload bytes that are not a valid abi.encode(address, bytes) head → abi.decode reverts.
    function test_Build_RevertIf_PayloadNotAbiEncoded() public {
        bytes memory payload = hex"01";
        bytes memory data = bytes.concat(_layer1Only(1e18, 1), payload);
        // patch payloadLength (offset 189) to 1 so the slice succeeds and abi.decode is what fails
        assembly {
            mstore(add(add(data, 0x20), 189), 1)
        }
        vm.expectRevert();
        hook.build(address(0), account, data);
    }

    /// @dev `to == address(0)` is just another mismatch, not a special case.
    function test_Build_RevertIf_PayloadToIsZero() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.ROUTER_MISMATCH.selector);
        hook.build(address(0), account, _data(1e18, 1, false, address(0), txData));
    }

    /// @dev Exactly four bytes of txData (a bare selector) is the minimum accepted.
    function test_Build_TxDataExactlyFourBytes_Allowed() public view {
        Execution[] memory executions =
            hook.build(address(0), account, _data(1e18, 1, false, address(router), hex"ad43f73d"));
        assertEq(executions.length, 6);
        assertEq(executions[3].callData, hex"ad43f73d");
    }

    function test_Build_TxDataEmpty_Reverts() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.build(address(0), account, _data(1e18, 1, false, address(router), ""));
    }

    /// @dev Smallest valid trade: inputAmount = 1, outputMin = 1.
    function test_Build_MinimalValidAmounts() public view {
        Execution[] memory executions = hook.build(address(0), account, _data(1, 1, false, address(router), txData));
        assertEq(executions.length, 6);
    }

    /// @dev Data exactly MIN_DATA_LENGTH long passes the length check and then fails on the empty payload.
    function test_Build_ExactMinLength_PassesLengthCheck_FailsOnPayload() public {
        bytes memory data = _layer1Only(1e18, 1);
        assertEq(data.length, SwapCalldataLayout.MIN_DATA_LENGTH);
        vm.expectRevert(); // abi.decode of zero bytes
        hook.build(address(0), account, data);
    }

    /// @dev The order of checks: usePrevHookAmount is rejected BEFORE the token / amount checks, so a
    ///      payload that is also invalid in every other way still surfaces USE_PREV_HOOK_NOT_SUPPORTED.
    function test_Build_CheckOrder_UsePrevBeforeTokens() public {
        bytes memory data = _createBinanceSwapHookData(address(0), address(0), 0, 0, 0, true, address(0), "");
        vm.expectRevert(ApproveAndSwapBinanceHook.USE_PREV_HOOK_NOT_SUPPORTED.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_CheckOrder_NativeBeforeSameToken() public {
        // both zero: NATIVE_ETH_NOT_SUPPORTED wins over SAME_INPUT_OUTPUT_TOKEN
        bytes memory data =
            _createBinanceSwapHookData(address(0), address(0), 1e18, 0, 1, false, address(router), txData);
        vm.expectRevert(ApproveAndSwapBinanceHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_CheckOrder_AmountZeroBeforeCap() public {
        // amount 0 is checked before the cap comparison
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, _data(0, 0, false, address(0), ""));
    }

    function test_Build_CheckOrder_CapBeforeMinOut() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(0), account, _data(CAP + 1, 0, false, address(0), ""));
    }

    function test_Build_CheckOrder_MinOutBeforePayload() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(0), account, _data(1e18, 0, false, address(0), ""));
    }

    function test_Build_CheckOrder_RouterBeforeTxDataLength() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.ROUTER_MISMATCH.selector);
        hook.build(address(0), account, _data(1e18, 1, false, address(0xBAD), ""));
    }

    /*//////////////////////////////////////////////////////////////
                        _preExecute — accumulator edges
    //////////////////////////////////////////////////////////////*/

    function test_TxSpent_FreshIsZero() public view {
        assertEq(hook.txSpent(account), 0);
        assertEq(hook.txSpent(address(0xBEEF)), 0);
    }

    function test_PreExecute_AccumulatesHeaderAmount() public {
        hook.preExecute(address(0), account, _data(123e18, 1, false, address(router), txData));
        assertEq(hook.txSpent(account), 123e18);
    }

    /// @dev Direct preExecute path: exactly the cap is allowed, one more in a fresh context is not.
    function test_PreExecute_AccumulatedExactlyCap_ThenOneMore_Reverts() public {
        hook.preExecute(address(0), account, _data(CAP, 1, false, address(router), txData));
        assertEq(hook.txSpent(account), CAP);

        hook.setExecutionContext(account); // fresh context, same tx → accumulator persists
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.preExecute(address(0), account, _data(1, 1, false, address(router), txData));
        assertEq(hook.txSpent(account), CAP, "a rejected preExecute does not advance the accumulator");
    }

    /// @dev preExecute does not re-run build's zero check; a zero header amount contributes nothing.
    function test_PreExecute_ZeroAmount_ContributesNothing() public {
        hook.preExecute(address(0), account, _data(0, 1, false, address(router), txData));
        assertEq(hook.txSpent(account), 0);
    }

    function test_PreExecute_SnapshotIsZeroWhenNoBalance() public {
        hook.preExecute(address(0), account, _data(1e18, 1, false, address(router), txData));
        assertEq(hook.getOutAmount(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        _postExecute — boundaries
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_ReceivedEqualsMinOut_Succeeds() public {
        bytes memory data = _data(1e18, 5e18, false, address(router), txData);
        hook.preExecute(address(0), account, data);
        outputToken.mint(account, 5e18);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), 5e18);
    }

    function test_PostExecute_ReceivedOneBelowMinOut_Reverts() public {
        bytes memory data = _data(1e18, 5e18, false, address(router), txData);
        hook.preExecute(address(0), account, data);
        outputToken.mint(account, 5e18 - 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev balanceAfter == balanceBefore is NOT a decrease; it falls through to MIN_OUT_NOT_MET.
    function test_PostExecute_UnchangedBalance_IsMinOutNotMet_NotDecreased() public {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        outputToken.mint(account, 7e18);
        hook.preExecute(address(0), account, data);
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev OUTPUT_BALANCE_DECREASED takes precedence over MIN_OUT_NOT_MET and ALLOWANCE_NOT_CLEARED.
    function test_PostExecute_CheckOrder_DecreasedBeforeMinOutAndAllowance() public {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        outputToken.mint(account, 7e18);
        hook.preExecute(address(0), account, data);
        outputToken.burn(account, 1);
        inputToken.approve(address(router), 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.OUTPUT_BALANCE_DECREASED.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev MIN_OUT_NOT_MET takes precedence over ALLOWANCE_NOT_CLEARED.
    function test_PostExecute_CheckOrder_MinOutBeforeAllowance() public {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        hook.preExecute(address(0), account, data);
        inputToken.approve(address(router), 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_AllowanceExactlyOneWei_Reverts() public {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        hook.preExecute(address(0), account, data);
        outputToken.mint(account, 1);
        inputToken.approve(address(router), 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.ALLOWANCE_NOT_CLEARED.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev Allowance to a DIFFERENT spender is not the hook's concern.
    function test_PostExecute_AllowanceToOtherSpender_Ignored() public {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        hook.preExecute(address(0), account, data);
        outputToken.mint(account, 1);
        inputToken.approve(address(0xBEEF), type(uint256).max);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    inspect / decoders at minimum length
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ExactMinLength_NoPayload() public view {
        bytes memory out = hook.inspect(_layer1Only(1e18, 1));
        assertEq(out, abi.encodePacked(address(inputToken), address(outputToken)));
    }

    function test_Inspect_OneByteShort_Reverts() public {
        bytes memory data = _layer1Only(1e18, 1);
        bytes memory short = new bytes(data.length - 1);
        for (uint256 i = 0; i < short.length; i++) {
            short[i] = data[i];
        }
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.inspect(short);
    }

    function test_DecodePayload_EmptyPayload() public view {
        assertEq(hook.decodePayload(_layer1Only(1e18, 1)).length, 0);
    }

    function test_DecodePayload_RoundTrip() public view {
        bytes memory data = _data(1e18, 1, false, address(router), txData);
        assertEq(hook.decodePayload(data), abi.encode(address(router), txData));
    }

    function test_Decoders_OnMinLengthData() public view {
        bytes memory data = _layer1Only(42, 7);
        assertEq(hook.decodeInputToken(data), address(inputToken));
        assertEq(hook.decodeOutputToken(data), address(outputToken));
        assertEq(hook.decodeInputAmount(data), 42);
        assertEq(hook.decodeOutputQuote(data), 0);
        assertEq(hook.decodeOutputMin(data), 7);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    /// @dev The ISuperHookSwap decoders have no length guard of their own (siblings do not either):
    ///      on short data they revert with BytesLib's out-of-bounds, not INVALID_HOOK_DATA.
    function test_Decoders_OnShortData_Revert() public {
        bytes memory short = new bytes(100);
        vm.expectRevert();
        hook.decodeInputAmount(short);
        vm.expectRevert();
        hook.decodeOutputMin(short);
        vm.expectRevert();
        hook.decodePayload(short);
        vm.expectRevert();
        hook.decodeUsePrevHookAmount(short);
    }

    function test_EncodeSwapData_UsePrevTrue_SetsFlagByte() public view {
        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: address(inputToken),
            outputToken: address(outputToken),
            inputAmount: 1,
            outputQuote: 2,
            outputMin: 3,
            usePrevHookAmount: true
        });
        bytes memory encoded = hook.encodeSwapData(header, "");
        assertEq(encoded.length, SwapCalldataLayout.MIN_DATA_LENGTH);
        assertEq(uint8(encoded[SwapCalldataLayout.USE_PREV_HOOK_OFFSET]), 1);
        assertTrue(hook.decodeUsePrevHookAmount(encoded));
        assertEq(hook.decodeOutputQuote(encoded), 2);
    }

    function test_EncodeSwapData_EmptyPayload_LengthField() public view {
        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: address(inputToken),
            outputToken: address(outputToken),
            inputAmount: 1,
            outputQuote: 0,
            outputMin: 1,
            usePrevHookAmount: false
        });
        bytes memory encoded = hook.encodeSwapData(header, "");
        assertEq(encoded, _layer1Only(1, 1));
    }

    /*//////////////////////////////////////////////////////////////
                            sizing / ERC-165 edges
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_UnknownId_False() public view {
        assertFalse(hook.supportsInterface(0xdeadbeef));
        assertFalse(hook.supportsInterface(0xffffffff));
    }

    function test_SupportsInterface_ERC165() public view {
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
    }

    function test_ReplaceCalldataAmounts_TwoAmounts_Reverts() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts("", _dualAmounts(1, 2));
    }

    function test_ReplaceCalldataAmounts_EmptyDataEmptyAmounts_Identity() public view {
        assertEq(hook.replaceCalldataAmounts("", new uint256[](0)).length, 0);
    }

    function test_DecodeAmounts_AmountRoles_EmptyOnAnyInput() public view {
        assertEq(hook.decodeAmounts(hex"00").length, 0);
        assertEq(hook.amountRoles(hex"ffff").length, 0);
    }

    function test_HookType_And_SubType() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), keccak256(bytes("Swap")));
    }

    /*//////////////////////////////////////////////////////////////
                        constructor boundary
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_CapOfOne_Allowed() public {
        ApproveAndSwapBinanceHook h = new ApproveAndSwapBinanceHook(address(router), 1);
        assertEq(h.MAX_INPUT_AMOUNT(), 1);
        Execution[] memory executions = h.build(address(0), account, _data(1, 1, false, address(router), txData));
        assertEq(executions.length, 6);
    }

    function test_Constructor_RouterCanBeAnyNonZero_EvenEOA() public {
        ApproveAndSwapBinanceHook h = new ApproveAndSwapBinanceHook(address(0xBEEF), CAP);
        assertEq(h.BINANCE_ROUTER(), address(0xBEEF));
    }
}
