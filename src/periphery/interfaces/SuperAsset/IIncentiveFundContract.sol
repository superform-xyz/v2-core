// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IIncentiveFundContract
 * @notice Interface for IncentiveFundContract which manages incentive tokens in the SuperAsset system
 */
interface IIncentiveFundContract {
    // --- Errors ---
    /// @notice Thrown when an address parameter is zero
    error ZERO_ADDRESS();

    /// @notice Thrown when amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when tokenOut is not configured
    error TOKEN_OUT_NOT_SET();

    /// @notice Thrown when tokenIn is not configured
    error TOKEN_IN_NOT_SET();

    /// @notice Thrown when contract is already initialized
    error ALREADY_INITIALIZED();

    /// @notice Thrown when the caller is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when attempting to set a non-whitelisted incentive token
    error TOKEN_NOT_WHITELISTED();

    // --- Events ---

    event TokenInIncentiveSet(address indexed token);
    event TokenOutIncentiveSet(address indexed token);

    /**
     * @notice Emitted when incentives are paid to a receiver
     * @param receiver Address that received the incentives
     * @param tokenOut Token that was paid
     * @param amount Amount that was paid
     */
    event IncentivePaid(address indexed receiver, address indexed tokenOut, uint256 amount);

    /**
     * @notice Emitted when incentives are taken from a sender
     * @param sender Address that sent the incentives
     * @param tokenIn Token that was taken
     * @param amount Amount that was taken
     */
    event IncentiveTaken(address indexed sender, address indexed tokenIn, uint256 amount);

    /**
     * @notice Emitted when tokens are withdrawn during rebalancing
     * @param receiver Address that received the tokens
     * @param tokenOut Token that was withdrawn
     * @param amount Amount that was withdrawn
     */
    event RebalanceWithdrawal(address indexed receiver, address indexed tokenOut, uint256 amount);

    /**
     * @notice Emitted when settlement token for incoming incentives is set
     * @param token Address of the token
     */
    event SettlementTokenInSet(address indexed token);

    /**
     * @notice Emitted when settlement token for outgoing incentives is set
     * @param token Address of the token
     */
    event SettlementTokenOutSet(address indexed token);

    // --- Functions ---

    /// @notice The token users send incentives to
    function tokenInIncentive() external view returns (address);

    /// @notice The token used to pay incentives
    function tokenOutIncentive() external view returns (address);

    /**
     * @notice Initializes the IncentiveFundContract
     * @param _superGovernor Address of the SuperGovernor contract
     * @param superAsset_ Address of the SuperAsset contract
     */
    function initialize(address _superGovernor, address superAsset_) external;

    /**
     * @notice Pays incentives to a receiver
     * @param receiver Address to receive the incentives
     * @param amount Amount of incentives to pay
     */
    function payIncentive(address receiver, uint256 amount) external;

    /**
     * @notice Takes incentives from a sender
     * @param sender Address to take incentives from
     * @param amount Amount of incentives to take
     */
    function takeIncentive(address sender, uint256 amount) external;

    /**
     * @notice Withdraws tokens during rebalancing
     * @param receiver Address to receive the tokens
     * @param tokenOut Token to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address receiver, address tokenOut, uint256 amount) external;

    /**
     * @notice Sets the token for incoming incentives
     * @param token Address of the token
     */
    function setTokenInIncentive(address token) external;

    /**
     * @notice Sets the token for outgoing incentives
     * @param token Address of the token
     */
    function setTokenOutIncentive(address token) external;
}
