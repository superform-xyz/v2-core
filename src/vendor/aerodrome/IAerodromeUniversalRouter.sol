// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAerodromeUniversalRouter
/// @notice Minimal interface for deadline-protected Aerodrome Universal Router execution
interface IAerodromeUniversalRouter {
    /// @notice Executes an ordered set of router commands before the deadline
    /// @param commands One-byte command identifiers
    /// @param inputs ABI-encoded input for each command
    /// @param deadline Latest timestamp at which execution is valid
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}
