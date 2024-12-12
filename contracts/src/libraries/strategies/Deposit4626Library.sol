// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Deposit4626Library {
  /// @notice Error thrown when the asset of the vaults is not the same
  error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

  /// @notice Gets the estimated rewards for a deposit
  /// @param finalTarget The final target vault to deposit into
  /// @return reward The estimated rewards
  function getEstimatedRewards(
    address finalTarget
  ) external view returns (uint256 reward) {
    uint256 decimals = IERC4626(finalTarget).decimals();
    reward = IERC4626(finalTarget).previewRedeem(10 ** decimals);
  }

  /// @notice Get the estimated rewards for a deposit into multiple vaults
  /// @param finalTargets The addresses of the final targets
  /// @return rewards The estimated rewards
  function getEstimatedRewardsMultiVault(
    address[] memory finalTargets,
    address underlyingAsset
  ) external view returns (uint256[] memory rewards) {
    rewards = new uint256[](finalTargets.length);
    for (uint256 i = 0; i < finalTargets.length; ++i) {
      if (IERC4626(finalTargets[i]).asset() != underlyingAsset) {
        revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
      }
      rewards[i] = getEstimatedRewards(finalTargets[i]);
    }
  }
}
