// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { IFluidLendingStakingRewards } from "../../interfaces/vendors/fluid/IFluidLendingStakingRewards.sol";

/// @title FluidYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Fluid yield source
contract FluidYieldSourceOracle is IYieldSourceOracle {
    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 pricePerShare) {
        pricePerShare = IFluidLendingStakingRewards(yieldSourceAddress).rewardPerToken();
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare)
    {
        uint256 length = yieldSourceAddresses.length;
        pricesPerShare = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            address yieldAddress = yieldSourceAddresses[i];
            pricesPerShare[i] = IFluidLendingStakingRewards(yieldAddress).rewardPerToken();
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        tvl = IFluidLendingStakingRewards(yieldSourceAddress).balanceOf(ownerOfShares)
            * IFluidLendingStakingRewards(yieldSourceAddress).rewardPerToken();
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls, uint256[] memory totalTvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length) revert ARRAY_LENGTH_MISMATCH();

        userTvls = new uint256[][](length);
        totalTvls = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvls[i] = new uint256[](ownersLength);
            uint256 totalTvl = 0;

            for (uint256 j = 0; j < ownersLength;) {
                uint256 userTvl = getTVL(yieldSource, owners[j]);
                userTvls[i][j] = userTvl;
                totalTvl += userTvl;
                unchecked {
                    ++j;
                }
            }

            totalTvls[i] = totalTvl;
            unchecked {
                ++i;
            }
        }
    }
}
