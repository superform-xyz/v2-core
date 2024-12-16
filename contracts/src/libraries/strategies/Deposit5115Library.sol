// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library Deposit5115Library {
    /// @notice Get the price per share for a deposit into a 5115 vault
    /// @param finalTarget The address of the final target vault
    /// @param tokenIn The address of the token to receive after redeeming
    /// @return pricePerShare The price per share
    function getPricePerShare(address finalTarget, address tokenIn) internal view returns (uint256 pricePerShare) {
        (,, uint8 decimals) = IStandardizedYield(finalTarget).assetInfo();
        pricePerShare = IStandardizedYield(finalTarget).previewRedeem(tokenIn, 10 ** decimals);
    }

    // TODO: Add multiple 5115 vaults
}
