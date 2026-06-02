// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title INativeFeeSponsorship
/// @author Superform Labs
/// @notice Interface for the NativeFeeSponsorship ledger contract
/// @dev Open balance model: no signatures or nonces. Sponsors deposit ETH keyed by (sponsor, account),
///      and smart accounts withdraw via hooks. Sponsors can reclaim unused deposits.
interface INativeFeeSponsorship {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a critical address parameter is the zero address
    error ZERO_ADDRESS();

    /// @notice Thrown when an amount parameter is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when withdrawal exceeds the sponsored balance
    error INSUFFICIENT_SPONSORED_BALANCE();

    /// @notice Thrown when an ETH transfer fails
    error ETH_TRANSFER_FAILED();

    /// @notice Thrown when msg.sender does not match the sponsor parameter
    /// @dev Kept for backwards compatibility but no longer used
    error UNAUTHORIZED_DEPOSITOR();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when native ETH is deposited for a smart account
    /// @param sponsor The address of the sponsor (typically the bundler)
    /// @param account The smart account that can withdraw these funds
    /// @param amount The amount of native ETH deposited
    event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount);

    /// @notice Emitted when a smart account withdraws sponsored native ETH
    /// @param sponsor The sponsor whose deposit was withdrawn from
    /// @param account The smart account that withdrew (msg.sender)
    /// @param amount The amount of native ETH withdrawn
    event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount);

    /// @notice Emitted when a sponsor reclaims unused deposited native ETH
    /// @param sponsor The sponsor reclaiming the deposit (msg.sender)
    /// @param account The account whose allocation is being reclaimed
    /// @param to The address receiving the reclaimed ETH
    /// @param amount The amount of native ETH reclaimed
    event NativeWithdrawnBySponsor(
        address indexed sponsor, address indexed account, address indexed to, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit native ETH for a smart account, keyed by sponsor
    /// @dev Allows intermediaries (e.g. SuperNativePaymaster) to deposit on behalf of the actual sponsor,
    ///      so the sponsor can later reclaim unused deposits via withdrawSponsorDeposit.
    /// @param sponsor The address of the sponsor (recorded as the deposit owner)
    /// @param account The smart account that can withdraw these funds
    function depositForAccount(address sponsor, address account) external payable;

    /// @notice Account (msg.sender) withdraws sponsored native ETH
    /// @param sponsor The sponsor whose deposit to withdraw from
    /// @param amount The amount of native ETH to withdraw
    function withdrawSponsoredNative(address sponsor, uint256 amount) external;

    /// @notice Sponsor (msg.sender) reclaims unused deposit
    /// @param account The account whose allocation to reclaim from
    /// @param to The address to send reclaimed ETH to
    /// @param amount The amount to reclaim
    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the sponsored amount for a given sponsor-account pair
    /// @param sponsor The sponsor address
    /// @param account The account address
    /// @return The amount of native ETH sponsored
    function sponsoredAmount(address sponsor, address account) external view returns (uint256);
}
