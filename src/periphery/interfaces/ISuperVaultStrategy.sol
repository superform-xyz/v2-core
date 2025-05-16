// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ISuperHook, Execution } from "../../core/interfaces/ISuperHook.sol";

/// @title ISuperVaultStrategy
/// @author Superform Labs
/// @notice Interface for SuperVault strategy implementation that manages yield sources and executes strategies
interface ISuperVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_LENGTH();
    error INVALID_HOOK();
    error ZERO_ADDRESS();
    error ACCESS_DENIED();
    error INVALID_AMOUNT();
    error INVALID_MANAGER();
    error ALREADY_INITIALIZED();
    error OPERATION_FAILED();
    error INVALID_TIMESTAMP();
    error REQUEST_NOT_FOUND();
    error INVALID_HOOK_ROOT();
    error INVALID_HOOK_TYPE();
    error INSUFFICIENT_FUNDS();
    error INVALID_STRATEGIST();
    error ZERO_OUTPUT_AMOUNT();
    error INSUFFICIENT_SHARES();
    error ZERO_EXPECTED_VALUE();
    error INVALID_ARRAY_LENGTH();
    error ACTION_TYPE_DISALLOWED();
    error YIELD_SOURCE_NOT_FOUND();
    error YIELD_SOURCE_NOT_ACTIVE();
    error INVALID_EMERGENCY_ADMIN();
    error INVALID_PERIPHERY_REGISTRY();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error YIELD_SOURCE_ALREADY_ACTIVE();
    error INVALID_PERFORMANCE_FEE_BPS();
    error INVALID_EMERGENCY_WITHDRAWAL();
    error ASYNC_REQUEST_BLOCKING();
    error MINIMUM_PREVIOUS_HOOK_OUT_AMOUNT_NOT_MET();
    error MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET();
    error INVALID_REDEEM_CLAIM();
    error STRATEGIST_NOT_AUTHORIZED();
    error PPS_UPDATE_RATE_LIMITED();
    error PPS_OUT_OF_BOUNDS();
    error CALCULATION_BLOCK_TOO_OLD();
    error INVALID_PPS();
    error INVALID_REDEEM_FILL();
    error INVALID_VAULT();
    error STAKE_TOO_LOW();
    error OPERATIONS_BLOCKED_BY_VETO();
    error HOOK_VALIDATION_FAILED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed vault, address indexed superGovernor);
    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceDeactivated(address indexed source);
    event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle);
    event YieldSourceReactivated(address indexed source);

    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event EmergencyWithdrawableProposed(bool newWithdrawable, uint256 effectiveTime);
    event EmergencyWithdrawableUpdated(bool withdrawable);
    event EmergencyWithdrawal(address indexed recipient, uint256 assets);
    event VaultFeeConfigUpdated(uint256 performanceFeeBps, address indexed recipient);
    event VaultFeeConfigProposed(uint256 performanceFeeBps, address indexed recipient, uint256 effectiveTime);
    event HooksExecuted(address[] hooks);
    event RedeemRequestPlaced(address indexed controller, address indexed owner, uint256 shares);
    event RedeemRequestFulfilled(address indexed controller, address indexed receiver, uint256 assets, uint256 shares);
    event RedeemRequestCanceled(address indexed controller, uint256 shares);
    event HookExecuted(
        address indexed hook,
        address indexed prevHook,
        address indexed targetedYieldSource,
        bool usePrevHookAmount,
        bytes hookCalldata
    );
    event FulfillHookExecuted(address indexed hook, address indexed targetedYieldSource, bytes hookCalldata);

    event PPSUpdated(uint256 newPPS, uint256 calculationBlock);

    event RedeemRequestsFulfilled(address[] hooks, address[] controllers, uint256 processedShares, uint256 currentPPS);

    event FeePaid(address indexed recipient, uint256 amount, uint256 performanceFeeBps);
    event DepositHandled(address indexed controller, uint256 assets, uint256 shares);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct FeeConfig {
        uint256 performanceFeeBps; // Fee in basis points
        address recipient; // Fee recipient address
    }

    /// @notice Structure for hook execution arguments
    struct ExecuteArgs {
        /// @notice Array of hooks to execute
        address[] hooks;
        /// @notice Calldata for each hook (must match hooks array length)
        bytes[] hookCalldata;
        /// @notice Expected output amounts or output shares
        uint256[] expectedAssetsOrSharesOut;
        /// @notice Global Merkle proofs for hook validation (must match hooks array length)
        bytes32[][] globalProofs;
        /// @notice Strategy-specific Merkle proofs for hook validation (must match hooks array length)
        bytes32[][] strategyProofs;
    }

    struct FulfillArgs {
        address[] controllers;
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
        bytes32[][] globalProofs;
        bytes32[][] strategyProofs;
    }

    struct YieldSource {
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    /// @notice Comprehensive information about a yield source including its address and configuration
    struct YieldSourceInfo {
        address sourceAddress; // Address of the yield source
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    /// @notice State specific to asynchronous redeem requests
    struct SuperVaultState {
        uint256 pendingRedeemRequest; // Shares requested
        uint256 maxWithdraw; // Assets claimable after fulfillment
        // Accumulators needed for fee calculation on redeem
        uint256 accumulatorShares;
        uint256 accumulatorCostBasis;
        uint256 averageWithdrawPrice; // Average price for claimable assets
    }

    struct ExecutionVars {
        bool success;
        address targetedYieldSource;
        uint256 outAmount;
        ISuperHook hookContract;
        Execution[] executions;
    }

    struct OutflowExecutionVars {
        bool success;
        address targetedYieldSource;
        address svAsset;
        uint256 outAmount;
        uint256 superVaultShares;
        uint256 amountOfAssets;
        uint256 amountConvertedToUnderlyingShares;
        uint256 balanceAssetBefore;
        Execution[] executions;
        ISuperHook hookContract;
        ISuperHook.HookType hookType;
    }

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    enum Operation {
        Deposit,
        RedeemRequest,
        CancelRedeem,
        ClaimRedeem,
        Claim,
        UpdateDepositAccumulators
    }

    /*//////////////////////////////////////////////////////////////
                        CORE STRATEGY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the strategy with required parameters
    /// @param vault_ Address of the associated SuperVault
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param feeConfig_ Fee configuration
    function initialize(address vault_, address superGovernor_, FeeConfig memory feeConfig_) external;

    /// @notice Handles asynchronous redeem operations initiated by the Vault.
    /// @param controller Controller address for the redeem operation.
    /// @param assets For Redeem Request: Ignored. For Claim Redeem: assets amount. For Cancel: Ignored.
    /// @param shares For Redeem Request: shares amount. For Claim Redeem: Ignored. For Cancel: Ignored.
    /// @param operation The type of redeem operation (RedeemRequest, CancelRedeem, ClaimRedeem).
    function handleOperation(address controller, uint256 assets, uint256 shares, Operation operation) external;

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute hooks for general strategy management (rebalancing, etc.).
    /// @param args Execution arguments containing hooks, calldata, proofs, expectations.
    function executeHooks(ExecuteArgs calldata args) external;

    /// @notice Fulfills pending redeem requests by executing specific fulfill hooks.
    /// @param args Execution arguments containing fulfill hooks, calldata, and expected outputs (proofs ignored).
    function fulfillRedeemRequests(FulfillArgs calldata args) external;

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Manage a single yield source: add, update oracle, and toggle activation
    /// @param source Address of the yield source
    /// @param oracle Address of the oracle (used for adding/updating)
    /// @param actionType Type of action: 0=Add, 1=UpdateOracle, 2=ToggleActivation
    /// @param activate Boolean flag for activation when actionType is 2
    /// @param isAsync Boolean flag for async yield source
    function manageYieldSource(
        address source,
        address oracle,
        uint8 actionType,
        bool activate,
        bool isAsync
    )
        external;

    /// @notice Batch manage multiple yield sources in a single transaction
    /// @param sources Array of yield source addresses
    /// @param oracles Array of oracle addresses (used for adding/updating)
    /// @param actionTypes Array of action types: 0=Add, 1=UpdateOracle, 2=ToggleActivation
    /// @param activates Array of boolean flags for activation when actionType is 2
    /// @param isAsyncs Array of boolean flags for async yield sources
    function manageYieldSources(
        address[] calldata sources,
        address[] calldata oracles,
        uint8[] calldata actionTypes,
        bool[] calldata activates,
        bool[] calldata isAsyncs
    )
        external;

    /// @notice Propose or execute a hook root update
    /// @notice Propose changes to vault-specific fee configuration
    /// @param performanceFeeBps New performance fee in basis points
    /// @param recipient New fee recipient
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external;

    /// @notice Execute the proposed vault fee configuration update after timelock
    function executeVaultFeeConfigUpdate() external;

    /// @notice Manage emergency withdrawals
    /// @param action Type of action: 1=Propose, 2=ExecuteActivation, 3=Withdraw
    /// @param recipient The recipient of the withdrawn assets (for action 3)
    /// @param amount The amount of assets to withdraw (for action 3)
    function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the strategy is initialized
    function isInitialized() external view returns (bool);

    /// @notice Get the vault info
    function getVaultInfo() external view returns (address vault, address asset, uint8 vaultDecimals);

    /// @notice Get the fee configurations
    function getConfigInfo() external view returns (FeeConfig memory feeConfig);

    /// @notice Returns the currently stored PPS value.
    function getStoredPPS() external view returns (uint256);

    /// @notice Get a yield source's configuration
    function getYieldSource(address source) external view returns (YieldSource memory);

    /// @notice Returns a list of all yield sources with their addresses and configurations
    /// @return A list of YieldSourceInfo structs containing comprehensive information about each yield source
    function getYieldSourcesList() external view returns (YieldSourceInfo[] memory);

    /// @notice Get the average withdraw price for a controller
    /// @param controller The controller address
    /// @return averageWithdrawPrice The average withdraw price
    function getAverageWithdrawPrice(address controller) external view returns (uint256 averageWithdrawPrice);

    /// @notice Previews the fee that would be taken for redeeming a specific amount of shares
    /// @param controller The address of the controller requesting the redemption
    /// @param sharesToRedeem The number of shares to redeem
    /// @return totalFee The estimated fee that would be taken in asset terms
    /// @return superformFee The portion of the fee that would go to Superform treasury
    /// @return recipientFee The portion of the fee that would go to the fee recipient
    function previewPerformanceFee(
        address controller,
        uint256 sharesToRedeem
    )
        external
        view
        returns (uint256 totalFee, uint256 superformFee, uint256 recipientFee);

    /// @notice Get the pending redeem request amount (shares) for a controller
    /// @param controller The controller address
    /// @return pendingShares The amount of shares pending redemption
    function pendingRedeemRequest(address controller) external view returns (uint256 pendingShares);

    /// @notice Get the claimable withdraw amount (assets) for a controller
    /// @param controller The controller address
    /// @return claimableAssets The amount of assets claimable
    function claimableWithdraw(address controller) external view returns (uint256 claimableAssets);
}
