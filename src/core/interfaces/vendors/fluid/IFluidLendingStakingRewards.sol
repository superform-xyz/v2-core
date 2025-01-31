// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IFluidLendingStakingRewards {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);    

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function getReward() external;
    function stakeWithPermit(
        uint256 amount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
}
