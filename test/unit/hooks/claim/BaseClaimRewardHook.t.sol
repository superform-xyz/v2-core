// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


import { Helpers } from "../../../utils/Helpers.sol";
import { MockClaimHook } from "../../../mocks/MockClaimHook.sol";
import { BaseClaimRewardHook } from "../../../../src/hooks/claim/BaseClaimRewardHook.sol";

contract BaseClaimRewardHookTest is Helpers {

    MockClaimHook public hook;

    function setUp() public {
        hook = new MockClaimHook();
    }

    function test_BalanceForInvalidToken() public {
        bytes memory data = _encodeData(address(0));
        vm.expectRevert(BaseClaimRewardHook.REWARD_TOKEN_ZERO_ADDRESS.selector);
        hook.getBalanceMock(data, address(0));
    }

     function _encodeData(address rewardToken) internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), address(this), rewardToken, address(this));
    }
}