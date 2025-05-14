// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Core Interfaces
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookOutflow,
    ISuperHookInflowOutflow,
    ISuperHookResultOutflow,
    ISuperHookContextAware
} from "../../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../../core/interfaces/accounting/IYieldSourceOracle.sol";

// Periphery Interfaces
import { ISuperVault } from "../interfaces/ISuperVault.sol";
import { HookDataDecoder } from "../../core/libraries/HookDataDecoder.sol";
import { ISuperVaultStrategy } from "../interfaces/ISuperVaultStrategy.sol";
import { ISuperGovernor, FeeType } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/ISuperVaultAggregator.sol";
import { console2 } from "forge-std/console2.sol";

/// @title SuperVaultStrategy
/// @author Superform Labs
/// @notice Strategy implementation for SuperVault that executes strategies
contract SuperVaultStrategy is ISuperVaultStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant BPS_PRECISION = 10_000; // For PPS deviation check
    uint256 private constant TOLERANCE_CONSTANT = 10 wei;

    // Slippage tolerance in BPS (1%)
    uint256 private constant SV_SLIPPAGE_TOLERANCE_BPS = 100;

    uint256 public PRECISION;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool private _initialized;
    address private _vault;
    IERC20 private _asset;
    uint8 private _vaultDecimals;

    // Global configuration

    // Fee configuration
    FeeConfig private feeConfig;
    FeeConfig private proposedFeeConfig;
    uint256 private feeConfigEffectiveTime;

    // Core contracts
    ISuperGovernor private superGovernor;

    // Emergency withdrawable configuration
    bool public emergencyWithdrawable;
    bool public proposedEmergencyWithdrawable;
    uint256 public emergencyWithdrawableEffectiveTime;

    // Yield source configuration
    mapping(address source => YieldSource sourceConfig) private yieldSources;
    mapping(address source => YieldSource sourceConfig) private asyncYieldSources;
    address[] private yieldSourcesList;
    address[] private asyncYieldSourcesList;

    // PPS is now managed by SuperVaultAggregator

    // --- Redeem Request State ---
    mapping(address controller => SuperVaultState state) private superVaultState;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(address vault_, address superGovernor_, FeeConfig memory feeConfig_) external {
        if (_initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();
        if (feeConfig.performanceFeeBps > 0 && feeConfig.recipient == address(0)) revert ZERO_ADDRESS();

        _initialized = true;
        _vault = vault_;
        _asset = IERC20(IERC4626(vault_).asset());
        _vaultDecimals = IERC20Metadata(vault_).decimals();
        PRECISION = 10 ** _vaultDecimals;
        superGovernor = ISuperGovernor(superGovernor_);
        feeConfig = feeConfig_;

        emit Initialized(_vault, superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE STRATEGY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultStrategy
    function handleOperation(address controller, uint256 assets, uint256 shares, Operation operation) external {
        _requireVault();

        if (operation == Operation.Deposit) {
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
        _isStrategist(msg.sender);

        uint256 hooksLength = args.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (args.expectedAssetsOrSharesOut.length != hooksLength) revert INVALID_ARRAY_LENGTH();

        address prevHook;

        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];
            if (!_isRegisteredHook(hook)) revert INVALID_HOOK();
            prevHook =
                _processSingleHookExecution(hook, prevHook, args.hookCalldata[i], args.expectedAssetsOrSharesOut[i]);
        }
        emit HooksExecuted(args.hooks);
    }

    /// @inheritdoc ISuperVaultStrategy
    function fulfillRedeemRequests(FulfillArgs calldata args) external nonReentrant {
        _isStrategist(msg.sender);

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

    // @inheritdoc ISuperVaultStrategy
    function manageYieldSource(
        address source,
        address oracle,
        uint8 actionType,
        bool activate,
        bool isAsync
    )
        external
    {
        _isPrimaryStrategist(msg.sender);
        _manageYieldSource(source, oracle, actionType, activate, isAsync);
    }

    // @inheritdoc ISuperVaultStrategy
    function manageYieldSources(
        address[] calldata sources,
        address[] calldata oracles,
        uint8[] calldata actionTypes,
        bool[] calldata activates,
        bool[] calldata isAsyncs
    )
        external
    {
        _isPrimaryStrategist(msg.sender);

        uint256 length = sources.length;
        if (length == 0) revert ZERO_LENGTH();
        if (oracles.length != length) revert INVALID_ARRAY_LENGTH();
        if (actionTypes.length != length) revert INVALID_ARRAY_LENGTH();
        if (activates.length != length) revert INVALID_ARRAY_LENGTH();
        if (isAsyncs.length != length) revert INVALID_ARRAY_LENGTH();

        for (uint256 i; i < length; ++i) {
            _manageYieldSource(sources[i], oracles[i], actionTypes[i], activates[i], isAsyncs[i]);
        }
    }

    // @inheritdoc ISuperVaultStrategy
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external {
        _isPrimaryStrategist(msg.sender);
        if (performanceFeeBps > ONE_HUNDRED_PERCENT) revert INVALID_PERFORMANCE_FEE_BPS();
        if (recipient == address(0)) revert ZERO_ADDRESS();
        proposedFeeConfig = FeeConfig({ performanceFeeBps: performanceFeeBps, recipient: recipient });
        feeConfigEffectiveTime = block.timestamp + ONE_WEEK;
        emit VaultFeeConfigProposed(performanceFeeBps, recipient, feeConfigEffectiveTime);
    }

    // @inheritdoc ISuperVaultStrategy
    function executeVaultFeeConfigUpdate() external {
        if (block.timestamp < feeConfigEffectiveTime) revert INVALID_TIMESTAMP();
        if (proposedFeeConfig.recipient == address(0)) revert ZERO_ADDRESS();
        feeConfig = proposedFeeConfig;
        delete proposedFeeConfig;
        feeConfigEffectiveTime = 0;
        emit VaultFeeConfigUpdated(feeConfig.performanceFeeBps, feeConfig.recipient);
    }

    // @inheritdoc ISuperVaultStrategy
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

    // @inheritdoc ISuperVaultStrategy
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    // @inheritdoc ISuperVaultStrategy
    function getVaultInfo() external view returns (address vault_, address asset_, uint8 vaultDecimals_) {
        vault_ = _vault;
        asset_ = address(_asset);
        vaultDecimals_ = _vaultDecimals;
    }

    // @inheritdoc ISuperVaultStrategy
    function getConfigInfo() external view returns (FeeConfig memory feeConfig_) {
        feeConfig_ = feeConfig;
    }

    // @inheritdoc ISuperVaultStrategy
    function getStoredPPS() external view returns (uint256) {
        return _getSuperVaultAggregator().getPPS(address(this));
    }

    // @inheritdoc ISuperVaultStrategy
    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }

    // @inheritdoc ISuperVaultStrategy
    function getYieldSourcesList() external view returns (YieldSourceInfo[] memory) {
        uint256 length = yieldSourcesList.length;
        YieldSourceInfo[] memory sourcesInfo = new YieldSourceInfo[](length);

        for (uint256 i; i < length; ++i) {
            address sourceAddress = yieldSourcesList[i];
            YieldSource memory source = yieldSources[sourceAddress];

            sourcesInfo[i] =
                YieldSourceInfo({ sourceAddress: sourceAddress, oracle: source.oracle, isActive: source.isActive });
        }

        return sourcesInfo;
    }

    // @inheritdoc ISuperVaultStrategy
    function pendingRedeemRequest(address controller) external view returns (uint256 pendingShares) {
        return superVaultState[controller].pendingRedeemRequest;
    }

    // @inheritdoc ISuperVaultStrategy
    function claimableWithdraw(address controller) external view returns (uint256 claimableAssets) {
        return superVaultState[controller].maxWithdraw;
    }

    // @inheritdoc ISuperVaultStrategy
    function getAverageWithdrawPrice(address controller) external view returns (uint256 averageWithdrawPrice) {
        return superVaultState[controller].averageWithdrawPrice;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
            _updateAverageWithdrawPrice(state, requestedShares, finalAssets, currentPricePerShare);
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
        uint256 finalAssets,
        uint256 pps
    )
        private
    {
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
                //console2.log("newTotalAssets", newTotalAssets);
                //console2.log("newTotalShares", newTotalShares);
                //state.averageWithdrawPrice = newTotalAssets.mulDiv(PRECISION, newTotalShares, Math.Rounding.Floor);
                console2.log(
                    "AVG WITHDRAW PRICE WITH FEES ",
                    newTotalAssets.mulDiv(PRECISION, newTotalShares, Math.Rounding.Floor)
                );
                //state.averageWithdrawPrice = pps;
            }
        }
        // Handle first withdrawal case
        if (state.maxWithdraw == 0 || state.averageWithdrawPrice == 0) {
            state.averageWithdrawPrice = pps;
            return;
        }

        // Calculate previous state before this request
        uint256 previousMaxWithdraw = state.maxWithdraw - finalAssets;
        uint256 previousShares = 0;
        if (previousMaxWithdraw > 0 && state.averageWithdrawPrice > 0) {
            previousShares = previousMaxWithdraw.mulDiv(PRECISION, state.averageWithdrawPrice, Math.Rounding.Floor);
        }

        // Calculate new weighted average
        uint256 totalShares = previousShares + requestedShares;
        console2.log("Previous MaxWithdraw:", previousMaxWithdraw);
        console2.log("Previous Shares:", previousShares);
        console2.log("Requested Shares:", requestedShares);
        console2.log("Total Shares:", totalShares);
        console2.log("Previous PPS:", state.averageWithdrawPrice);
        console2.log("New PPS:", pps);
        if (totalShares > 0) {
            // Weight by shares
            uint256 weightedPrice = (
                (previousShares.mulDiv(state.averageWithdrawPrice, PRECISION, Math.Rounding.Floor))
                    + (requestedShares.mulDiv(pps, PRECISION, Math.Rounding.Floor))
            ).mulDiv(PRECISION, totalShares, Math.Rounding.Floor);

            // Log for debugging

            console2.log("Weighted PPS:", weightedPrice);

            state.averageWithdrawPrice = weightedPrice;
        }
    }

    // --- End Hook Execution ---

    // --- Internal Strategist Check Helpers ---

    function _getSuperVaultAggregator() internal view returns (ISuperVaultAggregator) {
        address aggregatorAddress = superGovernor.getAddress(superGovernor.SUPER_VAULT_AGGREGATOR());

        return ISuperVaultAggregator(aggregatorAddress);
    }

    function _isStrategist(address strategist_) internal view {
        if (!_getSuperVaultAggregator().isAnyStrategist(strategist_, address(this))) {
            revert STRATEGIST_NOT_AUTHORIZED();
        }
    }

    function _isPrimaryStrategist(address strategist_) internal view {
        if (!_getSuperVaultAggregator().isMainStrategist(strategist_, address(this))) {
            revert STRATEGIST_NOT_AUTHORIZED();
        }
    }

    // --- End Internal Strategist Check Helpers ---

    /// @notice Internal function to manage a yield source
    /// @param source Address of the yield source
    /// @param oracle Address of the oracle
    /// @param actionType Type of action: 0=Add, 1=UpdateOracle, 2=ToggleActivation
    /// @param activate Boolean flag for activation when actionType is 2
    /// @param isAsync Boolean flag for async yield source
    function _manageYieldSource(
        address source,
        address oracle,
        uint8 actionType,
        bool activate,
        bool isAsync
    )
        internal
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

    function _proposeEmergencyWithdraw() internal {
        _isPrimaryStrategist(msg.sender);

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

    function _performEmergencyWithdraw(address recipient, uint256 amount) internal {
        _isPrimaryStrategist(msg.sender);

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

    function _isRegisteredHook(address hook) private view returns (bool) {
        return superGovernor.isHookRegistered(hook);
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

        // Handle dust collection for rounding errors
        uint256 actualAmountToClaim = assetsToClaim;
        uint256 remainingAssets = _asset.balanceOf(address(this));

        // If user is requesting slightly more than available due to rounding errors,
        // and the difference is small (dust), give them the remaining balance
        if (assetsToClaim > remainingAssets && assetsToClaim - remainingAssets <= TOLERANCE_CONSTANT) {
            actualAmountToClaim = remainingAssets;
        }

        if (state.maxWithdraw < actualAmountToClaim) revert INVALID_REDEEM_CLAIM();
        state.maxWithdraw -= actualAmountToClaim;
        _asset.safeTransfer(controller, actualAmountToClaim);
        emit RedeemRequestFulfilled(controller, controller, actualAmountToClaim, 0);
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
}
