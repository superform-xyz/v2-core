// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Vault Interface
import { IERC7540 } from "../../interfaces/vendors/vaults/7540/IERC7540.sol";

// External
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library ERC7540YieldSourceOracleLibrary {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return pricePerShare The price per share
    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 decimals = ERC20(share).decimals();
        return IERC7540(yieldSourceAddress).previewRedeem(10 ** decimals);
    }

    /// @notice Get the price per share for a deposit into multiple yield sources
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param underlyingAsset The address of the underlying asset
    /// @return pricePerShares The price per share per yield source
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address underlyingAsset
    ) internal view returns (uint256[] memory pricePerShares) {
        uint256 length = yieldSourceAddresses.length;
        pricePerShares = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            if (IERC7540(yieldSourceAddresses[i]).asset() != underlyingAsset) {
                revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
            }
            pricePerShares[i] = getPricePerShare(yieldSourceAddresses[i]);
            unchecked {
                ++i;
            }
        }
    }
}

