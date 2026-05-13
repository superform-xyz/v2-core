// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMachine
/// @notice Minimal interface for Dialectic's Machine vault
/// @dev Machine is a modified ERC-4626 vault with separate share and accounting tokens.
///      Deployed as a BeaconProxy at 0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735.
///      NOTE: Machine does NOT expose standard ERC-4626 view functions (decimals, totalAssets, totalSupply).
///      Use DETH token for decimals/totalSupply, and lastTotalAum() for TVL.
interface IMachine {
    /// @notice Returns the share token address (DETH)
    /// @return The address of the DETH share token
    function shareToken() external view returns (address);

    /// @notice Returns the accounting token address (WETH)
    /// @return The address of the WETH accounting token
    function accountingToken() external view returns (address);

    /// @notice Converts share amount to asset amount using Machine's internal pricing
    /// @param shares Amount of DETH shares
    /// @return assets Equivalent amount of WETH assets
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Converts asset amount to share amount using Machine's internal pricing
    /// @param assets Amount of WETH assets
    /// @return shares Equivalent amount of DETH shares
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice Returns the last recorded total AUM in asset terms (WETH)
    /// @dev Used instead of totalAssets() which is not exposed by Machine
    /// @return Total AUM in WETH
    function lastTotalAum() external view returns (uint256);
}
