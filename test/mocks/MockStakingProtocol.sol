// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockStakingProtocol {
    /// @notice Mock the rewardPerToken function
    /// @return rewardPerToken The reward per token
    /// @return latestTimestamp The latest timestamp
    function rewardPerToken() external view returns (uint256, uint256) {
        return (1e18, block.timestamp);
    }

    /// @notice Mock the activeRewardAmount function
    /// @return activeRewardAmount The active reward amount
    function activeRewardAmount() external pure returns (uint256) {
        return 1e18;
    }
}
