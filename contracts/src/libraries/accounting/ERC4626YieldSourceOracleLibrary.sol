// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library ERC4626YieldSourceOracleLibrary {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

    /// @notice Gets the price per share for a deposit
    /// @param yieldSourceAddress The final target vault to deposit into
    /// @return pricePerShare The price per share
    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
        uint256 decimals = IERC4626(yieldSourceAddress).decimals();
        pricePerShare = IERC4626(yieldSourceAddress).previewRedeem(10 ** decimals);
    }

    /// @notice Get the price per share for a deposit into multiple vaults
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param underlyingAsset The address of the underlying asset
    /// @return pricePerShares The price per share per yield source
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address underlyingAsset
    )
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        uint256 length = yieldSourceAddresses.length;
        pricePerShares = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            if (IERC4626(yieldSourceAddresses[i]).asset() != underlyingAsset) {
                revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
            }
            pricePerShares[i] = getPricePerShare(yieldSourceAddresses[i]);
            unchecked {
                ++i;
            }
        }
    }
}
