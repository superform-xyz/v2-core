// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IEVault
/// @notice Minimal Euler V2 EVault interface for Superform hooks
/// @dev Only includes functions needed by Euler lending hooks.
///      EVaults extend ERC-4626 with lending operations (borrow, repay) and controller management.
interface IEVault {
    /*//////////////////////////////////////////////////////////////
                            ERC-4626 COMPATIBLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit assets into the vault
    /// @param assets Amount of underlying tokens to deposit
    /// @param receiver Address to receive the vault shares
    /// @return shares Amount of shares minted
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraw assets from the vault
    /// @param assets Amount of underlying tokens to withdraw
    /// @param receiver Address to receive the underlying tokens
    /// @param owner Address whose shares will be burned
    /// @return shares Amount of shares burned
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /*//////////////////////////////////////////////////////////////
                            LENDING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow assets from the vault
    /// @param assets Amount of underlying tokens to borrow
    /// @param receiver Address to receive the borrowed tokens
    /// @return shares Amount of debt shares minted
    function borrow(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Repay borrowed assets
    /// @param assets Amount of underlying tokens to repay
    /// @param receiver Address whose debt is being repaid
    /// @return shares Amount of debt shares burned
    function repay(uint256 assets, address receiver) external returns (uint256 shares);

    /*//////////////////////////////////////////////////////////////
                          CONTROLLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Release the account from being controlled by this vault
    /// @dev Only callable by the account itself (msg.sender via EVC resolution).
    ///      The account must have zero debt. Internally calls evc.disableController(msg.sender).
    function disableController() external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current accrued debt of an account in asset units
    /// @dev Rounds up (conservative — borrower owes at least this much). Includes accrued interest.
    /// @param account The account to query
    /// @return The current debt amount in asset units
    function debtOf(address account) external view returns (uint256);

    /// @notice Get the vault share balance of an account
    /// @param account The account to query
    /// @return The share balance
    function balanceOf(address account) external view returns (uint256);

    /// @notice Convert vault shares to underlying asset amount
    /// @param shares Amount of shares to convert
    /// @return The equivalent amount of underlying assets
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Get the number of decimals of the vault shares
    /// @dev Euler V2 EVaults extend ERC-4626, so decimals matches the underlying asset
    /// @return The number of decimals
    function decimals() external view returns (uint8);

    /// @notice Get the underlying asset of the vault
    /// @return The address of the underlying token
    function asset() external view returns (address);

    /// @notice Get the oracle used by this vault
    /// @return The oracle address
    function oracle() external view returns (address);

    /// @notice Get the unit of account for value normalization
    /// @return The unit of account address
    function unitOfAccount() external view returns (address);

    /// @notice Get the interest rate model
    /// @return The IRM address
    function interestRateModel() external view returns (address);

    /// @notice Get account's collateral and liability values for health checking
    /// @param account The account to query
    /// @param liquidation True for liquidation LTV, false for borrow LTV
    /// @return collateralValue Total weighted collateral value in unit of account
    /// @return liabilityValue Total liability value in unit of account
    /// @dev CRITICAL: collateral is returned FIRST, liability SECOND
    function accountLiquidity(
        address account,
        bool liquidation
    )
        external
        view
        returns (uint256 collateralValue, uint256 liabilityValue);

    /// @notice Get the maximum amount of assets that can be withdrawn by an owner
    /// @param owner The account to query
    /// @return The maximum withdrawable amount
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Get the vault's current cash balance
    /// @return The cash amount
    function cash() external view returns (uint256);

    /// @notice Get the vault's supply and borrow caps
    /// @return supplyCap The supply cap
    /// @return borrowCap The borrow cap
    function caps() external view returns (uint16 supplyCap, uint16 borrowCap);

    /// @notice Get the total borrows of the vault
    /// @return The total borrow amount
    function totalBorrows() external view returns (uint256);
}
