// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {MockERC20} from "./MockERC20.sol";

contract MockStakingRewards {
    MockERC20 public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = MockERC20(_rewardToken);
    }

    function getReward() public {
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }
}