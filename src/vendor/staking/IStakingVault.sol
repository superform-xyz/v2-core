// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface IStakingVault {
    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);
}
