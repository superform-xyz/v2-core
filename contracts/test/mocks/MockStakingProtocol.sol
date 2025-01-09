// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockStakingProtocol {
    function rewardPerToken() external view returns (uint256) {
        return 1e18;
    }

    function activeRewardAmount() external view returns (uint256) {
        return 1e18;
    }
}
