// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Looped4626DepositLibrary {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

  /// @notice Get the estimated rewards for a single vault over a number of loops
  /// @param finalTarget The address of the final target
  /// @param loops The number of loops
  /// @return rewards The estimated rewards
  function getPricePerShare(
    address finalTarget,
    uint256 loops
  ) internal view returns (uint256 rewards) {
    uint256 decimals = IERC4626(finalTarget).decimals();
    rewards = IERC4626(finalTarget).previewRedeem(10 ** decimals);
    rewards *= loops;
  }

  /// @notice Get the estimated rewards for multiple vaults
  /// @param finalTargets The addresses of the final targets
  /// @param underlyingAsset The address of the underlying asset
  /// @param loops The number of loops
  /// @return rewards The estimated rewards per vault
  function getPricePerShareMultiVault(
    address[] memory finalTargets,
    address underlyingAsset,
    uint256 loops
  ) internal view returns (uint256[] memory rewards) {
    rewards = new uint256[](finalTargets.length);
    for (uint256 i = 0; i < finalTargets.length; ++i) {
      if (IERC4626(finalTargets[i]).asset() != underlyingAsset) revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
      rewards[i] = getPricePerShare(finalTargets[i], loops);
    }
  }
}