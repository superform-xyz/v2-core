// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IPMarket } from "@pendle/interfaces/IPMarket.sol";
import { IStandardizedYield } from "@pendle/interfaces/IStandardizedYield.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IOracle } from "../../vendor/awesome-oracles/IOracle.sol";
// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperYieldSourceOracle } from "../../interfaces/accounting/ISuperYieldSourceOracle.sol";

/// @title SuperYieldSourceOracle
/// @author Superform Labs
/// @notice Provides quoting functionality for yield sources using a SuperOracle.
contract SuperYieldSourceOracle is ISuperYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                        GENERALIZED QUOTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperYieldSourceOracle
    function getPricePerShareQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote,
        address oracle
    )
        external
        view
        override // Added override
        returns (uint256 pricePerShareQuote)
    {
        // Get price per share in base asset terms
        uint256 baseAmount = _ppsToBaseAmount(yieldSourceAddress, yieldSourceOracle, base);

        // Convert to quote asset using oracle
        pricePerShareQuote = IOracle(oracle).getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLByOwnerOfSharesQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address ownerOfShares,
        address base,
        address quote,
        address oracle
    )
        external
        view
        override // Added override
        returns (uint256 tvlQuote)
    {
        // Get TVL in base asset terms
        uint256 baseAmount =
            IYieldSourceOracle(yieldSourceOracle).getTVLByOwnerOfShares(yieldSourceAddress, ownerOfShares);

        // Convert to quote asset using oracle
        tvlQuote = IOracle(oracle).getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote,
        address oracle
    )
        external
        view
        override // Added override
        returns (uint256 tvlQuote)
    {
        // Get TVL in base asset terms
        uint256 baseAmount = IYieldSourceOracle(yieldSourceOracle).getTVL(yieldSourceAddress);

        // Convert to quote asset using oracle
        tvlQuote = IOracle(oracle).getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getPricePerShareMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses,
        address[] memory quoteAddresses,
        address[] memory oracles
    )
        external
        view
        override // Added override
        returns (uint256[] memory pricesPerShareQuote)
    {
        uint256 length = yieldSourceAddresses.length;
        if (
            length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length
                || length != oracles.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        pricesPerShareQuote = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            // Get price per share in base asset terms
            uint256 baseAmount = _ppsToBaseAmount(yieldSourceAddresses[i], yieldSourceOracles[i], baseAddresses[i]);
            // Convert to quote asset using oracle
            pricesPerShareQuote[i] = IOracle(oracles[i]).getQuote(baseAmount, baseAddresses[i], quoteAddresses[i]);
        }
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLByOwnerOfSharesMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        address[] memory quoteAddresses,
        address[] memory oracles
    )
        external
        view
        override // Added override
        returns (uint256[][] memory userTvlsQuote, uint256[] memory totalTvlsQuote)
    {
        TVLMultipleQuoteVars memory vars; // Using a struct to avoid stack too deep
        vars.length = yieldSourceAddresses.length;
        if (
            vars.length != ownersOfShares.length || vars.length != baseAddresses.length
                || vars.length != quoteAddresses.length || vars.length != yieldSourceOracles.length
                || vars.length != oracles.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        userTvlsQuote = new uint256[][](vars.length);
        totalTvlsQuote = new uint256[](vars.length);

        for (uint256 i; i < vars.length; ++i) {
            vars.yieldSource = yieldSourceAddresses[i];
            vars.owners = ownersOfShares[i];
            vars.ownersLength = vars.owners.length;
            vars.totalTvlQuote = 0; // Renamed from totalTvlUSD

            userTvlsQuote[i] = new uint256[](vars.ownersLength);

            for (uint256 j = 0; j < vars.ownersLength; ++j) {
                // Get TVL in base asset terms
                vars.baseAmount =
                    IYieldSourceOracle(yieldSourceOracles[i]).getTVLByOwnerOfShares(vars.yieldSource, vars.owners[j]);

                // Convert to quote asset using oracle registry
                vars.userTvlQuote = IOracle(oracles[i]).getQuote(vars.baseAmount, baseAddresses[i], quoteAddresses[i]);
                userTvlsQuote[i][j] = vars.userTvlQuote;
                vars.totalTvlQuote += vars.userTvlQuote;
            }

            totalTvlsQuote[i] = vars.totalTvlQuote;
        }
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses,
        address[] memory quoteAddresses,
        address[] memory oracles
    )
        external
        view
        override // Added override
        returns (uint256[] memory tvlsQuote)
    {
        uint256 length = yieldSourceAddresses.length;
        if (
            length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length
                || length != oracles.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        tvlsQuote = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            // Get TVL in base asset terms
            uint256 baseAmount = IYieldSourceOracle(yieldSourceOracles[i]).getTVL(yieldSourceAddresses[i]);

            // Convert to quote asset using oracle
            tvlsQuote[i] = IOracle(oracles[i]).getQuote(baseAmount, baseAddresses[i], quoteAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE ORACLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperYieldSourceOracle
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles
    )
        external
        view
        returns (uint256[] memory pricesPerShare)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != yieldSourceOracles.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }
        pricesPerShare = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            pricesPerShare[i] = IYieldSourceOracle(yieldSourceOracles[i]).getPricePerShare(yieldSourceAddresses[i]);
        }
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory ownersOfShares
    )
        external
        view
        returns (uint256[] memory userTvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != yieldSourceOracles.length || length != ownersOfShares.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }
        userTvls = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            userTvls[i] = IYieldSourceOracle(yieldSourceOracles[i]).getTVLByOwnerOfShares(
                yieldSourceAddresses[i], ownersOfShares[i]
            );
        }
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLMultiple(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles
    )
        external
        view
        returns (uint256[] memory tvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != yieldSourceOracles.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }
        tvls = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            tvls[i] = IYieldSourceOracle(yieldSourceOracles[i]).getTVL(yieldSourceAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _safeBaseDecimals(address base) internal view returns (uint8) {
        // Fallback to 18 if token is non-standard or reverts
        try IERC20Metadata(base).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _detectFlavor(address yieldSourceAddress) internal view returns (Flavor) {
        // Probe 1: Pendle Market (has readTokens())
        try IPMarket(yieldSourceAddress).readTokens() {
            return Flavor.PendlePT;
        } catch { }

        // Probe 2: ERC-5115 (has exchangeRate())
        try IStandardizedYield(yieldSourceAddress).exchangeRate() returns (uint256) {
            return Flavor.ERC5115;
        } catch { }

        return Flavor.Unknown;
    }

    /// Normalize PPS to **base token units** if it was a 1e18 ratio.
    /// Otherwise return as-is (already base-denominated).
    function _ppsToBaseAmount(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base
    )
        internal
        view
        returns (uint256 baseAmount)
    {
        uint256 pps = IYieldSourceOracle(yieldSourceOracle).getPricePerShare(yieldSourceAddress);
        Flavor f = _detectFlavor(yieldSourceAddress);

        if (f == Flavor.PendlePT || f == Flavor.ERC5115) {
            // pps is a ratio (assets/share) scaled 1e18. Convert to base units:
            // baseAmount = pps * 10^baseDecimals / 1e18
            uint8 baseDec = _safeBaseDecimals(base);
            return Math.mulDiv(pps, 10 ** uint256(baseDec), 1e18);
        }

        // Non-ratio adapters: treat pps as already in base units
        return pps;
    }
}
