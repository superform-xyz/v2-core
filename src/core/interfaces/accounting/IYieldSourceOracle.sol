// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { IOracle } from "../../../vendor/awesome-oracles/IOracle.sol";

/// @title IYieldSourceOracle
/// @author Superform Labs
/// @notice Interface for Yield Source Oracles
interface IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error when array lengths do not match in batch operations
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Error when base asset is not valid for the yield source
    error INVALID_BASE_ASSET();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to hold local variables for getTVLMultipleUSD
    struct TVLMultipleUSDVars {
        uint256 length;
        uint256 ownersLength;
        uint256 baseAmount;
        uint256 userTvlUSD;
        uint256 totalTvlUSD;
        address yieldSource;
        address[] owners;
        IOracle registry;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the oracle registry contract
    /// @return oracleRegistry The oracle registry contract
    function oracleRegistry() external view returns (address);

    /// @notice Returns the number of decimals of the yield source shares
    /// @return decimals The number of decimals of the yield source shares
    function decimals(address yieldSourceAddress) external view returns (uint8);

    /// @notice Returns the number of shares that would be received for a given amount of assets
    /// @param yieldSourceAddress The yield source to derive the number of shares for
    /// @param assetIn The asset to derive the number of shares for
    /// @param assetsIn The amount of assets to derive the number of shares for
    /// @return shares The number of shares that would be received for the given amount of assets
    function getShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        external
        view
        returns (uint256);

    /// @notice Returns the number of assets that would be received for a given amount of shares
    /// @param yieldSourceAddress The yield source to derive the number of assets for
    /// @param assetIn The asset to derive the number of assets for
    /// @param sharesIn The amount of shares to derive the number of assets for
    /// @return assets The number of assets that would be received for the given amount of shares
    function getAssetOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 sharesIn
    )
        external
        view
        returns (uint256);

    /// @notice Derives the price of an action
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @return pricePerShare The price of the action
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256);

    /// @notice Derives the TVL in a yield source by a given owner of shares
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param ownerOfShares The owner of the shares
    /// @return tvl The TVL of the yield source by the owner of the shares
    function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) external view returns (uint256);

    /// @notice Derives the total TVL in a yield source
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @return tvl The total TVL of the yield source
    function getTVL(address yieldSourceAddress) external view returns (uint256);

    /// @notice Derives the price of an action for multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive the price for
    /// @return pricesPerShare Array of prices for each yield source
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare);

    /// @notice Returns the TVL in multiple yield sources for multiple owners
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @param ownersOfShares Array of arrays containing owner addresses for each yield source
    /// @return userTvls Array of arrays containing TVLs for each owner in each yield source
    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls);

    /// @notice Derives the total TVL in multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @return tvls Array containing total TVL for each yield source
    function getTVLMultiple(address[] memory yieldSourceAddresses) external view returns (uint256[] memory tvls);

    /// @notice Returns the price per share in USD terms
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @param base The underlying asset of the yield source
    /// @param provider The provider ID to use for price conversion
    /// @return pricePerShareUSD The price per share in USD terms
    function getPricePerShareUSD(
        address yieldSourceAddress,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 pricePerShareUSD);

    /// @notice Returns the TVL in USD terms
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param ownerOfShares The owner of the shares
    /// @param base The underlying asset of the yield source
    /// @param provider The provider ID to use for price conversion
    /// @return tvlUSD The TVL in USD terms
    function getTVLByOwnerOfSharesUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 tvlUSD);

    /// @notice Returns the total TVL in USD terms
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param base The underlying asset of the yield source
    /// @param provider The provider ID to use for price conversion
    /// @return tvlUSD The TVL in USD terms
    function getTVLUSD(
        address yieldSourceAddress,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 tvlUSD);

    /// @notice Returns the price per share in USD terms for multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive the price for
    /// @param baseAddresses Array of underlying assets for each yield source
    /// @param providers Array of provider IDs to use for price conversion
    /// @return pricesPerShareUSD Array of prices in USD terms for each yield source
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD);

    /// @notice Returns the TVL in USD terms for multiple yield sources and owners
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @param ownersOfShares Array of arrays containing owner addresses for each yield source
    /// @param baseAddresses Array of underlying assets for each yield source
    /// @param providers Array of provider IDs to use for price conversion
    /// @return userTvlsUSD Array of arrays containing TVLs in USD terms for each owner in each yield source
    /// @return totalTvlsUSD Array containing total TVL in USD terms for each yield source for the selected owners
    function getTVLByOwnerOfSharesMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD);

    /// @notice Returns the total TVL in USD terms for multiple yield sources
    /// @param yieldSourceAddresses Array of yield sources to derive TVL for
    /// @param baseAddresses Array of underlying assets for each yield source
    /// @param providers Array of provider IDs to use for price conversion
    /// @return tvlsUSD Array containing total TVL in USD terms for each yield source
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[] memory tvlsUSD);
}
