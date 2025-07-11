// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { GearboxClaimRewardHook } from "../../../../../src/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { IGearboxFarmingPool } from "../../../../../src/vendor/gearbox/IGearboxFarmingPool.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract GearboxClaimRewardHookTest is Helpers {
    using BytesLib for bytes;

    GearboxClaimRewardHook public hook;
    address public mockFarmingPool;
    address public mockRewardToken;
    address public mockAccount;
    uint256 public mockAmount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        mockRewardToken = address(_mockToken);

        mockFarmingPool = makeAddr("farmingPool");
        mockAccount = makeAddr("account");
        mockAmount = 1000;

        hook = new GearboxClaimRewardHook();
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
        assertEq(executions[1].target, mockFarmingPool);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        mockFarmingPool = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecute() public {
        _getTokens(mockRewardToken, mockAccount, mockAmount);

        vm.mockCall(
            mockFarmingPool,
            abi.encodeWithSelector(IGearboxFarmingPool.rewardsToken.selector),
            abi.encode(mockRewardToken)
        );

        vm.prank(mockAccount);
        hook.preExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.getOutAmount(address(this)), mockAmount);

        vm.prank(mockAccount);
        hook.postExecute(address(0), mockAccount, _encodeData());
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        assertEq(BytesLib.toAddress(argsEncoded, 0), mockFarmingPool);
        assertEq(BytesLib.toAddress(argsEncoded, 20), mockRewardToken);
    }

    function test_CalldataDecoding() public view {
        // Create test addresses and data values
        address testFarmingPool = address(0x1234567890123456789012345678901234567890);
        address testRewardToken = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        address testAccount = address(0x9876543210987654321098765432109876543210);

        // Encode data according to the NatSpec format:
        // bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
        // address farmingPool = BytesLib.toAddress(data, 32);
        // address rewardToken = BytesLib.toAddress(data, 52);
        // address account = BytesLib.toAddress(data, 72);
        bytes memory data = abi.encodePacked(
            bytes32(0), // placeholder
            testFarmingPool, // farmingPool at offset 32
            testRewardToken, // rewardToken at offset 52
            testAccount // account at offset 72
        );

        // Verify the build function extracts farmingPool correctly
        Execution[] memory executions = hook.build(address(0), testAccount, data);

        // Check farmingPool is properly extracted
        // Validate it by checking that it's used as the target in the execution
        assertEq(executions[1].target, testFarmingPool, "FarmingPool address not correctly decoded");
        // Verify data length is as expected (4 + 20 + 20 + 20 = 64 bytes)
        assertEq(data.length, 92, "Calldata length is incorrect");
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), mockFarmingPool, mockRewardToken, mockAccount);
    }
}
