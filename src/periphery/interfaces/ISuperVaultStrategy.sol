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
    error ZERO_LENGTH();
    error INVALID_HOOK();
    error ZERO_ADDRESS();
    error INVALID_VAULT();
    error ACCESS_DENIED();
    error INVALID_ORACLE();
    error INVALID_AMOUNT();
    error ALREADY_EXISTS();
    error LIMIT_EXCEEDED();
    error LENGTH_MISMATCH();
    error INVALID_MANAGER();
    error ALREADY_INITIALIZED();
    error OPERATION_FAILED();
    error INVALID_TIMESTAMP();
    error REQUEST_NOT_FOUND();
    error INVALID_HOOK_ROOT();
    error INVALID_VAULT_CAP();
    error INVALID_HOOK_TYPE();
    error INSUFFICIENT_FUNDS();
    error INVALID_STRATEGIST();
    error INVALID_CONTROLLER();
    error INVALID_ARRAY_LENGTH();
    error INVALID_ASSET_BALANCE();
    error INVALID_BALANCE_CHANGE();
    error ACTION_TYPE_DISALLOWED();
    error YIELD_SOURCE_NOT_FOUND();
    error INVALID_VAULT_THRESHOLD();
    error YIELD_SOURCE_NOT_ACTIVE();
    error INVALID_SUPER_VAULT_CAP();
    error INVALID_EMERGENCY_ADMIN();
    error VAULT_THRESHOLD_EXCEEDED();
    error INCOMPLETE_DEPOSIT_MATCH();
    error SUPER_VAULT_CAP_EXCEEDED();
    error RESIZED_ARRAY_LENGTH_ERROR();
    error INVALID_PERIPHERY_REGISTRY();
    error CANNOT_CHANGE_TOTAL_ASSETS();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error INVALID_MAX_ALLOCATION_RATE();
    error YIELD_SOURCE_ALREADY_ACTIVE();
    error INVALID_PERFORMANCE_FEE_BPS();
    error INVALID_EMERGENCY_WITHDRAWAL();
    error YIELD_SOURCE_ORACLE_NOT_FOUND();
    error MINIMUM_OUTPUT_AMOUNT_NOT_MET();
    error DEPOSIT_FAILURE_INVALID_TARGET();
    error INVALID_EXPECTED_ASSETS_OR_SHARES_OUT();
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(
        address indexed vault,
        address indexed manager,
        address indexed strategist,
        address emergencyAdmin,
        uint256 superVaultCap
    );
    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceDeactivated(address indexed source);
    event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle);
    event YieldSourceReactivated(address indexed source);
    event SuperVaultCapUpdated(uint256 superVaultCap);
    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime);
    event EmergencyWithdrawableUpdated(bool withdrawable);
    event EmergencyWithdrawal(address indexed recipient, uint256 assets);
    event FeePaid(address indexed recipient, uint256 assets, uint256 bps);
    event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient);
    event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime);
    event HooksExecuted(address[] hooks);
    event ExecutionCompleted(address[] hooks, bool isFulfillment, uint256 usersProcessed, uint256 spentAmount);

    /*////////////////////////////////`//////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
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

    /// @notice Combined execution variables for all hook types
    struct ExecutionVars {
        // Common variables
        uint256 hooksLength;
        address prevHook;
        address targetedYieldSource;
        bool success;
        ISuperHook hookContract;
        ISuperHook.HookType hookType;
        Execution[] executions;
        // Fulfill hooks specific
        bool isFulfillment;
        uint256 totalRequestedAmount;
        uint256 spentAmount;
        uint256 pricePerShare;
        uint256 availableAmount;
        uint256 requestedAmount;
        uint256 shares;
        // Execute hooks specific
        uint256 inflowCount;
        address[] inflowTargets;
        uint256 outAmount;
    }

    /// @notice Local variables struct for executeHooks to avoid stack too deep
    struct ExecuteHooksVars {
        uint256 hooksLength;
        uint256 initialAssetBalance;
        uint256 finalAssetBalance;
        uint256 amount;
        uint256 maxDecrease;
        uint256 inflowCount;
        uint256 actualDecrease;
        address targetedYieldSource;
        address prevHook;
        address[] inflowTargets;
        ISuperHook hookContract;
        ISuperHook.HookType hookType;
        Execution[] executions;
        bool success;
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
    /// @notice Execute hooks with support for fulfilling user requests
    /// @param users Optional array of users for request fulfillment (empty if not fulfilling requests)
    /// @param hooks Array of hooks to execute in sequence
    /// @param hookCalldata Array of calldata for each hook
    /// @param expectedAssetsOrSharesOut Optional array of expected minimum output values (required for fulfillment)
    /// @param isDeposit Whether to process as deposits (true) or withdrawals (false) when fulfilling
    function execute(
        address[] calldata users,
        address[] calldata hooks,
        bytes[] memory hookCalldata,
        uint256[] memory expectedAssetsOrSharesOut,
        bool isDeposit
    )
        external;

    /// @notice Match redeem requests with deposit requests directly
    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external;

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update super vault cap
    /// @param superVaultCap New super vault cap
    function updateSuperVaultCap(uint256 superVaultCap) external;

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

    /// @notice Get the super vault cap and fee configurations
    function getConfigInfo() external view returns (uint256 superVaultCap, FeeConfig memory feeConfig);

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
