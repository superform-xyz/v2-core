// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { IOracle } from "../../interfaces/vendors/awesome-oracles/IOracle.sol";
import { SuperRegistryImplementer } from "../../utils/SuperRegistryImplementer.sol";

/// @title AbstractYieldSourceOracle
/// @author Superform Labs
/// @notice Abstract contract for yield source oracles with common functionality
abstract contract AbstractYieldSourceOracle is SuperRegistryImplementer, IYieldSourceOracle {
    /// @notice USD address constant based on ISO 4217 code
    address public constant USD = address(840);

    constructor(address _superRegistry) SuperRegistryImplementer(_superRegistry) { }

    function decimals(address yieldSourceAddress) external view virtual returns (uint8);

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view virtual returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        virtual
        returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view virtual returns (uint256);

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
    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length) revert ARRAY_LENGTH_MISMATCH();

        userTvls = new uint256[][](length);

        for (uint256 i = 0; i < length;) {
            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvls[i] = new uint256[](ownersLength);

            for (uint256 j = 0; j < ownersLength;) {
                uint256 userTvl = getTVLByOwnerOfShares(yieldSource, owners[j]);
                userTvls[i][j] = userTvl;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultiple(address[] memory yieldSourceAddresses) external view returns (uint256[] memory tvls) {
        uint256 length = yieldSourceAddresses.length;
        tvls = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            tvls[i] = getTVL(yieldSourceAddresses[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareUSD(
        address yieldSourceAddress,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 pricePerShareUSD)
    {
        // Validate base asset
        _validateBaseAsset(yieldSourceAddress, base);

        // Get price per share in base asset terms
        uint256 baseAmount = getPricePerShare(yieldSourceAddress);

        // Convert to USD using oracle registry with specified provider
        pricePerShareUSD = IOracle(_getOracleRegistry()).getQuote(baseAmount, base, _encodeProvider(provider));
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfSharesUSD(
        address yieldSourceAddress,
        address ownerOfShares,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 tvlUSD)
    {
        // Validate base asset
        _validateBaseAsset(yieldSourceAddress, base);

        // Get TVL in base asset terms
        uint256 baseAmount = getTVLByOwnerOfShares(yieldSourceAddress, ownerOfShares);

        // Convert to USD using oracle registry with specified provider
        tvlUSD = IOracle(_getOracleRegistry()).getQuote(baseAmount, base, _encodeProvider(provider));
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLUSD(
        address yieldSourceAddress,
        address base,
        uint256 provider
    )
        external
        view
        returns (uint256 tvlUSD)
    {
        // Validate base asset
        _validateBaseAsset(yieldSourceAddress, base);

        // Get TVL in base asset terms
        uint256 baseAmount = getTVL(yieldSourceAddress);

        // Convert to USD using oracle registry with specified provider
        tvlUSD = IOracle(_getOracleRegistry()).getQuote(baseAmount, base, _encodeProvider(provider));
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[] memory pricesPerShareUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length || length != providers.length) revert ARRAY_LENGTH_MISMATCH();

        pricesPerShareUSD = new uint256[](length);
        IOracle registry = IOracle(_getOracleRegistry());

        for (uint256 i = 0; i < length;) {
            // Validate base asset - this is implemented by child contracts
            _validateBaseAsset(yieldSourceAddresses[i], baseAddresses[i]);

            // Get price per share in base asset terms
            uint256 baseAmount = getPricePerShare(yieldSourceAddresses[i]);

            // Convert to USD using oracle registry with specified provider
            pricesPerShareUSD[i] = registry.getQuote(baseAmount, baseAddresses[i], _encodeProvider(providers[i]));

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfSharesMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[][] memory userTvlsUSD, uint256[] memory totalTvlsUSD)
    {
        TVLMultipleUSDVars memory vars;
        vars.length = yieldSourceAddresses.length;
        if (
            vars.length != ownersOfShares.length || vars.length != baseAddresses.length
                || vars.length != providers.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        userTvlsUSD = new uint256[][](vars.length);
        totalTvlsUSD = new uint256[](vars.length);
        vars.registry = IOracle(_getOracleRegistry());

        for (uint256 i = 0; i < vars.length;) {
            // Validate base asset - this is implemented by child contracts
            _validateBaseAsset(yieldSourceAddresses[i], baseAddresses[i]);

            vars.yieldSource = yieldSourceAddresses[i];
            vars.owners = ownersOfShares[i];
            vars.ownersLength = vars.owners.length;
            vars.totalTvlUSD = 0;

            userTvlsUSD[i] = new uint256[](vars.ownersLength);

            for (uint256 j = 0; j < vars.ownersLength;) {
                // Get TVL in base asset terms
                vars.baseAmount = getTVLByOwnerOfShares(vars.yieldSource, vars.owners[j]);

                // Convert to USD using oracle registry with specified provider
                vars.userTvlUSD =
                    vars.registry.getQuote(vars.baseAmount, baseAddresses[i], _encodeProvider(providers[i]));
                userTvlsUSD[i][j] = vars.userTvlUSD;
                vars.totalTvlUSD += vars.userTvlUSD;

                unchecked {
                    ++j;
                }
            }

            totalTvlsUSD[i] = vars.totalTvlUSD;
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultipleUSD(
        address[] memory yieldSourceAddresses,
        address[] memory baseAddresses,
        uint256[] memory providers
    )
        external
        view
        returns (uint256[] memory tvlsUSD)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length || length != providers.length) revert ARRAY_LENGTH_MISMATCH();

        tvlsUSD = new uint256[](length);
        IOracle registry = IOracle(_getOracleRegistry());

        for (uint256 i = 0; i < length;) {
            // Validate base asset
            _validateBaseAsset(yieldSourceAddresses[i], baseAddresses[i]);

            // Get TVL in base asset terms
            uint256 baseAmount = getTVL(yieldSourceAddresses[i]);

            // Convert to USD using oracle registry with specified provider
            tvlsUSD[i] = registry.getQuote(baseAmount, baseAddresses[i], _encodeProvider(providers[i]));

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns the oracle registry from SuperRegistry
    /// @return registry The oracle registry contract
    function _getOracleRegistry() internal view returns (IOracle) {
        return IOracle(superRegistry.getAddress(superRegistry.ORACLE_REGISTRY_ID()));
    }

    /// @notice Internal function to encode provider ID with USD address
    /// @param provider The provider ID to encode
    /// @return quote The encoded quote address
    function _encodeProvider(uint256 provider) internal pure returns (address) {
        // Encode provider in upper bits and USD in lower bits
        // Note: USD is address(840) which is already in the lower 20 bits format
        return address(uint160((provider << 20) | uint160(USD)));
    }

    /// @notice Validates if a base token is the underlying asset of the yield source
    /// @param yieldSourceAddress The yield source to check
    /// @param base The token to validate
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view virtual;
}
