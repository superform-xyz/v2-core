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

    /// @notice Error thrown when base asset is not valid for the yield source
    error INVALID_BASE_ASSET();

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

    /// @notice Returns the price per share in USD terms
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @param base The underlying asset of the yield source
    /// @param oracle The oracle to use for USD conversion
    /// @return pricePerShareUSD The price per share in USD terms
    function getPricePerShareUSD(
        address yieldSourceAddress,
        address base,
        address oracle
    )
        external
        view
        returns (uint256 pricePerShareUSD);

    /// @notice Returns the price per share in USD terms for multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive the price for
    /// @param baseAddresses Array of underlying assets for each yield source
    /// @param oracleAddresses Array of oracles to use for USD conversion for each yield source
    /// @return pricesPerShareUSD Array of prices in USD terms for each yield source
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        address[] memory oracleAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD);

    /// @notice Returns the TVL in USD terms
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param ownerOfShares The owner of the shares
    /// @param base The underlying asset of the yield source
    /// @param oracle The oracle to use for USD conversion
    /// @return tvlUSD The TVL in USD terms
    function getTVLUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base,
        address oracle
    )
        external
        view
        returns (uint256 tvlUSD);

    /// @notice Returns the TVL in USD terms for multiple yield sources and owners
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @param ownersOfShares Array of arrays containing owner addresses for each yield source
    /// @param baseAddresses Array of underlying assets for each yield source
    /// @param oracleAddresses Array of oracles to use for USD conversion for each yield source
    /// @return userTvlsUSD Array of arrays containing TVLs in USD terms for each owner in each yield source
    /// @return totalTvlsUSD Array containing total TVL in USD terms for each yield source
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        address[] memory oracleAddresses
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD);
}
