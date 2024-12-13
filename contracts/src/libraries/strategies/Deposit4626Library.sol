// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Deposit4626Library {
    function getEstimatedRewards(address vault, uint256 amountToDeposit) external view returns (uint256 reward) {
        reward = IERC4626(vault).previewDeposit(amountToDeposit);
    }
}
