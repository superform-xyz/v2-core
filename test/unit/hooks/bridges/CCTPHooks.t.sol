// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndCCTPSendHook } from "../../../../src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol";
import { CCTPSendHook } from "../../../../src/hooks/bridges/cctp/CCTPSendHook.sol";
import { ITokenMessengerV2 } from "../../../../src/vendor/bridges/cctp/ITokenMessengerV2.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockCCTPSignatureStorage {
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

contract CCTPHooks is Helpers {
    ApproveAndCCTPSendHook public cctpHook;
    MockCCTPSignatureStorage public mockSignatureStorage;

    address public mockAccount;
    address public mockPrevHook;
    address public mockTokenMessenger;
    address public mockBurnToken;

    uint256 public mockAmount;
    uint32 public mockDestinationDomain;
    bytes32 public mockMintRecipient;
    bytes32 public mockDestinationCaller;
    uint256 public mockMaxFee;
    uint32 public mockMinFinalityThreshold;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockTokenMessenger = makeAddr("tokenMessenger");
        mockBurnToken = makeAddr("burnToken");

        mockAmount = 1000e6; // 1000 USDC
        mockDestinationDomain = 6; // Base
        mockMintRecipient = bytes32(uint256(uint160(makeAddr("recipient"))));
        mockDestinationCaller = bytes32(uint256(uint160(makeAddr("caller"))));
        mockMaxFee = 1e6; // 1 USDC fee
        mockMinFinalityThreshold = 1000; // Fast finality

        mockSignatureStorage = new MockCCTPSignatureStorage();
        cctpHook = new ApproveAndCCTPSendHook(mockTokenMessenger, address(mockSignatureStorage));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Constructor() public view {
        assertEq(uint256(cctpHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(cctpHook.TOKEN_MESSENGER(), mockTokenMessenger);
    }

    function test_CCTP_Constructor_RevertIf_ZeroTokenMessenger() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndCCTPSendHook(address(0), address(mockSignatureStorage));
    }

    function test_CCTP_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndCCTPSendHook(mockTokenMessenger, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD TESTS (BASIC)
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Build() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        // preExecute + 4 hook executions + postExecute = 6
        assertEq(executions.length, 6);
    }

    function test_CCTP_Build_VerifyApprovePattern() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        // Execution 1 (index 1): approve(TOKEN_MESSENGER, 0)
        assertEq(executions[1].target, mockBurnToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockTokenMessenger, 0)));

        // Execution 2 (index 2): approve(TOKEN_MESSENGER, amount)
        assertEq(executions[2].target, mockBurnToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockTokenMessenger, mockAmount)));

        // Execution 3 (index 3): depositForBurnWithHook
        assertEq(executions[3].target, mockTokenMessenger);

        // Execution 4 (index 4): approve(TOKEN_MESSENGER, 0)
        assertEq(executions[4].target, mockBurnToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockTokenMessenger, 0)));
    }

    function test_CCTP_Build_VerifyDepositForBurnWithHookCalldata() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        // Execution 3 (index 3): depositForBurnWithHook
        bytes memory expectedCalldata = abi.encodeCall(
            ITokenMessengerV2.depositForBurnWithHook,
            (
                mockAmount,
                mockDestinationDomain,
                mockMintRecipient,
                mockBurnToken,
                mockDestinationCaller,
                mockMaxFee,
                mockMinFinalityThreshold,
                bytes("") // empty hookCallData
            )
        );
        assertEq(executions[3].callData, expectedCalldata);
    }

    function test_CCTP_Build_VerifyNoNativeValue() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        // All executions should have value = 0 (no native ETH needed for CCTP)
        for (uint256 i = 0; i < executions.length; i++) {
            assertEq(executions[i].value, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            mockBurnToken, // address (20 bytes)
            uint256(0), // amount = 0
            mockDestinationDomain, // uint32 (4 bytes)
            mockMintRecipient, // bytes32 (32 bytes)
            mockDestinationCaller, // bytes32 (32 bytes)
            mockMaxFee, // uint256 (32 bytes)
            mockMinFinalityThreshold, // uint32 (4 bytes)
            false // usePrevHookAmount (1 byte)
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cctpHook.build(address(0), mockAccount, data);
    }

    function test_CCTP_Build_RevertIf_ZeroBurnToken() public {
        bytes memory data = abi.encodePacked(
            address(0), // burnToken = 0
            mockAmount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        cctpHook.build(address(0), mockAccount, data);
    }

    function test_CCTP_Build_RevertIf_ZeroRecipient() public {
        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            mockDestinationDomain,
            bytes32(0), // mintRecipient = 0
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        vm.expectRevert(ApproveAndCCTPSendHook.RECIPIENT_NOT_VALID.selector);
        cctpHook.build(address(0), mockAccount, data);
    }

    function test_CCTP_Build_RevertIf_DataTooShort() public {
        bytes memory data = hex"aabbccdd"; // Way too short

        vm.expectRevert(ApproveAndCCTPSendHook.DATA_NOT_VALID.selector);
        cctpHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                        PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);
        Execution[] memory executions = cctpHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);

        // Verify the approval uses the prev hook amount, not the encoded amount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockTokenMessenger, prevHookAmount)));
    }

    function test_CCTP_Build_WithPrevHookAmount_ScalesMaxFee() public {
        uint256 prevHookAmount = 2000e6; // Double the original

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);
        Execution[] memory executions = cctpHook.build(mockPrevHook, mockAccount, data);

        // maxFee should scale: 1e6 * 2000e6 / 1000e6 = 2e6
        uint256 expectedMaxFee = Math.mulDiv(mockMaxFee, prevHookAmount, mockAmount);

        // Decode the depositForBurnWithHook calldata to verify maxFee was scaled
        // calldata layout: selector(4) + amount(32) + destinationDomain(32) + mintRecipient(32)
        //                  + burnToken(32) + destinationCaller(32) + maxFee(32) + ...
        bytes memory callData = executions[3].callData;
        uint256 encodedMaxFee;
        assembly {
            // skip 4 bytes selector + 5*32 bytes (amount, dstDomain, recipient, burnToken, dstCaller) = 164 offset
            // from start of callData memory: +32 (length) + 4 (selector) + 160 (5 params) = 196
            encodedMaxFee := mload(add(callData, 196))
        }
        assertEq(encodedMaxFee, expectedMaxFee, "maxFee should be scaled proportionally");
        assertEq(expectedMaxFee, 2e6, "expected 2 USDC maxFee for doubled amount");
    }

    function test_CCTP_Build_WithPrevHookAmount_RevertIf_ZeroAmount() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cctpHook.build(mockPrevHook, mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                          HOOK CALL DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Build_WithHookCallData() public view {
        bytes memory data = _encodeCCTPData(false, true);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        // Verify the depositForBurnWithHook call has non-empty hookData
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, ITokenMessengerV2.depositForBurnWithHook.selector);
    }

    function test_CCTP_Build_WithoutHookCallData() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);

        // Verify the depositForBurnWithHook is called with empty hookData
        bytes memory expectedCalldata = abi.encodeCall(
            ITokenMessengerV2.depositForBurnWithHook,
            (
                mockAmount,
                mockDestinationDomain,
                mockMintRecipient,
                mockBurnToken,
                mockDestinationCaller,
                mockMaxFee,
                mockMinFinalityThreshold,
                bytes("")
            )
        );
        assertEq(executions[3].callData, expectedCalldata);
    }

    function test_CCTP_Build_WithHookCallData_RevertIf_TooShort() public {
        // Create hookCallData that is too short (< 160 bytes)
        bytes memory shortHookCallData = hex"aabbccdd";

        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false,
            shortHookCallData
        );

        vm.expectRevert(ApproveAndCCTPSendHook.DATA_NOT_VALID.selector);
        cctpHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                          INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Inspector() public view {
        bytes memory data = _encodeCCTPData(false, false);
        bytes memory result = cctpHook.inspect(data);

        // Should return burnToken + mintRecipient (as address)
        address expectedRecipientAddress = address(uint160(uint256(mockMintRecipient)));
        assertEq(result, abi.encodePacked(mockBurnToken, expectedRecipientAddress));
    }

    function test_CCTP_Inspector_VerifyBurnToken() public view {
        bytes memory data = _encodeCCTPData(false, false);
        bytes memory result = cctpHook.inspect(data);

        // Extract burnToken (first 20 bytes)
        address burnTokenResult;
        assembly {
            burnTokenResult := mload(add(result, 20))
        }
        assertEq(burnTokenResult, mockBurnToken);
    }

    function test_CCTP_Inspector_VerifyMintRecipient() public view {
        bytes memory data = _encodeCCTPData(false, false);
        bytes memory result = cctpHook.inspect(data);

        // Extract mintRecipient (bytes 20-39)
        address recipientResult;
        assembly {
            recipientResult := mload(add(result, 40))
        }
        assertEq(recipientResult, address(uint160(uint256(mockMintRecipient))));
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeCCTPData(true, false);
        assertTrue(cctpHook.decodeUsePrevHookAmount(data));
    }

    function test_CCTP_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeCCTPData(false, false);
        assertFalse(cctpHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                       PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_PreExecute() public {
        // preExecute is a no-op in the hook itself (handled by BaseHook)
        // Just verify it doesn't revert
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);
        assertTrue(executions.length > 0);
    }

    function test_CCTP_PostExecute() public {
        // postExecute is a no-op in the hook itself (handled by BaseHook)
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);
        assertTrue(executions.length > 0);
    }

    /*//////////////////////////////////////////////////////////////
                           SUBTYPE TEST
    //////////////////////////////////////////////////////////////*/

    function test_CCTP_Subtype() public view {
        assertEq(cctpHook.subtype(), keccak256(bytes("Bridge")));
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CCTP_Build_VariableAmounts(uint256 amount) public view {
        vm.assume(amount > 0);

        bytes memory data = abi.encodePacked(
            mockBurnToken,
            amount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);

        // Verify approve uses the fuzzed amount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockTokenMessenger, amount)));
    }

    function testFuzz_CCTP_Build_VariableDomains(uint32 domain) public view {
        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            domain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        Execution[] memory executions = cctpHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createMockComposeMsg() internal pure returns (bytes memory) {
        bytes memory initData = abi.encode(bytes("init"));
        bytes memory executorCalldata = abi.encode(bytes("executor"));
        address account = address(0xBEEF);
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(0xCAFE);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 500e6;

        return abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts);
    }

    function _encodeCCTPData(bool usePrevHookAmount, bool withHookCallData) internal view returns (bytes memory) {
        bytes memory hookCallData;
        if (withHookCallData) {
            hookCallData = _createMockComposeMsg();
        }

        return abi.encodePacked(
            mockBurnToken, // address (20 bytes)
            mockAmount, // uint256 (32 bytes)
            mockDestinationDomain, // uint32 (4 bytes)
            mockMintRecipient, // bytes32 (32 bytes)
            mockDestinationCaller, // bytes32 (32 bytes)
            mockMaxFee, // uint256 (32 bytes)
            mockMinFinalityThreshold, // uint32 (4 bytes)
            usePrevHookAmount, // bool (1 byte)
            hookCallData // bytes (variable, last field)
        );
    }
}

