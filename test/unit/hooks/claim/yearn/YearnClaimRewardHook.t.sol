// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { YearnClaimOneRewardHook } from "../../../../../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { IYearnStakingRewardsMulti } from "../../../../../src/vendor/yearn/IYearnStakingRewardsMulti.sol";

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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockYieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        mockYieldSource = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecute() public {
        _getTokens(mockRewardToken, mockAccount, mockAmount);

        vm.prank(mockAccount);
        hook.preExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.outAmount(), mockAmount);

        vm.prank(mockAccount);
        hook.postExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.outAmount(), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_CalldataDecoding() public view {
        // Create test addresses and data values
        address testYieldSource = address(0x1234567890123456789012345678901234567890);
        address testRewardToken = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        address testAccount = address(0x9876543210987654321098765432109876543210);

        // Encode data according to the NatSpec format:
        // bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
        // address yieldSource = BytesLib.toAddress(data, 4);
        // address rewardToken = BytesLib.toAddress(data, 24);
        // address account = BytesLib.toAddress(data, 44);
        bytes memory data = abi.encodePacked(
            bytes4(0), // placeholder
            testYieldSource, // yieldSource at offset 4
            testRewardToken, // rewardToken at offset 24
            testAccount // account at offset 44
        );

        // Verify the build function extracts yieldSource and rewardToken correctly
        Execution[] memory executions = hook.build(address(0), testAccount, data);

        // Check yieldSource is properly extracted
        // Validate it by checking that it's used as the target in the execution
        assertEq(executions[1].target, testYieldSource, "YieldSource address not correctly decoded");
        // Unlike the other hooks, Yearn also uses the rewardToken in its function call
        // We can't easily check the rewardToken directly, but we can verify the execution has
        // the proper calldata format with the encoded parameter
        bytes memory expectedCallData = abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (testRewardToken));

        // Verify that the calldata contains the rewardToken correctly
        assertEq(
            keccak256(executions[1].callData),
            keccak256(expectedCallData),
            "Calldata doesn't contain the correct rewardToken"
        );

        // Verify data length is as expected (4 + 20 + 20 + 20 = 64 bytes)
        assertEq(data.length, 64, "Calldata length is incorrect");
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes4(0), mockYieldSource, mockRewardToken, mockAccount);
    }
}
