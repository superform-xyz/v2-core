// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @dev Minimal interface for Chainlink proxy to access underlying aggregator
interface IChainlinkProxy {
    function aggregator() external view returns (address);
}

/// @dev Minimal interface for Chainlink aggregator circuit breaker bounds
interface IChainlinkAggregator {
    function minAnswer() external view returns (int192);
    function maxAnswer() external view returns (int192);
}