/// @title CCTPSendHookTests
/// @notice Unit tests for the no-approve CCTP V2 send hook variant
contract CCTPSendHookTests is Helpers {
    CCTPSendHook public cctpSendHook;
    MockCCTPSignatureStorage public mockSignatureStorage;

    address public mockAccount;
    address public mockPrevHook;
    address public mockTokenMessenger;
    address public mockBurnToken;

    uint256 public mockAmount;
    uint32 public mockDestinationDomain;
    bytes32 public mockMintRecipient;
    bytes32 public mockDestinationCaller;
    uint256 public mockMaxFee;
    uint32 public mockMinFinalityThreshold;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockTokenMessenger = makeAddr("tokenMessenger");
        mockBurnToken = makeAddr("burnToken");

        mockAmount = 1000e6;
        mockDestinationDomain = 6;
        mockMintRecipient = bytes32(uint256(uint160(makeAddr("recipient"))));
        mockDestinationCaller = bytes32(uint256(uint160(makeAddr("caller"))));
        mockMaxFee = 1e6;
        mockMinFinalityThreshold = 1000;

        mockSignatureStorage = new MockCCTPSignatureStorage();
        cctpSendHook = new CCTPSendHook(mockTokenMessenger, address(mockSignatureStorage));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Constructor() public view {
        assertEq(uint256(cctpSendHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(cctpSendHook.TOKEN_MESSENGER(), mockTokenMessenger);
    }

    function test_CCTPSend_Constructor_RevertIf_ZeroTokenMessenger() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new CCTPSendHook(address(0), address(mockSignatureStorage));
    }

    function test_CCTPSend_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new CCTPSendHook(mockTokenMessenger, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD TESTS (BASIC)
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Build() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);

        // preExecute + 1 hook execution + postExecute = 3
        assertEq(executions.length, 3);
    }

    function test_CCTPSend_Build_NoApprovePattern() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);

        // Only 3 executions: preExecute + depositForBurnWithHook + postExecute
        assertEq(executions.length, 3);

        // Execution 1 (index 1): depositForBurnWithHook — not an approve call
        assertEq(executions[1].target, mockTokenMessenger);
        assertEq(bytes4(executions[1].callData), ITokenMessengerV2.depositForBurnWithHook.selector);
    }

    function test_CCTPSend_Build_VerifyDepositForBurnWithHookCalldata() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);

        bytes memory expectedCalldata = abi.encodeCall(
            ITokenMessengerV2.depositForBurnWithHook,
            (
                mockAmount,
                mockDestinationDomain,
                mockMintRecipient,
                mockBurnToken,
                mockDestinationCaller,
                mockMaxFee,
                mockMinFinalityThreshold,
                bytes("")
            )
        );
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_CCTPSend_Build_VerifyNoNativeValue() public view {
        bytes memory data = _encodeCCTPData(false, false);
        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);

        for (uint256 i = 0; i < executions.length; i++) {
            assertEq(executions[i].value, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            mockBurnToken,
            uint256(0),
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cctpSendHook.build(address(0), mockAccount, data);
    }

    function test_CCTPSend_Build_RevertIf_ZeroBurnToken() public {
        bytes memory data = abi.encodePacked(
            address(0),
            mockAmount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        cctpSendHook.build(address(0), mockAccount, data);
    }

    function test_CCTPSend_Build_RevertIf_ZeroRecipient() public {
        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            mockDestinationDomain,
            bytes32(0),
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        vm.expectRevert(CCTPSendHook.RECIPIENT_NOT_VALID.selector);
        cctpSendHook.build(address(0), mockAccount, data);
    }

    function test_CCTPSend_Build_RevertIf_DataTooShort() public {
        bytes memory data = hex"aabbccdd";

        vm.expectRevert(CCTPSendHook.DATA_NOT_VALID.selector);
        cctpSendHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                        PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);
        Execution[] memory executions = cctpSendHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);

        // Verify the depositForBurnWithHook uses the prev hook amount and scaled maxFee
        uint256 expectedMaxFee = Math.mulDiv(mockMaxFee, prevHookAmount, mockAmount);
        bytes memory expectedCalldata = abi.encodeCall(
            ITokenMessengerV2.depositForBurnWithHook,
            (
                prevHookAmount,
                mockDestinationDomain,
                mockMintRecipient,
                mockBurnToken,
                mockDestinationCaller,
                expectedMaxFee,
                mockMinFinalityThreshold,
                bytes("")
            )
        );
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_CCTPSend_Build_WithPrevHookAmount_ScalesMaxFee() public {
        uint256 prevHookAmount = 2000e6; // Double the original

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);
        Execution[] memory executions = cctpSendHook.build(mockPrevHook, mockAccount, data);

        // maxFee should scale: 1e6 * 2000e6 / 1000e6 = 2e6
        uint256 expectedMaxFee = Math.mulDiv(mockMaxFee, prevHookAmount, mockAmount);

        // Decode the depositForBurnWithHook calldata to verify maxFee was scaled
        // For CCTPSendHook: executions[1] is the depositForBurnWithHook (no approve pattern)
        bytes memory callData = executions[1].callData;
        uint256 encodedMaxFee;
        assembly {
            // skip 4 bytes selector + 5*32 bytes (amount, dstDomain, recipient, burnToken, dstCaller) = 164 offset
            // from start of callData memory: +32 (length) + 4 (selector) + 160 (5 params) = 196
            encodedMaxFee := mload(add(callData, 196))
        }
        assertEq(encodedMaxFee, expectedMaxFee, "maxFee should be scaled proportionally");
        assertEq(expectedMaxFee, 2e6, "expected 2 USDC maxFee for doubled amount");
    }

    function test_CCTPSend_Build_WithPrevHookAmount_RevertIf_ZeroAmount() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockBurnToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeCCTPData(true, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cctpSendHook.build(mockPrevHook, mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                          HOOK CALL DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Build_WithHookCallData() public view {
        bytes memory data = _encodeCCTPData(false, true);
        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(bytes4(executions[1].callData), ITokenMessengerV2.depositForBurnWithHook.selector);
    }

    function test_CCTPSend_Build_WithHookCallData_RevertIf_TooShort() public {
        bytes memory shortHookCallData = hex"aabbccdd";

        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false,
            shortHookCallData
        );

        vm.expectRevert(CCTPSendHook.DATA_NOT_VALID.selector);
        cctpSendHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                          INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Inspector() public view {
        bytes memory data = _encodeCCTPData(false, false);
        bytes memory result = cctpSendHook.inspect(data);

        address expectedRecipientAddress = address(uint160(uint256(mockMintRecipient)));
        assertEq(result, abi.encodePacked(mockBurnToken, expectedRecipientAddress));
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeCCTPData(true, false);
        assertTrue(cctpSendHook.decodeUsePrevHookAmount(data));
    }

    function test_CCTPSend_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeCCTPData(false, false);
        assertFalse(cctpSendHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                           SUBTYPE TEST
    //////////////////////////////////////////////////////////////*/

    function test_CCTPSend_Subtype() public view {
        assertEq(cctpSendHook.subtype(), keccak256(bytes("Bridge")));
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CCTPSend_Build_VariableAmounts(uint256 amount) public view {
        vm.assume(amount > 0);

        bytes memory data = abi.encodePacked(
            mockBurnToken,
            amount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function testFuzz_CCTPSend_Build_VariableDomains(uint32 domain) public view {
        bytes memory data = abi.encodePacked(
            mockBurnToken,
            mockAmount,
            domain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            false
        );

        Execution[] memory executions = cctpSendHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createMockComposeMsg() internal pure returns (bytes memory) {
        bytes memory initData = abi.encode(bytes("init"));
        bytes memory executorCalldata = abi.encode(bytes("executor"));
        address account = address(0xBEEF);
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(0xCAFE);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 500e6;

        return abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts);
    }

    function _encodeCCTPData(bool usePrevHookAmount, bool withHookCallData) internal view returns (bytes memory) {
        bytes memory hookCallData;
        if (withHookCallData) {
            hookCallData = _createMockComposeMsg();
        }

        return abi.encodePacked(
            mockBurnToken,
            mockAmount,
            mockDestinationDomain,
            mockMintRecipient,
            mockDestinationCaller,
            mockMaxFee,
            mockMinFinalityThreshold,
            usePrevHookAmount,
            hookCallData
        );
    }
}
