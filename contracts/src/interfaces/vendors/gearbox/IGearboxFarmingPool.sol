// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IGearboxFarmingPool {
    event DistributorChanged(address oldDistributor, address newDistributor);
    event RewardUpdated(uint256 reward, uint256 duration);

    // View functions
    function distributor() external view returns (address);
    //function farmInfo() external view returns(FarmAccounting.Info memory);
    function farmed(address account) external view returns (uint256);

    // User functions
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claim() external;
    function exit() external;

    // Owner functions
    function setDistributor(address distributor_) external;

    // Distributor functions
    function startFarming(uint256 amount, uint256 period) external;
    function rescueFunds(IERC20 token, uint256 amount) external;
}
