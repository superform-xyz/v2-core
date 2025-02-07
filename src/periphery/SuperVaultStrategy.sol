// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// External
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// Interfaces
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";
import { ISuperHook, ISuperHookResult, Execution, ISuperHookInflowOutflow } from "../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperVault } from "./interfaces/ISuperVault.sol";

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
    uint256 public constant ONE_WEEK = 7 days;

    // Role identifiers
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    bool public initialized;
    address public vault;
    IERC20 public asset;
    uint8 public underlyingDecimals;
    // Role-based access control
    mapping(bytes32 role => address roleAddress) public addresses;

    // Global configuration
    GlobalConfig public globalConfig;

    // Fee configuration
    FeeConfig public feeConfig;

    // Hook root configuration
    bytes32 public hookRoot;
    bytes32 public proposedHookRoot;
    uint256 public hookRootEffectiveTime;

    // Emergency withdrawable configuration
    bool public emergencyWithdrawable;
    bool public proposedEmergencyWithdrawable;
    uint256 public emergencyWithdrawableEffectiveTime;

    // Yield source configuration
    mapping(address source => YieldSource sourceConfig) public yieldSources;
    address[] public yieldSourcesList;
    mapping(address source => ProposedYieldSource proposedSourceConfig) public proposedYieldSources;

    // Request tracking
    mapping(address controller => SuperVaultState state) private superVaultState;

    // Modifiers for role checks
    modifier onlyManager() {
        if (msg.sender != addresses[MANAGER_ROLE]) revert UNAUTHORIZED();
        _;
    }

    modifier onlyStrategist() {
        if (msg.sender != addresses[STRATEGIST_ROLE]) revert UNAUTHORIZED();
        _;
    }

    modifier onlyEmergencyAdmin() {
        if (msg.sender != addresses[EMERGENCY_ADMIN_ROLE]) revert UNAUTHORIZED();
        _;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert UNAUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address vault_,
        address manager_,
        address strategist_,
        address emergencyAdmin_,
        GlobalConfig memory config_
    )
        external
    {
        if (initialized) revert ALREADY_INITIALIZED();
        if (vault_ == address(0)) revert INVALID_VAULT();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (config_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config_.maxAllocationRate == 0 || config_.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_ALLOCATION_RATE();
        }
        if (config_.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        initialized = true;
        vault = vault_;
        asset = IERC20(IERC4626(vault_).asset());
        underlyingDecimals = IERC20Metadata(vault_).decimals();

        // Initialize roles
        addresses[MANAGER_ROLE] = manager_;
        addresses[STRATEGIST_ROLE] = strategist_;
        addresses[EMERGENCY_ADMIN_ROLE] = emergencyAdmin_;

        globalConfig = config_;
    }

    /*//////////////////////////////////////////////////////////////
                        REQUEST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update state for a new deposit request
    /// @param controller The controller address
    /// @param assets Amount of assets being deposited
    function handleRequestDeposit(address controller, uint256 assets) external onlyVault {
        if (assets == 0) revert ZERO_AMOUNT();

        // Transfer assets from vault
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Update state
        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + assets;
    }

    /// @notice Update state for a deposit request cancellation
    /// @param controller The controller address
    /// @param assets Amount of assets to return
    function handleCancelDeposit(address controller, uint256 assets) external onlyVault {
        if (assets == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingDepositRequest = 0;

        // Return assets to vault
        asset.safeTransfer(vault, assets);
    }

    /// @notice Update state for a new redeem request
    /// @param controller The controller address
    /// @param shares Amount of shares being redeemed
    function handleRequestRedeem(address controller, uint256 shares) external onlyVault {
        if (shares == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;
    }

    /// @notice Update state for a redeem request cancellation
    /// @param controller The controller address
    function handleCancelRedeem(address controller) external onlyVault {
        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = 0;
    }

    /// @notice Handle deposit claim by updating maxMint state
    /// @param controller The controller address
    /// @param shares Amount of shares being claimed
    function handleDeposit(address controller, uint256 shares) external onlyVault {
        if (shares == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        if (state.maxMint < shares) revert INVALID_AMOUNT();

        // Update state
        state.maxMint -= shares;
    }

    /// @notice Handle withdraw claim by updating maxWithdraw state
    /// @param controller The controller address
    /// @param assets Amount of assets being claimed
    function handleWithdraw(address controller, uint256 assets) external onlyVault {
        if (assets == 0) revert ZERO_AMOUNT();

        SuperVaultState storage state = superVaultState[controller];
        if (state.maxWithdraw < assets) revert INVALID_AMOUNT();

        // Update state
        state.maxWithdraw -= assets;

        // Transfer assets to vault
        asset.safeTransfer(vault, assets);
    }

    /*//////////////////////////////////////////////////////////////
                STRATEGIST EXTERNAL ACCESS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fulfillDepositRequests(
        address[] calldata users,
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external
        onlyStrategist
    {
        uint256 usersLength = users.length;
        uint256 hooksLength = hooks.length;

        _validateFulfillArrays(usersLength, hooksLength, hookProofs.length, hookCalldata.length);

        FulfillmentVars memory vars;

        // Validate requests and get total assets
        vars.totalRequestedAmount = _validateRequests(usersLength, users, true);

        // Check we have enough free assets to fulfill these requests
        vars.availableAmount = asset.balanceOf(address(this));
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
            vars.shares = vars.requestedAmount.mulDiv(10 ** underlyingDecimals, vars.pricePerShare);
            // Add new share price point
            state.sharePricePoints.push(SharePricePoint({ shares: vars.shares, pricePerShare: vars.pricePerShare }));

            // Move request to claimable state
            state.pendingDepositRequest = 0;

            // Mint shares to escrow
            ISuperVault(vault).mintShares(vars.shares);

            state.maxMint += vars.shares;

            // Call vault callback instead of emitting event directly
            ISuperVault(vault).onDepositClaimable(user, vars.requestedAmount, vars.shares);

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
        onlyStrategist
    {
        uint256 usersLength = users.length;
        uint256 hooksLength = hooks.length;

        _validateFulfillArrays(usersLength, hooksLength, hookProofs.length, hookCalldata.length);

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
            ISuperVault(vault).onRedeemClaimable(user, finalAssets, vars.requestedAmount);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Match redeem requests with deposit requests directly, without accessing yield sources
    /// @param redeemUsers Array of users with pending redeem requests
    /// @param depositUsers Array of users with pending deposit requests
    function matchRequests(address[] calldata redeemUsers, address[] calldata depositUsers) external onlyStrategist {
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
            vars.sharesNeeded = vars.depositAssets.mulDiv(10 ** underlyingDecimals, vars.currentPricePerShare);
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
            ISuperVault(vault).onDepositClaimable(depositor, vars.depositAssets, vars.sharesNeeded);

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
                ISuperVault(vault).onRedeemClaimable(redeemer, vars.finalAssets, sharesUsed);
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
        onlyStrategist
    {
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (hooksLength != hookProofs.length || hooksLength != hookCalldata.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        AllocationVars memory vars;
        address[] memory inflowTargets = new address[](hooksLength);
        uint256 inflowCount;
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
                // Get current total assets in yield source
                vars.currentYieldSourceAssets = IERC4626(vars.executions[0].target).convertToAssets(
                    IERC4626(vars.executions[0].target).balanceOf(address(this))
                );

                // Check allocation rate
                if (
                    (vars.currentYieldSourceAssets + vars.amount).mulDiv(ONE_HUNDRED_PERCENT, totalAssets())
                        > globalConfig.maxAllocationRate
                ) {
                    revert MAX_ALLOCATION_RATE_EXCEEDED();
                }

                // Check vault threshold
                if (vars.currentYieldSourceAssets < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

                // Track inflow target
                inflowTargets[inflowCount++] = vars.executions[0].target;

                // Approve spending
                asset.safeIncreaseAllowance(vars.executions[0].target, vars.amount);
            }

            // Execute the transaction
            (bool success,) =
                vars.executions[0].target.call{ value: vars.executions[0].value }(vars.executions[0].callData);
            if (!success) revert EXECUTION_FAILED();

            // Reset approval if it was an inflow
            if (vars.hookType == ISuperHook.HookType.INFLOW) {
                asset.forceApprove(vars.executions[0].target, 0);
            }

            // Update prevHook for next iteration
            vars.prevHook = hooks[i];

            unchecked {
                ++i;
            }
        }
        // Resize array to actual count if needed
        if (inflowCount < hooksLength) {
            // Get the memory pointer of the array
            assembly {
                mstore(inflowTargets, inflowCount)
            }
        }

        // Check vault caps for all inflow targets after processing
        _checkVaultCaps(inflowTargets);
    }

    /// @inheritdoc ISuperVaultStrategy
    function claimRewards(
        address[] calldata hooks,
        bytes32[][] calldata hookProofs,
        bytes[] calldata hookCalldata
    )
        external
        onlyStrategist
    {
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (hooksLength != hookProofs.length || hooksLength != hookCalldata.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        address prevHook;
        // Process each hook in sequence
        for (uint256 i; i < hooksLength;) {
            // Validate hook via merkle proof
            if (!isHookAllowed(hooks[i], hookProofs[i])) revert INVALID_HOOK();

            // Build executions for this hook
            ISuperHook hookContract = ISuperHook(hooks[i]);
            Execution[] memory executions = hookContract.build(prevHook, address(this), hookCalldata[i]);
            // prevent any hooks with more than one execution
            if (executions.length > 1) revert INVALID_HOOK();

            // Validate hook type is neither INFLOW nor OUTFLOW
            ISuperHook.HookType hookType = ISuperHookResult(hooks[i]).hookType();
            if (hookType == ISuperHook.HookType.INFLOW || hookType == ISuperHook.HookType.OUTFLOW) {
                revert INVALID_HOOK();
            }

            // Validate target is an active yield source
            YieldSource storage source = yieldSources[executions[0].target];
            if (!source.isActive) revert INVALID_YIELD_SOURCE();

            // Execute the transaction
            (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
            if (!success) revert EXECUTION_FAILED();

            // Update prevHook for next iteration
            prevHook = hooks[i];

            unchecked {
                ++i;
            }
        }
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
            pricePerShare = 10 ** underlyingDecimals;
        } else {
            // Calculate current PPS
            pricePerShare = totalAssets().mulDiv(10 ** underlyingDecimals, totalSupplyAmount);
        }
    }

    /// @inheritdoc ISuperVaultStrategy
    function totalSupply() public view returns (uint256) {
        return IERC4626(vault).totalSupply();
    }

    /// @inheritdoc ISuperVaultStrategy
    function totalAssets() public view returns (uint256) {
        // Total assets is the sum of all assets in yield sources plus idle assets
        uint256 total = asset.balanceOf(address(this)); // Idle assets

        uint256 length = yieldSourcesList.length;
        // Sum up value in yield sources
        for (uint256 i; i < length;) {
            address source = yieldSourcesList[i];
            if (yieldSources[source].isActive) {
                total += IYieldSourceOracle(yieldSources[source].oracle).getTVL(source, address(this));
            }
            unchecked {
                i++;
            }
        }

        return total;
    }

    /// @inheritdoc ISuperVaultStrategy
    function maxMint(address owner) public view returns (uint256) {
        return superVaultState[owner].maxMint;
    }

    /// @inheritdoc ISuperVaultStrategy
    function maxWithdraw(address owner) public view returns (uint256) {
        return superVaultState[owner].maxWithdraw;
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Propose a new yield source
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function proposeYieldSource(address source, address oracle) external onlyManager {
        if (source == address(0)) revert INVALID_YIELD_SOURCE();
        if (oracle == address(0)) revert INVALID_ORACLE();
        if (yieldSources[source].oracle != address(0)) revert YIELD_SOURCE_ALREADY_EXISTS();

        // Check vault threshold
        uint256 sourceAssets = IERC4626(source).totalAssets();
        if (sourceAssets < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

        // Create proposal
        proposedYieldSources[source] = ProposedYieldSource({
            source: source,
            oracle: oracle,
            effectiveTime: block.timestamp + ONE_WEEK,
            isPending: true
        });

        emit YieldSourceProposed(source, oracle, block.timestamp + ONE_WEEK);
    }

    /// @notice Execute a proposed yield source addition after timelock
    /// @param source Address of the yield source to execute proposal for
    function executeYieldSourceProposal(address source) external {
        ProposedYieldSource memory proposal = proposedYieldSources[source];
        if (!proposal.isPending) revert REQUEST_NOT_FOUND();
        if (block.timestamp < proposal.effectiveTime) revert TIMELOCK_NOT_EXPIRED();

        // Add yield source
        yieldSources[source] = YieldSource({ oracle: proposal.oracle, isActive: true });
        yieldSourcesList.push(source);

        // Clean up proposal
        delete proposedYieldSources[source];

        emit YieldSourceAdded(source, proposal.oracle);
    }

    /// @notice Update oracle for an existing yield source
    /// @param source Address of the yield source
    /// @param newOracle Address of the new oracle
    function updateYieldSourceOracle(address source, address newOracle) external onlyManager {
        if (newOracle == address(0)) revert INVALID_ORACLE();
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        address oldOracle = yieldSource.oracle;
        yieldSource.oracle = newOracle;

        emit YieldSourceOracleUpdated(source, oldOracle, newOracle);
    }

    /// @notice Deactivate a yield source
    /// @param source Address of the yield source to deactivate
    function deactivateYieldSource(address source) external onlyManager {
        YieldSource storage yieldSource = yieldSources[source];
        if (!yieldSource.isActive) revert YIELD_SOURCE_NOT_FOUND();

        // Check no assets are allocated to this source
        uint256 sourceShares = IERC4626(source).balanceOf(address(this));
        if (sourceShares > 0) revert INVALID_YIELD_SOURCE();

        yieldSource.isActive = false;
        emit YieldSourceDeactivated(source);
    }

    /// @notice Reactivate a previously removed yield source
    /// @param source Address of the yield source to reactivate
    function reactivateYieldSource(address source) external onlyManager {
        YieldSource storage yieldSource = yieldSources[source];
        if (yieldSource.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        if (yieldSource.isActive) revert YIELD_SOURCE_ALREADY_EXISTS();

        // Check vault threshold
        uint256 sourceAssets = IERC4626(source).totalAssets();
        if (sourceAssets < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

        yieldSource.isActive = true;
        emit YieldSourceReactivated(source);
    }

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external onlyManager {
        if (config.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (config.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (config.maxAllocationRate == 0 || config.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_ALLOCATION_RATE();
        }
        if (config.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();

        globalConfig = config;
        emit GlobalConfigUpdated(config.vaultCap, config.superVaultCap, config.maxAllocationRate, config.vaultThreshold);
    }

    /// @notice Propose a new hook root
    /// @param newRoot New hook root to propose
    function proposeHookRoot(bytes32 newRoot) external onlyManager {
        proposedHookRoot = newRoot;
        hookRootEffectiveTime = block.timestamp + ONE_WEEK;
        emit HookRootProposed(newRoot, hookRootEffectiveTime);
    }

    /// @notice Execute the proposed hook root update after timelock
    function executeHookRootUpdate() external {
        if (block.timestamp < hookRootEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
        if (proposedHookRoot == bytes32(0)) revert INVALID_HOOK_ROOT();

        hookRoot = proposedHookRoot;
        proposedHookRoot = bytes32(0);
        hookRootEffectiveTime = 0;
        emit HookRootUpdated(hookRoot);
    }

    /// @notice Update fee configuration
    /// @param feeBps New fee in basis points
    /// @param recipient New fee recipient
    function updateFeeConfig(uint256 feeBps, address recipient) external onlyManager {
        if (feeBps > ONE_HUNDRED_PERCENT) revert INVALID_FEE();
        if (recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        feeConfig = FeeConfig({ feeBps: feeBps, recipient: recipient });
        emit FeeConfigUpdated(feeBps, recipient);
    }

    /// @notice Set an address for a given role
    /// @dev Only callable by MANAGER role. Cannot set address(0) or remove MANAGER role from themselves
    /// @param role The role identifier
    /// @param account The address to set for the role
    function setAddress(bytes32 role, address account) external onlyManager {
        // Prevent setting zero address
        if (account == address(0)) revert ZERO_ADDRESS();

        // Prevent manager from changing themselves
        if (role == MANAGER_ROLE && account != msg.sender) revert UNAUTHORIZED();

        addresses[role] = account;
    }

    /// @notice Propose a change to emergency withdrawable status
    /// @param newWithdrawable The new emergency withdrawable status to propose
    function proposeEmergencyWithdrawable(bool newWithdrawable) external onlyManager {
        proposedEmergencyWithdrawable = newWithdrawable;
        emergencyWithdrawableEffectiveTime = block.timestamp + ONE_WEEK;
        emit EmergencyWithdrawableProposed(newWithdrawable, emergencyWithdrawableEffectiveTime);
    }

    /// @notice Execute the proposed emergency withdrawable update after timelock
    function executeEmergencyWithdrawableUpdate() external {
        if (block.timestamp < emergencyWithdrawableEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        emergencyWithdrawable = proposedEmergencyWithdrawable;
        proposedEmergencyWithdrawable = false;
        emergencyWithdrawableEffectiveTime = 0;
        emit EmergencyWithdrawableUpdated(emergencyWithdrawable);
    }

    /// @notice Emergency withdraw free assets from the vault
    /// @dev Only works when emergency withdrawals are enabled
    /// @param recipient Address to receive the withdrawn assets
    /// @param amount Amount of free assets to withdraw
    function emergencyWithdraw(address recipient, uint256 amount) external onlyEmergencyAdmin {
        if (!emergencyWithdrawable) revert EMERGENCY_WITHDRAWALS_DISABLED();
        if (recipient == address(0)) revert ZERO_ADDRESS();

        // Check we have enough free assets
        uint256 freeAssets = asset.balanceOf(address(this));
        if (amount > freeAssets) revert INSUFFICIENT_FREE_ASSETS();

        // Transfer free assets to recipient
        asset.safeTransfer(recipient, amount);
        emit EmergencyWithdrawal(recipient, amount);
    }
    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get a yield source's configuration
    /// @param source Address of the yield source

    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }

    /// @notice Get the global configuration
    function getGlobalConfig() external view returns (GlobalConfig memory) {
        return globalConfig;
    }

    /// @notice Get the fee configuration
    function getFeeConfig() external view returns (FeeConfig memory) {
        return feeConfig;
    }

    /// @notice Get the current hook root
    function getHookRoot() external view returns (bytes32) {
        return hookRoot;
    }

    /// @notice Get the proposed hook root
    function getProposedHookRoot() external view returns (bytes32) {
        return proposedHookRoot;
    }

    /// @notice Get the hook root effective time
    function getHookRootEffectiveTime() external view returns (uint256) {
        return hookRootEffectiveTime;
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
        bytes32 leaf = keccak256(abi.encodePacked(hook));
        return MerkleProof.verify(proof, hookRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //--Fulfilment and allocation helpers--

    /// @notice Validate array lengths for fulfill functions
    /// @param usersLength Length of users array
    /// @param hooksLength Length of hooks array
    /// @param hookProofsLength Length of hook proofs array
    /// @param hookCalldataLength Length of hook calldata array
    function _validateFulfillArrays(
        uint256 usersLength,
        uint256 hooksLength,
        uint256 hookProofsLength,
        uint256 hookCalldataLength
    )
        internal
        pure
    {
        if (usersLength == 0 || hooksLength == 0) revert ZERO_LENGTH();

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

    /// @notice Common hook execution logic shared between deposit and redeem flows
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence
    /// @param hookCalldata The calldata for the hook
    /// @param expectedHookType The expected type of hook (INFLOW/OUTFLOW)
    function _processCommonHookExecution(
        address hook,
        address prevHook,
        bytes calldata hookCalldata,
        ISuperHook.HookType expectedHookType
    )
        internal
        view
        returns (Execution[] memory executions, uint256 amount)
    {
        // Build executions for this hook
        ISuperHook hookContract = ISuperHook(hook);
        executions = hookContract.build(prevHook, address(this), hookCalldata);
        // prevent any hooks with more than one execution
        if (executions.length > 1) revert INVALID_HOOK();

        // Validate hook type
        ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();
        if (hookType != expectedHookType) revert INVALID_HOOK();

        // Get amount from hook
        amount = ISuperHookInflowOutflow(hook).decodeAmount(hookCalldata);

        // Validate target is an active yield source
        YieldSource storage source = yieldSources[executions[0].target];
        if (!source.isActive) revert INVALID_YIELD_SOURCE();
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
        bytes[] calldata hookCalldata,
        FulfillmentVars memory vars,
        bool isDeposit
    )
        internal
        returns (FulfillmentVars memory, address[] memory)
    {
        uint256 hooksLength = hooks.length;
        // Track targeted yield sources for inflow operations
        address[] memory targetedYieldSources = new address[](hooksLength);
        uint256 targetedSourcesCount;
        address target;
        for (uint256 i; i < hooksLength;) {
            // Validate hook via merkle proof
            if (!isHookAllowed(hooks[i], hookProofs[i])) revert INVALID_HOOK();

            // Process hook executions
            (vars.prevHook, vars.spentAmount, target) = isDeposit
                ? _processInflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i], vars.spentAmount)
                : _processOutflowHookExecution(hooks[i], vars.prevHook, hookCalldata[i], vars.spentAmount);

            // Track targeted yield source for inflow operations
            if (isDeposit) {
                targetedYieldSources[targetedSourcesCount++] = target;
            }

            unchecked {
                ++i;
            }
        }

        // Verify all amounts were spent
        if (vars.spentAmount != vars.totalRequestedAmount) revert INVALID_AMOUNT();

        // Resize array to actual count if needed
        if (targetedSourcesCount < hooksLength) {
            assembly {
                mstore(targetedYieldSources, targetedSourcesCount)
            }
        }

        return (vars, targetedYieldSources);
    }

    function _processInflowHookExecution(
        address hook,
        address prevHook,
        bytes calldata hookCalldata,
        uint256 spentAmount
    )
        internal
        returns (address, uint256, address)
    {
        // Process common hook execution logic
        (Execution[] memory executions, uint256 amount) =
            _processCommonHookExecution(hook, prevHook, hookCalldata, ISuperHook.HookType.INFLOW);

        // Get current total assets in yield source
        uint256 currentYieldSourceAssets =
            IERC4626(executions[0].target).convertToAssets(IERC4626(executions[0].target).balanceOf(address(this)));

        // Check allocation rate
        if (
            (currentYieldSourceAssets + amount).mulDiv(ONE_HUNDRED_PERCENT, totalAssets())
                > globalConfig.maxAllocationRate
        ) {
            revert MAX_ALLOCATION_RATE_EXCEEDED();
        }

        // Check vault threshold
        if (currentYieldSourceAssets < globalConfig.vaultThreshold) revert VAULT_THRESHOLD_NOT_MET();

        // Approve assets to target
        asset.safeIncreaseAllowance(executions[0].target, amount);

        // Execute the transaction
        (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert EXECUTION_FAILED();

        // Reset approval
        asset.forceApprove(executions[0].target, 0);

        // Update spent assets
        spentAmount += amount;

        return (hook, spentAmount, executions[0].target);
    }

    function _processOutflowHookExecution(
        address hook,
        address prevHook,
        bytes calldata hookCalldata,
        uint256 spentAmount
    )
        internal
        returns (address, uint256, address)
    {
        // Process common hook execution logic
        (Execution[] memory executions, uint256 shares) =
            _processCommonHookExecution(hook, prevHook, hookCalldata, ISuperHook.HookType.OUTFLOW);

        // Execute the transaction
        (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert EXECUTION_FAILED();

        // Update spent amount (tracking shares)
        spentAmount += shares;

        return (hook, spentAmount, executions[0].target);
    }

    /// @notice Check vault caps for targeted yield sources
    /// @param targetedYieldSources Array of yield sources to check
    function _checkVaultCaps(address[] memory targetedYieldSources) internal view {
        // Note: This check is gas expensive due to getTVL calls
        for (uint256 i; i < targetedYieldSources.length;) {
            address source = targetedYieldSources[i];
            uint256 yieldSourceTVL = IYieldSourceOracle(yieldSources[source].oracle).getTVL(source, address(this));
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
            uint256 fee = profit.mulDiv(feeConfig.feeBps, ONE_HUNDRED_PERCENT);
            currentAssets -= fee;

            // Transfer fee to recipient if non-zero
            if (fee > 0) {
                asset.safeTransfer(feeConfig.recipient, fee);
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
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, 10 ** underlyingDecimals);

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
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, 10 ** underlyingDecimals);
        finalAssets = _calculateAndTransferFee(currentAssets, historicalAssets);
    }
}
