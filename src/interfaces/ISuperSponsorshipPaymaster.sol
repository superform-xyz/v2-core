// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISuperSponsorshipPaymaster
/// @author Superform Labs
/// @notice Interface for a paymaster with per-strategy gas sponsorship budgets
interface ISuperSponsorshipPaymaster {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @param balance Available budget for this strategy
    /// @param totalDebited Cumulative gas spent (accounting)
    /// @param maxSingleOpCost Cap per UserOp (0 = no cap)
    /// @param paused Whether sponsorship is paused for this strategy
    struct StrategyBudget {
        uint256 balance;
        uint256 totalDebited;
        uint256 maxSingleOpCost;
        bool paused;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error STRATEGY_PAUSED();
    error GLOBAL_PAUSED();
    error INSUFFICIENT_STRATEGY_BUDGET();
    error EXCEEDS_SINGLE_OP_CAP();
    error INSUFFICIENT_UNALLOCATED_BALANCE();
    error WITHDRAW_EXCEEDS_BALANCE();
    error INSUFFICIENT_ENTRYPOINT_DEPOSIT();
    error ETH_TRANSFER_FAILED();
    error EXCEEDS_MAX_POST_OP_OVERHEAD();
    error POST_OP_OVERHEAD_BELOW_MINIMUM();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyFunded(address indexed strategy, uint256 amount);
    event StrategyCredited(address indexed strategy, uint256 amount);
    event StrategyDebited(address indexed strategy, uint256 amount);
    event StrategyWithdrawn(address indexed strategy, address indexed to, uint256 amount);
    event StrategyPaused(address indexed strategy);
    event StrategyUnpaused(address indexed strategy);
    event MaxSingleOpCostSet(address indexed strategy, uint256 maxCost);
    event PostOpGasOverheadSet(uint256 overhead);
    event GlobalPauseSet(bool paused);
    event ETHSwept(address indexed to, uint256 amount);
    event Reconciled(uint256 drift);
    event EmergencyWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        FUNDING (FUNDING_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit new ETH into a strategy's gas budget.
    ///         The sent ETH is forwarded to the EntryPoint deposit and assigned to the strategy's balance.
    /// @param strategy The strategy to fund
    function fundStrategy(address strategy) external payable;

    /// @notice Assign already-deposited but unallocated EntryPoint balance to a strategy's budget.
    ///         No ETH is transferred — this is a bookkeeping operation that moves unallocated
    ///         EntryPoint deposit (e.g. from direct deposits or gas refunds) into a strategy bucket.
    /// @param strategy The strategy to credit
    /// @param amount The amount to credit from the unallocated pool
    function creditStrategy(address strategy, uint256 amount) external;

    /// @notice Withdraw from a strategy's budget via EntryPoint
    /// @param strategy The strategy to withdraw from
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function withdrawStrategyFunds(address strategy, address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT (MANAGER_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the max cost per single UserOp for a strategy (0 = no cap)
    /// @param strategy The strategy address
    /// @param maxCost The max cost in wei
    function setMaxSingleOpCost(address strategy, uint256 maxCost) external;

    /// @notice Pause sponsorship for a strategy
    /// @param strategy The strategy to pause
    function pauseStrategy(address strategy) external;

    /// @notice Unpause sponsorship for a strategy
    /// @param strategy The strategy to unpause
    function unpauseStrategy(address strategy) external;

    /*//////////////////////////////////////////////////////////////
                        ADMIN (DEFAULT_ADMIN_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the gas overhead for postOp cost estimation.
    ///         Must be within [MIN_POST_OP_OVERHEAD, MAX_POST_OP_GAS_OVERHEAD].
    /// @param overhead Gas units to add to actualGasCost in postOp
    function setPostOpGasOverhead(uint256 overhead) external;

    /// @notice Set global pause state for all strategies
    /// @param paused Whether to pause
    function setGlobalPause(bool paused) external;

    /// @notice Sweep stuck ETH from the contract (not EntryPoint deposit).
    ///         ETH on the contract is NOT usable for gas sponsorship — it must be swept
    ///         and re-deposited via fundStrategy to enter the EntryPoint deposit.
    /// @param to The recipient address
    function sweepETH(address to) external;

    /// @notice Reconcile internal accounting with actual EntryPoint deposit.
    ///         Snaps `totalAllocated` down to match the real deposit when drift has accumulated.
    function reconcile() external;

    /// @notice Emergency withdraw from EntryPoint deposit, bypassing per-strategy accounting.
    ///         Use when withdrawStrategyFunds fails due to accounting drift.
    /// @param to Recipient address
    /// @param amount Amount to withdraw from EntryPoint deposit
    function emergencyWithdrawFromEntryPoint(address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the budget data for a strategy
    /// @param strategy The strategy address
    /// @return The StrategyBudget struct
    function getStrategyBudget(address strategy) external view returns (StrategyBudget memory);

    /// @notice Total ETH allocated across all strategy budgets
    function totalAllocated() external view returns (uint256);

    /// @notice Unallocated ETH in the EntryPoint deposit
    function unallocatedBalance() external view returns (uint256);

    /// @notice Gas overhead added in postOp
    function postOpGasOverhead() external view returns (uint256);

    /// @notice Whether the paymaster is globally paused
    function globalPaused() external view returns (bool);

    /// @notice Role for funding operations
    function FUNDING_ROLE() external view returns (bytes32);

    /// @notice Role for management operations
    function MANAGER_ROLE() external view returns (bytes32);

    /// @notice Minimum allowed postOp gas overhead
    function MIN_POST_OP_OVERHEAD() external pure returns (uint256);

    /// @notice Maximum allowed postOp gas overhead
    function MAX_POST_OP_GAS_OVERHEAD() external pure returns (uint256);
}
