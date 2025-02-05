// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { ISuperHook, Execution } from "../../core/interfaces/ISuperHook.sol";

/// @title ISuperVault
/// @notice Interface for SuperVault contract that manages multiple yield sources
/// @author SuperForm Labs
interface ISuperVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_AMOUNT();
    error ZERO_ADDRESS();
    error ZERO_LENGTH();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error YIELD_SOURCE_NOT_FOUND();
    error INVALID_ALLOCATION();
    error INVALID_VAULT_CAP();
    error INVALID_SUPER_VAULT_CAP();
    error INVALID_MAX_ALLOCATION_RATE();
    error INVALID_VAULT_THRESHOLD();
    error INVALID_FEE();
    error INVALID_FEE_RECIPIENT();
    error INVALID_ORACLE();
    error TIMELOCK_NOT_EXPIRED();
    error INVALID_HOOK_ROOT();
    error INVALID_HOOK_PROOF();
    error INVALID_OWNER_OR_OPERATOR();
    error INVALID_CONTROLLER_OR_OPERATOR();
    error UNAUTHORIZED();
    error INVALID_ASSET();
    error INVALID_MANAGER();
    error INVALID_STRATEGIST();
    error INVALID_KEEPER();
    error INVALID_EMERGENCY_ADMIN();
    error INVALID_AMOUNT();
    error INVALID_OWNER();
    error INVALID_CONTROLLER();
    error INVALID_YIELD_SOURCE();
    error REQUEST_NOT_FOUND();
    error REQUEST_ALREADY_CANCELLED();
    error REQUEST_ALREADY_CLAIMED();
    error INVALID_SIGNATURE();
    error INVALID_HOOK();
    error INVALID_TARGET();
    error EXECUTION_FAILED();
    error VAULT_CAP_EXCEEDED();
    error MAX_ALLOCATION_RATE_EXCEEDED();
    error VAULT_THRESHOLD_NOT_MET();
    error ARRAY_LENGTH_MISMATCH();
    error CANCELLATION_IS_PENDING();
    error INVALID_DEPOSIT_CLAIM();
    error NOT_IMPLEMENTED();
    error INCOMPLETE_DEPOSIT_MATCH();
    error PAUSED();
    error NOT_PAUSED();
    error EMERGENCY_WITHDRAWAL_FAILED();
    error INSUFFICIENT_FREE_ASSETS();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceDeactivated(address indexed source);
    event YieldSourceProposed(address indexed source, address indexed oracle, uint256 effectiveTime);
    event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle);
    event YieldSourceReactivated(address indexed source);
    event GlobalConfigUpdated(
        uint256 vaultCap, uint256 superVaultCap, uint256 maxAllocationRate, uint256 vaultThreshold
    );
    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    /// @notice Event emitted when a deposit request is fulfilled
    event DepositFulfilled(address indexed controller, address indexed owner, uint256 shares);
    event DepositRequestCancelled(address indexed controller, address sender);
    event RedeemRequestCancelled(address indexed controller, address sender);
    event EmergencyWithdrawal(address indexed recipient, uint256 assets);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event StrategistTransferred(address indexed oldStrategist, address indexed newStrategist);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProposedYieldSource {
        address source; // Address of the yield source
        address oracle; // Address of the oracle
        uint256 effectiveTime; // Timestamp when proposal can be executed
        bool isPending; // Whether proposal is pending
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

    struct SharePricePoint {
        /// @notice Number of shares at this price point
        uint256 shares;
        /// @notice Price per share in asset decimals when these shares were minted
        uint256 pricePerShare;
    }

    struct YieldSource {
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    struct GlobalConfig {
        uint256 vaultCap; // Maximum assets per individual yield source
        uint256 superVaultCap; // Maximum total assets across all yield sources
        uint256 maxAllocationRate; // Maximum allocation percentage per yield source (in basis points)
        uint256 vaultThreshold; // Minimum TVL of a yield source that can be interacted with
    }

    struct FeeConfig {
        uint256 feeBps; // Fee in basis points
        address recipient; // Fee recipient address
    }

    struct SuperVaultState {
        uint256 pendingDepositRequest;
        uint256 pendingRedeemRequest;
        uint256 maxMint;
        uint256 maxWithdraw;
        uint256 sharePricePointCursor;
        SharePricePoint[] sharePricePoints;
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

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getYieldSource(address source) external view returns (YieldSource memory);
    function getGlobalConfig() external view returns (GlobalConfig memory);
    function getFeeConfig() external view returns (FeeConfig memory);
    function getHookRoot() external view returns (bytes32);
    function getProposedHookRoot() external view returns (bytes32);
    function getHookRootEffectiveTime() external view returns (uint256);
    function getYieldSourcesList() external view returns (address[] memory);
    function isHookAllowed(address hook, bytes32[] calldata proof) external view returns (bool);

    /// @notice Get the current price per share of the SuperVault
    /// @dev If total supply is 0, returns 1 unit in vault decimals as the initial price per share.
    /// Otherwise, calculates the current price based on total assets and total supply.
    /// @return pricePerShare The current price per share in vault decimals (1 share = pricePerShare / 10^decimals
    /// assets)
    function getSuperVaultPPS() external view returns (uint256 pricePerShare);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Propose a new yield source with timelock
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function proposeYieldSource(address source, address oracle) external;

    /// @notice Execute a proposed yield source addition after timelock
    /// @param source Address of the yield source to execute proposal for
    function executeYieldSourceProposal(address source) external;

    /// @notice Update oracle for an existing yield source
    /// @param source Address of the yield source
    /// @param newOracle Address of the new oracle
    function updateYieldSourceOracle(address source, address newOracle) external;

    /// @notice Deactivate a yield source
    /// @param source Address of the yield source to deactivate
    function deactivateYieldSource(address source) external;

    /// @notice Reactivate a previously removed yield source
    /// @param source Address of the yield source to reactivate
    function reactivateYieldSource(address source) external;

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external;

    /// @notice Propose a new hook root
    /// @param newRoot New hook root to propose
    function proposeHookRoot(bytes32 newRoot) external;

    /// @notice Execute hook root update after timelock
    function executeHookRootUpdate() external;

    /// @notice Update fee configuration
    /// @param feeBps New fee in basis points
    /// @param recipient New fee recipient address
    function updateFeeConfig(uint256 feeBps, address recipient) external;

    function cancelDeposit(address controller) external;

    function cancelRedeem(address controller) external;

    /// @notice Match redeem requests with deposit requests directly, without accessing yield sources
    /// @dev Each deposit request must be fully matched with one or more redeem requests. Redeem requests can be
    /// partially fulfilled.
    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external;

    /// @notice Allocate funds between yield sources
    /// @dev Only callable by strategist role. Allows reallocation of funds between yield sources.
    /// @param hooks Array of hooks to use for allocations
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    function allocate(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external;

    /// @notice Pause all vault operations except emergency withdrawals
    function pause() external;

    /// @notice Unpause vault operations
    function unpause() external;

    /// @notice Emergency withdraw free assets from the vault
    /// @dev Only works when paused and only transfers free assets (not those in yield sources)
    /// @param recipient Address to receive the withdrawn assets
    /// @param amount Amount of free assets to withdraw
    function emergencyWithdraw(address recipient, uint256 amount) external;

    /// @notice Set an address for a given role
    /// @dev Only callable by MANAGER role. Cannot set address(0) or remove MANAGER role from themselves
    /// @param role The role identifier
    /// @param account The address to set for the role
    function setAddress(bytes32 role, address account) external;
}
