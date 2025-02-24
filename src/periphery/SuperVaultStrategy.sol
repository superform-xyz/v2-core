// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { console2 } from "forge-std/console2.sol";

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
import { ISuperRegistry } from "../core/interfaces/ISuperRegistry.sol";

import { HookDataDecoder } from "../core/libraries/HookDataDecoder.sol";

/// @title SuperVaultStrategy
/// @notice Strategy implementation for SuperVault that manages yield sources and executes strategies
/// @author SuperForm Labs
contract SuperVaultStrategy is ISuperVaultStrategy {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint256 private constant ONE_WEEK = 7 days;

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

    ISuperRegistry private superRegistry;

    function _requireVault() internal view {
        if (msg.sender != _vault) revert UNAUTHORIZED();
    }

    /// @dev MANAGER_ROLE, STRATEGIST_ROLE, EMERGENCY_ADMIN_ROLE
    function _requireRole(bytes32 role) internal view {
        if (msg.sender != addresses[role]) revert UNAUTHORIZED();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address vault_,
        address manager_,
        address strategist_,
        address emergencyAdmin_,
        address superRegistry_,
        GlobalConfig memory config_
    )
        external
    {
        if (_initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (superRegistry_ == address(0)) revert INVALID_SUPER_REGISTRY();
        if (config_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config_.maxAllocationRate == 0 || config_.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_ALLOCATION_RATE();
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
        superRegistry = ISuperRegistry(superRegistry_);
        globalConfig = config_;
    }

    /*//////////////////////////////////////////////////////////////
                        REQUEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultStrategy
    function handleOperation(address controller, uint256 amount, Operation operation) external {
        if (operation == Operation.DepositRequest) {
            _handleRequestDeposit(controller, amount);
        } else if (operation == Operation.CancelDeposit) {
            _handleCancelDeposit(controller, amount);
        } else if (operation == Operation.ClaimDeposit) {
            _handleClaimDeposit(controller, amount);
        } else if (operation == Operation.RedeemRequest) {
            _handleRequestRedeem(controller, amount);
        } else if (operation == Operation.CancelRedeem) {
            _handleCancelRedeem(controller);
        } else if (operation == Operation.ClaimRedeem) {
            _handleClaimWithdraw(controller, amount);
        } else {
            revert UNAUTHORIZED();
        }
    }

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fulfillDepositRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] memory hookCalldata
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();
        uint256 hooksLength = hooks.length;

        _validateHooksArrays(hooksLength, hookProofs.length, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and get total assets
        vars.totalRequestedAmount = _validateRequests(usersLength, users, true);

        // Check we have enough free assets to fulfill these requests
        vars.availableAmount = _asset.balanceOf(address(this));
        if (vars.availableAmount < vars.totalRequestedAmount) revert INVALID_AMOUNT();

        // Process hooks and get targeted yield sources
        address[] memory targetedYieldSources;
        (vars, targetedYieldSources) = _processHooks(hooks, hookProofs, hookCalldata, vars, true);

        // Check vault caps after all hooks are processed
        _checkVaultCaps(targetedYieldSources);

        vars.pricePerShare = getSuperVaultPPS();

        // Update accounting for each user
        for (uint256 i; i < usersLength;) {
            address user = users[i];
            SuperVaultState storage state = superVaultState[user];
            vars.requestedAmount = state.pendingDepositRequest;

            // Calculate user's share of total shares
            vars.shares = vars.requestedAmount.mulDiv(10 ** _vaultDecimals, vars.pricePerShare);

            // Calculate new weighted average deposit price
            uint256 newTotalAssets = vars.requestedAmount; // New assets being added
            uint256 newTotalShares = vars.shares; // New shares being minted

            if (state.maxMint > 0) {
                // Add existing assets and shares to calculation
                newTotalAssets += state.maxMint.mulDiv(state.averageDepositPrice, 1e18, Math.Rounding.Floor);
                newTotalShares += state.maxMint;
            }

            // Update average deposit price
            if (newTotalShares > 0) {
                state.averageDepositPrice = newTotalAssets.mulDiv(1e18, newTotalShares, Math.Rounding.Floor);
            }

            // Add new share price point
            state.sharePricePoints.push(SharePricePoint({ shares: vars.shares, pricePerShare: vars.pricePerShare }));

            // Move request to claimable state
            state.pendingDepositRequest = 0;

            state.maxMint += vars.shares;

            // Mint shares to escrow
            ISuperVault(_vault).mintShares(vars.shares);

            // Call vault callback instead of emitting event directly
            ISuperVault(_vault).onDepositClaimable(user, vars.requestedAmount, vars.shares);

            unchecked {
                ++i;
            }
        }
    }

    function fulfillRedeemRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();
        uint256 hooksLength = hooks.length;

        _validateHooksArrays(hooksLength, hookProofs.length, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and get total shares
        vars.totalRequestedAmount = _validateRequests(usersLength, users, false);

        // Process hooks
        address[] memory targetedYieldSources;
        (vars, targetedYieldSources) = _processHooks(hooks, hookProofs, hookCalldata, vars, false);

        vars.pricePerShare = getSuperVaultPPS();

        // Update accounting for each user
        for (uint256 i; i < usersLength;) {
            address user = users[i];
            SuperVaultState storage state = superVaultState[user];

            // Get the shares this user requested to redeem
            vars.requestedAmount = state.pendingRedeemRequest;

            // Calculate historical assets and process fees
            uint256 lastConsumedIndex;
            uint256 finalAssets;
            (finalAssets, lastConsumedIndex) =
                _calculateHistoricalAssetsAndProcessFees(state, vars.requestedAmount, vars.pricePerShare);

            // Update share price point cursor
            state.sharePricePointCursor = lastConsumedIndex;

            // Move request to claimable state
            state.pendingRedeemRequest = 0;
            state.maxWithdraw += finalAssets;

            // Call vault callback instead of emitting event directly
            ISuperVault(_vault).onRedeemClaimable(user, finalAssets, vars.requestedAmount);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Match redeem requests with deposit requests directly, without accessing yield sources
    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external {
        _requireRole(STRATEGIST_ROLE);
        uint256 redeemLength = redeemUsers.length;
        uint256 depositLength = depositUsers.length;
        if (redeemLength == 0 || depositLength == 0) revert ZERO_LENGTH();

        MatchVars memory vars;
        vars.currentPricePerShare = getSuperVaultPPS();

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
            vars.sharesNeeded = vars.depositAssets.mulDiv(10 ** _vaultDecimals, vars.currentPricePerShare);
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
            ISuperVault(_vault).onDepositClaimable(depositor, vars.depositAssets, vars.sharesNeeded);

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
                ISuperVault(_vault).onRedeemClaimable(redeemer, vars.finalAssets, sharesUsed);
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
            vars.amount = ISuperHookInflowOutflow(hooks[i]).decodeAmount(hookCalldata[i]);

            // Validate target is an active yield source
            YieldSource storage source = yieldSources[vars.executions[0].target];
            if (!source.isActive) revert INVALID_YIELD_SOURCE();

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
                    (currentYieldSourceAssets + vars.amount).mulDiv(ONE_HUNDRED_PERCENT, totalAssets_)
                        > globalConfig.maxAllocationRate
                ) {
                    revert MAX_ALLOCATION_RATE_EXCEEDED();
                }

                // Track inflow target
                inflowTargets[inflowCount++] = vars.executions[0].target;

                // Approve spending
                _asset.safeIncreaseAllowance(vars.executions[0].target, vars.amount);
            }

            // Execute the transaction
            (bool success,) =
                vars.executions[0].target.call{ value: vars.executions[0].value }(vars.executions[0].callData);
            if (!success) revert EXECUTION_FAILED();

            // Reset approval if it was an inflow
            if (vars.hookType == ISuperHook.HookType.INFLOW) {
                _asset.forceApprove(vars.executions[0].target, 0);
            }

            // Update prevHook for next iteration
            vars.prevHook = hooks[i];

            unchecked {
                ++i;
            }
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
    function claimAndCompound(
        address[][] calldata hooks,
        bytes32[][] calldata claimHookProofs,
        bytes32[][] calldata swapHookProofs,
        bytes32[][] calldata allocateHookProofs,
        bytes[][] calldata hookCalldata,
        address[] calldata expectedTokensOut
    )
        external
    {
        _requireRole(STRATEGIST_ROLE);

        // Validate overall hook sets
        _validateHookSets(hooks, hookCalldata, 3); // Must have exactly 3 arrays: claim, swap, allocate
        if (expectedTokensOut.length == 0) revert ZERO_LENGTH();

        // Validate individual hook arrays
        _validateHookArrayLengths(hooks[0], claimHookProofs, hookCalldata[0]);
        _validateHookArrayLengths(hooks[1], swapHookProofs, hookCalldata[1]);
        _validateHookArrayLengths(hooks[2], allocateHookProofs, hookCalldata[2]);

        ClaimLocalVars memory vars;

        // Get initial asset balance
        vars.initialAssetBalance = _asset.balanceOf(address(this));

        // Step 1: Execute claim hooks and get balance changes
        vars.balanceChanges = _processClaimHookExecution(hooks[0], claimHookProofs, hookCalldata[0], expectedTokensOut);

        // Step 2: Execute swap hooks and get asset gained
        vars.assetGained = _processSwapHookExecution(
            hooks[1], swapHookProofs, hookCalldata[1], expectedTokensOut, vars.balanceChanges, vars.initialAssetBalance
        );

        // Step 3: Execute inflow hooks to allocate gained assets
        // assume requested amount is the asset gain
        vars.fulfillmentVars.totalRequestedAmount = vars.assetGained;

        (vars.fulfillmentVars, vars.targetedYieldSources) =
            _processHooks(hooks[2], allocateHookProofs, hookCalldata[2], vars.fulfillmentVars, true);

        // Check vault caps after all hooks are processed
        _checkVaultCaps(vars.targetedYieldSources);

        // Verify all assets were allocated
        if (vars.fulfillmentVars.spentAmount != vars.assetGained) revert INVALID_ASSET_BALANCE();

        emit RewardsClaimedAndCompounded(vars.assetGained);
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
        vars.initialAssetBalance = _asset.balanceOf(address(this));

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
        if (vars.fulfillmentVars.spentAmount != vars.assetGained) revert INVALID_ASSET_BALANCE();

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
    function getSuperVaultPPS() public view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = totalSupply();

        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in vault decimals
            pricePerShare = 10 ** _vaultDecimals;
        } else {
            // Calculate current PPS
            (uint256 totalAssets_,) = totalAssets();
            pricePerShare = totalAssets_.mulDiv(10 ** _vaultDecimals, totalSupplyAmount);
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function totalSupply() public view returns (uint256) {
        return IERC4626(_vault).totalSupply();
    }

    /// @inheritdoc ISuperVaultStrategy
    function totalAssets() public view returns (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs) {
        // Initialize array with length of yield sources list
        uint256 length = yieldSourcesList.length;
        sourceTVLs = new YieldSourceTVL[](length);
        uint256 activeSourceCount;

        // Start with idle assets
        totalAssets_ = _asset.balanceOf(address(this));

        // Sum up value in yield sources and track TVL per source
        for (uint256 i; i < length;) {
            address source = yieldSourcesList[i];
            if (yieldSources[source].isActive) {
                uint256 tvl =
                    IYieldSourceOracle(yieldSources[source].oracle).getTVLByOwnerOfShares(source, address(this));
                totalAssets_ += tvl;
                sourceTVLs[activeSourceCount++] = YieldSourceTVL({ source: source, tvl: tvl });
            }
            unchecked {
                ++i;
            }
        }

        // Resize array to actual count if needed
        if (activeSourceCount < length) {
            assembly {
                mstore(sourceTVLs, activeSourceCount)
            }
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function maxMint(address owner) public view returns (uint256) {
        return superVaultState[owner].maxMint;
    }

    /// @inheritdoc ISuperVaultStrategy
    function maxWithdraw(address owner) public view returns (uint256) {
        return superVaultState[owner].maxWithdraw;
    }

    /// @inheritdoc ISuperVaultStrategy
    function getAverageDepositPrice(address owner) external view returns (uint256) {
        return superVaultState[owner].averageDepositPrice;
    }

    /// @inheritdoc ISuperVaultStrategy
    function getAverageWithdrawPrice(address owner) external view returns (uint256) {
        return superVaultState[owner].averageWithdrawPrice;
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Add a new yield source to the system
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function addYieldSource(address source, address oracle) external {
        _requireRole(MANAGER_ROLE);
        if (source == address(0)) revert INVALID_YIELD_SOURCE();
        if (oracle == address(0)) revert INVALID_ORACLE();
        if (yieldSources[source].oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

        // Check vault threshold
        if (IERC4626(source).totalAssets() < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

        // Add yield source
        yieldSources[source] = YieldSource({ oracle: oracle, isActive: true });
        yieldSourcesList.push(source);

        emit YieldSourceAdded(source, oracle);
    }

    /// @notice Update oracle for an existing yield source
    /// @param source Address of the yield source
    /// @param newOracle Address of the new oracle
    function updateYieldSourceOracle(address source, address newOracle) external {
        _requireRole(MANAGER_ROLE);
        if (newOracle == address(0)) revert INVALID_ORACLE();
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        address oldOracle = yieldSource.oracle;
        yieldSource.oracle = newOracle;

        emit YieldSourceOracleUpdated(source, oldOracle, newOracle);
    }

    /// @inheritdoc ISuperVaultStrategy
    function toggleYieldSource(address source, bool activate) external {
        _requireRole(MANAGER_ROLE);
        YieldSource storage yieldSource = yieldSources[source];
        if (activate) {
            if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
            if (yieldSource.isActive) revert YIELD_SOURCE_ALREADY_EXISTS();

            // Check vault threshold
            if (IERC4626(source).totalAssets() < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

            yieldSource.isActive = true;
            emit YieldSourceReactivated(source);
        } else {
            if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_FOUND();

            // Check no assets are allocated to this source
            uint256 sourceShares = IERC4626(source).balanceOf(address(this));
            if (sourceShares > 0) revert INVALID_YIELD_SOURCE();

            yieldSource.isActive = false;
            emit YieldSourceDeactivated(source);
        }
    }

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external {
        _requireRole(MANAGER_ROLE);
        if (config.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config.maxAllocationRate == 0 || config.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_ALLOCATION_RATE();
        }
        if (config.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        globalConfig = config;
        emit GlobalConfigUpdated(config.vaultCap, config.superVaultCap, config.maxAllocationRate, config.vaultThreshold);
    }

    /// @inheritdoc ISuperVaultStrategy
    function proposeOrExecuteHookRoot(bytes32 newRoot) external {
        if (newRoot == bytes32(0)) {
            // execute hook root update
            if (block.timestamp < hookRootEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
            if (proposedHookRoot == bytes32(0)) revert INVALID_HOOK_ROOT();
            hookRoot = proposedHookRoot;
            proposedHookRoot = bytes32(0);
            hookRootEffectiveTime = 0;
            emit HookRootUpdated(hookRoot);
        } else {
            // propose new hook
            _requireRole(MANAGER_ROLE);
            proposedHookRoot = newRoot;
            hookRootEffectiveTime = block.timestamp + ONE_WEEK;
            emit HookRootProposed(newRoot, hookRootEffectiveTime);
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function proposeVaultFeeConfigUpdate(uint256 performanceFeeBps, address recipient) external {
        _requireRole(MANAGER_ROLE);

        if (performanceFeeBps > ONE_HUNDRED_PERCENT) revert INVALID_FEE();
        if (recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        proposedFeeConfig = FeeConfig({ performanceFeeBps: performanceFeeBps, recipient: recipient });
        feeConfigEffectiveTime = block.timestamp + ONE_WEEK;

        emit VaultFeeConfigProposed(performanceFeeBps, recipient, feeConfigEffectiveTime);
    }

    /// @inheritdoc ISuperVaultStrategy
    function executeVaultFeeConfigUpdate() external {
        if (block.timestamp < feeConfigEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
        if (proposedFeeConfig.recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        feeConfig = proposedFeeConfig;
        delete proposedFeeConfig;
        feeConfigEffectiveTime = 0;

        emit VaultFeeConfigUpdated(feeConfig.performanceFeeBps, feeConfig.recipient);
    }

    /// @notice Set an address for a given role
    /// @dev Only callable by MANAGER role. Cannot set address(0) or remove MANAGER role from themselves
    /// @param role The role identifier
    /// @param account The address to set for the role
    function setAddress(bytes32 role, address account) external {
        _requireRole(MANAGER_ROLE);
        // Prevent setting zero address
        if (account == address(0)) revert ZERO_ADDRESS();

        // Prevent manager from changing themselves
        if (role == MANAGER_ROLE && account != msg.sender) revert UNAUTHORIZED();

        addresses[role] = account;
    }

    /// @inheritdoc ISuperVaultStrategy
    function proposeEmergencyWithdrawable(bool newWithdrawable) external {
        _requireRole(EMERGENCY_ADMIN_ROLE);
        proposedEmergencyWithdrawable = newWithdrawable;
        emergencyWithdrawableEffectiveTime = block.timestamp + ONE_WEEK;
        emit EmergencyWithdrawableProposed(newWithdrawable, emergencyWithdrawableEffectiveTime);
    }

    /// @inheritdoc ISuperVaultStrategy
    function executeEmergencyWithdrawableUpdate() external {
        if (block.timestamp < emergencyWithdrawableEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        emergencyWithdrawable = proposedEmergencyWithdrawable;
        proposedEmergencyWithdrawable = false;
        emergencyWithdrawableEffectiveTime = 0;
        emit EmergencyWithdrawableUpdated(emergencyWithdrawable);
    }

    /// @inheritdoc ISuperVaultStrategy
    function emergencyWithdraw(address recipient, uint256 amount) external {
        _requireRole(EMERGENCY_ADMIN_ROLE);
        if (!emergencyWithdrawable) revert EMERGENCY_WITHDRAWALS_DISABLED();
        if (recipient == address(0)) revert ZERO_ADDRESS();

        // Check we have enough free assets
        uint256 freeAssets = _asset.balanceOf(address(this));
        if (amount > freeAssets) revert INSUFFICIENT_FREE_ASSETS();

        // Transfer free assets to recipient
        _asset.safeTransfer(recipient, amount);
        emit EmergencyWithdrawal(recipient, amount);
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
    //--Core helpers--
    function _handleRequestDeposit(address controller, uint256 assets) internal {
        _requireVault();
        if (assets == 0) revert ZERO_AMOUNT();

        // Transfer assets from vault
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Update state
        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + assets;
    }

    function _handleCancelDeposit(address controller, uint256 assets) internal {
        _requireVault();
        if (assets == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = 0;

        // Return assets to vault
        _asset.safeTransfer(_vault, assets);
    }

    function _handleClaimDeposit(address controller, uint256 shares) internal {
        _requireVault();
        if (shares == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        if (state.maxMint < shares) revert INVALID_AMOUNT();

        // Update state
        state.maxMint -= shares;
    }

    function _handleRequestRedeem(address controller, uint256 shares) internal {
        _requireVault();
        if (shares == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;
    }

    function _handleCancelRedeem(address controller) internal {
        _requireVault();
        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = 0;
    }

    function _handleClaimWithdraw(address controller, uint256 assets) internal {
        _requireVault();
        if (assets == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        console2.log("state.maxWithdraw", state.maxWithdraw);
        console2.log("assets", assets);
        console2.log("state.averageWithdrawPrice", state.averageWithdrawPrice);

        if (state.maxWithdraw < assets) revert INVALID_AMOUNT();

        // Check actual asset balance
        uint256 availableAssets = _asset.balanceOf(address(this));
        if (availableAssets < assets) revert INSUFFICIENT_ASSETS();

        // Update state
        state.maxWithdraw -= assets;

        // Transfer assets to vault
        _asset.safeTransfer(_vault, assets);
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
        internal
        pure
    {
        if (hooksLength == 0) revert ZERO_LENGTH();

        // Validate array lengths match
        if (hooksLength != hookProofsLength || hooksLength != hookCalldataLength) {
            revert ARRAY_LENGTH_MISMATCH();
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
        internal
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
        internal
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
        if (hookType != expectedHookType) revert INVALID_HOOK();

        target = executions[0].target;

        // Validate target is an active yield source if needed
        if (validateYieldSource) {
            YieldSource storage source = yieldSources[target];
            if (!source.isActive) revert INVALID_YIELD_SOURCE();
        }
        approvalToken = hookType == ISuperHook.HookType.OUTFLOW ? target : approvalToken;
        // Handle token approvals if needed
        if (approvalToken != address(0)) {
            IERC20(approvalToken).safeIncreaseAllowance(target, approvalAmount);
        }

        // Execute the transaction
        (bool success,) = target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert EXECUTION_FAILED();

        // Reset approval if needed
        if (approvalToken != address(0)) {
            IERC20(approvalToken).forceApprove(target, 0);
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
        internal
        view
        returns (uint256[] memory changes)
    {
        uint256 length = tokens.length;
        changes = new uint256[](length);

        for (uint256 i; i < length;) {
            uint256 finalBalance = IERC20(tokens[i]).balanceOf(address(this));

            if (requireZeroBalance) {
                if (finalBalance != 0) revert INVALID_BALANCE_CHANGE();
            } else {
                if (finalBalance < initialBalances[i]) revert INVALID_BALANCE_CHANGE();
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
        internal
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
        internal
        returns (uint256 amount, address target)
    {
        // Get amount before execution
        amount = ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);

        // Get all TVLs in one call
        (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs) = totalAssets();
        // Execute hook with asset approval
        target = _executeHook(
            hook, prevHook, hookCalldata, hookProof, ISuperHook.HookType.INFLOW, true, address(_asset), amount
        );

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
            (currentYieldSourceAssets + amount).mulDiv(ONE_HUNDRED_PERCENT, totalAssets_)
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
        internal
        returns (uint256 amount, address target)
    {
        // Get amount before execution
        amount = ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);

        // convert amount to underlying vault shares
        address yieldSource = HookDataDecoder.extractYieldSource(hookCalldata);
        uint256 amountConvertedToUnderlyingShares =
            IYieldSourceOracle(yieldSources[yieldSource].oracle).getShareOutput(yieldSource, address(_asset), amount);
        hookCalldata = ISuperHookOutflow(hook).replaceCalldataAmount(hookCalldata, amountConvertedToUnderlyingShares);

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
        internal
        returns (uint256[] memory balanceChanges)
    {
        // Get initial balances
        uint256[] memory initialBalances = new uint256[](expectedTokensOut.length);
        for (uint256 i = 0; i < expectedTokensOut.length;) {
            initialBalances[i] = IERC20(expectedTokensOut[i]).balanceOf(address(this));
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
        internal
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
        uint256 finalAssetBalance = _asset.balanceOf(address(this));
        if (finalAssetBalance <= initialAssetBalance) revert INVALID_BALANCE_CHANGE();
        assetGained = finalAssetBalance - initialAssetBalance;
    }

    /// @notice Check vault caps for targeted yield sources
    /// @param targetedYieldSources Array of yield sources to check
    function _checkVaultCaps(address[] memory targetedYieldSources) internal view {
        // Note: This check is gas expensive due to getTVLByOwnerOfShares calls
        for (uint256 i; i < targetedYieldSources.length;) {
            address source = targetedYieldSources[i];
            uint256 yieldSourceTVL =
                IYieldSourceOracle(yieldSources[source].oracle).getTVLByOwnerOfShares(source, address(this));
            if (yieldSourceTVL > globalConfig.vaultCap) revert VAULT_CAP_EXCEEDED();
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Calculate fee on profit and transfer to recipient
    /// @param currentAssets Current value of shares in assets
    /// @param historicalAssets Historical value of shares in assets
    /// @return uint256 Assets after fee deduction
    function _calculateAndTransferFee(uint256 currentAssets, uint256 historicalAssets) internal returns (uint256) {
        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, ONE_HUNDRED_PERCENT);

            if (totalFee > 0) {
                // Calculate Superform's portion of the fee
                uint256 superformFee = totalFee.mulDiv(superRegistry.getSuperformFeeSplit(), ONE_HUNDRED_PERCENT);
                uint256 recipientFee = totalFee - superformFee;

                // Transfer fees
                if (superformFee > 0) {
                    _asset.safeTransfer(superRegistry.getTreasury(), superformFee);
                    emit FeePaid(superRegistry.getTreasury(), superformFee, performanceFeeBps);
                }

                if (recipientFee > 0) {
                    _asset.safeTransfer(feeConfig.recipient, recipientFee);
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
        internal
        returns (uint256 finalAssets, uint256 lastConsumedIndex)
    {
        uint256 historicalAssets = 0;
        uint256 sharePricePointsLength = state.sharePricePoints.length;
        uint256 remainingShares = requestedShares;
        uint256 currentIndex = state.sharePricePointCursor;
        lastConsumedIndex = currentIndex;

        // Calculate historicalAssets for each share price point
        for (uint256 j = currentIndex; j < sharePricePointsLength && remainingShares > 0;) {
            SharePricePoint memory point = state.sharePricePoints[j];
            uint256 sharesFromPoint = point.shares > remainingShares ? remainingShares : point.shares;
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, 10 ** _vaultDecimals);

            // Update point's remaining shares or mark for deletion
            if (sharesFromPoint == point.shares) {
                // Point fully consumed, move cursor
                lastConsumedIndex = j + 1;
            } else if (sharesFromPoint < point.shares) {
                // Point partially consumed, update shares
                state.sharePricePoints[j].shares -= sharesFromPoint;
            }

            remainingShares -= sharesFromPoint;
            unchecked {
                ++j;
            }
        }

        // Calculate current value and process fees
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, 10 ** _vaultDecimals);
        finalAssets = _calculateAndTransferFee(currentAssets, historicalAssets);

        // Update average withdraw price
        if (requestedShares > 0) {
            state.averageWithdrawPrice = finalAssets.mulDiv(
                1e18,
                requestedShares,
                Math.Rounding.Ceil // Use ceiling rounding to avoid underflow
            );
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
        internal
        pure
    {
        if (hooks.length != expectedLength || hookCalldata.length != expectedLength) {
            revert ARRAY_LENGTH_MISMATCH();
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
        internal
        pure
    {
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (hooksLength != hookProofs.length || hooksLength != hookCalldata.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }
    }
}
