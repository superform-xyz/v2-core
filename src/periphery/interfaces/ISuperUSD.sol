// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC7575, IERC7575Share } from "./IERC7575.sol";
import { IERC7540Vault } from "./IERC7540Vault.sol";
import { ISuperOracle } from "../../core/interfaces/accounting/ISuperOracle.sol";

/// @title ISuperUSD
/// @notice Interface for SuperUSD stablecoin vault
/// @author SuperForm Labs
interface ISuperUSD is IERC7575, IERC7575Share, IERC7540Vault {

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_MANAGER();
    error INVALID_STRATEGIST();
    error INVALID_ORACLE();
    error INVALID_ASSET();
    error INVALID_VAULT();
    error ASSET_ALREADY_SUPPORTED();
    error ASSET_NOT_SUPPORTED();
    error UNAUTHORIZED();
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error REQUEST_NOT_FOUND();
    error INVALID_AMOUNT();
    error INVALID_CONTROLLER();
    error NOT_IMPLEMENTED();
    error REQUEST_EXISTS();
    error INVALID_FEE();
    error INVALID_FEE_RECIPIENT();
    error ZERO_LENGTH();
    error INCOMPLETE_DEPOSIT_MATCH();


    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    event DepositRequestCancelled(address indexed controller, address sender);
    event RedeemRequestCancelled(address indexed controller, address sender);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    // Share price tracking
    struct SharePricePoint {
        uint256 shares;
        uint256 pricePerShare;
    }

    struct FeeConfig {
        uint256 feeBps; // Fee in basis points
        address recipient; // Fee recipient address
    }

    struct SuperUSDState {
        uint256 pendingDepositRequest;
        uint256 pendingRedeemRequest;
        uint256 maxMint;
        uint256 maxWithdraw;
        uint256 sharePricePointCursor;
        SharePricePoint[] sharePricePoints;
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Add support for a SuperVault
    /// @param vault The vault to add
    function addVault(address vault) external;

    /// @notice Remove support for a vault
    /// @param vault The vault to remove
    function removeVault(address vault) external;

    /// @notice Cancel a pending deposit request
    /// @param controller The controller address
    function cancelDeposit(address controller) external;

    /// @notice Cancel a pending redeem request
    /// @param controller The controller address
    function cancelRedeem(address controller) external;

    /// @notice Get the manager address
    function manager() external view returns (address);

    /// @notice Get the strategist address
    function strategist() external view returns (address);

    /// @notice Get the oracle contract address
    function oracle() external view returns (ISuperOracle);

    /// @notice Get the vault address for a given asset
    /// @param asset The asset address
    function assetToVault(address asset) external view returns (address);

    /// @notice Get the current share price point cursor for a controller
    /// @param controller The controller address
    function sharePricePointCursor(address controller) external view returns (uint256);

    /// @notice Get a share price point for a controller at a given index
    /// @param controller The controller address
    /// @param index The index of the share price point
    function sharePricePoints(
        address controller, 
        uint256 index
    ) external view returns (uint256 shares, uint256 pricePerShare);

    /// @notice Convert USD value to shares
    /// @param usdValue The USD value to convert
    function convertToShares(uint256 usdValue) external view returns (uint256 shares);

    /// @notice Convert shares to USD value
    /// @param shares The shares to convert
    function convertToAssets(uint256 shares) external view returns (uint256 usdValue);

    /// @notice Get total assets in USD terms
    function totalAssets() external view returns (uint256 total);
} 