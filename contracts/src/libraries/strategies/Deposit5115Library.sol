// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library Deposit5115Library {
  /// @notice Get the estimated rewards for a deposit into a 5115 vault
  /// @param finalTarget The address of the final target vault
  /// @param tokenIn The address of the token to receive after redeeming
  /// @return reward The estimated rewards
  function getPricePerShare(
    address finalTarget,
    address tokenIn
  ) internal view returns (uint256 reward) {
    (,, uint256 decimals) = IStandardizedYield(finalTarget).assetInfo();
    reward = IStandardizedYield(finalTarget).previewRedeem(
      tokenIn,
      10 ** decimals
    );
  }
}
