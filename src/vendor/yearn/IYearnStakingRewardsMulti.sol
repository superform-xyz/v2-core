// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface IYearnStakingRewardsMulti {
    /// @notice Claim any (and all) earned reward tokens.
    /// @dev Can claim rewards even if no tokens still staked.
    function getReward() external;

    /// @notice Claim any one earned reward token.
    /// @dev Can claim rewards even if no tokens still staked.
    /// @param _rewardsToken Address of the rewards token to claim.
    function getOneReward(address _rewardsToken) external;
}
