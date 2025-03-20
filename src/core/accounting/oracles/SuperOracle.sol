// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// external
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IOracle } from "../../../vendor/awesome-oracles/IOracle.sol";
import { AggregatorV3Interface } from "../../../vendor/chainlink/AggregatorV3Interface.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BoringERC20 } from "../../../vendor/BoringSolidity/BoringERC20.sol";

// Superform
import { ISuperOracle } from "../../interfaces/accounting/ISuperOracle.sol";

/// @title SuperOracle
/// @author Superform Labs
/// @notice Registry for managing oracle providers and getting quotes
contract SuperOracle is Ownable2Step, ISuperOracle, IOracle {
    using BoringERC20 for IERC20;

    /// @notice Mapping of base asset to array of oracle providers
    mapping(address base => mapping(uint256 provider => address oracle)) private usdQuotedOracle;

    /// @notice Mapping of provider to max staleness period
    mapping(uint256 provider => uint256 maxStaleness) public providerMaxStaleness;

    uint256 public maxStaleness;

    /// @notice There is a single supported quote in this oracle system: USD
    address private constant USD = address(840);

    /// @notice Timelock period for oracle updates
    uint256 private constant TIMELOCK_PERIOD = 1 weeks;
    uint256 private constant ORACLE_PROVIDER_AVERAGE = 0;
    uint256 private constant MAX_PROVIDERS = 10;

    /// @notice Pending oracle update
    PendingUpdate private pendingUpdate;

    constructor(
        address owner_,
        address[] memory initialBases,
        uint256[] memory initialProviders,
        address[] memory initialOracleAddresses
    )
        Ownable(owner_)
    {
        if (owner_ == address(0)) revert ZERO_ADDRESS();

        maxStaleness = 1 days;

        uint256 length = initialProviders.length;
        // Set default staleness for initial providers
        for (uint256 i; i < length; ++i) {
            providerMaxStaleness[initialProviders[i]] = maxStaleness;
        }
        _configureOracles(initialBases, initialProviders, initialOracleAddresses);
    }

    // -- Get quote functions --

    /// @inheritdoc ISuperOracle
    function getQuoteFromProvider(
        uint256 baseAmount,
        address base,
        address quote,
        uint256 oracleProvider
    )
        public
        view
        returns (uint256 quoteAmount)
    {
        address oracle = usdQuotedOracle[base][oracleProvider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();

        // If average (0), calculate average of all oracles
        if (oracleProvider == ORACLE_PROVIDER_AVERAGE) {
            uint256 total;
            uint256 count;

            // Start from index 1 to skip the average provider
            for (uint256 i = 1; i < MAX_PROVIDERS; ++i) {
                address providerOracle = usdQuotedOracle[base][i];
                if (providerOracle == address(0)) break; // Stop if we hit an empty slot

                uint256 quote_ = _getQuoteFromOracle(providerOracle, baseAmount, base, quote, false, i);
                /// @dev we don't revert on error, we just skip the oracle value
                if (quote_ > 0) {
                    total += quote_;
                    unchecked {
                        ++count;
                    }
                }
            }

            if (count == 0) revert NO_VALID_REPORTED_PRICES();
            quoteAmount = total / count;
        } else {
            quoteAmount = _getQuoteFromOracle(oracle, baseAmount, base, quote, true, oracleProvider);
        }
    }

    /// @inheritdoc IOracle
    function getQuote(uint256 baseAmount, address base, address quote) external view returns (uint256 quoteAmount) {
        // Extract provider from quote address if it's ISO 4217 code
        // Note: it is always assumed a provider is encoded in the quote address and not in a base
        uint256 provider = _extractProvider(quote);

        // If no provider encoded or provider has no oracle, use average
        if (provider == 0 || usdQuotedOracle[base][provider] == address(0)) {
            provider = ORACLE_PROVIDER_AVERAGE;
        }

        return getQuoteFromProvider(baseAmount, base, quote, provider);
    }

    // -- External configuration functions --
    /// @inheritdoc ISuperOracle
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        maxStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function setProviderMaxStaleness(uint256 provider, uint256 newMaxStaleness) external onlyOwner {
        if (newMaxStaleness > maxStaleness) {
            revert MAX_STALENESS_EXCEEDED();
        }
        providerMaxStaleness[provider] = newMaxStaleness;
        emit ProviderMaxStalenessUpdated(provider, newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function queueOracleUpdate(
        address[] calldata bases,
        uint256[] calldata providers,
        address[] calldata oracleAddresses
    )
        external
        onlyOwner
    {
        if (pendingUpdate.timestamp != 0) revert PENDING_UPDATE_EXISTS();
        uint256 providersLength = providers.length;
        if (providersLength > MAX_PROVIDERS) {
            revert MAX_PROVIDERS_EXCEEDED();
        }
        if (bases.length != providersLength || providersLength != oracleAddresses.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }
      
        pendingUpdate = PendingUpdate({
            bases: bases,
            providers: providers,
            oracleAddresses: oracleAddresses,
            timestamp: block.timestamp
        });

        emit OracleUpdateQueued(bases, providers, oracleAddresses, block.timestamp);
    }

    /// @inheritdoc ISuperOracle
    function executeOracleUpdate() external {
        if (pendingUpdate.timestamp == 0) revert NO_PENDING_UPDATE();
        if (block.timestamp < pendingUpdate.timestamp + TIMELOCK_PERIOD) revert TIMELOCK_NOT_ELAPSED();

        _configureOracles(pendingUpdate.bases, pendingUpdate.providers, pendingUpdate.oracleAddresses);

        emit OracleUpdateExecuted(pendingUpdate.bases, pendingUpdate.providers, pendingUpdate.oracleAddresses);

        delete pendingUpdate;
    }

    /// @inheritdoc ISuperOracle
    function getOracleAddress(address base, uint256 provider) external view returns (address oracle) {
        oracle = usdQuotedOracle[base][provider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();
    }

    // -- Internal functions --

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
        if (length > MAX_PROVIDERS) {
            // @dev there shouldn't be a case where this happens
            // it's already validated on `queueOracleUpdate`
            // but double check to be safe
            revert MAX_PROVIDERS_EXCEEDED();
        }
        if (length != providers.length || length != oracleAddresses.length) revert ARRAY_LENGTH_MISMATCH();

        for (uint256 i = 0; i < length; ++i) {
            usdQuotedOracle[bases[i]][providers[i]] = oracleAddresses[i];
            // Set default staleness if not already set
            if (providerMaxStaleness[providers[i]] == 0) {
                providerMaxStaleness[providers[i]] = maxStaleness;
            }
        }

        emit OraclesConfigured(bases, providers, oracleAddresses);
    }

    function _getOracleDecimals(AggregatorV3Interface oracle_) internal view returns (uint8) {
        return oracle_.decimals();
    }

    function _getQuoteFromOracle(
        address oracle,
        uint256 baseAmount,
        address base,
        address quote,
        bool revertOnError,
        uint256 provider
    )
        internal
        view
        returns (uint256 quoteAmount)
    {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(oracle).latestRoundData();

        // Validate data
        if (answer <= 0 || block.timestamp - updatedAt > providerMaxStaleness[provider]) {
            if (revertOnError) revert ORACLE_UNTRUSTED_DATA();
            return 0;
        }

        // Get decimals
        uint8 feedDecimals = _getOracleDecimals(AggregatorV3Interface(oracle));
        uint8 baseDecimals = IERC20(base).safeDecimals();
        uint8 quoteDecimals = IERC20(quote).safeDecimals();

        // Calculate quote amount with proper decimal scaling
        quoteAmount =
            (baseAmount * uint256(answer) * (10 ** quoteDecimals)) / ((10 ** baseDecimals) * (10 ** feedDecimals));
    }

    /// @notice Extract provider ID from quote address
    /// @param quote The quote address
    /// @return provider The provider ID (0 if not encoded)
    function _extractProvider(address quote) internal pure returns (uint256 provider) {
        // Extract provider from upper bits
        provider = uint160(quote) >> 20;

        // Verify the lower 20 bits match a supported quote
        address extractedQuote = address(uint160(quote) & ((1 << 20) - 1));
        if (extractedQuote != USD) revert UNSUPPORTED_QUOTE();
    }
}
