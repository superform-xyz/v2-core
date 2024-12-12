// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library Deposit5115Library {
  /// @notice Get the estimated rewards for a deposit into a 5115 vault
  /// @param finalTarget The address of the final target vault
  /// @param tokenIn The address of the token to receive after redeeming
  /// @return reward The estimated rewards
  function getEstimatedRewards(
    address finalTarget,
    address tokenIn
  ) external view returns (uint256 reward) {
    reward = IStandardizedYield(finalTarget).previewRedeem(tokenIn, 1);
  }
}
