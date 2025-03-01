// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperVaultEscrow
/// @notice Interface for SuperVault escrow contract that holds shares during request/claim process
/// @author SuperForm Labs
interface ISuperVaultEscrow {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_INITIALIZED();
    error UNAUTHORIZED();
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the escrow with required parameters
    /// @param vault_ The vault contract address
    /// @param strategy_ The strategy contract address
    function initialize(address vault_, address strategy_) external;

    /*//////////////////////////////////////////////////////////////
                            VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer shares from user to escrow during redeem request
    /// @param from The address to transfer shares from
    /// @param amount The amount of shares to transfer
    function escrowShares(address from, uint256 amount) external;

    /// @notice Return shares from escrow to user during redeem cancellation
    /// @param to The address to return shares to
    /// @param amount The amount of shares to return
    function returnShares(address to, uint256 amount) external;

    /// @notice Transfer shares from escrow to user during deposit claim
    /// @param to The address to transfer shares to
    /// @param amount The amount of shares to transfer
    function transferShares(address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive newly minted shares from strategy during deposit fulfillment
    /// @param amount The amount of shares to receive
    function receiveShares(uint256 amount) external;
}
