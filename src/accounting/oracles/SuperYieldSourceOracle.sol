// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
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
        uint256 baseAmount = IYieldSourceOracle(yieldSourceOracle).getPricePerShare(yieldSourceAddress);

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
            length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length ||
            length != oracles.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        pricesPerShareQuote = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            // Get price per share in base asset terms
            uint256 baseAmount = IYieldSourceOracle(yieldSourceOracles[i]).getPricePerShare(yieldSourceAddresses[i]);

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
                || vars.length != quoteAddresses.length || vars.length != yieldSourceOracles.length || vars.length != oracles.length
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
        if (length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length || length != oracles.length) {
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
}
