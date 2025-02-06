// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { IOracle } from "../../interfaces/vendors/awesome-oracles/IOracle.sol";
import { SuperRegistryImplementer } from "../../utils/SuperRegistryImplementer.sol";
import { SuperRegistry } from "../../settings/SuperRegistry.sol";

/// @title ERC5115YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 5115 Vaults
contract ERC5115YieldSourceOracle is SuperRegistryImplementer, IYieldSourceOracle {
    /// @notice USD address constant based on ISO 4217 code
    address public constant USD = address(840);

    constructor(address _superRegistry) SuperRegistryImplementer(_superRegistry) { }

    /// @inheritdoc IYieldSourceOracle
    function decimals(address) external pure returns (uint8) {
        return 18;
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 pricePerShare) {
        // Get the exchange rate from the StandardizedYield contract
        // This represents how many assets (in 1e18) one SY token is worth
        pricePerShare = IStandardizedYield(yieldSourceAddress).exchangeRate();

        // Note: exchangeRate is already normalized to 1e18, so no additional scaling needed
        // If exchangeRate is 2e18, it means 1 SY token = 2 asset tokens
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
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return (shares * yieldSource.exchangeRate()) / 1e18;
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
        address base
    )
        external
        view
        returns (uint256 pricePerShareUSD)
    {
        // For ERC5115, base must be one of the accepted input tokens
        _validateBaseToken(yieldSourceAddress, base);

        // Get price per share in base asset terms
        uint256 baseAmount = getPricePerShare(yieldSourceAddress);

        // Convert to USD using oracle registry
        pricePerShareUSD = _getOracleRegistry().getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length) revert ARRAY_LENGTH_MISMATCH();

        pricesPerShareUSD = new uint256[](length);
        IOracle registry = _getOracleRegistry();

        for (uint256 i = 0; i < length;) {
            // For ERC5115, base must be one of the accepted input tokens
            _validateBaseToken(yieldSourceAddresses[i], baseAddresses[i]);

            // Get price per share in base asset terms
            uint256 baseAmount = getPricePerShare(yieldSourceAddresses[i]);

            // Convert to USD using oracle registry
            pricesPerShareUSD[i] = registry.getQuote(baseAmount, baseAddresses[i], USD);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base
    )
        external
        view
        returns (uint256 tvlUSD)
    {
        // For ERC5115, base must be one of the accepted input tokens
        _validateBaseToken(yieldSourceAddress, base);

        // Get TVL in base asset terms
        uint256 baseAmount = getTVL(yieldSourceAddress, ownerOfShares);

        // Convert to USD using oracle registry
        tvlUSD = _getOracleRegistry().getQuote(baseAmount, base, USD);
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length || length != baseAddresses.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        userTvlsUSD = new uint256[][](length);
        totalTvlsUSD = new uint256[](length);
        IOracle registry = _getOracleRegistry();

        for (uint256 i = 0; i < length;) {
            // For ERC5115, base must be one of the accepted input tokens
            _validateBaseToken(yieldSourceAddresses[i], baseAddresses[i]);

            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvlsUSD[i] = new uint256[](ownersLength);
            uint256 totalTvlUSD = 0;

            for (uint256 j = 0; j < ownersLength;) {
                // Get TVL in base asset terms
                uint256 baseAmount = getTVL(yieldSource, owners[j]);

                // Convert to USD using oracle registry
                uint256 userTvlUSD = registry.getQuote(baseAmount, baseAddresses[i], USD);
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

    /// @notice Validates if a base token is accepted by the yield source as an asset out
    /// @param yieldSourceAddress The yield source to check
    /// @param base The token to validate
    function _validateBaseToken(address yieldSourceAddress, address base) internal view {
        address[] memory tokensIn = IStandardizedYield(yieldSourceAddress).getTokensOut();
        bool isValid = false;

        for (uint256 i = 0; i < tokensIn.length;) {
            if (tokensIn[i] == base) {
                isValid = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!isValid) revert INVALID_BASE_ASSET();
    }

    /// @notice Returns the oracle registry from SuperRegistry
    /// @return registry The oracle registry contract
    function _getOracleRegistry() internal view returns (IOracle) {
        return IOracle(superRegistry.getAddress(superRegistry.ORACLE_REGISTRY_ID()));
    }
}
