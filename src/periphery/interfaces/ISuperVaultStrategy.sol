// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ISuperHook, Execution } from "../../core/interfaces/ISuperHook.sol";

/// @title ISuperVaultStrategy
/// @author SuperForm Labs
/// @notice Interface for SuperVault strategy implementation that manages yield sources and executes strategies
interface ISuperVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error MISMATCH();
    error ZERO_LENGTH();
    error INVALID_HOOK();
    error ZERO_ADDRESS();
    error INVALID_VAULT();
    error ACCESS_DENIED();
    error INVALID_ORACLE();
    error INVALID_AMOUNT();
    error ALREADY_EXISTS();
    error LIMIT_EXCEEDED();
    error INVALID_MANAGER();
    error NOT_INITIALIZED();
    error OPERATION_FAILED();
    error INVALID_TIMESTAMP();
    error REQUEST_NOT_FOUND();
    error INVALID_HOOK_ROOT();
    error INVALID_VAULT_CAP();
    error INVALID_HOOK_TYPE();
    error INSUFFICIENT_FUNDS();
    error INVALID_STRATEGIST();
    error INVALID_CONTROLLER();
    error INVALID_ASSET_BALANCE();
    error INVALID_BALANCE_CHANGE();
    error INVALID_PERIPHERY_REGISTRY();
    error ACTION_TYPE_DISALLOWED();
    error YIELD_SOURCE_NOT_FOUND();
    error INVALID_VAULT_THRESHOLD();
    error YIELD_SOURCE_NOT_ACTIVE();
    error INVALID_SUPER_VAULT_CAP();
    error INVALID_EMERGENCY_ADMIN();
    error VAULT_THRESHOLD_EXCEEDED();
    error INCOMPLETE_DEPOSIT_MATCH();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error INVALID_MAX_ALLOCATION_RATE();
    error YIELD_SOURCE_ALREADY_ACTIVE();
    error INVALID_PERFORMANCE_FEE_BPS();
    error INVALID_EMERGENCY_WITHDRAWAL();
    error MAX_ALLOCATION_RATE_EXCEEDED();
    error YIELD_SOURCE_ORACLE_NOT_FOUND();
    error INSUFFICIENT_BALANCE_AFTER_TRANSFER();

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
    event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient);
    event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime);
    event RewardsClaimedAndCompounded(uint256 amount);
    event RewardsDistributorSet(address indexed rewardsDistributor);
    event RewardsDistributed(address[] tokens, uint256[] amounts);
    event RewardsClaimed(address[] tokens, uint256[] amounts);

    /*////////////////////////////////`//////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct GlobalConfig {
        uint256 vaultCap; // Maximum assets per individual yield source
        uint256 superVaultCap; // Maximum total assets across all yield sources
        uint256 maxAllocationRate; // Maximum allocation percentage per yield source (in basis points)
        uint256 vaultThreshold; // Minimum TVL of a yield source that can be interacted with
    }

    struct FeeConfig {
        uint256 performanceFeeBps; // Fee in basis points
        address recipient; // Fee recipient address
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
        uint256 totalSupplyAmount; // Base total amount of shares in the vault
        uint256 spentAmount; // Running total of assets/shares spent in hooks
        uint256 pricePerShare; // Current price per share, used for calculations
        uint256 requestedAmount; // Individual user's requested amount
        address prevHook; // Previous hook in sequence for hook chaining
        // Deposit-specific variables
        uint256 availableAmount; // Only used in deposit to check initial balance
        // Variables for share calculations
        uint256 shares; // Used in deposit for minting shares
        uint256 totalAssets; // Total assets across all yield sources
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
        uint256 totalAssets; // Total assets across all yield sources
    }

    struct AllocationVars {
        // Hook execution variables
        address prevHook;
        uint256 amount;
        uint256 balanceAssetBefore;
        uint256 balanceAssetAfter;
        // Current yield source state
        uint256 currentYieldSourceAssets;
        // Hook type and execution
        ISuperHook.HookType hookType;
        Execution[] executions;
    }

    struct YieldSource {
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    struct YieldSourceTVL {
        address source;
        uint256 tvl;
    }

    struct ClaimLocalVars {
        // Initial state tracking
        uint256 initialAssetBalance;
        // Claim phase variables
        uint256[] balanceChanges;
        // Swap phase variables
        uint256 assetGained;
        // Allocation phase variables
        FulfillmentVars fulfillmentVars;
        address[] targetedYieldSources;
    }

    struct ProcessHooksLocalVars {
        // Hook execution variables
        uint256 hooksLength;
        uint256 targetedSourcesCount;
        address target;
        // Hook execution results
        uint256 amount;
        address hookTarget;
        // Arrays for tracking
        address[] targetedYieldSources;
        address[] resizedArray;
    }

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    enum Operation {
        DepositRequest,
        CancelDeposit,
        ClaimDeposit,
        RedeemRequest,
        CancelRedeem,
        ClaimRedeem
    }

    /*//////////////////////////////////////////////////////////////
                        REQUEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Update state for a deposit or a redeem operation
    /// @param controller The controller address
    /// @param assetsOrShares Amount of assets being deposited
    /// @param operation The operation to perform
    /// @return assetsOrSharesOut The amount of assets or shares after the operation
    function handleOperation(
        address controller,
        uint256 assetsOrShares,
        Operation operation
    )
        external
        returns (uint256 assetsOrSharesOut);

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Fulfill deposit requests for multiple users
    /// @param users Array of users with pending deposit requests
    /// @param hooks Array of hooks to use for deposits
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    /// @param isDeposit Whether the requests are deposits or redeems
    function fulfillRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata,
        bool isDeposit
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

    /// @notice Claims rewards from yield sources and stores them for later use
    /// @param hooks Array of hooks to use for claiming rewards
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    /// @param expectedTokensOut Array of tokens expected from hooks
    function claim(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata,
        address[] calldata expectedTokensOut
    )
        external;

    /// @notice Compounds previously claimed tokens by swapping them to the asset and allocating to yield sources
    /// @param hooks Array of arrays of hooks to use for swapping and allocating [swapHooks, allocateHooks]
    /// @param swapHookProofs Array of merkle proofs for swap hooks
    /// @param allocateHookProofs Array of merkle proofs for allocate hooks
    /// @param hookCalldata Array of arrays of calldata for hooks [swapHookCalldata, allocateHookCalldata]
    /// @param claimedTokensToCompound Array of claimed token addresses to compound
    function compoundClaimedTokens(
        address[][] calldata hooks,
        bytes32[][] calldata swapHookProofs,
        bytes32[][] calldata allocateHookProofs,
        bytes[][] calldata hookCalldata,
        address[] calldata claimedTokensToCompound
    )
        external;

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external;

    /// @notice Manage yield sources: add, update oracle, and toggle activation.
    /// @param source Address of the yield source.
    /// @param oracle Address of the oracle (used for adding/updating).
    /// @param actionType Type of action:
    ///        0 - Add new yield source,
    ///        1 - Update oracle,
    ///        2 - Toggle activation (oracle param ignored).
    /// @param activate Boolean flag for activation when actionType is 2.
    function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) external;

    /// @notice Propose or execute a hook root update
    /// @dev if newRoot is 0, executes the proposed hook root update
    /// @param newRoot New hook root to propose or execute
    function proposeOrExecuteHookRoot(bytes32 newRoot) external;

    /// @notice Propose changes to vault-specific fee configuration
    /// @param performanceFeeBps New performance fee in basis points
    /// @param recipient New fee recipient
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external;

    /// @notice Execute the proposed vault fee configuration update after timelock
    function executeVaultFeeConfigUpdate() external;

    /// @notice Set an address for a given role
    /// @dev Only callable by MANAGER role. Cannot set address(0) or remove MANAGER role from themselves
    /// @param role The role identifier
    /// @param account The address to set for the role
    function setAddress(bytes32 role, address account) external;

    /// @notice Manage emergency withdrawals
    /// @param action The action to perform
    ///        0 - Propose new emergency withdrawable state,
    ///        1 - Execute emergency withdrawable update,
    ///        2 - Perform emergency withdrawal
    /// @param recipient The recipient of the withdrawn assets
    /// @param amount The amount of assets to withdraw
    function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the strategy is initialized
    /// @return True if the strategy is initialized, false otherwise
    function isInitialized() external view returns (bool);

    /// @notice Get the vault info
    /// @dev returns vault address, asset address, and vault decimals
    function getVaultInfo() external view returns (address vault, address asset, uint8 vaultDecimals);

    /// @notice Get the hook info
    /// @dev returns hook root, proposed hook root, and hook root effective time
    function getHookInfo()
        external
        view
        returns (bytes32 hookRoot, bytes32 proposedHookRoot, uint256 hookRootEffectiveTime);

    /// @notice Get the global and fee configurations
    function getConfigInfo() external view returns (GlobalConfig memory globalConfig, FeeConfig memory feeConfig);

    /// @notice Get total assets managed by the strategy
    /// @return totalAssets_ Total assets across all yield sources and idle assets
    /// @return sourceTVLs Array of TVL information for each yield source
    function totalAssets() external view returns (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs);

    /// @notice Get a yield source's configuration
    /// @param source Address of the yield source
    function getYieldSource(address source) external view returns (YieldSource memory);

    /// @notice Get the list of all yield sources
    function getYieldSourcesList() external view returns (address[] memory);

    /// @notice Check if a hook is allowed via merkle proof
    /// @param hook Address of the hook to check
    /// @param proof Merkle proof for the hook
    function isHookAllowed(address hook, bytes32[] calldata proof) external view returns (bool);

    /// @notice Get the claimed token amounts in the vault
    /// @param token The token address
    /// @return The amount of tokens claimed
    function claimedTokens(address token) external view returns (uint256);

    /// @notice Get the SuperVault state for a given owner and state type
    /// @param owner The owner address
    /// @param stateType The state type to get
    ///        1 - maxMint,
    ///        2 - maxWithdraw,
    ///        3 - averageDepositPrice,
    ///        4 - averageWithdrawPrice
    /// @return The state value
    function getSuperVaultState(address owner, uint8 stateType) external view returns (uint256);

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
