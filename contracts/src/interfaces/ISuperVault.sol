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
     * @dev The last hook in both deposit and redeem pathways must be SuperLedgerHook
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

    /// @notice Invalid yield source address
    error INVALID_YIELD_SOURCE();

    /// @notice Invalid oracle address
    error INVALID_ORACLE();

    /// @notice Invalid vault type
    error INVALID_TYPE();

    /// @notice Yield source already exists
    error YIELD_SOURCE_ALREADY_ADDED();

    /// @notice Yield source not found
    error YIELD_SOURCE_NOT_FOUND();

    /// @notice Invalid hooks configuration
    error INVALID_HOOKS();

    /// @notice Duplicate hooks in pathway
    error DUPLICATE_HOOKS();

    /// @notice Hook not whitelisted
    error HOOK_NOT_WHITELISTED();

    /// @notice Invalid proportions
    error INVALID_PROPORTIONS();

    /// @notice Encoder not found
    error ENCODER_NOT_FOUND();

    /// @notice Invalid configuration parameters
    error INVALID_CONFIG();

    /// @notice Hook execution failed
    error EXECUTION_FAILED();

    /// @notice Invalid allocation
    error INVALID_ALLOCATION();

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer strategist role to a new address
    /// @param newStrategist Address of the new strategist
    function transferStrategist(address newStrategist) external;

    /// @notice Add a new yield source
    /// @param yieldSource Address of the yield source
    /// @param oracle Address of the price oracle
    /// @param vaultType Type of the vault
    /// @param depositHooks Ordered list of hooks for deposits (last must be SuperLedgerHook)
    /// @param redeemHooks Ordered list of hooks for redemptions (last must be SuperLedgerHook)
    function addYieldSource(
        address yieldSource,
        address oracle,
        string calldata vaultType,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external;

    /// @notice Update hooks for a yield source
    /// @param yieldSource Address of the yield source
    /// @param depositHooks New ordered list of hooks for deposits (last must be SuperLedgerHook)
    /// @param redeemHooks New ordered list of hooks for redemptions (last must be SuperLedgerHook)
    function updateYieldSourcePathway(
        address yieldSource,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external;

    /// @notice Remove a yield source (must have 0 allocation)
    /// @param yieldSource Address of the yield source to remove
    function removeYieldSource(address yieldSource) external;

    /// @notice Set target proportions for yield sources
    /// @param proportions Array of allocation percentages in basis points (must sum to 10000)
    function setTargetProportions(uint256[] calldata proportions) external;

    /// @notice Execute a sequence of hooks for a yield source
    /// @param yieldSource Address of the yield source
    /// @param hooks Array of hook addresses to execute
    /// @param hookData Array of encoded data for each hook
    /// @return success Whether the execution was successful
    function executeHookPathway(
        address yieldSource,
        address[] memory hooks,
        bytes[] memory hookData
    ) external returns (bool success);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current vault configuration
    function getVaultConfig() external view returns (VaultConfig memory);

    /// @notice Get yield source configuration
    function getYieldSourceConfig(address yieldSource) external view returns (YieldSourceConfig memory);

    /// @notice Get active yield sources
    function getActiveYieldSources() external view returns (address[] memory);

    /// @notice Get hooks for a yield source
    function getYieldSourceHooks(address yieldSource) external view returns (address[] memory);
} 