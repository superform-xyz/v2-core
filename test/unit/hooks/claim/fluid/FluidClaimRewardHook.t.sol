// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { FluidClaimRewardHook } from "../../../../../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { IFluidLendingStakingRewards } from "../../../../../src/vendor/fluid/IFluidLendingStakingRewards.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, stakingRewards);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        stakingRewards = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecuteA() public {
        _getTokens(rewardToken, account, amount);

        vm.mockCall(
            stakingRewards,
            abi.encodeWithSelector(IFluidLendingStakingRewards.rewardsToken.selector),
            abi.encode(rewardToken)
        );

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(address(this)), amount);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_CalldataDecoding() public view {
        // Create test addresses and data values
        address testStakingRewards = address(0x1234567890123456789012345678901234567890);
        address testRewardToken = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        address testAccount = address(0x9876543210987654321098765432109876543210);

        // Encode data according to the NatSpec format:
        // bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
        // address stakingRewards = BytesLib.toAddress(data, 32);
        // address rewardToken = BytesLib.toAddress(data, 52);
        // address account = BytesLib.toAddress(data, 72);
        bytes memory data = abi.encodePacked(
            bytes32(0), // placeholder
            testStakingRewards, // stakingRewards at offset 4
            testRewardToken, // rewardToken at offset 24
            testAccount // account at offset 44
        );

        // Verify the build function extracts stakingRewards correctly
        Execution[] memory executions = hook.build(address(0), testAccount, data);

        // Check stakingRewards is properly extracted
        // Validate it by checking that it's used as the target in the execution
        assertEq(executions[1].target, testStakingRewards, "StakingRewards address not correctly decoded");
        // Verify data length is as expected (4 + 20 + 20 + 20 = 64 bytes)
        assertEq(data.length, 92, "Calldata length is incorrect");
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), stakingRewards, rewardToken, account);
    }
}
