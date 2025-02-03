// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Vault Interface
import { IERC7540 } from "../../interfaces/vendors/vaults/7540/IERC7540.sol";

// External
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library ERC7540YieldSourceOracleLibrary {
    function getTVL(address yieldSourceAddress, address ownerOfShares) internal view returns (uint256) {
        uint256 shares = IERC7540(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(shares);
    }

    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 decimals = ERC20(share).decimals();
        return IERC7540(yieldSourceAddress).convertToAssets(10 ** decimals);
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
