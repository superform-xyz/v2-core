// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// External
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Core Interfaces
import {
    ISuperHook,
    ISuperHookResult,
    Execution,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../core/interfaces/accounting/IYieldSourceOracle.sol";

// Periphery Interfaces
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";
import { HookDataDecoder } from "../core/libraries/HookDataDecoder.sol";

/// @title SuperVaultStrategy
/// @author SuperForm Labs
/// @notice Strategy implementation for SuperVault that manages yield sources and executes strategies
contract SuperVaultStrategy is ISuperVaultStrategy {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant PRECISION_DECIMALS = 18;
    uint256 private constant PRECISION = 1e18;

    // Role identifiers
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 private constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 private constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool private _initialized;
    address private _vault;
    IERC20 private _asset;
    uint8 private _vaultDecimals;

    // Role-based access control
    mapping(bytes32 role => address roleAddress) public addresses;

    // Global configuration
    GlobalConfig private globalConfig;

    // Fee configuration
    FeeConfig private feeConfig;
    FeeConfig private proposedFeeConfig;
    uint256 private feeConfigEffectiveTime;

    // Hook root configuration
    bytes32 private hookRoot;
    bytes32 private proposedHookRoot;
    uint256 private hookRootEffectiveTime;

    // Emergency withdrawable configuration
    bool public emergencyWithdrawable;
    bool public proposedEmergencyWithdrawable;
    uint256 public emergencyWithdrawableEffectiveTime;

    // Yield source configuration
    mapping(address source => YieldSource sourceConfig) private yieldSources;
    address[] private yieldSourcesList;

    // Request tracking
    mapping(address controller => SuperVaultState state) private superVaultState;

    // Claimed tokens tracking
    mapping(address token => uint256 amount) public claimedTokens;

    IPeripheryRegistry private peripheryRegistry;

    // Track the last known total assets (free assets available)
    uint256 private assetsInRequest;

    function _requireVault() internal view {
        if (msg.sender != _vault) revert ACCESS_DENIED();
    }

    /// @dev MANAGER_ROLE, STRATEGIST_ROLE, EMERGENCY_ADMIN_ROLE
    function _requireRole(bytes32 role) internal view {
        if (msg.sender != addresses[role]) revert ACCESS_DENIED();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address vault_,
        address manager_,
        address strategist_,
        address emergencyAdmin_,
        address peripheryRegistry_,
        GlobalConfig memory config_,
        address initYieldSource_,
        bytes32 initHooksRoot_,
        address initYieldSourceOracle_
    )
        external
    {
        if (_initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (peripheryRegistry_ == address(0)) revert INVALID_PERIPHERY_REGISTRY();
        if (config_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();

        if (config_.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        _initialized = true;
        _vault = vault_;
        _asset = IERC20(IERC4626(vault_).asset());
        _vaultDecimals = IERC20Metadata(vault_).decimals();

        // Initialize roles
        addresses[MANAGER_ROLE] = manager_;
        addresses[STRATEGIST_ROLE] = strategist_;
        addresses[EMERGENCY_ADMIN_ROLE] = emergencyAdmin_;
        peripheryRegistry = IPeripheryRegistry(peripheryRegistry_);
        globalConfig = config_;

        // Initialize first yield source and hook root to bootstrap the vault
        if (initHooksRoot_ == bytes32(0)) revert INVALID_HOOK_ROOT();
        hookRoot = initHooksRoot_;
        emit HookRootUpdated(initHooksRoot_);

        if (initYieldSourceOracle_ == address(0)) revert ZERO_ADDRESS();
        if (initYieldSource_ == address(0)) revert ZERO_ADDRESS();

        yieldSources[initYieldSource_] = YieldSource({ oracle: initYieldSourceOracle_, isActive: true });
        yieldSourcesList.push(initYieldSource_);
        emit YieldSourceAdded(initYieldSource_, initYieldSourceOracle_);

        // Initialize assetsInRequest to 0
        assetsInRequest = 0;
    }

    /*//////////////////////////////////////////////////////////////
                        REQUEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultStrategy
    function handleOperation(
        address controller,
        uint256 amount,
        Operation operation
    )
        external
        returns (uint256 assetsOrSharesOut)
    {
        if (operation == Operation.DepositRequest) {
            assetsOrSharesOut = _handleRequestDeposit(controller, amount);
        } else if (operation == Operation.CancelDeposit) {
            assetsOrSharesOut = _handleCancelDeposit(controller, amount);
        } else if (operation == Operation.ClaimDeposit) {
            assetsOrSharesOut = _handleClaimDeposit(controller, amount);
        } else if (operation == Operation.RedeemRequest) {
            assetsOrSharesOut = _handleRequestRedeem(controller, amount);
        } else if (operation == Operation.CancelRedeem) {
            assetsOrSharesOut = _handleCancelRedeem(controller);
        } else if (operation == Operation.ClaimRedeem) {
            assetsOrSharesOut = _handleClaimWithdraw(controller, amount);
        } else {
            revert ACCESS_DENIED();
        }
    }

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function fulfillRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes[] memory hookCalldata,
        bool isDeposit
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();
        uint256 hooksLength = hooks.length;

        _validateFulfillHooksArrays(hooksLength, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and determine total amount (assets for deposits, shares for redeem)
        vars.totalRequestedAmount = _validateRequests(usersLength, users, isDeposit);
        // If deposit, check available balance
        if (isDeposit) {
            vars.availableAmount = _getTokenBalance(address(_asset), address(this));
            if (vars.availableAmount < vars.totalRequestedAmount) revert INVALID_AMOUNT();
        }

        /// @dev grab current PPS before processing hooks
        vars.pricePerShare = _getSuperVaultPPS();

        // Process hooks and get targeted yield sources
        address[] memory targetedYieldSources;
        bytes32[][] memory hookProofs = new bytes32[][](hooksLength);
        (vars, targetedYieldSources) = _processHooks(hooks, hookProofs, hookCalldata, vars, isDeposit, true);

        // Check vault caps after hooks processing (only for deposits)
        if (isDeposit) {
            _checkVaultCaps(targetedYieldSources);
        }

        // Process requests
        for (uint256 i; i < usersLength;) {
            address user = users[i];
            SuperVaultState storage state = superVaultState[user];

            if (isDeposit) {
                _processDeposit(user, state, vars);
            } else {
                _processRedeem(user, state, vars);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external {
        _requireRole(STRATEGIST_ROLE);
        uint256 redeemLength = redeemUsers.length;
        uint256 depositLength = depositUsers.length;
        if (redeemLength == 0 || depositLength == 0) revert ZERO_LENGTH();

        MatchVars memory vars;
        vars.currentPricePerShare = _getSuperVaultPPS();

        // Track shares used from each redeemer in memory
        uint256[] memory sharesUsedByRedeemer = new uint256[](redeemLength);
        // Process deposits first, matching with redeem requests
        // Full deposit fulfilment is prioritized vs outflows from the SuperVault (which can be partially matched)
        for (uint256 i; i < depositLength;) {
            address depositor = depositUsers[i];
            SuperVaultState storage depositState = superVaultState[depositor];
            vars.depositAssets = depositState.pendingDepositRequest;
            if (vars.depositAssets == 0) revert REQUEST_NOT_FOUND();

            // Calculate shares needed at current price
            vars.sharesNeeded = vars.depositAssets.mulDiv(PRECISION, vars.currentPricePerShare, Math.Rounding.Floor);
            vars.remainingShares = vars.sharesNeeded;

            // Try to fulfill with redeem requests
            for (uint256 j; j < redeemLength && vars.remainingShares > 0;) {
                address redeemer = redeemUsers[j];
                SuperVaultState storage redeemState = superVaultState[redeemer];
                vars.redeemShares = redeemState.pendingRedeemRequest;
                if (vars.redeemShares == 0) {
                    unchecked {
                        ++j;
                    }
                    continue;
                }

                // Calculate how many shares we can take from this redeemer
                vars.sharesToUse = vars.redeemShares > vars.remainingShares ? vars.remainingShares : vars.redeemShares;

                // Update redeemer's state and accumulate shares used
                redeemState.pendingRedeemRequest -= vars.sharesToUse;
                sharesUsedByRedeemer[j] += vars.sharesToUse;

                vars.remainingShares -= vars.sharesToUse;

                unchecked {
                    ++j;
                }
            }

            // Verify deposit was fully matched
            if (vars.remainingShares > 0) revert INCOMPLETE_DEPOSIT_MATCH();

            // Add share price point for the deposit
            depositState.sharePricePoints.push(
                SharePricePoint({ shares: vars.sharesNeeded, pricePerShare: vars.currentPricePerShare })
            );

            // Clear deposit request and update state
            depositState.pendingDepositRequest = 0;
            depositState.maxMint += vars.sharesNeeded;

            // Call vault callback instead of emitting event directly
            _onDepositClaimable(depositor, vars.depositAssets, vars.sharesNeeded);

            unchecked {
                ++i;
            }
        }

        // Process accumulated shares for redeemers
        for (uint256 i; i < redeemLength;) {
            uint256 sharesUsed = sharesUsedByRedeemer[i];

            if (sharesUsed > 0) {
                address redeemer = redeemUsers[i];
                SuperVaultState storage redeemState = superVaultState[redeemer];

                // Calculate historical assets and process fees once for total shares used
                (vars.finalAssets, vars.lastConsumedIndex) =
                    _calculateHistoricalAssetsAndProcessFees(redeemState, sharesUsed, vars.currentPricePerShare);
                // Update share price point cursor
                if (vars.lastConsumedIndex > redeemState.sharePricePointCursor) {
                    redeemState.sharePricePointCursor = vars.lastConsumedIndex;
                }

                // Update maxWithdraw and emit event once
                redeemState.maxWithdraw += vars.finalAssets;

                // Call vault callback instead of emitting event directly
                _onRedeemClaimable(redeemer, vars.finalAssets, sharesUsed);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Local variables struct for executeHooks to avoid stack too deep
    struct ExecuteHooksVars {
        uint256 hooksLength;
        uint256 initialAssetBalance;
        uint256 finalAssetBalance;
        uint256 inflowCount;
        uint256 amount;
        uint256 maxDecrease;
        uint256 actualDecrease;
        address prevHook;
        address[] inflowTargets;
        ISuperHook hookContract;
        ISuperHook.HookType hookType;
        Execution[] executions;
        bool success;
    }

    /// @inheritdoc ISuperVaultStrategy
    function executeHooks(address[] calldata hooks, bytes[] calldata hookCalldata) external {
        _requireRole(STRATEGIST_ROLE);

        ExecuteHooksVars memory vars;
        vars.hooksLength = hooks.length;
        _validateFulfillHooksArrays(vars.hooksLength, hookCalldata.length);

        // Track initial state
        vars.initialAssetBalance = _getTokenBalance(address(_asset), address(this));
        vars.inflowTargets = new address[](vars.hooksLength);

        (uint256 postExecutionTotalAssets,) = totalAssets();

        // Process each hook in sequence
        for (uint256 i; i < vars.hooksLength;) {
            // Validate hook via periphery registry
            if (!peripheryRegistry.isHookRegistered(hooks[i])) revert INVALID_HOOK();

            // Get hook type
            vars.hookContract = ISuperHook(hooks[i]);
            vars.hookType = ISuperHookResult(hooks[i]).hookType();

            // Call preExecute to initialize outAmount tracking
            vars.hookContract.preExecute(vars.prevHook, address(this), hookCalldata[i]);

            // Build executions for this hook
            vars.executions = vars.hookContract.build(vars.prevHook, address(this), hookCalldata[i]);

            if (vars.executions.length == 1) {
                // For inflow/outflow hooks, validate target is an active yield source
                if (vars.hookType == ISuperHook.HookType.INFLOW || vars.hookType == ISuperHook.HookType.OUTFLOW) {
                    YieldSource storage source = yieldSources[vars.executions[0].target];
                    if (!source.isActive) revert YIELD_SOURCE_NOT_ACTIVE();

                    // For inflows, track targets for cap validation
                    if (vars.hookType == ISuperHook.HookType.INFLOW) {
                        vars.inflowTargets[vars.inflowCount++] = vars.executions[0].target;

                        // Get amount from hook and approve spending
                        vars.amount = _decodeHookAmount(hooks[i], hookCalldata[i]);
                        // TODO: think of a better to do this for outflows , especially when share is externalized
                        _handleTokenApproval(address(_asset), vars.executions[0].target, vars.amount);
                    }
                }

                // Store pre-execution balance for non-accounting hooks
                uint256 preExecutionTotalAssets = postExecutionTotalAssets;

                // Execute the transaction
                (vars.success,) =
                    vars.executions[0].target.call{ value: vars.executions[0].value }(vars.executions[0].callData);
                if (!vars.success) revert OPERATION_FAILED();

                // Call postExecute to update outAmount tracking
                vars.hookContract.postExecute(vars.prevHook, address(this), hookCalldata[i]);

                // For non-accounting hooks, verify asset balance hasn't decreased
                if (vars.hookType == ISuperHook.HookType.NONACCOUNTING) {
                    (postExecutionTotalAssets,) = totalAssets();
                    if (postExecutionTotalAssets < preExecutionTotalAssets) revert CANNOT_CHANGE_TOTAL_ASSETS();
                }

                // Update prevHook for next iteration
                vars.prevHook = hooks[i];
            } else {
                uint256 prevExecutionAmount;
                uint256 preExecutionTotalAssets;
                for (uint256 j; j < vars.executions.length;) {
                    // For inflow/outflow hooks, validate target is an active yield source
                    if (vars.hookType == ISuperHook.HookType.INFLOW || vars.hookType == ISuperHook.HookType.OUTFLOW) {
                        YieldSource storage source = yieldSources[vars.executions[j].target];
                        if (!source.isActive) revert YIELD_SOURCE_NOT_ACTIVE();

                        // For inflows, track targets for cap validation
                        if (vars.hookType == ISuperHook.HookType.INFLOW) {
                            vars.inflowTargets[vars.inflowCount++] = vars.executions[j].target;

                            if (prevExecutionAmount == 0) {
                                // Get amount from hook and approve spending
                                vars.amount = _decodeHookAmount(hooks[i], hookCalldata[i]);

                                // TODO: think of a better to do this for outflows , especially when share is
                                // externalized
                                _handleTokenApproval(address(_asset), vars.executions[j].target, vars.amount);
                            }
                            prevExecutionAmount = vars.amount;
                        }
                    }

                    // Store pre-execution balance for non-accounting hooks
                    preExecutionTotalAssets = postExecutionTotalAssets;

                    // Execute the transaction
                    (vars.success,) =
                        vars.executions[j].target.call{ value: vars.executions[j].value }(vars.executions[j].callData);
                    if (!vars.success) revert OPERATION_FAILED();

                    unchecked {
                        ++j;
                    }
                }

                // Call postExecute to update outAmount tracking
                vars.hookContract.postExecute(vars.prevHook, address(this), hookCalldata[i]);

                // For non-accounting hooks, verify asset balance hasn't decreased
                if (vars.hookType == ISuperHook.HookType.NONACCOUNTING) {
                    (postExecutionTotalAssets,) = totalAssets();
                    if (postExecutionTotalAssets < preExecutionTotalAssets) revert CANNOT_CHANGE_TOTAL_ASSETS();
                }
                // Update prevHook for next iteration
                vars.prevHook = hooks[i];
            }

            unchecked {
                ++i;
            }
        }

        // Reset approval if it was an inflow
        if (vars.hookType == ISuperHook.HookType.INFLOW) {
            _resetTokenApproval(address(_asset), vars.executions[0].target);
        }

        // Resize array if needed
        if (vars.inflowCount < vars.hooksLength && vars.inflowCount > 0) {
            vars.inflowTargets = _resizeAddressArray(vars.inflowTargets, vars.inflowCount);
        }

        // Check vault caps for all inflow targets
        if (vars.inflowCount > 0) {
            _checkVaultCaps(vars.inflowTargets);
        }

        // Validate final state based on hook types
        vars.finalAssetBalance = _getTokenBalance(address(_asset), address(this));

        // Always ensure we have enough to cover assetsInRequest
        if (vars.finalAssetBalance < assetsInRequest) revert INVALID_AMOUNT();

        emit HooksExecuted(hooks, vars.initialAssetBalance, vars.finalAssetBalance);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC7540 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultStrategy
    function pendingDepositRequest(address controller) external view returns (uint256 pendingAssets) {
        pendingAssets = superVaultState[controller].pendingDepositRequest;
    }

    /// @inheritdoc ISuperVaultStrategy
    function pendingRedeemRequest(address controller) external view returns (uint256 pendingShares) {
        pendingShares = superVaultState[controller].pendingRedeemRequest;
    }

    /// @inheritdoc ISuperVaultStrategy
    function totalAssets() public view returns (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs) {
        uint256 length = yieldSourcesList.length;
        sourceTVLs = new YieldSourceTVL[](length);
        uint256 activeSourceCount;

        for (uint256 i; i < length;) {
            address source = yieldSourcesList[i];
            if (yieldSources[source].isActive) {
                uint256 tvl = _getTvlByOwnerOfShares(source);
                totalAssets_ += tvl;
                sourceTVLs[activeSourceCount++] = YieldSourceTVL({ source: source, tvl: tvl });
            }
            unchecked {
                ++i;
            }
        }

        if (activeSourceCount < length) {
            assembly {
                mstore(sourceTVLs, activeSourceCount)
            }
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function getSuperVaultState(address owner, uint8 stateType) external view returns (uint256) {
        SuperVaultState storage state = superVaultState[owner];

        if (stateType == 1) return state.maxMint;
        if (stateType == 2) return state.maxWithdraw;
        if (stateType == 3) return state.averageDepositPrice;
        if (stateType == 4) return state.averageWithdrawPrice;

        revert ACTION_TYPE_DISALLOWED();
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Manage yield sources: add, update oracle, and toggle activation.
    /// @param source Address of the yield source.
    /// @param oracle Address of the oracle (used for adding/updating).
    /// @param actionType Type of action:
    ///        0 - Add new yield source,
    ///        1 - Update oracle,
    ///        2 - Toggle activation (oracle param ignored).
    /// @param activate Boolean flag for activation when actionType is 2.
    function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) external {
        _requireRole(MANAGER_ROLE);
        YieldSource storage yieldSource = yieldSources[source];

        if (actionType == 0) {
            if (source == address(0)) revert ZERO_ADDRESS();
            if (oracle == address(0)) revert ZERO_ADDRESS();
            if (yieldSource.oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

            if (IYieldSourceOracle(oracle).getTVL(source) < globalConfig.vaultThreshold) {
                revert VAULT_THRESHOLD_EXCEEDED();
            }

            yieldSources[source] = YieldSource({ oracle: oracle, isActive: true });
            yieldSourcesList.push(source);
            emit YieldSourceAdded(source, oracle);
        } else if (actionType == 1) {
            if (oracle == address(0)) revert ZERO_ADDRESS();
            if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_ORACLE_NOT_FOUND();

            address oldOracle = yieldSource.oracle;
            yieldSource.oracle = oracle;
            emit YieldSourceOracleUpdated(source, oldOracle, oracle);
        } else if (actionType == 2) {
            if (activate) {
                if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_ORACLE_NOT_FOUND();
                if (yieldSource.isActive) revert YIELD_SOURCE_ALREADY_ACTIVE();

                if (IYieldSourceOracle(oracle).getTVL(source) < globalConfig.vaultThreshold) {
                    revert VAULT_THRESHOLD_EXCEEDED();
                }

                yieldSource.isActive = true;
                emit YieldSourceReactivated(source);
            } else {
                if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
                if (IYieldSourceOracle(oracle).getTVLByOwnerOfShares(source, address(this)) > 0) {
                    revert INVALID_AMOUNT();
                }

                yieldSource.isActive = false;
                emit YieldSourceDeactivated(source);
            }
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function updateGlobalConfig(GlobalConfig calldata config) external {
        _requireRole(MANAGER_ROLE);
        if (config.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        globalConfig = config;
        emit GlobalConfigUpdated(config.vaultCap, config.superVaultCap, config.vaultThreshold);
    }

    /// @inheritdoc ISuperVaultStrategy
    function proposeOrExecuteHookRoot(bytes32 newRoot) external {
        if (newRoot == bytes32(0)) {
            if (block.timestamp < hookRootEffectiveTime) revert INVALID_TIMESTAMP();
            if (proposedHookRoot == bytes32(0)) revert INVALID_HOOK_ROOT();
            hookRoot = proposedHookRoot;
            proposedHookRoot = bytes32(0);
            hookRootEffectiveTime = 0;
            emit HookRootUpdated(hookRoot);
        } else {
            _requireRole(MANAGER_ROLE);
            proposedHookRoot = newRoot;
            hookRootEffectiveTime = block.timestamp + ONE_WEEK;
            emit HookRootProposed(newRoot, hookRootEffectiveTime);
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external {
        _requireRole(MANAGER_ROLE);

        if (performanceFeeBps > ONE_HUNDRED_PERCENT) revert INVALID_AMOUNT();
        if (recipient == address(0)) revert ZERO_ADDRESS();

        proposedFeeConfig = FeeConfig({ performanceFeeBps: performanceFeeBps, recipient: recipient });
        feeConfigEffectiveTime = block.timestamp + ONE_WEEK;

        emit VaultFeeConfigProposed(performanceFeeBps, recipient, feeConfigEffectiveTime);
    }

    /// @inheritdoc ISuperVaultStrategy
    function executeVaultFeeConfigUpdate() external {
        if (block.timestamp < feeConfigEffectiveTime) revert INVALID_TIMESTAMP();
        if (proposedFeeConfig.recipient == address(0)) revert ZERO_ADDRESS();

        feeConfig = proposedFeeConfig;
        delete proposedFeeConfig;
        feeConfigEffectiveTime = 0;

        emit VaultFeeConfigUpdated(feeConfig.performanceFeeBps, feeConfig.recipient);
    }

    /// @notice Set an address for a given role
    /// @dev Only callable by MANAGER role
    /// @param role The role identifier
    /// @param account The address to set for the role
    function setAddress(bytes32 role, address account) external {
        _requireRole(MANAGER_ROLE);
        if (account == address(0)) revert ZERO_ADDRESS();

        addresses[role] = account;
    }

    /// @inheritdoc ISuperVaultStrategy
    function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) external {
        if (action == 1 || action == 3) {
            _requireRole(EMERGENCY_ADMIN_ROLE);
        }

        if (action == 1) {
            // Propose new emergency withdrawable state
            proposedEmergencyWithdrawable = true;
            emergencyWithdrawableEffectiveTime = block.timestamp + ONE_WEEK;
            emit EmergencyWithdrawableProposed(true, emergencyWithdrawableEffectiveTime);
        } else if (action == 2) {
            // Execute emergency withdrawable update (no role required)
            if (block.timestamp < emergencyWithdrawableEffectiveTime) revert INVALID_TIMESTAMP();
            emergencyWithdrawable = proposedEmergencyWithdrawable;
            proposedEmergencyWithdrawable = false;
            emergencyWithdrawableEffectiveTime = 0;
            emit EmergencyWithdrawableUpdated(emergencyWithdrawable);
        } else if (action == 3) {
            // Perform emergency withdrawal
            if (!emergencyWithdrawable) revert INVALID_EMERGENCY_WITHDRAWAL();
            if (recipient == address(0)) revert ZERO_ADDRESS();

            uint256 freeAssets = _getTokenBalance(address(_asset), address(this));
            if (amount > freeAssets) revert INSUFFICIENT_FUNDS();

            _safeTokenTransfer(address(_asset), recipient, amount);
            emit EmergencyWithdrawal(recipient, amount);
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if the vault is initialized
    /// @return True if the vault is initialized, false otherwise
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    /// @inheritdoc ISuperVaultStrategy
    function getVaultInfo() external view returns (address vault_, address asset_, uint8 vaultDecimals_) {
        vault_ = _vault;
        asset_ = address(_asset);
        vaultDecimals_ = _vaultDecimals;
    }

    /// @inheritdoc ISuperVaultStrategy
    function getHookInfo()
        external
        view
        returns (bytes32 hookRoot_, bytes32 proposedHookRoot_, uint256 hookRootEffectiveTime_)
    {
        hookRoot_ = hookRoot;
        proposedHookRoot_ = proposedHookRoot;
        hookRootEffectiveTime_ = hookRootEffectiveTime;
    }

    /// @inheritdoc ISuperVaultStrategy
    function getConfigInfo() external view returns (GlobalConfig memory globalConfig_, FeeConfig memory feeConfig_) {
        globalConfig_ = globalConfig;
        feeConfig_ = feeConfig;
    }

    /// @notice Get a yield source's configuration
    /// @param source Address of the yield source
    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }

    /// @notice Get the list of all yield sources
    function getYieldSourcesList() external view returns (address[] memory) {
        return yieldSourcesList;
    }

    /// @notice Check if a hook is allowed via merkle proof
    /// @param hook Address of the hook to check
    /// @param proof Merkle proof for the hook
    function isHookAllowed(address hook, bytes32[] memory proof) public view returns (bool) {
        if (hookRoot == bytes32(0)) return false;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hook))));
        return MerkleProof.verify(proof, hookRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isFulfillRequestsHook(address hook) private view returns (bool) {
        return peripheryRegistry.isFulfillRequestsHookRegistered(hook);
    }

    function _decodeHookAmount(address hook, bytes memory hookCalldata) private pure returns (uint256 amount) {
        return ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);
    }

    function _total4626Assets(address source) private view returns (uint256) {
        return IERC4626(source).totalAssets();
    }

    function _onRedeemClaimable(address redeemer, uint256 assets, uint256 shares) private {
        ISuperVault(_vault).onRedeemClaimable(redeemer, assets, shares);
    }

    function _onDepositClaimable(address depositor, uint256 assets, uint256 shares) private {
        ISuperVault(_vault).onDepositClaimable(depositor, assets, shares);
    }

    function _getTvlByOwnerOfShares(address source) private view returns (uint256) {
        return IYieldSourceOracle(yieldSources[source].oracle).getTVLByOwnerOfShares(source, address(this));
    }

    function _getSuperVaultPPS() private view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = IERC4626(_vault).totalSupply();
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = PRECISION;
        } else {
            // Calculate current PPS in price decimals
            (uint256 totalAssetsValue,) = totalAssets();
            pricePerShare = totalAssetsValue.mulDiv(PRECISION, totalSupplyAmount, Math.Rounding.Floor);
        }
    }

    function _processDeposit(address user, SuperVaultState storage state, FulfillmentVars memory vars) private {
        vars.requestedAmount = state.pendingDepositRequest;
        vars.shares = vars.requestedAmount.mulDiv(PRECISION, vars.pricePerShare, Math.Rounding.Floor);

        uint256 newTotalUserShares = state.maxMint + vars.shares;

        if (newTotalUserShares > 0) {
            uint256 existingUserAssets = 0;
            if (state.maxMint > 0 && state.averageDepositPrice > 0) {
                existingUserAssets = state.maxMint.mulDiv(state.averageDepositPrice, PRECISION, Math.Rounding.Floor);
            }

            uint256 newTotalUserAssets = existingUserAssets + vars.requestedAmount;
            state.averageDepositPrice = newTotalUserAssets.mulDiv(PRECISION, newTotalUserShares, Math.Rounding.Floor);
        }

        state.sharePricePoints.push(SharePricePoint({ shares: vars.shares, pricePerShare: vars.pricePerShare }));
        state.pendingDepositRequest = 0;
        state.maxMint += vars.shares;

        ISuperVault(_vault).mintShares(vars.shares);

        _onDepositClaimable(user, vars.requestedAmount, vars.shares);
    }

    function _processRedeem(address user, SuperVaultState storage state, FulfillmentVars memory vars) private {
        vars.requestedAmount = state.pendingRedeemRequest;

        uint256 lastConsumedIndex;
        uint256 finalAssets;
        (finalAssets, lastConsumedIndex) =
            _calculateHistoricalAssetsAndProcessFees(state, vars.requestedAmount, vars.pricePerShare);

        state.sharePricePointCursor = lastConsumedIndex;
        state.pendingRedeemRequest = 0;

        state.maxWithdraw += finalAssets;

        ISuperVault(_vault).burnShares(vars.requestedAmount);

        _onRedeemClaimable(user, finalAssets, vars.requestedAmount);
    }

    function _handleRequestDeposit(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        _safeTokenTransferFrom(address(_asset), msg.sender, address(this), assets);

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + assets;

        // Update assetsInRequest
        _updateAssetsInRequest(assetsInRequest + assets);

        return assets;
    }

    function _handleCancelDeposit(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = 0;

        // Update assetsInRequest
        _updateAssetsInRequest(assetsInRequest - assets);

        _safeTokenTransfer(address(_asset), _vault, assets);
        return assets;
    }

    function _handleClaimDeposit(address controller, uint256 shares) private returns (uint256) {
        _requireVault();
        if (shares == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        if (state.maxMint < shares) revert INVALID_AMOUNT();
        // Update state
        state.maxMint -= shares;
        return shares;
    }

    function _handleRequestRedeem(address controller, uint256 shares) private returns (uint256) {
        _requireVault();
        if (shares == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];

        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;
        return shares;
    }

    function _handleCancelRedeem(address controller) internal returns (uint256) {
        _requireVault();
        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = 0;
        return 0;
    }

    function _handleClaimWithdraw(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];

        if (state.maxWithdraw < assets) revert INVALID_AMOUNT();

        // Update state
        state.maxWithdraw -= assets;

        // Get actual balance and ensure we don't underflow assetsInRequest
        uint256 currentBalance = _getTokenBalance(address(_asset), address(this));
        uint256 assetsToWithdraw = assets > currentBalance ? currentBalance : assets;

        // Update assetsInRequest based on actual withdrawal amount
        _updateAssetsInRequest(currentBalance - assetsToWithdraw);

        // Transfer assets to vault
        _safeTokenTransfer(address(_asset), _vault, assetsToWithdraw);
        return assetsToWithdraw;
    }

    /// @notice Update the total amount of assets in request
    /// @param assetsInRequest_ The new total assets in request
    function _updateAssetsInRequest(uint256 assetsInRequest_) internal {
        assetsInRequest = assetsInRequest_;
    }

    //--Fulfilment and allocation helpers--

    /// @notice Validate array lengths for fulfill functions
    /// @param hooksLength Length of hooks array
    /// @param hookProofsLength Length of hook proofs array
    /// @param hookCalldataLength Length of hook calldata array
    function _validateHooksArrays(
        uint256 hooksLength,
        uint256 hookProofsLength,
        uint256 hookCalldataLength
    )
        private
        pure
    {
        if (hooksLength == 0) revert ZERO_LENGTH();

        // Validate array lengths match
        if (hooksLength != hookProofsLength || hooksLength != hookCalldataLength) {
            revert LENGTH_MISMATCH();
        }
    }

    /// @notice Validate array lengths for fulfill functions
    /// @param hooksLength Length of hooks array
    /// @param hookCalldataLength Length of hook calldata array
    function _validateFulfillHooksArrays(uint256 hooksLength, uint256 hookCalldataLength) private pure {
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (hooksLength != hookCalldataLength) {
            revert LENGTH_MISMATCH();
        }
    }

    /// @notice Validate requests and get total amount
    /// @param usersLength Length of users array
    /// @param users Array of user addresses
    /// @param isDeposit Whether this is a deposit request validation
    /// @return totalRequested Total amount requested (assets for deposits, shares for redeems)
    function _validateRequests(
        uint256 usersLength,
        address[] calldata users,
        bool isDeposit
    )
        private
        view
        returns (uint256 totalRequested)
    {
        for (uint256 i; i < usersLength;) {
            uint256 pendingRequest = isDeposit
                ? superVaultState[users[i]].pendingDepositRequest
                : superVaultState[users[i]].pendingRedeemRequest;

            if (pendingRequest == 0) revert REQUEST_NOT_FOUND();
            totalRequested += pendingRequest;
            unchecked {
                i++;
            }
        }
    }

    /// @notice Common hook execution logic
    /// @param hook The hook to execute
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param hookProof The merkle proof for the hook
    /// @param expectedHookType The expected type of hook
    /// @param validateYieldSource Whether to validate the yield source
    /// @param approvalToken Token to approve (address(0) if no approval needed)
    /// @param approvalAmount Amount to approve
    /// @return target The target address from the execution
    function _executeHook(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        bytes32[] memory hookProof,
        ISuperHook.HookType expectedHookType,
        bool validateYieldSource,
        address approvalToken,
        uint256 approvalAmount,
        bool isFulfillRequestsHook
    )
        private
        returns (address target)
    {
        // Validate hook via merkle proof
        if (isFulfillRequestsHook) {
            if (!_isFulfillRequestsHook(hook)) revert INVALID_HOOK();
        } else {
            if (!isHookAllowed(hook, hookProof)) revert INVALID_HOOK();
        }

        // Build executions for this hook
        ISuperHook hookContract = ISuperHook(hook);
        Execution[] memory executions = hookContract.build(prevHook, address(this), hookCalldata);
        // prevent any hooks with more than one execution
        if (executions.length > 1) revert INVALID_HOOK();

        // Validate hook type
        ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();
        if (hookType != expectedHookType) revert INVALID_HOOK_TYPE();

        target = executions[0].target;

        // Validate target is an active yield source if needed
        if (validateYieldSource) {
            YieldSource storage source = yieldSources[target];
            if (!source.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
        }
        approvalToken = hookType == ISuperHook.HookType.OUTFLOW ? target : approvalToken;
        // Handle token approvals if needed
        if (approvalToken != address(0)) {
            _handleTokenApproval(approvalToken, target, approvalAmount);
        }

        // Execute the transaction
        (bool success,) = target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert OPERATION_FAILED();

        // Reset approval if needed
        if (approvalToken != address(0)) {
            _resetTokenApproval(approvalToken, target);
        }
    }

    /// @notice Common balance tracking logic
    /// @param tokens Array of tokens to track
    /// @param initialBalances Initial balances of tokens
    /// @param requireZeroBalance Whether to require zero final balance
    /// @return changes Array of balance changes
    function _trackBalanceChanges(
        address[] calldata tokens,
        uint256[] memory initialBalances,
        bool requireZeroBalance
    )
        private
        view
        returns (uint256[] memory changes)
    {
        uint256 length = tokens.length;
        changes = new uint256[](length);

        for (uint256 i; i < length;) {
            uint256 finalBalance = _getTokenBalance(tokens[i], address(this));

            if (requireZeroBalance) {
                if (finalBalance != 0) revert INVALID_AMOUNT();
            } else {
                if (finalBalance < initialBalances[i]) revert INVALID_AMOUNT();
                changes[i] = finalBalance - initialBalances[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Process hooks for both deposit and redeem fulfillment
    /// @param hooks Array of hook addresses
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    /// @param vars Fulfillment variables
    /// @param isDeposit Whether this is a deposit fulfillment
    /// @return vars Updated fulfillment variables
    /// @return targetedYieldSources Array of yield sources targeted by inflow hooks
    function _processHooks(
        address[] calldata hooks,
        bytes32[][] memory hookProofs,
        bytes[] memory hookCalldata,
        FulfillmentVars memory vars,
        bool isDeposit,
        bool isFulfillRequestsHookCheck
    )
        private
        returns (FulfillmentVars memory, address[] memory)
    {
        ProcessHooksLocalVars memory locals;
        locals.hooksLength = hooks.length;
        // Track targeted yield sources for inflow operations
        locals.targetedYieldSources = new address[](locals.hooksLength);

        // Process each hook in sequence
        for (uint256 i; i < locals.hooksLength;) {
            // Process hook executions
            if (isDeposit) {
                (locals.amount, locals.hookTarget) = _processInflowHookExecution(
                    hooks[i], vars.prevHook, hookCalldata[i], hookProofs[i], isFulfillRequestsHookCheck
                );
                vars.prevHook = hooks[i];
                vars.spentAmount += locals.amount;
                locals.target = locals.hookTarget;
            } else {
                (locals.amount, locals.hookTarget) = _processOutflowHookExecution(
                    hooks[i],
                    vars.prevHook,
                    hookCalldata[i],
                    hookProofs[i],
                    isFulfillRequestsHookCheck,
                    vars.pricePerShare
                );
                vars.prevHook = hooks[i];
                vars.spentAmount += locals.amount;
            }

            // Track targeted yield source for inflow operations
            if (isDeposit) {
                locals.targetedYieldSources[locals.targetedSourcesCount++] = locals.target;
            }

            unchecked {
                ++i;
            }
        }

        // Verify hook spent assets or SuperVault shares in full
        if (vars.spentAmount != vars.totalRequestedAmount) revert INVALID_AMOUNT();

        // Resize array to actual count if needed
        if (locals.targetedSourcesCount < locals.hooksLength) {
            // Create new array with actual count and copy elements
            locals.resizedArray = new address[](locals.targetedSourcesCount);
            for (uint256 i = 0; i < locals.targetedSourcesCount; i++) {
                locals.resizedArray[i] = locals.targetedYieldSources[i];
            }
            locals.targetedYieldSources = locals.resizedArray;
        }

        return (vars, locals.targetedYieldSources);
    }

    /// @notice Process inflow hook execution
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param hookProof The merkle proof for the hook
    /// @return amount The amount from the hook
    /// @return target The target address from the execution
    function _processInflowHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        bytes32[] memory hookProof,
        bool isFulfillRequestsHookCheck
    )
        private
        returns (uint256 amount, address target)
    {
        // Get amount before execution
        amount = _decodeHookAmount(hook, hookCalldata);
        uint256 balanceAssetBefore = _getTokenBalance(address(_asset), address(this));

        // Execute hook with asset approval
        target = _executeHook(
            hook,
            prevHook,
            hookCalldata,
            hookProof,
            ISuperHook.HookType.INFLOW,
            true,
            address(_asset),
            amount,
            isFulfillRequestsHookCheck
        );

        uint256 balanceAssetAfter = _getTokenBalance(address(_asset), address(this));

        // Update assetsInRequest to account for assets being moved in
        _updateAssetsInRequest(assetsInRequest - (balanceAssetBefore - balanceAssetAfter));
    }

    /// @notice Struct for outflow execution variables
    struct OutflowExecutionVars {
        uint256 amount;
        uint256 amountOfAssets;
        uint256 amountConvertedToUnderlyingShares;
        uint256 balanceAssetBefore;
        uint256 balanceAssetAfter;
        address target;
        address yieldSource;
    }

    /// @notice Process outflow hook execution
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param hookProof The merkle proof for the hook
    /// @return amount The amount from the hook
    /// @return target The target address from the execution
    function _processOutflowHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        bytes32[] memory hookProof,
        bool isFulfillRequestsHookCheck,
        uint256 pricePerShare
    )
        private
        returns (uint256 amount, address target)
    {
        OutflowExecutionVars memory execVars;

        // Get amount and convert to underlying shares
        (execVars.amount, execVars.yieldSource) = _prepareOutflowExecution(hook, hookCalldata);

        // Calculate underlying shares and update hook calldata
        execVars.amountOfAssets = execVars.amount.mulDiv(pricePerShare, PRECISION, Math.Rounding.Floor);
        execVars.amountConvertedToUnderlyingShares = IYieldSourceOracle(yieldSources[execVars.yieldSource].oracle)
            .getShareOutput(execVars.yieldSource, address(_asset), execVars.amountOfAssets);

        hookCalldata =
            ISuperHookOutflow(hook).replaceCalldataAmount(hookCalldata, execVars.amountConvertedToUnderlyingShares);

        // Execute hook and track balances
        (execVars.target, execVars.balanceAssetBefore, execVars.balanceAssetAfter) =
            _executeOutflowHook(hook, prevHook, hookCalldata, hookProof, execVars.amount, isFulfillRequestsHookCheck);

        // Update total assets and return values
        _updateAssetsInRequest(assetsInRequest + (execVars.balanceAssetAfter - execVars.balanceAssetBefore));

        return (execVars.amount, execVars.target);
    }

    /// @notice Prepare variables for outflow execution
    function _prepareOutflowExecution(
        address hook,
        bytes memory hookCalldata
    )
        private
        pure
        returns (uint256 amount, address yieldSource)
    {
        amount = _decodeHookAmount(hook, hookCalldata);
        yieldSource = HookDataDecoder.extractYieldSource(hookCalldata);
    }

    /// @notice Execute outflow hook and track balances
    function _executeOutflowHook(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        bytes32[] memory hookProof,
        uint256 amount,
        bool isFulfillRequestsHookCheck
    )
        private
        returns (address target, uint256 balanceAssetBefore, uint256 balanceAssetAfter)
    {
        balanceAssetBefore = _getTokenBalance(address(_asset), address(this));

        target = _executeHook(
            hook,
            prevHook,
            hookCalldata,
            hookProof,
            ISuperHook.HookType.OUTFLOW,
            true,
            address(0),
            amount,
            isFulfillRequestsHookCheck
        );

        balanceAssetAfter = _getTokenBalance(address(_asset), address(this));
    }

    /// @notice Check vault caps for targeted yield sources
    /// @param targetedYieldSources Array of yield sources to check
    function _checkVaultCaps(address[] memory targetedYieldSources) private view {
        // Note: This check is gas expensive due to getTVLByOwnerOfShares calls
        for (uint256 i; i < targetedYieldSources.length;) {
            address source = targetedYieldSources[i];
            uint256 yieldSourceTVL = _getTvlByOwnerOfShares(source);
            if (yieldSourceTVL > globalConfig.vaultCap) revert LIMIT_EXCEEDED();
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Calculate fee on profit and transfer to recipient
    /// @param currentAssets Current value of shares in assets
    /// @param historicalAssets Historical value of shares in assets
    /// @return uint256 Assets after fee deduction
    function _calculateAndTransferFee(uint256 currentAssets, uint256 historicalAssets) private returns (uint256) {
        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, ONE_HUNDRED_PERCENT, Math.Rounding.Floor);
            if (totalFee > 0) {
                // Calculate Superform's portion of the fee
                uint256 superformFee =
                    totalFee.mulDiv(peripheryRegistry.getSuperformFeeSplit(), ONE_HUNDRED_PERCENT, Math.Rounding.Floor);
                uint256 recipientFee = totalFee - superformFee;

                // Transfer fees
                if (superformFee > 0) {
                    address treasury = peripheryRegistry.getTreasury();
                    _safeTokenTransfer(address(_asset), treasury, superformFee);
                    emit FeePaid(treasury, superformFee, performanceFeeBps);
                }

                if (recipientFee > 0) {
                    _safeTokenTransfer(address(_asset), feeConfig.recipient, recipientFee);
                    emit FeePaid(feeConfig.recipient, recipientFee, performanceFeeBps);
                }

                currentAssets -= totalFee;
            }
        }
        return currentAssets;
    }

    /// @notice Calculate historical assets and process fees
    /// @param state User's vault state
    /// @param requestedShares Shares being redeemed
    /// @param currentPricePerShare Current price per share
    function _calculateHistoricalAssetsAndProcessFees(
        SuperVaultState storage state,
        uint256 requestedShares,
        uint256 currentPricePerShare
    )
        private
        returns (uint256 finalAssets, uint256 lastConsumedIndex)
    {
        // Calculate historical assets and update share price points
        (finalAssets, lastConsumedIndex) =
            _calculateHistoricalAssetsAndUpdatePoints(state, requestedShares, state.sharePricePointCursor);

        // Process fees and get final assets
        finalAssets = _processFees(requestedShares, currentPricePerShare, finalAssets);

        // Update average withdraw price if needed
        if (requestedShares > 0) {
            _updateAverageWithdrawPrice(state, requestedShares, finalAssets);
        }
    }

    function _calculateHistoricalAssetsAndUpdatePoints(
        SuperVaultState storage state,
        uint256 requestedShares,
        uint256 currentIndex
    )
        private
        returns (uint256 historicalAssets, uint256 lastConsumedIndex)
    {
        uint256 remainingShares = requestedShares;
        lastConsumedIndex = currentIndex;
        uint256 sharePricePointsLength = state.sharePricePoints.length;

        for (uint256 j = currentIndex; j < sharePricePointsLength && remainingShares > 0;) {
            SharePricePoint memory point = state.sharePricePoints[j];
            uint256 sharesFromPoint = point.shares > remainingShares ? remainingShares : point.shares;
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, PRECISION, Math.Rounding.Floor);

            if (sharesFromPoint == point.shares) {
                lastConsumedIndex = j + 1;
            } else if (sharesFromPoint < point.shares) {
                state.sharePricePoints[j].shares -= sharesFromPoint;
            }

            remainingShares -= sharesFromPoint;
            unchecked {
                ++j;
            }
        }
    }

    function _processFees(
        uint256 requestedShares,
        uint256 currentPricePerShare,
        uint256 historicalAssets
    )
        private
        returns (uint256 finalAssets)
    {
        uint256 currentValue = requestedShares.mulDiv(currentPricePerShare, PRECISION, Math.Rounding.Floor);

        finalAssets = _calculateAndTransferFee(currentValue, historicalAssets);

        uint256 balanceOfStrategy = _getTokenBalance(address(_asset), address(this));

        finalAssets = finalAssets > balanceOfStrategy ? balanceOfStrategy : finalAssets;
    }

    function _updateAverageWithdrawPrice(
        SuperVaultState storage state,
        uint256 requestedShares,
        uint256 finalAssets
    )
        private
    {
        uint256 existingShares;
        uint256 existingAssets;

        if (state.maxWithdraw > 0 && state.averageWithdrawPrice > 0) {
            existingShares = state.maxWithdraw.mulDiv(PRECISION, state.averageWithdrawPrice, Math.Rounding.Floor);
            existingAssets = state.maxWithdraw;
        }

        uint256 newTotalShares = existingShares + requestedShares;
        uint256 newTotalAssets = existingAssets + finalAssets;

        if (newTotalShares > 0) {
            state.averageWithdrawPrice = newTotalAssets.mulDiv(PRECISION, newTotalShares, Math.Rounding.Floor);
        }
    }

    function _handleTokenApproval(address token, address spender, uint256 amount) private {
        if (amount > 0) {
            IERC20(token).safeIncreaseAllowance(spender, amount);
        }
    }

    function _resetTokenApproval(address token, address spender) private {
        IERC20(token).forceApprove(spender, 0);
    }

    function _safeTokenTransfer(address token, address recipient, uint256 amount) private {
        if (amount > 0) {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    function _safeTokenTransferFrom(address token, address sender, address recipient, uint256 amount) private {
        if (amount > 0) {
            IERC20(token).safeTransferFrom(sender, recipient, amount);
        }
    }

    function _getTokenBalance(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    /// @notice Resize an address array to a smaller size
    /// @param array The original array
    /// @param newSize The new size (must be smaller than the original array)
    /// @return A new array with the specified size containing the first newSize elements of the original array
    function _resizeAddressArray(address[] memory array, uint256 newSize) private pure returns (address[] memory) {
        require(newSize <= array.length, "New size must be <= original size");
        address[] memory newArray = new address[](newSize);
        for (uint256 i = 0; i < newSize; i++) {
            newArray[i] = array[i];
        }
        return newArray;
    }
}
