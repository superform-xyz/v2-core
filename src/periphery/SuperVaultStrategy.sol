// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../vendor/pendle/IStandardizedYield.sol";

// External
import { IERC7540 } from "../vendor/vaults/7540/IERC7540.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Pausable } from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";



// Core Interfaces
import {
    Execution,
    ISuperHook,
    ISuperHookResult,
    ISuperHookOutflow,
    ISuperHookInflowOutflow,
    ISuperHookNonAccounting
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
contract SuperVaultStrategy is ISuperVaultStrategy, Pausable {
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
    uint256 private superVaultCap;

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

    // Track assets in transit from vault to two-step yield sources
    mapping(address yieldSource => uint256 assetsInTransit) private yieldSourceAssetsInTransit;

    IPeripheryRegistry private peripheryRegistry;

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
        uint256 superVaultCap_
    )
        external
    {
        if (_initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (peripheryRegistry_ == address(0)) revert INVALID_PERIPHERY_REGISTRY();
        if (superVaultCap_ == 0) revert INVALID_SUPER_VAULT_CAP();

        _initialized = true;
        _vault = vault_;
        _asset = IERC20(IERC4626(vault_).asset());
        _vaultDecimals = IERC20Metadata(vault_).decimals();

        superVaultCap = superVaultCap_;

        // Initialize roles
        addresses[MANAGER_ROLE] = manager_;
        addresses[STRATEGIST_ROLE] = strategist_;
        addresses[EMERGENCY_ADMIN_ROLE] = emergencyAdmin_;
        peripheryRegistry = IPeripheryRegistry(peripheryRegistry_);
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
        uint256[] memory expectedAssetsOrSharesOut,
        bool isDeposit
    )
        external
        whenNotPaused
    {
        _requireRole(STRATEGIST_ROLE);

        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();
        uint256 hooksLength = hooks.length;
        if (hooksLength != expectedAssetsOrSharesOut.length) revert INVALID_ARRAY_LENGTH();

        _validateFulfillHooksArrays(hooksLength, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and determine total amount (assets for deposits, shares for redeem)
        vars.totalRequestedAmount = _validateRequests(usersLength, users, isDeposit);

        /// @dev grab current PPS before processing hooks
        vars.pricePerShare = _getSuperVaultPPS();

        // Process hooks
        vars = _processHooks(hooks, hookCalldata, vars, expectedAssetsOrSharesOut, isDeposit);

        // Process requests
        for (uint256 i; i < usersLength; ++i) {
            address user = users[i];
            SuperVaultState storage state = superVaultState[user];

            if (isDeposit) {
                _processDeposit(user, state, vars);
            } else {
                _processRedeem(user, state, vars);
            }
        }

        //check super vault cap
        _checkSuperVaultCap();
    }

    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external whenNotPaused {
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
        for (uint256 i; i < depositLength; ++i) {
            address depositor = depositUsers[i];
            SuperVaultState storage depositState = superVaultState[depositor];
            vars.depositAssets = depositState.pendingDepositRequest;
            if (vars.depositAssets == 0) revert REQUEST_NOT_FOUND();

            // Calculate shares needed at current price
            vars.sharesNeeded = vars.depositAssets.mulDiv(PRECISION, vars.currentPricePerShare, Math.Rounding.Floor);
            vars.remainingShares = vars.sharesNeeded;

            // Try to fulfill with redeem requests
            for (uint256 j; j < redeemLength && vars.remainingShares > 0; ++j) {
                address redeemer = redeemUsers[j];
                SuperVaultState storage redeemState = superVaultState[redeemer];
                vars.redeemShares = redeemState.pendingRedeemRequest;
                if (vars.redeemShares == 0) {
                    continue;
                }

                // Calculate how many shares we can take from this redeemer
                vars.sharesToUse = vars.redeemShares > vars.remainingShares ? vars.remainingShares : vars.redeemShares;

                // Update redeemer's state and accumulate shares used
                redeemState.pendingRedeemRequest -= vars.sharesToUse;
                sharesUsedByRedeemer[j] += vars.sharesToUse;

                vars.remainingShares -= vars.sharesToUse;
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
        }

        // Process accumulated shares for redeemers
        for (uint256 i; i < redeemLength; ++i) {
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
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function executeHooks(address[] calldata hooks, bytes[] calldata hookCalldata) external whenNotPaused {
        _requireRole(STRATEGIST_ROLE);

        ExecuteHooksVars memory vars;
        vars.hooksLength = hooks.length;
        _validateFulfillHooksArrays(vars.hooksLength, hookCalldata.length);

        vars.inflowTargets = new address[](vars.hooksLength);

        // Process each hook in sequence
        for (uint256 i = 0; i < vars.hooksLength; ++i) {
            // Validate hook via periphery registry
            if (!peripheryRegistry.isHookRegistered(hooks[i])) revert INVALID_HOOK();

            // Get hook type
            vars.hookContract = ISuperHook(hooks[i]);
            vars.hookType = ISuperHookResult(hooks[i]).hookType();

            // Call preExecute to initialize outAmount tracking
            vars.hookContract.preExecute(vars.prevHook, address(this), hookCalldata[i]);

            // Extract targeted yield source from hook calldata
            vars.targetedYieldSource = HookDataDecoder.extractYieldSource(hookCalldata[i]);

            // Build executions for this hook
            vars.executions = vars.hookContract.build(vars.prevHook, address(this), hookCalldata[i]);

            if (vars.hookType == ISuperHook.HookType.INFLOW || vars.hookType == ISuperHook.HookType.OUTFLOW) {
                if (!yieldSources[vars.targetedYieldSource].isActive) {
                    revert YIELD_SOURCE_NOT_ACTIVE();
                }
                if (vars.hookType == ISuperHook.HookType.INFLOW) {
                    vars.inflowTargets[vars.inflowCount++] = vars.targetedYieldSource;
                }
            }

            for (uint256 j = 0; j < vars.executions.length; ++j) {
                // Execute the transaction
                (vars.success,) =
                    vars.executions[j].target.call{ value: vars.executions[j].value }(vars.executions[j].callData);
                if (!vars.success) revert OPERATION_FAILED();
            }
            // Call postExecute to update outAmount tracking
            vars.hookContract.postExecute(vars.prevHook, address(this), hookCalldata[i]);

            // If the hook is non-accounting and the yield source is active, add the asset balance change to the yield source's assets in transit
            if (vars.hookType == ISuperHook.HookType.NONACCOUNTING && yieldSources[vars.targetedYieldSource].isActive) {
                uint256 outAmount = ISuperHookResult(hooks[i]).outAmount();

                uint256 assetsOut = IYieldSourceOracle(yieldSources[vars.targetedYieldSource].oracle).getAssetOutput(vars.targetedYieldSource, address(this), outAmount);

                yieldSourceAssetsInTransit[vars.targetedYieldSource] += assetsOut;
            }

            // Update prevHook for next iteration
            vars.prevHook = hooks[i];
        }
        // Resize array if needed
        if (vars.inflowCount < vars.hooksLength && vars.inflowCount > 0) {
            vars.inflowTargets = _resizeAddressArray(vars.inflowTargets, vars.inflowCount);
        }

        //check super vault cap
        _checkSuperVaultCap();

        emit HooksExecuted(hooks);
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

        for (uint256 i; i < length; ++i) {
            address source = yieldSourcesList[i];
            if (yieldSources[source].isActive) {
                // Add yield source's TVL to total assets
                uint256 tvl = _getTvlByOwnerOfShares(source);
                totalAssets_ += tvl + yieldSourceAssetsInTransit[source];
                sourceTVLs[activeSourceCount++] = 
                YieldSourceTVL({ source: source, tvl: tvl + yieldSourceAssetsInTransit[source] });
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

    /// @inheritdoc ISuperVaultStrategy
    function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) external {
        _requireRole(MANAGER_ROLE);
        YieldSource storage yieldSource = yieldSources[source];

        if (actionType == 0) {
            if (source == address(0)) revert ZERO_ADDRESS();
            if (oracle == address(0)) revert ZERO_ADDRESS();
            if (yieldSource.oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

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
    function updateSuperVaultCap(uint256 superVaultCap_) external {
        _requireRole(MANAGER_ROLE);
        if (superVaultCap_ == 0) revert INVALID_SUPER_VAULT_CAP();

        superVaultCap = superVaultCap_;
        emit SuperVaultCapUpdated(superVaultCap_);
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

    /// @notice Pauses the strategy
    function pause() external {
        _requireRole(MANAGER_ROLE);
        _pause();
    }

    /// @notice Unpauses the strategy
    function unpause() external {
        _requireRole(MANAGER_ROLE);
        _unpause();
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
    function getConfigInfo() external view returns (uint256 superVaultCap_, FeeConfig memory feeConfig_) {
        superVaultCap_ = superVaultCap;
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
    function _checkSuperVaultCap() internal view {
        if (superVaultCap > 0) {
            (uint256 totalAssets_,) = totalAssets();
            if (totalAssets_ > superVaultCap) revert SUPER_VAULT_CAP_EXCEEDED();
        }
    }

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
        state.pendingDepositRequest = vars.requestedAmount >= vars.spentAmount ? vars.requestedAmount - vars.spentAmount : 0;
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
        state.pendingRedeemRequest = state.pendingRedeemRequest >= vars.spentAmount ? state.pendingRedeemRequest - vars.spentAmount : 0;

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

        return assets;
    }

    function _handleCancelDeposit(address controller, uint256 assets) private returns (uint256) {
        _requireVault();
        if (assets == 0) revert INVALID_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = 0;

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

        // Get actual balance and ensure we don't underflow
        uint256 currentBalance = _getTokenBalance(address(_asset), address(this));
        uint256 assetsToWithdraw = assets > currentBalance ? currentBalance : assets;

        // Transfer assets to vault
        _safeTokenTransfer(address(_asset), _vault, assetsToWithdraw);
        return assetsToWithdraw;
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
        for (uint256 i; i < usersLength; ++i) {
            uint256 pendingRequest = isDeposit
                ? superVaultState[users[i]].pendingDepositRequest
                : superVaultState[users[i]].pendingRedeemRequest;

            if (pendingRequest == 0) revert REQUEST_NOT_FOUND();
            totalRequested += pendingRequest;
        }
    }

    /// @notice Common hook execution logic
    /// @param hook The hook to execute
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param expectedHookType The expected type of hook
    /// @param approvalToken Token to approve (address(0) if no approval needed)
    /// @param approvalAmount Amount to approve
    function _executeHook(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        ISuperHook.HookType expectedHookType,
        address approvalToken,
        uint256 approvalAmount,
        address target
    )
        private
    {
        // Validate hook via merkle proof
        if (!_isFulfillRequestsHook(hook)) revert INVALID_HOOK();

        // Build executions for this hook
        ISuperHook hookContract = ISuperHook(hook);
        Execution[] memory executions = hookContract.build(prevHook, address(this), hookCalldata);
        // Validate hook type
        ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();
        if (hookType != expectedHookType) revert INVALID_HOOK_TYPE();

        for (uint256 i; i < executions.length; ++i) {
            target = executions[i].target;

            approvalToken = hookType == ISuperHook.HookType.OUTFLOW ? target : approvalToken;
            // Handle token approvals if needed
            if (approvalToken != address(0)) {
                _handleTokenApproval(approvalToken, target, approvalAmount);
            }

            // Execute the transaction
            (bool success,) = target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) revert OPERATION_FAILED();
        }

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

        for (uint256 i; i < length; ++i) {
            uint256 finalBalance = _getTokenBalance(tokens[i], address(this));

            if (requireZeroBalance) {
                if (finalBalance != 0) revert INVALID_AMOUNT();
            } else {
                if (finalBalance < initialBalances[i]) revert INVALID_AMOUNT();
                changes[i] = finalBalance - initialBalances[i];
            }
        }
    }

    /// @notice Process hooks for both deposit and redeem fulfillment
    /// @param hooks Array of hook addresses
    /// @param hookCalldata Array of calldata for hooks
    /// @param vars Fulfillment variables
    /// @param isDeposit Whether this is a deposit fulfillment
    /// @return vars Updated fulfillment variables
    function _processHooks(
        address[] calldata hooks,
        bytes[] memory hookCalldata,
        FulfillmentVars memory vars,
        uint256[] memory expectedAssetsOrSharesOut,
        bool isDeposit
    )
        private
        returns (FulfillmentVars memory)
    {
        ProcessHooksLocalVars memory locals;
        locals.hooksLength = hooks.length;

        // Process each hook in sequence
        for (uint256 i; i < locals.hooksLength; ++i) {
            // Process hook executions
            if (isDeposit) {
                (locals.amount, locals.outAmount) =
                    _processInflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i]);
            } else {
                (locals.amount, locals.outAmount) =
                    _processOutflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i], vars.pricePerShare);
            }

            if (expectedAssetsOrSharesOut[i] == 0) revert INVALID_EXPECTED_ASSETS_OR_SHARES_OUT();

            vars.prevHook = hooks[i];
            vars.spentAmount += locals.amount;
            if (
                locals.outAmount * ONE_HUNDRED_PERCENT
                    < expectedAssetsOrSharesOut[i] * (ONE_HUNDRED_PERCENT - _getSlippageTolerance())
            ) revert MINIMUM_OUTPUT_AMOUNT_NOT_MET();
        }

        // Resize array to actual count if needed
        if (locals.targetedSourcesCount < locals.hooksLength) {
            // Create new array with actual count and copy elements
            locals.resizedArray = new address[](locals.targetedSourcesCount);
            for (uint256 i = 0; i < locals.targetedSourcesCount; i++) {
                locals.resizedArray[i] = locals.targetedYieldSources[i];
            }
            locals.targetedYieldSources = locals.resizedArray;
        }

        return (vars);
    }

    /// @notice Process inflow hook execution
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @return amount The amount from the hook
    function _processInflowHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata
    )
        private
        returns (uint256 amount, uint256 outAmount)
    {
        // Get amount before execution
        amount = _decodeHookAmount(hook, hookCalldata);

        address target = HookDataDecoder.extractYieldSource(hookCalldata);
        YieldSource storage yieldSource = yieldSources[target];
        if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
        outAmount = IYieldSourceOracle(yieldSource.oracle).getBalanceOfOwner(target, address(this));

        // Execute hook with asset approval
        _executeHook(hook, prevHook, hookCalldata, ISuperHook.HookType.INFLOW, address(_asset), amount, target);

        outAmount = IYieldSourceOracle(yieldSource.oracle).getBalanceOfOwner(target, address(this)) - outAmount;
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
    /// @return amount The amount from the hook
    function _processOutflowHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        uint256 pricePerShare
    )
        private
        returns (uint256 amount, uint256 outAmount)
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

        execVars.target = HookDataDecoder.extractYieldSource(hookCalldata);
        if (!yieldSources[execVars.target].isActive) revert YIELD_SOURCE_NOT_ACTIVE();

        execVars.balanceAssetBefore = _getTokenBalance(address(_asset), address(this));

        // Execute hook and track balances
        _executeHook(
            hook,
            prevHook,
            hookCalldata,
            ISuperHook.HookType.OUTFLOW,
            address(0),
            execVars.amountConvertedToUnderlyingShares,
            execVars.target
        );

        execVars.balanceAssetAfter = _getTokenBalance(address(_asset), address(this));

        outAmount = execVars.balanceAssetAfter - execVars.balanceAssetBefore;

        if (outAmount > 0) {
            // Get hook type
            ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();

            if (hookType == ISuperHook.HookType.OUTFLOW || hookType == ISuperHook.HookType.NONACCOUNTING) {
                if (yieldSourceAssetsInTransit[execVars.target] >= outAmount) {
                    yieldSourceAssetsInTransit[execVars.target] -= outAmount;
                }
            }
        }

        return (execVars.amount, outAmount);
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

        for (uint256 j = currentIndex; j < sharePricePointsLength && remainingShares > 0; ++j) {
            SharePricePoint memory point = state.sharePricePoints[j];
            uint256 sharesFromPoint = point.shares > remainingShares ? remainingShares : point.shares;
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, PRECISION, Math.Rounding.Floor);

            if (sharesFromPoint == point.shares) {
                lastConsumedIndex = j + 1;
            } else if (sharesFromPoint < point.shares) {
                state.sharePricePoints[j].shares -= sharesFromPoint;
            }

            remainingShares -= sharesFromPoint;
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
        if (newSize > array.length) revert RESIZED_ARRAY_LENGTH_ERROR();
        address[] memory newArray = new address[](newSize);
        for (uint256 i; i < newSize; ++i) {
            newArray[i] = array[i];
        }
        return newArray;
    }

    function _getSlippageTolerance() private view returns (uint256) {
        return peripheryRegistry.svSlippageTolerance();
    }
}
