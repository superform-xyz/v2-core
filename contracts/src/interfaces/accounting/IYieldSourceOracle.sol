// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/// @title IYieldSourceOracle
/// @author Superform Labs
/// @notice Interface for Yield Source Oracles
interface IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Derives the TVL in a yield source
    /// @param yieldSourceAddress The yield source to derive TVL for
    function getTVL(address yieldSourceAddress) external view returns (uint256 tvl);

    /// @notice Derives the price of an action
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @return price The price of the action
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price);

    /// @notice Gets the price per share for multiple yield sources
    /// @param yieldSourceAddresses The yield sources to derive the price for
    /// @param underlyingAsset The underlying asset of the yield sources
    /// @return prices The prices of the yield sources
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address underlyingAsset
    )
        external
        view
        returns (uint256[] memory prices);

    /// @notice Gets the metadata of a strategy
    /// @param yieldSourceAddress The vault to get the metadata for
    /// @return metadata The metadata of the strategy
    function getYieldSourceMetadata(address yieldSourceAddress) external view returns (bytes memory metadata);

    /// @notice Gets the metadata of multiple strategies
    /// @param yieldSourceAddresses The vaults to get the metadata for
    /// @return metadata The metadata of the strategies
    function getYieldSourcesMetadata(address[] memory yieldSourceAddresses)
        external
        view
        returns (bytes[] memory metadata);
}
