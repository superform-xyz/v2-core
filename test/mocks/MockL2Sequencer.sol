// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MockL2Sequencer
 * @dev Mocks Chainlink's L2 Sequencer Uptime Feed
 * When answer is 0: Sequencer is up
 * When answer is 1: Sequencer is down
 */
contract MockL2Sequencer {
    int256 private _answer;
    uint256 private _startedAt;

    constructor() {
        _answer = 0; // Sequencer is up by default
        _startedAt = block.timestamp;
    }

    function setLatestAnswer(int256 answer) external {
        _answer = answer;
    }

    function setStartedAt(uint256 startedAt) external {
        _startedAt = startedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _answer, _startedAt, block.timestamp, 0);
    }
}
