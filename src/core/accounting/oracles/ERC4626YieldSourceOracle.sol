// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";


/// @title ERC4626YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 4626 Vaults
contract ERC4626YieldSourceOracle is IYieldSourceOracle {
    /// @inheritdoc IYieldSourceOracle
    function decimals(address yieldSourceAddress) external view returns (uint8) {
        return IERC4626(yieldSourceAddress).decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 pricePerShare) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 _decimals = yieldSource.decimals();
        pricePerShare = yieldSource.convertToAssets(10 ** _decimals);
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
            pricesPerShare[i] = getPricePerShare(yieldSourceAddresses[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return yieldSource.convertToAssets(shares);
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
