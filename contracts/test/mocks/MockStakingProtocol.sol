// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockStakingProtocol {
    function rewardPerToken() external pure returns (uint256) {
        return 1e18;
    }

    function activeRewardAmount() external pure returns (uint256) {
        return 1e18;
    }
}
