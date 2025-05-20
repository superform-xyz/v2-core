// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

/// @title ISuperYieldSourceOracle
/// @notice Interface for SuperYieldSourceOracle, providing functions to quote yield source metrics in various assets.
interface ISuperYieldSourceOracle {
    error INVALID_BASE_ASSET();
    /// @dev Helper struct to avoid stack too deep errors in getTVLByOwnerOfSharesMultipleQuote

    struct TVLMultipleQuoteVars {
        uint256 length;
        // Removed IOracle registry as it's already a state variable
        address yieldSource;
        address[] owners;
        uint256 ownersLength;
        uint256 totalTvlQuote;
        uint256 baseAmount;
        uint256 userTvlQuote;
    }

    /*//////////////////////////////////////////////////////////////
                        GENERALIZED QUOTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share of a yield source in terms of a specified quote asset.
    /// @param yieldSourceAddress The address of the yield source.
    /// @param yieldSourceOracle The address of the yield source oracle.
    /// @param base The base asset of the yield source.
    /// @param quote The asset to quote the price in.
    /// @return pricePerShareQuote The price per share in terms of the quote asset.
    function getPricePerShareQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote
    )
        external
        view
        returns (uint256 pricePerShareQuote);

    /// @notice Get the Total Value Locked (TVL) by a specific owner in a yield source, quoted in a specified asset.
    /// @param yieldSourceAddress The address of the yield source.
    /// @param yieldSourceOracle The address of the yield source oracle.
    /// @param ownerOfShares The address of the owner whose shares' value is being queried.
    /// @param base The base asset of the yield source.
    /// @param quote The asset to quote the TVL in.
    /// @return tvlQuote The TVL in terms of the quote asset.
    function getTVLByOwnerOfSharesQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address ownerOfShares,
        address base,
        address quote
    )
        external
        view
        returns (uint256 tvlQuote);

    /// @notice Get the total TVL of a yield source, quoted in a specified asset.
    /// @param yieldSourceAddress The address of the yield source.
    /// @param yieldSourceOracle The address of the yield source oracle.
    /// @param base The base asset of the yield source.
    /// @param quote The asset to quote the TVL in.
    /// @return tvlQuote The TVL in terms of the quote asset.
    function getTVLQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote
    )
        external
        view
        returns (uint256 tvlQuote);

    /// @notice Get the price per share for multiple yield sources, quoted in specified assets.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @param baseAddresses Array of corresponding base asset addresses.
    /// @param quoteAddresses Array of corresponding quote asset addresses.
    /// @return pricesPerShareQuote Array of prices per share in terms of the respective quote assets.
    function getPricePerShareMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses,
        address[] memory quoteAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShareQuote);

    /// @notice Get the TVL by owner for multiple yield sources and owners, quoted in specified assets.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @param ownersOfShares Jagged array where each inner array contains owners for the corresponding yield source.
    /// @param baseAddresses Array of corresponding base asset addresses.
    /// @param quoteAddresses Array of corresponding quote asset addresses.
    /// @return userTvlsQuote Jagged array of user TVLs in terms of the respective quote assets.
    /// @return totalTvlsQuote Array of total TVLs for each yield source in terms of the respective quote assets.
    function getTVLByOwnerOfSharesMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        address[] memory quoteAddresses
    )
        external
        view
        returns (uint256[][] memory userTvlsQuote, uint256[] memory totalTvlsQuote);

    /// @notice Get the total TVL for multiple yield sources, quoted in specified assets.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @param baseAddresses Array of corresponding base asset addresses.
    /// @param quoteAddresses Array of corresponding quote asset addresses.
    /// @return tvlsQuote Array of total TVLs in terms of the respective quote assets.
    function getTVLMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses,
        address[] memory quoteAddresses
    )
        external
        view
        returns (uint256[] memory tvlsQuote);

    /*//////////////////////////////////////////////////////////////
                    YIELD SOURCE ORACLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the price per share for multiple yield sources, in terms of a specified base asset.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @param baseAddresses Array of corresponding base asset addresses.
    /// @return pricesPerShare Array of prices per share in terms of the specified base asset.
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShare);

    /// @notice Get the TVL by owner for multiple yield sources and owners, in terms of a specified base asset.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @param ownersOfShares Jagged array where each inner array contains owners for the corresponding yield source.
    /// @param baseAddresses Array of corresponding base asset addresses.
    /// @return totalTvls Array of total TVLs for each yield source in terms of the specified base asset.
    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[][] memory userTvls, uint256[] memory totalTvls);

    /// @notice Get the total TVL for multiple yield sources, in terms of a specified base asset.
    /// @param yieldSourceAddresses Array of yield source addresses.
    /// @param yieldSourceOracles Array of yield source oracle addresses.
    /// @return tvls Array of total TVLs in terms of the specified base asset.
    function getTVLMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles
    )
        external
        view
        returns (uint256[] memory tvls);
}
