// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IPendlePTAmortizedOracleV2
/// @author Superform Labs
/// @notice Interface for the PendlePTAmortizedOracleV2 contract
/// @dev V2: recordPurchase calculates sySpent from PT rate (no off-chain price dependency)
/// @dev twapDuration is passed as parameter per-call (no market config storage)
/// @dev Provides amortized cost pricing for Pendle PT positions held by strategies
interface IPendlePTAmortizedOracleV2 {
    /// @notice Record a PT purchase - called by strategy via hooks AFTER deposit
    /// @dev V2: Calculates sySpent from ptBought using on-chain PT rate
    /// @dev twapDuration is passed per-call for flexibility (0 = spot, 900 = 15min TWAP)
    /// @dev msg.sender is the strategy being updated
    /// @param market The Pendle market address
    /// @param ptBought Amount of PT received from the purchase
    /// @param twapDuration TWAP duration for rate calculation in seconds (0 for spot)
    function recordPurchase(address market, uint256 ptBought, uint32 twapDuration) external;

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
