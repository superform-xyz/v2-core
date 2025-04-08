// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

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
    error INVALID_NONCE();
    error INVALID_DEPOSIT_CLAIM();
    error INVALID_CONTROLLER();
    error INVALID_DEPOSIT_PRICE();
    error INVALID_WITHDRAW_PRICE();
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositClaimable(
        address indexed user,
        uint256 indexed requestId,
        uint256 assets,
        uint256 shares,
        uint256 averageDepositPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    );
    event RedeemClaimable(
        address indexed user,
        uint256 indexed requestId,
        uint256 assets,
        uint256 shares,
        uint256 averageWithdrawPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    );
    event DepositRequestCancelled(address indexed controller, address indexed sender);
    event RedeemRequestCancelled(address indexed controller, address indexed sender);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancel a pending deposit request and return assets to the user in one step
    /// @param controller The controller address
    function cancelDeposit(address controller) external;

    /// @notice Cancel a pending redeem request and return shares to the user in one step
    /// @param controller The controller address
    function cancelRedeem(address controller) external;

    /// @notice Mint new shares, only callable by strategy
    /// @param amount The amount of shares to mint
    function mintShares(uint256 amount) external;

    /// @notice Burn shares, only callable by strategy
    /// @param amount The amount of shares to burn
    function burnShares(uint256 amount) external;

    /// @notice Callback function for when a deposit becomes claimable
    /// @param user The user whose deposit is claimable
    /// @param assets The amount of assets deposited
    /// @param shares The amount of shares to be received
    /// @param averageDepositPrice The average price of the deposit
    /// @param accumulatorShares The amount of shares in the accumulator
    /// @param accumulatorCostBasis The cost basis of the accumulator
    function onDepositClaimable(
        address user,
        uint256 assets,
        uint256 shares,
        uint256 averageDepositPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    )
        external;

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
