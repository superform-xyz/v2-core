// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IYearnVault {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function balanceOf(address account) external view returns (uint256);    
    
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Deposit assets into the vault.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraw assets from the vault.
    function withdraw(uint256 maxShares, address receiver, uint256 maxLoss) external returns (uint256 assets);
}

