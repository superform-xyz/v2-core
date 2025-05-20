// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// External
import { IOracle } from "../../vendor/awesome-oracles/IOracle.sol";
// Superform
import { IYieldSourceOracle } from "../../core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperYieldSourceOracle } from "../interfaces/ISuperYieldSourceOracle.sol";

/// @title SuperYieldSourceOracle
/// @author Superform Labs
/// @notice Provides quoting functionality for yield sources using a SuperOracle.
contract SuperYieldSourceOracle is ISuperYieldSourceOracle {
    IOracle public immutable superOracle;

    /// @dev Thrown when array lengths do not match in batch functions.
    error ARRAY_LENGTH_MISMATCH();

    constructor(address superOracle_) {
        superOracle = IOracle(superOracle_);
    }

    /*//////////////////////////////////////////////////////////////
                        GENERALIZED QUOTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperYieldSourceOracle
    function getPricePerShareQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote
    )
        external
        view
        override // Added override
        returns (uint256 pricePerShareQuote)
    {
        IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracle);
        if (!yS.isValidUnderlyingAsset(yieldSourceAddress, base)) revert INVALID_BASE_ASSET();

        // Get price per share in base asset terms
        uint256 baseAmount = yS.getPricePerShare(yieldSourceAddress);

        // Convert to quote asset using oracle registry
        pricePerShareQuote = superOracle.getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLByOwnerOfSharesQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address ownerOfShares,
        address base,
        address quote
    )
        external
        view
        override // Added override
        returns (uint256 tvlQuote)
    {
        IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracle);
        if (!yS.isValidUnderlyingAsset(yieldSourceAddress, base)) revert INVALID_BASE_ASSET();

        // Get TVL in base asset terms
        uint256 baseAmount = yS.getTVLByOwnerOfShares(yieldSourceAddress, ownerOfShares);

        // Convert to quote asset using oracle registry
        tvlQuote = superOracle.getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLQuote(
        address yieldSourceAddress,
        address yieldSourceOracle,
        address base,
        address quote
    )
        external
        view
        override // Added override
        returns (uint256 tvlQuote)
    {
        IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracle);
        if (!yS.isValidUnderlyingAsset(yieldSourceAddress, base)) revert INVALID_BASE_ASSET();

        // Get TVL in base asset terms
        uint256 baseAmount = yS.getTVL(yieldSourceAddress);

        // Convert to quote asset using oracle registry
        tvlQuote = superOracle.getQuote(baseAmount, base, quote);
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getPricePerShareMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[] memory baseAddresses,
        address[] memory quoteAddresses
    )
        external
        view
        override // Added override
        returns (uint256[] memory pricesPerShareQuote)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        pricesPerShareQuote = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            if (!yS.isValidUnderlyingAsset(yieldSourceAddresses[i], baseAddresses[i])) {
                revert INVALID_BASE_ASSET();
            }

            // Get price per share in base asset terms
            uint256 baseAmount = yS.getPricePerShare(yieldSourceAddresses[i]);

            // Convert to quote asset using oracle registry
            pricesPerShareQuote[i] = superOracle.getQuote(baseAmount, baseAddresses[i], quoteAddresses[i]);
        }
    }

    /// @inheritdoc ISuperYieldSourceOracle
    function getTVLByOwnerOfSharesMultipleQuote(
        address[] memory yieldSourceAddresses,
        address[] memory yieldSourceOracles,
        address[][] memory ownersOfShares,
        address[] memory baseAddresses,
        address[] memory quoteAddresses
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
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            if (!yS.isValidUnderlyingAsset(vars.yieldSource, baseAddresses[i])) {
                revert INVALID_BASE_ASSET();
            }

            for (uint256 j = 0; j < vars.ownersLength; ++j) {
                // Get TVL in base asset terms
                vars.baseAmount = yS.getTVLByOwnerOfShares(vars.yieldSource, vars.owners[j]);

                // Convert to quote asset using oracle registry
                vars.userTvlQuote = superOracle.getQuote(vars.baseAmount, baseAddresses[i], quoteAddresses[i]); // Renamed
                    // from userTvlUSD
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
        address[] memory quoteAddresses
    )
        external
        view
        override // Added override
        returns (uint256[] memory tvlsQuote)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != baseAddresses.length || length != quoteAddresses.length || length != yieldSourceOracles.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        tvlsQuote = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            if (!yS.isValidUnderlyingAsset(yieldSourceAddresses[i], baseAddresses[i])) {
                revert INVALID_BASE_ASSET();
            }

            // Get TVL in base asset terms
            uint256 baseAmount = yS.getTVL(yieldSourceAddresses[i]);

            // Convert to quote asset using oracle registry
            tvlsQuote[i] = superOracle.getQuote(baseAmount, baseAddresses[i], quoteAddresses[i]);
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
        pricesPerShare = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            pricesPerShare[i] = yS.getPricePerShare(yieldSourceAddresses[i]);
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
        userTvls = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            userTvls[i] = yS.getTVLByOwnerOfShares(yieldSourceAddresses[i], ownersOfShares[i]);
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
        tvls = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            IYieldSourceOracle yS = IYieldSourceOracle(yieldSourceOracles[i]);
            tvls[i] = yS.getTVL(yieldSourceAddresses[i]);
        }
    }
    
    
}
