// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

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
/// @notice Oracle for Superform
abstract contract SuperOracleBase is Ownable2Step, ISuperOracle, IOracle {
    using BoringERC20 for IERC20;

    /// @notice Mapping of feed to max staleness period
    mapping(address feed => uint256 maxStaleness) public feedMaxStaleness;

    uint256 public maxDefaultStaleness;

    /// @notice Mapping of base asset to array of oracle providers to oracle feed address
    mapping(address base => mapping(address quote => mapping(bytes32 provider => address feed))) internal oracles;

    /// @notice Array of active provider ids
    bytes32[] public activeProviders;

    /// @notice Timelock period for oracle updates
    uint256 internal constant TIMELOCK_PERIOD = 1 weeks;
    bytes32 internal constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

    /// @notice Pending oracle update
    PendingUpdate internal pendingUpdate;

    /// @notice Pending provider removal
    PendingRemoval internal pendingRemoval;

    constructor(
        address owner_,
        address[] memory bases,
        address[] memory quotes,
        bytes32[] memory providers,
        address[] memory feeds
    )
        Ownable(owner_)
    {
        maxDefaultStaleness = 1 days;

        // validate oracle inputs
        _validateOracleInputs(bases, quotes, providers, feeds);

        // configure oracles
        _configureOracles(bases, quotes, providers, feeds);

        // set default staleness for feeds
        uint256 length = feeds.length;
        for (uint256 i; i < length; ++i) {
            feedMaxStaleness[feeds[i]] = maxDefaultStaleness;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperOracle
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        maxDefaultStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) external onlyOwner {
        _setFeedMaxStaleness(feed, newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function setFeedMaxStalenessBatch(
        address[] calldata feeds,
        uint256[] calldata newMaxStalenessList
    )
        external
        onlyOwner
    {
        uint256 length = feeds.length;
        if (length == 0) revert ZERO_ARRAY_LENGTH();
        if (length != newMaxStalenessList.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        for (uint256 i; i < length; ++i) {
            _setFeedMaxStaleness(feeds[i], newMaxStalenessList[i]);
        }
    }

    /// @inheritdoc ISuperOracle
    function queueOracleUpdate(
        address[] calldata bases,
        address[] calldata quotes,
        bytes32[] calldata providers,
        address[] calldata feeds
    )
        external
        onlyOwner
    {
        if (pendingUpdate.timestamp != 0) revert PENDING_UPDATE_EXISTS();

        uint256 length = bases.length;
        if (length != quotes.length || length != providers.length || length != feeds.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        _validateOracleInputs(bases, quotes, providers, feeds);

        pendingUpdate = PendingUpdate({
            bases: bases,
            quotes: quotes,
            providers: providers,
            feeds: feeds,
            timestamp: block.timestamp
        });

        emit OracleUpdateQueued(bases, quotes, providers, feeds, block.timestamp);
    }

    /// @inheritdoc ISuperOracle
    function executeOracleUpdate() external {
        if (pendingUpdate.timestamp == 0) revert NO_PENDING_UPDATE();
        if (block.timestamp < pendingUpdate.timestamp + TIMELOCK_PERIOD) revert TIMELOCK_NOT_ELAPSED();

        _configureOracles(pendingUpdate.bases, pendingUpdate.quotes, pendingUpdate.providers, pendingUpdate.feeds);

        emit OracleUpdateExecuted(
            pendingUpdate.bases, pendingUpdate.quotes, pendingUpdate.providers, pendingUpdate.feeds
        );

        delete pendingUpdate;
    }

    /// @inheritdoc ISuperOracle
    function getOracleAddress(address base, address quote, bytes32 provider) external view returns (address oracle) {
        oracle = oracles[base][quote][provider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();
    }

    /// @inheritdoc ISuperOracle
    function queueProviderRemoval(bytes32[] calldata providers) external onlyOwner {
        if (pendingRemoval.timestamp != 0) revert PENDING_UPDATE_EXISTS();

        uint256 length = providers.length;
        if (length == 0) revert ZERO_ARRAY_LENGTH();

        pendingRemoval = PendingRemoval({ providers: providers, timestamp: block.timestamp });

        emit ProviderRemovalQueued(providers, block.timestamp);
    }

    /// @inheritdoc ISuperOracle
    function executeProviderRemoval() external {
        if (pendingRemoval.timestamp == 0) revert NO_PENDING_UPDATE();
        if (block.timestamp < pendingRemoval.timestamp + TIMELOCK_PERIOD) revert TIMELOCK_NOT_ELAPSED();

        bytes32[] memory providersToRemove = pendingRemoval.providers;

        // Loop through each provider to remove
        for (uint256 i = 0; i < providersToRemove.length; i++) {
            bytes32 providerToRemove = providersToRemove[i];

            // Find the provider in activeProviders array
            for (uint256 j = 0; j < activeProviders.length; j++) {
                if (activeProviders[j] == providerToRemove) {
                    // Replace the provider to remove with the last provider in the array
                    if (j < activeProviders.length - 1) {
                        activeProviders[j] = activeProviders[activeProviders.length - 1];
                    }

                    // Remove the last element
                    activeProviders.pop();
                    break;
                }
            }
        }

        emit ProviderRemovalExecuted(providersToRemove);

        delete pendingRemoval;
    }

    /// @inheritdoc ISuperOracle
    function getActiveProviders() external view returns (bytes32[] memory) {
        return activeProviders;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNALVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperOracle
    function getQuoteFromProvider(
        uint256 baseAmount,
        address base,
        address quote,
        bytes32 oracleProvider
    )
        public
        view
        virtual
        returns (uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
    {
        // If average, calculate average of all oracles
        if (oracleProvider == AVERAGE_PROVIDER) {
            uint256 length = activeProviders.length;
            uint256[] memory validQuotes = new uint256[](length);
            uint256 count;
            (quoteAmount, validQuotes, count) = _getAverageQuote(base, quote, baseAmount, length);
            totalProviders = length;
            availableProviders = count;
            deviation = _calculateStdDev(validQuotes);
        } else {
            quoteAmount = _getQuoteFromOracle(oracles[base][quote][oracleProvider], baseAmount, base, quote, true);
            deviation = 0;
            totalProviders = 1;
            availableProviders = 1;
        }
    }

    /// @inheritdoc IOracle
    function getQuote(
        uint256 baseAmount,
        address base,
        address quote
    )
        external
        view
        virtual
        returns (uint256 quoteAmount)
    {
        // using IOracle interface we always assume average provider
        (quoteAmount,,,) = getQuoteFromProvider(baseAmount, base, quote, AVERAGE_PROVIDER);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateOracleInputs(
        address[] memory bases,
        address[] memory quotes,
        bytes32[] memory providers,
        address[] memory feeds
    )
        internal
        pure
    {
        uint256 length = bases.length;
        for (uint256 i; i < length; ++i) {
            address base = bases[i];
            address quote = quotes[i];
            bytes32 provider = providers[i];
            address feed = feeds[i];

            if (provider == bytes32(0)) revert ZERO_PROVIDER();
            if (provider == AVERAGE_PROVIDER) revert AVERAGE_PROVIDER_NOT_ALLOWED();
            if (base == address(0) || quote == address(0) || feed == address(0)) revert ZERO_ADDRESS();
        }
    }

    function _setFeedMaxStaleness(address feed, uint256 newMaxStaleness) internal {
        if (newMaxStaleness > maxDefaultStaleness) {
            revert MAX_STALENESS_EXCEEDED();
        }
        if (newMaxStaleness == 0) {
            newMaxStaleness = maxDefaultStaleness;
        }
        feedMaxStaleness[feed] = newMaxStaleness;
        emit FeedMaxStalenessUpdated(feed, newMaxStaleness);
    }

    function _getQuoteFromOracle(
        address oracle,
        uint256 baseAmount,
        address base,
        address quote,
        bool revertOnError
    )
        internal
        view
        virtual
        returns (uint256 quoteAmount)
    {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(oracle).latestRoundData();

        // Validate data
        if (answer <= 0 || block.timestamp - updatedAt > feedMaxStaleness[oracle]) {
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

    function _getAverageQuote(
        address base,
        address quote,
        uint256 baseAmount,
        uint256 numberOfProviders
    )
        internal
        view
        virtual
        returns (uint256 quoteAmount, uint256[] memory validQuotes, uint256 count)
    {
        uint256 total;
        // Create a temporary array to store valid quotes
        uint256[] memory tempQuotes = new uint256[](numberOfProviders);

        // Loop through all active providers
        for (uint256 i = 0; i < numberOfProviders; ++i) {
            bytes32 provider = activeProviders[i];
            address providerOracle = oracles[base][quote][provider];
            if (providerOracle == address(0)) revert NO_ORACLES_CONFIGURED();

            uint256 quote_ = _getQuoteFromOracle(providerOracle, baseAmount, base, quote, false);
            /// @dev we don't revert on error, we just skip the oracle value
            if (quote_ > 0) {
                total += quote_;
                tempQuotes[count] = quote_;
                unchecked {
                    ++count;
                }
            }
        }
        if (count == 0) revert NO_VALID_REPORTED_PRICES();

        // Create a new array with the exact size needed
        validQuotes = new uint256[](count);

        // Copy valid quotes to the properly sized array
        for (uint256 i; i < count; i++) {
            validQuotes[i] = tempQuotes[i];
        }

        quoteAmount = total / count;
    }

    function _getOracleDecimals(AggregatorV3Interface oracle_) internal view virtual returns (uint8) {
        return oracle_.decimals();
    }

    function _calculateStdDev(uint256[] memory values) internal pure virtual returns (uint256 stddev) {
        uint256 length = values.length;
        uint256 sum = 0;
        uint256 count = 0;
        for (uint256 i; i < length; ++i) {
            if (values[i] == 0) continue;
            sum += values[i];
            count++;
        }
        if (count < 2) return 0;

        uint256 mean = sum / count;
        uint256 sumSquaredDiff = 0;
        for (uint256 i; i < length; ++i) {
            if (values[i] == 0) continue;

            uint256 diff;
            if (values[i] >= mean) {
                diff = values[i] - mean;
            } else {
                diff = mean - values[i];
            }

            uint256 squaredDiff = diff * diff;
            sumSquaredDiff += squaredDiff;
        }

        uint256 variance = sumSquaredDiff / count;
        return _sqrt(variance);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _configureOracles(
        address[] memory bases,
        address[] memory quotes,
        bytes32[] memory providers,
        address[] memory feeds
    )
        internal
    {
        uint256 length = bases.length;

        for (uint256 i; i < length; ++i) {
            address base = bases[i];
            address quote = quotes[i];
            bytes32 provider = providers[i];
            address feed = feeds[i];

            oracles[base][quote][provider] = feed;

            // Update activeProviders array - add provider if not already present
            bool providerExists = false;
            uint256 activeProvidersLength = activeProviders.length;
            for (uint256 j; j < activeProvidersLength; ++j) {
                if (activeProviders[j] == provider) {
                    providerExists = true;
                    break;
                }
            }

            if (!providerExists) {
                activeProviders.push(provider);
            }
        }
    }
}
