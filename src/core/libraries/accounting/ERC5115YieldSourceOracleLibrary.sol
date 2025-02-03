// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library ERC5115YieldSourceOracleLibrary {
    function getTVL(address yieldSourceAddress, address ownerOfShares) internal view returns (uint256 tvl) {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return (shares * yieldSource.exchangeRate()) / 1e18;
    }

    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
        // Get the exchange rate from the StandardizedYield contract
        // This represents how many assets (in 1e18) one SY token is worth
        pricePerShare = IStandardizedYield(yieldSourceAddress).exchangeRate();

        // Note: exchangeRate is already normalized to 1e18, so no additional scaling needed
        // If exchangeRate is 2e18, it means 1 SY token = 2 asset tokens
    }

    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        uint256 length = yieldSourceAddresses.length;
        pricePerShares = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            pricePerShares[i] = getPricePerShare(yieldSourceAddresses[i]);
            unchecked {
                ++i;
            }
        }
    }
}
