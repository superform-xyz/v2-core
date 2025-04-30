// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAssetBank
 * @notice Interface for AssetBank contract which manages asset holdings and withdrawals
 * for the SuperAsset system. This contract is responsible for handling asset withdrawals
 * during rebalancing operations.
 */
interface IAssetBank {
    /**
     * @notice Withdraws tokens from the bank
     * @param receiver The address to receive the tokens
     * @param tokenOut The token to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(
        address receiver,
        address tokenOut,
        uint256 amount
    ) external;

    /**
     * @notice Emitted when tokens are withdrawn during rebalancing
     * @param receiver Address that received the tokens
     * @param tokenOut Token that was withdrawn
     * @param amount Amount that was withdrawn
     */

    // --- Events ---
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);
}
