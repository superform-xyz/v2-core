// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IPendlePTAmortizedOracle
/// @author Superform Labs
/// @notice Interface for the PendlePTAmortizedOracle contract
/// @dev Provides amortized cost pricing for Pendle PT positions held by strategies
interface IPendlePTAmortizedOracle {
    /// @notice Record a PT purchase - called by strategy via hooks AFTER deposit
    /// @dev msg.sender is the strategy being updated
    /// @param market The Pendle market address
    /// @param sySpent Amount of SY spent on the purchase (book value increment)
    /// @param ptAmount Amount of PT received from the purchase
    function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) external;

    /// @notice Record a PT redemption - called by strategy via hooks AFTER redeem
    /// @dev msg.sender is the strategy being updated
    /// @param market The Pendle market address
    /// @param ptSold Amount of PT that was sold/redeemed
    function recordRedemption(address market, uint256 ptSold) external;

    /// @notice Get the current amortized book value for a position
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return bookValue Current amortized book value
    function getBookValue(address strategy, address market) external view returns (uint256 bookValue);

    /// @notice Check if a position exists
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return exists True if position has been recorded
    function hasPosition(address strategy, address market) external view returns (bool exists);
}
