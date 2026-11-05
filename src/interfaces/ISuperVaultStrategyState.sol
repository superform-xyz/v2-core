// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISuperVaultStrategyState
/// @author Superform Labs
/// @notice The narrow read surface `GyldTradePolicy` needs from `SuperVaultAggregator`: is this strategy
///         paused, and is its price-per-share observation usable.
/// @dev SEPARATE FROM `ISuperVaultAggregator` ON PURPOSE. That interface is deliberately a single function
///      — the one read `SuperSponsorshipPaymaster` needs — and `test/mocks/MockSuperVaultAggregator.sol`
///      implements it. Adding methods there would break the paymaster suite for no benefit, so this is a
///      second narrow interface rather than an extension.
/// @dev VERIFIED AGAINST THE LIVE AGGREGATOR: `getPPS` at SuperVaultAggregator.sol:1008,
///      `getLastUpdateTimestamp` at :1013, `isStrategyPaused` at :1038, `isPPSStale` at :1043.
/// @dev ONLY `getPPS` CARRIES `validStrategy`. `isStrategyPaused` and `getLastUpdateTimestamp` have no such
///      modifier, so for an address that is not a registered strategy they return `false` and `0` — a pause
///      check that silently passes. There is no public `isRegisteredStrategy` predicate to ask instead
///      (`_superVaultStrategies` is private), so `getPPS` reverting is the only reachable registration
///      probe. Callers MUST establish registration before trusting the other three reads.
interface ISuperVaultStrategyState {
    /// @notice Price per share for a registered strategy
    /// @dev Reverts `UNKNOWN_STRATEGY` for an unregistered address. Used as the registration probe.
    function getPPS(address strategy) external view returns (uint256 pps);

    /// @notice Timestamp of the last price-per-share update
    /// @dev Returns 0 for an unregistered strategy — not an error. Check registration first.
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp);

    /// @notice Whether the strategy is paused
    /// @dev Returns false for an unregistered strategy — not an error. Check registration first.
    function isStrategyPaused(address strategy) external view returns (bool isPaused);

    /// @notice Whether the strategy's price-per-share observation is considered stale by the aggregator
    /// @dev Returns false for an unregistered strategy — not an error. Check registration first.
    function isPPSStale(address strategy) external view returns (bool isStale);
}
