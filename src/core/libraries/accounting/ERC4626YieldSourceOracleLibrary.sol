// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library ERC4626YieldSourceOracleLibrary {
    function getTVL(address yieldSourceAddress, address ownerOfShares) internal view returns (uint256) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return yieldSource.convertToAssets(shares);
    }

    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 decimals = yieldSource.decimals();
        pricePerShare = yieldSource.convertToAssets(10 ** decimals);
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
