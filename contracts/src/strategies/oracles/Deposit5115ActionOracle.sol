// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IActionOracle } from "../../interfaces/strategies/IActionOracle.sol";
import { Deposit5115Library } from "../../libraries/strategies/Deposit5115Library.sol";

/// @title Deposit5115ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit Action in 5115 Vaults
contract Deposit5115ActionOracle is IActionOracle {
  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor() {}

  /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IActionOracle
  function getStrategyPrice(
    address finalTarget
  ) public view returns (uint256 price) {
    price = Deposit5115Library.getPricePerShare(finalTarget);
  }

  /// @inheritdoc IActionOracle
  function getStrategyPrices(
    address[] memory finalTargets
  ) external view returns (uint256[] memory prices) {
    prices = new uint256[](finalTargets.length);
    for (uint256 i = 0; i < finalTargets.length; i++) {
      prices[i] = getStrategyPrice(finalTargets[i]);
    }
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IActionOracle
  function getVaultStrategyMetadata(
    address finalTarget
  ) external view returns (bytes memory metadata) {
    return "0x0";
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IActionOracle
  function getVaultsStrategyMetadata(
    address[] memory finalTargets
  ) external view returns (bytes[] memory metadata) {
    return new bytes[](finalTargets.length);
  }
}
