// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperLedgerData
/// @author Superform Labs
/// @notice Interface defining core data structures and events for ledger accounting
/// @dev This interface is extended by ISuperLedger to provide a complete accounting system
///      It separates data structures and events from functional methods
interface ISuperLedgerData {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Represents a single accounting entry in a user's ledger
    /// @dev Used to track shares and their acquisition price for accurate profit calculation
    struct LedgerEntry {
        /// @notice Amount of shares available to be consumed in this entry
        uint256 amountSharesAvailableToConsume;
        /// @notice Price at which these shares were acquired (in asset terms)
        uint256 price;
    }

    /// @notice Collection of ledger entries for a user's position
    /// @dev Manages entries in a FIFO queue for accurate cost basis calculation
    struct Ledger {
        /// @notice Array of ledger entries
        LedgerEntry[] entries;
        /// @notice Number of entries that still have unconsumed shares
        uint256 unconsumedEntries;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when shares are added to a user's ledger
    /// @param user The user whose ledger is being updated
    /// @param yieldSourceOracle The oracle providing price information
    /// @param yieldSource The yield-bearing asset being accounted for
    /// @param amount The amount of shares being added
    /// @param pps The price per share at the time of inflow (in asset terms)
    event AccountingInflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 pps
    );
    
    /// @notice Emitted when shares are consumed from a user's ledger
    /// @param user The user whose ledger is being updated
    /// @param yieldSourceOracle The oracle providing price information
    /// @param yieldSource The yield-bearing asset being accounted for
    /// @param amount The amount of shares or assets being processed
    /// @param feeAmount The performance fee charged on yield profit
    event AccountingOutflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 feeAmount
    );

    /// @notice Emitted when an outflow is skipped due to zero fee percentage
    /// @param user The user whose outflow was skipped
    /// @param yieldSource The yield-bearing asset being accounted for
    /// @param yieldSourceOracleId The ID of the oracle for this yield source
    /// @param amount The amount of shares/assets in the skipped operation
    event AccountingOutflowSkipped(
        address indexed user, 
        address indexed yieldSource, 
        bytes4 indexed yieldSourceOracleId, 
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a referenced hook cannot be found
    error HOOK_NOT_FOUND();
    
    /// @notice Thrown when a user attempts to consume more shares than they have available
    error INSUFFICIENT_SHARES();
    
    /// @notice Thrown when a price returned from an oracle is invalid (typically zero)
    error INVALID_PRICE();
    
    /// @notice Thrown when attempting to charge a fee without a valid fee percentage
    error FEE_NOT_SET();
    
    /// @notice Thrown when setting a fee percentage outside the allowed range
    error INVALID_FEE_PERCENT();
    
    /// @notice Thrown when a critical address parameter is set to the zero address
    error ZERO_ADDRESS_NOT_ALLOWED();
    
    /// @notice Thrown when an unauthorized address attempts a restricted operation
    error NOT_AUTHORIZED();
    
    /// @notice Thrown when a non-manager address attempts a manager-only operation
    error NOT_MANAGER();
    
    /// @notice Thrown when a manager is required but not set
    error MANAGER_NOT_SET();
    
    /// @notice Thrown when providing an empty array where at least one element is required
    error ZERO_LENGTH();
    
    /// @notice Thrown when an ID parameter is set to zero
    error ZERO_ID_NOT_ALLOWED();
    
    /// @notice Thrown when an operation references an invalid ledger
    error INVALID_LEDGER();
}

/// @title ISuperLedger
/// @author Superform Labs
/// @notice Interface for the SuperLedger contract that manages yield accounting
/// @dev Extends ISuperLedgerData to provide methods for tracking and calculating performance fees
///      The accounting system tracks shares and their cost basis to accurately calculate yield
interface ISuperLedger is ISuperLedgerData {
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Updates accounting for a user's yield source interaction
    /// @dev For inflows, records new shares at current price; for outflows, calculates fees based on profit
    ///      Only authorized executors can call this function
    ///      For outflows, the fee is calculated as a percentage of the profit:
    ///      profit = (current_value - cost_basis) where current_value is based on oracle price
    /// @param user The user address whose accounting is being updated
    /// @param yieldSource The yield source address (e.g. aUSDC, cUSDC, etc.)
    /// @param yieldSourceOracleId ID for looking up the oracle configuration for this yield source
    /// @param isInflow Whether this is an inflow (true) or outflow (false)
    /// @param amountSharesOrAssets The amount of shares (for inflow) or assets (for outflow) 
    /// @param usedShares The amount of shares used for outflow calculation (0 for inflows)
    /// @return feeAmount The amount of fee to be collected in the asset being withdrawn (0 for inflows)
    function updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        returns (uint256 feeAmount);

    /// @notice Previews fees for a given amount of assets obtained from shares without modifying state
    /// @dev Used to estimate fees before executing a transaction
    ///      Fee calculation: fee = (current_value - cost_basis) * fee_percent / 10_000
    ///      Returns 0 if there is no profit (current_value <= cost_basis)
    /// @param user The user address whose fees are being calculated
    /// @param yieldSourceAddress The yield source address (e.g. aUSDC, cUSDC, etc.)
    /// @param amountAssets The amount of assets retrieved from shares (current value)
    /// @param usedShares The amount of shares used to obtain the assets
    /// @param feePercent The fee percentage in basis points (0-10000, where 10000 = 100%)
    /// @return feeAmount The amount of fee to be collected in the asset being withdrawn
    function previewFees(
        address user,
        address yieldSourceAddress,
        uint256 amountAssets,
        uint256 usedShares,
        uint256 feePercent
    )
        external
        view
        returns (uint256 feeAmount);

    /// @notice Calculates the cost basis for a given user and amount of shares without modifying state
    /// @dev Cost basis represents the original asset value of the shares when they were acquired
    ///      This is calculated proportionally based on the shares being consumed
    ///      Formula: user_cost_basis * (used_shares / total_shares)
    ///      Reverts with INSUFFICIENT_SHARES if usedShares > user's total shares
    /// @param user The user address whose cost basis is being calculated
    /// @param yieldSource The yield source address (e.g. aUSDC, cUSDC, etc.)
    /// @param usedShares The amount of shares to calculate cost basis for
    /// @return costBasis The original asset value of the specified shares
    function calculateCostBasisView(
        address user,
        address yieldSource,
        uint256 usedShares
    )
        external
        view
        returns (uint256 costBasis);
}
