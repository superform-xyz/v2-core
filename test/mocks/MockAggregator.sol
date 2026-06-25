// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MockAggregator
 * @dev Mocks the Chainlink Aggregator interface for testing.
 *      Supports roundId/answeredInRound validation and circuit breaker bounds.
 */
contract MockAggregator {
    uint8 private _decimals;
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint80 private _answeredInRound;
    int192 private _minAnswer;
    int192 private _maxAnswer;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
        _answeredInRound = 1;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function setLatestAnswer(int256 answer) external {
        _answer = answer;
        _updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 updatedAt) external {
        _updatedAt = updatedAt;
    }

    function setRoundData(uint80 roundId, uint80 answeredInRound) external {
        _roundId = roundId;
        _answeredInRound = answeredInRound;
    }

    function setCircuitBreakerBounds(int192 min, int192 max) external {
        _minAnswer = min;
        _maxAnswer = max;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, _answer, block.timestamp, _updatedAt, _answeredInRound);
    }

    /// @dev Acts as its own proxy (aggregator() returns self) for circuit breaker testing
    function aggregator() external view returns (address) {
        return address(this);
    }

    function minAnswer() external view returns (int192) {
        return _minAnswer;
    }

    function maxAnswer() external view returns (int192) {
        return _maxAnswer;
    }
}
