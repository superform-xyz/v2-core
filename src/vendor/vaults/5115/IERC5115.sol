// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface IERC5115 {
    function asset() external view returns (address assetTokenAddress);

    /// @notice Deposit tokens into the vault
    /// @param receiver The address to receive the shares
    /// @param tokenIn The address of the token to deposit
    /// @param amountTokenToDeposit The amount of tokens to deposit
    /// @param minSharesOut The minimum amount of shares to receive
    /// @param depositFromInternalBalance Whether to deposit from the internal balance
    /// @return amountSharesOut The amount of shares received
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut,
        bool depositFromInternalBalance
    )
        external
        returns (uint256 amountSharesOut);

    /// @notice Redeem shares from the vault
    /// @param receiver The address to receive the tokens
    /// @param amountSharesToRedeem The amount of shares to redeem
    /// @param tokenOut The address of the token to redeem
    /// @param minTokenOut The minimum amount of tokens to receive
    /// @param burnFromInternalBalance Whether to burn shares from the internal balance
    /// @return amountTokenOut The amount of tokens received
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut,
        bool burnFromInternalBalance
    )
        external
        returns (uint256 amountTokenOut);
}
