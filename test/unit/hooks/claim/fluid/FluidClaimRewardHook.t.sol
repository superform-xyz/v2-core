// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { FluidClaimRewardHook } from "../../../../../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract FluidClaimRewardHookTest is Helpers {
    FluidClaimRewardHook public hook;
    address public stakingRewards;
    address public rewardToken;
    address public account;
    uint256 public amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        rewardToken = address(_mockToken);

        stakingRewards = makeAddr("stakingRewards");
        account = makeAddr("account");
        amount = 1000;

        hook = new FluidClaimRewardHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_decodeAmount() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeAmount(data), 0);
    }

    function test_replaceCalldataAmount() public view {
        bytes memory data = _encodeData();
        bytes memory newData = hook.replaceCalldataAmount(data, amount);
        assertEq(newData, data);
    }

    function test_decodeUsePrevHookAmount() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeUsePrevHookAmount(data), false);
    }

    function test_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, stakingRewards);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        stakingRewards = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecute() public {
        _getTokens(rewardToken, account, amount);

        hook.preExecute(address(0), account, _encodeData());
        assertEq(hook.outAmount(), amount);

        hook.postExecute(address(0), account, _encodeData());
        assertEq(hook.outAmount(), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(stakingRewards, rewardToken, account);
    }
}
