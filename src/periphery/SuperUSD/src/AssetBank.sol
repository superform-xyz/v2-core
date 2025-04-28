// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Swap Fee Fund
 * @notice Manages swap fee tokens.
 */
contract AssetBank is AccessControl{
    using SafeERC20 for IERC20;

    // --- Events ---
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);

    // --- Constructor ---
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
    }

    // --- State Changing Functions ---

    /**
     * @notice Withdraws tokens from the fund.
     * @param receiver The address to receive the tokens.
     * @param tokenOut The token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdraw(address receiver, address tokenOut, uint256 amount)
    external
    onlyRole(INCENTIVE_FUND_MANAGER)
    {
        require(receiver != address(0), "SwapFeeFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "SwapFeeFund: TokenOut cannot be zero address");

        IERC20(tokenOut).safeTransferFrom(address(this), receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }
}




