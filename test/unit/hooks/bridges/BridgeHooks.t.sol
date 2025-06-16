// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {AcrossSendFundsAndExecuteOnDstHook} from
    "../../../../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import {DeBridgeSendOrderAndExecuteOnDstHook} from
    "../../../../src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import {ISuperHook} from "../../../../src/core/interfaces/ISuperHook.sol";
import {IAcrossSpokePoolV3} from "../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import {MockHook} from "../../../mocks/MockHook.sol";
import {BaseHook} from "../../../../src/core/hooks/BaseHook.sol";
import {Helpers} from "../../../utils/Helpers.sol";
import {DlnExternalCallLib} from "../../../../lib/pigeon/src/debridge/libraries/DlnExternalCallLib.sol";

contract MockSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        bytes32[] memory proofDst = new bytes32[](1);
        proofDst[0] = keccak256("dst1");

        bytes memory signature = hex"abcdef";
        return abi.encode(validUntil, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract BridgeHooks is Helpers {
    AcrossSendFundsAndExecuteOnDstHook public acrossV3hook;
    DeBridgeSendOrderAndExecuteOnDstHook public deBridgehook;
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

    function test_AcrossV3_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000;

        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeAcrossData(true);

        Execution[] memory executions = acrossV3hook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(mockOutputToken);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), dstTokens, intentAmounts, sigData);

        bytes memory expectedCallData = abi.encodeCall(
            IAcrossSpokePoolV3.depositV3Now,
            (
                mockAccount,
                mockRecipient,
                mockInputToken,
                mockOutputToken,
                prevHookAmount,
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

    function test_AcrossV3_Build_WithPrevHookAmount_AndRevertIfAmountZero() public {
        uint256 prevHookAmount = 0;

        vm.mockCall(
            mockSpokePool, abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector), abi.encode(0)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeAcrossData(true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossV3hook.build(mockPrevHook, mockAccount, data);
    }

    function test_AcrossV3_Build_WithPrevHookAmount_AndRevertIfAmountZero_WithWrappedNative() public {
        uint256 prevHookAmount = 0;

        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

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
        bytes memory data = _encodeDebridgeData(false, 100, address(mockInputToken));
        bytes memory argsEncoded = deBridgehook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_Debrigdge_Build() public view {
        bytes memory data = _encodeDebridgeData(false, 100, address(mockInputToken));
        Execution[] memory executions = deBridgehook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debrigdge_Build_UsePrevAmount() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(100);

        bytes memory data = _encodeDebridgeData(true, 100, address(mockInputToken));
        Execution[] memory executions = deBridgehook.build(mockPrevHook, mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debrigdge_Build_UsePrevAmount_ETH() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(100);

        bytes memory data = _encodeDebridgeData(true, 100, address(0));
        Execution[] memory executions = deBridgehook.build(mockPrevHook, mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_Debridge_RevertAmountZero() public {
        bytes memory data = _encodeDebridgeData(false, 0, address(mockInputToken));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        deBridgehook.build(address(0), mockAccount, data);
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

    function _encodeDebridgeData(bool usePrevHookAmount, uint256 amount, address tokenIn)
        internal
        view
        returns (bytes memory hookData)
    {
        DebridgeOrderData memory data = DebridgeOrderData({
            usePrevHookAmount: usePrevHookAmount,
            value: amount,
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
    ) internal pure returns (bytes memory) {
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
}
