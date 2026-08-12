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
    /// @param sySpent Purchase cost in SY accounting-asset units (book value increment)
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

    /// @notice The TWAP duration the oracle uses for Pendle rate queries (immutable, in seconds)
    /// @return The TWAP duration in seconds
    function TWAP_DURATION() external view returns (uint32);

    /// @notice Convert a PT amount into SY accounting-asset units at the oracle's configured TWAP rate
    /// @dev IYieldSourceOracle view implemented by PendlePTAmortizedOracle
    /// @param market The Pendle market address (yieldSourceAddress)
    /// @param expectedUnderlying Unused by the Pendle implementation (pass address(0))
    /// @param sharesIn The PT amount to convert
    /// @return assetsOut The value in SY accounting-asset units
    function getAssetOutput(
        address market,
        address expectedUnderlying,
        uint256 sharesIn
    )
        external
        view
        returns (uint256 assetsOut);
}
