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
}
