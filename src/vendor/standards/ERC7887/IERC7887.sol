// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// @title ERC-7887 Cancelation for ERC-7540 Tokenized Vaults
/// @notice Extension of ERC-7540 with cancelation support
/// @author SuperForm Labs
interface IERC7887 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a deposit cancelation request is submitted
    /// @param controller The controller address
    /// @param requestId The request ID
    /// @param sender The sender of the request
    event CancelDepositRequest(address indexed controller, uint256 indexed requestId, address sender);

    /// @notice Emitted when a deposit cancelation request is claimed
    /// @param controller The controller address
    /// @param receiver The receiver address
    /// @param requestId The request ID
    /// @param sender The sender of the request
    /// @param assets The amount of assets claimed
    event CancelDepositClaim(
        address indexed controller,
        address indexed receiver,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    /// @notice Emitted when a redeem cancelation request is submitted
    /// @param controller The controller address
    /// @param requestId The request ID
    /// @param sender The sender of the request
    event CancelRedeemRequest(address indexed controller, uint256 indexed requestId, address sender);

    /// @notice Emitted when a redeem cancelation request is claimed
    /// @param controller The controller address
    /// @param receiver The receiver address
    /// @param requestId The request ID
    /// @param sender The sender of the request
    /// @param shares The amount of shares claimed
    event CancelRedeemClaim(
        address indexed controller,
        address indexed receiver,
        uint256 indexed requestId,
        address sender,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Submits a request for asynchronous deposit cancelation
    /// @param requestId The request ID
    /// @param controller The controller address
    function cancelDepositRequest(uint256 requestId, address controller) external;

    /// @notice Returns whether a deposit cancelation request is pending
    /// @param requestId The request ID
    /// @param controller The controller address
    /// @return isPending Whether the request is pending
    function pendingCancelDepositRequest(uint256 requestId, address controller) external view returns (bool isPending);

    /// @notice Returns the amount of assets claimable for a deposit cancelation request
    /// @param requestId The request ID
    /// @param controller The controller address
    /// @return assets The amount of assets claimable
    function claimableCancelDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);

    /// @notice Claims a deposit cancelation request
    /// @param requestId The request ID
    /// @param receiver The receiver address
    /// @param controller The controller address
    function claimCancelDepositRequest(uint256 requestId, address receiver, address controller) external;

    /*//////////////////////////////////////////////////////////////
                            REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Submits a request for asynchronous redeem cancelation
    /// @param requestId The request ID
    /// @param controller The controller address
    function cancelRedeemRequest(uint256 requestId, address controller) external;

    /// @notice Returns whether a redeem cancelation request is pending
    /// @param requestId The request ID
    /// @param controller The controller address
    /// @return isPending Whether the request is pending
    function pendingCancelRedeemRequest(uint256 requestId, address controller) external view returns (bool isPending);

    /// @notice Returns the amount of shares claimable for a redeem cancelation request
    /// @param requestId The request ID
    /// @param controller The controller address
    /// @return shares The amount of shares claimable
    function claimableCancelRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);

    /// @notice Claims a redeem cancelation request
    /// @param requestId The request ID
    /// @param receiver The receiver address
    /// @param controller The controller address
    function claimCancelRedeemRequest(uint256 requestId, address receiver, address controller) external;
} 