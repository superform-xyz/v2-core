// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library DepositRedeem5115Library {
    /// @notice Get the price per share for a deposit into a 5115 vault
    /// @param yieldSourceAddress The address of the final target vault
    /// @param tokenIn The address of the token to receive after redeeming
    /// @return pricePerShare The price per share
    function getPricePerShare(address yieldSourceAddress, address tokenIn) internal view returns (uint256 pricePerShare) {
        (,, uint8 decimals) = IStandardizedYield(yieldSourceAddress).assetInfo();
        pricePerShare = IStandardizedYield(yieldSourceAddress).previewRedeem(tokenIn, 10 ** decimals);
    }

    /// @notice Get the price per share for a deposit into multiple 5115 vaults
    /// @param finalTargets The addresses of the final target vaults
    /// @param tokenIns The addresses of the tokens to receive after redeeming
    /// @return pricePerShares The price per share for each vault
    function getPricePerShareMultiple(
        address[] memory finalTargets,
        address[] memory tokenIns
    )
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        uint256 length = finalTargets.length;
        pricePerShares = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            pricePerShares[i] = getPricePerShare(finalTargets[i], tokenIns[i]);
            unchecked {
                ++i;
            }
        }
    }
}
