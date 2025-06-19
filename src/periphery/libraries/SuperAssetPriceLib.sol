// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISuperOracle } from "../interfaces/oracles/ISuperOracle.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library SuperAssetPriceLib {
    using Math for uint256;

    /// @dev Gets the price of a token with circuit breakers
    /// @param args The arguments for the price calculation
    /// @return priceUSD The price of the token in USD
    /// @return isDepeg Whether the token is depegged
    /// @return isDispersion Whether the token has price dispersion
    /// @return isOracleOff Whether the oracle is off
    function getPriceWithCircuitBreakers(ISuperAsset.PriceArgs memory args)
        external
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
    {
        // Get token decimals
        uint256 stddev;
        uint256 M;

        // @dev Passing oneUnit to get the price of a single unit of asset to check if it has depegged
        ISuperOracle superOracle = ISuperOracle(args.superOracle);
        ISuperAsset superAsset = ISuperAsset(args.superAsset);

        uint256 precision = superAsset.getPrecision();

        (priceUSD, stddev, M) = _getPriceInfo(superOracle, superAsset, args.usd, args.token);

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            isOracleOff = true;
        } else {
            address primaryAsset = superAsset.getPrimaryAsset();
            if (primaryAsset == args.usd) {
                return (precision, false, false, false);
            }

            // Circuit Breaker for Depeg - price deviates more than ±2% from expected
            (isDepeg, isDispersion) = _getDepegAndDispersion(args, precision, priceUSD, stddev);
        }
        return (priceUSD, isDepeg, isDispersion, isOracleOff);
    }

    /// @dev Derives the price of the token from the underlying vault
    /// @param token The address of the token to derive the price of
    /// @return priceUSD The price of the token in USD
    /// @return stddev The standard deviation of the token
    /// @return M The number of quote providers
    function _derivePriceFromUnderlyingVault(
        ISuperOracle superOracle,
        ISuperAsset superAsset,
        address USD,
        address token,
        address oracle
    )
        internal
        view
        returns (uint256 priceUSD, uint256 stddev, uint256 M)
    {
        address vaultAsset = IERC4626(token).asset();
        uint256 unitVaultAsset = 10 ** IERC20Metadata(vaultAsset).decimals();

        bytes32 AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

        try superOracle.getQuoteFromProvider(unitVaultAsset, vaultAsset, USD, AVERAGE_PROVIDER) returns (
            uint256 _priceUSD, uint256 _stddev, uint256, uint256 _m
        ) {
            priceUSD = _priceUSD;
            stddev = _stddev;
            M = _m;
        } catch {
            priceUSD = superOracle.getEmergencyPrice(vaultAsset);
            stddev = 0;
            M = 0;
        }

        uint256 pricePerShare = IYieldSourceOracle(oracle).getPricePerShare(token);
        if (priceUSD > 0) {
            priceUSD = pricePerShare.mulDiv(priceUSD, superAsset.getPrecision(), Math.Rounding.Floor);
        }
    }

    /// @dev Checks if the standard deviation is greater than the dispersion threshold
    /// @param stddev The standard deviation
    /// @param priceUSD The price in USD
    /// @return isDispersion True if the standard deviation is greater than the dispersion threshold
    function _isSTDDevDegged(
        address superAsset,
        uint256 stddev,
        uint256 priceUSD,
        uint256 dispersionThreshold
    )
        internal
        pure
        returns (bool)
    {
        // Calculate relative standard deviation
        uint256 relativeStdDev = Math.mulDiv(stddev, ISuperAsset(superAsset).getPrecision(), priceUSD);

        // Circuit Breaker for Dispersion
        if (relativeStdDev > dispersionThreshold) {
            return true;
        }
        return false;
    }

    /// @dev Checks if the token is depegged
    /// @param priceUSD The price of the token in USD
    /// @param assetPriceUSD The price of the asset in USD
    /// @return isDepeg True if the token is depegged
    function _isTokenDepeg(
        uint256 priceUSD,
        uint256 precision,
        uint256 assetPriceUSD,
        uint256 depegLowerThreshold,
        uint256 depegUpperThreshold
    )
        internal
        pure
        returns (bool isDepeg)
    {
        // NOTE: There should be no need to adjust for decimals since
        // the token specific decimals and
        // the Oracle Price decimals
        // can be different
        // Example, if we send 2 USDC to someone then the transferred amount is 2e6 since USDC has 6d
        // but the USDC price quoted in USD can have its own decimals, for example
        // if USDC depegs high and is worth 3 USD then its price quoted in a 18d oracle will be 3e18
        uint256 ratio = Math.mulDiv(priceUSD, precision, assetPriceUSD);

        if (ratio < depegLowerThreshold || ratio > depegUpperThreshold) {
            isDepeg = true;
        }
    }

    /// @dev Gets the price information for a token
    /// @param superOracle The super oracle
    /// @param superAsset The super asset
    /// @param USD The USD address
    /// @param token The token address
    /// @return priceUSD The price of the token in USD
    /// @return stddev The standard deviation of the token
    function _getPriceInfo(
        ISuperOracle superOracle,
        ISuperAsset superAsset,
        address USD,
        address token
    )
        internal
        view
        returns (uint256 priceUSD, uint256 stddev, uint256 M)
    {
        bytes32 AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");
        uint256 one = 10 ** IERC20Metadata(token).decimals();

        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(token);

        if (tokenData.isSupportedERC20) {
            try superOracle.getQuoteFromProvider(one, token, USD, AVERAGE_PROVIDER) returns (
                uint256 _priceUSD, uint256 _stddev, uint256, uint256 _m
            ) {
                priceUSD = _priceUSD;
                stddev = _stddev;
                M = _m;
            } catch {
                priceUSD = superOracle.getEmergencyPrice(token);
                M = 0;
            }
        } else if (tokenData.isSupportedUnderlyingVault) {
            (priceUSD, stddev, M) =
                _derivePriceFromUnderlyingVault(superOracle, superAsset, USD, token, tokenData.oracle);
        }
    }

    /// @dev Gets the depeg and dispersion status of a token
    /// @param args The arguments for the price calculation
    /// @param precision The precision of the token
    /// @param priceUSD The price of the token in USD
    /// @param stddev The standard deviation of the token
    /// @return isDepeg True if the token is depegged
    /// @return isDispersion True if the token has price dispersion
    function _getDepegAndDispersion(
        ISuperAsset.PriceArgs memory args,
        uint256 precision,
        uint256 priceUSD,
        uint256 stddev
    )
        internal
        view
        returns (bool isDepeg, bool isDispersion)
    {
        uint256 assetPriceUSD = _getAssetPriceUSD(args.superOracle, args.superAsset, args.usd);

        isDepeg = _isTokenDepeg(priceUSD, precision, assetPriceUSD, args.depegLowerThreshold, args.depegUpperThreshold);

        isDispersion = _isSTDDevDegged(args.superAsset, stddev, priceUSD, args.dispersionThreshold);
    }

    /// @dev Gets the price of the asset in USD
    /// @param superOracleAddress The address of the super oracle
    /// @param superAssetAddress The address of the super asset
    /// @param USD The address of the USD token
    /// @return assetPriceUSD The price of the asset in USD
    function _getAssetPriceUSD(
        address superOracleAddress,
        address superAssetAddress,
        address USD
    )
        internal
        view
        returns (uint256 assetPriceUSD)
    {
        bytes32 AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");
        address primaryAsset = ISuperAsset(superAssetAddress).getPrimaryAsset();
        uint256 oneUnitAsset = 10 ** IERC20Metadata(primaryAsset).decimals();

        ISuperOracle superOracle = ISuperOracle(superOracleAddress);

        try superOracle.getQuoteFromProvider(oneUnitAsset, primaryAsset, USD, AVERAGE_PROVIDER) returns (
            uint256 _priceUSD, uint256, uint256, uint256
        ) {
            assetPriceUSD = _priceUSD;
        } catch {
            assetPriceUSD = superOracle.getEmergencyPrice(primaryAsset);
        }
    }
}
