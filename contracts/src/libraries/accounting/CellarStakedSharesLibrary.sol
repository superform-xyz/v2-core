// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ICellarStaking } from "./external/ICellarStaking.sol";

/// @title CellarStakedSharesLibrary
/// @author Superform Labs
/// @notice Library for calculating rewards for staked shares in Cellar
library CellarStakedSharesLibrary {
  /// @notice Get the estimated rewards for staking shares received after a deposit into vault
  /// @param vault The address of the vault in which to deposit
  /// @param stakingProtocol The address of the staking protocol
  /// @param amountToDeposit The amount of underlying asset to deposit
  /// @return rewards The estimated rewards in staking rewards tokens
  function getEstimatedRewards(
    address vault,
    address stakingProtocol,
    uint256 amountToDeposit
  ) internal view returns (uint256 rewards) {
    uint256 shares = IERC4626(vault).previewDeposit(amountToDeposit);
    rewards = shares * ICellarStaking(stakingProtocol).rewardPerToken();
  }
}

