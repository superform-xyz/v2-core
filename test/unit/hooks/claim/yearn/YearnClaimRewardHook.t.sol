// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {YearnClaimOneRewardHook} from "../../../../../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import {BaseHook} from "../../../../../src/core/hooks/BaseHook.sol";
import {Helpers} from "../../../../utils/Helpers.sol";

contract YearnClaimOneRewardHookTest is Helpers {
    YearnClaimOneRewardHook public hook;
    address public mockYieldSource;
    address public mockRewardToken;
    address public mockAccount;
    uint256 public mockAmount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        mockRewardToken = address(_mockToken);

        mockYieldSource = makeAddr("yieldSource");
        mockAccount = makeAddr("account");
        mockAmount = 1000;

        hook = new YearnClaimOneRewardHook();
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
        bytes memory newData = hook.replaceCalldataAmount(data, mockAmount);
        assertEq(newData, data);
    }

    function test_decodeUsePrevHookAmount() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeUsePrevHookAmount(data), false);
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

    function test_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(mockYieldSource, mockRewardToken, mockAccount);
    }
}
