// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

/// @title ISuperVault
/// @notice Interface for SuperVault core contract that manages share minting
/// @author Superform Labs
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
    error INVALID_NONCE();
    error INVALID_WITHDRAW_PRICE();
    error TRANSFER_FAILED();
    error CAP_EXCEEDED();
    error INVALID_PPS();
    error INVALID_CONTROLLER();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RedeemClaimable(
        address indexed user,
        uint256 indexed requestId,
        uint256 assets,
        uint256 shares,
        uint256 averageWithdrawPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    );
    event RedeemRequestCancelled(address indexed controller, address indexed sender);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function cancelRedeem(address controller) external;

    /// @notice Mint new shares, only callable by strategy
    /// @param amount The amount of shares to mint
    function mintShares(uint256 amount) external;

    /// @notice Burn shares, only callable by strategy
    /// @param amount The amount of shares to burn
    function burnShares(uint256 amount) external;

    /// @notice Callback function for when a redeem becomes claimable
    /// @param user The user whose redeem is claimable
    /// @param assets The amount of assets to be received
    /// @param shares The amount of shares redeemed
    /// @param averageWithdrawPrice The average price of the redeem
    /// @param accumulatorShares The amount of shares in the accumulator
    /// @param accumulatorCostBasis The cost basis of the accumulator
    function onRedeemClaimable(
        address user,
        uint256 assets,
        uint256 shares,
        uint256 averageWithdrawPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    )
        external;
}
