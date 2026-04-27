// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { StargateV2SendHook } from "../../../../src/hooks/bridges/stargate/StargateV2SendHook.sol";
import { ApproveAndStargateV2SendHook } from
    "../../../../src/hooks/bridges/stargate/ApproveAndStargateV2SendHook.sol";
import { IOFT, SendParam, MessagingFee } from "../../../../src/vendor/bridges/stargate/IOFT.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract StargateHooks is Helpers {
    StargateV2SendHook public stargateHook;
    ApproveAndStargateV2SendHook public approveAndStargateHook;
    MockStargateSignatureStorage public mockSignatureStorage;

    address public mockOft;
    address public mockAccount;
    address public mockPrevHook;
    address public mockInputToken;

    uint256 public mockValue;
    uint32 public mockDstEid;
    bytes32 public mockTo;
    uint256 public mockAmountLD;
    uint256 public mockMinAmountLD;
    uint256 public mockNativeFee;
    uint256 public mockLzTokenFee;
    bytes public mockExtraOptions;
    bytes public mockComposeMsg;
    bytes public mockOftCmd;

    function setUp() public {
        mockOft = makeAddr("oft");
        mockAccount = makeAddr("account");
        mockInputToken = makeAddr("inputToken");
        mockSignatureStorage = new MockStargateSignatureStorage();

        // Mock IOFT.token() for the approve variant
        vm.mockCall(mockOft, abi.encodeWithSelector(IOFT.token.selector), abi.encode(mockInputToken));

        stargateHook = new StargateV2SendHook(address(mockSignatureStorage));
        approveAndStargateHook = new ApproveAndStargateV2SendHook(address(mockSignatureStorage));

        mockValue = 0.1 ether;
        mockDstEid = 30_101;
        mockTo = bytes32(uint256(uint160(makeAddr("recipient"))));
        mockAmountLD = 1000e18;
        mockMinAmountLD = 950e18;
        mockNativeFee = 0.05 ether;
        mockLzTokenFee = 0;
        mockExtraOptions = "";
        mockOftCmd = "";

        // Build composeMsg matching the Across pattern
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        mockComposeMsg = abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts);
    }

    /*//////////////////////////////////////////////////////////////
                       STARGATE V2 SEND HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateV2_Constructor() public view {
        assertEq(uint256(stargateHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_StargateV2_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new StargateV2SendHook(address(0));
    }

    function test_StargateV2_Build() public {
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // 1 hook execution + preExecute + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockOft);
        assertEq(executions[1].value, mockValue);

        // Verify callData encodes IOFT.send correctly
        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory expectedComposeMsg =
            abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts, sigData);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: expectedComposeMsg,
            oftCmd: mockOftCmd
        });

        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });

        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_NoComposeMsg() public {
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockOft);

        // Verify callData encodes send with empty composeMsg (no signature appended)
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "", // stays empty, no signature appended
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_WithLzTokenFee() public {
        mockLzTokenFee = 100;
        mockNativeFee = 0;
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);

        // Verify fee struct in callData
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: 0, lzTokenFee: 100 });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_RevertIf_AmountNotValid() public {
        mockAmountLD = 0;
        bytes memory data = _encodeStargateData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateV2_Build_RevertIf_RecipientNotValid() public {
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateV2_Build_RevertIf_DataNotValid() public {
        // Create data shorter than required 217 bytes
        bytes memory malformedData = abi.encodePacked(uint256(1 ether), uint32(30_101));

        vm.expectRevert(StargateV2SendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, malformedData);
    }

    function test_StargateV2_Build_RevertIf_OftAddressZero() public {
        // Encode with address(0) as the OFT contract
        bytes memory fixedFields = abi.encodePacked(
            address(0), mockValue, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD, mockNativeFee, mockLzTokenFee,
            false
        );
        bytes memory variableFields = abi.encodePacked(uint256(0), uint256(0), uint256(0));
        bytes memory data = abi.encodePacked(fixedFields, variableFields);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e18;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);

        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        // Verify amounts are scaled
        uint256 expectedMinAmountLD = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);

        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory expectedComposeMsg =
            abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts, sigData);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: prevHookAmount,
            minAmountLD: expectedMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: expectedComposeMsg,
            oftCmd: mockOftCmd
        });

        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });

        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_WithPrevHookAmount_AndRevertIfAmountZero() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(mockPrevHook, mockAccount, data);
    }

    function test_StargateV2_Inspector() public view {
        bytes memory data = _encodeStargateData(false);
        bytes memory argsEncoded = stargateHook.inspect(data);
        assertGt(argsEncoded.length, 0);
        // Should be 20 bytes: OFT address from calldata
        assertEq(argsEncoded.length, 20);
        assertEq(argsEncoded, abi.encodePacked(mockOft));
    }

    function test_StargateV2_DecodePrevHookAmount() public view {
        bytes memory data = _encodeStargateData(false);
        assertFalse(stargateHook.decodeUsePrevHookAmount(data));

        data = _encodeStargateData(true);
        assertTrue(stargateHook.decodeUsePrevHookAmount(data));
    }

    function test_StargateV2_PreExecute() public {
        stargateHook.preExecute(address(0), address(this), "");
    }

    function test_StargateV2_PostExecute() public {
        stargateHook.postExecute(address(0), address(this), "");
    }

    function test_StargateV2_Subtype() public view {
        assertNotEq(BaseHook(address(stargateHook)).subtype(), bytes32(0));
    }

    function test_StargateV2_Build_WithExtraOptions() public {
        mockExtraOptions = hex"0003010011010000000000000000000000000000ea60";
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_WithOftCmd() public {
        mockOftCmd = hex"01";
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: hex"01"
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_WithAllVariableFields() public {
        mockExtraOptions = hex"0003010011010000000000000000000000000000ea60";
        mockOftCmd = hex"01";
        // keep mockComposeMsg non-empty (set in setUp)
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);

        // Verify all variable fields pass through
        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory expectedComposeMsg =
            abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts, sigData);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: expectedComposeMsg,
            oftCmd: hex"01"
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_ValueZero() public {
        mockValue = 0;
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, 0);
    }

    function test_StargateV2_Build_WithPrevHookAmount_MinAmountZero() public {
        uint256 prevHookAmount = 2000e18;
        mockMinAmountLD = 0; // scaling skipped because minAmountLD == 0
        mockComposeMsg = "";

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        // minAmountLD stays 0 because scaling is skipped (original minAmountLD == 0)
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: prevHookAmount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_StargateV2_Build_WithPrevHookAmount_OriginalAmountZero() public {
        uint256 prevHookAmount = 2000e18;
        mockAmountLD = 0; // scaling skipped because amountLD == 0
        mockMinAmountLD = 950e18;
        mockComposeMsg = "";

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        // minAmountLD resets to 0 because scaling condition (amountLD > 0 && minAmountLD > 0) is false
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: prevHookAmount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[1].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                 APPROVE AND STARGATE V2 SEND HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndStargateV2_Constructor() public view {
        assertEq(uint256(approveAndStargateHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ApproveAndStargateV2_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndStargateV2SendHook(address(0));
    }

    function test_ApproveAndStargateV2_Build_ERC20() public {
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // 4 hook executions + preExecute + postExecute = 6
        assertEq(executions.length, 6, "Should have 6 executions for ERC20 (4 hook + preExecute + postExecute)");

        // Check approval reset to 0 (index 1 after preExecute)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockOft, 0)));

        // Check approval to exact amount
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockOft, mockAmountLD)));

        // Check bridge execution
        assertEq(executions[3].target, mockOft);
        assertEq(executions[3].value, mockValue);

        // Check approval cleanup
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].value, 0);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockOft, 0)));
    }

    function test_ApproveAndStargateV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e18;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, mockAccount);

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);

        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(
            executions.length, 6, "Should have 6 executions for ERC20 with prev amount (4 hook + preExecute + postExecute)"
        );

        // Check that approval uses prev hook amount (index 2 after preExecute)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockOft, prevHookAmount)));
    }

    function test_ApproveAndStargateV2_Build_RevertIf_AmountNotValid() public {
        mockAmountLD = 0;
        bytes memory data = _encodeStargateData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateV2_Build_RevertIf_RecipientNotValid() public {
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateV2_Build_RevertIf_DataNotValid() public {
        bytes memory malformedData = abi.encodePacked(uint256(1 ether), uint32(30_101));

        vm.expectRevert(ApproveAndStargateV2SendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, malformedData);
    }

    function test_ApproveAndStargateV2_Inspector() public view {
        bytes memory data = _encodeStargateData(false);
        bytes memory argsEncoded = approveAndStargateHook.inspect(data);
        assertGt(argsEncoded.length, 0);
        // Should be 20 bytes: OFT address from calldata
        assertEq(argsEncoded.length, 20);
        assertEq(argsEncoded, abi.encodePacked(mockOft));
    }

    function test_ApproveAndStargateV2_DecodePrevHookAmount() public view {
        bytes memory data = _encodeStargateData(false);
        assertFalse(approveAndStargateHook.decodeUsePrevHookAmount(data));

        data = _encodeStargateData(true);
        assertTrue(approveAndStargateHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndStargateV2_PreExecute() public {
        approveAndStargateHook.preExecute(address(0), address(this), "");
    }

    function test_ApproveAndStargateV2_PostExecute() public {
        approveAndStargateHook.postExecute(address(0), address(this), "");
    }

    function test_ApproveAndStargateV2_Subtype() public view {
        assertNotEq(BaseHook(address(approveAndStargateHook)).subtype(), bytes32(0));
    }

    function test_ApproveAndStargateV2_Build_NoComposeMsg() public {
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        // Verify bridge callData with empty composeMsg (no signature appended)
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithExtraOptions() public {
        mockExtraOptions = hex"0003010011010000000000000000000000000000ea60";
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithOftCmd() public {
        mockOftCmd = hex"01";
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: hex"01"
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithAllVariableFields() public {
        mockExtraOptions = hex"0003010011010000000000000000000000000000ea60";
        mockOftCmd = hex"01";
        // mockComposeMsg is non-empty from setUp
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory expectedComposeMsg =
            abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts, sigData);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: expectedComposeMsg,
            oftCmd: hex"01"
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_ValueZero() public {
        mockValue = 0;
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].value, 0);
    }

    function test_ApproveAndStargateV2_Build_WithLzTokenFee() public {
        mockLzTokenFee = 100;
        mockNativeFee = 0;
        mockComposeMsg = "";
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: 0, lzTokenFee: 100 });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithPrevHookAmount_RevertIfAmountZero() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, mockAccount);
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndStargateHook.build(mockPrevHook, mockAccount, data);
    }

    function test_ApproveAndStargateV2_Build_WithPrevHookAmount_MinAmountZero() public {
        uint256 prevHookAmount = 2000e18;
        mockMinAmountLD = 0;
        mockComposeMsg = "";

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, mockAccount);
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);

        // Approval uses prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockOft, prevHookAmount)));

        // Bridge uses prevHookAmount with minAmountLD=0 (scaling skipped)
        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: prevHookAmount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithPrevHookAmount_VerifyBridgeCallData() public {
        uint256 prevHookAmount = 2000e18;
        mockComposeMsg = "";

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, mockAccount);
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        // Verify full bridge callData with scaled amounts
        uint256 expectedMinAmountLD = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: prevHookAmount,
            minAmountLD: expectedMinAmountLD,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });
        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_ApproveAndStargateV2_Build_WithMessage() public {
        bytes memory data = _encodeStargateData(false);

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        // Verify the bridge call includes the processed message with signature (index 3 after preExecute)
        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        bytes memory expectedComposeMsg =
            abi.encode(bytes("0x123"), bytes("0x123"), mockAccount, dstTokens, intentAmounts, sigData);

        SendParam memory expectedSendParam = SendParam({
            dstEid: mockDstEid,
            to: mockTo,
            amountLD: mockAmountLD,
            minAmountLD: mockMinAmountLD,
            extraOptions: mockExtraOptions,
            composeMsg: expectedComposeMsg,
            oftCmd: mockOftCmd
        });

        MessagingFee memory expectedFee = MessagingFee({ nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee });

        bytes memory expectedCallData = abi.encodeCall(IOFT.send, (expectedSendParam, expectedFee, mockAccount));
        assertEq(executions[3].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _encodeStargateData(bool usePrevHookAmount) internal view returns (bytes memory) {
        // Fixed fields (OFT address prepended)
        bytes memory fixedFields = abi.encodePacked(
            mockOft, // address oftContract (offset 0, 20 bytes)
            mockValue, // uint256 value (offset 20)
            mockDstEid, // uint32 dstEid (offset 52)
            mockTo, // bytes32 to (offset 56)
            mockAmountLD, // uint256 amountLD (offset 88)
            mockMinAmountLD, // uint256 minAmountLD (offset 120)
            mockNativeFee, // uint256 nativeFee (offset 152)
            mockLzTokenFee, // uint256 lzTokenFee (offset 184)
            usePrevHookAmount // bool usePrevHookAmount (offset 216)
        );

        // Variable-length fields (length-prefixed)
        bytes memory variableFields = abi.encodePacked(
            uint256(mockExtraOptions.length),
            mockExtraOptions,
            uint256(mockComposeMsg.length),
            mockComposeMsg,
            uint256(mockOftCmd.length),
            mockOftCmd
        );

        return abi.encodePacked(fixedFields, variableFields);
    }
}
