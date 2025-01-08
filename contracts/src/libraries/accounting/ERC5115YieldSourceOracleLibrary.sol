// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library ERC5115YieldSourceOracleLibrary {
    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @param tokenIn The address of the token to receive after redeeming
    /// @return pricePerShare The price per share
    function getPricePerShare(
        address yieldSourceAddress,
        address tokenIn
    )
        internal
        view
        returns (uint256 pricePerShare)
    {
        (,, uint8 decimals) = IStandardizedYield(yieldSourceAddress).assetInfo();
        pricePerShare = IStandardizedYield(yieldSourceAddress).previewRedeem(tokenIn, 10 ** decimals);
    }

    /// @notice Get the price per share for a deposit into multiple yield sources
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param tokenIns The addresses of the tokens to receive after redeeming
    /// @return pricePerShares The price per share for each yield source
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory tokenIns
    )
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        uint256 length = yieldSourceAddresses.length;
        pricePerShares = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            pricePerShares[i] = getPricePerShare(yieldSourceAddresses[i], tokenIns[i]);
            unchecked {
                ++i;
            }
        }
    }
}
