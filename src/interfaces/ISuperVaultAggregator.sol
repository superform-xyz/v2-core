// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISuperVaultAggregator (minimal)
/// @notice The single read the paymaster needs from the SuperVaultAggregator (v2-periphery): whether an
///         address is the primary ("main") manager of a strategy. The full aggregator lives in v2-periphery;
///         this is a deliberately minimal surface so v2-core does not depend on the whole contract.
/// @dev `SuperVaultExecutor._validatePrimaryManager` gates on this exact call; the paymaster authorizes a
///      manager's gas-budget withdrawal the same way.
interface ISuperVaultAggregator {
    /// @param manager The address to check
    /// @param strategy The strategy address
    /// @return True if `manager` is the strategy's current main (primary) manager
    function isMainManager(address manager, address strategy) external view returns (bool);
}
