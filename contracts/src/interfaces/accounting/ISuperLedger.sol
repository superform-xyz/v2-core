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
<<<<<<< HEAD
        address[] mainHooks;
=======
        address yieldSourceOracle;
>>>>>>> dev
        uint256 feePercent;
        address vaultShareToken;
        address feeRecipient;
        address manager;
    }

    struct HookRegistrationConfig {
<<<<<<< HEAD
        address[] mainHooks;
        address yieldSourceOracle;
=======
        address yieldSourceOracle;
        bytes32 yieldSourceOracleId;
>>>>>>> dev
        uint256 feePercent;
        address vaultShareToken;
        address feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AccountingUpdated(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        bool isInflow,
        uint256 amount,
        uint256 price
    );
<<<<<<< HEAD
    event YieldSourceOracleConfigSet(
=======

    event AccountingOutflowSkipped(
        address indexed user,
        address indexed yieldSource,
        bytes32 indexed yieldSourceOracleId,
        uint256 amount,
        uint256 price
    );

    event YieldSourceOracleConfigSet(
        bytes32 indexed yieldSourceOracleId,
>>>>>>> dev
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address vaultShareToken,
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
<<<<<<< HEAD
=======
    error ZERO_ID_NOT_ALLOWED();
>>>>>>> dev
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates accounting for a user's yield source interaction
    /// @param user The user address
<<<<<<< HEAD
    /// @param yieldSourceOracle The yield source oracle address
    /// @param yieldSource The yield source address
=======
    /// @param yieldSource The yield source address
    /// @param yieldSourceOracleId The yield source id
>>>>>>> dev
    /// @param isInflow Whether this is an inflow (true) or outflow (false)
    /// @param amount The amount of shares
    /// @return pps The price per share used for the accounting
    function updateAccounting(
        address user,
<<<<<<< HEAD
        address yieldSourceOracle,
        address yieldSource,
=======
        address yieldSource,
        bytes32 yieldSourceOracleId,
>>>>>>> dev
        bool isInflow,
        uint256 amount
    )
        external
        returns (uint256 pps);

    /// @notice Registers hooks and sets their oracle configs in one transaction
    /// @param configs Array of oracle configurations
    function setYieldSourceOracles(HookRegistrationConfig[] calldata configs) external;

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
<<<<<<< HEAD
    /// @param yieldSourceOracle The oracle address
    /// @return The oracle configuration
    function getYieldSourceOracleConfig(address yieldSourceOracle)
=======
    /// @param yieldSourceOracleId The yield source id
    /// @return The oracle configuration
    function getYieldSourceOracleConfig(bytes32 yieldSourceOracleId)
>>>>>>> dev
        external
        view
        returns (YieldSourceOracleConfig memory);

    /// @notice Returns the configurations for multiple yield source oracles
<<<<<<< HEAD
    /// @param yieldSourceOracles The array of yield source oracle addresses
    /// @return The array of oracle configurations
    function getYieldSourceOracleConfigs(address[] calldata yieldSourceOracles)
=======
    /// @param yieldSourceOracleIds The array of yield source ids
    /// @return The array of oracle configurations
    function getYieldSourceOracleConfigs(bytes32[] calldata yieldSourceOracleIds)
>>>>>>> dev
        external
        view
        returns (YieldSourceOracleConfig[] memory);
}
