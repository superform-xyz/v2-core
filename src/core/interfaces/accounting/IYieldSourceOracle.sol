// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Superform
import {IOracle} from "../../../vendor/awesome-oracles/IOracle.sol";

/// @title IYieldSourceOracle
/// @author Superform Labs
/// @notice Interface for oracles that provide price and TVL data for yield-bearing assets
interface IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error when array lengths do not match in batch operations
    /// @dev Thrown when the lengths of input arrays in multi-asset operations don't match
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Error when base asset is not valid for the yield source
    /// @dev Thrown when attempting to use an asset that isn't supported by the yield source
    error INVALID_BASE_ASSET();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to hold local variables for getTVLMultipleUSD
    /// @dev Used to manage complex computation state without stack-too-deep errors
    ///      These variables support the calculation of USD-denominated TVL values
    ///      across multiple yield sources and owners
    struct TVLMultipleUSDVars {
        /// @notice Number of yield sources being processed
        uint256 length;
        /// @notice Number of share owners being processed
        uint256 ownersLength;
        /// @notice Base amount in the underlying asset's native units
        uint256 baseAmount;
        /// @notice Accumulated TVL in USD for a specific user
        uint256 userTvlUSD;
        /// @notice Accumulated total TVL in USD across all sources
        uint256 totalTvlUSD;
        /// @notice Current yield source being processed
        address yieldSource;
        /// @notice Array of addresses that own shares in the yield source
        address[] owners;
        /// @notice Oracle registry used for price conversions
        IOracle registry;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of decimals of the yield source shares
    /// @dev Critical for accurately interpreting share amounts and calculating prices
    ///      Different yield sources may have different decimal precision
    /// @param yieldSourceAddress The address of the yield-bearing token contract
    /// @return decimals The number of decimals used by the yield source's share token
    function decimals(address yieldSourceAddress) external view returns (uint8);

    /// @notice Calculates the number of shares that would be received for a given amount of assets
    /// @dev Used for deposit simulations and to calculate current exchange rates
    /// @param yieldSourceAddress The yield-bearing token address (e.g., aUSDC, cDAI)
    /// @param assetIn The underlying asset being deposited (e.g., USDC, DAI)
    /// @param assetsIn The amount of underlying assets to deposit, in the asset's native units
    /// @return shares The number of yield-bearing shares that would be received
    function getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn)
        external
        view
        returns (uint256);

    /// @notice Calculates the number of underlying assets that would be received for a given amount of shares
    /// @dev Used for withdrawal simulations and to calculate current yield
    /// @param yieldSourceAddress The yield-bearing token address (e.g., aUSDC, cDAI)
    /// @param assetIn The underlying asset to receive (e.g., USDC, DAI)
    /// @param sharesIn The amount of yield-bearing shares to redeem
    /// @return assets The number of underlying assets that would be received
    function getAssetOutput(address yieldSourceAddress, address assetIn, uint256 sharesIn)
        external
        view
        returns (uint256);

    /// @notice Retrieves the current price per share in terms of the underlying asset
    /// @dev Core function for calculating yields and determining returns
    /// @param yieldSourceAddress The yield-bearing token address to get the price for
    /// @return pricePerShare The current price per share in underlying asset terms, scaled by decimals
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256);

    /// @notice Calculates the total value locked in a yield source by a specific owner
    /// @dev Used to track individual position sizes within the system
    /// @param yieldSourceAddress The yield-bearing token address to check
    /// @param ownerOfShares The address owning the yield-bearing tokens
    /// @return tvl The total value locked by the owner, in underlying asset terms
    function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) external view returns (uint256);

    /// @notice Gets the share balance of a specific owner in a yield source
    /// @dev Returns raw share balance without converting to underlying assets
    ///      Used to track participation in the system and for accounting
    /// @param yieldSourceAddress The yield-bearing token address
    /// @param ownerOfShares The address to check the balance for
    /// @return balance The number of yield-bearing tokens owned by the address
    function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) external view returns (uint256);

    /// @notice Calculates the total value locked across all users in a yield source
    /// @dev Critical for monitoring the size of each yield source in the system
    /// @param yieldSourceAddress The yield-bearing token address to check
    /// @return tvl The total value locked in the yield source, in underlying asset terms
    function getTVL(address yieldSourceAddress) external view returns (uint256);

    /// @notice Verifies if a given token is a valid underlying asset for a yield source
    /// @dev Security check to prevent operations with incompatible assets
    /// @param yieldSourceAddress The yield-bearing token address to check against
    /// @param expectedUnderlying The address of the potential underlying asset
    /// @return True if the address is a valid underlying asset for the yield source
    function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying)
        external
        view
        returns (bool);

    /// @notice Batch version of isValidUnderlyingAsset for multiple yield sources
    /// @dev Efficiently verifies multiple yield source/asset pairs in a single call
    /// @param yieldSourceAddresses Array of yield-bearing token addresses
    /// @param expectedUnderlying Array of potential underlying asset addresses
    /// @return isValid Array of booleans indicating validity of each pair
    function isValidUnderlyingAssets(address[] memory yieldSourceAddresses, address[] memory expectedUnderlying)
        external
        view
        returns (bool[] memory isValid);

    /// @notice Batch version of getPricePerShare for multiple yield sources
    /// @dev Efficiently retrieves current prices for multiple yield sources
    /// @param yieldSourceAddresses Array of yield-bearing token addresses
    /// @return pricesPerShare Array of current prices for each yield source
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare);

    /// @notice Batch version of getTVLByOwnerOfShares for multiple yield sources and owners
    /// @dev Efficiently calculates TVL for multiple owners across multiple yield sources
    /// @param yieldSourceAddresses Array of yield-bearing token addresses
    /// @param ownersOfShares 2D array where each sub-array contains owner addresses for a yield source
    /// @return userTvls 2D array of TVL values for each owner in each yield source
    function getTVLByOwnerOfSharesMultiple(address[] memory yieldSourceAddresses, address[][] memory ownersOfShares)
        external
        view
        returns (uint256[][] memory userTvls);

    /// @notice Batch version of getTVL for multiple yield sources
    /// @dev Efficiently calculates total TVL across multiple yield sources
    /// @param yieldSourceAddresses Array of yield-bearing token addresses
    /// @return tvls Array containing the total TVL for each yield source
    function getTVLMultiple(address[] memory yieldSourceAddresses) external view returns (uint256[] memory tvls);
}
