// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

// Superform
import { IERC7540 } from "../../interfaces/vendors/vaults/7540/IERC7540.sol";
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { IOracle } from "../../interfaces/vendors/awesome-oracles/IOracle.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is IYieldSourceOracle {
    /// @notice USD address constant based on ISO 4217 code
    address public constant USD = address(840);

    /// @inheritdoc IYieldSourceOracle
    function decimals(address yieldSourceAddress) external view returns (uint8) {
        address share = IERC7540(yieldSourceAddress).share();
        return IERC20Metadata(share).decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 pricePerShare) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 _decimals = IERC20Metadata(share).decimals();
        pricePerShare = IERC7540(yieldSourceAddress).convertToAssets(10 ** _decimals);
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
        uint256 shares = IERC7540(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(shares);
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

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareUSD(
        address yieldSourceAddress,
        address base,
        address oracle
    )
        external
        view
        returns (uint256 pricePerShareUSD)
    {
        // Validate base asset
        if (base != IERC7540(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();

        // Get price per share in base asset terms
        uint256 baseAmount = getPricePerShare(yieldSourceAddress);

        // Convert to USD using oracle
        pricePerShareUSD = IOracle(oracle).getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        address[] memory oracleAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length || length != oracleAddresses.length) revert ARRAY_LENGTH_MISMATCH();

        pricesPerShareUSD = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            // Validate base asset
            if (baseAddresses[i] != IERC7540(yieldSourceAddresses[i]).asset()) revert INVALID_BASE_ASSET();

            // Get price per share in base asset terms
            uint256 baseAmount = getPricePerShare(yieldSourceAddresses[i]);

            // Convert to USD using oracle
            pricesPerShareUSD[i] = IOracle(oracleAddresses[i]).getQuote(baseAmount, baseAddresses[i], USD);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base,
        address oracle
    )
        external
        view
        returns (uint256 tvlUSD)
    {
        // Validate base asset
        if (base != IERC7540(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();

        // Get TVL in base asset terms
        uint256 baseAmount = getTVL(yieldSourceAddress, ownerOfShares);

        // Convert to USD using oracle
        tvlUSD = IOracle(oracle).getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        address[] memory oracleAddresses
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length || length != baseAddresses.length || length != oracleAddresses.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        userTvlsUSD = new uint256[][](length);
        totalTvlsUSD = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            // Validate base asset
            if (baseAddresses[i] != IERC7540(yieldSourceAddresses[i]).asset()) revert INVALID_BASE_ASSET();

            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvlsUSD[i] = new uint256[](ownersLength);
            uint256 totalTvlUSD = 0;

            for (uint256 j = 0; j < ownersLength;) {
                // Get TVL in base asset terms
                uint256 baseAmount = getTVL(yieldSource, owners[j]);

                // Convert to USD using oracle
                uint256 userTvlUSD = IOracle(oracleAddresses[i]).getQuote(baseAmount, baseAddresses[i], USD);
                userTvlsUSD[i][j] = userTvlUSD;
                totalTvlUSD += userTvlUSD;

                unchecked {
                    ++j;
                }
            }

            totalTvlsUSD[i] = totalTvlUSD;
            unchecked {
                ++i;
            }
        }
    }
}
