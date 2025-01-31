// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperHookRegistry
/// @notice Interface for the SuperHookRegistry contract that manages yield source hooks and their accounting
interface ISuperLedger {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct LedgerEntry {
        uint256 amountSharesAvailableToConsume;
        uint256 price;
    }

    struct Ledger {
        LedgerEntry[] entries;
        uint256 unconsumedEntries;
    }

    struct YieldSourceOracleConfig {
        address yieldSourceOracle;
        uint256 feePercent;
        address feeRecipient;
        address manager;
    }

    struct YieldSourceOracleConfigArgs {
        bytes32 yieldSourceOracleId;
        address yieldSourceOracle;
        uint256 feePercent;
        address feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AccountingInflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 pps
    );
    event AccountingOutflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 feeAmount
    );

    event AccountingOutflowSkipped(
        address indexed user, address indexed yieldSource, bytes32 indexed yieldSourceOracleId, uint256 amount
    );

    event YieldSourceOracleConfigSet(
        bytes32 indexed yieldSourceOracleId,
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address manager,
        address feeRecipient
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HOOK_NOT_FOUND();
    error INSUFFICIENT_SHARES();
    error INVALID_PRICE();
    error FEE_NOT_SET();
    error INVALID_FEE_PERCENT();
    error ZERO_ADDRESS_NOT_ALLOWED();
    error NOT_AUTHORIZED();
    error NOT_MANAGER();
    error MANAGER_NOT_SET();
    error ZERO_LENGTH();
    error ZERO_ID_NOT_ALLOWED();
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates accounting for a user's yield source interaction
    /// @param user The user address
    /// @param yieldSource The yield source address
    /// @param yieldSourceOracleId The yield source id
    /// @param isInflow Whether this is an inflow (true) or outflow (false)
    /// @param amountSharesOrAssets The amount of shares or assets
    /// @return feeAmount The amount of fee to be collected in the asset being withdrawn (only for outflows)
    function updateAccounting(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets
    )
        external
        returns (uint256 feeAmount);

    /// @notice Registers hooks and sets their oracle configs in one transaction
    /// @param configs Array of oracle configurations
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external;

    /// @notice Returns the ledger for a specific user and yield source
    /// @param user The user address
    /// @param yieldSource The yield source address
    /// @return entries Array of ledger entries
    /// @return unconsumedEntries Number of unconsumed entries
    function getLedger(
        address user,
        address yieldSource
    )
        external
        view
        returns (LedgerEntry[] memory entries, uint256 unconsumedEntries);

    /// @notice Returns the configuration for a yield source oracle
    /// @param yieldSourceOracleId The yield source id
    /// @return The oracle configuration
    function getYieldSourceOracleConfig(bytes32 yieldSourceOracleId)
        external
        view
        returns (YieldSourceOracleConfig memory);

    /// @notice Returns the configurations for multiple yield source oracles
    /// @param yieldSourceOracleIds The array of yield source ids
    /// @return The array of oracle configurations
    function getYieldSourceOracleConfigs(bytes32[] calldata yieldSourceOracleIds)
        external
        view
        returns (YieldSourceOracleConfig[] memory);
}
