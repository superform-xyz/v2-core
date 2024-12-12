// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Looped4626DepositLibrary {
  /// @notice Error thrown when the asset of the vaults is not the same
  error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

  /// @notice Get the estimated rewards for a single vault over a number of loops
  /// @param vault The address of the vault
  /// @param loops The number of loops
  /// @param amountPerLoop The amount per loop
  /// @return rewards The estimated rewards
  function getEstimatedRewards(
    address vault,
    uint256 loops,
    uint256 amountPerLoop
  ) internal view returns (uint256 rewards) {
    rewards = IERC4626(vault).previewDeposit(amountPerLoop);
    rewards *= loops;
  }

  /// @notice Get the estimated rewards for multiple vaults
  /// @param vaults The addresses of the vaults
  /// @param underlyingAsset The address of the underlying asset
  /// @param amountPerLoop The amount per loop
  /// @param loops The number of loops
  /// @return rewards The estimated rewards per vault
  function getEstimatedRewardsMultiVault(
    address[] memory vaults,
    address underlyingAsset,
    uint256 amountPerLoop,
    uint256 loops
  ) internal view returns (uint256[] memory rewards) {
    rewards = new uint256[](vaults.length);
    for (uint256 i = 0; i < vaults.length; ++i) {
      if (IERC4626(vaults[i]).asset() != underlyingAsset) revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
      rewards[i] = getEstimatedRewards(vaults[i], loops, amountPerLoop);
    }
  }
}
