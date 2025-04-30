// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// Core Interfaces
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookOutflow,
    ISuperHookInflowOutflow,
    ISuperHookResultOutflow,
    ISuperHookContextAware
} from "../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../core/interfaces/accounting/IYieldSourceOracle.sol";

// Periphery Interfaces
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import { HookDataDecoder } from "../core/libraries/HookDataDecoder.sol";
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";
import { ISuperGovernor, FeeType } from "./interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "./interfaces/ISuperVaultAggregator.sol";

/// @title SuperVaultStrategy
/// @author SuperForm Labs
/// @notice Strategy implementation for SuperVault that manages yield sources, executes strategies, and uses optimistic
/// PPS.
contract SuperVaultStrategy is ISuperVaultStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant BPS_PRECISION = 10_000; // For PPS deviation check
    uint256 private constant TOLERANCE_CONSTANT = 10 wei;

    // Role identifiers
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 private constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    // Slippage tolerance in BPS (1%)
    uint256 private constant SV_SLIPPAGE_TOLERANCE_BPS = 100;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool private _initialized;
    address private _vault;
    IERC20 private _asset;
    uint8 private _vaultDecimals;

    // Global configuration
    uint256 private superVaultCap;

    // Fee configuration
    FeeConfig private feeConfig;
    FeeConfig private proposedFeeConfig;
    uint256 private feeConfigEffectiveTime;

    // Core contracts
    ISuperGovernor private superGovernor;

    // Hook root configuration
    bytes32 private hookRoot;
    bytes32 private proposedHookRoot;
    uint256 private hookRootEffectiveTime;

    // Emergency withdrawable configuration
    bool public emergencyWithdrawable;
    bool public proposedEmergencyWithdrawable;
    uint256 public emergencyWithdrawableEffectiveTime;

    // Role-based access control
    mapping(bytes32 role => address roleAddress) public addresses;

    // Yield source configuration
    mapping(address source => YieldSource sourceConfig) private yieldSources;
    mapping(address source => YieldSource sourceConfig) private asyncYieldSources;
    address[] private yieldSourcesList;
    address[] private asyncYieldSourcesList;

    // PPS is now managed by SuperVaultAggregator

    // --- Redeem Request State ---
    mapping(address controller => SuperVaultState state) private superVaultState;

    modifier onlyRole(bytes32 role) {
        if (msg.sender != addresses[role]) revert ACCESS_DENIED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address vault_,
        address manager_,
        address emergencyAdmin_,
        address superGovernor_,
        uint256 superVaultCap_
    )
        external
    {
        if (_initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();
        if (superVaultCap_ == 0) revert INVALID_SUPER_VAULT_CAP();

        _initialized = true;
        _vault = vault_;
        superGovernor = ISuperGovernor(superGovernor_);
        superVaultCap = superVaultCap_;

        _initializeRoles(manager_, emergencyAdmin_);

        emit Initialized(_vault, manager_, emergencyAdmin_, superGovernor_, superVaultCap_);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE STRATEGY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultStrategy
    function handleOperation(address controller, uint256 assets, uint256 shares, Operation operation) external {
        _requireVault();

        if (operation == Operation.Deposit) {
            _getAndCheckStrategist();

            _handleDeposit(controller, assets, shares);
        } else if (operation == Operation.RedeemRequest) {
            _handleRequestRedeem(controller, shares);
        } else if (operation == Operation.CancelRedeem) {
            _handleCancelRedeem(controller);
        } else if (operation == Operation.ClaimRedeem) {
            _handleClaimRedeem(controller, assets);
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultStrategy
    function executeHooks(ExecuteArgs calldata args) external nonReentrant {
        _getAndCheckStrategist();
        // TODO check msg-sender to be a valid caller

        uint256 hooksLength = args.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (args.hookProofs.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.expectedAssetsOrSharesOut.length != hooksLength) revert INVALID_ARRAY_LENGTH();

        address prevHook;

        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];
            if (!isHookAllowed(hook, args.hookProofs[i])) revert INVALID_HOOK();
            prevHook =
                _processSingleHookExecution(hook, prevHook, args.hookCalldata[i], args.expectedAssetsOrSharesOut[i]);
        }
        emit HooksExecuted(args.hooks);
    }

    /// @inheritdoc ISuperVaultStrategy
    function fulfillRedeemRequests(FulfillArgs calldata args) external nonReentrant {
        // note: this prevents users from exiting till strategist has a minimum stake
        // todo: implement emergency procedure could allow an adjudicator to take over strategist and allow exit here?
        _getAndCheckStrategist();
        // todo check caller

        uint256 hooksLength = args.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        uint256 controllersLength = args.controllers.length;
        if (controllersLength == 0) revert ZERO_LENGTH();
        if (args.expectedAssetsOrSharesOut.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.controllers.length != controllersLength) revert INVALID_ARRAY_LENGTH();

        uint256 processedShares;
        uint256 currentPPS = _getSuperVaultAggregator().getPPS(address(this));
        if (currentPPS == 0) revert INVALID_PPS();

        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];
            if (!_isFulfillRequestsHook(hook)) revert INVALID_HOOK();

            uint256 amountSharesSpent = _processSingleFulfillHookExecution(
                hook, args.hookCalldata[i], args.expectedAssetsOrSharesOut[i], currentPPS
            );
            processedShares += amountSharesSpent;
        }

        _processRedeemFulfillments(args.controllers, controllersLength, processedShares, currentPPS);

        ISuperVault(_vault).burnShares(processedShares);

        emit RedeemRequestsFulfilled(args.hooks, args.controllers, processedShares, currentPPS);
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function manageYieldSource(
        address source,
        address oracle,
        uint8 actionType,
        bool activate,
        bool isAsync
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (actionType == 0) {
            _addYieldSource(source, oracle, isAsync);
        } else if (actionType == 1) {
            _updateYieldSourceOracle(source, oracle);
        } else if (actionType == 2) {
            _toggleYieldSourceActivation(source, activate);
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    function updateSuperVaultCap(uint256 superVaultCap_) external onlyRole(MANAGER_ROLE) {
        if (superVaultCap_ == 0) revert INVALID_SUPER_VAULT_CAP();
        superVaultCap = superVaultCap_;
        emit SuperVaultCapUpdated(superVaultCap_);
    }

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

    function proposeVaultFeeConfigUpdate(
        uint256 performanceFeeBps,
        address recipient
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (performanceFeeBps > ONE_HUNDRED_PERCENT) revert INVALID_PERFORMANCE_FEE_BPS();
        if (recipient == address(0)) revert ZERO_ADDRESS();
        proposedFeeConfig = FeeConfig({ performanceFeeBps: performanceFeeBps, recipient: recipient });
        feeConfigEffectiveTime = block.timestamp + ONE_WEEK;
        emit VaultFeeConfigProposed(performanceFeeBps, recipient, feeConfigEffectiveTime);
    }

    function executeVaultFeeConfigUpdate() external {
        if (block.timestamp < feeConfigEffectiveTime) revert INVALID_TIMESTAMP();
        if (proposedFeeConfig.recipient == address(0)) revert ZERO_ADDRESS();
        feeConfig = proposedFeeConfig;
        delete proposedFeeConfig;
        feeConfigEffectiveTime = 0;
        emit VaultFeeConfigUpdated(feeConfig.performanceFeeBps, feeConfig.recipient);
    }

    function setAddress(bytes32 role, address account) external onlyRole(MANAGER_ROLE) {
        if (account == address(0)) revert ZERO_ADDRESS();
        if (role == MANAGER_ROLE && account != msg.sender) revert ACCESS_DENIED();
        // STRATEGIST_ROLE is no longer set here - managed by SuperVaultAggregator
        addresses[role] = account;
    }

    // PPS configuration is now managed by SuperVaultAggregator

    function manageEmergencyWithdraw(uint8 action, address recipient, uint256 amount) external {
        if (action == 1) {
            _proposeEmergencyWithdraw();
        } else if (action == 2) {
            _executeEmergencyWithdrawActivation();
        } else if (action == 3) {
            _performEmergencyWithdraw(recipient, amount);
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    function getVaultInfo() external view returns (address vault_, address asset_, uint8 vaultDecimals_) {
        vault_ = _vault;
        asset_ = address(_asset);
        vaultDecimals_ = _vaultDecimals;
    }

    function getHookInfo()
        external
        view
        returns (bytes32 hookRoot_, bytes32 proposedHookRoot_, uint256 hookRootEffectiveTime_)
    {
        hookRoot_ = hookRoot;
        proposedHookRoot_ = proposedHookRoot;
        hookRootEffectiveTime_ = hookRootEffectiveTime;
    }

    function getConfigInfo() external view returns (uint256 superVaultCap_, FeeConfig memory feeConfig_) {
        superVaultCap_ = superVaultCap;
        feeConfig_ = feeConfig;
    }

    function getStoredPPS() external view returns (uint256) {
        return _getSuperVaultAggregator().getPPS(address(this));
    }

    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }

    function getYieldSourcesList() external view returns (address[] memory) {
        return yieldSourcesList;
    }

    function isHookAllowed(address hook, bytes32[] memory proof) public view returns (bool) {
        if (hookRoot == bytes32(0)) return false;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hook))));
        return MerkleProof.verify(proof, hookRoot, leaf);
    }

    function pendingRedeemRequest(address controller) external view returns (uint256 pendingShares) {
        return superVaultState[controller].pendingRedeemRequest;
    }

    function claimableWithdraw(address controller) external view returns (uint256 claimableAssets) {
        return superVaultState[controller].maxWithdraw;
    }

    function getAverageWithdrawPrice(address controller) external view returns (uint256 averageWithdrawPrice) {
        return superVaultState[controller].averageWithdrawPrice;
    }

    // PPS configuration is now managed by SuperVaultAggregator

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // --- Internal Initialization Helpers ---
    function _initializeRoles(address manager_, address emergencyAdmin_) internal {
        addresses[MANAGER_ROLE] = manager_;
        addresses[EMERGENCY_ADMIN_ROLE] = emergencyAdmin_;
    }

    // --- Hook Execution ---

    function _processSingleHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        uint256 expectedAssetsOrSharesOut
    )
        internal
        returns (address)
    {
        ExecutionVars memory vars;

        vars.hookContract = ISuperHook(hook);
        vars.targetedYieldSource = HookDataDecoder.extractYieldSource(hookCalldata);
        // todo missing validation of targeted yield source

        bool usePrevHookAmount = _decodeHookUsePrevHookAmount(hook, hookCalldata);
        if (usePrevHookAmount && prevHook != address(0)) {
            vars.outAmount = _getPreviousHookOutAmount(prevHook);
            if (expectedAssetsOrSharesOut == 0) revert ZERO_EXPECTED_VALUE();
            uint256 minExpectedPrevOut = expectedAssetsOrSharesOut * (BPS_PRECISION - _getSlippageTolerance());
            if (vars.outAmount * BPS_PRECISION < minExpectedPrevOut) {
                revert MINIMUM_PREVIOUS_HOOK_OUT_AMOUNT_NOT_MET();
            }
        }

        vars.hookContract.preExecute(prevHook, address(this), hookCalldata);

        vars.executions = vars.hookContract.build(prevHook, address(this), hookCalldata);
        for (uint256 j; j < vars.executions.length; ++j) {
            (vars.success,) =
                vars.executions[j].target.call{ value: vars.executions[j].value }(vars.executions[j].callData);
            if (!vars.success) revert OPERATION_FAILED();
        }
        vars.hookContract.postExecute(prevHook, address(this), hookCalldata);

        emit HookExecuted(hook, prevHook, vars.targetedYieldSource, usePrevHookAmount, hookCalldata);

        return hook;
    }

    function _processSingleFulfillHookExecution(
        address hook,
        bytes memory hookCalldata,
        uint256 expectedAssetOutput,
        uint256 currentPPS
    )
        internal
        returns (uint256)
    {
        OutflowExecutionVars memory vars;
        vars.hookContract = ISuperHook(hook);
        vars.hookType = ISuperHookResult(hook).hookType();
        if (vars.hookType != ISuperHook.HookType.OUTFLOW) revert INVALID_HOOK_TYPE();
        vars.targetedYieldSource = HookDataDecoder.extractYieldSource(hookCalldata);
        // we must always encode supervault shares when fulfilling redemptions
        vars.superVaultShares = ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);

        // Calculate underlying shares and update hook calldata
        vars.amountOfAssets = vars.superVaultShares.mulDiv(currentPPS, PRECISION, Math.Rounding.Floor);
        vars.svAsset = address(_asset);
        vars.amountConvertedToUnderlyingShares = IYieldSourceOracle(yieldSources[vars.targetedYieldSource].oracle)
            .getShareOutput(vars.targetedYieldSource, vars.svAsset, vars.amountOfAssets);
        hookCalldata =
            ISuperHookOutflow(hook).replaceCalldataAmount(hookCalldata, vars.amountConvertedToUnderlyingShares);

        vars.balanceAssetBefore = _getTokenBalance(vars.svAsset, address(this));

        vars.executions = vars.hookContract.build(address(0), address(this), hookCalldata);
        for (uint256 j; j < vars.executions.length; ++j) {
            (vars.success,) =
                vars.executions[j].target.call{ value: vars.executions[j].value }(vars.executions[j].callData);
            if (!vars.success) revert OPERATION_FAILED();
        }

        vars.outAmount = _getTokenBalance(vars.svAsset, address(this)) - vars.balanceAssetBefore;

        if (vars.outAmount == 0) revert ZERO_OUTPUT_AMOUNT();
        if (expectedAssetOutput == 0) revert ZERO_EXPECTED_VALUE();
        if (vars.outAmount * BPS_PRECISION < expectedAssetOutput * (BPS_PRECISION - _getSlippageTolerance())) {
            revert MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET();
        }
        emit FulfillHookExecuted(hook, vars.targetedYieldSource, hookCalldata);

        return vars.superVaultShares;
    }

    function _processRedeemFulfillments(
        address[] calldata controllers,
        uint256 controllersLength,
        uint256 processedShares,
        uint256 currentPPS
    )
        internal
    {
        uint256 totalRequestedAmount = 0;
        uint256[] memory controllerRequestedAmount = new uint256[](controllersLength);
        for (uint256 i; i < controllersLength; ++i) {
            controllerRequestedAmount[i] = superVaultState[controllers[i]].pendingRedeemRequest;
            totalRequestedAmount += controllerRequestedAmount[i];
        }
        if (processedShares + TOLERANCE_CONSTANT < totalRequestedAmount) {
            revert INVALID_REDEEM_FILL();
        }

        for (uint256 i; i < controllersLength; ++i) {
            SuperVaultState storage state = superVaultState[controllers[i]];

            uint256 finalAssets =
                _calculateHistoricalAssetsAndProcessFees(state, controllerRequestedAmount[i], currentPPS);

            // Update user state, no partial redeems allowed
            state.pendingRedeemRequest -= controllerRequestedAmount[i];
            state.maxWithdraw += finalAssets;

            // Call vault callback
            _onRedeemClaimable(
                controllers[i],
                finalAssets,
                controllerRequestedAmount[i],
                state.averageWithdrawPrice,
                state.accumulatorShares,
                state.accumulatorCostBasis
            );
        }
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
        returns (uint256 finalAssets)
    {
        // Calculate cost basis based on requested shares
        uint256 historicalAssets = _calculateCostBasis(state, requestedShares);

        // Process fees and get final assets
        finalAssets = _processFees(requestedShares, currentPricePerShare, historicalAssets);

        // Update average withdraw price if needed
        if (requestedShares > 0) {
            _updateAverageWithdrawPrice(state, requestedShares, finalAssets);
        }

        return finalAssets;
    }

    /// @notice Calculate cost basis for requested shares using weighted average approach
    /// @param state User's vault state
    /// @param requestedShares Shares being redeemed
    function _calculateCostBasis(
        SuperVaultState storage state,
        uint256 requestedShares
    )
        private
        returns (uint256 costBasis)
    {
        if (requestedShares > state.accumulatorShares) revert INSUFFICIENT_SHARES();

        // Calculate cost basis proportionally
        costBasis = requestedShares.mulDiv(state.accumulatorCostBasis, state.accumulatorShares, Math.Rounding.Floor);

        // Update user's accumulator state
        state.accumulatorShares -= requestedShares;
        state.accumulatorCostBasis -= costBasis;

        return costBasis;
    }

    function _processFees(
        uint256 requestedShares,
        uint256 currentPricePerShare,
        uint256 historicalAssets
    )
        private
        returns (uint256 finalAssets)
    {
        // Calculate current value of the shares at current price
        uint256 currentValue = requestedShares.mulDiv(currentPricePerShare, PRECISION, Math.Rounding.Floor);

        // Apply fees only on profit
        finalAssets = _calculateAndTransferFee(currentValue, historicalAssets);

        // Ensure we don't exceed available balance
        uint256 balanceOfStrategy = _getTokenBalance(address(_asset), address(this));
        finalAssets = finalAssets > balanceOfStrategy ? balanceOfStrategy : finalAssets;

        return finalAssets;
    }

    /// @notice Calculate fee on profit and transfer to recipient
    /// @param currentAssets Current value of shares in assets
    /// @param historicalAssets Historical value of shares in assets
    /// @return uint256 Assets after fee deduction
    function _calculateAndTransferFee(uint256 currentAssets, uint256 historicalAssets) private returns (uint256) {
        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, BPS_PRECISION, Math.Rounding.Floor);
            if (totalFee > 0) {
                // Calculate Superform's portion of the fee using revenueShare from SuperGovernor
                uint256 superformFee = totalFee.mulDiv(
                    superGovernor.getFee(FeeType.SUPER_VAULT_PERFORMANCE_FEE), ONE_HUNDRED_PERCENT, Math.Rounding.Floor
                );
                uint256 recipientFee = totalFee - superformFee;

                // Transfer fees
                if (superformFee > 0) {
                    // Get treasury address from SuperGovernor
                    address treasury = superGovernor.getAddress(superGovernor.TREASURY());
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

    // --- End Hook Execution ---

    // --- Internal Strategist Check Helpers ---
    function _getAndCheckStrategist() internal view {
        // Get the strategist from the aggregator
        address strategist = _getStrategist();
        // Check if strategist
        _isStrategist(strategist);
    }

    function _getSuperVaultAggregator() internal view returns (ISuperVaultAggregator) {
        address aggregatorAddress = superGovernor.getAddress(superGovernor.SUPER_VAULT_AGGREGATOR());

        return ISuperVaultAggregator(aggregatorAddress);
    }

    function _getStrategist() internal view returns (address) {
        return _getSuperVaultAggregator().getStrategist(address(this));
    }

    function _isStrategist(address strategist_) internal view {
        if (!_getSuperVaultAggregator().isStrategist(strategist_, address(this))) {
            revert STRATEGIST_NOT_AUTHORIZED();
        }
    }

    // --- End Internal Strategist Check Helpers ---

    function _addYieldSource(address source, address oracle, bool isAsync) internal {
        if (source == address(0) || oracle == address(0)) revert ZERO_ADDRESS();
        if (yieldSources[source].oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();
        yieldSources[source] = YieldSource({ oracle: oracle, isActive: true });
        yieldSourcesList.push(source);
        if (isAsync) {
            asyncYieldSources[source] = YieldSource({ oracle: oracle, isActive: true });
            asyncYieldSourcesList.push(source);
        }
        emit YieldSourceAdded(source, oracle);
    }

    function _updateYieldSourceOracle(address source, address oracle) internal {
        if (oracle == address(0)) revert ZERO_ADDRESS();
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        address oldOracle = yieldSource.oracle;
        yieldSource.oracle = oracle;
        if (asyncYieldSources[source].oracle != address(0)) {
            asyncYieldSources[source].oracle = oracle;
        }
        emit YieldSourceOracleUpdated(source, oldOracle, oracle);
    }

    function _toggleYieldSourceActivation(address source, bool activate) internal {
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        if (activate) {
            if (yieldSource.isActive) revert YIELD_SOURCE_ALREADY_ACTIVE();
            yieldSource.isActive = true;
            if (asyncYieldSources[source].oracle != address(0)) asyncYieldSources[source].isActive = true;
            emit YieldSourceReactivated(source);
        } else {
            if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
            if (IYieldSourceOracle(yieldSource.oracle).getTVLByOwnerOfShares(source, address(this)) > 0) {
                revert INVALID_AMOUNT();
            }
            yieldSource.isActive = false;
            if (asyncYieldSources[source].oracle != address(0)) asyncYieldSources[source].isActive = false;
            emit YieldSourceDeactivated(source);
        }
    }

    function _proposeEmergencyWithdraw() internal onlyRole(EMERGENCY_ADMIN_ROLE) {
        proposedEmergencyWithdrawable = true;
        emergencyWithdrawableEffectiveTime = block.timestamp + ONE_WEEK;
        emit EmergencyWithdrawableProposed(true, emergencyWithdrawableEffectiveTime);
    }

    function _executeEmergencyWithdrawActivation() internal {
        if (block.timestamp < emergencyWithdrawableEffectiveTime) revert INVALID_TIMESTAMP();
        emergencyWithdrawable = proposedEmergencyWithdrawable;
        proposedEmergencyWithdrawable = false;
        emergencyWithdrawableEffectiveTime = 0;
        emit EmergencyWithdrawableUpdated(emergencyWithdrawable);
    }

    function _performEmergencyWithdraw(address recipient, uint256 amount) internal onlyRole(EMERGENCY_ADMIN_ROLE) {
        if (!emergencyWithdrawable) revert INVALID_EMERGENCY_WITHDRAWAL();
        if (recipient == address(0)) revert ZERO_ADDRESS();
        uint256 freeAssets = _getTokenBalance(address(_asset), address(this));
        if (amount == 0 || amount > freeAssets) revert INSUFFICIENT_FUNDS();
        _safeTokenTransfer(address(_asset), recipient, amount);
        emit EmergencyWithdrawal(recipient, amount);
    }

    function _isFulfillRequestsHook(address hook) private view returns (bool) {
        return superGovernor.isFulfillRequestsHookRegistered(hook);
    }

    function _decodeHookAmount(address hook, bytes memory hookCalldata) private pure returns (uint256 amount) {
        return ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);
    }

    function _decodeHookUsePrevHookAmount(address hook, bytes memory hookCalldata) private pure returns (bool) {
        try ISuperHookContextAware(hook).decodeUsePrevHookAmount(hookCalldata) returns (bool usePrevHookAmount) {
            return usePrevHookAmount;
        } catch {
            return false;
        }
    }

    function _getPreviousHookOutAmount(address prevHook) private view returns (uint256) {
        return ISuperHookResultOutflow(prevHook).outAmount();
    }

    function _getHookOutAmountAfterExecution(address hook) private view returns (uint256) {
        try ISuperHookResultOutflow(hook).outAmount() returns (uint256 outAmount) {
            return outAmount;
        } catch {
            return 0;
        }
    }

    function _onRedeemClaimable(
        address controller,
        uint256 assetsFulfilled,
        uint256 sharesFulfilled,
        uint256 averageWithdrawPrice,
        uint256 accumulatorShares,
        uint256 accumulatorCostBasis
    )
        private
    {
        ISuperVault(_vault).onRedeemClaimable(
            controller, assetsFulfilled, sharesFulfilled, averageWithdrawPrice, accumulatorShares, accumulatorCostBasis
        );
    }

    function _handleDeposit(address controller, uint256 assets, uint256 shares) private {
        if (assets == 0 || shares == 0) revert INVALID_AMOUNT();
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];
        state.accumulatorShares += shares;
        state.accumulatorCostBasis += assets;
        emit DepositHandled(controller, assets, shares);
    }

    function _handleRequestRedeem(address controller, uint256 shares) private {
        if (shares == 0) revert INVALID_AMOUNT();
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];
        if (state.pendingRedeemRequest > 0) revert ASYNC_REQUEST_BLOCKING();
        state.pendingRedeemRequest = shares;
        emit RedeemRequestPlaced(controller, controller, shares);
    }

    function _handleCancelRedeem(address controller) private {
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];
        uint256 pendingShares = state.pendingRedeemRequest;
        if (pendingShares == 0) revert REQUEST_NOT_FOUND();
        delete superVaultState[controller];
        emit RedeemRequestCanceled(controller, pendingShares);
    }

    function _handleClaimRedeem(address controller, uint256 assetsToClaim) private {
        if (assetsToClaim == 0) revert INVALID_AMOUNT();
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];
        if (state.maxWithdraw < assetsToClaim) revert INVALID_REDEEM_CLAIM();
        state.maxWithdraw -= assetsToClaim;
        emit RedeemRequestFulfilled(controller, controller, assetsToClaim, 0);
        if (state.maxWithdraw == 0 && state.pendingRedeemRequest == 0) {
            delete superVaultState[controller];
        }
    }

    function _safeTokenTransfer(address token, address recipient, uint256 amount) private {
        if (amount > 0) IERC20(token).safeTransfer(recipient, amount);
    }

    function _safeTokenTransferFrom(address token, address sender, address recipient, uint256 amount) private {
        if (amount > 0) IERC20(token).safeTransferFrom(sender, recipient, amount);
    }

    function _getTokenBalance(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    function _getSlippageTolerance() private pure returns (uint256) {
        return SV_SLIPPAGE_TOLERANCE_BPS;
    }

    function _requireVault() internal view {
        if (msg.sender != _vault) revert ACCESS_DENIED();
    }

    function _requireRole(bytes32 role) internal view {
        if (msg.sender != addresses[role]) revert ACCESS_DENIED();
    }
}
