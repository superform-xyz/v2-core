// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library CellarStakedVaultSharesLibrary {
  function getEstimatedRewards(
    address vault,
    address stakingProtocol,
    uint256 amountToDeposit
  ) internal view returns (uint256 rewards) {
    uint256 shares = IERC4626(vault).previewDeposit(amountToDeposit);
    //rewards = IStakingRewards(stakingProtocol).getRewardForDuration(shares);
  }
}
