// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/// @title IActionOracle
/// @author Superform Labs
/// @notice Interface for Action Oracles
interface IActionOracle {
    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Derives the price of an action
    /// @param finalTarget The vault to derive the price for
    /// @return price The price of the action
    function getStrategyPrice(address finalTarget) external view returns (uint256 price);

    /// @notice Derives the price of an action for multiple vaults
    /// @param finalTargets The vaults to derive the price for
    /// @return prices The prices of the actions
    function getStrategyPrices(
        address[] memory finalTargets,
        address underlyingAsset
    )
        external
        view
        returns (uint256[] memory prices);

    /// @notice Gets the metadata of a strategy
    /// @param finalTarget The vault to get the metadata for
    /// @return metadata The metadata of the strategy
    function getVaultStrategyMetadata(address finalTarget) external view returns (bytes memory metadata);

    /// @notice Gets the metadata of multiple strategies
    /// @param finalTargets The vaults to get the metadata for
    /// @return metadata The metadata of the strategies
    function getVaultsStrategyMetadata(address[] memory finalTargets) external view returns (bytes[] memory metadata);
}
