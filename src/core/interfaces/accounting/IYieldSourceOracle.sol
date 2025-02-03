// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/// @title IYieldSourceOracle
/// @author Superform Labs
/// @notice Interface for Yield Source Oracles
interface IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Derives the TVL in a yield source by a given owner of shares
    /// @param yieldSourceAddress The yield source to derive TVL for
    /// @param ownerOfShares The owner of the shares
    /// @return tvl The TVL of the yield source by the owner of the shares
    function getTVL(address yieldSourceAddress, address ownerOfShares) external view returns (uint256 tvl);

    /// @notice Derives the price of an action
    /// @param yieldSourceAddress The yield source to derive the price for
    /// @return price The price of the action
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price);

    /// @notice Gets the price per share for multiple yield sources
    /// @param yieldSourceAddresses The yield sources to derive the price for
    /// @return prices The prices of the yield sources
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices);
}
