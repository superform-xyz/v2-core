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

    /// @notice Mapping of base asset to array of oracle providers
    /// @dev provider 0 (`ORACLE_PROVIDER_AVERAGE`) is the average provider
    ///      1 - Chainlink ?
    ///      2 - ...
    ///      3 - ...
    /// @dev quote uses address(isoCode)  https://en.wikipedia.org/wiki/ISO_4217#Active_codes
    ///      address(840) for USD
    mapping(address base => mapping(address quote => mapping(uint256 provider => address feed))) internal oracles;

    /// @notice Timelock period for oracle updates
    uint256 internal constant TIMELOCK_PERIOD = 1 weeks;
    uint256 internal constant ORACLE_PROVIDER_AVERAGE = 0;
    uint256 internal constant MAX_PROVIDERS = 10;

    /// @notice Pending oracle update
    PendingUpdate internal pendingUpdate;

    constructor(
        address owner_,
        address[] memory bases,
        address[] memory quotes,
        uint256[] memory providers,
        address[] memory feeds
    )
        Ownable(owner_)
    {
        if (owner_ == address(0)) revert ZERO_ADDRESS();

        maxDefaultStaleness = 1 days;

        // configure oracles
        _configureOracles(bases, quotes, providers, feeds);

        // set default staleness for feeds
        uint256 length = feeds.length;
        for (uint256 i; i < length; ++i) {
            feedMaxStaleness[feeds[i]] = maxDefaultStaleness;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
        virtual
        returns (uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders)
    {
        // If average (0), calculate average of all oracles
        if (oracleProvider == ORACLE_PROVIDER_AVERAGE) {
            uint256[] memory validQuotes = new uint256[](MAX_PROVIDERS);
            uint256 count;
            (quoteAmount, validQuotes, count) = _getAverageQuote(base, quote, baseAmount);
            totalProviders = MAX_PROVIDERS;
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
        // Extract provider from quote address if it's ISO 4217 code; from upper bits
        uint256 provider = uint160(quote) >> 20;

        // If no provider encoded or provider has no oracle, use average
        if (provider == 0 || oracles[base][quote][provider] == address(0)) {
            provider = ORACLE_PROVIDER_AVERAGE;
        }

        (quoteAmount,,,) = getQuoteFromProvider(baseAmount, base, quote, provider);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // -- External configuration functions --
    /// @inheritdoc ISuperOracle
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        maxDefaultStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) external onlyOwner {
        if (newMaxStaleness > maxDefaultStaleness) {
            revert MAX_STALENESS_EXCEEDED();
        }
        if (newMaxStaleness == 0) {
            newMaxStaleness = maxDefaultStaleness;
        }
        feedMaxStaleness[feed] = newMaxStaleness;
        emit FeedMaxStalenessUpdated(feed, newMaxStaleness);
    }

    /// @inheritdoc ISuperOracle
    function queueOracleUpdate(
        address[] calldata bases,
        address[] calldata quotes,
        uint256[] calldata providers,
        address[] calldata feeds
    )
        external
        onlyOwner
    {
        if (pendingUpdate.timestamp != 0) revert PENDING_UPDATE_EXISTS();
        // no need to check MAX_PROVIDERS because we're only interating up to MAX_PROVIDERS
        // everything above MAX_PROVIDERS is ignored

        uint256 length = bases.length;
        if (length != quotes.length || length != providers.length || length != feeds.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

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
    function getOracleAddress(address base, address quote, uint256 provider) external view returns (address oracle) {
        oracle = oracles[base][quote][provider];
        if (oracle == address(0)) revert NO_ORACLES_CONFIGURED();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getAverageQuote(
        address base,
        address quote,
        uint256 baseAmount
    )
        internal
        view
        virtual
        returns (uint256 quoteAmount, uint256[] memory validQuotes, uint256 count)
    {
        uint256 total;
        validQuotes = new uint256[](MAX_PROVIDERS);

        // Start from index 1 to skip the average provider
        for (uint256 i = 1; i < MAX_PROVIDERS; ++i) {
            address providerOracle = oracles[base][quote][i];
            if (providerOracle == address(0)) break; // Stop if we hit an empty slot

            uint256 quote_ = _getQuoteFromOracle(providerOracle, baseAmount, base, quote, false);
            /// @dev we don't revert on error, we just skip the oracle value
            if (quote_ > 0) {
                total += quote_;
                validQuotes[count] = quote_;
                unchecked {
                    ++count;
                }
            }
        }
        if (count == 0) revert NO_VALID_REPORTED_PRICES();

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

    function _sqrt(uint256 x) private pure returns (uint256 y) {
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
        uint256[] memory providers,
        address[] memory feeds
    )
        private
    {
        uint256 length = bases.length;
        if (length != quotes.length || length != providers.length || length != feeds.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        for (uint256 i; i < length; ++i) {
            address base = bases[i];
            address quote = quotes[i];
            uint256 provider = providers[i];
            address feed = feeds[i];

            oracles[base][quote][provider] = feed;
            // no need to check MAX_PROVIDERS because we're only interating up to MAX_PROVIDERS
            // everything above MAX_PROVIDERS is ignored
        }
    }
}
