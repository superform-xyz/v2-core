// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IGyldNavFeed
/// @author Superform Labs
/// @notice Minimal interface for a Gyld-native complete-NAV feed.
/// @dev ASSUMED ABI — NOT CONFIRMED WITH GYLD. See `IGyldSettlement` for the standing caveat.
/// @dev COMPLETE NAV means the bond token's accounting value INCLUDING coupon accrual, coupon-pool amounts and
///      accrued fees. A catalog price or an executable quote is NOT a substitute and must never be wired here.
///      Confirming that Gyld's feed actually represents complete NAV is a launch blocker, not a detail.
/// @dev OBSERVATION TIME vs PUBLICATION TIME. These are different clocks and both matter. `navAsOf` is the
///      issuer's valuation "as of" instant; `publishedAt` is when that number reached this chain. A feed can be
///      published seconds ago while describing a day-old valuation. A Chainlink `AggregatorV3` exposes only the
///      publication clock, which is why `GyldBondRegistry` carries `requiresObservationTime`: an instrument that
///      needs observation-time bounds must not be served by a feed that cannot express them.
interface IGyldNavFeed {
    /// @notice Complete NAV of one whole bond token
    /// @param bondToken The instrument being valued
    /// @return nav Complete NAV per one bond token, scaled by `decimals()`
    /// @return navAsOf Observation time: the issuer's valuation instant. Zero means the feed cannot express it.
    /// @return publishedAt On-chain publication time of `nav`
    function latestNav(address bondToken) external view returns (uint256 nav, uint256 navAsOf, uint256 publishedAt);

    /// @notice Fixed-point scale of `nav`
    function decimals() external view returns (uint8);
}
