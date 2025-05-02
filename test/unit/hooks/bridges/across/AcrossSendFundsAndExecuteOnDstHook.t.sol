// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../../../../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { ISuperHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { IAcrossSpokePoolV3 } from "../../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";

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

contract AcrossSendFundsAndExecuteOnDstHookTest is BaseTest {
    AcrossSendFundsAndExecuteOnDstHook public hook;
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

    function setUp() public override {
        super.setUp();
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
        hook = new AcrossSendFundsAndExecuteOnDstHook(mockSpokePool, address(mockSignatureStorage));

        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), uint256(1));
    }

    function test_Constructor() public view {
        assertEq(address(hook.spokePoolV3()), mockSpokePool);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHook(address(0), address(this));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AcrossSendFundsAndExecuteOnDstHook(address(this), address(0));
    }

    function test_Build() public {
        bytes memory data = _encodeData(false);

        Execution[] memory executions = hook.build(address(0), mockAccount, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, mockSpokePool);
        assertEq(executions[0].value, mockValue);

        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), uint256(1), sigData);
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

        assertEq(executions[0].callData, expectedCallData);
    }

    function test_Build_RevertIf_AmountNotValid() public {
        mockInputAmount = 0;
        bytes memory data = _encodeData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), mockAccount, data);
    }

    function test_Build_RevertIf_RecipientNotValid() public {
        mockRecipient = address(0);
        bytes memory data = _encodeData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), mockAccount, data);
    }

    function test_Build_WithPrevHookAmountXQ() public {
        uint256 prevHookAmount = 2000;

        vm.mockCall(
            mockSpokePool,
            abi.encodeWithSelector(IAcrossSpokePoolV3.wrappedNativeToken.selector),
            abi.encode(mockInputToken)
        );

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);

        Execution[] memory executions = hook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 1);


        bytes memory sigData = mockSignatureStorage.retrieveSignatureData(address(0));
        mockMessage = abi.encode(bytes("0x123"), bytes("0x123"), address(this), uint256(1), sigData);
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



        assertEq(executions[0].callData, expectedCallData);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        mockInputAmount = 0;
        bytes memory data = _encodeData(false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), mockAccount, data);
    }

    function test_Build_RevertIf_ZeroRecipient() public {
        mockRecipient = address(0);
        bytes memory data = _encodeData(false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), mockAccount, data);
    }

    function test_PreExecute() public {
        hook.preExecute(address(0), address(0), "");
    }

    function test_PostExecute() public {
        hook.postExecute(address(0), address(0), "");
    }

    function _encodeData(bool usePrevHookAmount) internal view returns (bytes memory) {
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

    function _decodeBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        return data[offset] != 0;
    }
}
