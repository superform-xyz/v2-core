// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { ISuperVaultStrategyState } from "../../../src/interfaces/ISuperVaultStrategyState.sol";

/// @title MockSuperVaultStrategyState
/// @notice Stands in for `SuperVaultAggregator`'s strategy-state reads in `GyldTradePolicy` tests.
/// @dev Deliberately mirrors the real contract's asymmetry: only `getPPS` reverts for an unregistered
///      strategy (the live aggregator carries `validStrategy` on that one function and on no other), so
///      `isStrategyPaused` and `getLastUpdateTimestamp` answer `false`/`0` for unknown addresses exactly as
///      production does. Tests that assume otherwise would be testing a configuration that cannot ship.
contract MockSuperVaultStrategyState is ISuperVaultStrategyState {
    error UNKNOWN_STRATEGY();

    mapping(address => bool) public registered;
    mapping(address => bool) public paused;
    mapping(address => bool) public ppsStale;
    mapping(address => uint256) public lastUpdate;
    uint256 public pps = 1e18;

    /// @notice Registers a strategy and gives it a fresh observation, the normal healthy fixture
    function register(address strategy) external {
        registered[strategy] = true;
        lastUpdate[strategy] = block.timestamp;
    }

    function setPaused(address strategy, bool value) external {
        paused[strategy] = value;
    }

    function setPPSStale(address strategy, bool value) external {
        ppsStale[strategy] = value;
    }

    function setLastUpdate(address strategy, uint256 value) external {
        lastUpdate[strategy] = value;
    }

    function getPPS(address strategy) external view returns (uint256) {
        if (!registered[strategy]) revert UNKNOWN_STRATEGY();
        return pps;
    }

    function getLastUpdateTimestamp(address strategy) external view returns (uint256) {
        return lastUpdate[strategy];
    }

    function isStrategyPaused(address strategy) external view returns (bool) {
        return paused[strategy];
    }

    function isPPSStale(address strategy) external view returns (bool) {
        return ppsStale[strategy];
    }
}
