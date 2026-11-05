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

/// @title MockHostileAggregator
/// @notice An aggregator that misbehaves in the ways a cross-contract dependency actually can.
/// @dev `GyldTradePolicy` added the aggregator as a new trust surface, so each of these has to be a
///      contained failure rather than a way to brick or bypass the policy.
contract MockHostileAggregator {
    enum Mode {
        REVERT_EVERYTHING,
        RETURNBOMB_ON_GETPPS,
        EMPTY_RETURN,
        OUT_OF_GAS_LOOP
    }

    Mode public mode;

    constructor(Mode mode_) {
        mode = mode_;
    }

    /// @dev 100KB of revert data. A `catch (bytes memory)` would copy all of it and run out of gas on the
    ///      1/64 the caller retains per EIP-150; a bare `catch` is immune, which is what the policy uses.
    function _bomb() private pure {
        assembly {
            revert(0, 100000)
        }
    }

    function getPPS(address) external view returns (uint256) {
        if (mode == Mode.RETURNBOMB_ON_GETPPS) _bomb();
        if (mode == Mode.REVERT_EVERYTHING) revert("no");
        if (mode == Mode.OUT_OF_GAS_LOOP) {
            uint256 i;
            while (true) {
                i++;
            }
        }
        return 1e18;
    }

    function isStrategyPaused(address) external view returns (bool) {
        if (mode == Mode.REVERT_EVERYTHING) revert("no");
        return false;
    }

    function isPPSStale(address) external view returns (bool) {
        if (mode == Mode.REVERT_EVERYTHING) revert("no");
        return false;
    }

    function getLastUpdateTimestamp(address) external view returns (uint256) {
        if (mode == Mode.REVERT_EVERYTHING) revert("no");
        return block.timestamp;
    }
}
