// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { SuperRbac } from "src/settings/SuperRbac.sol";
import { IStrategyOracle } from "src/interfaces/accounting/IStrategyOracle.sol";
import { Deposit4626Library } from "src/libraries/strategies/Deposit4626Library.sol";

/// @title Deposit4626StrategyOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit4626 Strategy
contract Deposit4626StrategyOracle is IStrategyOracle {
  /*//////////////////////////////////////////////////////////////
                              STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @notice The percentage of rewards to add to the price
  uint256 rewardPercentage;

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

  constructor(uint256 _rewardPercentage) {
    rewardPercentage = _rewardPercentage;
  }

  /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IStrategyOracle
  function deriveVaultStrategyPrice(
    address vault,
    uint256 amount
  ) external view returns (uint256 price) {
    uint256 estimatedRewards = Deposit4626Library.getEstimatedRewards(vault, amount);
    price = (estimatedRewards * rewardPercentage) / 10_000;
  }

  /// @inheritdoc IStrategyOracle
  function deriveVaultsStrategyPrice(
    address[] memory vaults,
    uint256[] memory amounts
  ) external view returns (uint256[] memory prices) {
    if (vaults.length != amounts.length) {
      revert INVALID_INPUT_LENGTH();
    }

    prices = new uint256[](vaults.length);
    for (uint256 i = 0; i < vaults.length; i++) {
      uint256 reward = deriveVaultStrategyPrice(vaults[i], amounts[i]);
      prices[i] = (reward * rewardPercentage) / 10_000;
    }
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IStrategyOracle
  function getVaultStrategyMetadata(
    address vault
  ) external view returns (bytes memory metadata) {
    return "0x0";
  }

  // ToDo: Implement this with the metadata library
  /// @inheritdoc IStrategyOracle
  function getVaultsStrategyMetadata(
    address[] memory vaults
  ) external view returns (bytes[] memory metadata) {
    return new bytes[](vaults.length);
  }

  /*//////////////////////////////////////////////////////////////
                      PERMISSIONED METHODS
  //////////////////////////////////////////////////////////////*/

  function setRewardPercentage(uint256 _rewardPercentage) external onlyStrategyOracleConfigurator {
    if (_rewardPercentage > 10_000) {
      revert INVALID_REWARD_PERCENTAGE();
    }
    rewardPercentage = _rewardPercentage;
  }
}
