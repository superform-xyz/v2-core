// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC7540Redeem, IERC7540CancelRedeem } from "../standards/ERC7540/IERC7540Vault.sol";
import { IERC7741 } from "../standards/ERC7741/IERC7741.sol";

/// @title ISuperVault
/// @notice Interface for SuperVault core contract that manages share minting
/// @author Superform Labs
interface ISuperVault is IERC4626, IERC7540Redeem, IERC7741, IERC7540CancelRedeem {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ASSET();
    error INVALID_STRATEGY();
    error INVALID_ESCROW();
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INVALID_OWNER_OR_OPERATOR();
    error INVALID_AMOUNT();
    error REQUEST_NOT_FOUND();
    error UNAUTHORIZED();
    error DEADLINE_PASSED();
    error INVALID_SIGNATURE();
    error NOT_IMPLEMENTED();
    error INVALID_NONCE();
    error INVALID_WITHDRAW_PRICE();
    error TRANSFER_FAILED();
    error CAP_EXCEEDED();
    error INVALID_PPS();
    error INVALID_CONTROLLER();
    error CONTROLLER_MUST_EQUAL_OWNER();
    error NOT_ENOUGH_ASSETS();
    error CANCELLATION_REDEEM_REQUEST_PENDING();

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

    event NonceInvalidated(address indexed sender, bytes32 indexed nonce);

    event SuperGovernorSet(address indexed superGovernor);

    event DepositRequestCancelled(address indexed receiver, address indexed caller, uint256 assets);

    event MintRequest(
        address indexed sender, address indexed receiver, uint256 requestId, uint256 requestedShares, uint256 maxAssets
    );

    event MintRequestCancelled(address indexed receiver, address indexed caller, uint256 assets);
    event DepositAssetsReturned(address indexed receiver, uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint shares, only callable by strategy
    /// @param to The address to mint shares to
    /// @param amount The amount of shares to mint
    function mintShares(address to, uint256 amount) external;

    /// @notice Burn shares, only callable by strategy
    /// @param amount The amount of shares to burn
    function burnShares(uint256 amount) external;

    /// @notice Extract assets from escrow and moves them to strategy
    /// @dev Called by `SuperVaultStrategy`
    /// @param to The address to send assets to
    /// @param assets The amount of assets to be extracted
    function extractAndSendAssets(address to, uint256 assets) external;

    /// @notice Get the amount of assets escrowed
    function getEscrowedAssets() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the escrow address
    function escrow() external view returns (address);
}
