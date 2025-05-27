// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperLedgerConfiguration
/// @author Superform Labs
/// @notice Interface for configuring yield source oracles and their associated fee parameters
/// @dev This interface defines the governance layer for yield tracking and fee collection
///      It manages configurations for yield source oracles, including fee percentages,
///      fee recipients, and management permissions
interface ISuperLedgerConfiguration {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Configuration for a yield source oracle
    /// @dev Stored configuration for a particular yield source, identified by its ID elsewhere
    struct YieldSourceOracleConfig {
        /// @notice Address of the oracle that provides price information for this yield source
        address yieldSourceOracle;
        /// @notice Fee percentage charged on yield in basis points (0-10000, where 10000 = 100%)
        uint256 feePercent;
        /// @notice Address that receives collected fees
        address feeRecipient;
        /// @notice Address with permission to update this configuration
        address manager;
        /// @notice Address of the ledger contract that uses this configuration
        address ledger;
    }

    /// @notice Input arguments for creating or updating a yield source oracle configuration
    /// @dev Similar to YieldSourceOracleConfig but includes the ID and excludes the manager
    ///      The manager is either derived from existing config or set to msg.sender for new configs
    struct YieldSourceOracleConfigArgs {
        /// @notice Unique identifier for this yield source oracle configuration
        bytes4 yieldSourceOracleId;
        /// @notice Address of the oracle that provides price information
        address yieldSourceOracle;
        /// @notice Fee percentage charged on yield in basis points (0-10000, where 10000 = 100%)
        uint256 feePercent;
        /// @notice Address that receives collected fees
        address feeRecipient;
        /// @notice Address of the ledger contract that uses this configuration
        address ledger;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS 
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a function restricted to managers is called by a non-manager address
    error NOT_MANAGER();

    /// @notice Thrown when providing an empty array where at least one element is required
    error ZERO_LENGTH();

    /// @notice Thrown when attempting to create a configuration that already exists
    error CONFIG_EXISTS();

    /// @notice Thrown when referencing a configuration that doesn't exist
    error CONFIG_NOT_FOUND();

    /// @notice Thrown when trying to accept a configuration proposal before the waiting period ends
    error CANNOT_ACCEPT_YET();

    /// @notice Thrown when a manager mismatch is detected during configuration operations
    error MANAGER_NOT_MATCHED();

    /// @notice Thrown when a zero ID is provided for a configuration
    error ZERO_ID_NOT_ALLOWED();

    /// @notice Thrown when setting a fee percentage outside the allowed range (0-10000)
    error INVALID_FEE_PERCENT();

    /// @notice Thrown when attempting to accept a manager role without being the pending manager
    error NOT_PENDING_MANAGER();

    /// @notice Thrown when attempting to propose changes to a configuration that already has pending changes
    error CHANGE_ALREADY_PROPOSED();

    /// @notice Thrown when a critical address parameter is set to the zero address
    error ZERO_ADDRESS_NOT_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a new yield source oracle configuration is created
    /// @param yieldSourceOracleId Unique identifier for the yield source oracle
    /// @param yieldSourceOracle Address of the oracle contract
    /// @param feePercent Fee percentage in basis points
    /// @param manager Address with permission to update this configuration
    /// @param feeRecipient Address that receives collected fees
    /// @param ledger Address of the ledger contract using this configuration
    event YieldSourceOracleConfigSet(
        bytes4 indexed yieldSourceOracleId,
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address manager,
        address feeRecipient,
        address ledger
    );

    /// @notice Emitted when changes to a yield source oracle configuration are proposed
    /// @param yieldSourceOracleId Unique identifier for the yield source oracle
    /// @param yieldSourceOracle Proposed oracle contract address
    /// @param feePercent Proposed fee percentage in basis points
    /// @param manager Current manager address (unchanged during proposal)
    /// @param feeRecipient Proposed fee recipient address
    /// @param ledger Proposed ledger contract address
    event YieldSourceOracleConfigProposalSet(
        bytes4 indexed yieldSourceOracleId,
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient,
        address manager,
        address ledger
    );

