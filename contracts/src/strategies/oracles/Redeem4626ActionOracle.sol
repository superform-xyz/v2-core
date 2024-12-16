// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { SuperRbac } from "../../settings/SuperRbac.sol";
import { IActionOracle } from "../../interfaces/strategies/IActionOracle.sol";
import { Redeem4626Library } from "../../libraries/strategies/Redeem4626Library.sol";

/// @title Redeem4626ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Redeem Action in 4626 Vaults
contract Redeem4626ActionOracle is IActionOracle {
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
    price = Redeem4626Library.getPricePerShare(finalTarget);
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
