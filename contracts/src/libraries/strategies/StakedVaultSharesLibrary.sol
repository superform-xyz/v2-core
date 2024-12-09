// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISynthetixStakingRewards } from "@synthetixio/synthetix-staking-rewards/contracts/interfaces/ISynthetixStakingRewards.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library SynthetixStakedVaultSharesLibrary {
  function getEstimatedRewards(
    address vault,
    address stakingProtocol,
    uint256 amountToDeposit
  ) internal view returns (uint256 rewards) {
    uint256 shares = IERC4626(vault).previewDeposit(amountToDeposit);
    rewards = ISynthetixStakingRewards(stakingProtocol).getRewardForDuration(shares);
  }
}
