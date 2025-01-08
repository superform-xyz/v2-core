// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IGenericStakingProtocol {
  function stakingToken() external view returns (ERC20);
  function rewardsToken() external view returns (ERC20);

  /// @notice This function is used to calculate the rewards for a given amount of staked tokens
  /// @dev Call this function if the staking protocol has a flexible duration
  function rewardPerToken() external view returns (uint256);

  /// @notice This function is used to calculate the rewards for a given amount of staked tokens
  /// @dev Call this function if the staking protocol has a fixed duration
  function getRewardForDuration() external view returns (uint256);
}
