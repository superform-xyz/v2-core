// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IGearboxFarmingPool } from "../../interfaces/vendors/gearbox/IGearboxFarmingPool.sol";


library GearboxSourceOracleLibrary {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

    /// @notice Get the price per share for a Gearbox yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return pricePerShare The price per share
    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
        pricePerShare = 1;
    }

    /// @notice Get the price per share for a deposit into multiple Gearbox yield sources
    /// @param yieldSourceAddresses The addresses of the Gearbox yield sources
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
            address yieldAddress = yieldSourceAddresses[i];
            if (IGearboxFarmingPool(yieldAddress).stakingToken() != underlyingAsset) {
                revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
            }
            pricePerShares[i] = 1;
            unchecked {
                ++i;
            }
        }
    }
}
