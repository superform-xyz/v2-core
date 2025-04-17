// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/**
 * @title Incentive Fund Contract
 * @notice Manages incentive tokens.
 */
contract IncentiveFundContract is AccessControl {
    // --- State ---
    address public tokenInIncentive;  // The token users send incentives to.
    address public tokenOutIncentive; // The token we pay incentives with.

    // --- Events ---
    event IncentivePaid(address receiver, address tokenOut, uint256 amount);
    event IncentiveTaken(address sender, address tokenIn, uint256 amount);
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);

    // --- Constructor ---
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
    }

    // --- State Changing Functions ---

    /**
     * @notice Pays incentives to a receiver.
     * @param receiver The address to receive the incentives.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives requested.
     * @return amountOut The amount of incentives actually paid.
     */
    function payIncentive(address receiver, address tokenOut, uint256 amount)
    external
    onlyRole(INCENTIVE_FUND_MANAGER)
    returns (uint256 amountOut)
    {
        require(receiver != address(0), "IncentiveFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");

        amountOut = previewPayIncentive(tokenOut, amount);
        IERC20(tokenOut).transfer(receiver, amountOut);
        emit IncentivePaid(receiver, tokenOut, amountOut);
    }

    /**
     * @notice Takes incentives from a sender.
     * @param sender The address to send the incentives from.
     * @param tokenIn The token the incentives are paid in.
     * @param amount The amount of incentives to take.
     */
    function takeIncentive(address sender, address tokenIn, uint256 amount)
    external
    onlyRole(INCENTIVE_FUND_MANAGER)
    {
        require(sender != address(0), "IncentiveFund: Sender cannot be zero address");
        require(tokenIn != address(0), "IncentiveFund: TokenIn cannot be zero address");

        IERC20(tokenIn).transferFrom(sender, address(this), amount);
        emit IncentiveTaken(sender, tokenIn, amount);
    }

    /**
     * @notice Settles incentives for a user.
     * @param user The address of the user.
     * @param amount The amount of incentives (positive for pay, negative for take).
     */
    function settleIncentive(address user, int256 amount) internal {
        if (amount > 0) {
            payIncentive(user, tokenOutIncentive, uint256(amount));
        } else if (amount < 0) {
            takeIncentive(user, tokenInIncentive, uint256(-amount));
        }
        // If amount == 0, do nothing.
    }

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
        require(receiver != address(0), "IncentiveFund: Receiver cannot be zero address");
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");

        IERC20(tokenOut).transferFrom(address(this), receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }

    // --- View Functions ---

    /**
     * @notice Preview the amount of incentives to pay.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives requested.
     * @return amountOut The actual amount of incentives to pay.
     */
    function previewPayIncentive(address tokenOut, uint256 amount)
    public
    view
    returns (uint256 amountOut)
    {
        require(tokenOut != address(0), "IncentiveFund: TokenOut cannot be zero address");
        amountOut = _cappingLogic(tokenOut, amount);
    }

    // --- Internal Functions ---

    /**
     * @notice Applies capping logic to the incentive amount.
     * @param tokenOut The token to pay the incentives in.
     * @param amount The amount of incentives.
     * @return cappedAmount The capped amount of incentives.
     */
    function _cappingLogic(address tokenOut, uint256 amount)
    internal
    view
    returns (uint256 cappedAmount)
    {
        // TBD: It could be something no more than X% of the remaining availability for tokenOut
        uint256 balance = IERC20(tokenOut).balanceOf(address(this));
        cappedAmount = (amount <= balance) ? amount : balance; // Simple cap: amount or balance, whichever is smaller
    }

    function setSettlementTokenIn(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "IncentiveFund: Token address cannot be zero");
        tokenInIncentive = token;
        emit SettlementTokenInSet(token);
    }

    function setSettlementTokenOut(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "IncentiveFund: Token address cannot be zero");
        tokenOutIncentive = token;
        emit SettlementTokenOutSet(token);
    }
}

