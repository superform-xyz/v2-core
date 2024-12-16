// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IFluidLendingStakingRewards {
    function rewardsToken() external view returns (address);

    function getReward() external;
}
