// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ISuperHook, Execution } from "../../core/interfaces/ISuperHook.sol";

/// @title ISuperVaultStrategy
/// @notice Interface for SuperVault strategy implementation that manages yield sources and executes strategies
/// @author SuperForm Labs
interface ISuperVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_INITIALIZED();
    error INVALID_VAULT();
    error INVALID_MANAGER();
    error INVALID_STRATEGIST();
    error INVALID_EMERGENCY_ADMIN();
    error INVALID_VAULT_CAP();
    error INVALID_SUPER_VAULT_CAP();
    error INVALID_MAX_ALLOCATION_RATE();
    error INVALID_VAULT_THRESHOLD();
    error ZERO_ADDRESS();
    error INVALID_ALLOCATION_RATE();
    error INVALID_AMOUNT();
    error INVALID_HOOK();
    error INVALID_HOOK_ROOT();
    error INVALID_ORACLE();
    error INVALID_YIELD_SOURCE();
    error INVALID_FEE();
    error INVALID_FEE_RECIPIENT();
    error INVALID_CONTROLLER();
    error UNAUTHORIZED();
    error TIMELOCK_NOT_EXPIRED();
    error REQUEST_NOT_FOUND();
    error YIELD_SOURCE_NOT_FOUND();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error VAULT_THRESHOLD_NOT_MET();
    error VAULT_CAP_EXCEEDED();
    error MAX_ALLOCATION_RATE_EXCEEDED();
    error EMERGENCY_WITHDRAWALS_DISABLED();
    error INSUFFICIENT_FREE_ASSETS();
    error ZERO_LENGTH();
    error ARRAY_LENGTH_MISMATCH();
    error EXECUTION_FAILED();
    error INCOMPLETE_DEPOSIT_MATCH();
    error INCOMPLETE_REDEEM_MATCH();
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Initialized(
        address indexed vault,
        address indexed manager,
        address indexed strategist,
        address emergencyAdmin,
        GlobalConfig config
    );
    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceDeactivated(address indexed source);
    event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle);
    event YieldSourceReactivated(address indexed source);
    event GlobalConfigUpdated(
        uint256 vaultCap, uint256 superVaultCap, uint256 maxAllocationRate, uint256 vaultThreshold
    );
    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime);
    event EmergencyWithdrawableUpdated(bool withdrawable);
    event EmergencyWithdrawal(address indexed recipient, uint256 assets);
    event FeePaid(address indexed recipient, uint256 assets, uint256 bps);
    /*////////////////////////////////`//////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct GlobalConfig {
        uint256 vaultCap; // Maximum assets per individual yield source
        uint256 superVaultCap; // Maximum total assets across all yield sources
        uint256 maxAllocationRate; // Maximum allocation percentage per yield source (in basis points)
        uint256 vaultThreshold; // Minimum TVL of a yield source that can be interacted with
    }

    struct SharePricePoint {
        /// @notice Number of shares at this price point
        uint256 shares;
        /// @notice Price per share in asset decimals when these shares were minted
        uint256 pricePerShare;
    }

    struct SuperVaultState {
        uint256 pendingDepositRequest;
        uint256 pendingRedeemRequest;
        uint256 maxMint;
        uint256 maxWithdraw;
        uint256 sharePricePointCursor;
        uint256 averageDepositPrice;
        uint256 averageWithdrawPrice;
        SharePricePoint[] sharePricePoints;
    }

    struct FulfillmentVars {
        // Common variables used in both deposit and redeem flows
        uint256 totalRequestedAmount; // Total amount of assets/shares requested across all users
        uint256 spentAmount; // Running total of assets/shares spent in hooks
        uint256 pricePerShare; // Current price per share, used for calculations
        uint256 requestedAmount; // Individual user's requested amount
        address prevHook; // Previous hook in sequence for hook chaining
        // Deposit-specific variables
        uint256 availableAmount; // Only used in deposit to check initial balance
        // Variables for share calculations
        uint256 shares; // Used in deposit for minting shares
    }

    struct MatchVars {
        // Variables for deposit processing
        uint256 depositAssets; // Assets requested in the deposit
        uint256 sharesNeeded; // Total shares needed for this deposit
        uint256 remainingShares; // Remaining shares needed to fulfill deposit
        // Variables for redeem processing
        uint256 redeemShares; // Shares available from redeemer
        uint256 sharesToUse; // Shares to take from current redeemer
        // Variables for historical assets calculation
        uint256 lastConsumedIndex; // Last consumed share price point index
        uint256 finalAssets; // Final assets after fee calculation
        // Price tracking
        uint256 currentPricePerShare; // Current price per share for calculations
    }

    struct AllocationVars {
        // Hook execution variables
        address prevHook;
        uint256 amount;
        // Current yield source state
        uint256 currentYieldSourceAssets;
        // Hook type and execution
        ISuperHook.HookType hookType;
        Execution[] executions;
    }

    struct FeeConfig {
        uint256 feeBps; // Fee in basis points
        address recipient; // Fee recipient address
    }

    struct YieldSource {
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    struct YieldSourceTVL {
        address source;
        uint256 tvl;
    }

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    enum Operation {
        Request,
        Cancel,
        Claim
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Initialize the strategy contract
    /// @param vault_ Address of the SuperVault
    /// @param manager_ Address of the manager
    /// @param strategist_ Address of the strategist
    /// @param emergencyAdmin_ Address of the emergency admin
    /// @param config_ Initial global configuration
    function initialize(
        address vault_,
        address manager_,
        address strategist_,
        address emergencyAdmin_,
        GlobalConfig memory config_
    )
        external;

    /*//////////////////////////////////////////////////////////////
                        REQUEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Update state for a deposit or a redeem operation
    /// @param controller The controller address
    /// @param assetsOrShares Amount of assets being deposited
    /// @param operation The operation to perform
    /// @param isDeposit Whether the operation is a deposit
    function handleOperation(address controller, uint256 assetsOrShares, Operation operation, bool isDeposit) external;

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Fulfill deposit requests for multiple users
    /// @param users Array of users with pending deposit requests
    /// @param hooks Array of hooks to use for deposits
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    function fulfillDepositRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external;

    /// @notice Fulfill redeem requests for multiple users
    /// @param users Array of users with pending redeem requests
    /// @param hooks Array of hooks to use for redeems
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    function fulfillRedeemRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external;

    /// @notice Match redeem requests with deposit requests directly
    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external;

    /// @notice Allocate funds between yield sources
    /// @param hooks Array of hooks to use for allocations
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    function allocate(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external;

    /// @notice Claim rewards from yield sources
    /// @param hooks Array of hooks to use for claiming rewards
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    function claimRewards(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external;

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Add a new yield source to the system
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function addYieldSource(address source, address oracle) external;

    /// @notice Update oracle for an existing yield source
    /// @param source Address of the yield source
    /// @param newOracle Address of the new oracle
    function updateYieldSourceOracle(address source, address newOracle) external;

    /// @notice Toggle a yield source's active state
    /// @param source Address of the yield source to toggle
    /// @param activate Whether to activate or deactivate the yield source
    function toggleYieldSource(address source, bool activate) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if the strategy is initialized
    /// @return True if the strategy is initialized, false otherwise
    function isInitialized() external view returns (bool);

    /// @notice Get the vault info
    /// @dev returns vault address, asset address, and vault decimals
    function getVaultInfo() external view returns (
        address vault, 
        address asset, 
        uint8 vaultDecimals
    );

    /// @notice Get the hook info
    /// @dev returns hook root, proposed hook root, and hook root effective time
    function getHookInfo() external view returns (
        bytes32 hookRoot, 
        bytes32 proposedHookRoot, 
        uint256 hookRootEffectiveTime
    );

    /// @notice Get the global and fee configurations   
    function getConfigInfo() external view returns (
        GlobalConfig memory globalConfig, 
        FeeConfig memory feeConfig
    );

    /// @notice Get the current price per share of the SuperVault
    /// @return pricePerShare The current price per share in underlying decimals
    function getSuperVaultPPS() external view returns (uint256 pricePerShare);

    /// @notice Get total assets managed by the strategy
    /// @return totalAssets_ Total assets across all yield sources and idle assets
    /// @return sourceTVLs Array of TVL information for each yield source
    function totalAssets() external view returns (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs);

    /// @notice Get the total supply of shares in the SuperVault
    /// @return The total number of shares currently in circulation
    function totalSupply() external view returns (uint256);

    /// @notice Get the maximum amount of shares that can be minted for an owner
    /// @param owner The owner address
    /// @return The maximum amount of shares that can be minted
    function maxMint(address owner) external view returns (uint256);

    /// @notice Get the maximum amount of assets that can be withdrawn for an owner
    /// @param owner The owner address
    /// @return The maximum amount of assets that can be withdrawn
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Get a yield source's configuration
    /// @param source Address of the yield source
    function getYieldSource(address source) external view returns (YieldSource memory);

    /// @notice Get the list of all yield sources
    function getYieldSourcesList() external view returns (address[] memory);

    /// @notice Check if a hook is allowed via merkle proof
    /// @param hook Address of the hook to check
    /// @param proof Merkle proof for the hook
    function isHookAllowed(address hook, bytes32[] calldata proof) external view returns (bool);

    /// @notice Get the average deposit price for a user
    /// @param owner The owner address
    /// @return The average deposit price for the user
    function getAverageDepositPrice(address owner) external view returns (uint256);

    /// @notice Get the average withdraw price for a user
    /// @param owner The owner address
    /// @return The average withdraw price for the user
    function getAverageWithdrawPrice(address owner) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        ERC7540 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the pending deposit request amount for a controller
    /// @param controller The controller address
    /// @return pendingAssets The amount of assets pending deposit
    function pendingDepositRequest(address controller) external view returns (uint256 pendingAssets);

    /// @notice Get the pending redeem request amount for a controller
    /// @param controller The controller address
    /// @return pendingShares The amount of shares pending redemption
    function pendingRedeemRequest(address controller) external view returns (uint256 pendingShares);
}
