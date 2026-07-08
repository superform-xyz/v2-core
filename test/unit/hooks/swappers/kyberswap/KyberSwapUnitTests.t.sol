// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SwapKyberSwapHook } from "../../../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import {
    ApproveAndSwapKyberSwapHook
} from "../../../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { IMetaAggregationRouterV2 } from "../../../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { KyberSwapScaler } from "../../../../../src/libraries/KyberSwapScaler.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract KyberSwapUnitTests is Helpers {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address account;
    address kyberRouter;
    address callTarget;
    address approveTarget;

    uint256 inputAmount = 1000;
    uint256 outputMin = 850;
    uint256 swapValue = 0;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        callTarget = makeAddr("callTarget");
        approveTarget = makeAddr("approveTarget");

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        // Deploy a mock router (just need an address for constructor)
        kyberRouter = address(new MockKyberRouter());

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        swapHook = new SwapKyberSwapHook(kyberRouter, address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        approveAndSwapHook =
            new ApproveAndSwapKyberSwapHook(kyberRouter, address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }

    /*//////////////////////////////////////////////////////////////
                         CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Constructor() public view {
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapHook.KYBER_ROUTER()), kyberRouter);
    }

    function test_ApproveAndSwapHook_Constructor() public view {
        assertEq(uint256(approveAndSwapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapHook.KYBER_ROUTER()), kyberRouter);
    }

    function test_SwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapKyberSwapHook(address(0), address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }

    function test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapKyberSwapHook(address(0), address(0), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }

    /*//////////////////////////////////////////////////////////////
                     DECODE USE PREV HOOK AMOUNT
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildSwapData(false);
        assertFalse(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_SwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildSwapData(true);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildApproveAndSwapData(true);
        assertTrue(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                         BUILD TESTS - SWAP HOOK
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Build() public view {
        bytes memory data = _buildSwapData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // 1 hook execution + preExecute + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, kyberRouter);
        assertEq(executions[1].value, 0);
    }

    function test_SwapHook_Build_DerivesZeroValueForErc20Input() public view {
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, kyberRouter);
        assertEq(executions[1].value, 0);
    }

    function test_SwapHook_Build_DerivesNativeValueFromInputAmount() public view {
        address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        bytes memory txData_ = _buildKyberTxDataWithTokens(native, outputToken, 1 ether, outputMin, approveTarget);
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(native),      // inputToken = native
            bytes20(outputToken),
            bytes32(uint256(1 ether)), // inputAmount
            bytes32(uint256(0)),       // outputQuote
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, kyberRouter);
        assertEq(executions[1].value, 1 ether);
    }

    function test_SwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildSwapData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, kyberRouter);
    }

    function test_SwapHook_Build_WithPrevHookAmount_NativeValue() public {
        address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        bytes memory txData_ = _buildKyberTxDataWithTokens(native, outputToken, 1 ether, outputMin, approveTarget);
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(native),      // inputToken = native
            bytes20(outputToken),
            bytes32(uint256(1 ether)), // inputAmount
            bytes32(uint256(0)),       // outputQuote
            bytes32(outputMin),
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes32(payload.length),
            payload
        );

        uint256 prevHookAmount = 2 ether;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, prevHookAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD TESTS - APPROVE AND SWAP HOOK
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_Build() public view {
        bytes memory data = _buildApproveAndSwapData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // 4 hook executions + preExecute + postExecute = 6
        assertEq(executions.length, 6);
        // executions[0] = preExecute
        assertEq(executions[1].target, inputToken); // approve(0)
        assertEq(executions[2].target, inputToken); // approve(amount)
        assertEq(executions[3].target, kyberRouter); // swap
        assertEq(executions[4].target, inputToken); // approve(0)
        // executions[5] = postExecute
    }

    function test_ApproveAndSwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildApproveAndSwapData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].target, kyberRouter);
    }

    function test_ApproveAndSwapHook_Build_ApproveTarget() public view {
        bytes memory data = _buildApproveAndSwapData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approvals go to approveTarget (decoded from txData)
        bytes memory approveCallData0 = executions[1].callData;
        (address spender0,) = abi.decode(_sliceBytes(approveCallData0, 4), (address, uint256));
        assertEq(spender0, approveTarget);
    }

    function test_ApproveAndSwapHook_Build_ApproveTarget_FallbackToRouter() public view {
        // Build txData with approveTarget = address(0), should fallback to KYBER_ROUTER
        bytes memory txData_ = _buildKyberTxDataWithApproveTarget(address(0));
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approvals go to KYBER_ROUTER when approveTarget == address(0)
        bytes memory approveCallData0 = executions[1].callData;
        (address spender0,) = abi.decode(_sliceBytes(approveCallData0, 4), (address, uint256));
        assertEq(spender0, kyberRouter);
    }

    /*//////////////////////////////////////////////////////////////
                         PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_PreExecute() public {
        bytes memory data = _buildSwapData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapHook.preExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 500);
    }

    function test_SwapHook_PostExecute() public {
        bytes memory data = _buildSwapData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        swapHook.postExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 300);
    }

    function test_ApproveAndSwapHook_PreExecute() public {
        bytes memory data = _buildApproveAndSwapData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 500);
    }

    function test_ApproveAndSwapHook_PostExecute() public {
        bytes memory data = _buildApproveAndSwapData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        approveAndSwapHook.postExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 300);
    }

    function test_SwapHook_PreExecute_NativeOutput() public {
        // Build data with outputToken = NATIVE for native ETH output
        address NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),  // inputToken
            bytes20(NATIVE),      // outputToken = native ETH
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        vm.deal(account, 1 ether);

        swapHook.preExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 1 ether);
    }

    function test_ApproveAndSwapHook_PreExecute_NativeOutput() public {
        address NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(NATIVE),      // outputToken = native ETH
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        vm.deal(account, 1 ether);

        approveAndSwapHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    ZERO AMOUNT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Build_RevertIf_PrevHookAmountZero() public {
        bytes memory data = _buildSwapData(true);

        // prevHook returns 0
        prevHook.setOutAmount(0, account);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_Build_RevertIf_PrevHookAmountZero() public {
        bytes memory data = _buildApproveAndSwapData(true);

        // prevHook returns 0
        prevHook.setOutAmount(0, account);

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_Build_RevertIf_OriginalAmountZero() public {
        // Build data with inputAmount=0 and usePrevHookAmount=true
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(uint256(0)), // inputAmount = 0 (originalAmount)
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin),
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes32(payload.length),
            payload
        );

        // prevHook returns non-zero, but originalAmount=0 causes div-by-zero in proportional fallback
        prevHook.setOutAmount(500, account);

        vm.expectRevert(); // Reverts in proportionalScale (ZERO_AMOUNT or Math.mulDiv panic)
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Inspect() public view {
        bytes memory data = _buildSwapData(false);
        bytes memory result = swapHook.inspect(data);

        // Should return 1 packed address: dstToken
        assertEq(result.length, 20); // 1 * 20 bytes
    }

    function test_ApproveAndSwapHook_Inspect() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        bytes memory result = approveAndSwapHook.inspect(data);

        // Should return 1 packed address: dstToken
        assertEq(result.length, 20); // 1 * 20 bytes
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildKyberTxData() internal view returns (bytes memory) {
        return _buildKyberTxDataWithApproveTarget(approveTarget);
    }

    function _buildKyberTxDataWithApproveTarget(address _approveTarget) internal view returns (bytes memory) {
        return _buildKyberTxDataWithTokens(inputToken, outputToken, inputAmount, outputMin, _approveTarget);
    }

    function _buildKyberTxDataWithTokens(
        address _inputToken,
        address _outputToken,
        uint256 _inputAmount,
        uint256 _outputMin,
        address _approveTarget
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget;

        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = _inputAmount;

        address[] memory feeReceivers = new address[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(_inputToken),
            dstToken: IERC20(_outputToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: _inputAmount,
            minReturnAmount: _outputMin,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget, approveTarget: _approveTarget, clientData: "", desc: desc, targetData: ""
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    function test_SwapKyberSwap_DecodeAmounts() public view {
        bytes memory data = _buildSwapData(false);
        assertEq(swapHook.decodeAmounts(data)[0], inputAmount);
    }

    function test_SwapKyberSwap_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildSwapData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapKyberSwap_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildSwapData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapKyberSwap_DecodeAmounts() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], inputAmount);
    }

    function test_ApproveAndSwapKyberSwap_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapKyberSwap_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildApproveAndSwapData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapKyberSwap_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildSwapData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapKyberSwap_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapKyberSwap_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildApproveAndSwapData(false);
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(999));
        // Verify bytes before AMOUNT_POSITION (92) are unchanged (52-byte placeholder + inputToken(20) + outputToken(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        // Verify bytes after AMOUNT_POSITION + 32 (124) are unchanged
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function test_SwapKyberSwap_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildSwapData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        // SwapKyberSwapHook layout: placeholder(52) + inputToken(20) + outputToken(20) + inputAmount(32) + ...
        // Verify bytes before AMOUNT_POSITION (92) are unchanged
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        // Verify bytes after AMOUNT_POSITION + 32 (124) are unchanged
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /// @dev Build SwapKyberSwapHook data layout (new standard):
    ///      inputToken(20) + outputToken(20) + inputAmount(32) + outputQuote(32) + outputMin(32) +
    ///      usePrevHookAmount(1) + payloadLength(32) + payload = abi.encode(txData_)
    function _buildSwapData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);

        return bytes.concat(
            bytes(new bytes(52)), // Layer 0: 52-byte placeholder
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote (unused by KyberSwap hook)
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    /// @dev Build ApproveAndSwapKyberSwapHook data layout (new standard):
    ///      inputToken(20) + outputToken(20) + inputAmount(32) + outputQuote(32) + outputMin(32) +
    ///      usePrevHookAmount(1) + payloadLength(32) + payload = abi.encode(txData_)
    function _buildApproveAndSwapData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory txData_ = _buildKyberTxData();
        bytes memory payload = abi.encode(txData_);

        return bytes.concat(
            bytes(new bytes(52)), // Layer 0: 52-byte placeholder
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(uint256(0)), // outputQuote (unused by KyberSwap hook)
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    function _sliceBytes(bytes memory data, uint256 start) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - start);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                     PAYLOAD DECODE ROUND-TRIP TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify decodePayload returns abi.encoded bytes that unwrap to original txData
    function test_SwapHook_PayloadDecodeRoundTrip() public view {
        bytes memory data = _buildSwapData(false);

        bytes memory decodedPayload = swapHook.decodePayload(data);
        (bytes memory decodedTxData) = abi.decode(decodedPayload, (bytes));

        // Verify the decoded txData matches what we built
        bytes memory expectedTxData = _buildKyberTxData();
        assertEq(decodedTxData.length, expectedTxData.length, "txData length mismatch");
        assertEq(keccak256(decodedTxData), keccak256(expectedTxData), "txData content mismatch");
    }

    /// @notice Verify ApproveAndSwap decodePayload round-trip
    function test_ApproveAndSwapHook_PayloadDecodeRoundTrip() public view {
        bytes memory data = _buildApproveAndSwapData(false);

        bytes memory decodedPayload = approveAndSwapHook.decodePayload(data);
        (bytes memory decodedTxData) = abi.decode(decodedPayload, (bytes));

        bytes memory expectedTxData = _buildKyberTxData();
        assertEq(keccak256(decodedTxData), keccak256(expectedTxData), "txData content mismatch");
    }

    /// @notice Verify that the txData in build's Execution matches the original router calldata
    function test_SwapHook_Build_ExecutionContainsCorrectTxData() public view {
        bytes memory data = _buildSwapData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // The swap execution calldata should match what _buildKyberTxData produced
        bytes memory swapCalldata = executions[1].callData;
        assertGt(swapCalldata.length, 4, "swap calldata too short");

        // Decode the swap params from the execution
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceBytes(swapCalldata, 4), (IMetaAggregationRouterV2.SwapExecutionParams));

        // Verify key fields are correct
        assertEq(address(decoded.desc.srcToken), inputToken, "srcToken mismatch");
        assertEq(address(decoded.desc.dstToken), outputToken, "dstToken mismatch");
        assertEq(decoded.desc.amount, inputAmount, "amount mismatch");
    }

    /// @notice Verify ApproveAndSwap build's Execution contains correct txData
    function test_ApproveAndSwapHook_Build_ExecutionContainsCorrectTxData() public view {
        bytes memory data = _buildApproveAndSwapData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // swap is at index 3 for approve-and-swap
        bytes memory swapCalldata = executions[3].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(_sliceBytes(swapCalldata, 4), (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(address(decoded.desc.srcToken), inputToken, "srcToken mismatch");
        assertEq(address(decoded.desc.dstToken), outputToken, "dstToken mismatch");
        assertEq(decoded.desc.amount, inputAmount, "amount mismatch");
    }

    /// @notice Fuzz: arbitrary txData survives abi.encode → payload → abi.decode round-trip
    function testFuzz_PayloadDecodeRoundTrip(bytes calldata fuzzTxData) public view {
        vm.assume(fuzzTxData.length > 0);

        bytes memory payload = abi.encode(fuzzTxData);
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(uint256(0)),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        bytes memory decodedPayload = swapHook.decodePayload(data);
        (bytes memory decodedTxData) = abi.decode(decodedPayload, (bytes));

        assertEq(keccak256(decodedTxData), keccak256(fuzzTxData), "txData content mismatch");
    }
}

/// @dev Minimal mock that just implements the interface
contract MockKyberRouter is IMetaAggregationRouterV2 {
    function swap(SwapExecutionParams calldata) external payable override returns (uint256, uint256) {
        return (0, 0);
    }
}
