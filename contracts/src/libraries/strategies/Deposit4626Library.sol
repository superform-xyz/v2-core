// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library Deposit4626Library {
    /// @notice Error thrown when the asset of the vaults is not the same
    error VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();

    /// @notice Gets the price per share for a deposit
    /// @param finalTarget The final target vault to deposit into
    /// @return pricePerShare The price per share
    function getPricePerShare(address finalTarget) internal view returns (uint256 pricePerShare) {
        uint256 decimals = IERC4626(finalTarget).decimals();
        pricePerShare = IERC4626(finalTarget).previewRedeem(10 ** decimals);
    }

    /// @notice Get the price per share for a deposit into multiple vaults
    /// @param finalTargets The addresses of the final targets
    /// @return pricePerShares The price per share per final target
    function getPricePerShareMultiple(
        address[] memory finalTargets,
        address underlyingAsset
    )
        internal
        view
        returns (uint256[] memory pricePerShares)
    {
        pricePerShares = new uint256[](finalTargets.length);
        for (uint256 i = 0; i < finalTargets.length; ++i) {
            if (IERC4626(finalTargets[i]).asset() != underlyingAsset) {
                revert VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET();
            }
            pricePerShares[i] = getPricePerShare(finalTargets[i]);
        }
    }
}
