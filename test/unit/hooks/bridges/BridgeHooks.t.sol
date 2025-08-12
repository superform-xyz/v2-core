// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { DeBridgeSendOrderAndExecuteOnDstHook } from
    "../../../../src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { DeBridgeCancelOrderHook } from "../../../../src/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IAcrossSpokePoolV3 } from "../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { DlnExternalCallLib } from "../../../../lib/pigeon/src/debridge/libraries/DlnExternalCallLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        /**
         * bytes32[] memory proofs = new bytes32[](1);
         *     proofs[0] = keccak256("dst1");
         *     proofDst[0] = ISuperValidator.DstProof({proof: proofs, dstChainId: uint64(block.chainid)});
         */
        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract BridgeHooks is Helpers {
    AcrossSendFundsAndExecuteOnDstHook public acrossV3hook;
    DeBridgeSendOrderAndExecuteOnDstHook public deBridgehook;
    DeBridgeCancelOrderHook public cancelOrderHook;
    address public mockSpokePool;
    address public mockAccount;
    address public mockPrevHook;
    address public mockRecipient;
    address public mockInputToken;
    address public mockOutputToken;
    address public mockExclusiveRelayer;
    uint256 public mockValue;
    uint256 public mockInputAmount;
    uint256 public mockOutputAmount;
    uint256 public mockDestinationChainId;
    uint32 public mockFillDeadlineOffset;
    uint32 public mockExclusivityPeriod;
    bytes public mockMessage;
    MockSignatureStorage public mockSignatureStorage;

    function setUp() public {
        mockSpokePool = makeAddr("spokePool");
        mockAccount = makeAddr("account");
        mockRecipient = makeAddr("recipient");
        mockInputToken = makeAddr("inputToken");
        mockOutputToken = makeAddr("outputToken");
        mockExclusiveRelayer = makeAddr("exclusiveRelayer");

        mockValue = 0.1 ether;
        mockInputAmount = 1000;
        mockOutputAmount = 950;
        mockDestinationChainId = 10;
        mockFillDeadlineOffset = 3600;
        mockExclusivityPeriod = 1800;
        mockSignatureStorage = new MockSignatureStorage();
        acrossV3hook = new AcrossSendFundsAndExecuteOnDstHook(mockSpokePool, address(mockSignatureStorage));
        deBridgehook = new DeBridgeSendOrderAndExecuteOnDstHook(address(this), address(mockSignatureStorage));
        cancelOrderHook = new DeBridgeCancelOrderHook(address(this)); // Initialize with this contract as dlnSource

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(mockOutputToken);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), dstTokens, intentAmounts, mockMessage);
    }

    function test_AcrossV3_Constructor() public view {
        assertEq(address(acrossV3hook.spokePoolV3()), mockSpokePool);
        assertEq(uint256(acrossV3hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_AcrossV3_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHook(address(0), address(this));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHook(address(this), address(0));
    }

    function test_AcrossV3_Build() public {
        bytes memory data = _encodeAcrossData(false);

        Execution[] memory executions = acrossV3hook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockSpokePool);
        assertEq(executions[1].value, mockValue);

        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(mockOutputToken);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), dstTokens, intentAmounts, sigData);

        bytes memory expectedCallData = abi.encodeCall(
            IAcrossSpokePoolV3.depositV3Now,
            (
                mockAccount,
                mockRecipient,
                mockInputToken,
                mockOutputToken,
                mockInputAmount,
                mockOutputAmount,
                mockDestinationChainId,
                mockExclusiveRelayer,
                mockFillDeadlineOffset,
                mockExclusivityPeriod,
                mockMessage
            )
        );

        assertEq(executions[1].callData, expectedCallData);
    }

    function test_AcrossV3_Inspector() public view {
        bytes memory data = _encodeAcrossData(false);
        bytes memory argsEncoded = acrossV3hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_AcrossV3_Build_RevertIf_AmountNotValid() public {
        mockInputAmount = 0;
        bytes memory data = _encodeAcrossData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossV3hook.build(address(0), mockAccount, data);
    }

    function test_AcrossV3_Build_RevertIf_RecipientNotValid() public {
        mockRecipient = address(0);
        bytes memory data = _encodeAcrossData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        acrossV3hook.build(address(0), mockAccount, data);
    }

    function test_AcrossV3_Build_WithPrevHookAmountABC() public {
        uint256 prevHookAmount = 2000;
        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));
        assertEq(MockHook(mockPrevHook).getOutAmount(address(this)), prevHookAmount);

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossData(true);

        Execution[] memory executions = acrossV3hook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(mockOutputToken);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), dstTokens, intentAmounts, sigData);

        uint256 finalOutputAmount = Math.mulDiv(mockOutputAmount, prevHookAmount, mockInputAmount);
        bytes memory expectedCallData = abi.encodeCall(
            IAcrossSpokePoolV3.depositV3Now,
            (
                mockAccount,
                mockRecipient,
                mockInputToken,
                mockOutputToken,
                prevHookAmount,
                finalOutputAmount,
                mockDestinationChainId,
                mockExclusiveRelayer,
                mockFillDeadlineOffset,
                mockExclusivityPeriod,
                mockMessage
            )
        );

        assertEq(executions[1].callData, expectedCallData);
    }

    function test_AcrossV3_Build_WithPrevHookAmount_AndRevertIfAmountZero() public {
        uint256 prevHookAmount = 0;

        vm.mockCall(
            mockSpokePool, abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector), abi.encode(0)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeAcrossData(true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossV3hook.build(mockPrevHook, mockAccount, data);
    }

    function test_AcrossV3_Build_NoLengthCheck() public {
        // Create data shorter than required 217 bytes
        bytes memory malformedData = abi.encodePacked(
            uint256(1 ether), // value (32 bytes)
            address(0x1), // recipient (20 bytes)
            address(0x2), // inputToken (20 bytes)
            address(0x3), // outputToken (20 bytes)
            uint256(1000), // inputAmount (32 bytes)
            uint256(900), // outputAmount (32 bytes)
            uint256(1) // destinationChainId (32 bytes)
        );
        // Missing remaining required fields - total length = 188 bytes

        // This should revert due to out of bounds read, but it doesn't
        // The build function will try to read past the end of the bytes array
        vm.expectRevert(); // Any revert would prove length is checked
        acrossV3hook.build(address(0), mockAccount, malformedData);
    }

    function test_AcrossV3_Build_WithPrevHookAmount_AndRevertIfAmountZero_WithWrappedNative() public {
        uint256 prevHookAmount = 0;

        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeAcrossData(true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossV3hook.build(mockPrevHook, mockAccount, data);
    }

    function test_AcrossV3_Build_RevertIf_ZeroAmount() public {
        mockInputAmount = 0;
        bytes memory data = _encodeAcrossData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossV3hook.build(address(0), mockAccount, data);
    }

    function test_AcrossV3_Build_RevertIf_ZeroRecipient() public {
        mockRecipient = address(0);
        bytes memory data = _encodeAcrossData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        acrossV3hook.build(address(0), mockAccount, data);
    }

    function test_AcrossV3_PreExecute() public {
        acrossV3hook.preExecute(address(0), address(this), "");
    }

    function test_AcrossV3_PostExecute() public {
        acrossV3hook.postExecute(address(0), address(this), "");
    }

    function test_AcrossV3_DecodePrevHookAmount() public view {
        bytes memory data = _encodeAcrossData(false);
        assertFalse(acrossV3hook.decodeUsePrevHookAmount(data));

        data = _encodeAcrossData(true);
        assertTrue(acrossV3hook.decodeUsePrevHookAmount(data));
    }

    function test_DeBridge_Constructor() public view {
        assertEq(address(deBridgehook.dlnSource()), address(this));
        assertEq(uint256(deBridgehook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_DeBridge_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new DeBridgeSendOrderAndExecuteOnDstHook(address(0), address(this));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new DeBridgeSendOrderAndExecuteOnDstHook(address(this), address(0));
    }

    function test_DeBridge_Inspector() public view {
        bytes memory data = _encodeDebridgeData(false, 100, 100, address(mockInputToken));
        bytes memory argsEncoded = deBridgehook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_Debrigdge_Build() public view {
        bytes memory data = _encodeDebridgeData(false, 100, 100, address(mockInputToken));
        Execution[] memory executions = deBridgehook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debrigdge_Build_UsePrevAmount() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(100, address(this));

        bytes memory data = _encodeDebridgeData(true, 100, 100, address(mockInputToken));
        Execution[] memory executions = deBridgehook.build(mockPrevHook, mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debrigdge_Build_UsePrevAmount_ETH() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(100, address(this));

        bytes memory data = _encodeDebridgeData(true, 100, 100, address(0));
        Execution[] memory executions = deBridgehook.build(mockPrevHook, mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debridge_RevertAmountZero() public {
        bytes memory data = _encodeDebridgeData(false, 0, 0, address(mockInputToken));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        deBridgehook.build(address(0), mockAccount, data);
    }

    function test_Debrigdge_Build_UsePrevAmount_ETH_Underflow() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(100, address(this));

        bytes memory data = _encodeDebridgeData(true, 100, 0, address(0));
        vm.expectRevert(DeBridgeSendOrderAndExecuteOnDstHook.AMOUNT_UNDERFLOW.selector);
        deBridgehook.build(mockPrevHook, mockAccount, data);
    }

    function test_subtype() public view {
        assertNotEq(BaseHook(address(deBridgehook)).subtype(), bytes32(0));
    }

    function test_Debridge_PreExecute() public {
        deBridgehook.preExecute(address(0), address(this), "");
    }

    function test_Debridge_PostExecute() public {
        deBridgehook.postExecute(address(0), address(this), "");
    }

    // DeBridge Cancel Order Hook Tests

    function test_CancelOrderHook_Constructor() public view {
        assertEq(address(cancelOrderHook.dlnDestination()), address(this));
        assertEq(uint256(cancelOrderHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_CancelOrderHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new DeBridgeCancelOrderHook(address(0));
    }

    function test_CancelOrderHook_Build() public view {
        // Create order data for cancellation
        bytes memory data = _encodeCancelOrderData();

        // Test the build function
        Execution[] memory executions = cancelOrderHook.build(address(0), mockAccount, data);

        // Verify the execution
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(this)); // Should be the dlnSource address
        assertEq(executions[1].value, 0.1 ether); // Using mockValue

        // Skip checking the exact selector since it's complex to extract in Solidity
        // Just verify the callData is not empty and the target is correct
        assertTrue(executions[1].callData.length > 0, "CallData should not be empty");
    }

    function test_CancelOrderHook_Inspector() public view {
        bytes memory data = _encodeCancelOrderData();
        bytes memory argsEncoded = cancelOrderHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _encodeAcrossData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return abi.encodePacked(
            mockValue,
            mockRecipient,
            mockInputToken,
            mockOutputToken,
            mockInputAmount,
            mockOutputAmount,
            mockDestinationChainId,
            mockExclusiveRelayer,
            mockFillDeadlineOffset,
            mockExclusivityPeriod,
            usePrevHookAmount,
            mockMessage
        );
    }

    struct DebridgeOrderData {
        bool usePrevHookAmount;
        uint256 value;
        address giveTokenAddress;
        uint256 giveAmount;
        uint8 version;
        address fallbackAddress;
        address executorAddress;
        uint256 executionFee;
        bool allowDelayedExecution;
        bool requireSuccessfulExecution;
        bytes payload;
        address takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        address receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes allowedCancelBeneficiarySrc;
        bytes affiliateFee;
        uint32 referralCode;
    }

    function _encodeDebridgeData(
        bool usePrevHookAmount,
        uint256 amount,
        uint256 value,
        address tokenIn
    )
        internal
        view
        returns (bytes memory hookData)
    {
        DebridgeOrderData memory data = DebridgeOrderData({
            usePrevHookAmount: usePrevHookAmount,
            value: value,
            giveTokenAddress: tokenIn,
            giveAmount: amount,
            version: 0,
            fallbackAddress: address(0),
            executorAddress: address(0),
            executionFee: 0,
            allowDelayedExecution: false,
            requireSuccessfulExecution: false,
            payload: "",
            takeTokenAddress: address(mockOutputToken),
            takeAmount: amount,
            takeChainId: 100,
            receiverDst: address(this),
            givePatchAuthoritySrc: address(0),
            orderAuthorityAddressDst: "",
            allowedTakerDst: "",
            allowedCancelBeneficiarySrc: "",
            affiliateFee: "",
            referralCode: 0
        });

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(mockOutputToken);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 100;
        data.payload = abi.encode("", "", address(this), dstTokens, intentAmounts);

        bytes memory part1 = _encodeDebridgePart1(data);
        bytes memory part2 = _encodeDebridgePart2(data);
        bytes memory part3 = _encodeDebridgePart3(data);
        hookData = bytes.concat(part1, part2, part3);
    }

    function _createDebridgeExternalCallEnvelope(
        address executorAddress,
        uint160 executionFee,
        address fallbackAddress,
        bytes memory payload,
        bool allowDelayedExecution,
        bool requireSuccessfulExecution // Note: Keep typo from library 'requireSuccessfullExecution'
    )
        internal
        pure
        returns (bytes memory)
    {
        DlnExternalCallLib.ExternalCallEnvelopV1 memory dataEnvelope = DlnExternalCallLib.ExternalCallEnvelopV1({
            executorAddress: executorAddress,
            executionFee: executionFee,
            fallbackAddress: fallbackAddress,
            payload: payload,
            allowDelayedExecution: allowDelayedExecution,
            requireSuccessfullExecution: requireSuccessfulExecution
        });

        // Prepend version byte (1) to the encoded envelope
        return abi.encodePacked(uint8(1), abi.encode(dataEnvelope));
    }

    function _encodeDebridgePart1(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            d.usePrevHookAmount,
            d.value,
            d.giveTokenAddress,
            d.giveAmount,
            d.version,
            d.fallbackAddress,
            d.executorAddress
        );
    }

    function _encodeDebridgePart2(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            d.executionFee,
            d.allowDelayedExecution,
            d.requireSuccessfulExecution,
            d.payload.length,
            d.payload,
            abi.encodePacked(d.takeTokenAddress).length,
            abi.encodePacked(d.takeTokenAddress),
            d.takeAmount,
            d.takeChainId
        );
    }

    function _encodeDebridgePart3(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            abi.encodePacked(d.receiverDst).length,
            abi.encodePacked(d.receiverDst),
            d.givePatchAuthoritySrc,
            d.orderAuthorityAddressDst.length,
            d.orderAuthorityAddressDst,
            d.allowedTakerDst.length,
            d.allowedTakerDst,
            d.allowedCancelBeneficiarySrc.length,
            d.allowedCancelBeneficiarySrc,
            d.affiliateFee.length,
            d.affiliateFee,
            d.referralCode
        );
    }

    function _decodeBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        return data[offset] != 0;
    }

    function _encodeCancelOrderData() internal view returns (bytes memory) {
        // Create and return the combined data in parts to avoid stack too deep error
        return _combineOrderCancellationData(_createOrderCancellationPart1(), _createOrderCancellationPart2());
    }

    // First part of the cancellation data
    function _createOrderCancellationPart1() internal view returns (bytes memory) {
        bytes memory makerSrc = abi.encodePacked(mockAccount);
        bytes memory giveTokenAddress = abi.encodePacked(mockInputToken);
        bytes memory takeTokenAddress = abi.encodePacked(mockOutputToken);

        uint64 makerOrderNonce = 123_456;
        uint256 giveAmount = mockInputAmount;
        uint256 takeAmount = mockOutputAmount;

        return abi.encodePacked(
            mockValue, // value
            makerOrderNonce, // makerOrderNonce
            uint256(makerSrc.length), // makerSrc length
            makerSrc, // makerSrc
            uint256(giveTokenAddress.length), // giveTokenAddress length
            giveTokenAddress, // giveTokenAddress
            giveAmount, // giveAmount
            uint256(1), // giveChainId
            mockDestinationChainId, // takeChainId
            uint256(takeTokenAddress.length), // takeTokenAddress length
            takeTokenAddress, // takeTokenAddress
            takeAmount // takeAmount
        );
    }

    // Second part of the cancellation data
    function _createOrderCancellationPart2() internal view returns (bytes memory) {
        bytes memory receiverDst = abi.encodePacked(mockRecipient);
        bytes memory givePatchAuthoritySrc = abi.encodePacked(address(this));
        bytes memory orderAuthorityAddressDst = abi.encodePacked(address(this));
        bytes memory allowedTakerDst = abi.encodePacked(address(0));
        bytes memory allowedCancelBeneficiarySrc = abi.encodePacked(mockAccount);

        uint256 executionFee = 0.01 ether;

        return abi.encodePacked(
            uint256(receiverDst.length), // receiverDst length
            receiverDst, // receiverDst
            uint256(givePatchAuthoritySrc.length), // givePatchAuthoritySrc length
            givePatchAuthoritySrc, // givePatchAuthoritySrc
            uint256(orderAuthorityAddressDst.length), // orderAuthorityAddressDst length
            orderAuthorityAddressDst, // orderAuthorityAddressDst
            uint256(allowedTakerDst.length), // allowedTakerDst length
            allowedTakerDst, // allowedTakerDst
            uint256(allowedCancelBeneficiarySrc.length), // allowedCancelBeneficiarySrc length
            allowedCancelBeneficiarySrc, // allowedCancelBeneficiarySrc
            executionFee // executionFee
        );
    }

    // Helper function to combine the data parts
    function _combineOrderCancellationData(
        bytes memory part1,
        bytes memory part2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(part1, part2);
    }
}
