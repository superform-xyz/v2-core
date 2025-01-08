// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { FluidLendingStakingRewards } from "./external/FluidLendingStakingRewards.sol";

/// @title CellarStakedSharesLibrary
/// @author Superform Labs
/// @notice Library for calculating rewards for staking vault shares in Fluid Lending
library FluidLendingStakedSharedLibrary {
  /// @notice Get the estimated rewards for staking shares received after a deposit into vault
  /// @param vault The address of the vault in which to deposit
  /// @param stakingProtocol The address of the staking protocol
  /// @param amountToDeposit The amount of underlying asset to deposit
  /// @return rewards The estimated rewards in staking rewards tokens
  function getEstimatedRewards(address vault, address stakingProtocol, uint256 amountToDeposit) external view returns (uint256 rewards) {
    uint256 shares = IERC4626(vault).convertToShares(amountToDeposit);
    rewards = shares * FluidLendingStakingRewards(stakingProtocol).rewardPerToken();
  }
}

