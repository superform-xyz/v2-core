// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IFluidLendingStakingRewards {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function rewardsToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);    

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function getReward() external;
}
