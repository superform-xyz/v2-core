// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/token/ERC4626/extensions/IERC4626.sol";

/**
 * @title ISuperVault
 * @notice Interface for SuperVault, an ERC-4626 compliant vault that manages multiple yield sources
 * @dev This interface defines the core functionality for:
 *      1. Managing yield sources and their configurations
 *      2. Executing deposit/redeem operations through hook pathways
 *      3. Setting allocation proportions across yield sources
 *      4. Maintaining vault-wide configuration and limits
 */
interface ISuperVault is IERC4626 {
    /*//////////////////////////////////////////////////////////////
                          DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Configuration parameters for the vault, set at deployment and immutable
     * @param vaultCap Maximum amount of assets that can be deposited into a single yield source
     * @param superVaultCap Maximum total assets the SuperVault can hold across all yield sources
     * @param vaultThreshold Minimum TVL required before allocations can be made
     * @param maxAllocationRate Maximum allocation rate per yield source in basis points (e.g., 2000 = 20%)
     */
    struct VaultConfig {
        uint256 vaultCap;    
        uint256 superVaultCap;  
        uint256 vaultThreshold;    
        uint256 maxAllocationRate; 
    }

    /**
     * @notice Configuration for each yield source integrated with the vault
     * @param oracle Address of the price oracle used for valuation
     * @param vaultType Type identifier of the vault (e.g., "ERC4626")
     * @param depositHooks Ordered sequence of hooks executed during deposits
     * @param redeemHooks Ordered sequence of hooks executed during redemptions
     * @param allocation Current allocation percentage in basis points
     * @param isActive Flag indicating if the yield source is currently active
     * @dev The last hook in both deposit and redeem pathways must be SuperLedger
     */
    struct YieldSourceConfig {
        address oracle;           
        string vaultType;         
        address[] depositHooks;    
        address[] redeemHooks;     
        uint256 allocation;        
        bool isActive;            
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address authorized to manage yield sources and allocation strategies
    function strategist() external view returns (address);

    /// @notice Immutable configuration parameters set at deployment
    function vaultConfig() external view returns (VaultConfig memory);

    /// @notice List of yield sources currently integrated with the vault
    function activeYieldSources(uint256) external view returns (address);

    /// @notice Mapping of yield source to its configuration
    function yieldSourceConfigs(address) external view returns (YieldSourceConfig memory);

    /// @notice Registry for standardizing hook data encoding across different vault types
    function encoderRegistry() external view returns (IHookDataEncoderRegistry);

    /// @notice Central registry for contract addresses and configurations
    function superRegistry() external view returns (ISuperRegistry);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when strategist is transferred
    event StrategistTransferred(address indexed oldStrategist, address indexed newStrategist);

    /// @notice Emitted when a yield source is added
    event YieldSourceAdded(
        address indexed yieldSource,
        address indexed oracle,
        string vaultType,
        address[] depositHooks,
        address[] redeemHooks
    );

    /// @notice Emitted when a yield source is removed
    event YieldSourceRemoved(address indexed yieldSource);

    /// @notice Emitted when hooks are updated for a yield source
    event HooksUpdated(
        address indexed yieldSource,
        address[] depositHooks,
        address[] redeemHooks
    );

    /// @notice Emitted when target proportions are set
    event TargetProportionsSet(uint256[] proportions);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Only strategist can call this function
    error ONLY_STRATEGIST();

    /// @notice Cannot transfer strategist to zero address
    error INVALID_STRATEGIST();

    /// @notice Invalid vault configuration parameters
    error INVALID_CONFIG();

    /// @notice Invalid yield source address
    error INVALID_YIELD_SOURCE();

    /// @notice Invalid allocation parameters
    error INVALID_ALLOCATION();

    /// @notice Invalid hooks configuration
    error INVALID_HOOKS();

    /// @notice Duplicate hooks in pathway
    error DUPLICATE_HOOKS();

    /// @notice Execution failed
    error EXECUTION_FAILED();

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers strategist role to a new address
     * @dev Emits StrategistTransferred event on successful transfer
     * @param newStrategist Address of the new strategist
     */
    function transferStrategist(address newStrategist) external;

    /**
     * @notice Adds a new yield source to the vault
     * @dev Performs validation checks and sets up hook pathways
     * @param yieldSource Address of the yield source to add
     * @param oracle Price oracle for the yield source
     * @param vaultType Type identifier for the yield source
     * @param depositHooks Sequence of hooks for deposits
     * @param redeemHooks Sequence of hooks for redemptions
     */
    function addYieldSource(
        address yieldSource,
        address oracle,
        string calldata vaultType,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external;

    /**
     * @notice Removes a yield source from the vault
     * @dev Can only remove yield sources with 0 allocation
     * @param yieldSource Address of the yield source to remove
     */
    function removeYieldSource(address yieldSource) external;

    /**
     * @notice Updates the hook pathways for a yield source
     * @param yieldSource Address of the yield source to update
     * @param depositHooks New sequence of hooks for deposits
     * @param redeemHooks New sequence of hooks for redemptions
     */
    function updateYieldSourcePathway(
        address yieldSource,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external;

    /**
     * @notice Set target proportions for yield sources and rebalance
     * @dev Proportions are in basis points (100% = 10000)
     * @param proportions Array of allocation percentages in basis points
     */
    function setTargetProportions(uint256[] calldata proportions) external;

    /**
     * @notice Execute a sequence of hooks for a yield source
     * @param yieldSource Address of the yield source
     * @param hooks Array of hook addresses to execute
     * @param hookData Array of encoded data for each hook
     * @return success Whether the execution was successful
     */
    function executeHookPathway(
        address yieldSource,
        address[] memory hooks,
        bytes[] memory hookData
    ) external returns (bool success);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get configuration for a yield source
     * @param yieldSource Address of the yield source
     * @return The yield source configuration
     */
    function getYieldSourceConfig(address yieldSource) external view returns (YieldSourceConfig memory);

    /**
     * @notice Get list of active yield sources
     * @return active Array of active yield source addresses
     */
    function getActiveYieldSources() external view returns (address[] memory active);

    /**
     * @notice Get hooks for a yield source based on operation type
     * @param yieldSource Address of the yield source
     * @param isDeposit Whether to return deposit hooks (true) or redeem hooks (false)
     * @return Array of hook addresses
     */
    function getYieldSourceHooks(address yieldSource, bool isDeposit) external view returns (address[] memory);

    /**
     * @notice Returns the maximum amount of assets that can be deposited
     * @param receiver Address receiving the deposit shares
     * @return Maximum deposit amount based on vault cap
     */
    function maxDeposit(address receiver) external view returns (uint256);

    /**
     * @notice Returns the total assets managed by the vault across all yield sources
     * @return Total assets in underlying token
     */
    function totalAssets() external view returns (uint256);
} 