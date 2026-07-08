// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SwapOdosV2Hook } from "../../../../../src/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { ApproveAndSwapOdosV2Hook } from "../../../../../src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { IOdosRouterV2 } from "../../../../../src/vendor/odos/IOdosRouterV2.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract MockOdosRouter is IOdosRouterV2 {
    function swap(
        swapTokenInfo calldata,
        bytes calldata,
        address,
        uint32
    )
        external
        payable
        override
        returns (uint256 outputAmount)
    {
        return 0;
    }

    function swapPermit2(
        permit2Info memory,
        swapTokenInfo memory,
        bytes calldata,
        address,
        uint32
    )
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return 0;
    }

    function swapCompact() external payable override returns (uint256) {
        return 0;
    }
}

contract ApproveAndSwapOdosHookTest is Helpers {
    ApproveAndSwapOdosV2Hook public approveAndSwapOdosHook;
    SwapOdosV2Hook public swapOdosHook;
    MockOdosRouter public odosRouter;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address inputReceiver;
    address account;

    uint256 inputAmount = 1000;
    uint256 outputQuote = 900;
    uint256 outputMin = 850;
    bytes pathDefinition;
    address executor;
    uint32 referralCode = 123;
    bool usePrevHookAmount;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        executor = makeAddr("executor");
        inputReceiver = makeAddr("inputReceiver");

        odosRouter = new MockOdosRouter();

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        pathDefinition = abi.encode("mock_path_definition");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        approveAndSwapOdosHook = new ApproveAndSwapOdosV2Hook(address(odosRouter));
        swapOdosHook = new SwapOdosV2Hook(address(odosRouter));
    }

    // ------------ ApproveAndSwapOdosV2Hook --------------
    function test_Constructor() public view {
        assertEq(uint256(approveAndSwapOdosHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapOdosHook.ODOS_ROUTER_V2()), address(odosRouter));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapOdosV2Hook(address(0));
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        assertFalse(approveAndSwapOdosHook.decodeUsePrevHookAmount(data));

        data = _buildApproveAndSwapOdosData(true);
        assertTrue(approveAndSwapOdosHook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookSwapHook() public view {
        bytes memory data = _buildSwapOdosData(false);
        assertFalse(swapOdosHook.decodeUsePrevHookAmount(data));

        data = _buildSwapOdosData(true);
        assertTrue(swapOdosHook.decodeUsePrevHookAmount(data));
    }

    function test_Build() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(inputToken));
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(odosRouter));
        assertEq(executions[3].value, 0);
        assertEq(executions[4].target, address(inputToken));
        assertEq(executions[4].value, 0);
    }

    function test_Build_With_ApproveSpender_OdosRouter() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(odosRouter));
    }

    function test_Build_WithPrevHookAmount() public {
        bytes memory data = _buildApproveAndSwapOdosData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, address(this));

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(inputToken));
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(odosRouter));
        assertEq(executions[3].value, 0);
        assertEq(executions[4].target, address(inputToken));
        assertEq(executions[4].value, 0);
    }

    function test_PreExecute() public {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.getOutAmount(address(this)), 500);
    }

    function test_PostExecute() public {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        approveAndSwapOdosHook.postExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.getOutAmount(address(this)), 300);
    }

    function test_BytesLengthDecoding() public view {
        bytes memory testPathDefinition = abi.encode("test_path_longer_than_before");

        bytes memory payload = abi.encode(inputReceiver, testPathDefinition, executor, referralCode);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    function test_BooleanDecoding_True() public {
        bytes memory data = _buildApproveAndSwapOdosData(true);

        prevHook.setOutAmount(2000, address(this));

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    function test_BooleanDecoding_False() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    function test_ZeroValue() public view {
        bytes memory payload = abi.encode(inputReceiver, pathDefinition, executor, referralCode);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(uint256(0)), // Zero input amount
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    function test_ApproveAndSwapOdosHook_inspect() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        bytes memory argsEncoded = approveAndSwapOdosHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_SwapOdos_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildSwapOdosData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapOdosHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapOdosHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapOdos_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapOdosHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapOdosHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapOdos_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildSwapOdosData(false);
        bytes memory replaced = swapOdosHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte placeholder + inputToken(20) + outputToken(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function _buildApproveAndSwapOdosData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = abi.encode(inputReceiver, pathDefinition, executor, referralCode);
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    // ------------ SwapOdosV2Hook --------------
    function test_SwapOdosHook_Constructor() public view {
        assertEq(uint256(swapOdosHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapOdosHook.ODOS_ROUTER_V2()), address(odosRouter));
    }

    function test_SwapOdosHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapOdosV2Hook(address(0));
    }

    function test_SwapOdosHook_decodeUsePrevHookAmount() public view {
        bytes memory data = _buildSwapOdosData(false);
        assertEq(swapOdosHook.decodeUsePrevHookAmount(data), false);

        data = _buildSwapOdosData(true);
        assertEq(swapOdosHook.decodeUsePrevHookAmount(data), true);
    }

    function test_SwapOdosHook_Build() public view {
        bytes memory data = _buildSwapOdosData(false);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(odosRouter));
        assertEq(executions[1].value, 0);
    }

    function test_SwapOdosHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildSwapOdosData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, address(this));

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(odosRouter));
        assertEq(executions[1].value, 0);
    }

    function test_SwapOdosHook_PreExecute() public {
        bytes memory data = _buildSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.getOutAmount(address(this)), 500);
    }

    function test_SwapOdosHook_PostExecute() public {
        bytes memory data = _buildSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapOdosHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        swapOdosHook.postExecute(address(0), account, data);

        assertEq(swapOdosHook.getOutAmount(address(this)), 300);
    }

    function test_SwapOdosHook_BytesLengthDecoding() public view {
        bytes memory testPathDefinition = abi.encode("test_path_longer_than_before");

        bytes memory payload = abi.encode(inputReceiver, testPathDefinition, executor, referralCode);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_SwapOdosHook_BooleanDecoding_True() public {
        bytes memory data = _buildSwapOdosData(true);

        prevHook.setOutAmount(2000, address(this));

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_SwapOdosHook_booleanDecoding_False() public view {
        bytes memory data = _buildSwapOdosData(false);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_SwapOdosHook_ZeroValue() public view {
        bytes memory payload = abi.encode(inputReceiver, pathDefinition, executor, referralCode);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(0), // Zero input amount
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_SwapOdosHook_inspect() public view {
        bytes memory data = _buildSwapOdosData(false);
        bytes memory argsEncoded = swapOdosHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_NativeSwapOdosHook() public view {
        bytes memory data = _buildNativeSwapOdosData(false);
        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_PreExecuteNativeSwapOdosHook() public {
        bytes memory data = _buildNativeSwapOdosData(false);
        vm.deal(account, inputAmount);
        swapOdosHook.preExecute(address(prevHook), account, data);
        assertEq(swapOdosHook.getOutAmount(account), inputAmount);
    }

    function test_PreExecuteNativeApproveAndSwapOdosHook() public {
        bytes memory data = _buildNativeSwapOdosData(false);
        vm.deal(account, inputAmount);
        approveAndSwapOdosHook.preExecute(address(prevHook), account, data);
        assertEq(approveAndSwapOdosHook.getOutAmount(account), inputAmount);
    }

    function test_ApproveAndSwapOdos_DecodeAmounts() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        assertEq(approveAndSwapOdosHook.decodeAmounts(data)[0], inputAmount);
    }

    function test_ApproveAndSwapOdos_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapOdosHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapOdosHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapOdos_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildApproveAndSwapOdosData(false);
        bytes memory result = approveAndSwapOdosHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapOdosHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapOdos_DecodeAmounts() public view {
        bytes memory data = _buildSwapOdosData(false);
        assertEq(swapOdosHook.decodeAmounts(data)[0], inputAmount);
    }

    function test_SwapOdos_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildSwapOdosData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapOdosHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapOdosHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapOdos_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildSwapOdosData(false);
        bytes memory result = swapOdosHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapOdosHook.decodeAmounts(result)[0], fuzzAmount);
    }

    // ========================== Payload Decode Round-Trip Tests ==========================

    function test_SwapOdosV2Hook_PayloadDecodeRoundTrip() public view {
        bytes memory data = _buildSwapOdosData(false);
        bytes memory payload = swapOdosHook.decodePayload(data);
        (address decodedInputReceiver, bytes memory decodedPath, address decodedExecutor, uint32 decodedReferralCode) =
            abi.decode(payload, (address, bytes, address, uint32));

        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(keccak256(decodedPath), keccak256(pathDefinition));
        assertEq(decodedExecutor, executor);
        assertEq(decodedReferralCode, referralCode);
    }

    function test_ApproveAndSwapOdosV2Hook_PayloadDecodeRoundTrip() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        bytes memory payload = approveAndSwapOdosHook.decodePayload(data);
        (address decodedInputReceiver, bytes memory decodedPath, address decodedExecutor, uint32 decodedReferralCode) =
            abi.decode(payload, (address, bytes, address, uint32));

        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(keccak256(decodedPath), keccak256(pathDefinition));
        assertEq(decodedExecutor, executor);
        assertEq(decodedReferralCode, referralCode);
    }

    function testFuzz_SwapOdosV2Hook_PayloadDecodeRoundTrip(
        address fuzzInputReceiver,
        bytes memory fuzzPath,
        address fuzzExecutor,
        uint32 fuzzReferralCode
    )
        public
        view
    {
        vm.assume(fuzzPath.length < 10_000);
        bytes memory payload = abi.encode(fuzzInputReceiver, fuzzPath, fuzzExecutor, fuzzReferralCode);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        bytes memory decodedPayload = swapOdosHook.decodePayload(data);
        (address decInputReceiver, bytes memory decPath, address decExecutor, uint32 decReferralCode) =
            abi.decode(decodedPayload, (address, bytes, address, uint32));

        assertEq(decInputReceiver, fuzzInputReceiver);
        assertEq(keccak256(decPath), keccak256(fuzzPath));
        assertEq(decExecutor, fuzzExecutor);
        assertEq(decReferralCode, fuzzReferralCode);
    }

    function test_SwapOdosV2Hook_Build_ExecutionTargetsRouter() public view {
        bytes memory data = _buildSwapOdosData(false);
        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions[1].target, address(odosRouter));
    }

    function test_ApproveAndSwapOdosV2Hook_Build_ExecutionTargetsRouter() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions[3].target, address(odosRouter));
    }

    // ========================== Data Builders ==========================

    function _buildSwapOdosData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = abi.encode(inputReceiver, pathDefinition, executor, referralCode);
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildNativeSwapOdosData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = abi.encode(inputReceiver, pathDefinition, executor, referralCode);
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(address(0)),  // native ETH output
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }
}
