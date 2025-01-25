// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IERC7540 } from "../interfaces/vendors/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISuperVault } from "../interfaces/ISuperVault.sol";

/// @title SuperVault7540
/// @author SuperVault
/// @notice Implementation of ERC-7540 for SuperVault
/// @dev TODO: SuperLedger Accounting Issue
///      When users deposit through this wrapper, all deposits appear to come from the wrapper's address.
///      This breaks SuperLedger's FIFO accounting for yield attribution because:
///      1. Multiple users' deposits get mixed under one address
///      2. Entry/exit prices can't be correctly tracked per user
///      3. Yield attribution becomes inaccurate
///      
///      Possible solutions:
///      1. Modify SuperLedger to handle batch deposits with different entry prices
///      2. Create new accounting mechanism for 7540-wrapped vaults
///      3. Track yield attribution at wrapper level
contract SuperVault7540 is IERC7540 {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying SuperVault
    ISuperVault public immutable superVault;
    
    /// @notice The underlying asset
    IERC20 public immutable asset;

    /// @notice Mapping of controllers that can execute deposits/redeems
    mapping(address => bool) public controllers;

    /// @notice Mapping of pending deposits per user
    mapping(address => uint256) public pendingDeposits;

    /// @notice Mapping of pending redeems per user
    mapping(address => uint256) public pendingRedeems;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NOT_CONTROLLER();
    error INSUFFICIENT_PENDING_DEPOSIT();
    error INSUFFICIENT_PENDING_REDEEM();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address superVault_) {
        superVault = ISuperVault(superVault_);
        asset = IERC20(ISuperVault(superVault_).asset());
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Request a deposit into the vault
    function requestDeposit(uint256 assets, address receiver) external returns (uint256) {
        // Transfer assets from user
        asset.safeTransferFrom(msg.sender, address(this), assets);
        
        // Record pending deposit
        pendingDeposits[receiver] += assets;
        
        return assets;
    }

    /// @notice Request a redemption from the vault
    function requestRedeem(uint256 shares, address receiver) external returns (uint256) {
        // Transfer shares from user
        IERC20(address(superVault)).safeTransferFrom(msg.sender, address(this), shares);
        
        // Record pending redeem
        pendingRedeems[msg.sender] += shares;
        
        return shares;
    }

    /*//////////////////////////////////////////////////////////////
                          CONTROLLER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute a deposit for a user through SuperVault
    function executeDeposit(address receiver, uint256 assets) external returns (uint256) {
        if (!controllers[msg.sender]) revert NOT_CONTROLLER();
        if (pendingDeposits[receiver] < assets) revert INSUFFICIENT_PENDING_DEPOSIT();

        // Approve assets to SuperVault
        asset.approve(address(superVault), assets);
        
        // Deposit directly into SuperVault
        uint256 shares = superVault.deposit(assets, receiver);

        // Update pending deposits
        pendingDeposits[receiver] -= assets;

        return shares;
    }

    /// @notice Execute a redemption for a user through SuperVault
    function executeRedeem(address owner, uint256 shares) external returns (uint256) {
        if (!controllers[msg.sender]) revert NOT_CONTROLLER();
        if (pendingRedeems[owner] < shares) revert INSUFFICIENT_PENDING_REDEEM();

        // Approve shares to SuperVault
        IERC20(address(superVault)).approve(address(superVault), shares);
        
        // Redeem directly from SuperVault
        uint256 assets = superVault.redeem(shares, owner, owner);

        // Update pending redeems
        pendingRedeems[owner] -= shares;

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                          CONTROLLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a controller
    function addController(address controller) external {
        // TODO: Add access control
        controllers[controller] = true;
    }

    /// @notice Remove a controller
    function removeController(address controller) external {
        // TODO: Add access control
        controllers[controller] = false;
    }
} 