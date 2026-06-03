// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ClaimFailedTransferHook } from
    "../../../../../src/hooks/claim/stargate/ClaimFailedTransferHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";

contract ClaimFailedTransferHookTest is Helpers {
    using BytesLib for bytes;

    ClaimFailedTransferHook public hook;
    address public adapter;
    address public token;
    address public account;
    uint256 public amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        token = address(_mockToken);
        adapter = makeAddr("stargateAdapter");
        account = makeAddr("account");
        amount = 1000;

        hook = new ClaimFailedTransferHook();
    }

    // --- Constructor Tests ---

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.CLAIM);
    }

    // --- Build Tests ---

    function test_Build_ERC20() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        // 3 executions: preExecute + claimFailedTransfer + postExecute
        assertEq(executions.length, 3);

        // Middle execution targets the adapter
        assertEq(executions[1].target, adapter);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_NativeETH() public view {
        bytes memory data = _encodeData(adapter, address(0), amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, adapter);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_CallDataEncoding() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        // Verify the calldata encodes claimFailedTransfer(address,uint256)
        bytes memory expectedCalldata =
            abi.encodeWithSignature("claimFailedTransfer(address,uint256)", token, amount);
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_CallDataEncoding_NativeETH() public view {
        bytes memory data = _encodeData(adapter, address(0), amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        bytes memory expectedCalldata =
            abi.encodeWithSignature("claimFailedTransfer(address,uint256)", address(0), amount);
        assertEq(executions[1].callData, expectedCalldata);
        assertEq(executions[1].value, 0, "Value must be 0 even for native ETH claims");
    }

    function test_Build_RevertIf_AdapterZeroAddress() public {
        bytes memory data = _encodeData(address(0), token, amount);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_AmountZero() public {
        bytes memory data = _encodeData(adapter, token, 0);
        vm.expectRevert(ClaimFailedTransferHook.CLAIM_AMOUNT_ZERO.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_TokenZeroAddress_Allowed() public view {
        // token = address(0) means native ETH — this is VALID, not an error
        bytes memory data = _encodeData(adapter, address(0), amount);
        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    // --- Pre/Post Execute Tests ---

    function test_PreAndPostExecute_ERC20() public {
        _getTokens(token, account, amount);

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), amount);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), 0);
    }

    function test_PreAndPostExecute_NativeETH() public {
        vm.deal(account, amount);

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), amount);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), 0);
    }

    function test_PreAndPostExecute_ERC20_BalanceIncrease() public {
        // Start with 0 balance, simulate claim adding tokens between pre and post
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), 0, "Pre-balance should be 0");

        // Simulate the claim: tokens arrive at account
        _getTokens(token, account, 500);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), 500, "OutAmount should be the balance delta");
    }

    function test_PreAndPostExecute_NativeETH_BalanceIncrease() public {
        // Start with 0 ETH balance
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), 0, "Pre-balance should be 0");

        // Simulate the claim: ETH arrives at account
        vm.deal(account, 750);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), 750, "OutAmount should be the ETH balance delta");
    }

    // --- Inspector Tests ---

    function test_Inspector() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        // Should return adapter and token addresses only
        assertEq(BytesLib.toAddress(argsEncoded, 0), adapter);
        assertEq(BytesLib.toAddress(argsEncoded, 20), token);
    }

    function test_Inspector_NativeETH() public view {
        bytes memory data = _encodeData(adapter, address(0), amount);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(BytesLib.toAddress(argsEncoded, 0), adapter);
        assertEq(BytesLib.toAddress(argsEncoded, 20), address(0));
    }

    function test_Inspector_OutputLength() public view {
        bytes memory argsEncoded = hook.inspect(_encodeData(adapter, token, amount));
        assertEq(argsEncoded.length, 40, "Inspector output should be exactly 40 bytes (2 addresses)");
    }

    function testFuzz_Inspector(address fuzzAdapter, address fuzzToken, uint256 fuzzAmount) public view {
        bytes memory data = _encodeData(fuzzAdapter, fuzzToken, fuzzAmount);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(argsEncoded.length, 40);
        assertEq(BytesLib.toAddress(argsEncoded, 0), fuzzAdapter);
        assertEq(BytesLib.toAddress(argsEncoded, 20), fuzzToken);
    }

    // --- Calldata Decoding Tests ---

    function test_CalldataDecoding() public view {
        address testAdapter = address(0x1234567890123456789012345678901234567890);
        address testToken = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        uint256 testAmount = 12_345e18;

        bytes memory data = abi.encodePacked(testAdapter, testToken, testAmount);

        Execution[] memory executions = hook.build(address(0), account, data);

        // Check adapter is correctly used as target
        assertEq(executions[1].target, testAdapter, "Adapter address not correctly decoded");
        assertEq(data.length, 72, "Calldata length is incorrect");
    }

    // --- Fuzz Tests ---

    function testFuzz_Build(address fuzzAdapter, address fuzzToken, uint256 fuzzAmount) public view {
        vm.assume(fuzzAdapter != address(0));
        vm.assume(fuzzAmount > 0);

        bytes memory data = _encodeData(fuzzAdapter, fuzzToken, fuzzAmount);
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, fuzzAdapter);
        assertEq(executions[1].value, 0);

        // Verify calldata roundtrips correctly
        bytes memory expectedCalldata =
            abi.encodeWithSignature("claimFailedTransfer(address,uint256)", fuzzToken, fuzzAmount);
        assertEq(executions[1].callData, expectedCalldata);
    }

    function testFuzz_PreAndPostExecute_ERC20_BalanceDelta(uint256 preBalance, uint256 claimed) public {
        preBalance = bound(preBalance, 0, type(uint128).max);
        claimed = bound(claimed, 0, type(uint128).max);

        // Set initial balance
        _getTokens(token, account, preBalance);

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), preBalance);

        // Simulate claim: set balance to preBalance + claimed
        _getTokens(token, account, preBalance + claimed);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), claimed);
    }

    // --- decodeAmount / replaceCalldataAmount Tests ---

    function test_DecodeAmount() public view {
        bytes memory data = _encodeData(adapter, token, 42_000e18);
        uint256 decoded = hook.decodeAmount(data);
        assertEq(decoded, 42_000e18, "decodeAmount should extract amount at offset 40");
    }

    function test_DecodeAmount_Zero() public view {
        bytes memory data = _encodeData(adapter, token, 0);
        uint256 decoded = hook.decodeAmount(data);
        assertEq(decoded, 0, "decodeAmount should return 0 for zero amount");
    }

    function testFuzz_DecodeAmount(address fuzzAdapter, address fuzzToken, uint256 fuzzAmount) public view {
        bytes memory data = _encodeData(fuzzAdapter, fuzzToken, fuzzAmount);
        assertEq(hook.decodeAmount(data), fuzzAmount);
    }

    function test_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeData(adapter, token, 1000);
        bytes memory replaced = hook.replaceCalldataAmount(data, 5000);

        // Verify amount was replaced
        assertEq(hook.decodeAmount(replaced), 5000, "Amount should be replaced");

        // Verify adapter and token are unchanged
        assertEq(BytesLib.toAddress(replaced, 0), adapter, "Adapter should be unchanged");
        assertEq(BytesLib.toAddress(replaced, 20), token, "Token should be unchanged");
    }

    function testFuzz_ReplaceCalldataAmount(
        address fuzzAdapter,
        address fuzzToken,
        uint256 originalAmount,
        uint256 newAmount
    )
        public
        view
    {
        bytes memory data = _encodeData(fuzzAdapter, fuzzToken, originalAmount);
        bytes memory replaced = hook.replaceCalldataAmount(data, newAmount);

        assertEq(hook.decodeAmount(replaced), newAmount, "Amount should be replaced");
        assertEq(BytesLib.toAddress(replaced, 0), fuzzAdapter, "Adapter unchanged");
        assertEq(BytesLib.toAddress(replaced, 20), fuzzToken, "Token unchanged");
    }

    // --- Data Validation Tests ---

    function test_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(adapter, token); // 40 bytes, missing amount
        vm.expectRevert(ClaimFailedTransferHook.DATA_NOT_VALID.selector);
        hook.build(address(0), account, shortData);
    }

    function test_Build_RevertIf_EmptyData() public {
        vm.expectRevert(ClaimFailedTransferHook.DATA_NOT_VALID.selector);
        hook.build(address(0), account, "");
    }

    // --- Helper Functions ---

    function _encodeData(
        address _adapter,
        address _token,
        uint256 _amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_adapter, _token, _amount);
    }
}
