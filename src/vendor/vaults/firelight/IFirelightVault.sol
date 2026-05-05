// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IFirelightVault
/// @notice Minimal interface for Firelight stXRP vault on Flare
/// @dev The vault uses ERC-4626 function signatures but with async withdrawal semantics.
///      redeem() burns shares and creates a WithdrawRequest instead of transferring assets.
///      claimWithdraw() claims assets after the cooldown period.
interface IFirelightVault {
    /// @notice Burns shares and creates a withdrawal request (does NOT transfer assets)
    /// @param shares Amount of stXRP shares to redeem
    /// @param receiver Address to receive assets when claimed
    /// @param owner Owner of the shares being redeemed
    /// @return assets Nominal asset value (NOT actually transferred)
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Claims assets from a completed withdrawal request
    /// @param requestId The withdrawal request ID from the WithdrawRequest event
    function claimWithdraw(uint256 requestId) external;

    /// @notice Returns the underlying asset address (FXRP)
    function asset() external view returns (address);

    /// @notice Returns the current withdrawal period number
    function currentPeriod() external view returns (uint256);

    /// @notice Returns the withdrawal amount for a given period and account
    /// @param period The period number to query
    /// @param account The account to query withdrawals for
    function withdrawalsOf(uint256 period, address account) external view returns (uint256);

    /// @notice Returns whether a withdrawal for a given period and account has been claimed
    /// @param period The period number to query
    /// @param account The account to check
    function isWithdrawClaimed(uint256 period, address account) external view returns (bool);

    /// @notice Converts shares to assets using the vault's exchange rate
    /// @param shares Amount of shares to convert
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Converts assets to shares using the vault's exchange rate
    /// @param assets Amount of assets to convert
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Returns total assets managed by the vault
    function totalAssets() external view returns (uint256);

    /// @notice Returns the number of decimals for the vault's share token
    function decimals() external view returns (uint8);

    /// @notice Returns the share balance of a given account
    /// @param account The account to query
    function balanceOf(address account) external view returns (uint256);
}
