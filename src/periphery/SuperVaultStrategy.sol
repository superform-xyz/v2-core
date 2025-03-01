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
    uint256 private _lastTotalAssets;

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
        if (_initialized) revert NOT_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (peripheryRegistry_ == address(0)) revert INVALID_PERIPHERY_REGISTRY();
        if (config_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config_.maxAllocationRate == 0 || config_.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_MAX_ALLOCATION_RATE();
        }
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

        // Initialize _lastTotalAssets to 0
        _lastTotalAssets = 0;
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
        bytes32[][] calldata hookProofs,
        bytes[] memory hookCalldata,
        bool isDeposit
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();
        uint256 hooksLength = hooks.length;

        _validateHooksArrays(hooksLength, hookProofs.length, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and determine total amount (assets for deposits, shares for redeem)
        vars.totalRequestedAmount = _validateRequests(usersLength, users, isDeposit);

        // If deposit, check available balance
        if (isDeposit) {
            vars.availableAmount = _getTokenBalance(address(_asset), address(this));
            if (vars.availableAmount < vars.totalRequestedAmount) revert INVALID_AMOUNT();
        }

        // Process hooks and get targeted yield sources
        address[] memory targetedYieldSources;
        (vars, targetedYieldSources) = _processHooks(hooks, hookProofs, hookCalldata, vars, isDeposit);

        // Check vault caps after hooks processing (only for deposits)
        if (isDeposit) {
            _checkVaultCaps(targetedYieldSources);
        }

        /// @dev pps obtained here is just to forward to _processRedeem, not used in deposits
        (vars.pricePerShare, vars.totalAssets, vars.totalSupplyAmount) = _getSuperVaultAssetInfo();

        if (vars.totalSupplyAmount > 0 && isDeposit) {
            /// @dev calculate total supply increase based on total requested amount variation
            uint256 totalSupplyIncrease = vars.totalRequestedAmount.mulDiv(
                vars.totalSupplyAmount, vars.totalAssets - vars.totalRequestedAmount, Math.Rounding.Floor
            );
            /// @dev determine the global new PPS for all depositors being fulfilled with the total supply increase
            vars.pricePerShare =
                vars.totalAssets.mulDiv(PRECISION, vars.totalSupplyAmount + totalSupplyIncrease, Math.Rounding.Floor);
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
        (vars.currentPricePerShare,,) = _getSuperVaultAssetInfo();

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

    /// @inheritdoc ISuperVaultStrategy
    function allocate(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);
        uint256 hooksLength = hooks.length;
        _validateHooksArrays(hooksLength, hookProofs.length, hookCalldata.length);

        AllocationVars memory vars;
        address[] memory inflowTargets = new address[](hooksLength);
        uint256 inflowCount;

        // Get all TVLs in one call at the start
        (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs) = totalAssets();

        vars.balanceAssetBefore = _getTokenBalance(address(_asset), address(this));
        // Process each hook in sequence
        for (uint256 i; i < hooksLength;) {
            // Validate hook via merkle proof
            if (!isHookAllowed(hooks[i], hookProofs[i])) revert INVALID_HOOK();

            // Build executions for this hook
            ISuperHook hookContract = ISuperHook(hooks[i]);
            vars.executions = hookContract.build(vars.prevHook, address(this), hookCalldata[i]);
            // prevent any hooks with more than one execution
            if (vars.executions.length > 1) revert INVALID_HOOK();

            // Get amount from hook
            vars.amount = _decodeHookAmount(hooks[i], hookCalldata[i]);

            // Validate target is an active yield source
            YieldSource storage source = yieldSources[vars.executions[0].target];
            if (!source.isActive) revert YIELD_SOURCE_NOT_ACTIVE();

            vars.hookType = ISuperHookResult(hooks[i]).hookType();
            // For inflows, check allocation rates and track targets
            if (vars.hookType == ISuperHook.HookType.INFLOW) {
                // Find TVL for target yield source
                uint256 currentYieldSourceAssets;
                bool found;
                for (uint256 j; j < sourceTVLs.length;) {
                    if (sourceTVLs[j].source == vars.executions[0].target) {
                        currentYieldSourceAssets = sourceTVLs[j].tvl;
                        found = true;
                        break;
                    }
                    unchecked {
                        ++j;
                    }
                }
                if (!found) revert YIELD_SOURCE_NOT_FOUND();
                // Check allocation rate using the same totalAssets value
                if (
                    (currentYieldSourceAssets + vars.amount).mulDiv(
                        ONE_HUNDRED_PERCENT, totalAssets_, Math.Rounding.Floor
                    ) > globalConfig.maxAllocationRate
                ) {
                    revert MAX_ALLOCATION_RATE_EXCEEDED();
                }

                // Track inflow target
                inflowTargets[inflowCount++] = vars.executions[0].target;

                // Approve spending
                _handleTokenApproval(address(_asset), vars.executions[0].target, vars.amount);
            }

            // Execute the transaction
            (bool success,) =
                vars.executions[0].target.call{ value: vars.executions[0].value }(vars.executions[0].callData);
            if (!success) revert OPERATION_FAILED();

            // Reset approval if it was an inflow
            if (vars.hookType == ISuperHook.HookType.INFLOW) {
                _resetTokenApproval(address(_asset), vars.executions[0].target);
            }
            // Update prevHook for next iteration
            vars.prevHook = hooks[i];

            unchecked {
                ++i;
            }
        }
        vars.balanceAssetAfter = _getTokenBalance(address(_asset), address(this));
        // inflows increase totalAssets, outflows decrease totalAssets
        if (vars.balanceAssetAfter > vars.balanceAssetBefore) {
            _updateLastTotalAssets(_lastTotalAssets + (vars.balanceAssetAfter - vars.balanceAssetBefore));
        } else {
            _updateLastTotalAssets(_lastTotalAssets - (vars.balanceAssetBefore - vars.balanceAssetAfter));
        }

        // Resize array to actual count if needed
        if (inflowCount < hooksLength) {
            assembly {
                mstore(inflowTargets, inflowCount)
            }
        }

        // Check vault caps for all inflow targets after processing
        _checkVaultCaps(inflowTargets);
    }

    /// @inheritdoc ISuperVaultStrategy
    function claim(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata,
        address[] calldata expectedTokensOut
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);

        // Validate hook arrays
        _validateHookArrayLengths(hooks, hookProofs, hookCalldata);
        uint256 expectedTokensLength = expectedTokensOut.length;
        if (expectedTokensLength == 0) revert ZERO_LENGTH();

        // Execute claim hooks and get balance changes
        uint256[] memory balanceChanges = _processClaimHookExecution(hooks, hookProofs, hookCalldata, expectedTokensOut);

        // Store claimed tokens in state
        for (uint256 i; i < expectedTokensLength;) {
            if (balanceChanges[i] > 0) {
                claimedTokens[expectedTokensOut[i]] += balanceChanges[i];
            }

            unchecked {
                ++i;
            }
        }

        emit RewardsClaimed(expectedTokensOut, balanceChanges);
    }

    /// @inheritdoc ISuperVaultStrategy
    function compoundClaimedTokens(
        address[][] calldata hooks,
        bytes32[][] calldata swapHookProofs,
        bytes32[][] calldata allocateHookProofs,
        bytes[][] calldata hookCalldata,
        address[] calldata claimedTokensToCompound
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);

        // Validate overall hook sets
        _validateHookSets(hooks, hookCalldata, 2); // Must have exactly 2 arrays: swap and allocate

        // Validate individual hook arrays
        _validateHookArrayLengths(hooks[0], swapHookProofs, hookCalldata[0]);
        _validateHookArrayLengths(hooks[1], allocateHookProofs, hookCalldata[1]);

        uint256 claimedTokensLength = claimedTokensToCompound.length;
        if (claimedTokensLength == 0) revert ZERO_LENGTH();

        ClaimLocalVars memory vars;

        // Get initial asset balance
        vars.initialAssetBalance = _getTokenBalance(address(_asset), address(this));

        // Get balance changes for claimed tokens
        vars.balanceChanges = new uint256[](claimedTokensLength);
        for (uint256 i; i < claimedTokensLength;) {
            vars.balanceChanges[i] = claimedTokens[claimedTokensToCompound[i]];
            // Reset claimed tokens amount
            if (vars.balanceChanges[i] > 0) {
                claimedTokens[claimedTokensToCompound[i]] = 0;
            }
            unchecked {
                ++i;
            }
        }

        // Step 1: Execute swap hooks and get asset gained
        vars.assetGained = _processSwapHookExecution(
            hooks[0],
            swapHookProofs,
            hookCalldata[0],
            claimedTokensToCompound,
            vars.balanceChanges,
            vars.initialAssetBalance
        );

        // Step 2: Execute inflow hooks to allocate gained assets
        vars.fulfillmentVars.totalRequestedAmount = vars.assetGained;

        (vars.fulfillmentVars, vars.targetedYieldSources) =
            _processHooks(hooks[1], allocateHookProofs, hookCalldata[1], vars.fulfillmentVars, true);

        // Check vault caps after all hooks are processed
        _checkVaultCaps(vars.targetedYieldSources);

        // Verify all assets were allocated
        if (vars.fulfillmentVars.spentAmount != vars.assetGained) revert INVALID_AMOUNT();

        emit RewardsClaimedAndCompounded(vars.assetGained);
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

        totalAssets_ = _lastTotalAssets;
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

            if (_total4626Assets(source) < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_EXCEEDED();

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

                if (_total4626Assets(source) < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_EXCEEDED();

                yieldSource.isActive = true;
                emit YieldSourceReactivated(source);
            } else {
                if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
                if (_getTokenBalance(source, address(this)) > 0) revert INVALID_AMOUNT();

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
        if (config.maxAllocationRate == 0 || config.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_MAX_ALLOCATION_RATE();
        }
        if (config.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        globalConfig = config;
        emit GlobalConfigUpdated(config.vaultCap, config.superVaultCap, config.maxAllocationRate, config.vaultThreshold);
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

            // Update _lastTotalAssets
            _updateLastTotalAssets(_lastTotalAssets - amount);

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
    function isHookAllowed(address hook, bytes32[] calldata proof) public view returns (bool) {
        if (hookRoot == bytes32(0)) return false;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hook))));
        return MerkleProof.verify(proof, hookRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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

    function _getSuperVaultAssetInfo()
        private
        view
        returns (uint256 pricePerShare, uint256 totalAssetsValue, uint256 totalSupplyAmount)
    {
        totalSupplyAmount = IERC4626(_vault).totalSupply();
        totalAssetsValue = _lastTotalAssets;
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = PRECISION;
        } else {
            // Calculate current PPS in price decimals
            (totalAssetsValue,) = totalAssets();
            pricePerShare = totalAssetsValue.mulDiv(PRECISION, totalSupplyAmount, Math.Rounding.Floor);
        }
    }

    function _processDeposit(address user, SuperVaultState storage state, FulfillmentVars memory vars) private {
        vars.requestedAmount = state.pendingDepositRequest;
        vars.shares = vars.totalSupplyAmount == 0
            ? vars.requestedAmount
            : vars.requestedAmount.mulDiv(PRECISION, vars.pricePerShare, Math.Rounding.Floor);

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
        _onRedeemClaimable(user, finalAssets, vars.requestedAmount);
    }

    function _handleRequestDeposit(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        _safeTokenTransferFrom(address(_asset), msg.sender, address(this), assets);

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + assets;

        // Update _lastTotalAssets
        _updateLastTotalAssets(_lastTotalAssets + assets);

        return assets;
    }

    function _handleCancelDeposit(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = 0;

        // Update _lastTotalAssets
        _updateLastTotalAssets(_lastTotalAssets - assets);

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

        // Get actual balance and ensure we don't underflow _lastTotalAssets
        uint256 currentBalance = _getTokenBalance(address(_asset), address(this));
        uint256 assetsToWithdraw = assets > currentBalance ? currentBalance : assets;
        
        // Update _lastTotalAssets based on actual withdrawal amount
        _updateLastTotalAssets(currentBalance - assetsToWithdraw);

        // Transfer assets to vault
        _safeTokenTransfer(address(_asset), _vault, assetsToWithdraw);
        return assetsToWithdraw;
    }

    /// @notice Update the last total assets value
    /// @param updatedTotalAssets The new total assets value
    function _updateLastTotalAssets(uint256 updatedTotalAssets) internal {
        _lastTotalAssets = updatedTotalAssets;
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
            revert MISMATCH();
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
        bytes32[] calldata hookProof,
        ISuperHook.HookType expectedHookType,
        bool validateYieldSource,
        address approvalToken,
        uint256 approvalAmount
    )
        private
        returns (address target)
    {
        // Validate hook via merkle proof
        if (!isHookAllowed(hook, hookProof)) revert INVALID_HOOK();

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
        bytes32[][] calldata hookProofs,
        bytes[] memory hookCalldata,
        FulfillmentVars memory vars,
        bool isDeposit
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
                (locals.amount, locals.hookTarget) =
                    _processInflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i], hookProofs[i]);
                vars.prevHook = hooks[i];
                vars.spentAmount += locals.amount;
                locals.target = locals.hookTarget;
            } else {
                (locals.amount, locals.hookTarget) =
                    _processOutflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i], hookProofs[i]);
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

        // Verify all amounts were spent
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
        bytes32[] calldata hookProof
    )
        private
        returns (uint256 amount, address target)
    {
        // Get amount before execution
        amount = _decodeHookAmount(hook, hookCalldata);

        // Get all TVLs in one call
        (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs) = totalAssets();
        // Execute hook with asset approval
        target = _executeHook(
            hook, prevHook, hookCalldata, hookProof, ISuperHook.HookType.INFLOW, true, address(_asset), amount
        );

        // Update _lastTotalAssets to account for assets being moved in
        // TODO: this should be done via balance difference
        _updateLastTotalAssets(_lastTotalAssets - amount);

        // Find TVL for target yield source
        uint256 currentYieldSourceAssets;
        bool found;
        for (uint256 i; i < sourceTVLs.length;) {
            if (sourceTVLs[i].source == target) {
                currentYieldSourceAssets = sourceTVLs[i].tvl;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
        if (!found) revert YIELD_SOURCE_NOT_FOUND();

        // Check allocation rate using the same totalAssets value
        if (
            (currentYieldSourceAssets + amount).mulDiv(ONE_HUNDRED_PERCENT, totalAssets_, Math.Rounding.Floor)
                > globalConfig.maxAllocationRate
        ) {
            revert MAX_ALLOCATION_RATE_EXCEEDED();
        }
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
        bytes32[] calldata hookProof
    )
        private
        returns (uint256 amount, address target)
    {
        // Get amount before execution
        amount = _decodeHookAmount(hook, hookCalldata);

        // convert amount to underlying vault shares
        (uint256 pricePerShare,,) = _getSuperVaultAssetInfo();

        uint256 amountOfAssets = amount.mulDiv(pricePerShare, PRECISION, Math.Rounding.Floor);
        address yieldSource = HookDataDecoder.extractYieldSource(hookCalldata);
        uint256 amountConvertedToUnderlyingShares = IYieldSourceOracle(yieldSources[yieldSource].oracle).getShareOutput(
            yieldSource, address(_asset), amountOfAssets
        );

        hookCalldata = ISuperHookOutflow(hook).replaceCalldataAmount(hookCalldata, amountConvertedToUnderlyingShares);

        uint256 balanceAssetBefore = _getTokenBalance(address(_asset), address(this));

        // Execute hook with vault token approval
        target = _executeHook(
            hook,
            prevHook,
            hookCalldata,
            hookProof,
            ISuperHook.HookType.OUTFLOW,
            true,
            address(0), // target is the vault token
            amount
        );

        uint256 balanceAssetAfter = _getTokenBalance(address(_asset), address(this));
        uint256 assetDiff = balanceAssetAfter > balanceAssetBefore ? 
            balanceAssetAfter - balanceAssetBefore : 
            balanceAssetBefore - balanceAssetAfter;

        // Update _lastTotalAssets to account for assets being moved out
        _updateLastTotalAssets(_lastTotalAssets + (balanceAssetAfter - balanceAssetBefore));
    }

    /// @notice Process claim hook execution
    /// @param hooks Array of hooks to process
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    /// @param expectedTokensOut Array of tokens expected from hooks
    /// @return balanceChanges Array of balance changes for each token
    function _processClaimHookExecution(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata,
        address[] calldata expectedTokensOut
    )
        private
        returns (uint256[] memory balanceChanges)
    {
        // Get initial balances
        uint256[] memory initialBalances = new uint256[](expectedTokensOut.length);
        for (uint256 i = 0; i < expectedTokensOut.length;) {
            initialBalances[i] = _getTokenBalance(expectedTokensOut[i], address(this));
            unchecked {
                ++i;
            }
        }

        // Process hooks
        address prevHook;
        for (uint256 i = 0; i < hooks.length;) {
            // Execute hook with no approval needed
            _executeHook(
                hooks[i],
                prevHook,
                hookCalldata[i],
                hookProofs[i],
                ISuperHook.HookType.NONACCOUNTING,
                false,
                address(0), // no approval needed
                0
            );
            prevHook = hooks[i];
            unchecked {
                ++i;
            }
        }

        // Track balance changes
        balanceChanges = _trackBalanceChanges(expectedTokensOut, initialBalances, false);
    }

    /// @notice Process swap hook execution
    /// @param hooks Array of hooks to process
    /// @param hookProofs Array of merkle proofs for hooks
    /// @param hookCalldata Array of calldata for hooks
    /// @param expectedTokensOut Array of tokens expected from hooks
    /// @param initialBalances Array of initial balances for each token
    /// @param initialAssetBalance Initial balance of the asset
    /// @return assetGained Amount of asset gained from swaps
    function _processSwapHookExecution(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata,
        address[] calldata expectedTokensOut,
        uint256[] memory initialBalances,
        uint256 initialAssetBalance
    )
        private
        returns (uint256 assetGained)
    {
        // Process hooks
        address prevHook;
        for (uint256 i = 0; i < hooks.length;) {
            // Execute hook with expected token approval
            _executeHook(
                hooks[i],
                prevHook,
                hookCalldata[i],
                hookProofs[i],
                ISuperHook.HookType.NONACCOUNTING,
                false,
                expectedTokensOut[i],
                initialBalances[i]
            );
            prevHook = hooks[i];
            unchecked {
                ++i;
            }
        }

        // Verify all initial token balances are now zero
        _trackBalanceChanges(expectedTokensOut, initialBalances, true);

        // Calculate asset gained by comparing final balance with initial
        uint256 finalAssetBalance = _getTokenBalance(address(_asset), address(this));
        if (finalAssetBalance <= initialAssetBalance) revert INVALID_BALANCE_CHANGE();
        assetGained = finalAssetBalance - initialAssetBalance;
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
        (finalAssets, lastConsumedIndex) = _calculateHistoricalAssetsAndUpdatePoints(
            state, requestedShares, state.sharePricePointCursor
        );

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

    /// @notice Validates that the hooks array has the expected number of hook sets
    /// @param hooks Array of hook arrays
    /// @param hookCalldata Array of hook calldata arrays
    /// @param expectedLength Expected number of hook sets
    function _validateHookSets(
        address[][] calldata hooks,
        bytes[][] calldata hookCalldata,
        uint256 expectedLength
    )
        private
        pure
    {
        if (hooks.length != expectedLength || hookCalldata.length != expectedLength) {
            revert MISMATCH();
        }
    }

    /// @notice Validates that a hook array's length matches its proofs and calldata
    /// @param hooks Array of hooks
    /// @param hookProofs Array of hook proofs
    /// @param hookCalldata Array of hook calldata
    function _validateHookArrayLengths(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        private
        pure
    {
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (hooksLength != hookProofs.length || hooksLength != hookCalldata.length) {
            revert MISMATCH();
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
}
