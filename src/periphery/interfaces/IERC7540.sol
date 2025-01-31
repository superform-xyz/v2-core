// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

/// @title IERC7540
/// @notice Interface for ERC7540 Asynchronous Tokenized Vault standard
/// @dev ERC7540 is an extension of ERC4626 that adds asynchronous deposit and redeem operations
interface IERC7540 is IERC4626, IERC165 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event CancelDepositRequest(address indexed controller, uint256 indexed requestId);
    event CancelRedeemRequest(address indexed controller, uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Request to deposit assets into the vault
    /// @param assets Amount of assets to deposit
    /// @param owner Address that will own the shares
    /// @param controller Address that can control the request
    /// @return requestId Unique identifier for the deposit request
    function requestDeposit(uint256 assets, address owner, address controller) external returns (uint256 requestId);

    /// @notice Get the status of a deposit request
    /// @param requestId Unique identifier for the deposit request
    /// @return status True if the deposit request is claimable
    function isDepositClaimable(uint256 requestId) external view returns (bool);

    /// @notice Cancel a pending deposit request
    /// @param requestId Unique identifier for the deposit request
    function cancelDepositRequest(uint256 requestId) external;

    /*//////////////////////////////////////////////////////////////
                            REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Request to redeem shares from the vault
    /// @param shares Amount of shares to redeem
    /// @param owner Address that owns the shares
    /// @param controller Address that can control the request
    /// @return requestId Unique identifier for the redeem request
    function requestRedeem(uint256 shares, address owner, address controller) external returns (uint256 requestId);

    /// @notice Get the status of a redeem request
    /// @param requestId Unique identifier for the redeem request
    /// @return status True if the redeem request is claimable
    function isRedeemClaimable(uint256 requestId) external view returns (bool);

    /// @notice Cancel a pending redeem request
    /// @param requestId Unique identifier for the redeem request
    function cancelRedeemRequest(uint256 requestId) external;
}
