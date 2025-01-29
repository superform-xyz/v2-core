// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Looped4626DepositYieldSourceOracleLibrary {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

    /// @notice Get the price per share for a single yield source over a number of loops
    /// @param yieldSourceAddress The address of the yield source
    /// @param loops The number of loops
    /// @return pricePerShare The price per share
    function getPricePerShare(
        address yieldSourceAddress,
        uint256 loops
    )
        internal
        view
        returns (uint256 pricePerShare)
    {
        uint256 decimals = IERC4626(yieldSourceAddress).decimals();
        pricePerShare = IERC4626(yieldSourceAddress).previewRedeem(10 ** decimals);
        pricePerShare *= loops;
    }

    /// @notice Get the price per share for multiple yield sources
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param underlyingAsset The address of the underlying asset
    /// @param loops The number of loops
    /// @return pricePerShares The price per share per yield source
    function getPricePerShares(
        address[] memory yieldSourceAddresses,
        address underlyingAsset,
        uint256 loops
    )
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        uint256 length = yieldSourceAddresses.length;
        pricePerShares = new uint256[](length);
        for (uint256 i; i < length;) {
            if (IERC4626(yieldSourceAddresses[i]).asset() != underlyingAsset) {
                revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
            }
            pricePerShares[i] = getPricePerShare(yieldSourceAddresses[i], loops);
            unchecked {
                ++i;
            }
        }
    }
}