    /// @notice Emitted when proposed changes to a yield source oracle configuration are accepted
    /// @param yieldSourceOracleId Unique identifier for the yield source oracle
    /// @param yieldSourceOracle New oracle contract address
    /// @param feePercent New fee percentage in basis points
    /// @param manager Current manager address
    /// @param feeRecipient New fee recipient address
    /// @param ledger New ledger contract address
    event YieldSourceOracleConfigAccepted(
        bytes4 indexed yieldSourceOracleId,
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address manager,
        address feeRecipient,
        address ledger
    );

    /// @notice Emitted when the transfer of manager role is initiated
    /// @param yieldSourceOracleId Unique identifier for the yield source oracle
    /// @param currentManager Address of the current manager
    /// @param newManager Address of the proposed new manager
    event ManagerRoleTransferStarted(
        bytes4 indexed yieldSourceOracleId, address indexed currentManager, address indexed newManager
    );

    /// @notice Emitted when the transfer of manager role is completed
    /// @param yieldSourceOracleId Unique identifier for the yield source oracle
    /// @param newManager Address of the new manager who accepted the role
    event ManagerRoleTransferAccepted(bytes4 indexed yieldSourceOracleId, address indexed newManager);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates initial configurations for yield source oracles
    /// @dev This function can only be used for first-time configuration setup
    ///      For existing configurations, use proposeYieldSourceOracleConfig instead
    ///      The caller becomes the manager for each new configuration
    /// @param configs Array of initial oracle configurations to be created
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external;

    /// @notice Proposes changes to existing yield source oracle configurations
    /// @dev Only the current manager of a configuration can propose changes
    ///      Proposals are subject to a time-lock before they can be accepted
    ///      Fee percentage changes are limited to a maximum percentage change
    /// @param configs Array of proposed configuration changes
    function proposeYieldSourceOracleConfig(YieldSourceOracleConfigArgs[] calldata configs) external;

    /// @notice Accepts previously proposed changes to yield source oracle configurations
    /// @dev Can only be called by the manager after the time-lock period has passed
    ///      Accepting the proposal replaces the current configuration with the proposed one
    /// @param yieldSourceOracleIds Array of yield source IDs with pending proposals to accept
    function acceptYieldSourceOracleConfigProposal(bytes4[] calldata yieldSourceOracleIds) external;

    /// @notice Initiates the transfer of manager role to a new address
    /// @dev First step in a two-step process for transferring management rights
    ///      Only the current manager can initiate the transfer
    ///      The transfer must be accepted by the new manager to complete
    /// @param yieldSourceOracleId The yield source oracle ID to transfer management of
    /// @param newManager The address of the proposed new manager
    function transferManagerRole(bytes4 yieldSourceOracleId, address newManager) external;

    /// @notice Accepts the pending manager role transfer
    /// @dev Second step in the two-step process for transferring management rights
    ///      Can only be called by the address designated as the pending manager
    ///      Completes the transfer, giving the caller full management rights
    /// @param yieldSourceOracleId The yield source oracle ID to accept management of
    function acceptManagerRole(bytes4 yieldSourceOracleId) external;

    /// @notice Retrieves the current configuration for a yield source oracle
    /// @dev Used by components that need oracle and fee information
    ///      Returns the complete configuration structure including all parameters
    /// @param yieldSourceOracleId The unique identifier for the yield source oracle
    /// @return Complete configuration struct for the specified yield source oracle
    function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId)
        external
        view
        returns (YieldSourceOracleConfig memory);

    /// @notice Retrieves configurations for multiple yield source oracles in a single call
    /// @dev Batch version of getYieldSourceOracleConfig for gas efficiency
    ///      Returns an array of configurations in the same order as the input IDs
    /// @param yieldSourceOracleIds Array of yield source oracle IDs to retrieve
    /// @return configs Array of configuration structs for the specified yield source oracles
    function getYieldSourceOracleConfigs(bytes4[] calldata yieldSourceOracleIds)
        external
        view
        returns (YieldSourceOracleConfig[] memory configs);
}
