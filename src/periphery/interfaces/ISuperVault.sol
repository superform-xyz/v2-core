// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// @title ISuperVault
/// @notice Interface for SuperVault core contract that manages share minting
/// @author SuperForm Labs
interface ISuperVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_INITIALIZED();
    error INVALID_ASSET();
    error INVALID_STRATEGY();
    error INVALID_ESCROW();
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INVALID_OWNER_OR_OPERATOR();
    error INVALID_AMOUNT();
    error REQUEST_NOT_FOUND();
    error UNAUTHORIZED();
    error TIMELOCK_NOT_EXPIRED();
    error INVALID_SIGNATURE();
    error NOT_IMPLEMENTED();
    error INVALID_DEPOSIT_CLAIM();
    error INVALID_CONTROLLER();
    error INVALID_DEPOSIT_PRICE();
    error INVALID_WITHDRAW_PRICE();

    /*//////////////////////////////////////////////////////////////
                            SHARE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint new shares, only callable by strategy
    /// @param amount The amount of shares to mint
    function mintShares(uint256 amount) external;

    /// @notice Callback function for when a deposit becomes claimable
    /// @param user The user whose deposit is claimable
    /// @param assets The amount of assets deposited
    /// @param shares The amount of shares to be received
    function onDepositClaimable(address user, uint256 assets, uint256 shares) external;

    /// @notice Callback function for when a redeem becomes claimable
    /// @param user The user whose redeem is claimable
    /// @param assets The amount of assets to be received
    /// @param shares The amount of shares redeemed
    function onRedeemClaimable(address user, uint256 assets, uint256 shares) external;
}
