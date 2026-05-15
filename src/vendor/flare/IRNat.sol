// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRNat
/// @notice Minimal interface for Flare's RNat (rFLR) reward contract
/// @dev rFLR tokens vest linearly over 12 months. Early withdrawal of locked tokens
///      incurs a 50% penalty (burned). The RNat contract IS the rFLR ERC-20 token.
interface IRNat {
    /// @notice Claims rFLR rewards across specified projects up to a given month
    /// @param projectIds Array of project IDs to claim from
    /// @param month The month up to which to claim (inclusive, cumulative)
    /// @return claimedAmount Total WFLR deposited into caller's RNat account
    function claimRewards(uint256[] calldata projectIds, uint256 month) external returns (uint128 claimedAmount);

    /// @notice Withdraws all funds from the caller's RNat account
    /// @dev 50% penalty on locked (unvested) portion -- half is burned
    /// @param wrap If true returns WFLR (ERC-20); if false returns native FLR
    /// @return withdrawnAmount Total withdrawn after penalty deduction
    function withdrawAll(bool wrap) external returns (uint128 withdrawnAmount);

    /// @notice Returns the balance breakdown for a given owner
    /// @param owner The address to query
    /// @return wNatBalance WFLR deposited into the account
    /// @return rNatBalance rFLR balance (claimed rewards)
    /// @return lockedBalance Locked (unvested) portion
    function getBalancesOf(address owner)
        external
        view
        returns (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance);

    /// @notice Returns the current distribution month
    /// @return The current month index
    function getCurrentMonth() external view returns (uint256);

    /// @notice Returns the claimable reward amount for a project and owner
    /// @param projectId The project ID
    /// @param owner The address to query
    /// @return The claimable amount
    function getClaimableRewards(uint256 projectId, address owner) external view returns (uint128);
}
