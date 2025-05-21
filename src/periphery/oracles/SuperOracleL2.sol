// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Superform
import {SuperOracleBase} from "./SuperOracleBase.sol";
import {ISuperOracleL2} from "../interfaces/ISuperOracleL2.sol";

// external
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {BoringERC20} from "../../vendor/BoringSolidity/BoringERC20.sol";
import {AggregatorV3Interface} from "../../vendor/chainlink/AggregatorV3Interface.sol";

/// @title SuperOracleL2
/// @author Superform Labs
/// @notice Layer 2 Oracle for Superform
contract SuperOracleL2 is SuperOracleBase, ISuperOracleL2 {
    using BoringERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address dataOracle => address uptimeOracle) public uptimeFeeds;
    mapping(address uptimeOracle => uint256 gracePeriod) public gracePeriods;

    uint256 private constant DEFAULT_GRACE_PERIOD_TIME = 3600;

    constructor(
        address owner_,
        address[] memory bases,
        address[] memory quotes,
        bytes32[] memory providers,
        address[] memory feeds
    ) SuperOracleBase(owner_, bases, quotes, providers, feeds) {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperOracleL2
    function setUptimeFeed(address dataOracle, address uptimeOracle, uint256 gracePeriod) external onlyOwner {
        if (dataOracle == address(0) || uptimeOracle == address(0)) revert ZERO_ADDRESS();
        uptimeFeeds[dataOracle] = uptimeOracle;
        gracePeriods[uptimeOracle] = gracePeriod;
        emit UptimeFeedSet(dataOracle, uptimeOracle);
        emit GracePeriodSet(uptimeOracle, gracePeriod);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getQuoteFromOracle(address oracle, uint256 baseAmount, address base, address quote, bool revertOnError)
        internal
        view
        override
        returns (uint256 quoteAmount)
    {
        {
            address uptimeOracle = uptimeFeeds[oracle];
            if (uptimeOracle == address(0)) revert NO_UPTIME_FEED();

            (
                /*uint80 roundID*/
                ,
                int256 uptimeAnswer,
                uint256 startedAt,
                /*uint256 updatedAt*/
                ,
                /*uint80 answeredInRound*/
            ) = AggregatorV3Interface(uptimeOracle).latestRoundData();

            // Answer == 0: Sequencer is up
            // Answer == 1: Sequencer is down
            bool isSequencerUp = uptimeAnswer == 0;
            if (!isSequencerUp) {
                revert SEQUENCER_DOWN();
            }

            // Make sure the grace period has passed after the
            // sequencer is back up.
            uint256 timeSinceUp = block.timestamp - startedAt;
            uint256 gracePeriod = gracePeriods[uptimeOracle];
            if (gracePeriod == 0) {
                gracePeriod = DEFAULT_GRACE_PERIOD_TIME;
            }
            if (timeSinceUp <= gracePeriod) {
                revert GRACE_PERIOD_NOT_OVER();
            }
        }

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
}
