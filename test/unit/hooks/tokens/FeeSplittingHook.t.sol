// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { FeeSplittingHook } from "../../../../src/hooks/tokens/FeeSplittingHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

contract FeeSplittingHookTest is Helpers {
    using BytesLib for bytes;

    FeeSplittingHook public hook;

    address token1;
    address token2;
    address receiver1;
    address receiver2;
    address receiver3;
    uint256 amount1 = 1000;
    uint256 amount2 = 2000;
    uint256 nativeAmount = 1 ether;
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        // Deploy mock ERC20 tokens
        MockERC20 _mockToken1 = new MockERC20("Mock Token 1", "MTK1", 18);
        MockERC20 _mockToken2 = new MockERC20("Mock Token 2", "MTK2", 18);
        token1 = address(_mockToken1);
        token2 = address(_mockToken2);

        // Set up recipients and hook
        receiver1 = makeAddr("feeRecipient1");
        receiver2 = makeAddr("feeRecipient2");
        receiver3 = makeAddr("feeRecipient3");
        hook = new FeeSplittingHook(NATIVE_TOKEN);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.subtype(), HookSubTypes.TOKEN);
        assertEq(hook.NATIVE_TOKEN(), NATIVE_TOKEN);
    }

    function test_NameAndDescription() public view {
        assertGt(bytes(hook.name()).length, 0);
        assertGt(bytes(hook.description()).length, 0);
    }

    function test_Build_ERC20Transfers() public view {
        // Prepare test data: 2 tokens to 2 different receivers
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 4 executions: 2 for the actual transfers and 2 for the hook callbacks
        assertEq(executions.length, 4);

        // Check first token transfer goes to receiver1
        assertEq(executions[1].target, token1);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.transfer, (receiver1, amount1)));

        // Check second token transfer goes to a different receiver
        assertEq(executions[2].target, token2);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.transfer, (receiver2, amount2)));
    }

    function test_Build_NativeTokenTransfer() public view {
        // Prepare test data with native token
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE_TOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = nativeAmount;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver1;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 3 executions: 1 for the native transfer and 2 for the hook callbacks
        assertEq(executions.length, 3);
        // The actual native transfer is the second execution
        assertEq(executions[1].target, receiver1); // For native token, target should be the recipient
        assertEq(executions[1].value, nativeAmount);
        assertEq(executions[1].callData.length, 0); // No call data for native transfers
    }

    function test_Build_MixedTransfers() public view {
        // Prepare test data with mixed ERC20 and native tokens, each to a distinct receiver
        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = NATIVE_TOKEN;
        tokens[2] = token2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount1;
        amounts[1] = nativeAmount;
        amounts[2] = amount2;

        address[] memory receivers = new address[](3);
        receivers[0] = receiver1;
        receivers[1] = receiver2;
        receivers[2] = receiver3;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 5 executions: 3 for the transfers and 2 for the hook callbacks
        assertEq(executions.length, 5);

        // Check first ERC20 transfer (index 1 because of hook callback)
        assertEq(executions[1].target, token1);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.transfer, (receiver1, amount1)));

        // Check native token transfer (index 2)
        assertEq(executions[2].target, receiver2);
        assertEq(executions[2].value, nativeAmount);
        assertEq(executions[2].callData.length, 0);

        // Check second ERC20 transfer (index 3)
        assertEq(executions[3].target, token2);
        assertEq(executions[3].value, 0);
        assertEq(executions[3].callData, abi.encodeCall(IERC20.transfer, (receiver3, amount2)));
    }

    function test_Build_RevertIf_LengthMismatch_Amounts() public {
        // Prepare invalid data with mismatched amounts array length
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](1); // One less than tokens array
        amounts[0] = amount1;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test should revert with LENGTH_MISMATCH error
        vm.expectRevert(FeeSplittingHook.LENGTH_MISMATCH.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_LengthMismatch_Receivers() public {
        // Prepare invalid data with mismatched receivers array length
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        address[] memory receivers = new address[](1); // One less than tokens array
        receivers[0] = receiver1;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test should revert with LENGTH_MISMATCH error
        vm.expectRevert(FeeSplittingHook.LENGTH_MISMATCH.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ZeroReceiver() public {
        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount1;

        address[] memory receivers = new address[](1);
        receivers[0] = address(0);

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test should revert with ADDRESS_NOT_VALID error
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_MaxTransfersBoundary() public view {
        // Exactly MAX_TRANSFERS entries must succeed
        uint256 len = hook.MAX_TRANSFERS();
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(len);

        Execution[] memory executions = hook.build(address(0), address(0), _encodeData(tokens, amounts, receivers));
        assertEq(executions.length, len + 2);
    }

    function test_Build_RevertIf_TooManyTransfers() public {
        uint256 len = hook.MAX_TRANSFERS() + 1;
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(len);

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(FeeSplittingHook.TOO_MANY_TRANSFERS.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(1);
        amounts[0] = 0;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_TokenHasNoCode() public {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(1);
        tokens[0] = makeAddr("codelessToken"); // EOA — call would succeed with empty returndata

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ZeroToken() public {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(1);
        tokens[0] = address(0);

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_DataTooShort() public {
        bytes memory data = new bytes(52); // header only, no payload

        vm.expectRevert(FeeSplittingHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Inspect_RevertIf_DataTooShort() public {
        bytes memory data = new bytes(51);

        vm.expectRevert(FeeSplittingHook.INVALID_DATA_LENGTH.selector);
        hook.inspect(data);
    }

    function test_Inspect_RevertIf_LengthMismatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver1;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(FeeSplittingHook.LENGTH_MISMATCH.selector);
        hook.inspect(data);
    }

    function test_Inspect_RevertIf_TooManyTransfers() public {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) =
            _buildArrays(hook.MAX_TRANSFERS() + 1);

        bytes memory data = _encodeData(tokens, amounts, receivers);

        vm.expectRevert(FeeSplittingHook.TOO_MANY_TRANSFERS.selector);
        hook.inspect(data);
    }

    function test_PreExecute_PassthroughForwardsPrevOutput() public {
        MockHook prevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, token1);
        prevHook.setOutAmount(12_345, address(0));

        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _buildArrays(1);
        bytes memory data = _encodeData(tokens, amounts, receivers);

        // preExecute must be called by the account itself
        hook.preExecute(address(prevHook), address(this), data);

        assertEq(hook.getOutAmount(address(this)), 12_345, "PASSTHROUGH should forward prev hook outAmount");
    }

    function test_Inspector() public view {
        // Prepare test data with 2 receivers
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        bytes memory data = _encodeData(tokens, amounts, receivers);

        // Test inspect function
        bytes memory result = hook.inspect(data);

        // Verify the output contains both receiver addresses, packed (20 bytes each)
        assertEq(result.length, 40);

        address first;
        address second;
        assembly ("memory-safe") {
            first := mload(add(result, 20))
            second := mload(add(result, 40))
        }
        assertEq(first, receiver1);
        assertEq(second, receiver2);
    }

    function test_DecodeAmounts_ReturnsEmpty() public view {
        assertEq(hook.decodeAmounts("").length, 0);
    }

    function test_AmountRoles_ReturnsEmpty() public view {
        assertEq(hook.amountRoles("").length, 0);
    }

    function test_SupportsInterface() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertFalse(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
    }

    function _buildArrays(uint256 len)
        internal
        view
        returns (address[] memory tokens, uint256[] memory amounts, address[] memory receivers)
    {
        tokens = new address[](len);
        amounts = new uint256[](len);
        receivers = new address[](len);
        for (uint256 i; i < len; i++) {
            tokens[i] = token1;
            amounts[i] = 1;
            receivers[i] = receiver1;
        }
    }

    function _encodeData(
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory receivers
    )
        internal
        pure
        returns (bytes memory)
    {
        // The hook expects the data to be in the format:
        // 1. First 52 bytes: placeholder (standard strategy header)
        // 2. Remaining bytes: abi encoded (address[] tokens, uint256[] amounts, address[] receivers)
        return abi.encodePacked(bytes(new bytes(52)), abi.encode(tokens, amounts, receivers));
    }
}
