// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockStakingProtocol {
    address public stakingToken;
    address public asset;
    address public TOKEN;

    constructor(address _stakingToken) {
        stakingToken = _stakingToken; //for Fluid
        asset = _stakingToken; //for Yearn
        TOKEN = _stakingToken;
    }

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
