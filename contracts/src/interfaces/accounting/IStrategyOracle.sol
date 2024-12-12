// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/// @title IStrategyOracle
/// @author Superform Labs
/// @notice Interface for Strategy Oracles
interface IStrategyOracle {
  /*//////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Error thrown when the caller is not the strategy oracle configurator
  error NOT_STRATEGY_ORACLE_CONFIGURATOR();

  /// @notice Error thrown when the input length is invalid
  error INVALID_INPUT_LENGTH();

  /// @notice Error thrown when the reward percentage is too high
  error INVALID_REWARD_PERCENTAGE();

  /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
  //////////////////////////////////////////////////////////////*/

  /// @notice Derives the price of a strategy
  /// @param vault The vault to derive the price for
  /// @param amount The amount of the vault to derive the price for
  /// @return The price of the strategy
  function deriveVaultStrategyPrice(
    address vault,
    uint256 amount
  ) external view returns (uint256 price);

  /// @notice Derives the price of a strategy for multiple vaults
  /// @param vaults The vaults to derive the price for
  /// @param amounts The amounts of the vaults to derive the price for
  /// @return The prices of the strategies
  function deriveVaultsStrategyPrice(
    address[] memory vaults,
    uint256[] memory amounts
  ) external view returns (uint256[] memory prices);

  /// @notice Gets the metadata of a strategy
  /// @param vault The vault to get the metadata for
  /// @return The metadata of the strategy
  function getVaultStrategyMetadata(
    address vault
  ) external view returns (bytes memory metadata);

  /// @notice Gets the metadata of multiple strategies
  /// @param vaults The vaults to get the metadata for
  /// @return The metadata of the strategies
  function getVaultsStrategyMetadata(
    address[] memory vaults
  ) external view returns (bytes[] memory metadata);

  /*//////////////////////////////////////////////////////////////
                          PERMISSIONED METHODS
  //////////////////////////////////////////////////////////////*/

  /// @notice Sets the reward percentage
  /// @param rewardPercentage_ The reward percentage to set
  function setRewardPercentage(uint256 rewardPercentage_) external;
}
