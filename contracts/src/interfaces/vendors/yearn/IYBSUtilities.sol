// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYBSUtilities {
    // Constants
    function PRECISION() external view returns (uint);
    function WEEKS_PER_YEAR() external view returns (uint);

    // Immutables
    function MAX_STAKE_GROWTH_WEEKS() external view returns (uint);
    function TOKEN() external view returns (IERC20);
    function YBS() external view returns (address);
    function REWARDS_DISTRIBUTOR() external view returns (address);

    // Calculation functions
    function getUserActiveBoostMultiplier(address _user) external view returns (uint256);
    function getUserProjectedBoostMultiplier(address _user) external view returns (uint256);
    function getUserActiveApr(
      address _account, 
      uint256 _stakeTokenPrice, 
      uint256 _rewardTokenPrice
    ) external view returns (uint256);
    function getUserProjectedApr(
      address _account, 
      uint256 _stakeTokenPrice, 
      uint256 _rewardTokenPrice
    ) external view returns (uint256);

    function getGlobalActiveBoostMultiplier() external view returns (uint);
    function getGlobalProjectedBoostMultiplier() external view returns (uint256);
    function getGlobalActiveApr(uint256 _stakeTokenPrice, uint256 _rewardTokenPrice) external view returns (uint256);
    function getGlobalProjectedApr(uint256 _stakeTokenPrice, uint256 _rewardTokenPrice) external view returns (uint256);

    function getGlobalMinMaxActiveApr(
      uint256 _stakeTokenPrice, 
    uint256 _rewardTokenPrice
    ) external view returns (uint256 min, uint256 max);
    function getGlobalMinMaxProjectedApr(
      uint256 _stakeTokenPrice, 
      uint256 _rewardTokenPrice
    ) external view returns (uint256 min, uint256 max);

    // Stake-related functions
    function getAccountStakeAmountAt(address _account, uint256 _week) external view returns (uint256);
    function getGlobalStakeAmountAt(uint256 _week) external view returns (uint256);

    // Reward functions
    function activeRewardAmount() external view returns (uint256);
    function projectedRewardAmount() external view returns (uint256);
    function weeklyRewardAmountAt(uint256 _week) external view returns (uint256);

    // Time function
    function getWeek() external view returns (uint);
}