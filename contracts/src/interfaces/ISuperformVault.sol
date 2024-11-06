// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISuperformVault {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DEPOSIT_ZERO();
    error SHARES_ZERO();
    error INSUFFICIENT_ALLOWANCE();
    error NO_SHARES_MINTED();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the asset of the vault.
    /// @return The asset.
    function asset() external view returns (IERC20);

    /// @dev Preview the number of shares received for a deposit.
    /// @param assets_ The number of assets to deposit.
    /// @return shares_ The number of shares received.
    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);

    /// @dev Preview the number of assets received for a withdrawal.
    /// @param assets_ The number of assets to withdraw.
    /// @return shares_ The number of shares received.
    function previewWithdraw(uint256 assets_) external view returns (uint256 shares_);

    /// @dev Get the total number of assets in the vault.
    /// @return The total number of assets.
    function totalAssets() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Deposit assets into the vault.
    /// @param assets_ The number of assets to deposit.
    /// @param receiver_ The address to receive the shares.
    /// @return shares_ The number of shares received.
    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);

    /// @dev Withdraw assets from the vault.
    /// @param assets_ The number of assets to withdraw.
    /// @param receiver_ The address to receive the assets.
    /// @param owner_ The address of the owner.
    /// @return shares_ The number of shares withdrawn.
    function withdraw(uint256 assets_, address receiver_, address owner_) external returns (uint256 shares_);
}
