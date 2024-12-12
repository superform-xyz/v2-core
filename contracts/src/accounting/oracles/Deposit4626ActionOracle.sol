// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { SuperRbac } from "src/settings/SuperRbac.sol";
import { IActionOracle } from "src/interfaces/accounting/IActionOracle.sol";
import { Deposit4626Library } from "src/libraries/strategies/Deposit4626Library.sol";

/// @title Deposit4626ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit4626 Action
contract Deposit4626ActionOracle is IActionOracle {
  /*//////////////////////////////////////////////////////////////
                             MODIFIERS
  //////////////////////////////////////////////////////////////*/

  modifier onlyStrategyOracleConfigurator() {
    if (!SuperRbac.hasRole(msg.sender, SuperRbac.STRATEGY_ORACLE_CONFIGURATOR)) {
      revert NotStrategyOracleConfigurator();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor() {}

  /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IStrategyOracle
  function deriveVaultStrategyPricePerShare(
    address finalTarget
  ) external view returns (uint256 price) {
    uint256 estimatedRewards = Deposit4626Library.getEstimatedRewards(vault);
    price = (estimatedRewards * rewardPercentage) / 10_000;
  }

  /// @inheritdoc IStrategyOracle
  function deriveVaultsStrategyPricePerShare(
    address[] memory finalTargets
  ) external view returns (uint256[] memory prices) {
    if (finalTargets.length != amounts.length) {
      revert INVALID_INPUT_LENGTH();
    }

    prices = new uint256[](finalTargets.length);
    for (uint256 i = 0; i < finalTargets.length; i++) {
      uint256 reward = deriveVaultStrategyPrice(finalTargets[i]);
      prices[i] = (reward * rewardPercentage) / 10_000;
    }
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IStrategyOracle
  function getVaultStrategyMetadata(
    address finalTarget
  ) external view returns (bytes memory metadata) {
    return "0x0";
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IStrategyOracle
  function getVaultsStrategyMetadata(
    address[] memory finalTargets
  ) external view returns (bytes[] memory metadata) {
    return new bytes[](finalTargets.length);
  }
}
