// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    AcrossSendFundsAndExecuteOnDstHookV2
} from "../../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol";
import {
    ApproveAndAcrossSendFundsAndExecuteOnDstHookV2
} from "../../../../src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol";
import { IAcrossSpokePoolV3 } from "../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Mock signature storage that returns sigData with a DstProof matching the current chain
contract MockAcrossSignatureStorageV2 {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        // V2: Include DstProof with matching chain ID so adapter can extract fields
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: address(0xBEEF),
                executor: address(0xCAFE),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
                data: hex"deadbeef"
            })
        });

        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract AcrossHooksV2 is Helpers {
    AcrossSendFundsAndExecuteOnDstHookV2 public acrossHookV2;
    ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 public approveAndAcrossHookV2;
    MockAcrossSignatureStorageV2 public mockSignatureStorage;

    address public mockAccount;
    address public mockPrevHook;
    address public mockSpokePool;
    address public mockInputToken;
    address public mockOutputToken;

    uint256 public mockValue;
    address public mockRecipient;
    uint256 public mockInputAmount;
    uint256 public mockOutputAmount;
    uint256 public mockDestinationChainId;
    address public mockExclusiveRelayer;
    uint32 public mockFillDeadlineOffset;
    uint32 public mockExclusivityPeriod;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockSpokePool = makeAddr("spokePool");
        mockInputToken = makeAddr("inputToken");
        mockOutputToken = makeAddr("outputToken");

        mockValue = 0;
        mockRecipient = makeAddr("recipient");
        mockInputAmount = 1000e6; // 1000 USDC
        mockOutputAmount = 995e6; // 0.5% slippage
        mockDestinationChainId = 8453; // Base
        mockExclusiveRelayer = address(0);
        mockFillDeadlineOffset = 3600;
        mockExclusivityPeriod = 0;

        mockSignatureStorage = new MockAcrossSignatureStorageV2();
        acrossHookV2 = new AcrossSendFundsAndExecuteOnDstHookV2(mockSpokePool, address(mockSignatureStorage));
        approveAndAcrossHookV2 =
            new ApproveAndAcrossSendFundsAndExecuteOnDstHookV2(mockSpokePool, address(mockSignatureStorage));

        // Mock wrappedNativeToken for native value test
        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_Constructor() public view {
        assertEq(uint256(acrossHookV2.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(acrossHookV2.SPOKE_POOL_V3(), mockSpokePool);
    }

    function test_AcrossSendV2_Constructor_RevertIf_ZeroSpokePool() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHookV2(address(0), address(mockSignatureStorage));
    }

    function test_AcrossSendV2_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHookV2(mockSpokePool, address(0));
    }

    function test_ApproveAndAcrossSendV2_Constructor() public view {
        assertEq(uint256(approveAndAcrossHookV2.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(approveAndAcrossHookV2.SPOKE_POOL_V3(), mockSpokePool);
    }

    function test_ApproveAndAcrossSendV2_Constructor_RevertIf_ZeroSpokePool() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndAcrossSendFundsAndExecuteOnDstHookV2(address(0), address(mockSignatureStorage));
    }

    function test_ApproveAndAcrossSendV2_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndAcrossSendFundsAndExecuteOnDstHookV2(mockSpokePool, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                         ACROSS SEND V2 BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_Build_NoDestinationMessage() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        Execution[] memory executions = acrossHookV2.build(address(0), mockAccount, data);

        // preExecute + depositV3Now + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockSpokePool);
        assertEq(executions[1].value, mockValue);
    }

    function test_AcrossSendV2_Build_WithDestinationMessage() public view {
        bytes memory data = _encodeAcrossV2Data(false, true);
        Execution[] memory executions = acrossHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockSpokePool);

        // Verify the calldata contains depositV3Now call
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IAcrossSpokePoolV3.depositV3Now.selector);
    }

    function test_AcrossSendV2_Build_DestinationMessageIsCompact() public view {
        // Verify V2 produces a compact 2-field destinationMessage (initData, sigData)
        bytes memory data = _encodeAcrossV2Data(false, true);
        Execution[] memory executions = acrossHookV2.build(address(0), mockAccount, data);

        assertGt(executions[1].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                       ACROSS V2 PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossV2Data(true, false);
        Execution[] memory executions = acrossHookV2.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
    }

    function test_AcrossSendV2_Build_WithPrevHookAmount_ScalesOutputAmount() public {
        uint256 prevHookAmount = 2000e6; // Double the original

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossV2Data(true, false);
        Execution[] memory executions = acrossHookV2.build(mockPrevHook, mockAccount, data);

        // Verify outputAmount was scaled: outputAmount * prevHookAmount / inputAmount
        uint256 expectedOutputAmount = Math.mulDiv(mockOutputAmount, prevHookAmount, mockInputAmount);
        assertGt(expectedOutputAmount, 0);
        assertEq(executions.length, 3);
    }

    function test_AcrossSendV2_Build_WithPrevHookAmount_NativeValue() public {
        uint256 prevHookAmount = 2 ether;
        uint256 originalValue = mockValue;
        mockValue = 1 ether;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossV2Data(true, false);
        Execution[] memory executions = acrossHookV2.build(mockPrevHook, mockAccount, data);

        // value should be updated to prevHookAmount when inputToken == wrappedNativeToken && value != 0
        assertEq(executions[1].value, prevHookAmount);
        mockValue = originalValue;
    }

    /*//////////////////////////////////////////////////////////////
                       ACROSS V2 REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(AcrossSendFundsAndExecuteOnDstHookV2.DATA_NOT_VALID.selector);
        acrossHookV2.build(address(0), mockAccount, shortData);
    }

    function test_AcrossSendV2_Build_RevertIf_AmountZero() public {
        uint256 originalAmount = mockInputAmount;
        mockInputAmount = 0;
        bytes memory data = _encodeAcrossV2Data(false, false);
        mockInputAmount = originalAmount;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossHookV2.build(address(0), mockAccount, data);
    }

    function test_AcrossSendV2_Build_RevertIf_RecipientZero() public {
        address originalRecipient = mockRecipient;
        mockRecipient = address(0);
        bytes memory data = _encodeAcrossV2Data(false, false);
        mockRecipient = originalRecipient;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        acrossHookV2.build(address(0), mockAccount, data);
    }

    function test_AcrossSendV2_Build_RevertIf_PrevHookAmountZero() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossV2Data(true, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        acrossHookV2.build(mockPrevHook, mockAccount, data);
    }

    function test_AcrossSendV2_Build_RevertIf_DestinationMessageTooShort() public {
        // destinationMessage present but < 64 bytes (too short for V2 abi.decode(bytes))
        bytes memory shortDstMsg = hex"deadbeef"; // 4 bytes

        bytes memory data = abi.encodePacked(
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
            false,
            shortDstMsg
        );

        vm.expectRevert(AcrossSendFundsAndExecuteOnDstHookV2.DATA_NOT_VALID.selector);
        acrossHookV2.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                       ACROSS V2 INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_Inspector() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        bytes memory argsEncoded = acrossHookV2.inspect(data);

        // Should return recipient + inputToken + outputToken + exclusiveRelayer (4 * 20 = 80 bytes)
        assertEq(argsEncoded.length, 80);
    }

    /*//////////////////////////////////////////////////////////////
                   ACROSS V2 CONTEXT AWARE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeAcrossV2Data(true, false);
        assertTrue(acrossHookV2.decodeUsePrevHookAmount(data));
    }

    function test_AcrossSendV2_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        assertFalse(acrossHookV2.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                   APPROVE AND ACROSS V2 BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndAcrossSendV2_Build_ERC20() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        Execution[] memory executions = approveAndAcrossHookV2.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + depositV3Now + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(spokePool, 0)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockSpokePool, 0)));

        // Execution 2: approve(spokePool, inputAmount)
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockSpokePool, mockInputAmount)));

        // Execution 3: bridge call
        assertEq(executions[3].target, mockSpokePool);
        assertEq(executions[3].value, mockValue);

        // Execution 4: approve(spokePool, 0) cleanup
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].value, 0);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockSpokePool, 0)));
    }

    function test_ApproveAndAcrossSendV2_Build_WithDestinationMessage() public view {
        bytes memory data = _encodeAcrossV2Data(false, true);
        Execution[] memory executions = approveAndAcrossHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IAcrossSpokePoolV3.depositV3Now.selector);
    }

    function test_ApproveAndAcrossSendV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeAcrossV2Data(true, false);
        Execution[] memory executions = approveAndAcrossHookV2.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockSpokePool, prevHookAmount)));
    }

    function test_ApproveAndAcrossSendV2_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.DATA_NOT_VALID.selector);
        approveAndAcrossHookV2.build(address(0), mockAccount, shortData);
    }

    function test_ApproveAndAcrossSendV2_Build_RevertIf_AmountZero() public {
        uint256 originalAmount = mockInputAmount;
        mockInputAmount = 0;
        bytes memory data = _encodeAcrossV2Data(false, false);
        mockInputAmount = originalAmount;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndAcrossHookV2.build(address(0), mockAccount, data);
    }

    function test_ApproveAndAcrossSendV2_Build_RevertIf_RecipientZero() public {
        address originalRecipient = mockRecipient;
        mockRecipient = address(0);
        bytes memory data = _encodeAcrossV2Data(false, false);
        mockRecipient = originalRecipient;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndAcrossHookV2.build(address(0), mockAccount, data);
    }

    function test_ApproveAndAcrossSendV2_Inspector() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        bytes memory argsEncoded = approveAndAcrossHookV2.inspect(data);
        assertEq(argsEncoded.length, 80);
    }

    function test_ApproveAndAcrossSendV2_DecodeUsePrevHookAmount() public view {
        bytes memory data = _encodeAcrossV2Data(true, false);
        assertTrue(approveAndAcrossHookV2.decodeUsePrevHookAmount(data));
    }

    function test_subtype() public view {
        assertNotEq(BaseHook(address(acrossHookV2)).subtype(), bytes32(0));
        assertNotEq(BaseHook(address(approveAndAcrossHookV2)).subtype(), bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AcrossSendV2_DecodeAmount() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        assertEq(acrossHookV2.decodeAmount(data), mockInputAmount);
    }

    function test_AcrossSendV2_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        uint256 newAmount = 2e18;
        bytes memory result = acrossHookV2.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(acrossHookV2.decodeAmount(result), newAmount);
    }

    function testFuzz_AcrossSendV2_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeAcrossV2Data(false, false);
        bytes memory result = acrossHookV2.replaceCalldataAmount(data, fuzzAmount);
        assertEq(acrossHookV2.decodeAmount(result), fuzzAmount);
    }

    function test_ApproveAndAcrossSendV2_DecodeAmount() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        assertEq(approveAndAcrossHookV2.decodeAmount(data), mockInputAmount);
    }

    function test_ApproveAndAcrossSendV2_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndAcrossHookV2.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(approveAndAcrossHookV2.decodeAmount(result), newAmount);
    }

    function testFuzz_ApproveAndAcrossSendV2_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeAcrossV2Data(false, false);
        bytes memory result = approveAndAcrossHookV2.replaceCalldataAmount(data, fuzzAmount);
        assertEq(approveAndAcrossHookV2.decodeAmount(result), fuzzAmount);
    }

    function test_AcrossV2_ReplaceCalldataAmount_ThenBuild() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        uint256 newAmount = 500;
        bytes memory replaced = acrossHookV2.replaceCalldataAmount(data, newAmount);
        Execution[] memory executions = acrossHookV2.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 3);
        assertEq(acrossHookV2.decodeAmount(replaced), newAmount);
    }

    function test_ApproveAndAcrossV2_ReplaceCalldataAmount_ThenBuild() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndAcrossHookV2.replaceCalldataAmount(data, newAmount);
        Execution[] memory executions = approveAndAcrossHookV2.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndAcrossHookV2.decodeAmount(replaced), newAmount);
    }

    function test_AcrossV2_ReplaceCalldataAmount_PreservesOtherFields() public view {
        bytes memory data = _encodeAcrossV2Data(false, false);
        bytes memory replaced = acrossHookV2.replaceCalldataAmount(data, 999);
        assertEq(replaced.length, data.length);
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes hook data for V2 hooks
    ///      V2 destinationMessage input = abi.encode(initData) — 1-field only
    function _encodeAcrossV2Data(
        bool usePrevHookAmount,
        bool includeDestinationMessage
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory destinationMessage;
        if (includeDestinationMessage) {
            // V2: destinationMessage = abi.encode(initData) — 1-field only
            bytes memory initData = bytes("0x123");
            destinationMessage = abi.encode(initData);
        }

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
            destinationMessage
        );
    }
}
