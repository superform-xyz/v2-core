// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SuperVaultEscrow
/// @author Superform Labs
/// @notice Escrow contract for SuperVault shares during request/claim process
contract SuperVaultEscrow {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_INITIALIZED();
    error UNAUTHORIZED();
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool public initialized;
    address public vault;
    address public strategy;
    IERC20 public shares;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyVault() {
        if (msg.sender != vault) revert UNAUTHORIZED();
        _;
    }

    modifier onlyStrategy() {
        if (msg.sender != strategy) revert UNAUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the escrow with required parameters
    /// @param vault_ The vault contract address
    /// @param strategy_ The strategy contract address
    function initialize(address vault_, address strategy_) external {
        if (initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0) || strategy_ == address(0)) revert ZERO_ADDRESS();

        initialized = true;
        vault = vault_;
        strategy = strategy_;
        shares = IERC20(vault_);
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer shares from user to escrow during redeem request
    /// @param from The address to transfer shares from
    /// @param amount The amount of shares to transfer
    function escrowShares(address from, uint256 amount) external onlyVault {
        shares.safeTransferFrom(from, address(this), amount);
    }

    /// @notice Return shares from escrow to user during redeem cancellation
    /// @param to The address to return shares to
    /// @param amount The amount of shares to return
    function returnShares(address to, uint256 amount) external onlyVault {
        shares.safeTransfer(to, amount);
    }
}
