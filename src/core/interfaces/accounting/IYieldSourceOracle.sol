// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/// @title IYieldSourceOracle
/// @author Superform Labs
/// @notice Interface for Yield Source Oracles
interface IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when array lengths do not match in batch operations
    error ARRAY_LENGTH_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the number of decimals of the yield source shares
    /// @return decimals The number of decimals of the yield source shares
    function decimals(address yieldSourceAddress) external view returns (uint8);

    /// @notice Derives the price of an action
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @return pricePerShare The price of the action
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 pricePerShare);

    /// @notice Derives the price of an action for multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive the price for
    /// @return pricesPerShare Array of prices for each yield source
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare);

    /// @notice Derives the TVL in a yield source by a given owner of shares
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param ownerOfShares The owner of the shares
    /// @return tvl The TVL of the yield source by the owner of the shares
    function getTVL(address yieldSourceAddress, address ownerOfShares) external view returns (uint256 tvl);

    /// @notice Derives the TVL in multiple yield sources for multiple owners
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @param ownersOfShares Array of arrays containing owner addresses for each yield source
    /// @return userTvls Array of arrays containing TVLs for each owner in each yield source
    /// @return totalTvls Array containing total TVL for each yield source
    function getTVLMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls, uint256[] memory totalTvls);
}
