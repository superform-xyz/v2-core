// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

struct Info {
    uint40 finished;
    uint32 duration;
    uint184 reward;
    uint256 balance;
}

interface IGearboxFarmingPool {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DistributorChanged(address oldDistributor, address newDistributor);
    event RewardUpdated(uint256 reward, uint256 duration);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function balanceOf(address account) external view returns (uint256);
    function distributor() external view returns (address);
    function farmInfo() external view returns (Info memory);
    function farmed(address account) external view returns (uint256);
    function stakingToken() external view returns (address);
    function rewardsToken() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claim() external;
    function exit() external;
}
