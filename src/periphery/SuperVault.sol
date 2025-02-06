// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// External
import { ERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Interfaces
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import {
    IERC7540Vault, IERC7540Operator, IERC7540Deposit, IERC7540Redeem, IERC7741
} from "./interfaces/IERC7540Vault.sol";

// Core
import { ISuperHook, ISuperHookResult, Execution, ISuperHookInflowOutflow } from "../core/interfaces/ISuperHook.sol";
import { IYieldSourceOracle } from "../core/interfaces/accounting/IYieldSourceOracle.sol";

/// @title SuperVault
/// @notice A vault that allows users to deposit and withdraw assets across multiple yield sources
/// @author SuperForm Labs
contract SuperVault is ERC20, IERC7540Vault, IERC4626, ISuperVault {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 private constant REQUEST_ID = 0;

    // Role identifiers
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    // EIP712 TypeHash
    bytes32 public constant AUTHORIZE_OPERATOR_TYPEHASH =
        keccak256("AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    // Domain separator
    bytes32 private immutable _DOMAIN_SEPARATOR;
    bytes32 private immutable _NAME_HASH;
    bytes32 private immutable _VERSION_HASH;
    uint256 public immutable deploymentChainId;

    // 4626
    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    // Role-based access control
    mapping(bytes32 => address) public addresses;

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
    mapping(address => YieldSource) public yieldSources;
    address[] public yieldSourcesList;
    mapping(address => ProposedYieldSource) public proposedYieldSources;

    // Request tracking
    mapping(address controller => SuperVaultState state) private superVaultState;

    /// @inheritdoc IERC7540Operator
    mapping(address owner => mapping(address operator => bool)) public isOperator;

    // Authorization tracking
    mapping(address controller => mapping(bytes32 nonce => bool used)) private _authorizations;

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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        address manager_,
        address strategist_,
        address emergencyAdmin_,
        GlobalConfig memory globalConfig_,
        FeeConfig memory feeConfig_,
        bool emergencyWithdrawable_
    )
        ERC20(name_, symbol_)
    {
        if (asset_ == address(0)) revert INVALID_ASSET();
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (emergencyAdmin_ == address(0)) revert INVALID_EMERGENCY_ADMIN();
        if (globalConfig_.vaultCap == 0) revert INVALID_VAULT_CAP();
        if (globalConfig_.superVaultCap == 0) revert INVALID_SUPER_VAULT_CAP();
        if (globalConfig_.maxAllocationRate == 0 || globalConfig_.maxAllocationRate > ONE_HUNDRED_PERCENT) {
            revert INVALID_MAX_ALLOCATION_RATE();
        }
        if (globalConfig_.vaultThreshold == 0) revert INVALID_VAULT_THRESHOLD();
        if (feeConfig_.feeBps > ONE_HUNDRED_PERCENT) revert INVALID_FEE();
        if (feeConfig_.recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = IERC20(asset_);

        // Initialize roles
        addresses[MANAGER_ROLE] = manager_;
        addresses[STRATEGIST_ROLE] = strategist_;
        addresses[EMERGENCY_ADMIN_ROLE] = emergencyAdmin_;

        // Initialize EIP712 domain separator
        _NAME_HASH = keccak256(bytes("SuperVault"));
        _VERSION_HASH = keccak256(bytes("1"));
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();

        globalConfig = globalConfig_;
        feeConfig = feeConfig_;
        emergencyWithdrawable = emergencyWithdrawable_;
    }

    /*//////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    //--ERC7540--

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        if (assets == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();

        if (_asset.balanceOf(owner) < assets) revert INVALID_AMOUNT();

        // Transfer assets to vault
        _asset.safeTransferFrom(owner, address(this), assets);

        SuperVaultState storage state = superVaultState[controller];

        // Create deposit request
        state.pendingDepositRequest = state.pendingDepositRequest + assets;

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /// @notice Cancel a pending deposit request and return assets to the user
    /// @param controller The controller address
    function cancelDeposit(address controller) external {
        _validateController(controller);
        SuperVaultState storage state = superVaultState[controller];
        uint256 assets = state.pendingDepositRequest;
        if (assets == 0) revert REQUEST_NOT_FOUND();

        // Clear the request
        state.pendingDepositRequest = 0;

        // Return assets to user
        _asset.safeTransfer(msg.sender, assets);

        emit DepositRequestCancelled(controller, msg.sender);
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256) {
        if (shares == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();
        if (balanceOf(owner) < shares) revert INVALID_AMOUNT();

        // If msg.sender is operator of owner, the transfer is executed as if
        // the sender is the owner, to bypass the allowance check
        address sender = isOperator[owner][msg.sender] ? owner : msg.sender;

        // Transfer shares to SuperVault for temporary locking
        _transfer(sender, address(this), shares);

        // Create redeem request
        SuperVaultState storage state = superVaultState[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @notice Cancel a pending redeem request and return shares to the user
    /// @param controller The controller address
    function cancelRedeem(address controller) external {
        _validateController(controller);
        SuperVaultState storage state = superVaultState[controller];
        uint256 shares = state.pendingRedeemRequest;
        if (shares == 0) revert REQUEST_NOT_FOUND();

        // Clear the request
        state.pendingRedeemRequest = 0;

        // Return shares to user
        _transfer(address(this), msg.sender, shares);

        emit RedeemRequestCancelled(controller, msg.sender);
    }

    //--Operator Management--

    /// @inheritdoc IERC7540Operator
    function setOperator(address operator, bool approved) public returns (bool success) {
        if (msg.sender == operator) revert UNAUTHORIZED();
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /// @inheritdoc IERC7741
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    )
        external
        returns (bool)
    {
        if (controller == operator) revert UNAUTHORIZED();
        if (block.timestamp > deadline) revert TIMELOCK_NOT_EXPIRED();
        if (_authorizations[controller][nonce]) revert UNAUTHORIZED();

        _authorizations[controller][nonce] = true;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(AUTHORIZE_OPERATOR_TYPEHASH, controller, operator, approved, nonce, deadline))
            )
        );

        if (!_isValidSignature(controller, digest, signature)) revert INVALID_SIGNATURE();

        isOperator[controller][operator] = approved;
        emit OperatorSet(controller, operator, approved);

        return true;
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
            vars.shares = vars.requestedAmount.mulDiv(10 ** _underlyingDecimals, vars.pricePerShare);
            // Add new share price point
            state.sharePricePoints.push(SharePricePoint({ shares: vars.shares, pricePerShare: vars.pricePerShare }));

            // Move request to claimable state
            state.pendingDepositRequest = 0;

            // Mint shares to this vault
            _mint(address(this), vars.shares);

            state.maxMint += vars.shares;

            // Emit event
            emit DepositClaimable(user, REQUEST_ID, vars.requestedAmount, vars.shares);

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

            // Emit event
            emit RedeemClaimable(user, REQUEST_ID, finalAssets, vars.requestedAmount);

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
            vars.sharesNeeded = vars.depositAssets.mulDiv(10 ** _underlyingDecimals, vars.currentPricePerShare);
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
            emit DepositClaimable(depositor, REQUEST_ID, vars.depositAssets, vars.sharesNeeded);

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
                emit RedeemClaimable(redeemer, REQUEST_ID, vars.finalAssets, sharesUsed);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ISuperVault
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
                _asset.approve(vars.executions[0].target, vars.amount);
            }

            // Execute the transaction
            (bool success,) =
                vars.executions[0].target.call{ value: vars.executions[0].value }(vars.executions[0].callData);
            if (!success) revert EXECUTION_FAILED();

            // Reset approval if it was an inflow
            if (vars.hookType == ISuperHook.HookType.INFLOW) {
                _asset.approve(vars.executions[0].target, 0);
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

    /// @inheritdoc ISuperVault
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
            revert INVALID_MAX_ALLOCATION_RATE();
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
        uint256 freeAssets = _asset.balanceOf(address(this));
        if (amount > freeAssets) revert INSUFFICIENT_FREE_ASSETS();

        // Transfer free assets to recipient
        _asset.safeTransfer(recipient, amount);
        emit EmergencyWithdrawal(recipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    USER EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVault
    function getSuperVaultPPS() public view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = totalSupply();

        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in vault decimals
            pricePerShare = 10 ** _underlyingDecimals;
        } else {
            // Calculate current PPS
            pricePerShare = totalAssets().mulDiv(10 ** _underlyingDecimals, totalSupplyAmount);
        }
    }

    //--ERC7540--

    function pendingDepositRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 pendingAssets)
    {
        pendingAssets = superVaultState[controller].pendingDepositRequest;
    }

    function claimableDepositRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 claimableAssets)
    {
        claimableAssets = maxDeposit(controller);
    }

    function pendingRedeemRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 pendingShares)
    {
        pendingShares = superVaultState[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(
        uint256, /*requestId*/
        address controller
    )
        external
        view
        returns (uint256 claimableShares)
    {
        claimableShares = maxRedeem(controller);
    }

    //--Operator Management--

    /// @inheritdoc IERC7741
    function authorizations(address controller, bytes32 nonce) external view returns (bool used) {
        return _authorizations[controller][nonce];
    }

    /// @inheritdoc IERC7741
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator();
    }

    /// @inheritdoc IERC7741
    function invalidateNonce(bytes32 nonce) external {
        _authorizations[msg.sender][nonce] = true;
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
                        ERC4626 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals;
    }

    /// @inheritdoc IERC4626
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256) {
        // Total assets is the sum of all assets in yield sources plus idle assets
        uint256 total = _asset.balanceOf(address(this)); // Idle assets

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

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : Math.mulDiv(assets, supply, totalAssets(), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : Math.mulDiv(shares, totalAssets(), supply, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxMint(address owner) public view override returns (uint256) {
        return superVaultState[owner].maxMint;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address owner) public view override returns (uint256) {
        return convertToAssets(maxMint(owner));
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        return superVaultState[owner].maxWithdraw;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        return convertToShares(superVaultState[owner].maxWithdraw);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 /*assets*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 /*shares*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 /*assets*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 /*shares*/ ) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /// @inheritdoc IERC7540Deposit
    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        shares = convertToShares(assets);

        SuperVaultState storage state = superVaultState[controller];
        if (shares > state.maxMint) revert INVALID_DEPOSIT_CLAIM();
        uint256 maxMintMem = state.maxMint;
        state.maxMint = maxMintMem > shares ? maxMintMem - shares : 0;

        // Transfer shares to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = deposit(assets, receiver, msg.sender);
    }

    /// @inheritdoc IERC7540Deposit
    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        _validateController(controller);

        SuperVaultState storage state = superVaultState[controller];
        if (shares > state.maxMint) revert INVALID_DEPOSIT_CLAIM();
        assets = convertToAssets(shares);

        uint256 maxMintMem = state.maxMint;

        state.maxMint = maxMintMem > shares ? maxMintMem - shares : 0;

        // Transfer shares to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _validateController(owner);
        shares = convertToShares(assets);

        SuperVaultState storage state = superVaultState[owner];
        if (assets > state.maxWithdraw) revert INVALID_AMOUNT();
        uint256 maxWithdrawMem = state.maxWithdraw;
        state.maxWithdraw = maxWithdrawMem > assets ? maxWithdrawMem - assets : 0;

        _burn(address(this), shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        _validateController(owner);
        assets = convertToAssets(shares);

        SuperVaultState storage state = superVaultState[owner];
        if (shares > convertToShares(state.maxWithdraw)) revert INVALID_AMOUNT();
        uint256 maxWithdrawMem = state.maxWithdraw;
        state.maxWithdraw = maxWithdrawMem > shares ? maxWithdrawMem - shares : 0;

        _burn(address(this), shares);
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC165 INTERFACE
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC7540Vault).interfaceId || interfaceId == type(ISuperVault).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7741).interfaceId
            || interfaceId == type(IERC4626).interfaceId;
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
        _asset.approve(executions[0].target, amount);

        // Execute the transaction
        (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        if (!success) revert EXECUTION_FAILED();

        // Reset approval
        _asset.approve(executions[0].target, 0);

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
                _asset.safeTransfer(feeConfig.recipient, fee);
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
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, 10 ** _underlyingDecimals);

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
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, 10 ** _underlyingDecimals);
        finalAssets = _calculateAndTransferFee(currentAssets, historicalAssets);
    }

    //--Misc helpers--

    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();
    }

    /// @notice Calculate the EIP712 domain separator
    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Verify an EIP712 signature
    function _isValidSignature(address signer, bytes32 digest, bytes memory signature) internal pure returns (bool) {
        if (signature.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) return false;

        address recoveredSigner = ecrecover(digest, v, r, s);
        return recoveredSigner != address(0) && recoveredSigner == signer;
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
    function _tryGetAssetDecimals(address asset_) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory encodedDecimals) =
            address(asset_).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }
}
