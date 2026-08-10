// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    RelaySendFundsAndExecuteOnDstHook
} from "../../../../src/hooks/bridges/relay/RelaySendFundsAndExecuteOnDstHook.sol";
import {
    ApproveAndRelaySendFundsAndExecuteOnDstHook
} from "../../../../src/hooks/bridges/relay/ApproveAndRelaySendFundsAndExecuteOnDstHook.sol";
import { IRelayDepository } from "../../../../src/vendor/bridges/relay/IRelayDepository.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { Helpers } from "../../../utils/Helpers.sol";

contract RelayHooks is Helpers {
    RelaySendFundsAndExecuteOnDstHook public relayHook;
    ApproveAndRelaySendFundsAndExecuteOnDstHook public approveAndRelayHook;

    address public mockAccount;
    address public mockPrevHook;
    address public mockDepository;
    address public mockToken;

    uint256 public mockAmount;
    bytes32 public mockDepositId;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockDepository = makeAddr("relayDepository");
        mockToken = makeAddr("token");

        mockAmount = 1000e6; // 1000 USDC
        mockDepositId = keccak256("relay_order_id");

        relayHook = new RelaySendFundsAndExecuteOnDstHook(mockDepository);
        approveAndRelayHook = new ApproveAndRelaySendFundsAndExecuteOnDstHook(mockDepository);
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_Constructor() public view {
        assertEq(uint256(relayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(relayHook.RELAY_DEPOSITORY(), mockDepository);
    }

    function test_RelaySend_Constructor_RevertIf_ZeroDepository() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new RelaySendFundsAndExecuteOnDstHook(address(0));
    }

    function test_ApproveAndRelaySend_Constructor() public view {
        assertEq(uint256(approveAndRelayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(approveAndRelayHook.RELAY_DEPOSITORY(), mockDepository);
    }

    function test_ApproveAndRelaySend_Constructor_RevertIf_ZeroDepository() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndRelaySendFundsAndExecuteOnDstHook(address(0));
    }

    function test_NameAndDescription() public view {
        assertGt(bytes(relayHook.name()).length, 0);
        assertGt(bytes(relayHook.description()).length, 0);
        assertGt(bytes(approveAndRelayHook.name()).length, 0);
        assertGt(bytes(approveAndRelayHook.description()).length, 0);
    }

    function test_subtype() public view {
        assertEq(BaseHook(address(relayHook)).subtype(), HookSubTypes.BRIDGE);
        assertEq(BaseHook(address(approveAndRelayHook)).subtype(), HookSubTypes.BRIDGE);
    }

    /*//////////////////////////////////////////////////////////////
                         RELAY SEND BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_Build_ERC20() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        Execution[] memory executions = relayHook.build(address(0), mockAccount, data);

        // preExecute + depositErc20 + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockDepository);
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IRelayDepository.depositErc20, (mockAccount, mockToken, mockAmount, mockDepositId))
        );
    }

    function test_RelaySend_Build_Native() public view {
        uint256 nativeAmount = 1 ether;
        bytes memory data = _encodeRelayData(address(0), nativeAmount, mockDepositId, false);
        Execution[] memory executions = relayHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockDepository);
        assertEq(executions[1].value, nativeAmount);
        assertEq(executions[1].callData, abi.encodeCall(IRelayDepository.depositNative, (mockAccount, mockDepositId)));
    }

    function test_RelaySend_Build_DepositorIsAlwaysAccount() public {
        // depositor must be the account even if a different address builds/inspects
        address otherAccount = makeAddr("otherAccount");
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        Execution[] memory executions = relayHook.build(address(0), otherAccount, data);

        assertEq(
            executions[1].callData,
            abi.encodeCall(IRelayDepository.depositErc20, (otherAccount, mockToken, mockAmount, mockDepositId))
        );
    }

    /*//////////////////////////////////////////////////////////////
                       RELAY PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, true);
        Execution[] memory executions = relayHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IRelayDepository.depositErc20, (mockAccount, mockToken, prevHookAmount, mockDepositId))
        );
    }

    function test_RelaySend_Build_WithPrevHookAmount_NativeValue() public {
        uint256 prevHookAmount = 2 ether;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, address(0)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeRelayData(address(0), 1 ether, mockDepositId, true);
        Execution[] memory executions = relayHook.build(mockPrevHook, mockAccount, data);

        // native path: msg.value must follow the chained amount
        assertEq(executions[1].value, prevHookAmount);
        assertEq(executions[1].callData, abi.encodeCall(IRelayDepository.depositNative, (mockAccount, mockDepositId)));
    }

    function test_RelaySend_Build_RevertIf_PrevHookAmountZero() public {
        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockToken));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        vm.mockCall(mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(0));

        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, true);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        relayHook.build(mockPrevHook, mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                       RELAY REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(RelaySendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        relayHook.build(address(0), mockAccount, shortData);
    }

    function test_RelaySend_Build_RevertIf_AmountZero() public {
        bytes memory data = _encodeRelayData(mockToken, 0, mockDepositId, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        relayHook.build(address(0), mockAccount, data);
    }

    function test_RelaySend_Build_RevertIf_DepositIdZero() public {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, bytes32(0), false);

        vm.expectRevert(RelaySendFundsAndExecuteOnDstHook.ID_NOT_VALID.selector);
        relayHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                   APPROVE AND RELAY BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndRelaySend_Build_ERC20() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        Execution[] memory executions = approveAndRelayHook.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + depositErc20 + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(depository, 0)
        assertEq(executions[1].target, mockToken);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockDepository, 0)));

        // Execution 2: approve(depository, amount)
        assertEq(executions[2].target, mockToken);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockDepository, mockAmount)));

        // Execution 3: deposit
        assertEq(executions[3].target, mockDepository);
        assertEq(executions[3].value, 0);
        assertEq(
            executions[3].callData,
            abi.encodeCall(IRelayDepository.depositErc20, (mockAccount, mockToken, mockAmount, mockDepositId))
        );

        // Execution 4: approve(depository, 0) cleanup
        assertEq(executions[4].target, mockToken);
        assertEq(executions[4].value, 0);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockDepository, 0)));
    }

    function test_ApproveAndRelaySend_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, true);
        Execution[] memory executions = approveAndRelayHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval and deposit should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockDepository, prevHookAmount)));
        assertEq(
            executions[3].callData,
            abi.encodeCall(IRelayDepository.depositErc20, (mockAccount, mockToken, prevHookAmount, mockDepositId))
        );
    }

    function test_ApproveAndRelaySend_Build_RevertIf_NativeToken() public {
        bytes memory data = _encodeRelayData(address(0), mockAmount, mockDepositId, false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndRelayHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndRelaySend_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(ApproveAndRelaySendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        approveAndRelayHook.build(address(0), mockAccount, shortData);
    }

    function test_ApproveAndRelaySend_Build_RevertIf_AmountZero() public {
        bytes memory data = _encodeRelayData(mockToken, 0, mockDepositId, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndRelayHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndRelaySend_Build_RevertIf_DepositIdZero() public {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, bytes32(0), false);

        vm.expectRevert(ApproveAndRelaySendFundsAndExecuteOnDstHook.ID_NOT_VALID.selector);
        approveAndRelayHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                       INSPECTOR / CONTEXT AWARE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_Inspector() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        bytes memory argsEncoded = relayHook.inspect(data);

        // Should return token only (20 bytes)
        assertEq(argsEncoded.length, 20);
        assertEq(address(bytes20(argsEncoded)), mockToken);
    }

    function test_ApproveAndRelaySend_Inspector() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        bytes memory argsEncoded = approveAndRelayHook.inspect(data);
        assertEq(argsEncoded.length, 20);
        assertEq(address(bytes20(argsEncoded)), mockToken);
    }

    function test_RelaySend_DecodeUsePrevHookAmount() public view {
        assertTrue(relayHook.decodeUsePrevHookAmount(_encodeRelayData(mockToken, mockAmount, mockDepositId, true)));
        assertFalse(relayHook.decodeUsePrevHookAmount(_encodeRelayData(mockToken, mockAmount, mockDepositId, false)));
    }

    function test_ApproveAndRelaySend_DecodeUsePrevHookAmount() public view {
        assertTrue(
            approveAndRelayHook.decodeUsePrevHookAmount(_encodeRelayData(mockToken, mockAmount, mockDepositId, true))
        );
        assertFalse(
            approveAndRelayHook.decodeUsePrevHookAmount(_encodeRelayData(mockToken, mockAmount, mockDepositId, false))
        );
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RelaySend_DecodeAmounts() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        assertEq(relayHook.decodeAmounts(data)[0], mockAmount);
    }

    function test_RelaySend_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        uint256 newAmount = 2e18;
        bytes memory result = relayHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(relayHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_RelaySend_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        bytes memory result = relayHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(relayHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndRelaySend_DecodeAmounts() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        assertEq(approveAndRelayHook.decodeAmounts(data)[0], mockAmount);
    }

    function testFuzz_ApproveAndRelaySend_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        bytes memory result = approveAndRelayHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndRelayHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_RelaySend_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        uint256 newAmount = 500;
        bytes memory replaced = relayHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = relayHook.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 3);
        assertEq(relayHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_RelaySend_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _encodeRelayData(mockToken, mockAmount, mockDepositId, false);
        bytes memory replaced = relayHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // amount is at AMOUNT_POSITION = 72 (uint256 = 32 bytes, ends at byte 103)
        for (uint256 i = 0; i < 72; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 104; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes hook data for the Relay hooks:
    ///      52-byte header + token (52) + amount (72) + depositId (104) + usePrevHookAmount (136)
    function _encodeRelayData(
        address token,
        uint256 amount,
        bytes32 depositId,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder header
            token,
            amount,
            depositId,
            usePrevHookAmount
        );
    }
}
