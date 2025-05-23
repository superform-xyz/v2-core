// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

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
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../../core/interfaces/accounting/IYieldSourceOracle.sol";

// Periphery Interfaces
import { ISuperVault } from "../interfaces/ISuperVault.sol";
import { HookDataDecoder } from "../../core/libraries/HookDataDecoder.sol";
import { ISuperVaultStrategy } from "../interfaces/ISuperVaultStrategy.sol";
import { ISuperGovernor, FeeType } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/ISuperVaultAggregator.sol";

/// @title SuperVaultStrategy
/// @author Superform Labs
/// @notice Strategy implementation for SuperVault that executes strategies
contract SuperVaultStrategy is ISuperVaultStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant BPS_PRECISION = 10_000;
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
    uint256 private _maxPPSSlippage;

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
    // @dev todo whenever a new yield source is added we can move it to allowed target
    mapping(address source => YieldSource sourceConfig) private yieldSources;
    address[] private yieldSourcesList;

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
        _maxPPSSlippage = 500; // 5% as a start, configurable later

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
        if (args.globalProofs.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.strategyProofs.length != hooksLength) revert INVALID_ARRAY_LENGTH();

        address prevHook;
        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];
            if (!_isRegisteredHook(hook)) revert INVALID_HOOK();

            // Check if the hook was validated
            if (!_validateHook(hook, args.hookCalldata[i], args.globalProofs[i], args.strategyProofs[i])) {
                revert HOOK_VALIDATION_FAILED();
            }

            prevHook =
                _processSingleHookExecution(hook, prevHook, args.hookCalldata[i], args.expectedAssetsOrSharesOut[i]);
        }
        emit HooksExecuted(args.hooks);
    }

    /// @inheritdoc ISuperVaultStrategy
    function fulfillRedeemRequests(FulfillArgs calldata args) external nonReentrant {
        _isStrategist(msg.sender);

        // Check if strategy is paused
        if (_isPaused()) revert STRATEGY_PAUSED();

        uint256 hooksLength = args.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        uint256 controllersLength = args.controllers.length;
        if (controllersLength == 0) revert ZERO_LENGTH();
        if (args.expectedAssetsOrSharesOut.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.controllers.length != controllersLength) revert INVALID_ARRAY_LENGTH();
        if (args.globalProofs.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.strategyProofs.length != hooksLength) revert INVALID_ARRAY_LENGTH();

        uint256 processedShares;
        uint256 currentPPS = getStoredPPS();
        if (currentPPS == 0) revert INVALID_PPS();

        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];
            if (!_isFulfillRequestsHook(hook)) revert INVALID_HOOK();
            // Check if the hook was validated
            if (!_validateHook(hook, args.hookCalldata[i], args.globalProofs[i], args.strategyProofs[i])) {
                revert HOOK_VALIDATION_FAILED();
            }

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
    function manageYieldSource(address source, address oracle, uint8 actionType, bool activate) external {
        _isPrimaryStrategist(msg.sender);
        _manageYieldSource(source, oracle, actionType, activate);
    }

    // @inheritdoc ISuperVaultStrategy
    function manageYieldSources(
        address[] calldata sources,
        address[] calldata oracles,
        uint8[] calldata actionTypes,
        bool[] calldata activates
    )
        external
    {
        _isPrimaryStrategist(msg.sender);

        uint256 length = sources.length;
        if (length == 0) revert ZERO_LENGTH();
        if (oracles.length != length) revert INVALID_ARRAY_LENGTH();
        if (actionTypes.length != length) revert INVALID_ARRAY_LENGTH();
        if (activates.length != length) revert INVALID_ARRAY_LENGTH();

        for (uint256 i; i < length; ++i) {
            _manageYieldSource(sources[i], oracles[i], actionTypes[i], activates[i]);
        }
    }

    // @inheritdoc ISuperVaultStrategy
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external {
        _isPrimaryStrategist(msg.sender);
        if (performanceFeeBps > BPS_PRECISION) revert INVALID_PERFORMANCE_FEE_BPS();
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
    function updateMaxPPSSlippage(uint256 maxSlippageBps) external {
        _isPrimaryStrategist(msg.sender);
        if (maxSlippageBps > BPS_PRECISION) revert INVALID_MAX_SLIPPAGE_BPS();
        _maxPPSSlippage = maxSlippageBps;
        emit MaxPPSSlippageUpdated(maxSlippageBps);
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
    function getStoredPPS() public view returns (uint256) {
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

    // @inheritdoc ISuperVaultStrategy
    function previewPerformanceFee(
        address controller,
        uint256 sharesToRedeem
    )
        external
        view
        returns (uint256 totalFee, uint256 superformFee, uint256 recipientFee)
    {
        if (sharesToRedeem == 0) return (0, 0, 0);

        // Get controller's state
        SuperVaultState storage state = superVaultState[controller];

        // Check if controller has enough shares
        if (sharesToRedeem > state.accumulatorShares) return (0, 0, 0);

        // Get the current price per share
        uint256 currentPPS = getStoredPPS();

        // Calculate historical assets (cost basis)
        uint256 historicalAssets = 0;
        if (state.accumulatorShares > 0) {
            historicalAssets =
                sharesToRedeem.mulDiv(state.accumulatorCostBasis, state.accumulatorShares, Math.Rounding.Floor);
        }

        // Calculate current value of shares in asset terms
        uint256 currentAssetsWithFees = sharesToRedeem.mulDiv(currentPPS, PRECISION, Math.Rounding.Floor);

        // Calculate fee (if any) using same logic as _calculateAndTransferFee
        if (currentAssetsWithFees > historicalAssets) {
            uint256 profit = currentAssetsWithFees - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            totalFee = profit.mulDiv(performanceFeeBps, BPS_PRECISION, Math.Rounding.Floor);

            if (totalFee > 0) {
                // Calculate Superform's portion of the fee using revenueShare from SuperGovernor
                superformFee = totalFee.mulDiv(
                    superGovernor.getFee(FeeType.SUPER_VAULT_PERFORMANCE_FEE), BPS_PRECISION, Math.Rounding.Floor
                );
                recipientFee = totalFee - superformFee;
            }
        }

        return (totalFee, superformFee, recipientFee);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Process a single hook execution
    /// @param hook Hook address
    /// @param prevHook Previous hook address
    /// @param hookCalldata Hook calldata
    /// @param expectedAssetsOrSharesOut Expected assets or shares output
    /// @return processedHook Processed hook address
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

    /// @notice Process a single hook fulfillment execution
    /// @param hook Hook address
    /// @param hookCalldata Hook calldata
    /// @param expectedAssetOutput Expected asset output
    /// @param currentPPS Current price per share
    /// @return processedShares Processed shares
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

    /// @notice Process redeem fulfillments for multiple controllers
    /// @param controllers Array of controller addresses
    /// @param controllersLength Length of controllers array
    /// @param processedShares Total shares processed
    /// @param currentPPS Current price per share
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

            // Check for PPS slippage if there's a recorded request PPS and max slippage is set
            if (state.averageRequestPPS > 0 && _maxPPSSlippage > 0) {
                uint256 averageRequestPPS = state.averageRequestPPS;
                // Calculate the percentage decrease from request PPS to current PPS
                if (currentPPS < averageRequestPPS) {
                    uint256 decrease =
                        ((averageRequestPPS - currentPPS).mulDiv(BPS_PRECISION, averageRequestPPS, Math.Rounding.Floor));
                    // If decrease exceeds maximum allowed slippage, revert
                    if (decrease > _maxPPSSlippage) revert SLIPPAGE_EXCEEDED();
                }
            }

            uint256 currentAssets =
                _calculateHistoricalAssetsAndProcessFees(state, controllerRequestedAmount[i], currentPPS);

            // Update user state, no partial redeems allowed
            state.pendingRedeemRequest -= controllerRequestedAmount[i];
            state.maxWithdraw += currentAssets;
            state.averageRequestPPS = 0; // Reset PPS value after fulfillment

            // Call vault callback
            _onRedeemClaimable(
                controllers[i],
                currentAssets,
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
        returns (uint256 currentAssets)
    {
        // Calculate cost basis based on requested shares
        uint256 historicalAssets = _calculateCostBasis(state, requestedShares);
        uint256 currentAssetsWithFees;
        // Process fees and get final assets
        (currentAssetsWithFees, currentAssets) = _processFees(requestedShares, currentPricePerShare, historicalAssets);

        // Update average withdraw price if needed
        if (requestedShares > 0) {
            _updateAverageWithdrawPrice(state, requestedShares, currentAssetsWithFees);
        }

        return currentAssets;
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

    // --- Fee Processing ---
    /// @notice Calculate and transfer fees based on profit
    /// @param requestedShares Shares being redeemed
    /// @param currentPricePerShare Current price per share
    /// @param historicalAssets Historical value of shares in assets
    /// @return currentAssetsWithFees Current value of shares in assets (not net of fees)
    /// @return currentAssets Current assets after fee deduction
    function _processFees(
        uint256 requestedShares,
        uint256 currentPricePerShare,
        uint256 historicalAssets
    )
        private
        returns (uint256 currentAssetsWithFees, uint256 currentAssets)
    {
        // Calculate current value of the shares at current price
        currentAssetsWithFees = requestedShares.mulDiv(currentPricePerShare, PRECISION, Math.Rounding.Floor);

        // Apply fees only on profit
        currentAssets = _calculateAndTransferFee(currentAssetsWithFees, historicalAssets);

        // Ensure we don't exceed available balance
        uint256 balanceOfStrategy = _getTokenBalance(address(_asset), address(this));
        currentAssets = currentAssets > balanceOfStrategy ? balanceOfStrategy : currentAssets;

        return (currentAssetsWithFees, currentAssets);
    }

    /// @notice Calculate fee on profit and transfer to recipient
    /// @param currentAssetsWithFees Current value of shares in assets (not net of fees)
    /// @param historicalAssets Historical value of shares in assets
    /// @return currentAssets Current assets after fee deduction
    function _calculateAndTransferFee(
        uint256 currentAssetsWithFees,
        uint256 historicalAssets
    )
        private
        returns (uint256 currentAssets)
    {
        currentAssets = currentAssetsWithFees;
        if (currentAssetsWithFees > historicalAssets) {
            uint256 profit = currentAssetsWithFees - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, BPS_PRECISION, Math.Rounding.Floor);
            if (totalFee > 0) {
                // Calculate Superform's portion of the fee using revenueShare from SuperGovernor
                uint256 superformFee = totalFee.mulDiv(
                    superGovernor.getFee(FeeType.SUPER_VAULT_PERFORMANCE_FEE), BPS_PRECISION, Math.Rounding.Floor
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

    /// @notice Internal function to update the average withdraw price
    /// @param state Storage reference to the vault state
    /// @param requestedShares Number of shares requested
    /// @param currentAssetsWithFees Current assets with fees
    function _updateAverageWithdrawPrice(
        SuperVaultState storage state,
        uint256 requestedShares,
        uint256 currentAssetsWithFees
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
        uint256 newTotalAssets = existingAssets + currentAssetsWithFees;

        if (newTotalShares > 0) {
            state.averageWithdrawPrice = newTotalAssets.mulDiv(PRECISION, newTotalShares, Math.Rounding.Floor);
        }
    }

    /// @notice Internal function to get the SuperVaultAggregator
    /// @return The SuperVaultAggregator
    function _getSuperVaultAggregator() internal view returns (ISuperVaultAggregator) {
        address aggregatorAddress = superGovernor.getAddress(superGovernor.SUPER_VAULT_AGGREGATOR());

        return ISuperVaultAggregator(aggregatorAddress);
    }

    /// @notice Internal function to check if a strategist is authorized
    /// @param strategist_ The strategist to check
    function _isStrategist(address strategist_) internal view {
        if (!_getSuperVaultAggregator().isAnyStrategist(strategist_, address(this))) {
            revert STRATEGIST_NOT_AUTHORIZED();
        }
    }

    /// @notice Internal function to check if a strategist is the primary strategist
    /// @param strategist_ The strategist to check
    function _isPrimaryStrategist(address strategist_) internal view {
        if (!_getSuperVaultAggregator().isMainStrategist(strategist_, address(this))) {
            revert STRATEGIST_NOT_AUTHORIZED();
        }
    }

    /// @notice Internal function to manage a yield source
    /// @param source Address of the yield source
    /// @param oracle Address of the oracle
    /// @param actionType Type of action: 0=Add, 1=UpdateOracle, 2=ToggleActivation
    /// @param activate Boolean flag for activation when actionType is 2
    function _manageYieldSource(address source, address oracle, uint8 actionType, bool activate) internal {
        if (actionType == 0) {
            _addYieldSource(source, oracle);
        } else if (actionType == 1) {
            _updateYieldSourceOracle(source, oracle);
        } else if (actionType == 2) {
            _toggleYieldSourceActivation(source, activate);
        } else {
            revert ACTION_TYPE_DISALLOWED();
        }
    }

    /// @notice Internal function to add a yield source
    /// @param source Address of the yield source
    /// @param oracle Address of the oracle
    function _addYieldSource(address source, address oracle) internal {
        if (source == address(0) || oracle == address(0)) revert ZERO_ADDRESS();
        if (yieldSources[source].oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();
        yieldSources[source] = YieldSource({ oracle: oracle, isActive: true });
        yieldSourcesList.push(source);

        emit YieldSourceAdded(source, oracle);
    }

    /// @notice Internal function to update a yield source's oracle
    /// @param source Address of the yield source
    /// @param oracle Address of the oracle
    function _updateYieldSourceOracle(address source, address oracle) internal {
        if (oracle == address(0)) revert ZERO_ADDRESS();
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        address oldOracle = yieldSource.oracle;
        yieldSource.oracle = oracle;

        emit YieldSourceOracleUpdated(source, oldOracle, oracle);
    }

    /// @notice Internal function to toggle a yield source's activation
    /// @param source Address of the yield source
    /// @param activate Boolean flag for activation
    function _toggleYieldSourceActivation(address source, bool activate) internal {
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        if (activate) {
            if (yieldSource.isActive) revert YIELD_SOURCE_ALREADY_ACTIVE();
            yieldSource.isActive = true;
            emit YieldSourceReactivated(source);
        } else {
            if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_ACTIVE();
            if (IYieldSourceOracle(yieldSource.oracle).getTVLByOwnerOfShares(source, address(this)) > 0) {
                revert INVALID_AMOUNT();
            }
            yieldSource.isActive = false;
            emit YieldSourceDeactivated(source);
        }
    }

    /// @notice Internal function to propose an emergency withdraw
    function _proposeEmergencyWithdraw() internal {
        _isPrimaryStrategist(msg.sender);

        proposedEmergencyWithdrawable = true;
        emergencyWithdrawableEffectiveTime = block.timestamp + ONE_WEEK;
        emit EmergencyWithdrawableProposed(true, emergencyWithdrawableEffectiveTime);
    }

    /// @notice Internal function to execute an emergency withdraw
    function _executeEmergencyWithdrawActivation() internal {
        if (block.timestamp < emergencyWithdrawableEffectiveTime) revert INVALID_TIMESTAMP();
        emergencyWithdrawable = proposedEmergencyWithdrawable;
        proposedEmergencyWithdrawable = false;
        emergencyWithdrawableEffectiveTime = 0;
        emit EmergencyWithdrawableUpdated(emergencyWithdrawable);
    }

    /// @notice Internal function to perform an emergency withdraw
    /// @param recipient Address to receive the assets
    /// @param amount Amount of assets to withdraw
    function _performEmergencyWithdraw(address recipient, uint256 amount) internal {
        _isPrimaryStrategist(msg.sender);

        if (!emergencyWithdrawable) revert INVALID_EMERGENCY_WITHDRAWAL();
        if (recipient == address(0)) revert ZERO_ADDRESS();
        uint256 freeAssets = _getTokenBalance(address(_asset), address(this));
        if (amount == 0 || amount > freeAssets) revert INSUFFICIENT_FUNDS();
        _safeTokenTransfer(address(_asset), recipient, amount);
        emit EmergencyWithdrawal(recipient, amount);
    }

    /// @notice Internal function to check if a hook is a fulfill requests hook
    /// @param hook Address of the hook
    /// @return True if the hook is a fulfill requests hook, false otherwise
    function _isFulfillRequestsHook(address hook) private view returns (bool) {
        return superGovernor.isFulfillRequestsHookRegistered(hook);
    }

    /// @notice Internal function to check if a hook is registered
    /// @param hook Address of the hook
    /// @return True if the hook is registered, false otherwise
    function _isRegisteredHook(address hook) private view returns (bool) {
        return superGovernor.isHookRegistered(hook);
    }

    /// @notice Internal function to decode a hook's use previous hook amount
    /// @param hook Address of the hook
    /// @param hookCalldata Call data for the hook
    /// @return True if the hook should use the previous hook amount, false otherwise
    function _decodeHookUsePrevHookAmount(address hook, bytes memory hookCalldata) private pure returns (bool) {
        try ISuperHookContextAware(hook).decodeUsePrevHookAmount(hookCalldata) returns (bool usePrevHookAmount) {
            return usePrevHookAmount;
        } catch {
            return false;
        }
    }

    /// @notice Internal function to get the previous hook's output amount
    /// @param prevHook Address of the previous hook
    /// @return Output amount of the previous hook
    function _getPreviousHookOutAmount(address prevHook) private view returns (uint256) {
        return ISuperHookResultOutflow(prevHook).outAmount();
    }

    /// @notice Internal function to handle a redeem claimable
    /// @param controller Address of the controller
    /// @param assetsFulfilled Amount of assets fulfilled
    /// @param sharesFulfilled Amount of shares fulfilled
    /// @param averageWithdrawPrice Average withdraw price
    /// @param accumulatorShares Accumulator shares
    /// @param accumulatorCostBasis Accumulator cost basis
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

    /// @notice Internal function to handle a deposit
    /// @param controller Address of the controller
    /// @param assets Amount of assets
    /// @param shares Amount of shares
    function _handleDeposit(address controller, uint256 assets, uint256 shares) private {
        if (assets == 0 || shares == 0) revert INVALID_AMOUNT();
        if (controller == address(0)) revert ZERO_ADDRESS();

        // Check if strategy is paused or if global hooks root is vetoed
        if (_isPaused()) revert STRATEGY_PAUSED();
        if (_getSuperVaultAggregator().isGlobalHooksRootVetoed()) {
            revert OPERATIONS_BLOCKED_BY_VETO();
        }

        SuperVaultState storage state = superVaultState[controller];
        state.accumulatorShares += shares;
        state.accumulatorCostBasis += assets;
        emit DepositHandled(controller, assets, shares);
    }

    /// @notice Internal function to handle a redeem
    /// @param controller Address of the controller
    /// @param shares Amount of shares
    function _handleRequestRedeem(address controller, uint256 shares) private {
        if (shares == 0) revert INVALID_AMOUNT();
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];

        // Get current PPS from aggregator to use as baseline for slippage protection
        uint256 currentPPS = getStoredPPS();
        if (currentPPS == 0) revert INVALID_PPS();

        // Calculate weighted average of PPS if there's an existing request
        if (state.pendingRedeemRequest > 0) {
            // Calculate weighted average of PPS based on share amounts
            uint256 existingSharesInRequest = state.pendingRedeemRequest;
            uint256 newTotalSharesInRequest = existingSharesInRequest + shares;

            // Use weighted average formula: (existingShares * existingPPS + newShares * currentPPS) / totalShares
            state.averageRequestPPS =
                ((existingSharesInRequest * state.averageRequestPPS) + (shares * currentPPS)) / newTotalSharesInRequest;

            // Update total shares
            state.pendingRedeemRequest = newTotalSharesInRequest;
        } else {
            // First request for this controller
            state.pendingRedeemRequest = shares;
            state.averageRequestPPS = currentPPS;
        }

        emit RedeemRequestPlaced(controller, controller, shares);
    }

    /// @notice Internal function to handle a redeem cancellation
    /// @param controller Address of the controller
    function _handleCancelRedeem(address controller) private {
        if (controller == address(0)) revert ZERO_ADDRESS();
        SuperVaultState storage state = superVaultState[controller];
        uint256 pendingShares = state.pendingRedeemRequest;
        if (pendingShares == 0) revert REQUEST_NOT_FOUND();
        delete superVaultState[controller];
        emit RedeemRequestCanceled(controller, pendingShares);
    }

    /// @notice Internal function to handle a redeem claim
    /// @param controller Address of the controller
    /// @param assetsToClaim Amount of assets to claim
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

    /// @notice Internal function to safely transfer tokens
    /// @param token Address of the token
    /// @param recipient Address to receive the tokens
    /// @param amount Amount of tokens to transfer
    function _safeTokenTransfer(address token, address recipient, uint256 amount) private {
        if (amount > 0) IERC20(token).safeTransfer(recipient, amount);
    }

    /// @notice Internal function to get the token balance of an account
    /// @param token Address of the token
    /// @param account Address of the account
    /// @return Token balance of the account
    function _getTokenBalance(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    /// @notice Internal function to get the slippage tolerance
    /// @return Slippage tolerance
    function _getSlippageTolerance() private pure returns (uint256) {
        return SV_SLIPPAGE_TOLERANCE_BPS;
    }

    /// @notice Internal function to check if the caller is the vault
    /// @dev This is used to prevent unauthorized access to certain functions
    function _requireVault() internal view {
        if (msg.sender != _vault) revert ACCESS_DENIED();
    }

    /// @notice Checks if the strategy is currently paused
    /// @dev This calls SuperVaultAggregator.isStrategyPaused to determine pause status
    /// @return True if the strategy is paused, false otherwise
    function _isPaused() internal view returns (bool) {
        return _getSuperVaultAggregator().isStrategyPaused(address(this));
    }

    /// @notice Validates a hook using the Merkle root system
    /// @param hook Address of the hook to validate
    /// @param hookCalldata Calldata to be passed to the hook
    /// @param globalProof Merkle proof for the global root
    /// @param strategyProof Merkle proof for the strategy-specific root
    /// @return isValid True if the hook is valid, false otherwise
    function _validateHook(
        address hook,
        bytes memory hookCalldata,
        bytes32[] memory globalProof,
        bytes32[] memory strategyProof
    )
        internal
        view
        returns (bool)
    {
        return _getSuperVaultAggregator().validateHook(
            address(this), ISuperHookInspector(hook).inspect(hookCalldata), globalProof, strategyProof
        );
    }
}
