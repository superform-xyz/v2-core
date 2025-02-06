// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracle } from "../../interfaces/vendors/awesome-oracles/IOracle.sol";
import { IOracleRegistry } from "../../interfaces/accounting/IOracleRegistry.sol";

/// @title OracleRegistry
/// @author Superform Labs
/// @notice Registry for managing oracle providers and getting quotes
contract OracleRegistry is Ownable, IOracleRegistry, IOracle {
    /// @notice Mapping of base asset to array of oracle providers
    mapping(address base => mapping(uint256 provider => address oracle)) private oracles;

    /// @notice Timelock period for oracle updates
    uint256 private constant TIMELOCK_PERIOD = 1 weeks;
    uint256 private constant ORACLE_PROVIDER_AVERAGE = 0;
    uint256 private constant MAX_PROVIDERS = 10;

    /// @notice Pending oracle update
    PendingUpdate private pendingUpdate;

    constructor(
        address owner,
        address[] memory initialBases,
        uint256[] memory initialProviders,
        address[] memory initialOracleAddresses
    )
        Ownable(owner)
    {
        _configureOracles(initialBases, initialProviders, initialOracleAddresses);
    }

    /// @inheritdoc IOracleRegistry
    function queueOracleUpdate(
        address[] calldata bases,
        uint256[] calldata providers,
        address[] calldata oracleAddresses
    )
        external
        onlyOwner
    {
        if (pendingUpdate.timestamp != 0) revert PENDING_UPDATE_EXISTS();

        pendingUpdate = PendingUpdate({
            bases: bases,
            providers: providers,
            oracleAddresses: oracleAddresses,
            timestamp: block.timestamp
        });

        emit OracleUpdateQueued(bases, providers, oracleAddresses, block.timestamp);
    }

    /// @inheritdoc IOracleRegistry
    function executeOracleUpdate() external {
        if (pendingUpdate.timestamp == 0) revert NO_ORACLES_CONFIGURED();
        if (block.timestamp < pendingUpdate.timestamp + TIMELOCK_PERIOD) revert TIMELOCK_NOT_ELAPSED();

        _configureOracles(pendingUpdate.bases, pendingUpdate.providers, pendingUpdate.oracleAddresses);

        emit OracleUpdateExecuted(pendingUpdate.bases, pendingUpdate.providers, pendingUpdate.oracleAddresses);

        delete pendingUpdate;
    }

    /// @inheritdoc IOracleRegistry
    function getOracleAddress(address base, uint256 provider) external view returns (address oracle) {
        oracle = oracles[base][provider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();
    }

    /// @inheritdoc IOracleRegistry
    function getQuoteFromProvider(
        uint256 baseAmount,
        address base,
        address quote,
        uint256 oracleProvider
    )
        external
        view
        returns (uint256 quoteAmount)
    {
        address oracle = oracles[base][oracleProvider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();

        // If average (0), calculate average of all oracles
        if (oracleProvider == ORACLE_PROVIDER_AVERAGE) {
            uint256 total;
            uint256 count;

            // Start from index 1 to skip the average provider
            for (uint256 i = 1; i < MAX_PROVIDERS;) {
                address providerOracle = oracles[base][i];
                if (providerOracle == address(0)) break; // Stop if we hit an empty slot

                total += IOracle(providerOracle).getQuote(baseAmount, base, quote);
                unchecked {
                    ++count;
                    ++i;
                }
            }

            if (count == 0) revert NO_ORACLES_CONFIGURED();
            quoteAmount = total / count;
        } else {
            quoteAmount = IOracle(oracle).getQuote(baseAmount, base, quote);
        }
    }

    /// @inheritdoc IOracle
    function getQuote(uint256 baseAmount, address base, address quote) external view returns (uint256 quoteAmount) {
        // By default use average (0) when called through IOracle interface
        return this.getQuoteFromProvider(baseAmount, base, quote, ORACLE_PROVIDER_AVERAGE);
    }

    /// @notice Internal function to configure oracles
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param oracleAddresses Array of oracle addresses
    function _configureOracles(
        address[] memory bases,
        uint256[] memory providers,
        address[] memory oracleAddresses
    )
        private
    {
        uint256 length = bases.length;
        if (length != providers.length || length != oracleAddresses.length) revert ARRAY_LENGTH_MISMATCH();

        for (uint256 i = 0; i < length;) {
            oracles[bases[i]][providers[i]] = oracleAddresses[i];
            unchecked {
                ++i;
            }
        }

        emit OraclesConfigured(bases, providers, oracleAddresses);
    }
}
