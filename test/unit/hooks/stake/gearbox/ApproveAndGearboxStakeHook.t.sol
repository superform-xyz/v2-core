// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndGearboxStakeHook } from "../../../../../src/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract ApproveAndGearboxStakeHookTest is Helpers {
    using BytesLib for bytes;

    ApproveAndGearboxStakeHook public hook;

    bytes32 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        token = address(_mockToken);

        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = makeAddr("yieldSource");
        amount = 1000;

        hook = new ApproveAndGearboxStakeHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        _assertExecutions(executions);

        data = _encodeData(false);
        executions = hook.build(address(0), address(this), data);
        _assertExecutions(executions);
    }

    function test_Build_RevertIf_AddressZero() public {
        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));

        yieldSource = address(this);
        token = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        _assertExecutions(executions);
    }

    function test_PreAndPostExecute() public {
        yieldSource = token; // to allow balanceOf call
        bytes memory data = _encodeData(false);

        _getTokens(token, address(this), amount);

        hook.preExecute(address(0), address(this), data);
        assertEq(hook.getOutAmount(address(this)), amount);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(yieldSource, BytesLib.toAddress(argsEncoded, 0));
        assertEq(token, BytesLib.toAddress(argsEncoded, 20));

        assertGt(argsEncoded.length, 0);
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory data = _encodeData(false);
        assertEq(hook.decodeUsePrevHookAmount(data), false);

        data = _encodeData(true);
        assertEq(hook.decodeUsePrevHookAmount(data), true);
    }

    function _assertExecutions(Execution[] memory executions) internal view {
        assertEq(executions.length, 6);
        assertEq(executions[1].target, token);
        assertEq(executions[2].target, token);
        assertEq(executions[3].target, yieldSource);
        assertEq(executions[4].target, token);

        assertEq(executions[1].value, 0);
        assertEq(executions[2].value, 0);
        assertEq(executions[3].value, 0);
        assertEq(executions[4].value, 0);

        assertGt(executions[1].callData.length, 0);
        assertGt(executions[2].callData.length, 0);
        assertGt(executions[3].callData.length, 0);
        assertGt(executions[4].callData.length, 0);
    }

    function _encodeData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHook);
    }
}
