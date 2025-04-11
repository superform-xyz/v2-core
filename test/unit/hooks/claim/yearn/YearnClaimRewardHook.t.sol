// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { YearnClaimOneRewardHook } from "../../../../../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { ISuperHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { console2 } from "forge-std/console2.sol";

contract YearnClaimOneRewardHookTest is BaseTest {
    YearnClaimOneRewardHook public hook;
    address public mockYieldSource;
    address public mockRewardToken;
    address public mockAccount;
    uint256 public mockAmount;

    function setUp() public override {
        super.setUp();

        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        mockRewardToken = address(_mockToken);

        mockYieldSource = makeAddr("yieldSource");
        mockAccount = makeAddr("account");
        mockAmount = 1000;

        hook = new YearnClaimOneRewardHook(address(this));
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = hook.build(address(0), mockAccount, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, mockYieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        mockYieldSource = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecute() public {
        _getTokens(mockRewardToken, mockAccount, mockAmount);

        hook.preExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.outAmount(), mockAmount);

        hook.postExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.outAmount(), 0);
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(mockYieldSource, mockRewardToken, mockAccount);
    }
}
